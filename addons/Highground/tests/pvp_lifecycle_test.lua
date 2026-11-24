-- Match and duel exits after their refresh tickers stop, coalesced
-- scoreboard reads and the match journal's own row. Run from addons/Highground.
local t = dofile("../../tools/harness.lua")("pvp lifecycle")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")

local function setup(client, build)
  return new(client, {}, function(s, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 22 2026", build end
    env.StartDuel, env.CancelDuel = function() end, function() end
    s.addon = "Highground"
  end)
end

local function hidden(win) return not win or not win:IsShown() end

for _, client in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  local name = client[2] .. " "

  t.test(name .. "a duel that ends in combat hides its secure panel once combat ends", function()
    local sim = setup(client[1], client[2])
    sim.units.target = { name = "Sneak", classID = 4, guid = "Player-Sneak" }
    sim:event("DUEL_REQUESTED", "Sneak-Realm")
    local A = sim.ns.Arena
    sim:advance(0.5)
    assert(A.win:IsShown(), "the duel shows its panel")
    sim:setCombat(true)
    sim:event("DUEL_FINISHED")
    t.equal(A.win:GetAlpha(), 0, "combat fades the protected panel instead of hiding it")
    sim:advance(1)
    sim:setCombat(false)
    assert(hidden(A.win), "combat ending hides it although its ticker has stopped")
    sim:assertHealthy()
  end)

  t.test(name .. "leaving in combat hides flag carriers and capture bars", function()
    local sim = setup(client[1], client[2])
    local C, F = sim.ns.Core, sim.ns.Flags
    sim:enemy("Runner")
    sim:join(1339, 489, "Warsong Gulch")
    sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Alliance flag was picked up by Runner!")
    sim:advance(0.5)
    assert(F.flagWin and F.flagWin:IsShown(), "the carrier window shows in a flag battleground")
    local bar = C.capPlates[1] or nil
    if not bar then
      -- A bar from an earlier capture, still anchored to a plate.
      C.HideCapPlates()
      bar = sim.env.CreateFrame("StatusBar", nil, sim.env.UIParent)
      C.capPlates[1] = bar
    end
    bar:Show()
    sim:setCombat(true)
    sim:leave()
    assert(hidden(bar), "leaving hides capture bars the stopped tick would have cleared")
    t.equal(F.flagWin:GetAlpha(), 0, "combat fades the protected carrier window")
    sim:setCombat(false)
    assert(hidden(F.flagWin), "combat ending hides it")
    sim:assertHealthy()
  end)

  t.test(name .. "a burst of score events reads the scoreboard once and keeps the latest rows", function()
    local sim = setup(client[1], client[2])
    local C = sim.ns.Core
    sim:enemy("First")
    sim:join()
    sim:advance(0.3)
    local reads, refresh = 0, C.RefreshRoster
    C.RefreshRoster = function(...) reads = reads + 1; return refresh(...) end
    sim:event("UPDATE_BATTLEFIELD_SCORE")
    sim:enemy("Late")
    sim:event("UPDATE_BATTLEFIELD_SCORE")
    sim:event("UPDATE_BATTLEFIELD_SCORE")
    t.equal(reads, 1, "one read for the frame's burst")
    t.equal(sim:entry("Late"), nil, "the later row waits for the next tick")
    sim:advance(0.25)
    t.equal(reads, 2, "the next tick reads the pending update")
    assert(sim:entry("Late"), "and keeps the latest rows")
    sim:advance(1)
    t.equal(reads, 2, "no poll within two seconds of a read")
    sim:advance(1.5)
    t.equal(reads, 3, "the scoreboard is still polled without events")
    sim:assertHealthy()
  end)
end

for _, client in ipairs({ { "cata", 40402, 118, "HARMFUL" }, { "retail", 120100, 118, "HARMFUL|CROWD_CONTROL" } }) do
  t.test(client[2] .. " arena crowd control is read on aura changes, not every refresh", function()
    local sim = setup(client[1], client[2])
    local reads, debuffs = 0, {}
    sim.env.C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
      if filter == client[4] then reads = reads + 1 end
      return (sim.units[unit] and sim.units[unit] == sim.units.arena1 and debuffs or {})[i]
    end
    sim:joinArena()
    sim.units.arena1 = { name = "Sneak", classID = 4, guid = "Player-Sneak", enemy = true }
    sim:event("ARENA_OPPONENT_UPDATE", "arena1", "seen")
    sim:advance(1)
    local row, before = sim.ns.Arena.rows[1], reads
    sim:advance(5)
    t.equal(reads, before, "no aura reads without a change")
    debuffs[1] = { name = "Polymorph", icon = 136071, spellId = client[3], duration = 8,
      expirationTime = sim.now + 8, auraInstanceID = 7 }
    sim.units.nameplate3 = sim.units.arena1
    sim:event("UNIT_AURA", "nameplate3")
    sim:advance(0.3)
    assert(row.cc:IsShown(), "an aura change on another token of the opponent shows the control")
    before = reads
    sim:advance(5)
    assert(reads - before <= 1, "a shown control is not rescanned on every refresh")
    debuffs[1] = nil
    sim:advance(3.5)
    assert(not row.cc:IsShown(), "the control clears at its expiry even without an aura event")
    sim:assertHealthy()
  end)
end

-- Arathi Basin with owned, contested and neutral bases and a live score.
local function arathi(sim)
  sim.pois = {
    { name = "Stables", position = { x = 0.37, y = 0.29 }, textureIndex = 38 },
    { name = "Farm", position = { x = 0.56, y = 0.60 }, textureIndex = 35 },
    { name = "Blacksmith", position = { x = 0.46, y = 0.45 }, textureIndex = 27 },
    { name = "Lumber Mill", position = { x = 0.40, y = 0.56 }, textureIndex = 23 },
    { name = "Gold Mine", position = { x = 0.58, y = 0.31 }, textureIndex = 16 },
  }
  local scores = { [1893] = "Bases: 2  Resources: 840/1600", [1894] = "Bases: 1  Resources: 610/1600" }
  sim.env.C_UIWidgetManager = { GetIconAndTextWidgetVisualizationInfo = function(id)
    return scores[id] and { text = scores[id], shownState = 1 }
  end }
  for i = 1, 5 do sim:enemy("Enemy" .. i) end
  sim:join(93, 529, "Arathi Basin")
  sim:advance(3)
end

local function rowWith(rows, tag, text)
  for _, row in ipairs(rows) do
    if row.tag == tag and (not text or (row.text or ""):find(text, 1, true)) then return row end
  end
end

t.test("timer windows rewrite their row models in place and follow structural changes", function()
  jit.off()
  local sim = setup("cata", 40402)
  arathi(sim)
  local T = sim.ns.Timers
  local rows = T.ObjectiveRows(sim.now)
  local cap = rowWith(rows, "CAP", "Blacksmith")
  assert(cap and T.Forecast(sim.now), "capture row and a forecast")
  local resRows = T.Rows(sim.now)
  local first = resRows[1]
  local again = T.ObjectiveRows(sim.now + 1)
  t.equal(again, rows, "the list is reused")
  t.equal(rowWith(again, "CAP", "Blacksmith"), cap, "row models are rewritten in place")
  t.equal(T.Rows(sim.now + 1)[1], first, "resurrection rows too")
  -- Structural change: the Blacksmith assault ends in an Alliance capture.
  sim.pois[3].textureIndex = 28
  sim:event("AREA_POIS_UPDATED")
  local after = T.ObjectiveRows(sim.now + 2)
  t.equal(rowWith(after, "CAP", "Blacksmith"), nil, "a finished capture leaves the list")
  assert(rowWith(after, "OURS", "Blacksmith"), "and the overview shows the new owner")
  t.equal(rowWith(after, "CONTEST", "Blacksmith"), nil, "no stale contested row")
  for _, row in ipairs(after) do assert(row.tag and row.color, "no stale or half-cleared rows") end
  collectgarbage("collect"); collectgarbage("stop")
  local before = collectgarbage("count")
  for i = 1, 240 do T.UpdateWindow(sim.now + 3 + i * 0.25) end
  local allocated = collectgarbage("count") - before
  collectgarbage("restart")
  -- Before row reuse this minute of refreshes allocated about 1.8 MiB.
  assert(T.foreWin:IsShown(), "the forecast panel refreshed too")
  assert(allocated < 256, "a minute of timer and forecast refreshes: " .. allocated .. " KiB")
  jit.on()
  sim:assertHealthy()
end)

t.test("the translated forecast knows the winner and cached text follows a language change", function()
  local sim = setup("cata", 40402)
  arathi(sim)
  local T, C, L = sim.ns.Timers, sim.ns.Core, sim.ns.Locale
  assert(sim.ns.Localization.SetPreference("deDE"), "German is available")
  local m = T.Forecast(sim.now)
  t.equal(m.winner, T.MyTeam(), "the winner is a team id, not a translated name")
  T.ShowForecast(m)
  local team = L:Get(m.winner == "A" and "shared.copy.alliance.a21193" or "shared.copy.horde.cf9229")
  t.equal(T.foreWin.block.winner:GetText(), L:Format("battlegrounds.forecast.team_wins.494649", { team = team }), "German winner line")
  t.equal(T.foreWin.title:GetText(), "PROGNOSE", "the panel title follows the language")
  C.lastError = "test: shown"
  C.Tick()
  local german = C.subtitle.text
  t.equal(german, L:Format("battlegrounds.lifecycle.value1_error_r_hg_err.fdd05a", { value1 = sim.ns.Theme.Hex("danger") }),
    "error notice in German")
  sim.ns.Localization.SetPreference("enUS")
  C.Tick()
  assert(C.subtitle.text ~= german and C.subtitle.text:find("/hg err", 1, true), "the cached notice follows the language")
  C.capPlates[1] = C.capPlates[1] or sim.env.CreateFrame("StatusBar", nil, sim.env.UIParent)
  C.capPlates[1].tenths = 5
  sim.ns.Localization.SetPreference("frFR")
  t.equal(C.capPlates[1].tenths, nil, "capture labels are formatted again after a language change")
  sim.ns.Localization.SetPreference("enUS")
  sim.ns.Util.ClearErrors()
  C.lastError = nil
end)

t.test("translated forecast lines and timer rows keep their tooltip meaning", function()
  local sim = setup("cata", 40402)
  arathi(sim)
  local T, L, Loc = sim.ns.Timers, sim.ns.Locale, sim.ns.Localization
  -- The enemy leads, so NEED names the bases your team needs.
  local scores = T.MyTeam() == "A" and { [1893] = "Bases: 1  Resources: 610/1600", [1894] = "Bases: 3  Resources: 1100/1600" }
    or { [1893] = "Bases: 3  Resources: 1100/1600", [1894] = "Bases: 1  Resources: 610/1600" }
  sim.env.C_UIWidgetManager = { GetIconAndTextWidgetVisualizationInfo = function(id)
    return scores[id] and { text = scores[id], shownState = 1 }
  end }
  sim:advance(3)
  for _, locale in ipairs({ "enUS", "deDE" }) do
    assert(Loc.SetPreference(locale), locale)
    local m = T.Forecast(sim.now)
    assert(m and m.winner ~= T.MyTeam() and m.needTeam == T.MyTeam(), locale .. ": the enemy wins; your team's NEED")
    for _, row in ipairs(T.ObjectiveRows(sim.now)) do
      assert(row.kind ~= "WIN" and row.kind ~= "NEED" and row.kind ~= "PLAN", locale .. ": predictions left the timers list")
    end
    T.ShowForecast(m)
    local b = T.foreWin.block
    local team = L:Get(T.MyTeam() == "A" and "shared.copy.alliance.a21193" or "shared.copy.horde.cf9229")
    assert(b.need:GetText():find(team, 1, true), locale .. ": NEED names your team: " .. b.need:GetText())
    b.scripts.OnEnter(b)
    local lines = table.concat(sim.env.GameTooltip.lines or {}, "|")
    assert(lines:find(L:Get("shared.windows.projected_win_if_current_captures_complete.f1bd30"), 1, true)
      and lines:find(L:Get("shared.windows.bases_required_for_the_trailing_team_to.4074ab"), 1, true),
      locale .. ": tooltip meanings: " .. lines)
  end
  -- Every tag the timers set has a translation; the id stays the row's kind.
  for _, locale in ipairs({ "ruRU", "zhCN" }) do
    assert(Loc.SetPreference(locale), locale)
    for _, id in ipairs({ "YOU", "RES", "SOON", "OURS", "THEIRS", "NEUTRAL", "CONTEST",
      "CAPPING", "CAP", "LOCK", "RESET", "FLAG", "STATUS", "CONTROL", "OBJECTIVE", "ROUND", "EVENT", "CART" }) do
      local row = T.Tag({}, id)
      assert(row.kind == id and row.tag ~= id and not row.tag:find("%u%u"), locale .. ": " .. id .. " -> " .. row.tag)
    end
  end
  Loc.SetPreference("enUS")
  T.ShowForecast(T.Forecast(sim.now))
  t.equal(T.foreWin.title:GetText(), "FORECAST", "and English again")
  sim:assertHealthy()
end)

t.test("arena target and focus marks follow the language without per-update joins", function()
  local sim = setup("cata", 40402)
  local A, L, Loc = sim.ns.Arena, sim.ns.Locale, sim.ns.Localization
  sim:joinArena()
  local foe = { name = "Sneak", classID = 4, enemy = true }
  sim.units.arena1, sim.units.target, sim.units.focus = foe, foe, foe
  sim:advance(0.5)
  local r = sim.env.HighgroundArenaRow1
  assert(r and r:IsVisible(), "an arena row")
  local lookups, get = 0, L.Get
  L.Get = function(self, key, ...)
    if key == "highground.render.tgt.e2afb7" or key == "highground.render.foc.a6c566" then lookups = lookups + 1 end
    return get(self, key, ...)
  end
  for _, locale in ipairs({ "enUS", "frFR", "enUS" }) do
    Loc.SetPreference(locale)
    lookups = 0
    for _ = 1, 10 do A.UpdateRow(r) end
    t.equal(lookups, 0, locale .. ": row updates reuse the label")
    t.equal(r.marks:GetText(), get(L, "highground.render.tgt.e2afb7") .. " " .. get(L, "highground.render.foc.a6c566"), locale)
  end
  L.Get = get
  sim:assertHealthy()
end)

t.test("cooldown summaries are built only when explanations want them", function()
  local sim = setup("cata", 40402)
  local C = sim.ns.Core
  sim:command("bg test")
  local enemy = { class = "MAGE", cds = { [42292] = sim.now + 30 } }
  local points, reason = C.CooldownBonus(enemy)
  assert(points > 0 and reason, "callers without the flag keep the summary")
  local quiet, none = C.CooldownBonus(enemy, false)
  t.equal(quiet, points, "same points")
  t.equal(none, nil, "no summary when scoring does not explain")
  t.equal(select(2, C.CooldownBonus(enemy, true)), reason, "explanations still get it")
  sim:command("bg test")
end)

t.test("a burst of target changes refreshes the panel once at once and once after", function()
  local sim = setup("cata", 40402)
  local C = sim.ns.Core
  sim:enemy("Enemy")
  sim:join()
  sim:advance(0.3)
  local ticks, tick = 0, C.Tick
  C.Tick = function(...) ticks = ticks + 1; return tick(...) end
  local ticker = 0
  sim:event("PLAYER_TARGET_CHANGED")
  t.equal(ticks, 1, "the first change refreshes immediately")
  for _ = 1, 5 do sim:event("PLAYER_TARGET_CHANGED") end
  t.equal(ticks, 1, "the burst waits")
  sim:advance(0.1)
  assert(ticks >= 2 and ticks <= 3, "one trailing refresh (plus at most one scheduled tick): " .. ticks)
  ticker = ticks
  sim:advance(0.05)
  t.equal(ticks, ticker, "no further refresh from the burst")
  C.Tick = tick
  sim:assertHealthy()
end)

for _, client in ipairs({ { "cata", 40402 }, { "retail", 16001 } }) do
  t.test(client[2] .. " a battleground preview ends cleanly when an arena starts or another page stops it", function()
    local sim = setup(client[1], client[2])
    local P, F, T, E = sim.ns.BattlegroundsPreview, sim.ns.Flags, sim.ns.Timers, sim.ns.PvPEvents
    local function live(stage)
      for _, ticker in ipairs(E.tickers) do if ticker.stage == stage then return ticker.live end end
    end
    assert(P.Start(), "preview starts outside instances")
    sim:advance(0.5)
    assert(F.flagWin:IsShown(), "sample carriers show")
    sim.instanceType = "arena"
    sim:joinArena()
    sim:advance(1)
    assert(not T.previewing, "an arena ends the preview")
    assert(not F.flagWin:IsShown(), "sample carriers and their secure rows are hidden")
    t.equal(live("flags"), false, "the flag ticker stopped")
    sim.inArena, sim.instanceType = false, nil
    sim:event("PLAYER_ENTERING_WORLD")
    sim:advance(1)
    assert(P.Start(), "preview starts again")
    sim:advance(0.5)
    t.equal(live("timers"), true, "the preview runs the timers ticker")
    T.previewing = nil -- what other pages' stop buttons do
    sim:advance(1)
    t.equal(live("timers"), false, "the ticker notices and stops itself")
    t.equal(live("flags"), false, "and the flag ticker")
    sim:assertHealthy()
  end)
end

t.test("map pin tooltips keep the sighting they were drawn from", function()
  local sim = setup("cata", 40402)
  sim:enemy("Enemy")
  sim:join()
  local I = sim.ns.Intel
  local key = "Enemy-Realm"
  sim.ns.Test.RecordSighting(key, 0.4, 0.4, 3, "Scout", sim.now, "Farm", "coords")
  local items = I.Pins(sim.mapID, 1000, 667)
  local pin
  for _, item in ipairs(items) do if item.sortKey == key then pin = item end end
  assert(pin, "the sighting has a pin")
  I.Died(key, sim.now + 1) -- the record is rewritten in place
  local lines = {}
  pin.tooltip({ AddLine = function(_, text) lines[#lines + 1] = text end })
  assert(table.concat(lines, " "):find("Scout", 1, true), "the tooltip still names the observer")
  sim:assertHealthy()
end)

t.test("the match journal records your own Cata scoreboard row", function()
  local sim = setup("cata", 40402)
  local score = sim.env.GetBattlefieldScore
  sim.env.GetBattlefieldScore = function(i)
    local row = sim.scores[i]
    if row and row.name == "Me-Realm" then
      return row.name, 3, 7, 1, 150, row.faction, "Human", "Class", row.classToken, 9000, 400
    end
    return score(i)
  end
  sim:enemy("Enemy")
  sim:join()
  sim:event("UPDATE_BATTLEFIELD_SCORE")
  local stats = sim.ns.MatchHistory.current.stats
  t.equal(stats.killingBlows, 3, "killing blows")
  t.equal(stats.damageDone, 9000, "damage")
  t.equal(stats.healingDone, 400, "healing")
  sim:assertHealthy()
end)

t.finish("PvP lifecycle: " .. t.tests .. " tests")
