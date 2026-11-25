local t = dofile("../../tools/harness.lua")("alerts")

-- Real Util and Alerts against a stub clock, one-shot timers and frames.
local function Fixture()
  local s = { now = 100, timers = {}, frames = {}, played = {}, said = {} }
  local env = setmetatable({ GetTime = function() return s.now end }, { __index = _G })
  env.C_Timer = { After = function(delay, fn) s.timers[#s.timers + 1] = { due = s.now + delay, fn = fn } end }
  env.CreateFrame = function()
    local f = { scripts = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:Show() end
    function f:Hide() end
    s.frames[#s.frames + 1] = f
    return f
  end
  env.print = function(line) s.said[#s.said + 1] = line end
  env.wipe = function(t) for k in pairs(t) do t[k] = nil end; return t end
  s.db = {}
  s.ns = { Core = { db = s.db, On = function() return true end }, Scope = { Listen = function() end },
    Saved = { Table = function(t, key) if type(t[key]) ~= "table" then t[key] = {} end; return t[key] end } }
  dofile("../../tests/locale_fixture.lua")(s.ns, env)
  for _, file in ipairs({ "Util", "Events", "Alerts" }) do
    setfenv(assert(loadfile("libs/core/" .. file .. ".lua")), env)("Highground", s.ns)
  end
  function s:advance(dt)
    self.now = self.now + dt
    local due = {}
    for i = #self.timers, 1, -1 do
      if self.timers[i].due <= self.now then table.insert(due, 1, table.remove(self.timers, i)) end
    end
    for _, timer in ipairs(due) do timer.fn() end
  end
  function s:sound(name) return function() self.played[#self.played + 1] = name end end
  return s
end

t.test("an idle queue schedules nothing", function()
  local s = Fixture()
  t.equal(#s.timers, 0, "no flush timer at load")
  local polling = 0
  for _, f in ipairs(s.frames) do if f.scripts.OnUpdate then polling = polling + 1 end end
  t.equal(polling, 1, "only the once-a-minute cleanup polls")
  s:advance(10)
  t.equal(#s.timers, 0, "still nothing while idle")
end)

t.test("simultaneous sounds play only the highest priority after a short wait", function()
  local s = Fixture()
  local U = s.ns.Util
  assert(U.Notify("nearby", "a", "Nearby enemy", s:sound("nearby")))
  assert(U.Notify("capture", "b", "Base capture", s:sound("capture")))
  assert(U.Notify("lockon", "c", nil, s:sound("lockon")))
  t.equal(#s.timers, 1, "one flush for the burst")
  t.equal(#s.played, 0, "sounds wait for the window")
  t.equal(#s.said, 2, "text is immediate")
  s:advance(0.15)
  t.equal(#s.played, 1, "one sound")
  t.equal(s.played[1], "capture", "highest priority wins")
  t.equal(next(s.ns.Alerts.pending), nil, "queue emptied")
  t.equal(#s.timers, 0, "no further flushes")
  t.equal(U.Notify("nearby", "a", "again", s:sound("nearby")), false, "repeat within a second is suppressed")
  s:advance(1)
  assert(U.Notify("nearby", "a", "later", s:sound("nearby")))
  s:advance(0.15)
  t.equal(#s.played, 1, "a lower priority cue waits 1.5 s after a louder one")
  s:advance(1.5)
  assert(U.Notify("nearby", "d", "later", s:sound("nearby")))
  s:advance(0.15)
  t.equal(s.played[2], "nearby", "lower priority plays once the earlier cue is old enough")
end)

t.test("muted sound channels and failing sounds stay contained", function()
  local s = Fixture()
  s.db.alerts = { channels = { capture = { sound = false } } }
  s.ns.Util.Notify("capture", "x", "Base capture", s:sound("capture"))
  s:advance(0.15)
  t.equal(#s.played, 0, "muted category does not play")
  s.db.alerts = nil
  s.ns.Util.Notify("objective", "y", nil, function() error("sound failed", 0) end)
  s:advance(0.15)
  t.equal(s.ns.Util.GuardStats.alerts.errors, 1, "a failing sound is recorded")
  s:advance(1.5)
  s.ns.Util.Notify("capture", "z", nil, s:sound("capture"))
  s:advance(0.15)
  t.equal(s.played[1], "capture", "later alerts still flush")
end)

t.test("target lock plays straight after another alert sound", function()
  local s = Fixture()
  local U = s.ns.Util
  assert(U.Notify("capture", "a", nil, s:sound("capture")))
  s:advance(0.15)
  assert(U.Notify("lockon", "target", nil, s:sound("lockon")))
  s:advance(0.15)
  t.equal(s.played[2], "lockon", "lock-on skips the gap between sounds")
end)

t.test("presets set every switch and keep nothing of their own", function()
  local s = Fixture()
  local A = s.ns.Alerts
  s.db.alerts = { channels = {} }
  assert(A.SetMode("critical"))
  t.equal(s.db.alerts.mode, nil, "no saved level")
  t.equal(A.Allowed("capture", "sound"), true, "critical keeps captures")
  t.equal(A.Allowed("lockon", "sound"), false, "critical turns target lock off")
  t.equal(A.Preset(s.db.alerts), "critical", "the switches match Critical only")
  A.SetChannel("lockon", "sound", true)
  t.equal(A.Allowed("lockon", "sound"), true, "a ticked switch plays")
  t.equal(A.Preset(s.db.alerts), "custom", "a changed switch shows Custom")
  assert(A.SetMode("everything"))
  t.equal(A.Preset(s.db.alerts), "everything", "a preset replaces every switch")
  t.equal(A.SetMode("essential"), false, "Essentials is gone")
end)

t.test("old alert levels and sound options fold into the switches once", function()
  local A = Fixture().ns.Alerts
  -- Essentials muted only target lock behind its ticked switch.
  local alerts = { mode = "essential", channels = {} }
  t.equal(A.Upgrade({ alerts = alerts }, { sniperSound = 1 }), true, "Essentials is a known level")
  t.equal(alerts.mode, nil, "the level is removed")
  t.equal(A.AllowedFor(alerts, "lockon", "sound", true), true, "Essentials becomes Everything")
  alerts = { mode = "objectives", channels = { capture = { text = false } } }
  A.Upgrade({ alerts = alerts })
  t.equal(A.AllowedFor(alerts, "capture", "text", true), false, "own switches stay off")
  t.equal(A.AllowedFor(alerts, "capture", "sound", true), true, "the level's choices stay on")
  t.equal(A.AllowedFor(alerts, "go", "text", true), false, "the level's filter becomes switches")
  local before = A.Preset(alerts)
  A.Upgrade({ alerts = alerts })
  t.equal(A.Preset(alerts), before, "repeating changes nothing")
  -- Older saves may have sound options before any alert settings.
  local db = { bountySound = false, nearbySound = true, sniperSound = 0 }
  A.Upgrade(db, db)
  alerts = db.alerts
  local prefs = db
  t.equal(A.AllowedFor(alerts, "bounty", "sound", true), false, "bounty sound option becomes its switch")
  t.equal(A.AllowedFor(alerts, "nearby", "sound", true), true, "an enabled option leaves the switch on")
  t.equal(A.AllowedFor(alerts, "lockon", "sound", true), false, "Silent becomes the lock-on switch")
  t.equal(prefs.sniperSound, 1, "and the chosen sound is a real one")
  t.equal(prefs.bountySound == nil and prefs.nearbySound == nil, true, "old options are removed")
  t.equal(A.Upgrade({ alerts = { mode = "loud" } }), false, "an unknown level is reported")
  alerts = { mode = "quiet" }
  A.Upgrade({ alerts = alerts }, { bountySound = false })
  t.equal(A.Preset(alerts), "quiet", "Text only stays Text only")
end)

t.test("sound-only categories ignore legacy text switches and still mute their cues", function()
  local s = Fixture()
  local A = s.ns.Alerts
  assert(A.SetMode("everything"))
  for _, category in ipairs({ "go", "lockon" }) do
    t.equal(A.Supports(category, "text"), false, "no written alert for " .. category)
    t.equal(A.SetChannel(category, "text", true), false, "unused preference cannot be edited")
    t.equal(A.Settings().channels[category].text, nil, "presets store only useful switches")
    A.Settings().channels[category].text = false -- an old profile
    t.equal(A.Preset(A.Settings()), "everything", "legacy text does not make a preset Custom")
    assert(A.SetChannel(category, "sound", false))
    A.Emit(category, category, nil, s:sound(category))
    s:advance(2)
    t.equal(#s.played, 0, "Sound off mutes " .. category)
    assert(A.SetChannel(category, "sound", true))
  end
  assert(A.SetMode("quiet"))
  t.equal(A.Preset(A.Settings()), "quiet", "Text only recognizes sound-only categories")
  t.equal(A.Allowed("go", "sound"), false, "Text only mutes the kill window")
end)

t.finish("Alerts: " .. t.tests .. " tests, " .. t.checks .. " checks")
