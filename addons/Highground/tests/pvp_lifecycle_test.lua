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
