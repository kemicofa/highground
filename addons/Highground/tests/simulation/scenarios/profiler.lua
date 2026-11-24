local test, new, equal = ...

local function horde(saved, configure)
  return new("cata", saved, function(sim)
    sim.faction, sim.scores[1].faction, sim.area = 0, 0, "Warsong Lumber Mill"
    if configure then configure(sim) end
  end)
end

local function find(session, pattern)
  for _, row in ipairs(session.rows) do
    if row:find(pattern) then return row end
  end
end

local function click(button) button.scripts.OnClick(button) end

test("battleground profiler waits outside, records a match and offers a reload on leaving", function()
  local sim = horde()
  local db = sim.env.HighgroundDB
  local guarded, setWave = sim.ns.Util.RunGuarded, sim.ns.Timers.SetWave
  sim:command("bg profiler start")
  assert(db.bgProfilerOn, "armed outside a battleground")
  equal(db.bgProfiles, nil, "nothing recorded outside")
  sim:join(1460, 489, "Warsong Gulch")
  local s = db.bgProfiles[1]
  assert(s and not s.ended, "recording starts on entering")
  assert(find(s, "^%d+%.%d start entered map=Warsong Gulch inst=489"), "start row")
  assert(sim.ns.Util.RunGuarded ~= guarded and sim.ns.Timers.SetWave ~= setWave, "hooks while recording")
  sim:event("CHAT_MSG_BG_SYSTEM_NEUTRAL", "The battle for Warsong Gulch has begun!")
  assert(find(s, " chat N The battle for Warsong Gulch has begun!$"), "announcement kept verbatim")
  local rows = #s.rows
  sim:event("CHAT_MSG_SYSTEM", { secret = true })
  equal(#s.rows, rows, "withheld text adds no row")
  equal(s.counts["chat hidden"], 1, "withheld text is counted")
  local rezAt = sim.now + 12
  sim.env.GetAreaSpiritHealerTime = function() return sim.units.player.ghost and math.max(0, rezAt - sim.now) or nil end
  sim.units.player.ghost = true
  sim:advance(1.5)
  assert(find(s, " me healer left=1%d%.%d gyNext=[%d%.%-]+ gy=Horde Base Graveyard$"), "the game's countdown")
  assert(find(s, " wave exact H Horde Base Graveyard at=1%d%.%d err=%- kept=true was=%-"), "first exact wave")
  assert(find(s, " gy H Horde Base Graveyard next="), "graveyard clock change")
  sim:advance(rezAt - sim.now)
  sim.units.player.ghost = false
  sim:event("PLAYER_UNGHOST")
  local rez = find(s, " me rez after=")
  assert(rez and rez:find("healerErr=%-?0%.%d"), "resurrection against the countdown: " .. tostring(rez))
  sim:advance(31)
  assert(find(s, " summary tracked=true enemies="), "periodic summary")
  assert(next(s.stages), "stage timings")
  sim:leave()
  assert(s.ended and s.stop == "left", "leaving stops it")
  assert(find(s, " end left$"), "end row")
  equal(db.bgProfilerOn, nil, "not armed for the next battleground")
  equal(sim.ns.Util.RunGuarded, guarded, "guards restored")
  equal(sim.ns.Timers.SetWave, setWave, "timers restored")
  local w = sim.ns.Profiler.win
  assert(w and w:IsShown(), "reload offered")
  assert(w.body:GetText():find("events in Warsong Gulch", 1, true), "offer names the battleground")
  local reloads = 0
  sim.env.ReloadUI = function() reloads = reloads + 1 end
  click(w.reload)
  equal(reloads, 1, "reload button reloads")
  sim:join(1460, 489, "Warsong Gulch")
  equal(#db.bgProfiles, 1, "the next battleground is not recorded")
  sim:assertHealthy()
end)

test("WoW Forever recordings measure waves on the 31.6-second cycle", function()
  local sim = new("retail", nil, function(s)
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
    s.env.loadstring_untainted, s.secureSnippets, s.rated, s.blitz = nil, false, false, false
  end)
  sim:command("bg profiler start")
  sim:join(1460, 489, "Warsong Gulch")
  local s = sim.env.HighgroundDB.bgProfiles[1]
  assert(find(s, " clock period=30 downtime=1%.6 "), "period and downtime")
  -- As live: whole-second countdowns, ghosts back 0.9 s after the end.
  local ends
  sim.env.GetAreaSpiritHealerTime = function()
    return sim.units.player.ghost and math.max(0, math.floor(ends - sim.now)) or nil
  end
  for _, delay in ipairs({ 12, 31.6 }) do
    ends = (ends or sim.now) + delay
    sim.units.player.ghost = true
    sim:advance(ends + 0.9 - sim.now)
    sim.units.player.ghost = false
    sim:event("PLAYER_UNGHOST")
    sim:advance(1)
  end
  local exact = 0
  for _, row in ipairs(s.rows) do
    if row:find(" wave exact ") then exact = exact + 1 end
  end
  equal(exact, 2, "one row per wave, not per countdown second")
  local last
  for _, row in ipairs(s.rows) do
    if row:find(" me rez ") then last = row end
  end
  local err = last and tonumber(last:match("gyErr=(%-?[%d.]+)"))
  assert(err and math.abs(err) <= 0.3, "the next wave a cycle later, after the revive lag: " .. tostring(last))
  local lag = tonumber(last:match("healerErr=(%-?[%d.]+)"))
  assert(lag and lag >= 0.8 and lag <= 1.2, "back about 0.9 s after the countdown's end: " .. last)
  sim:assertHealthy()
end)

test("map POIs without an icon field are recorded without errors", function()
  local sim = horde()
  sim:command("bg profiler start")
  sim:join(1460, 489, "Warsong Gulch")
  sim:poi(nil)
  sim:advance(1.5)
  local s = sim.env.HighgroundDB.bgProfiles[1]
  assert(find(s, " poi 1 Stables|nil|nil at="), "a POI with neither atlas nor texture")
  sim:assertHealthy()
end)

test("a reload inside the battleground continues the same recording", function()
  local sim = horde()
  sim:join(1460, 489, "Warsong Gulch")
  sim:command("bg profiler start")
  local db = sim.env.HighgroundDB
  assert(find(db.bgProfiles[1], " start command "), "starts at once inside")
  sim:advance(2)
  local again = horde(db, function(s) s.inBG, s.instanceID, s.mapName = true, 489, "Warsong Gulch" end)
  again:advance(1)
  equal(#db.bgProfiles, 1, "same session")
  local s = again.ns.Profiler.Session()
  equal(s, db.bgProfiles[1], "resumed")
  assert(find(s, " resume runtime="), "resume row")
  again:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Alliance flag was picked up by Buddy!")
  assert(find(s, " chat H The Alliance flag was picked up by Buddy!"), "keeps recording")
  again:setCombat(true)
  again:leave()
  assert(s.ended and s.stop == "left", "leaving stops it")
  assert(not (again.ns.Profiler.win and again.ns.Profiler.win:IsShown()), "no dialog in combat")
  again:setCombat(false)
  assert(again.ns.Profiler.win:IsShown(), "offered after combat")
  again:assertHealthy()
end)

test("battleground profiler commands, limits and kept sessions", function()
  local sim = horde()
  local db, P = sim.env.HighgroundDB, sim.ns.Profiler
  sim:command("bg profiler stop")
  sim:command("bg profiler start")
  sim:command("bg profiler start")
  sim:command("bg profiler stop")
  equal(db.bgProfiles, nil, "armed and stopped outside records nothing")
  sim:join(1460, 489, "Warsong Gulch")
  P.MAX_ROWS = 6
  for round = 1, 4 do
    sim:command("bg profiler start")
    for i = 1, 8 do sim:event("CHAT_MSG_BG_SYSTEM_NEUTRAL", "Notice " .. round .. "." .. i) end
    sim:command("bg profiler stop")
    if P.win then P.win:Hide() end
  end
  equal(#db.bgProfiles, P.KEEP, "only the newest sessions are kept")
  local s = db.bgProfiles[1]
  equal(s.stop, "stopped", "stopped by command")
  equal(#s.rows, 7, "capped rows plus the end row")
  assert(s.dropped > 0 and s.counts.chat == 8, "dropped rows are counted")
  assert(find(s, " end stopped$"), "end row")
  sim:assertHealthy()
end)

test("damaged battleground recordings are repaired on load", function()
  local saved = { bgProfilerOn = "yes", bgProfiles = { "bad", { rows = { "1.0 chat N x", 5 }, t0 = 10, counts = 3 }, { rows = "bad", t0 = 1 } } }
  local sim = horde(saved)
  local db = sim.env.HighgroundDB
  equal(db.bgProfilerOn, nil, "not armed")
  equal(#db.bgProfiles, 1, "one usable session")
  equal(#db.bgProfiles[1].rows, 1, "string rows only")
  equal(type(db.bgProfiles[1].counts), "table", "counts repaired")
  sim:assertHealthy()
end)

test("WoW Forever: refused auras fall back to the loss-of-control count; recordings note its clues", function()
  local count = 0
  local sim = new("forever", {}, function(sim)
    sim.env.C_LossOfControl = {
      GetActiveLossOfControlDataCountByUnit = function() return count end,
      GetActiveLossOfControlDataByUnit = function() return { priority = 5, displayType = 2 } end,
    }
  end)
  sim.env.C_UnitAuras.GetUnitAuras = function() error("Auras cannot be accessed when secret") end
  sim:enemy("Stunned")
  sim:command("bg profiler start")
  sim:join(1460, 489, "Warsong Gulch")
  count = 1
  sim:advance(1)
  local Core = sim.ns.Core
  local row = Core.rows[1]
  assert(row.entry.crowdControlled, "crowd controlled")
  equal(row.pipText:GetText(), Core.PIP.control[1], "the row shows the generic control chip")
  count = 0
  sim:advance(1)
  assert(not row.entry.crowdControlled, "control ended")
  local s = sim.env.HighgroundDB.bgProfiles[1]
  assert(find(s, " loc Stunned%-Realm on=true priority=5 display=2"), "start with its clues")
  assert(find(s, " loc Stunned%-Realm on=false priority=nil display=nil"), "end")
end)
