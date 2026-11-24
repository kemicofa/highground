local _, ns = ...
local Probe, Secret = ns.Probe, ns.Secret

---------------------------------------------------------------------------
-- /hgprobe world: one snapshot of what addons can read about an enemy
-- player, taken in one frame with whether you are in combat and in an
-- instance, to compare the open world in and out of combat with a match.
-- Restriction state; identity, health, auras and raid icon on the target,
-- party1 and enemy players' nameplates; group positions. A listener counts
-- PARTY_KILL and UNIT_DEATH and whether their arguments were secret.
-- Secret values are only described, never saved.
---------------------------------------------------------------------------
local World = {}
ns.World = World

local MAX_PLATES, MAX_ARGS = 3, 8
local IDENTITY = { "UnitGUID", "UnitClass", "UnitRace", "UnitLevel", "GetGuildInfo", "UnitHealth", "UnitHealthMax",
  "UnitHealthPercent" }
local AURA_FILTERS = { "HELPFUL", "HARMFUL" }
local KILL_EVENTS = { "PARTY_KILL", "UNIT_DEATH" }

-- "C_Map.GetBestMapForUnit" -> the client's function, nil when absent.
local function Resolve(path)
  local value = _G
  for part in path:gmatch("[^.]+") do
    if type(value) ~= "table" then return nil end
    value = value[part]
  end
  return type(value) == "function" and value or nil
end

-- Calls path(...) and appends the described result as `label`.
local function Add(snapshot, label, path, ...)
  local fn = Resolve(path)
  local record = fn and Probe.Invoke(fn, ...) or { missing = true }
  record.call = label
  snapshot.reads[#snapshot.reads + 1] = record
  local plain, secret = Probe.Count(record)
  snapshot.plain, snapshot.secret = snapshot.plain + plain, snapshot.secret + secret
  if record.ok == false then snapshot.errors = snapshot.errors + 1 end
  if record.missing then snapshot.missing = snapshot.missing + 1 end
end

-- Chat lockdown, addon-message restriction and each Enum.AddOnRestrictionType.
local function Restrictions(snapshot)
  Add(snapshot, "C_ChatInfo.InChatMessagingLockdown()", "C_ChatInfo.InChatMessagingLockdown")
  Add(snapshot, "C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()",
    "C_ChatInfo.AreOutgoingAddonChatMessagesRestricted")
  local types = type(Enum) == "table" and Enum.AddOnRestrictionType
  local names = {}
  for name, value in pairs(type(types) == "table" and types or {}) do
    if type(name) == "string" and type(value) == "number" and not Secret(value) then names[#names + 1] = name end
  end
  if #names == 0 then
    Add(snapshot, "Enum.AddOnRestrictionType", "Enum.AddOnRestrictionType")
    return
  end
  table.sort(names, function(a, b) return types[a] < types[b] end)
  for _, name in ipairs(names) do
    Add(snapshot, "C_RestrictedActions.IsAddOnRestrictionActive(" .. name .. ")",
      "C_RestrictedActions.IsAddOnRestrictionActive", types[name])
  end
end

-- `key` names the unit in labels so snapshots line up: target, party1,
-- nameplate#1 (whichever nameplate token that was).
local function UnitReads(snapshot, key, unit, enemy)
  for _, path in ipairs(IDENTITY) do Add(snapshot, path .. "(" .. key .. ")", path, unit) end
  for _, filter in ipairs(AURA_FILTERS) do
    Add(snapshot, "C_UnitAuras.GetAuraDataByIndex(" .. key .. ", 1, " .. filter .. ")",
      "C_UnitAuras.GetAuraDataByIndex", unit, 1, filter)
  end
  if enemy then
    Add(snapshot, "GetRaidTargetIndex(" .. key .. ")", "GetRaidTargetIndex", unit)
    Add(snapshot, "UnitIsUnit(" .. key .. "target, player)", "UnitIsUnit", unit .. "target", "player")
  end
end

local function Positions(snapshot)
  Add(snapshot, "C_Map.GetBestMapForUnit(player)", "C_Map.GetBestMapForUnit", "player")
  local getMap, map = Resolve("C_Map.GetBestMapForUnit")
  if getMap then
    local ok, value = pcall(getMap, "player")
    map = ok and value or nil
  end
  for _, unit in ipairs({ "player", "party1", "raid1" }) do
    Add(snapshot, "C_Map.GetPlayerMapPosition(map, " .. unit .. ")", "C_Map.GetPlayerMapPosition", map, unit)
  end
  for _, unit in ipairs({ "player", "party1" }) do Add(snapshot, "UnitPosition(" .. unit .. ")", "UnitPosition", unit) end
end

-- Up to MAX_PLATES enemy players' nameplates other than the target's. A
-- secret answer counts as a match: inside a match it can't be compared.
local function EnemyPlates()
  local found, Read = {}, Probe.Read
  for i = 1, 40 do
    local unit = "nameplate" .. i
    local player, enemy = Read(UnitIsPlayer, unit), Read(UnitCanAttack, "player", unit)
    if Read(UnitExists, unit) == true and (player == true or player == "secret")
        and (enemy == true or enemy == "secret") and Read(UnitIsUnit, unit, "target") ~= true then
      found[#found + 1] = unit
      if #found == MAX_PLATES then break end
    end
  end
  return found
end

local function Where(inInstance, kind)
  if inInstance == true then return tostring(kind) end
  return inInstance == false and "world" or "?"
end

function World.Snapshot()
  local plates = EnemyPlates()
  local context = Probe.Context("target")
  context.affecting = Probe.Read(UnitAffectingCombat, "player")
  context.group = Probe.Read(GetNumGroupMembers)
  context.nameplates = plates
  context.events = {}
  for event, registered in pairs(World.events) do context.events[event] = registered end
  local snapshot = { context = context, reads = {}, plain = 0, secret = 0, errors = 0, missing = 0 }
  Restrictions(snapshot)
  UnitReads(snapshot, "target", "target", true)
  UnitReads(snapshot, "party1", "party1", false)
  for i, unit in ipairs(plates) do UnitReads(snapshot, "nameplate#" .. i, unit, true) end
  Positions(snapshot)
  local world = HighgroundApiProbeDB.world
  world[#world + 1] = snapshot
  Probe.Say(string.format("world snapshot %d (%s, %s, %d enemy nameplates): %d reads, %d readable, %d secret, "
    .. "%d errors. Type /reload to save.", #world, Where(context.inInstance, context.instanceType),
    context.combat == true and "in combat" or "out of combat", #plates, #snapshot.reads, snapshot.plain,
    snapshot.secret, snapshot.errors))
end

-- Prints snapshots and kill counts; true when there were any.
function World.Summary()
  local db, any = HighgroundApiProbeDB, false
  for index, snapshot in ipairs(db.world) do
    local c = snapshot.context or {}
    Probe.Say(string.format("world %d %s %s, %s: %d readable, %d secret, %d errors.", index, tostring(c.date),
      Where(c.inInstance, c.instanceType), c.combat == true and "in combat" or "out of combat", snapshot.plain or 0,
      snapshot.secret or 0, snapshot.errors or 0))
    any = true
  end
  for _, event in ipairs(KILL_EVENTS) do
    for where, bucket in pairs(db.kills[event] or {}) do
      Probe.Say(string.format("%s %s: %d, %d with secret arguments.", event, where, bucket.n, bucket.secret))
      any = true
    end
  end
  return any
end

-- Per event and place: count, how many had a secret argument, how many came
-- in combat, and the last one's arguments described.
local function OnKill(_, event, ...)
  local db = HighgroundApiProbeDB
  if type(db) ~= "table" or type(db.kills) ~= "table" then return end
  local okInstance, inInstance, kind = pcall(IsInInstance)
  local where = okInstance and Where(inInstance, kind) or "?"
  local places = db.kills[event] or {}
  db.kills[event] = places
  local bucket = places[where] or { n = 0, secret = 0, plain = 0, combat = 0 }
  places[where] = bucket
  local args, secret = {}, false
  for i = 1, math.min(select("#", ...), MAX_ARGS) do
    args[i] = Probe.Describe((select(i, ...)), true)
    secret = secret or args[i].s == true
  end
  bucket.n, bucket.last = bucket.n + 1, args
  if secret then bucket.secret = bucket.secret + 1 else bucket.plain = bucket.plain + 1 end
  if Probe.Read(InCombatLockdown) == true then bucket.combat = bucket.combat + 1 end
end

-- Events this client doesn't know raise an error on registration.
World.events = {}
local listener = CreateFrame("Frame")
for _, event in ipairs(KILL_EVENTS) do
  local ok, registered = pcall(listener.RegisterEvent, listener, event)
  World.events[event] = ok and registered ~= false
end
listener:SetScript("OnEvent", OnKill)
