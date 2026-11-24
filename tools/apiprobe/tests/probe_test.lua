-- HighgroundApiProbe against a fake client: documentation flags, present vs
-- documented functions, the read-only filter, and secret values described
-- but never saved. Run from the repository root:
--   luajit tools/apiprobe/tests/probe_test.lua
local t = dofile("tools/harness.lua")("apiprobe")
local equal = t.equal
local ROOT = "tools/apiprobe/HighgroundApiProbe/"

local function client()
  local secret = { secret = true }
  local called, queue, printed, frames = {}, {}, {}, {}
  local function track(name, fn) return function(...) called[name] = { ... }; return fn(...) end end
  local methods = { Show = function() end, Hide = function() end, Mystery = function() end,
    CreateFontString = function(f) return f end, CreateTexture = function(f) return f end,
    RegisterEvent = function() end, UnregisterEvent = function() end,
    SetScript = function(f, name, fn) f.scripts[name] = fn end }
  local env = setmetatable({
    issecretvalue = function(v) return v == secret end,
    issecrettable = function() return false end,
    canaccesstable = function() return true end,
    print = function(text) printed[#printed + 1] = text end,
    date = function() return "2026-11-24 12:00:00" end,
    GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end,
    IsInInstance = function() return true, "pvp" end,
    GetRealZoneText = function() return "Darkspear Islands" end,
    InCombatLockdown = function() return false end,
    UnitExists = function() return true end,
    UnitCanAttack = function() return true end,
    UnitIsPlayer = function() return true end,
    C_ChatInfo = { InChatMessagingLockdown = function() return true end },
    C_Timer = { After = function(_, fn) queue[#queue + 1] = fn end },
    C_AddOns = { LoadAddOn = function() return true end },
    SlashCmdList = {},
    CreateFrame = function()
      frames[#frames + 1] = setmetatable({ scripts = {} }, { __index = methods })
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
  for _, file in ipairs({ "Catalog.lua", "Probe.lua" }) do
    local chunk = assert(loadfile(ROOT .. file))
    setfenv(chunk, env)("HighgroundApiProbe", ns)
  end
  return env, ns, { secret = secret, called = called, queue = queue, printed = printed, frames = frames }
end

-- Fire ADDON_LOADED on the loader frame Probe.lua made.
local function load(state)
  for _, frame in ipairs(state.frames) do
    if frame.scripts.OnEvent then frame.scripts.OnEvent(frame, "ADDON_LOADED", "HighgroundApiProbe") end
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
  local function scan(value, path)
    assert(value ~= state.secret, "secret saved at " .. path)
    if type(value) == "table" then
      for key, inner in pairs(value) do
        assert(key ~= state.secret, "secret key saved at " .. path)
        scan(inner, path .. "." .. tostring(key))
      end
    end
  end
  scan(env.HighgroundApiProbeDB, "HighgroundApiProbeDB")
  assert(state.printed[#state.printed]:find("/reload", 1, true), "reminds to reload")
  env.SlashCmdList.HGPROBE("summary")
  assert(state.printed[#state.printed]:find("enemy", 1, true), "summary lists the run")
  env.SlashCmdList.HGPROBE("unit bad-token!")
  assert(state.printed[#state.printed]:find("not a unit token", 1, true))
  env.SlashCmdList.HGPROBE("clear")
  equal(#env.HighgroundApiProbeDB.runs, 0, "runs cleared")
end)

t.finish("API probe: " .. t.tests .. " tests")
