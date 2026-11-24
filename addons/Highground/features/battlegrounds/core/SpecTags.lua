local _, ns = ...
local Core, Comms = ns.Core, ns.Comms

---------------------------------------------------------------------------
-- Spec tags: a player names an enemy's talent tree by hand (the enemy
-- panel's spec picker) when the game can't tell. WoW Forever's scoreboard
-- only gives the class, and its auras and casts are secret in a match.
-- Tags are kept per region like scoreboard history and shared with the team
-- (prefix HighgroundS, group channel):
--   1:key,class,tree;key,class,tree;...   (tree 0 = tag removed)
--   R                                      (resend your tags: I just arrived)
-- Tree indexes, not spec IDs or names, so every client and language reads
-- them the same way. Older versions ignore R.
--
-- Precedence: what the game shows this match (scoreboard, even a secret
-- one, a talent-tree cast, an estimate from buffs) outranks a tag; a tag outranks earlier
-- matches' history and mana estimates.
---------------------------------------------------------------------------
Core.SPEC_TAG_PREFIX = "HighgroundS"
Core.SPEC_TAG_RETRY = 2 -- seconds between attempts while the game refuses
Core.SPEC_TAG_STRONG = { live = true, cast = true, aura = true }

local previewTags = {} -- sample tags while a preview or guide runs
local pending = {} -- [key] = true: tags (or removals) teammates haven't heard
local waiting = false
-- Teammates' tags for enemies the scoreboard hasn't listed yet (it can lag
-- several seconds): [key] = { class, tree, by, match }. Memory only, for
-- this match, and at most Core.EARLY_SPEC_TAGS_MAX.
local early, earlyCount = {}, 0
Core.EARLY_SPEC_TAGS_MAX = 40
-- A request for teammates' tags waits here while the game refuses to send.
local requesting = false

local function Store()
  if Core.testMode then return previewTags end
  return ns.Scope.Saved("specTags", "social")
end

function Core.ClearPreviewSpecTags() wipe(previewTags) end

-- The tagged spec ID and its record, for an enemy key of that class.
function Core.SpecTag(key, class)
  local t = key and Store()[key]
  if type(t) ~= "table" or t.class ~= class then return end
  local id = Core.classSpecs[class] and Core.classSpecs[class][tonumber(t.tree) or 0]
  if id then return id, t end
end

-- The game draws a scoreboard spec in the row, secret or not: Retail
-- shows it mid-match without letting addons read it.
local function GameShows(e)
  local spec = e.specLive
  if spec == nil then return false end
  if Core.plain(spec) then return spec ~= "" end
  return true
end

-- Whether the panel may offer the picker: the game hasn't identified it.
function Core.SpecTaggable(e)
  return e ~= nil and not Core.SPEC_TAG_STRONG[e.specSrc] and not GameShows(e)
    and Core.classSpecs[e.class] ~= nil and #Core.classSpecs[e.class] > 0
end

-- Put a tag on the enemy unless stronger evidence holds; a removed tag
-- gives back what the enemy had before it (history, an estimate or nothing).
function Core.ApplySpecTag(e)
  if not e or Core.SPEC_TAG_STRONG[e.specSrc] then return end
  local id, t
  if not GameShows(e) then id, t = Core.SpecTag(e.key, e.class) end
  if id then
    if e.specSrc ~= "tag" then e.beforeTag = { e.specID, e.specSrc, e.specReason } end
    e.specID, e.specSrc, e.specReason, e.specBy = id, "tag", nil, t.by
  elseif e.specSrc == "tag" then
    local b = e.beforeTag
    e.specID, e.specSrc, e.specReason = b and b[1], b and b[2], b and b[3]
    e.beforeTag, e.specBy = nil, nil
  end
end

local function Send(text)
  local chan = ns.IsActive() and Core.db and Core.ShareOn() and Comms.GroupChannel()
  if not chan then return nil end
  if Comms.Blocked() then return false end
  return Comms.Send(Core.SPEC_TAG_PREFIX, text, chan) and true or false
end

local function Retry()
  if waiting or not (C_Timer and C_Timer.After) then return end
  waiting = true
  C_Timer.After(Core.SPEC_TAG_RETRY, function()
    waiting = false
    if not ns.IsActive() then wipe(pending); requesting = false; return end
    if requesting then Core.RequestSpecTags() end
    if next(pending) then Core.ShareSpecTags() end
  end)
end

-- Send every pending tag that still names a current enemy; refused ones
-- wait and are tried again while the match lasts.
function Core.ShareSpecTags()
  local parts, keys, len = {}, {}, 2
  local function flush()
    if #parts == 0 then return true end
    local sent = Send("1:" .. table.concat(parts, ";"))
    if sent then for _, key in ipairs(keys) do pending[key] = nil end end
    parts, keys, len = {}, {}, 2
    return sent
  end
  for key in pairs(pending) do
    local e = Core.enemies[key]
    if not e then
      pending[key] = nil
    else
      local _, t = Core.SpecTag(key, e.class)
      local tok = string.format("%s,%s,%d", key, e.class, t and tonumber(t.tree) or 0)
      if len + #tok + 1 > 250 and flush() == nil then break end
      parts[#parts + 1], keys[#keys + 1], len = tok, key, len + #tok + 1
    end
  end
  local sent = flush()
  if sent == nil then wipe(pending) end -- nobody to tell
  if next(pending) then Retry() end
end

-- Arriving in a match (or after /reload): ask teammates for their tags.
function Core.RequestSpecTags()
  if Core.testMode then return end
  local sent = Send("R")
  requesting = sent == false -- refused for now; nil: nobody to ask
  if requesting then Retry() end
end

-- Your own tags on this match's enemies again, for teammates who joined or
-- reloaded: at most once per SPEC_TAG_RESEND seconds, the last request of
-- a burst answered at the end of the wait. Teammates' tags are theirs to send.
Core.SPEC_TAG_RESEND = 10
local resendAt, resendDue = -math.huge, false
function Core.ResendSpecTags()
  if not ns.IsActive() then return end
  local wait = resendAt + Core.SPEC_TAG_RESEND - GetTime()
  if wait > 0 then
    if not resendDue and C_Timer and C_Timer.After then
      resendDue = true
      C_Timer.After(wait, function()
        resendDue = false
        Core.ResendSpecTags()
      end)
    end
    return
  end
  resendAt = GetTime()
  for key, e in pairs(Core.enemies) do
    local _, t = Core.SpecTag(key, e.class)
    if t and t.by == nil then pending[key] = true end
  end
  if next(pending) then Core.ShareSpecTags() end
end

-- The player tags (tree) or untags (nil, or the tree already tagged) an enemy.
function Core.SetSpecTag(e, tree)
  if not (e and e.key and Core.classSpecs[e.class]) then return false end
  local store = Store()
  local current = Core.SpecTag(e.key, e.class)
  local id = tree and Core.classSpecs[e.class][tree]
  if not id or id == current then
    store[e.key] = nil
  else
    store[e.key] = { class = e.class, tree = tree, t = time() }
  end
  Core.ApplySpecTag(e)
  if not Core.testMode then
    pending[e.key] = true
    Core.ShareSpecTags()
  end
  if Core.Render then Core.Render() end
  return true
end

-- A tag for an enemy the scoreboard hasn't listed: kept for this match.
local function Hold(key, class, tree, by)
  local held = early[key]
  if not held then
    if earlyCount >= Core.EARLY_SPEC_TAGS_MAX then return end
    held, earlyCount = {}, earlyCount + 1
    early[key] = held
  end
  held.class, held.tree, held.by, held.match = class, tree, by, ns.MatchSerial
end

-- The roster lists e: take a teammate's tag that arrived before it did.
function Core.TakeEarlySpecTag(e)
  local held = e and early[e.key]
  if not held then return end
  early[e.key], earlyCount = nil, earlyCount - 1
  local specs = held.match == ns.MatchSerial and e.class == held.class and Core.classSpecs[held.class]
  if not (specs and (held.tree == 0 or specs[held.tree])) then return end
  Store()[e.key] = held.tree > 0 and { class = held.class, tree = held.tree, t = time(), by = held.by } or nil
  Core.ApplySpecTag(e)
end

function Core.ClearEarlySpecTags()
  wipe(early)
  earlyCount = 0
end

function Core.ReceiveSpecTags(text, sender)
  if not ns.IsActive() or not Core.On("intelShare") then return end
  local short = type(sender) == "string" and sender:match("^[^-]+")
  if not short or Core.IsMe(sender) then return end
  if text == "R" then return Core.ResendSpecTags() end
  local body = text:match("^1:(.+)$")
  if not body then return end
  local store, changed = Store(), false
  for tok in body:gmatch("[^;]+") do
    local key, class, tree = tok:match("^([^,]+),(%u+),(%d+)$")
    tree = tonumber(tree)
    local e = key and Core.enemies[key]
    local specs = e and e.class == class and Core.classSpecs[class]
    if specs and (tree == 0 or specs[tree]) then
      store[key] = tree > 0 and { class = class, tree = tree, t = time(), by = short } or nil
      Core.ApplySpecTag(e)
      changed = true
    elseif key and not e and Core.classSpecs[class] and (tree == 0 or Core.classSpecs[class][tree]) then
      Hold(key, class, tree, short)
    end
  end
  if changed and Core.Render then Core.Render() end
end

Comms.Listen(Core.SPEC_TAG_PREFIX, function(text, channel, sender)
  if Comms.FromGroup(channel) then Core.ReceiveSpecTags(text, sender) end
end, "spectags", "battlegrounds")

-- A bigger group may hold players who never heard your tags.
local members = 0
ns.Util.Events({
  GROUP_ROSTER_UPDATE = function()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if n > members and ns.IsActive() then Core.ResendSpecTags() end
    members = n
  end,
}, "spectags", "battlegrounds")
