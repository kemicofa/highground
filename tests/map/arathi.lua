local support = ...
local check, key = support.check, support.key
local function client(mapID)
  local s, ns, e = support.client({ unit = "target" })
  s.mapID, s.positions, e.yards = mapID or 1461, {}, 5
  s.bg = assert(ns.ResolveBattleground(s.mapID, 529, "cata", "standard"))
  return s, ns, e
end

-- No coordinates or POIs: named Cata areas still place approximate pins.
for _, mapID in ipairs({ 93, 1461 }) do
  local s, ns = client(mapID)
  for _, area in ipairs({ "Stables", "Blacksmith", "Farm", "Lumber Mill", "Gold Mine", "Trollbane Hall", "Defiler's Den" }) do
    s.area, s.now = area, s.now + 2
    s.tick()
    local sight = ns.intel[key]
    check(sight and sight.how == "area" and sight.area == area, area .. " gets an approximate position without client coordinates")
    local items = s.items()
    check(#items == 1 and items[1].x > 0.3 and items[1].x < 0.7 and items[1].y > 0.1 and items[1].y < 0.75,
      area .. " reaches the playable map instead of the unknown column")
    check(items[1].label == "~" and support.tooltip(items[1]):find("approximate area anchor", 1, true),
      "fallback area positions remain visibly approximate")
  end
  s.area, s.now = "Arathi Basin", s.now + 5
  s.tick()
  local sight = ns.intel[key]
  check(sight.how == "recent" and sight.near == "Defiler's Den" and sight.area == "Arathi Basin",
    "leaving a node for the road keeps a guess near the node just left")
  check(sight.x == 0.6547 and sight.r > 80, "the guess sits on the left anchor with a widened radius")
  local item = s.items()[1]
  check(item.x ~= 0.05 and item.label == "~" and support.tooltip(item):find("defiler's den moments before", 1, true),
    "the recent-area guess reaches the map, visibly approximate")
  s.now = s.now + 16
  s.tick()
  support.checkUnknown(s, ns, "a map-wide area cannot locate a fight on an Arathi road")
  check(ns.AreaXY(206, "Stables") == nil, "Arathi fallback anchors cannot leak onto another map")
end

do
  local s, ns = client()
  s.area = "Lumber Mill"
  s.pois = { { name = "Stables", position = { x = 0.38, y = 0.29 } } }
  s.tick() -- cache a partial landmark list
  s.pois[2] = { name = "Lumber Mill", position = { x = 0.41, y = 0.56 } }
  s.poiUpdated()
  s.now = s.now + 2
  s.tick()
  check(ns.intel[key].x == 0.41 and ns.intel[key].y == 0.56, "late client landmarks replace fallback anchors")
  check(select(3, ns.AreaXY(s.mapID, s.area)) == "landmark", "partial landmark cache refreshes on POI updates")
end

for _, badPosition in ipairs({ { x = 0, y = 0 }, { x = 2, y = 0.3 }, { x = 0.4 } }) do
  local s, ns = client()
  s.area = "Blacksmith"
  s.pois = { { name = s.area, position = badPosition } }
  s.tick()
  check(ns.intel[key].how == "area" and ns.intel[key].x == 0.4622, "invalid landmark positions cannot suppress a usable fallback")
  s.pois[1].position = { x = 0.46, y = 0.45 }
  s.now = s.now + 2
  s.tick()
  check(ns.intel[key].x == 0.46, "invalid landmark samples are not cached")
end

do
  local s, ns = client()
  s.area, s.poiError = "Farm", true
  s.pois = { { name = s.area, position = { x = 0.56, y = 0.60 } } }
  s.tick()
  check(ns.intel[key] and ns.intel[key].how == "area" and not s.db.intelErr,
    "an unavailable landmark detail API still permits configured area sightings")
end
