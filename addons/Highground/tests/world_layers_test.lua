-- Layers (world/Layer.lua): each open-world sighting's layer status, the
-- list, map pins, heat and tracking alerts that follow it, the world map's
-- Layers button and /hg nearby layers, against each client's real TOC.
local t = dofile("../../tools/harness.lua")("world layers")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test = t.test
local function equal(actual, expected, why) t.equal(actual, expected, why or "values match") end

local HILLSBRAD, ARATHI = 1424, 1417
local SHARDING = 1

-- In Hillsbrad with Ally in your party. s.phase[unit]: what the game's
-- phase mark says of that member (nil: on your layer); s.where[unit]: the
-- member's map.
local function setup(build, client)
  return new(client or "retail", nil, function(s, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", build end
    env.IsInGuild = function() return true end
    env.IsInGroup = function(category)
      if category ~= nil and category == env.LE_PARTY_CATEGORY_INSTANCE then return s.inBG end
      return s.grouped or s.inBG
    end
    s.phase, s.where = {}, {}
    env.UnitPhaseReason = function(unit) return s.phase[unit] end
    s.mapID, s.mapName, s.area = HILLSBRAD, "Hillsbrad Foothills", "Tarren Mill"
    s.units.player.position = { x = 0.5, y = 0.4 }
    s.units.party1 = { name = "Ally", realm = "Realm" }
    s.grouped, s.members = true, 2
  end)
end

-- The party member's map, read per unit.
local function maps(sim)
  local best = sim.env.C_Map.GetBestMapForUnit
  sim.env.C_Map.GetBestMapForUnit = function(unit)
    if sim.where[unit] then return sim.where[unit] end
    return best(unit)
  end
end

local function plate(sim, name)
  sim.units.nameplate1 = { name = name, classID = 4, enemy = true, level = 60, realm = "" }
  sim:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
  sim:advance(0.2)
end

local function receive(sim, name, channel, sender, x)
  sim:event("CHAT_MSG_ADDON", "HighgroundW", string.format("1:%d:%s-Realm,MAGE,60,%d,4100,28,1,", HILLSBRAD, name, x or 4800),
    channel or "PARTY", sender or "Ally-Realm")
end

local function row(sim, name)
  sim.ns.Nearby.Update()
  for _, r in ipairs(sim.ns.Nearby.rows or {}) do
    if r:IsShown() and r.who == name then return r end
  end
end

local function pins(sim)
  local out = {}
  for _, item in ipairs(sim.ns.WorldMap.Pins(HILLSBRAD)) do
    if item.sortKey then out[#out + 1] = item end
  end
  return out
end

local function tip(item)
  local lines = {}
  item.tooltip({ AddLine = function(_, line) lines[#lines + 1] = line end }, item)
  return table.concat(lines, "\n")
end

local function heatCount(sim)
  local n = 0
  sim.ns.WorldHeat.Refresh()
  for _, item in ipairs(sim.ns.WorldHeat.Pins(HILLSBRAD)) do
    if item.heat then n = n + item.count end
  end
  return n
end

local function said(sim, text)
  for i = #sim.messages, 1, -1 do
    if sim.messages[i]:find(text, 1, true) then return sim.messages[i] end
  end
end

test("16001: a group member's phase mark judges their sightings; other layers leave list, pins and heat", function()
  local sim = setup(16001)
  maps(sim)
  local L, N = sim.ns.WorldLayer, sim.ns.Nearby
  assert(L.Supported(), "WoW Forever has layers")
  receive(sim, "Here")
  equal(L.Status(N.seen.Here), "same", "no phase mark in your zone: your layer")
  sim.phase.party1 = SHARDING
  receive(sim, "Away", nil, nil, 2000)
  equal(L.Status(N.seen.Away), "other", "marked as sharded: another layer")
  sim.phase.party1 = nil
  sim.where.party1 = ARATHI
  receive(sim, "Elsewhere", nil, nil, 7000)
  equal(L.Status(N.seen.Elsewhere), nil, "a member in another zone: unknown")
  sim.where.party1 = nil
  receive(sim, "Guilded", "GUILD", "Officer-Realm", 6000)
  equal(L.Status(N.seen.Guilded), nil, "the guild's: unknown")
  assert(row(sim, "Here") and row(sim, "Guilded"), "your layer and unknown are listed")
  equal(row(sim, "Away"), nil, "another layer is not")
  local here
  for _, p in ipairs(pins(sim)) do
    assert(not p.sortKey:find("Away", 1, true), "no pin for another layer")
    if p.sortKey == "world:Here" then here = p end
  end
  assert(here and tip(here):find("Seen on your layer", 1, true), "the tooltip names the layer")
  equal(heatCount(sim), 3, "another layer adds no heat")
  -- Showing all: greyed, tagged, in the heat.
  sim:command("nearby layers all")
  assert(sim.ns.Core.O("nearbyLayersAll"))
  local r = row(sim, "Away")
  assert(r, "listed with all layers")
  assert(r.sub.text:find("other layer", 1, true), "tagged: " .. r.sub.text)
  local away
  for _, p in ipairs(pins(sim)) do if p.sortKey == "world:Away" then away = p end end
  assert(away, "pinned with all layers")
  equal(away.desat, 1, "greyed")
  assert(tip(away):find("Seen on another layer", 1, true))
  equal(heatCount(sim), 4)
  sim:command("nearby layers mine")
  equal(sim.ns.Core.O("nearbyLayersAll"), false)
  equal(row(sim, "Away"), nil)
  sim:assertHealthy()
end)

test("16001: a move puts your own sightings on another layer; a loading screen makes them unknown", function()
  local sim = setup(16001)
  local L, N = sim.ns.WorldLayer, sim.ns.Nearby
  plate(sim, "Mine")
  local e = N.seen.Mine
  equal(L.Status(e), "same", "yours: your layer")
  sim.units.nameplate1 = nil
  sim:event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
  sim:event("SHARD_TRANSFER")
  equal(L.Status(e), "other", "the game moved you")
  equal(row(sim, "Mine"), nil, "left out of the list")
  -- Seeing it again on the new layer makes it yours again.
  plate(sim, "Mine")
  equal(L.Status(N.seen.Mine), "same")
  sim.units.nameplate1 = nil
  sim:event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
  sim:event("PLAYER_ENTERING_WORLD")
  equal(L.Status(N.seen.Mine), nil, "after a loading screen: unknown")
  sim:assertHealthy()
end)

test("16001: tracking alerts name another layer", function()
  local sim = setup(16001)
  maps(sim)
  sim:command("nearby track Away")
  sim.phase.party1 = SHARDING
  receive(sim, "Away")
  sim:advance(0.2)
  assert(said(sim, "Tracked: Away · Hillsbrad Foothills · seen by Ally · on another layer"), "the alert names the layer")
  sim:assertHealthy()
end)

test("16001: the world map's Layers button counts hidden sightings and switches", function()
  local sim = setup(16001)
  maps(sim)
  local L = sim.ns.WorldLayer
  sim.phase.party1 = SHARDING
  receive(sim, "Away")
  sim.env.OpenWorldMap(HILLSBRAD)
  sim:advance(1)
  local b = L.chip
  assert(b and b:IsShown(), "shown on the open map")
  equal(b.text, "Layers: yours · hidden: 1")
  b:Click()
  assert(sim.ns.Core.O("nearbyLayersAll"), "a click shows all layers")
  equal(b.text, "Layers: all")
  b:Click()
  equal(sim.ns.Core.O("nearbyLayersAll"), false)
  sim.env.WorldMapFrame:Hide()
  sim:advance(1)
  assert(not b:IsShown(), "gone with the map")
  sim:command("nearby")
  assert(said(sim, "Other layers: hidden (1 sightings)"), "/hg nearby reports it")
  sim:assertHealthy()
end)

test("16001: the preview's other-layer sample waits for all layers", function()
  local sim = setup(16001)
  sim.grouped = false
  local N = sim.ns.Nearby
  sim:command("nearby test")
  equal(row(sim, "Duskblade"), nil, "hidden on your layer")
  sim:command("nearby layers all")
  local r = row(sim, "Duskblade")
  assert(r and r.sub.text:find("other layer", 1, true), "shown and tagged with all layers")
  sim:command("nearby test")
  assert(not N.preview)
  sim:assertHealthy()
end)

for _, case in ipairs({ { "retail", 120100 }, { "cata", 40402 } }) do
  local client, build = unpack(case)
  test(build .. ": games without layers judge nothing and hide nothing", function()
    local sim = setup(build, client)
    maps(sim)
    local L, N = sim.ns.WorldLayer, sim.ns.Nearby
    assert(not L.Supported())
    sim.phase.party1 = SHARDING
    receive(sim, "Away")
    equal(L.Status(N.seen.Away), nil, "no group judgement")
    plate(sim, "Mine")
    sim:event("SHARD_TRANSFER")
    assert(row(sim, "Away") and row(sim, "Mine"), "nothing is hidden")
    sim.env.OpenWorldMap(HILLSBRAD)
    sim:advance(1)
    assert(not (L.chip and L.chip:IsShown()), "no Layers button")
    sim:command("nearby layers all")
    assert(said(sim, "Layers aren't tracked in this game."))
    sim:assertHealthy()
  end)
end

t.finish("World layers: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
