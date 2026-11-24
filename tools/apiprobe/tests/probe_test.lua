-- HighgroundApiProbe against a fake client: documentation flags, present vs
-- documented functions, the read-only filter, the open-world snapshot, the
-- kill listener, and secret values described but never saved. Run from the
-- repository root:
--   luajit tools/apiprobe/tests/probe_test.lua
local t = dofile("tools/harness.lua")("apiprobe")
local equal = t.equal
local ROOT = "tools/apiprobe/HighgroundApiProbe/"

-- The client knows these events; registering another one raises an error.
local KNOWN_EVENTS = { ADDON_LOADED = true, PARTY_KILL = true }

local function client()
  local secret = { secret = true }
  local called, queue, printed, frames, isUnit = {}, {}, {}, {}, {}
  local state = { secret = secret, called = called, queue = queue, printed = printed, frames = frames, isUnit = isUnit,
    inInstance = true, kind = "pvp", combat = false }
  local function track(name, fn) return function(...) called[name] = { ... }; return fn(...) end end
  local methods = { Show = function() end, Hide = function() end, Mystery = function() end,
    CreateFontString = function(f) return f end, CreateTexture = function(f) return f end,
    RegisterEvent = function(f, event)
      if not KNOWN_EVENTS[event] then error('Attempt to register unknown event "' .. event .. '"') end
      f.events[event] = true
      return true
    end,
    UnregisterEvent = function(f, event) f.events[event] = nil end,
    SetScript = function(f, name, fn) f.scripts[name] = fn end }
  local env = setmetatable({
    issecretvalue = function(v) return v == secret end,
    issecrettable = function() return false end,
    canaccesstable = function() return true end,
    print = function(text) printed[#printed + 1] = text end,
    date = function() return "2026-11-24 12:00:00" end,
    GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end,
    IsInInstance = function() return state.inInstance, state.kind end,
    GetRealZoneText = function() return "Darkspear Islands" end,
    InCombatLockdown = function() return state.combat end,
    -- Nameplates 1-5: the target's, an enemy player, an NPC, an enemy whose
    -- hostility is secret, a friendly player.
    UnitExists = function(unit)
      local plate = unit:match("^nameplate(%d+)$")
      return not plate or tonumber(plate) <= 5
    end,
    UnitCanAttack = function(_, unit)
      if unit == "nameplate4" then return secret end
      return unit ~= "nameplate5"
    end,
    UnitIsPlayer = function(unit) return unit ~= "nameplate3" end,
    UnitIsUnit = function(a, b)
      isUnit[a] = b
      if a == "targettarget" then return secret end
      return a == "nameplate1" and b == "target"
    end,
    UnitAffectingCombat = function() return true end,
    GetNumGroupMembers = function() return 2 end,
    -- Open-world reads: the target's identity and health are secret, a
    -- party member's GUID is readable, the target's auras are refused.
    UnitGUID = function(unit) return unit == "party1" and "Player-1-0A" or secret end,
    UnitClass = function() return "Mage", "MAGE", 8 end,
    UnitRace = function() return secret end,
    UnitLevel = function() return 70 end,
    GetGuildInfo = function() return "Highground", "Member", 2 end,
    UnitHealthMax = function() return secret end,
    UnitHealthPercent = function() return secret end,
    GetRaidTargetIndex = function(unit) return unit == "target" and 8 or nil end,
    UnitPosition = function(unit) if unit == "player" then return 100, 200, 0, 0 end end,
    C_UnitAuras = { GetAuraDataByIndex = function(unit, _, filter)
      if unit == "target" then error("Auras cannot be accessed when secret while tainted") end
      if filter == "HELPFUL" then return { name = "Power Word: Fortitude", spellId = 21562, duration = secret } end
    end },
    Enum = { AddOnRestrictionType = { Map = 1, Combat = 0 } },
    C_RestrictedActions = { IsAddOnRestrictionActive = function(kind) return kind == 0 end },
    C_Map = { GetBestMapForUnit = function(unit) return unit == "player" and 1429 or nil end,
      GetPlayerMapPosition = function(map, unit)
        if map == 1429 and unit == "player" then return { x = 0.41, y = secret, GetXY = function() end } end
        return nil
      end },
    C_ChatInfo = { InChatMessagingLockdown = function() return true end },
    C_Timer = { After = function(_, fn) queue[#queue + 1] = fn end },
    C_AddOns = { LoadAddOn = function() return true end },
    SlashCmdList = {},
    CreateFrame = function()
      frames[#frames + 1] = setmetatable({ scripts = {}, events = {} }, { __index = methods })
      return frames[#frames]
    end,
  }, { __index = _G })
  -- The client: documented and undocumented unit reads, actions that must
  -- never run, a FrameXML helper and a function that errors.
  env.UnitHealth = track("UnitHealth", function() return secret end)
  env.UnitName = track("UnitName", function() return "Lunara", nil end)
  env.UnitMystery = track("UnitMystery", function() return 42 end)
  env.UnitBroken = track("UnitBroken", function() error("bad unit") end)
  env.GetOtherThing = track("GetOtherThing", function(index, unit) return index == nil and unit end)
  env.SetRaidTarget = track("SetRaidTarget", function() end)
  env.UnitPopup_ShowMenu = track("UnitPopup_ShowMenu", function() end)
  env.UnitSetRole = track("UnitSetRole", function() end)
  env.C_Test = { GetUnitThing = track("C_Test.GetUnitThing", function() return { a = 1, b = secret, [secret] = 2 } end),
    SetThing = track("C_Test.SetThing", function() end) }
  env.APIDocumentation = { systems = {
    { Name = "Unit", Type = "System", Functions = {
      { Name = "UnitHealth", SecretArguments = "AllowedWhenUntainted",
        Arguments = { { Name = "unit", Type = "UnitToken" } }, Returns = { { Name = "health", Type = "number", ConditionalSecret = true } } },
      { Name = "SetRaidTarget", Arguments = { { Name = "unit", Type = "UnitToken" } } },
      { Name = "GetOtherThing", Arguments = { { Name = "index", Type = "number" }, { Name = "unitToken", Type = "UnitToken" } } },
      { Name = "UnitRemovedLongAgo", Arguments = { { Name = "unit", Type = "UnitToken" } } },
    } },
    { Name = "Test", Type = "System", Namespace = "C_Test", Functions = {
      { Name = "GetUnitThing", Arguments = { { Name = "unit", Type = "UnitToken" } } },
    } },
    { Name = "SimpleFrameAPI", Type = "ScriptObject", Functions = { { Name = "Show" }, { Name = "Hide" } } },
  } }
  env._G = env -- the client's globals, as in WoW
  local ns = {}
  for _, file in ipairs({ "Catalog.lua", "Probe.lua", "World.lua" }) do
    local chunk = assert(loadfile(ROOT .. file))
    setfenv(chunk, env)("HighgroundApiProbe", ns)
  end
  return env, ns, state
end

-- Fire an event on every frame registered for it.
local function fire(state, event, ...)
  for _, frame in ipairs(state.frames) do
    if frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, ...) end
  end
end

local function load(state)
  fire(state, "ADDON_LOADED", "HighgroundApiProbe")
end

-- Fails when the secret (or a key made of it) was saved anywhere.
local function noSecrets(state, value, path)
  assert(value ~= state.secret, "secret saved at " .. path)
  if type(value) == "table" then
    for key, inner in pairs(value) do
      assert(key ~= state.secret, "secret key saved at " .. path)
      noSecrets(state, inner, path .. "." .. tostring(key))
    end
  end
end

local function drain(state)
  while #state.queue > 0 do table.remove(state.queue, 1)() end
end

local function contains(list, value)
  for _, v in ipairs(list) do if v == value then return true end end
  return false
end

t.test("list records documentation flags, undocumented and missing functions", function()
  local env, ns, state = client()
  load(state)
  env.SlashCmdList.HGPROBE("list")
  local list = env.HighgroundApiProbeDB.list
  assert(list.docsLoaded, "documentation loaded")
  local health = list.documented.UnitHealth
  equal(health.unit, 1, "unit argument position")
  equal(health.flags.SecretArguments, "AllowedWhenUntainted", "function flags kept verbatim")
  equal(health.returns["1"].ConditionalSecret, true, "return flags kept")
  equal(list.documented.GetOtherThing.unit, 2, "unit argument found by type")
  equal(list.documented["C_Test.GetUnitThing"].unit, 1, "namespaced functions by full name")
  assert(contains(list.undocumented, "UnitMystery") and not contains(list.undocumented, "UnitHealth"))
  assert(contains(list.missing, "UnitRemovedLongAgo"), "documented but absent")
  assert(contains(list.widgetUndocumented.Frame, "Mystery") and not contains(list.widgetUndocumented.Frame, "Show"))
  assert(ns.Catalog.ReadOnly("C_PvP.GetScoreInfo") and ns.Catalog.ReadOnly("UnitCastingInfo"))
  assert(not ns.Catalog.ReadOnly("UnitPopup_ShowMenu") and not ns.Catalog.ReadOnly("C_PartyInfo.LeaveParty"))
  assert(not ns.Catalog.ReadOnly("Issue") and not ns.Catalog.ReadOnly("GetAndSendReport"))
end)

t.test("unit run calls only read-only functions and never saves a secret", function()
  local env, _, state = client()
  load(state)
  env.SlashCmdList.HGPROBE("unit nameplate3")
  drain(state)
  for _, name in ipairs({ "SetRaidTarget", "UnitPopup_ShowMenu", "UnitSetRole", "C_Test.SetThing" }) do
    equal(state.called[name], nil, name .. " is an action and is never called")
  end
  equal(state.called.GetOtherThing[2], "nameplate3", "unit in its documented position")
  equal(state.called.GetOtherThing[1], nil, "other arguments stay nil")
  local run = env.HighgroundApiProbeDB.runs[1]
  equal(run.context.instanceType, "pvp", "instance type"); equal(run.context.lockdown, true, "chat lockdown")
  equal(run.context.enemy, true, "enemy unit"); equal(run.context.name, "Lunara", "unit name")
  local health = run.results.UnitHealth
  equal(health.r[1].s, true, "secret return described")
  equal(health.r[1].v, nil, "and not saved")
  equal(run.results.UnitMystery.r[1].v, 42, "readable undocumented read saved")
  equal(run.results.UnitMystery.doc, nil, "marked undocumented")
  assert(run.results.UnitBroken.err:find("bad unit", 1, true), "errors recorded")
  local thing = run.results["C_Test.GetUnitThing"].r[1]
  equal(thing.f.a.v, 1, "readable field"); equal(thing.f.b.s, true, "secret field")
  equal(thing.k, 3, "secret keys counted, not saved")
  equal(run.errors, 1, "one error")
  assert(run.plain >= 3 and run.secret >= 2, "counts")
  noSecrets(state, env.HighgroundApiProbeDB, "HighgroundApiProbeDB")
  assert(state.printed[#state.printed]:find("/reload", 1, true), "reminds to reload")
  env.SlashCmdList.HGPROBE("summary")
  assert(state.printed[#state.printed]:find("enemy", 1, true), "summary lists the run")
  env.SlashCmdList.HGPROBE("unit bad-token!")
  assert(state.printed[#state.printed]:find("not a unit token", 1, true))
  env.SlashCmdList.HGPROBE("clear")
  equal(#env.HighgroundApiProbeDB.runs, 0, "runs cleared")
end)

t.test("world snapshot records restrictions, units, nameplates and positions with the combat state", function()
  local env, _, state = client()
  load(state)
  state.inInstance, state.kind, state.combat = false, "none", true
  env.SlashCmdList.HGPROBE("world")
  local snapshot = env.HighgroundApiProbeDB.world[1]
  local c, reads = snapshot.context, {}
  for _, record in ipairs(snapshot.reads) do reads[record.call] = record end
  equal(c.inInstance, false, "outside instances"); equal(c.combat, true, "in combat"); equal(c.affecting, true, "affecting")
  equal(c.enemy, true, "target is an enemy"); equal(c.group, 2, "group size")
  equal(#c.nameplates, 2, "enemy players' nameplates other than the target")
  equal(c.nameplates[1], "nameplate2", "enemy player"); equal(c.nameplates[2], "nameplate4", "secret hostility counts")
  equal(snapshot.reads[1].call, "C_ChatInfo.InChatMessagingLockdown()", "restrictions first")
  equal(snapshot.reads[1].r[1].v, true, "chat lockdown")
  equal(reads["C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()"].missing, true, "absent function marked missing")
  equal(snapshot.reads[3].call, "C_RestrictedActions.IsAddOnRestrictionActive(Combat)", "restriction types by value")
  equal(snapshot.reads[3].r[1].v, true, "combat restriction active")
  equal(reads["C_RestrictedActions.IsAddOnRestrictionActive(Map)"].r[1].v, false, "map restriction inactive")
  equal(reads["UnitGUID(target)"].r[1].s, true, "secret identity described")
  equal(reads["UnitGUID(target)"].r[1].v, nil, "and not saved")
  equal(reads["UnitGUID(party1)"].r[1].v, "Player-1-0A", "readable GUID saved")
  equal(reads["GetGuildInfo(target)"].r[1].v, "Highground", "guild")
  equal(reads["UnitLevel(nameplate#2)"].r[1].v, 70, "nameplate reads")
  equal(reads["UnitGUID(nameplate#3)"], nil, "no third enemy nameplate")
  assert(reads["C_UnitAuras.GetAuraDataByIndex(target, 1, HARMFUL)"].err:find("tainted", 1, true), "refused auras")
  local aura = reads["C_UnitAuras.GetAuraDataByIndex(party1, 1, HELPFUL)"].r[1]
  equal(aura.f.spellId.v, 21562, "readable aura field"); equal(aura.f.duration.s, true, "secret aura field")
  equal(reads["GetRaidTargetIndex(target)"].r[1].v, 8, "raid icon")
  equal(reads["GetRaidTargetIndex(party1)"], nil, "raid icon and target read for enemies only")
  equal(reads["UnitIsUnit(targettarget, player)"].r[1].s, true, "secret comparison")
  equal(state.isUnit.nameplate4target, "player", "a nameplate's target by its real token")
  assert(reads["UnitIsUnit(nameplate#2target, player)"], "labelled by nameplate order")
  equal(reads["C_Map.GetBestMapForUnit(player)"].r[1].v, 1429, "map")
  local position = reads["C_Map.GetPlayerMapPosition(map, player)"].r[1]
  equal(position.f.x.v, 0.41, "map position with the player's map"); equal(position.f.y.s, true, "secret coordinate")
  equal(reads["C_Map.GetPlayerMapPosition(map, raid1)"].r[1].t, "nil", "no raid1")
  equal(reads["UnitPosition(player)"].r[1].v, 100, "world position")
  equal(snapshot.errors, 2, "two refused auras"); equal(snapshot.missing, 1, "one missing function")
  noSecrets(state, env.HighgroundApiProbeDB, "HighgroundApiProbeDB")
  assert(state.printed[#state.printed]:find("world, in combat", 1, true), "place and combat state")
end)

t.test("kill listener counts PARTY_KILL and UNIT_DEATH by place and whether their arguments are secret", function()
  local env, ns, state = client()
  load(state)
  equal(ns.World.events.PARTY_KILL, true, "registered")
  equal(ns.World.events.UNIT_DEATH, false, "an unknown event doesn't stop the addon")
  state.inInstance, state.kind = false, "none"
  fire(state, "PARTY_KILL", "Player-1-0A", "Player-1-0B")
  state.combat = true
  fire(state, "PARTY_KILL", "Player-1-0A", state.secret)
  state.inInstance, state.kind = true, "pvp"
  for _, frame in ipairs(state.frames) do
    if frame.events.PARTY_KILL then frame.scripts.OnEvent(frame, "UNIT_DEATH", state.secret) end
  end
  local kills = env.HighgroundApiProbeDB.kills
  local world = kills.PARTY_KILL.world
  equal(world.n, 2, "two in the world"); equal(world.plain, 1, "one readable"); equal(world.secret, 1, "one secret")
  equal(world.combat, 1, "one in combat")
  equal(world.last[1].v, "Player-1-0A", "readable GUID"); equal(world.last[2].s, true, "secret GUID described")
  equal(kills.UNIT_DEATH.pvp.n, 1, "by place"); equal(kills.UNIT_DEATH.pvp.secret, 1, "secret")
  noSecrets(state, env.HighgroundApiProbeDB, "HighgroundApiProbeDB")
  env.SlashCmdList.HGPROBE("world")
  equal(env.HighgroundApiProbeDB.world[1].context.events.UNIT_DEATH, false, "snapshot names unavailable events")
  env.SlashCmdList.HGPROBE("summary")
  local text = table.concat(state.printed, "\n")
  assert(text:find("PARTY_KILL world: 2, 1 with secret arguments.", 1, true), "summary counts kills")
  assert(text:find("world 1 2026-11-24 12:00:00 pvp, in combat", 1, true), "summary lists snapshots")
  env.SlashCmdList.HGPROBE("clear")
  equal(#env.HighgroundApiProbeDB.world, 0, "snapshots cleared"); equal(next(env.HighgroundApiProbeDB.kills), nil, "kills")
  env.SlashCmdList.HGPROBE("summary")
  assert(state.printed[#state.printed]:find("nothing recorded yet", 1, true))
end)

t.finish("API probe: " .. t.tests .. " tests")
