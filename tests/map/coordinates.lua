local support = ...
local key = support.key
local check = support.check
local client = support.client
local tooltip = support.tooltip
local checkUnknown = support.checkUnknown

do
  local s, ns, e = client({ unit = "arena1" })
  e.carrier = true
  s.flags = { { 0.85, 0.8, "Alliance" } }
  s.tick()
  check(ns.Test.intel[key].x == 0.85 and ns.Test.intel[key].by == "flag", "exact flag API sightings remain available")
end

do
  local s, ns = client()
  local x, y = ns.AreaXY(1339, "Silverwing Hold")
  check(x == 0.5 and y == 0.15, "configured anchors apply to every supported map alias")
  check(ns.AreaXY(206, "Silverwing Hold") == nil, "active BG anchors must not leak to another map")
  s.bg = { name = "Eye of the Storm", ui = { 112 }, rules = { map = { zoneCenter = { 0.52, 0.48 } } } }
  x, y = ns.AreaXY(112, "Eye of the Storm")
  check(x == 0.52 and y == 0.48, "zone centers come from the battleground configuration")
end

do
  local s, ns, e = client({ unit = "target" })
  e.yards = 5
  s.tick()
  check(ns.Test.intel[key] ~= nil, "setup produces a sighting")
  s.active = false
  s.tick()
  check(next(ns.Test.intel) == nil, "leaving a match clears intel")
  s.active, s.mapID, e.unit = true, nil, nil
  check(ns.CurrentMapID() == nil, "a new match must not inherit the previous cached map")
  s.mapID = 1460
  s.tick()
  ns.Test.RecordSighting(key, 0.8, 0.8, 40, "Me", s.now)
  s.enterWorld()
  check(next(ns.Test.intel) == nil, "world transitions clear even same-map match sightings")
end

do
  local s, ns = client()
  s.projection = { north = 1000, west = 1000, height = -1000, width = -2000, instance = 726 }
  s.worldPositions.target = { 750, 500, 0, 726 }
  local x, y = ns.UnitXY(206, "target")
  check(x == 0.25 and y == 0.25, "rectangular maps project north/west axes without guessing")
  s.worldPositions.target = { 200, 600, 0, 726 }
  x, y = ns.UnitXY(206, "target")
  check(x == 0.2 and y == 0.8, "a second asymmetric world point preserves horizontal and vertical axes")
  s.worldPositions.target = { 750, 500, 0, 489 }
  check(ns.UnitXY(206, "target") == nil, "coordinates from another world instance must be rejected")
  s.worldPositions.target = { 1100, 500, 0, 726 }
  check(ns.UnitXY(206, "target") == nil, "off-map world coordinates must be rejected")
end

do
  local s, ns = client()
  s.projection = { north = 1000, west = 1000, height = -1000, width = -1000, instance = 726 }
  s.worldPositions.target = { 200, 600, 0, 726 }
  local x, y = ns.UnitXY(206, "target")
  check(x == 0.4 and y == 0.8, "square maps also follow the defined world axes")
end

do
  local s, ns = client()
  s.projection = { north = 1000, west = 1000, height = -1000, width = -2000, instance = 726 }
  s.worldPositions.target = { 750, 500, 0, 726 }
  s.cornerFailures = 1
  check(ns.UnitXY(206, "target") == nil, "unavailable world corners produce no fabricated coordinates")
  local x, y = ns.UnitXY(206, "target")
  check(x == 0.25 and y == 0.25, "a temporary corner failure must recover on the next query")
end

for _, zeroAxis in ipairs({ "width", "height" }) do
  local s, ns = client()
  s.projection = { north = 1000, west = 1000, height = -1000, width = -2000, instance = 726 }
  s.projection[zeroAxis] = 0
  s.worldPositions.target = { 750, 500, 0, 726 }
  check(ns.UnitXY(206, "target") == nil, "zero-sized map " .. zeroAxis .. " cannot be projected")
end

do
  local s, ns = client()
  s.tick()
  s.receive("3:1460:" .. key .. ",9000,8000,3,0,coords,")
  local sight = ns.Test.intel[key]
  check(sight and sight.x == 0.9 and sight.y == 0.8 and sight.how == "coords", "v3 exact coordinates retain their precision")
  check(s.items()[1].label:sub(1, 1) ~= "~", "exact shared coordinates must not acquire an approximate marker")
  s.now = 110
  s.receive("3:1460:" .. key .. ",7000,6000,35,0,nearby,")
  check(ns.Test.intel[key].x == 0.7 and ns.Test.intel[key].how == "nearby", "v3 nearby observations retain their source quality")
  check(s.items()[1].label:sub(1, 1) == "~", "shared approximate observations remain visibly approximate")
  s.now = 120
  s.receive("3:1460:" .. key .. ",0,0,40,0,unknown,")
  checkUnknown(s, ns, "a fresh shared unknown observation removes a stale remote position")
end
