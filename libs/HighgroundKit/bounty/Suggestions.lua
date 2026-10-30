local _, ns = ...
local B, P, Core, U = ns.Bounty, ns.Bounty.Public, ns.Core, ns.Util
local S = { MAX_EVENTS = 600, MAX_VICTIM = 60 }
B.Suggestions = S

function S.Enabled() return not ns.STANDBY and Core.db and Core.On("bounty") and Core.O("bountySuggestions") == true end
function S.Sharing() return not ns.STANDBY and Core.db and Core.On("bounty") and Core.O("bountyDeathShare") == true end
function S.Window() return (Core.O("bountySuggestionWindow") or 30) * 60 end

local rosterAt = -math.huge
function S.ReadRoster()
  if GetTime() - rosterAt >= 5 then B.ReadRoster(); rosterAt = GetTime() end
end

-- Character-scoped records in the common data addon survive reloads and
-- switching between Highground, Bounties and Nearby. No lifetime totals
-- are imported: each counted death needs its own recent report.
function S.Data()
  if not P.ready then return end
  P.db.suggestions = type(P.db.suggestions) == "table" and P.db.suggestions or {}
  local key = P.Scope() .. ":" .. (B.Me() or "")
  local d = P.db.suggestions[key]
  if type(d) ~= "table" then d = {}; P.db.suggestions[key] = d end
  for _, field in ipairs({ "events", "notices", "dismissed", "ignored" }) do
    if type(d[field]) ~= "table" then d[field] = {} end
  end
  local guild = B.GuildKey()
  if d.guild ~= guild then
    local own = {}
    for _, e in ipairs(d.events) do if type(e) == "table" and e.own then e.guild = nil; own[#own + 1] = e end end
    d.events, d.guild = own, guild
    B.ReadRoster()
    if S.ClearQueue then S.ClearQueue() end
  end
  return d
end

function S.Valid(e)
  return type(e) == "table" and P.ID(e.id) and type(e.name) == "string" and P.Name(e.name) == e.name
    and type(e.victim) == "string" and P.Name(e.victim) == e.victim
    and P.Integer(e.at, 0, P.Now() + 5) and e.at > P.Now() - S.Window()
    and (e.source == "combat" or e.source == "recap") and type(e.zone) == "string" and #e.zone <= 64
end

function S.Prune()
  local d = S.Data()
  if not d then return end
  S.ReadRoster()
  local rosterReady = B.ranks[B.Me()] ~= nil
  local keep, seen, victims = {}, {}, {}
  for _, e in ipairs(d.events) do
    local identity = S.Valid(e) and e.victim:lower() .. ":" .. e.at
    if identity and not seen[identity] and #keep < S.MAX_EVENTS and (victims[e.victim] or 0) < S.MAX_VICTIM
      and (e.own and e.victim == B.Me() or not e.own and e.guild == d.guild and (not rosterReady or B.ranks[e.victim] ~= nil)) then
      keep[#keep + 1], seen[identity] = e, true
      victims[e.victim] = (victims[e.victim] or 0) + 1
    end
  end
  d.events = keep
  for _, field in ipairs({ "notices", "dismissed" }) do
    for key, at in pairs(d[field]) do
      if type(at) ~= "number" or at < P.Now() - 86400 then d[field][key] = nil end
    end
  end
end

function S.Record(e)
  if not P.ready or not (S.Enabled() or S.Sharing()) or not S.Valid(e) then return false end
  S.Prune()
  local d, count = S.Data(), 0
  if e.own and e.victim ~= B.Me() or not e.own and (not d.guild or e.guild ~= d.guild or B.ranks[e.victim] == nil) then return false end
  for _, old in ipairs(d.events) do
    if old.victim == e.victim then
      count = count + 1
      if old.id == e.id or old.at == e.at then return false end
    end
  end
  if count >= S.MAX_VICTIM then return false end
  if #d.events >= S.MAX_EVENTS then table.remove(d.events, 1) end
  d.events[#d.events + 1] = e
  B.Emit("updated")
  return true
end

function S.LocalDeath(death)
  if not P.ready or not (S.Enabled() or S.Sharing()) then return end
  local name = P.Name(death.name)
  if not name or B.Key(name) == B.Key(B.Me()) then return end
  local e = { id = P.NewID(), name = name, victim = B.Me(), at = death.at, source = death.source,
    zone = B.Clean(death.zone):sub(1, 64), own = true, guild = B.GuildKey() }
  if S.Record(e) and S.ShareDeath then S.ShareDeath(e) end
end
ns.PlayerDeaths.Listen(S.LocalDeath)

function S.Existing(name)
  local key = B.Key(name)
  local personal, guild = B.Personal()[key], B.Guild()[key]
  if guild and guild.state ~= "removed" and not guild.publicClosed and B.Visible(guild) then return "guild" end
  if personal or P.Own(name) then return "mine" end
  for _, b in ipairs(P.All()) do if B.Key(b.name) == key then return "public" end end
end

local function Blank(name)
  return { name = name, suggestion = true, gold = 0, scope = "suggestions", total = 0, personal = 0,
    guildDeaths = 0, victimCount = 0, guildVictimCount = 0, victims = {}, guildVictims = {}, reports = {}, last = 0 }
end

function S.Rows(query, showIgnored)
  if not S.Enabled() or not P.ready then return {} end
  S.Prune()
  local d, groups, out = S.Data(), {}, {}
  query = (query or ""):lower()
  for _, e in ipairs(d.events) do
    if e.own or B.ranks[e.victim] ~= nil then
      local key = B.Key(e.name)
      local r = groups[key] or Blank(e.name); groups[key] = r
      r.total = r.total + 1; r.reports[#r.reports + 1] = e
      if not r.victims[e.victim] then r.victimCount = r.victimCount + 1 end
      r.victims[e.victim] = (r.victims[e.victim] or 0) + 1
      if e.own then r.personal = r.personal + 1 end
      if e.guild and e.guild == d.guild then
        r.guildDeaths = r.guildDeaths + 1
        if not r.guildVictims[e.victim] then r.guildVictimCount = r.guildVictimCount + 1 end
        r.guildVictims[e.victim] = true
      end
      if e.at >= r.last then r.last, r.zone = e.at, e.zone end
    end
  end
  if showIgnored then
    for key, name in pairs(d.ignored) do if P.Name(name) then groups[key] = groups[key] or Blank(name) end end
  end
  for key, r in pairs(groups) do
    local personal = r.personal >= (Core.O("bountySuggestionPersonal") or 3)
    r.guildTrigger = r.guildDeaths >= (Core.O("bountySuggestionGuildDeaths") or 5)
      and r.guildVictimCount >= (Core.O("bountySuggestionVictims") or 3)
    r.ignored = d.ignored[key] ~= nil
    local dismissed = (d.dismissed[key] or 0) > P.Now()
    if (r.ignored and showIgnored or not r.ignored and not dismissed and (personal or r.guildTrigger))
      and (query == "" or r.name:lower():find(query, 1, true)) then
      r.mode = r.guildTrigger and "guild" or "personal"
      r.existing = S.Existing(r.name)
      r.owner = r.guildTrigger and "Recurring guild attacker" or "Recurring personal attacker"
      r.visibility = "You: " .. r.personal .. " · guild reports: " .. r.guildDeaths
      r.status = r.ignored and "Ignored · choose Allow again to restore suggestions"
        or r.total .. " reported deaths / " .. (S.Window() / 60) .. "m · " .. (r.zone or "Unknown location")
      r.muted = r.ignored
      out[#out + 1] = r
    end
  end
  table.sort(out, function(a, b)
    if a.ignored ~= b.ignored then return not a.ignored end
    return a.total > b.total or a.total == b.total and a.name < b.name
  end)
  return out
end

function S.Change(name, action)
  local d, key = S.Data(), B.Key(name)
  if not d or not key then return end
  if action == "ignore" then d.ignored[key] = name
  elseif action == "allow" then d.ignored[key], d.dismissed[key] = nil, nil
  else d.dismissed[key] = P.Now() + 86400 end
  if S.View then S.View.Hide(name) end
  B.Emit("updated")
end

function S.Reason(r)
  return string.format("Reported: %d deaths / %dm; you %d, guild victims %d", r.total, S.Window() / 60, r.personal, r.guildVictimCount):sub(1, B.NOTE_MAX)
end

local lastPrompt = -math.huge
function S.Tick()
  if not P.ready then return end
  if not S.Enabled() then
    if S.View then S.View.Hide() end
    if not S.Sharing() then S.Data().events = {} else S.Prune() end
    if B.Board then B.Board.Refresh() end
    return
  end
  local rows = S.Rows()
  if S.View then S.View.Update(rows) end
  if ns.Nearby.InWorld() and not U.read(InCombatLockdown) and S.View
    and (not ns.Alerts or ns.Alerts.Allowed("bounty", "text")) and GetTime() - lastPrompt >= 30 then
    local d = S.Data()
    for _, r in ipairs(rows) do
      if not r.existing and (r.personal > 0 or B.IsOfficer())
        and P.Now() - (d.notices[B.Key(r.name)] or -math.huge) >= (Core.O("bountySuggestionCooldown") or 60) * 60 then
        if S.View.Notify(r) then d.notices[B.Key(r.name)], lastPrompt = P.Now(), GetTime() end
        break
      end
    end
  end
  if B.Board then B.Board.Refresh() end
end
U.Every(1, S.Tick, "bounty suggestions")
