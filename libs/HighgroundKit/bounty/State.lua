local _, ns = ...
local Core = ns.Core
ns.Bounty = {}
local Bounty = ns.Bounty

---------------------------------------------------------------------------
-- Bounties: gold put on an enemy player's head. Highground keeps and shares
-- the list; paying the gold is between players.
--
-- Anyone can add a personal bounty on anyone (alerts for you only) and
-- submit it to the guild. A submission stays pending, seen by officers and
-- its submitter only, until an officer approves it; then every member gets
-- it. Officers are the guild ranks up to bountyOfficerRank (0 = guild master).
--
-- HighgroundDB.bountyPersonal[key] and HighgroundDB.bountyGuild[guild@realm][key]
-- hold { name, gold, by, at, note, state, approver }. state: "personal",
-- "pending", "approved" or "removed". `at` (epoch seconds) versions a guild
-- entry: the newest wins, and removals stay as tombstones until they expire
-- so an old copy can't bring them back.
-- Names may contain spaces (WoW Forever has first and last names): never
-- split them on whitespace.
--
-- Files: State (model), Messages (actions and chat lines), Sync (guild
-- messages), Alerts (sightings and chat), Marks (nameplates and rows),
-- Widgets (card), Board (window), Share (chat links), Import (preview),
-- Driver (events and scans).
-- Used by other modules: Bounty.Find(name), Bounty.Enabled(),
-- Bounty.Spot(name, class[, quiet]), Bounty.MarkRow(row, name),
-- Bounty.GoldText(b), Bounty.Board.Build/Open/Toggle/Refresh.
---------------------------------------------------------------------------
Bounty.MAX_GOLD = 9999999
Bounty.CMD = ns.BOUNTY_CMD or "/hg bounty" -- named in chat lines (standalone: /hgb)
Bounty.NOTE_MAX = 60

local Util = ns.Util
local Call, Plain = Util.call, Util.value

Bounty.Clean = Util.Clean

-- Events, so the model never calls the files that load after it:
--   added(b)            a local Add (bounty/Alerts.lua records your target)
--   publish(b)          a guild entry changed here (bounty/Sync.lua sends it)
--   changed(b, from, was), shared(b, from, zone), claimed(b, from)
--                       guild messages (bounty/Sync.lua)
--   updated()           any local change (the board refreshes)
local listeners = {}
function Bounty.Listen(event, fn)
  listeners[event] = listeners[event] or {}
  table.insert(listeners[event], fn)
end

-- Each listener runs guarded: one failing does not stop the others.
function Bounty.Emit(event, ...)
  for _, fn in ipairs(listeners[event] or {}) do Util.Guard("bounty", fn, ...) end
end

-- "First Last-Realm" (lowercase) for lookups; nil for unusable names.
function Bounty.Key(name)
  local canon = Core.Canon(name)
  return canon and canon:lower()
end

-- First word + realm: a looser key for clients that show part of a name.
local function Loose(key)
  local short, realm = key:match("^([^-]+)-(.*)$")
  return short and (short:match("^(%S+)") or short) .. "-" .. realm
end

function Bounty.Me()
  return Core.CanonUnit("player") or Core.Canon(Plain(Call(UnitName, "player")))
end

local function GuildInfo()
  local guild, _, rank = Call(GetGuildInfo, "player")
  guild, rank = Plain(guild), Plain(rank)
  if type(guild) ~= "string" or guild == "" then return nil end
  return guild, rank
end

function Bounty.InGuild()
  return GuildInfo() ~= nil
end

function Bounty.GuildKey()
  local guild = GuildInfo()
  return guild and (guild .. "@" .. (Core.myRealm or ""))
end

-- Guild rank index by member (0 = guild master), rebuilt on roster updates.
Bounty.ranks = {}
function Bounty.ReadRoster()
  wipe(Bounty.ranks)
  for i = 1, Plain(Call(GetNumGuildMembers)) or 0 do
    local name, _, rank = Call(GetGuildRosterInfo, i)
    local key = Core.Canon(Plain(name))
    if key and type(Plain(rank)) == "number" then Bounty.ranks[key] = rank end
  end
end

function Bounty.IsOfficer(who)
  local limit = Core.O("bountyOfficerRank")
  if not who or who == Bounty.Me() then
    local guild, rank = GuildInfo()
    return guild ~= nil and type(rank) == "number" and rank <= limit
  end
  -- Unknown sender: the roster may have changed or not loaded yet.
  if Bounty.ranks[who] == nil and GetTime() - (Bounty.rosterRead or -math.huge) > 5 then
    Bounty.rosterRead = GetTime()
    Bounty.ReadRoster()
  end
  local rank = Bounty.ranks[who]
  return rank ~= nil and rank <= limit
end

-- Saved variables: the only reads of HighgroundDB in bounty/.
local function Saved(name)
  local db = Core.db
  if not db then return {} end
  db[name] = type(db[name]) == "table" and db[name] or {}
  return db[name]
end

function Bounty.Personal()
  return Saved("bountyPersonal")
end

-- One list per guild (and realm); empty outside a guild.
function Bounty.Guild()
  local bucket = Bounty.GuildKey()
  if not bucket then return {} end
  local all = Saved("bountyGuild")
  all[bucket] = all[bucket] or {}
  return all[bucket]
end

-- Whether this player sees (and is alerted for) an entry.
function Bounty.Visible(b)
  if b.state == "personal" or b.state == "approved" then return true end
  return b.state == "pending" and (b.by == Bounty.Me() or Bounty.IsOfficer())
end

-- Everything this player can see, highest reward first.
function Bounty.All()
  local out, seen = {}, {}
  local function Add(b)
    local key = Bounty.Key(b.name)
    if seen[key] then out[seen[key]] = b
    else out[#out + 1] = b; seen[key] = #out end
  end
  for _, b in ipairs(Bounty.GuildEntries()) do Add(b) end
  for _, b in pairs(Bounty.Personal()) do Add(b) end
  for _, b in ipairs(Bounty.Public.All()) do Add(b) end
  table.sort(out, function(a, b) return a.gold > b.gold or (a.gold == b.gold and a.name < b.name) end)
  return out
end

-- Entries that alert: personal, approved, and your own submissions.
local function Alerts(b)
  return b and b.state ~= "removed" and (b.state ~= "pending" or b.by == Bounty.Me()) and b or nil
end

local function Lookup(list, key)
  local exact = list[key]
  if exact then return exact end
  local loose = Loose(key)
  for k, e in pairs(list) do
    if Loose(k) == loose or k == loose then return e end
  end
end

-- The bounty that alerts on a name, exact first, then by first name.
function Bounty.Find(name, forAlert)
  local key = Bounty.Key(name)
  if not key then return nil end
  local shared = Bounty.Public and Bounty.Public.Find(name, forAlert)
  if shared then return shared end
  local guild = Lookup(Bounty.Guild(), key)
  if guild and guild.publicID then
    local p = Bounty.LinkedOffer(guild)
    if not p or not Bounty.Public.Active(p) or forAlert and (Bounty.Public.Funds(p) ~= "available"
      or p.gold < (Core.O("bountyMinGold") or 0)) then guild = nil end
  end
  return Alerts(Lookup(Bounty.Personal(), key)) or Alerts(guild)
end

-- Any visible entry on a name (board and commands act on these).
function Bounty.Entry(name)
  local key = Bounty.Key(name)
  if not key then return nil end
  local b = Bounty.Personal()[key]
  if b then return b end
  b = Bounty.Guild()[key]
  return b and b.state ~= "removed" and Bounty.Visible(b) and b
    or Bounty.Public and Bounty.Public.Find(name)
end

-- Drop guild entries older than bountyDays, tombstones included.
function Bounty.Expire()
  local limit = time() - Core.O("bountyDays") * 86400
  local list = Bounty.Guild()
  for key, b in pairs(list) do
    if b.at < limit then list[key] = nil end
  end
end

-- Class and last sighting are local: carried over when an entry changes.
function Bounty.KeepSighting(b, old)
  if not old then return end
  b.class, b.seenAt, b.seenZone, b.seenBy = old.class, old.seenAt, old.seenZone, old.seenBy
end

-- Accept a version of a guild entry if it is newer. Returns it when stored.
function Bounty.Merge(e)
  local key = Bounty.Key(e.name)
  if not key or type(e.gold) ~= "number" or type(e.at) ~= "number" then return nil end
  local list = Bounty.Guild()
  local old = list[key]
  if old and old.at >= e.at then return nil end
  if e.at < time() - Core.O("bountyDays") * 86400 then return nil end
  list[key] = { name = Core.Canon(e.name), gold = e.gold, by = e.by, at = e.at, state = e.state,
    approver = e.approver ~= "" and e.approver or nil, note = e.note ~= "" and e.note or nil,
    publicID = e.publicID or (old and old.by == e.by and old.state ~= "removed" and not old.publicClosed and old.publicID),
    publicClosed = old and old.by == e.by and old.publicID == e.publicID and old.publicClosed }
  Bounty.KeepSighting(list[key], old)
  return list[key]
end

local function Check(name, gold)
  local canon = Core.Canon(name)
  local short = canon and canon:match("^([^-]*)-")
  -- Character names have no digits (realms can: Area 52).
  if not canon or canon:find("[,;:|]") or not short or short == "" or short:find("%d") then
    return nil, "invalid name"
  end
  if gold == nil or gold == "" then gold = 0 end -- optional: no reward
  gold = tonumber(gold)
  if not gold or gold < 0 or gold > Bounty.MAX_GOLD or gold ~= math.floor(gold) then
    return nil, "gold must be empty or a whole number up to " .. Bounty.MAX_GOLD
  end
  return canon, gold
end

-- Local changes. Each returns the entry, or nil and a reason.
function Bounty.Add(name, gold, note)
  local canon, g = Check(name, gold)
  if not canon then return nil, g end
  local b = { name = canon, gold = g, by = Bounty.Me() or "?", at = time(), state = "personal",
    note = Bounty.Clean(note):sub(1, Bounty.NOTE_MAX) }
  Bounty.KeepSighting(b, Bounty.Personal()[canon:lower()])
  if b.note == "" then b.note = nil end
  Bounty.Personal()[canon:lower()] = b
  Bounty.Emit("added", b)
  return b
end

local function Publish(b, state, approver)
  b.state, b.approver = state, approver or b.approver
  b.at = math.max(time(), b.at + 1)
  Bounty.Emit("publish", b)
  return b
end

-- Personal -> guild: pending, or approved at once when you are an officer.
function Bounty.Submit(name)
  if not Bounty.InGuild() then return nil, "not in a guild" end
  local key = Bounty.Key(name)
  local p = key and Bounty.Personal()[key]
  if not p then return nil, "no personal bounty on " .. tostring(name) end
  local old = Bounty.Guild()[key]
  if old and old.state ~= "removed" and not old.publicClosed then return nil, "your guild already has a bounty on " .. p.name end
  local shared = Bounty.Public.Own(name)
  if shared and not Bounty.Public.CanManage(shared) then return nil, "Log into " .. shared.by .. " to share this contribution with your guild." end
  if shared and shared.revision >= 64 then return nil, "This contribution has reached its edit limit." end
  local b = { name = p.name, gold = shared and shared.gold or p.gold, by = Bounty.Me() or "?", note = shared and shared.note or p.note,
    publicID = shared and shared.id,
    at = math.max(p.at, old and old.at or 0) }
  Bounty.KeepSighting(b, p)
  Bounty.Guild()[key] = b
  Bounty.Personal()[key] = nil
  local officer = Bounty.IsOfficer()
  Publish(b, officer and "approved" or "pending", officer and Bounty.Me() or nil)
  if shared then Bounty.Public.AttachGuild(shared, b) end
  return b
end

function Bounty.Approve(name)
  local b = Bounty.Guild()[Bounty.Key(name)]
  if not (b and b.state == "pending") then return nil, "no pending bounty on " .. tostring(name) end
  if not Bounty.IsOfficer() then return nil, "only officers approve bounties" end
  return Publish(b, "approved", Bounty.Me())
end

-- Personal: deleted. Guild: the submitter or an officer takes it down
-- (an officer removing a pending one rejects it).
function Bounty.Remove(name, scope)
  local key = Bounty.Key(name)
  if scope ~= "guild" and key and Bounty.Personal()[key] then
    local b = Bounty.Personal()[key]
    Bounty.Personal()[key] = nil
    return b
  end
  local b = scope == "guild" and Bounty.Guild()[key] or Bounty.Entry(name)
  if not b then return nil, "no bounty on " .. tostring(name) end
  if b.state == "public" then return Bounty.Public.Withdraw(Bounty.Public.Own(name)) end
  if b.by ~= Bounty.Me() and not Bounty.IsOfficer() then
    return nil, "only " .. tostring(b.by) .. " or an officer can remove it"
  end
  return Publish(b, "removed")
end
