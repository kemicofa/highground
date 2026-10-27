local support = ...
local check, key = support.check, support.key
local function client()
  local s, ns, e = support.client({ unit = "target" })
  s.mapID, s.positions, e.yards = 275, {}, 5
  s.bg = assert(ns.ResolveBattleground(275, 761, "cata", "standard"))
  return s, ns, e
end

-- Reproduce the client's observed area names with both coordinate APIs and
-- landmarks unavailable. Capture flags must not be confused with graveyards.
for _, area in ipairs({ "Lighthouse", "Waterworks", "Mine", "Mines" }) do
  local s, ns = client()
  s.area = area
  s.releasePosition = { x = 0.31275517, y = 0.80102750 }
  s.tick()
  local sight = ns.Test.intel[key]
  check(sight and sight.how == "area" and sight.area == area, area .. " still places an enemy when coordinates and POIs are absent")
  local control
  for _, graveyard in ipairs(s.bg.rules.graveyards.nodes) do
    if area:find(graveyard.node.name, 1, true) then
      control = graveyard.node
      check(sight.x ~= graveyard.x and sight.y ~= graveyard.y, "enemy area does not use the resurrection location")
    end
  end
  check(control and sight.x == control.x and sight.y == control.y, "enemy pin uses the known capture point")
  local item = s.items()[1]
  check(item and item.x == control.x and item.y == control.y and item.label == "~", "capture point estimate reaches the map")
  check(support.tooltip(item):find("approximate area anchor", 1, true), "estimated enemy position is clearly labeled")
  check(ns.AreaXY(1461, area) == nil, "Gilneas capture positions cannot leak into another map")
end

do
  local s, ns = client()
  for _, area in ipairs({ "Gilnean Stronghold", "Horde Landing" }) do
    s.area, s.now = area, s.now + 2
    s.tick()
    local sight = ns.Test.intel[key]
    check(sight and sight.how == "area", area .. " has an approximate starting-area position")
    check(s.items()[1].x ~= 0.05 and s.items()[1].label == "~", "starting area is placed outside the unknown column")
  end
  s.area, s.now = "Gilnean Coast", s.now + 5
  s.tick()
  check(ns.Test.intel[key].how == "recent" and ns.Test.intel[key].near == "Horde Landing",
    "the coast right after a base is guessed near that base")
  s.now = s.now + 16
  s.tick()
  support.checkUnknown(s, ns, "the broad coastal area does not imply a specific base")
end

do
  local s, ns = client()
  s.area = "Mines"
  s.pois = { { name = "Mine", position = { x = 0.61, y = 0.41 } } }
  s.tick()
  check(ns.Test.intel[key].x == 0.61 and ns.Test.intel[key].y == 0.41, "live Mine landmark overrides the configured capture point for Mines")
end

do
  local s, ns = client()
  s.bg = assert(ns.ResolveBattleground(275, 761, "retail", "standard"))
  check(ns.AreaXY(275, "Lighthouse") == nil, "Cata capture fallbacks stay isolated from Retail")
  check(ns.AreaXY(275, "Horde Landing") == nil, "Cata start positions stay isolated from Retail")
end
