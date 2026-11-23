-- Diagnostic commands (commands/Diagnostics.lua, core/Diagnostics.lua):
-- /hg probe, kit, err, perf, map and help output.
-- Run from addons/Highground: luajit tests/commands_diagnostics_test.lua
local t = dofile("../../tools/harness.lua")("diagnostic commands")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local C = dofile("tests/support/commands.lua")
local equal, run, has = t.equal, C.run, C.has

-- Calls a handler directly: the simulator fails any action while errors
-- are recorded, and /hg err exists to print them.
local function direct(sim, name, arg)
  local lines = {}
  sim.ns.Commands[name](arg or "", name, function(text) lines[#lines + 1] = C.Plain(text) end)
  return table.concat(lines, "\n")
end

t.test("/hg probe labels secret values, tables and failed reads and saves the report", function()
  local sim = new("retail", {})
  local secret = { secret = true }
  local enemy = sim:enemy("Probed", { health = secret, maxHealth = secret })
  sim:join()
  sim.units.target = enemy
  sim.env.UnitHealthPercent = function() return secret end
  sim.env.C_ChatInfo = { InChatMessagingLockdown = function() return true end }
  sim.env.C_UnitAuras.GetUnitAuras = function(_, filter)
    if filter:find("CROWD_CONTROL", 1, true) then error("blocked read") end
    return { {}, {} }
  end
  local out = run(sim, "probe")
  assert(has(out, "UnitHealthPercent = SECRET"), "secret percentage")
  assert(has(out, "UnitHealthMax = SECRET"), "secret maximum")
  assert(has(out, "BIG_DEFENSIVE auras = table#2"), "table length")
  assert(has(out, "CROWD_CONTROL auras = ERROR ") and has(out, "blocked read"), "failed read named")
  assert(has(out, "InChatMessagingLockdown = true"), "chat lockdown where the API exists")
  assert(has(out, "CanonUnit / in roster = Probed-Realm, true"), "roster lookup")
  local saved = sim.env.HighgroundDB.lastProbe
  local found
  for _, line in ipairs(saved.lines) do if line == "UnitHealthPercent = SECRET" then found = true end end
  assert(found, "saved lines are plain text")
  out = run(new("cata", {}), "probe")
  assert(has(out, "no target: target an enemy player"), "unit checks need a target")
  assert(not has(out, "InChatMessagingLockdown"), "no lockdown line without the API")
end)

t.test("/hg kit needs a target and the combat log", function()
  local retail = new("retail", {})
  assert(has(run(retail, "kit"), "target an enemy (or have a kill target) first"), "no target")
  retail:enemy("Kitted")
  retail:join()
  assert(has(run(retail, "kit"), "needs the combat log (Cata Classic only)"), "Retail explains")
  local cata = new("cata", {})
  cata:enemy("Kitted", { classID = 8 })
  cata:join()
  local out = run(cata, "kit")
  assert(has(out, "Kitted (") and has(out, " MAGE)"), "kill target named: " .. out)
  assert(has(out, "not observed"), "cooldowns listed")
end)

t.test("/hg err lists recorded errors, health errors and counters; clearerr empties them", function()
  local sim = new("cata", {})
  sim:enemy("Enemy")
  sim:join()
  local out = run(sim, "err")
  assert(has(out, "no errors recorded"), "clean start")
  assert(has(out, "roster: ok | active=true enemies=1"), "roster line")
  local db = sim.env.HighgroundDB
  db.errors = { ["render: boom"] = { count = 3, first = "10:00", trace = "trace" } }
  db.healthErr = "bar rejected"
  db.apiMissing = { "C_PvP.GetScoreInfo" }
  out = direct(sim, "err")
  assert(has(out, "missing on this client: C_PvP.GetScoreInfo"), "missing APIs")
  assert(has(out, "render: boom x3 (since 10:00)"), "error with count and first time")
  assert(has(out, "full traces saved"), "where traces are")
  assert(has(out, "health error: bar rejected"), "health error")
  assert(has(out, "health: "), "live counters")
  db.healthErr, db.apiMissing = nil, nil
  direct(sim, "clearerr")
  equal(next(db.errors or {}), nil, "errors cleared")
end)

t.test("/hg perf explains its words and stopping without a capture", function()
  local sim = new("cata", {})
  local out = run(sim, "perf later")
  assert(has(out, "/hg perf start: capture 60 seconds"), "usage")
  out = run(sim, "perf stop")
  assert(has(out, "No performance capture is running."), "nothing to stop")
  out = run(sim, "perf")
  assert(has(out, "Use /hg perf start"), "no report yet")
end)

t.test("/hg bg profiler start and stop explain waiting, recording and saving", function()
  local sim = new("retail", {})
  assert(has(run(sim, "bg profiler stop"), "The battleground profiler is not on."), "nothing to stop")
  assert(has(run(sim, "bg profiler start"), "recording starts when you enter a battleground"), "waits outside")
  assert(has(run(sim, "bg profiler start"), "/hg bg profiler stop ends it"), "already on")
  assert(has(run(sim, "bg profiler stop"), "Nothing was recorded."), "stopped before a battleground")
  sim:join()
  assert(has(run(sim, "bg profiler start"), "It stops when you leave the battleground."), "records inside")
  sim:event("CHAT_MSG_BG_SYSTEM_NEUTRAL", "Let the battle begin!")
  local out = run(sim, "bg profiler stop")
  assert(out:find("stopped after %d+ events%. /reload saves them to SavedVariables%."), "count and reload: " .. out)
  assert(has(run(sim, "bg profiler"), "/hg bg profiler start, /hg bg profiler stop"), "usage names both")
end)

t.test("/hg map names the battleground weighting profile", function()
  local sim = new("cata", {})
  assert(has(run(sim, "map"), "no battleground profile for this map"), "outside a battleground")
  sim:enemy("Enemy")
  sim:join(1460, 489, "Warsong Gulch")
  local out = run(sim, "map")
  assert(has(out, "Warsong Gulch  uiMap=1460 instance=489"), "map and instance")
  assert(has(out, "profile: Warsong Gulch (CTF)") and has(out, "objective x1.5"), "weighting profile: " .. out)
end)

t.test("/hg help prints command syntax with its pipes intact", function()
  for _, client in ipairs({ "cata", "retail" }) do
    local out = run(new(client, {}), "help")
    assert(has(out, "/hg call s|i|raid|party|y"), client .. " call channels")
    assert(has(out, "/hg sniper place body|head|left|right|above"), client .. " placements")
    assert(has(out, "/hg points NAME VALUE|reset"), client .. " points reset")
  end
end)

t.finish("Diagnostic commands: " .. t.tests .. " tests")
