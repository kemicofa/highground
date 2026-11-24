-- Argument modes of the battleground display commands (commands/Display.lua):
-- saved state, invalid input, chat feedback and combat behavior.
-- Run from addons/Highground: luajit tests/commands_display_test.lua
local t = dofile("../../tools/harness.lua")("display commands")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local C = dofile("tests/support/commands.lua")
local equal, run, has = t.equal, C.run, C.has

t.test("/hg intel switches map positions and sharing separately and reports both", function()
  local sim = new("cata", {})
  local db = sim.env.HighgroundDB
  local out = run(sim, "intel off")
  equal(db.intel, false, "map positions saved off")
  assert(has(out, "intel map OFF, sharing with teammates on"), "status names both switches")
  out = run(sim, "intel share off")
  equal(db.intelShare, false, "sharing saved off")
  equal(db.intel, false, "map switch untouched")
  assert(has(out, "sharing with teammates OFF"), "sharing status")
  run(sim, "intel on"); run(sim, "intel share on")
  equal(db.intel, true, "map positions back on")
  equal(db.intelShare, true, "sharing back on")
  out = run(sim, "intel bogus")
  assert(has(out, "intel map on, sharing with teammates on"), "unknown words only print status")
  local again = new("cata", db)
  equal(again.ns.Core.On("intel"), true, "saved switch survives reload")
  again.ns.MapWhere = nil -- an update installed without a client restart
  out = run(again, "intel off")
  assert(has(out, "intel map not loaded"), "missing map module explained")
  equal(again.env.HighgroundDB.intel, true, "nothing changes without the map module")
end)

t.test("/hg timers on, off and reset change the switch and restore window positions", function()
  local sim = new("cata", {})
  local Core = sim.ns.Core
  local out = run(sim, "timers off")
  equal(sim.env.HighgroundDB.timers, false, "timers saved off")
  assert(has(out, "timers OFF | timers:"), "status follows the switch")
  run(sim, "timers on")
  equal(sim.env.HighgroundDB.timers, true, "timers saved on")
  sim:command("bg test"); sim:command("bg test") -- builds the windows
  local win = sim.ns.Timers.windows[1]
  Core.pos[win.key] = { "CENTER", "CENTER", 123, 45 }
  out = run(sim, "timers reset")
  equal(Core.pos[win.key], nil, "saved position forgotten")
  local point = win.points[#win.points]
  equal(point[1], win.def[1], "window back at its default anchor")
  equal(point[4], win.def[3], "default x offset")
  assert(has(out, "moved back to their default spots"), "reset confirmed")
end)

t.test("/hg call chooses the chat channel, keeps it on bad input and uses it for calls", function()
  local sim = new("cata", {})
  local db = sim.env.HighgroundDB
  local out = run(sim, "call raid")
  equal(db.callChannel, "raid", "channel saved")
  assert(has(out, "calls go to /raid "), "channel confirmed")
  out = run(sim, "call shout")
  equal(db.callChannel, "raid", "unknown channel ignored")
  assert(has(out, "= channel"), "usage printed")
  out = run(sim, "call")
  assert(has(out, "no kill target to call"), "nothing to call outside a match")
  sim:enemy("Caller")
  sim:join()
  run(sim, "call")
  assert(sim.chatDraft:find("^/raid {rt8} KILL Caller"), "call drafted in the chosen channel: " .. tostring(sim.chatDraft))
  equal(new("cata", db).ns.Core.db.callChannel, "raid", "channel survives reload")
end)

t.test("/hg mark sets the raid icon, ignores out-of-range icons and explains the button", function()
  local sim = new("cata", {})
  local db = sim.env.HighgroundDB
  local out = run(sim, "mark icon 3")
  equal(db.markIcon, 3, "icon saved")
  equal(db.markMode, "icon", "icon mode")
  assert(has(out, "raid icon diamond"), "icon named")
  for _, bad in ipairs({ "mark icon 0", "mark icon 9", "mark icon x" }) do
    out = run(sim, bad)
    equal(db.markIcon, 3, bad .. " keeps the icon")
    assert(has(out, "Now: raid icon diamond"), bad .. " prints the current mode")
  end
  out = run(sim, "mark")
  assert(has(out, "nothing"), "no kill target yet")
  sim:enemy("Marked")
  sim:join()
  out = run(sim, "mark")
  assert(has(out, "Button currently does: /targetexact Marked | /tm 3"), "button marks the kill target: " .. out)
end)

t.test("/hg mark ping changes the ping where pings exist and is refused elsewhere", function()
  local retail = new("retail", {})
  local db = retail.env.HighgroundDB
  local out = run(retail, "mark ping warning")
  equal(db.markMode, "ping", "ping mode")
  equal(db.pingType, "warning", "ping saved")
  assert(has(out, "warning ping"), "ping confirmed")
  out = run(retail, "mark ping bogus")
  equal(db.pingType, "warning", "unknown ping keeps the last one")
  retail:enemy("Pinged")
  retail:join()
  out = run(retail, "mark")
  assert(has(out, "/ping [@target] warning"), "button pings: " .. out)
  local cata = new("cata", {})
  out = run(cata, "mark ping attack")
  equal(cata.env.HighgroundDB.markMode, "icon", "no ping mode without pings")
  assert(has(out, "pings are not available"), "refusal explained: " .. out)
  out = run(cata, "mark")
  assert(not has(out, "mark ping"), "help omits pings on this client")
end)

-- WoW Forever: the retail manifest on interface 16001.
local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  s.env.loadstring_untainted = nil
  s.secureSnippets = false
end

t.test("WoW Forever refuses raid icons on enemies: the mark key pings and marker scores are hidden", function()
  local sim = new("retail", {}, forever)
  local ns, db = sim.ns, sim.env.HighgroundDB
  equal(ns.GAME, "forever", "Forever client")
  local out = run(sim, "mark icon 3")
  equal(db.markMode, "ping", "mode unchanged")
  equal(db.markIcon, 8, "icon unchanged")
  assert(has(out, "raid icons can't go on enemy players"), "refusal explained: " .. out)
  out = run(sim, "mark")
  assert(has(out, "/hg mark ping attack|warning|assist|onmyway"), "help offers pings")
  assert(not has(out, "/hg mark icon"), "help omits raid icons: " .. out)
  assert(not has(out, "Raid icons may need"), "no raid-icon note")
  local skull, cross, marker
  for _, row in ipairs(ns.Core.POINTS) do
    if row.key == "skull" then skull = row elseif row.key == "cross" then cross = row end
  end
  for _, w in ipairs(ns.Core.WEIGHTS) do if w.key == "marker" then marker = w end end
  assert(not ns.OptionAvailable(skull) and not ns.OptionAvailable(cross), "skull/cross values hidden")
  assert(not ns.OptionAvailable(marker), "marker multiplier hidden")

  -- A mark key saved on a raid icon pings again, on load and from a profile.
  local saved = new("retail", { markMode = "icon", markIcon = 3 }, forever)
  equal(saved.env.HighgroundDB.markMode, "ping", "saved raid icon resets to ping")
  saved:enemy("Pinged")
  saved:join()
  assert(has(run(saved, "mark"), "/ping [@target] attack"), "button pings")
  local setup = saved.ns.Options.Profiles.PrepareSetup({ preferences = { markMode = "icon", pingType = "warning" } })
  equal(setup.preferences.markMode, nil, "imported raid icon keeps the default")
  equal(setup.preferences.pingType, "warning", "other preferences import")

  -- Retail and Cata keep raid icons; Cata can't keep a ping mode.
  local retail = new("retail", { markMode = "icon", markIcon = 3 })
  equal(retail.env.HighgroundDB.markMode, "icon", "Retail keeps raid icons")
  assert(retail.ns.OptionAvailable(skull), "Retail shows the skull value")
  equal(new("cata", { markMode = "ping" }).env.HighgroundDB.markMode, "icon", "Cata has no pings")
end)

t.test("the battleground preview shows raid markers only where enemies can carry them", function()
  local function markers(sim)
    sim:command("bg test")
    local n = 0
    for _, e in pairs(sim.ns.Core.enemies) do if e.marker then n = n + 1 end end
    sim:command("bg test stop")
    return n
  end
  equal(markers(new("retail", {})), 2, "skull and cross samples on Retail")
  equal(markers(new("retail", {}, forever)), 0, "no samples on WoW Forever")
end)

t.test("/hg burst lists recent burst buffs with what each marker showed", function()
  local diag = {}
  for i = 1, 8 do
    diag[i] = { t = "12:00:0" .. i, who = "Lock" .. i .. "-Realm", name = "Demon Soul", mode = "cc", nameplate = "nameplate1",
      read = true, dispel = "Magic" }
  end
  diag[1].answer = "cc"
  diag[2].nameplate = nil
  diag[3].read = nil
  local sim = new("cata", { burstDiag = diag })
  local out = run(sim, "burst")
  assert(has(out, "enemy burst buffs seen: 8"), "count")
  assert(has(out, "Lock1 Demon Soul (cc): marker CC"), "realm dropped, answer shown")
  assert(has(out, "Lock2 Demon Soul (cc): no nameplate"), "nameplate missing")
  assert(has(out, "Lock3 Demon Soul (cc): buff not read"), "buff not read")
  assert(has(out, "Lock4 Demon Soul (cc): no marker (dispel Magic)"), "read without a marker")
  assert(has(out, "Lock6") and not has(out, "Lock7"), "six most recent only")
end)

t.test("/hg cap why reports learned spells, recent events and the target's cast", function()
  local sim = new("cata", { capSpells = { [21651] = { name = "Opening", secs = 7, own = true },
    [403] = { name = "Lightning Bolt", secs = 1.8 } } })
  local db = sim.env.HighgroundDB
  db.capLog = {}
  for i = 1, 5 do db.capLog[i] = { t = "12:0" .. i, who = "Capper-Realm", sub = "SPELL_CAST_START", spell = 21651 } end
  local out = run(sim, "cap")
  assert(has(out, "/hg cap why"), "no subcommand prints help")
  out = run(sim, "cap why")
  assert(has(out, "capture spells learned: Opening 7s"), "own capture spell listed")
  assert(not has(out, "Lightning Bolt"), "guessed combat spell not a capture")
  assert(has(out, "combat-log capture events seen: 5"), "event count")
  assert(has(out, "12:03 Capper-Realm") and not has(out, "12:04"), "three latest events")
  assert(has(out, "target the player who is capping"), "no target")
  sim.units.target = { name = "Teammate" }
  out = run(sim, "cap why")
  assert(has(out, "counts as a capture: false"), "not casting")
  assert(has(out, "not in the enemy roster"), "teammate")
  local enemy, token = sim:enemy("Capper")
  sim:join()
  sim.units.target = enemy
  local start = sim.now
  sim.env.UnitCastingInfo = function(unit)
    if unit == token or unit == "target" then return "Opening", nil, nil, start * 1000, (start + 7) * 1000, false, nil, false, 21651 end
  end
  sim:advance(1)
  out = run(sim, "cap why")
  assert(has(out, "target cast: Opening (spell 21651, 7.0s)"), "cast length read: " .. out)
  assert(has(out, "counts as a capture: true"), "learned capture")
  assert(has(out, "tracked capture: 6.0s left"), "tracked on the roster: " .. out)
  assert(has(out, "nameplate: " .. token .. " | nameplate bars on"), "plate and bars")
end)

t.test("/hg cap why shows a secret cast without reading it", function()
  local sim = new("retail", {})
  local secret = { secret = true } -- WoW Forever and Retail hide casts in a match
  sim.units.target = { name = "Somebody" }
  sim.env.UnitCastingInfo = function() return secret, nil, nil, secret, secret, false, nil, false, secret end
  local out = run(sim, "cap why")
  assert(has(out, "target cast: nil (spell nil, no timing)"), "no arithmetic on a secret: " .. out)
  assert(has(out, "counts as a capture: false"), "a secret cast is no capture")
  sim:assertHealthy()
end)

t.test("/hg cap probe needs the combat log and clear keeps learned spells", function()
  local retail = new("retail", {})
  local out = run(retail, "cap probe")
  assert(has(out, "needs the combat log"), "Retail explains the probe is unavailable")
  equal(retail.env.HighgroundDB.capProbeOn, nil, "probe stays off")
  local sim = new("cata", { capSpells = { [21651] = { name = "Opening", secs = 7, own = true } },
    capLog = { { t = "1", who = "x", sub = "y" } }, capDiag = { {} }, capProbe = { {}, {} } })
  out = run(sim, "cap probe")
  equal(sim.env.HighgroundDB.capProbeOn, true, "probe on")
  out = run(sim, "cap probe")
  equal(sim.env.HighgroundDB.capProbeOn, nil, "probe off")
  assert(has(out, "capture probe off"), "off confirmed")
  run(sim, "cap clear")
  local db = sim.env.HighgroundDB
  assert(db.capLog == nil and db.capDiag == nil and db.capProbe == nil, "diagnostics cleared")
  equal(db.capSpells[21651].secs, 7, "learned capture spell kept")
end)

t.test("/hg sniper rejects unknown colors, sounds and words with their choices", function()
  local sim = new("cata", {})
  local db = sim.env.HighgroundDB
  local before = db.sniperColor
  local out = run(sim, "sniper color teal")
  equal(db.sniperColor, before, "unknown preset ignored")
  assert(has(out, "cyan, gold, lime, magenta, orange, theme, white, yellow"), "sorted presets listed: " .. out)
  out = run(sim, "sniper color ring nothex")
  equal(db.sniperRingColor or "", "", "invalid hex ignored")
  out = run(sim, "sniper sound 0")
  equal(db.alerts.channels.lockon.sound, false, "zero turns the lock-on Sound switch off")
  equal(db.sniperSound, 1, "zero keeps the chosen sound")
  assert(has(out, "lock-on sound: Off"), "off confirmed")
  for _, bad in ipairs({ "sniper sound 9", "sniper sound -1", "sniper sound loud" }) do
    out = run(sim, bad)
    equal(db.sniperSound, 1, bad .. " keeps the sound")
    equal(db.alerts.channels.lockon.sound, false, bad .. " keeps the switch")
    assert(has(out, "1=Highground lock-on") and has(out, "0=off"), bad .. " lists sounds")
  end
  run(sim, "sniper sound 2")
  equal(db.sniperSound, 2, "a number picks the sound")
  equal(db.alerts.channels.lockon.sound, true, "and turns the switch back on")
  out = run(sim, "sniper skull maybe")
  assert(has(out, "/hg sniper skull on"), "skull usage")
  out = run(sim, "sniper wobble")
  assert(has(out, "/hg sniper [test"), "unknown word prints usage")
  out = run(sim, "sniper size big")
  assert(has(out, "/hg sniper [test"), "non-numeric size prints usage")
end)

t.test("/hg sniper why stops at the first missing step", function()
  local sim = new("cata", {})
  local out = run(sim, "sniper why")
  assert(has(out, "no target"), "needs a target")
  sim:command("sniper")
  out = run(sim, "sniper why")
  assert(has(out, "scope switched off"), "switched off first")
  assert(not has(out, "no target"), "stops there")
  sim:command("sniper")
  local enemy, token = sim:enemy("Scoped")
  local plate = sim.plates[token]
  sim.units.target, sim.plates[token] = enemy, nil -- beyond nameplate range
  out = run(sim, "sniper why")
  assert(has(out, "no target has a nameplate") or has(out, "reports no nameplate"), "no plate for the target")
  sim.plates[token] = plate
  sim.plates[token].IsForbidden = function() return true end
  out = run(sim, "sniper why")
  assert(has(out, "forbidden"), "forbidden plate")
  sim.plates[token].IsForbidden = function() return false end
  sim.plates[token].namePlateUnitToken = token
  out = run(sim, "sniper why")
  assert(has(out, "nameplate unit token " .. token), "unit token found")
  assert(has(out, "scope has no nameplate anchor"), "not showing outside a match or test")
  sim:command("sniper test"); sim:advance(0.2)
  out = run(sim, "sniper why")
  assert(has(out, "scope is showing"), "preview shows the marker")
  sim:command("sniper test")
  sim:join()
  out = run(sim, "sniper why")
  assert(has(out, "the scope marks the recommended kill target: "), "match explains the kill target")
end)

t.test("/hg go previews the kill window only with a sample or roster", function()
  local sim = new("cata", {})
  local out = run(sim, "go")
  assert(has(out, "no enemies listed: try /hg bg test first"), "nothing to preview")
  sim:command("bg test")
  out = run(sim, "go")
  local top = sim.ns.Core.order[1]
  assert(top.burnedAt, "defensive marked spent")
  assert(has(out, "kill-window preview on " .. top.display) and not has(out, "live data may override"), "sample preview")
  sim:command("bg test")
end)

t.test("panel commands save the lock and refuse to move protected panels in combat", function()
  local sim = new("cata", {})
  local Core = sim.ns.Core
  sim:enemy("Enemy")
  sim:join()
  Core.pos.point = { "CENTER", "CENTER", 10, 20 }
  run(sim, "reset")
  equal(Core.pos.point, nil, "saved position forgotten")
  equal(Core.frame.points[1][1], "TOPRIGHT", "main panel back at its default spot")
  Core.pos.point = { "CENTER", "CENTER", 10, 20 }
  sim:setCombat(true)
  local out = run(sim, "reset")
  assert(has(out, "leave combat first"), "reset waits for the player: " .. out)
  equal(Core.pos.point[3], 10, "position kept while the panel cannot move")
  out = run(sim, "unlock")
  equal(sim.env.HighgroundDB.locked, false, "unlock saved in combat")
  assert(has(out, "drag panel headers after combat"), "combat note")
  run(sim, "lock")
  equal(sim.env.HighgroundDB.locked, true, "lock saved")
  sim:setCombat(false)
  out = run(sim, "unlock")
  assert(has(out, "drag panel headers to move"), "plain unlock")
end)

t.test("previews refuse to start in combat", function()
  local sim = new("cata", {})
  sim:setCombat(true)
  local out = run(sim, "arena test")
  assert(has(out, "leave combat first"), "arena preview")
  assert(not (sim.env.HighgroundArenaFrame and sim.env.HighgroundArenaFrame:IsShown()), "arena sample stays hidden")
  out = run(sim, "nearby test")
  assert(has(out, "leave combat first"), "nearby preview")
  out = run(sim, "arena test ")
  assert(has(out, "leave combat first"), "a trailing space still starts the preview: " .. out)
end)

t.test("/hg pressure validates its count and prints its choices intact", function()
  local sim = new("cata", {})
  local db = sim.env.HighgroundDB
  local out = run(sim, "pressure count 9")
  assert(has(out, "/hg pressure count 1-3"), "range explained")
  out = run(sim, "pressure count 2")
  equal(db.pressureCount, 2, "count saved")
  out = run(sim, "pressure loud")
  assert(has(out, "/hg pressure [on|off|count 1-3|test]"), "choices: " .. out)
  run(sim, "pressure off")
  equal(db.pressure, false, "switched off")
  out = run(new("retail", {}), "pressure")
  assert(has(out, "available on Cata"), "Retail explains")
end)

t.finish("Display commands: " .. t.tests .. " tests")
