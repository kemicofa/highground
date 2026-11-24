local _, ns = ...
local Core = ns.Core
local Read, Call = ns.Util.read, ns.Util.call

---------------------------------------------------------------------------
-- Team healers: which teammates get the green healer cross.
-- Retail's group roles name healers. WoW Forever gives every teammate the
-- DAMAGER role, so Highground inspects teammates whose class can heal and
-- reads their talent points (ns.Caps.inspectTalents). You can mark or
-- unmark anyone by hand: a key binding, /hg healer or the Team healers
-- window. A hand mark beats an inspect. Marks are kept per region like spec
-- tags, so a known healer is marked from the start of the next match. They
-- stay on this client: Forever drops addon messages during a match.
--   healerTags[key] = { healer = bool, by = "hand"|"inspect", spec = specID, t = time() }
---------------------------------------------------------------------------
Core.INSPECT_GAP = 1.5 -- seconds between inspect requests
Core.INSPECT_WAIT = 4 -- seconds before an unanswered request counts as failed
Core.INSPECT_RETRY = 10 -- seconds before a failed teammate is asked again

local previewTags = {} -- sample marks while a preview or guide runs
local function Store()
  if Core.testMode then return previewTags end
  return ns.Scope.Saved("healerTags", "social")
end

local healersAt -- when Core.TeamHealers last read the group

function Core.ClearPreviewHealerTags() wipe(previewTags); healersAt = nil end

-- Whether a class has a healing spec; nil until the spec catalog is built.
local healerClass = {}
function Core.HealerClass(class)
  if healerClass[class] == nil and Core.classSpecs[class] then
    local can = false
    for _, id in ipairs(Core.classSpecs[class]) do
      if Core.IsHealer({ specID = id }) then can = true end
    end
    healerClass[class] = can
  end
  return healerClass[class] == true
end

-- A teammate's saved mark: { healer, by, spec, t } or nil.
function Core.HealerTag(key)
  local t = key and Store()[key]
  if type(t) == "table" then return t end
end

-- Player keys of group tokens, kept until the roster or a name changes:
-- the healer markers ask for every teammate each tick.
local keys = {}
function Core.TeamKey(unit)
  local key = keys[unit]
  if not key then
    key = Core.CanonUnit(unit)
    keys[unit] = key
  end
  return key
end

-- Whether a friendly unit is a healer, and how Highground knows: "role"
-- (the game's group role), "hand", "inspect" or "self" (your talents).
-- key: the unit's player key when the caller has it.
function Core.TeamHealer(unit, key)
  if Read(UnitGroupRolesAssigned, unit) == "HEALER" then return true, "role" end
  key = key or Core.CanonUnit(unit)
  local t = Core.HealerTag(key)
  if t then return t.healer == true, t.by end
  if key and key == Core.TeamKey("player") then
    return Core.me.specID ~= nil and Core.IsHealer(Core.me), "self"
  end
  return false
end

-- Your group's unit tokens, you included once.
local RAID, PARTY = ns.Util.UnitTokens("raid", 40), ns.Util.UnitTokens("party", 4)
function Core.TeamUnits(out)
  out = out or {}
  wipe(out)
  local n = Read(GetNumGroupMembers) or 0
  if Read(IsInRaid) == true then
    for i = 1, math.min(#RAID, n) do out[#out + 1] = RAID[i] end
  else
    out[1] = "player"
    for i = 1, math.min(#PARTY, math.max(0, n - 1)) do out[#out + 1] = PARTY[i] end
  end
  return out
end

-- Teammates who heal, by player key and by group token. Read once per tick
-- for the healer marks and the enemy scan, and again after a mark changes.
local healerKeys, healerUnits, healerTeam = {}, {}, {}
function Core.TeamHealers()
  local now = GetTime()
  if healersAt ~= now then
    healersAt = now
    wipe(healerKeys); wipe(healerUnits)
    for _, unit in ipairs(Core.TeamUnits(healerTeam)) do
      local key = Core.TeamKey(unit)
      if Core.TeamHealer(unit, key) then
        if key then healerKeys[key] = true end
        healerUnits[unit] = true
      end
    end
  end
  return healerKeys, healerUnits
end

local function UnitClassToken(unit)
  local _, class = Call(UnitClass, unit)
  if Core.plain(class) then return class end
end

local scratch = {}
-- The group unit of a teammate named in full or by first name.
function Core.TeamUnitByName(name)
  local want = type(name) == "string" and name:lower()
  if not want or want == "" then return end
  for _, unit in ipairs(Core.TeamUnits(scratch)) do
    for _, known in ipairs({ Core.FullUnitName(unit), Read(GetUnitName, unit, false), (Read(UnitName, unit)) }) do
      if type(known) == "string" and known:lower() == want then return unit end
    end
  end
end

local function Changed()
  healersAt = nil
  if Core.UpdateHealerMarks then Core.UpdateHealerMarks() end
  if Core.RefreshTeamHealers then Core.RefreshTeamHealers() end
end

-- Mark (true), unmark (false) or flip (nil) a teammate by hand. Returns the
-- new state, else nil and why: "unit" (not a friendly player) or "class"
-- (the class has no healing spec).
function Core.SetTeamHealer(unit, on)
  local key = Core.CanonUnit(unit)
  if not key or Read(UnitIsPlayer, unit) ~= true or Read(UnitIsFriend, "player", unit) ~= true then return nil, "unit" end
  if not Core.HealerClass(UnitClassToken(unit)) then return nil, "class" end
  if on == nil then on = not Core.TeamHealer(unit) end
  local old = Core.HealerTag(key)
  Store()[key] = { healer = on, by = "hand", spec = old and old.spec, t = time() }
  Changed()
  return on
end

-- The key binding and /hg healer without a name: the teammate under the
-- mouse, else your target. Says what changed.
function Core.ToggleHoveredHealer(say)
  say = say or ns.Util.Say
  local unit = Read(UnitExists, "mouseover") and Read(UnitIsPlayer, "mouseover") and "mouseover" or "target"
  return Core.ToggleTeamHealer(unit, say)
end

function Core.ToggleTeamHealer(unit, say)
  say = say or ns.Util.Say
  local on, why = Core.SetTeamHealer(unit)
  local name = Core.DisplayName(Core.FullUnitName(unit))
  if name == "" then name = nil end
  if on == nil then
    say(why == "class" and ns.Locale:Format("highground.healertags.name_s_class_has_no_healing_spec.0f70ee", { name = name or "?" })
      or ns.Locale:Get("highground.healertags.hover_over_or_target_a_teammate_first.4cd28c"))
  else
    say(ns.Locale:Format(on and "highground.healertags.name_is_marked_as_a_healer.047962" or "highground.healertags.name_is_no_longer_marked_as_a.383cb2", { name = name or "?" }))
  end
  return on
end

Highground_TeamHealer = function() Core.ToggleHoveredHealer() end
ns.Localization.Define(_G, { BINDING_NAME_HIGHGROUND_TEAM_HEALER = "highground.healertags.mark_or_unmark_the_teammate_under_your.107b21" })

---------------------------------------------------------------------------
-- Inspecting teammates (WoW Forever). One request at a time, spaced out;
-- a teammate out of range doesn't answer and is asked again later. Each
-- teammate is inspected once a match. Never while your Inspect window is
-- open, so it keeps the player you chose.
---------------------------------------------------------------------------
local seen = {} -- [key] = true: inspected this match
local failed = {} -- [key] = GetTime() of the last unanswered request
local pending -- { key, guid, class, at }
local nextAt = 0
local units = {}

local function InspectOpen()
  return InspectFrame ~= nil and InspectFrame:IsShown()
end

function Core.InspectOn()
  return ns.Caps.inspectTalents and not Core.testMode and Core.db ~= nil
    and Core.On("healerMarks") and Core.On("healerInspect")
end

function Core.InspectTeam()
  if not Core.InspectOn() or type(NotifyInspect) ~= "function" then return end
  local now = GetTime()
  if pending then
    if now - pending.at < Core.INSPECT_WAIT then return end
    failed[pending.key], pending = now, nil
  end
  if now < nextAt or InspectOpen() then return end
  local store = Store()
  for _, unit in ipairs(Core.TeamUnits(units)) do
    local key = Core.TeamKey(unit)
    if key == Core.TeamKey("player") then key = nil end
    local t = key and store[key]
    if key and not seen[key] and not (type(t) == "table" and t.by == "hand")
      and now - (failed[key] or -Core.INSPECT_RETRY) >= Core.INSPECT_RETRY then
      local class = UnitClassToken(unit)
      if Core.HealerClass(class) and Read(UnitIsConnected, unit) ~= false
        and Read(CanInspect, unit) == true and Read(UnitIsVisible, unit) ~= false then
        -- Forever hides enemy GUIDs; without a teammate's, the next answer counts.
        pending, nextAt = { key = key, guid = Read(UnitGUID, unit), class = class, at = now }, now + Core.INSPECT_GAP
        Call(NotifyInspect, unit)
        return
      end
    end
  end
end

-- An inspect answered: the tree with the most points names the teammate.
-- No points spent leaves what was known; a hand mark is never replaced.
function Core.InspectReady(guid)
  local p = pending
  if not p or p.guid and (not Core.plain(guid) or guid ~= p.guid) then return end
  pending = nil
  local tree = Core.SpentTree(p.class, ns.Api.InspectTalentTreePoints())
  if not InspectOpen() then Call(ClearInspectPlayer) end
  if tree == nil then failed[p.key] = GetTime(); return end
  seen[p.key] = true
  local store, old = Store(), Core.HealerTag(p.key)
  local spec = tree and Core.classSpecs[p.class] and Core.classSpecs[p.class][tree]
  if not spec or (old and old.by == "hand") then return end
  store[p.key] = { healer = Core.IsHealer({ specID = spec }), by = "inspect", spec = spec, t = time() }
  Changed()
end

-- A new zone is a new match: everyone is inspected again.
function Core.ResetTeamInspect()
  wipe(seen); wipe(failed)
  pending, nextAt = nil, 0
end

ns.Util.Events({
  INSPECT_READY = function(_, guid) Core.InspectReady(guid) end,
  PLAYER_ENTERING_WORLD = function() wipe(keys); Core.ResetTeamInspect() end,
  UNIT_NAME_UPDATE = function() wipe(keys) end,
  GROUP_ROSTER_UPDATE = function()
    wipe(keys)
    if Core.RefreshTeamHealers then Core.RefreshTeamHealers() end
  end,
}, "team healers", "battlegrounds")
