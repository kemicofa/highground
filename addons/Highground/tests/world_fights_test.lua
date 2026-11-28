-- World fights (features/battlegrounds/core/World.lua): the kill order on
-- Nearby's sightings in open-world group fights.
local t = dofile("../../tools/harness.lua")("world fights")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test = t.test
local function equal(actual, expected, why) t.equal(actual, expected, why or "values match") end

local function setup(client, build)
  return new(client, nil, function(s, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", build end
    env.IsInGuild = function() return true end
    env.IsInGroup = function(category)
      if category ~= nil and category == env.LE_PARTY_CATEGORY_INSTANCE then return s.inBG end
      return s.grouped or s.inBG
    end
    s.mapID, s.mapName, s.area = 1424, "Hillsbrad Foothills", "Tarren Mill"
    s.units.player.position = { x = 0.5, y = 0.4 }
    s.grouped = true
  end)
end

local function plate(sim, name, token)
  sim.units[token or "nameplate1"] = { name = name, classID = 4, enemy = true, level = 60, yards = 20 }
  sim:event("NAME_PLATE_UNIT_ADDED", token or "nameplate1")
end

local function prefixes(sim)
  local seen = {}
  for _, m in ipairs(sim.sent) do seen[m.prefix] = true end
  return seen
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  local client, build = unpack(case)

  test(build .. ": a group fight runs the kill order on Nearby's enemies, without battleground parts", function()
    local sim = setup(client, build)
    local Core = sim.ns.Core
    equal(Core.active, false)
    plate(sim, "Sneaky")
    sim:advance(1.5)
    assert(Core.active and Core.context == "world", "an enemy in sight with a group starts a world fight")
    equal(sim.ns.IsActive(), false, "battleground-only parts stay off")
    assert(sim.ns.InWorldFight())
    assert(Core.enemies["Sneaky-Realm"], "the board lists Nearby's enemy")
    sim:advance(1)
    equal(Core.order[1] and Core.order[1].key, "Sneaky-Realm", "and scores it")
    assert(Core.frame and not Core.frame:IsShown(), "no kill-order board in the open world")
    local N = sim.ns.Nearby
    sim:advance(1)
    assert(N.Fighting(), "Nearby's list is the kill order")
    local r = N.rows[1]
    equal(Core.Canon(r.who), "Sneaky-Realm")
    assert(r.rankBox:IsShown() and tostring(r.rank:GetText()) == "1", "with its rank")
    assert(r.hp:IsShown(), "and health")
    local p = prefixes(sim)
    assert(not p.HighgroundS and not p.HighgroundI and not p.HighgroundT and not p.HighgroundC,
      "no spec tags, map intel, timers or captures are sent")
    if sim.ns.Caps.combatLog then
      sim:combatLog("SPELL_CAST_START", "Looter-Realm", "", 6477, { spellName = "Opening" })
      equal(sim.env.HighgroundDB.capLog, nil, "an Opening cast near a world fight is no capture")
      equal(next(Core.recentCasts), nil, "nor a remembered cast")
    end
    -- A shared sighting in your zone joins the board.
    sim:event("CHAT_MSG_ADDON", "HighgroundW", "1:1424:Healer-Realm,PRIEST,60,4000,4000,60,1,", "PARTY", "Ally-Realm")
    sim:advance(1)
    assert(Core.enemies["Healer-Realm"], "a group member's sighting is on the board")
    -- Gone for a minute: the fight ends and the board clears.
    sim.units.nameplate1 = nil
    sim:event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    sim:advance(65)
    equal(Core.active, false, "the fight ends a minute after the last enemy")
    equal(next(Core.enemies), nil)
    assert(not Core.frame:IsShown())
    sim:advance(1)
    assert(not N.Fighting() and not r.rankBox:IsShown() and not r.hp:IsShown(), "Nearby goes back to its list")
    sim:assertHealthy()
  end)

  test(build .. ": Nearby follows the kill order out of combat and keeps its rows in combat", function()
    local sim = setup(client, build)
    local Core, N = sim.ns.Core, sim.ns.Nearby
    plate(sim, "Sneaky")
    sim:advance(1)
    plate(sim, "Holy", "nameplate2")
    sim:advance(1.5)
    assert(sim.ns.InWorldFight() and #Core.order == 2)
    local function rows() return Core.Canon(N.rows[1].who), Core.Canon(N.rows[2].who) end
    local function rank(i) return tostring(N.rows[i].rank:GetText()) end
    local a, b = Core.order[1].key, Core.order[2].key
    equal(table.concat({ rows() }, ","), a .. "," .. b, "rows follow the rank")
    -- The order flips: out of combat the rows follow.
    Core.order[1], Core.order[2] = Core.order[2], Core.order[1]
    N.Update()
    equal(table.concat({ rows() }, ","), b .. "," .. a, "rows reorder")
    -- In combat the rows keep their enemies; the ranks follow.
    sim:setCombat(true)
    Core.order[1], Core.order[2] = Core.order[2], Core.order[1]
    N.Update()
    equal(table.concat({ rows() }, ","), b .. "," .. a, "bindings stay in combat")
    equal(rank(1) .. rank(2), "21", "ranks follow")
    sim:setCombat(false)
    N.Update()
    equal(table.concat({ rows() }, ","), a .. "," .. b, "and reorder after combat")
    -- Without Target recommendations: the usual most-recent order, no ranks.
    Core.SetFeature("killorder", false)
    N.Update()
    assert(not N.rows[1].rankBox:IsShown(), "no ranks")
    assert(not Core.frame:IsShown(), "and still no board")
    sim:assertHealthy()
  end)

  test(build .. ": solo, the switch, instances and combat decide when it runs", function()
    local sim = setup(client, build)
    local Core = sim.ns.Core
    sim.grouped = false
    plate(sim, "Sneaky")
    sim:advance(2)
    equal(Core.active, false, "not alone")
    sim.grouped = true
    sim:command("nearby fights off")
    sim:advance(2)
    equal(Core.active, false, "not with the switch off")
    sim:command("nearby fights on")
    sim:advance(2)
    assert(Core.active and Core.context == "world")
    -- In combat the board stays, even with no enemy left.
    sim:setCombat(true)
    sim.units.nameplate1 = nil
    sim:event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    sim:advance(70)
    assert(Core.active, "stays during combat")
    sim:setCombat(false)
    sim:advance(2)
    equal(Core.active, false, "ends after combat")
    -- A battleground takes over.
    plate(sim, "Sneaky", "nameplate2")
    sim:advance(2)
    assert(Core.context == "world")
    -- One zone check from a world fight to a battleground: its board shows.
    local rated = Core.InRatedBG
    Core.InRatedBG = function() return true end
    Core.CheckZone()
    assert(Core.context == "bg" and Core.frame:IsShown(), "the board, straight from a world fight")
    Core.InRatedBG = rated; Core.CheckZone()
    assert(Core.context == "world" and not Core.frame:IsShown(), "and gone again")
    sim:join(93, 529, "Arathi Basin")
    sim:advance(2)
    equal(Core.context, "bg", "a battleground runs as before")
    assert(sim.ns.IsActive())
    assert(Core.frame:IsShown(), "with its board")
    sim:assertHealthy()
  end)
end

t.finish("World fights: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
