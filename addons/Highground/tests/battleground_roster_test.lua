-- Scoreboard roster (core/Roster.lua): which team is yours when your own
-- row is missing, filtered or unreadable scoreboards, class names and
-- enemies leaving. Run from addons/Highground: luajit tests/battleground_roster_test.lua
local t = dofile("../../tools/harness.lua")("battleground roster")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local equal = t.equal

-- A Cata match whose scoreboard lacks your own row (cross-realm names that
-- do not match, a row still loading).
local function withoutOwnRow(configure)
  local sim = new("cata", {}, configure)
  sim.scores = {
    { name = "Ally-Realm", classToken = "PRIEST", faction = 1 },
    { name = "Buddy-Realm", classToken = "ROGUE", faction = 1 },
    { name = "Foe-Realm", classToken = "MAGE", faction = 0 },
    { name = "Rival-Realm", classToken = "WARRIOR", faction = 0 },
  }
  return sim
end

local function join(sim)
  sim.inBG, sim.mapID, sim.instanceID, sim.mapName = true, 1460, 489, "Warsong Gulch"
  sim:event("PLAYER_ENTERING_WORLD"); sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
end

t.test("two group members on the scoreboard decide your team", function()
  local sim = withoutOwnRow()
  sim.members = 2
  sim.units.raid1 = { name = "Ally" }
  sim.units.raid2 = { name = "Buddy" }
  sim.env.GetBattlefieldArenaFaction = nil
  join(sim)
  local Core = sim.ns.Core
  equal(Core.allyFaction, 1, "majority of your group")
  assert(Core.enemies["Foe-Realm"] and Core.enemies["Rival-Realm"], "enemy team listed")
  equal(Core.enemies["Ally-Realm"], nil, "teammates are not enemies")
end)

t.test("one group member is not enough; the arena faction is the fallback", function()
  local sim = withoutOwnRow()
  sim.members = 1
  sim.units.raid1 = { name = "Foe" } -- a stale or wrong group entry
  sim.faction = 0
  join(sim)
  equal(sim.ns.Core.allyFaction, 0, "client's battleground faction used")
  assert(sim.ns.Core.enemies["Ally-Realm"], "the other side is the enemy")
end)

t.test("an unknown team leaves the roster empty and says why", function()
  local sim = withoutOwnRow()
  sim.members = 0
  sim.env.GetBattlefieldArenaFaction = function() return 7 end -- not on this scoreboard
  join(sim)
  local Core = sim.ns.Core
  equal(Core.allyFaction, nil, "team unknown")
  equal(Core.rosterStatus, "can't tell which team is yours", "status for /hg err")
  equal(next(Core.enemies), nil, "nobody guessed as an enemy")
end)

t.test("a scoreboard filtered to one team keeps enemies and is reset once closed", function()
  local sim = new("cata", {})
  sim:enemy("Kept")
  sim:join(1460, 489, "Warsong Gulch")
  local Core = sim.ns.Core
  assert(Core.enemies["Kept-Realm"], "enemy listed")
  local all = sim.scores
  sim.scores = { all[1] } -- only your team's tab
  sim.scoreFilter = nil
  sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
  equal(sim.scoreFilter, -1, "filter reset to both teams")
  assert(Core.enemies["Kept-Realm"], "enemy kept on a one-team read")
  equal(Core.rosterStatus, "enemy team not on scoreboard yet", "status explains the wait")
  sim.scores = all
  sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
  equal(Core.rosterStatus, nil, "full read clears the status")
  table.remove(sim.scores, 2)
  sim.scores[#sim.scores + 1] = { name = "Late-Realm", classToken = "PALADIN", faction = 0 }
  sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
  equal(Core.enemies["Kept-Realm"], nil, "an enemy who left is dropped")
  assert(Core.enemies["Late-Realm"], "a new enemy is added")
end)

t.test("Cata class names become class tokens", function()
  local sim = new("cata", {})
  sim:enemy("Plain")
  sim:join(1460, 489, "Warsong Gulch")
  sim.scores[#sim.scores + 1] = { name = "Death-Realm", classToken = "Death Knight", faction = 0 }
  sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
  local Core = sim.ns.Core
  equal(Core.enemies["Death-Realm"].class, "DEATHKNIGHT", "class name with a space")
  equal(Core.ClassToken("death_knight"), "DEATHKNIGHT", "underscores dropped")
  sim.env.LOCALIZED_CLASS_NAMES_MALE.MAGE = "Magier"
  equal(Core.ClassToken("Magier"), "MAGE", "localized class name")
  equal(Core.ClassToken({ secret = true }), nil, "secret class unreadable")
end)

t.test("unreadable scoreboard rows are counted and never listed", function()
  local sim = new("retail", {})
  sim:enemy("Plain")
  sim:join(1460, 489, "Warsong Gulch")
  local secret = { secret = true }
  for _, row in ipairs({ { name = secret, classToken = "MAGE", faction = 0 },
    { name = "Hidden-Realm", classToken = secret, faction = 0 },
    { name = "Nowhere-Realm", classToken = "MAGE", faction = secret } }) do
    sim.scores[#sim.scores + 1] = row
  end
  sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
  local Core, debug = sim.ns.Core, sim.env.HighgroundDB.rosterDebug
  equal(debug.scores, 5, "scoreboard size")
  equal(debug.badName, 1, "unreadable name counted")
  equal(debug.badClass, 1, "unreadable class counted")
  equal(debug.badFaction, 1, "unreadable faction counted")
  equal(debug.rows, 2, "readable rows")
  assert(Core.enemies["Plain-Realm"], "readable enemy listed")
  equal(Core.enemies["Hidden-Realm"], nil, "unreadable class never listed")
  equal(Core.enemies["Nowhere-Realm"], nil, "unreadable faction never listed")
end)

t.finish("Battleground roster: " .. t.tests .. " tests")
