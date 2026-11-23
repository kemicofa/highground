local support = ...
local check = support.check

for _, position in ipairs({ { 0.5, 0.5 }, { 0.99, 0.99 }, { false, false } }) do
  local s, ns = support.client()
  s.tick()
  for i = 1, 15 do
    local key = "Stack" .. i .. "-Realm"
    ns.enemies[key] = { key = key, display = "Stack" .. i, class = "MAGE" }
    ns.Test.RecordSighting(key, position[1] or nil, position[2] or nil, 80, "Me", s.now,
      "same area", position[1] and "area" or "unknown")
  end
  for _, size in ipairs({ { 1000, 667 }, { 300, 200 } }) do
    local items, again = s.items(unpack(size)), s.items(unpack(size))
    local enemies = {}
    for _, item in ipairs(items) do
      if item.sortKey then enemies[#enemies + 1] = item end
    end
    local zone = s.zones(unpack(size))[1]
    check(position[1] and zone.count == 15 or not position[1] and zone == nil,
      position[1] and "the circle counts every stacked enemy" or "enemies without a position get no pins")
    check(#s.zones(unpack(size)) == (position[1] and 1 or 0), "one shared circle for one area")
    local prior = {}
    for _, item in ipairs(again) do if item.sortKey then prior[item.sortKey] = item end end
    for i, item in ipairs(enemies) do
      check(item.x > 0 and item.x < 1 and item.y > 0 and item.y < 1, "stacked markers stay inside the map")
      check(item.x == prior[item.sortKey].x and item.y == prior[item.sortKey].y, "redraws keep a stable enemy order")
      check(item.label == "", "a crowd's ages move to the circle's tooltip")
      for j = 1, i - 1 do
        local dx, dy = (item.x - enemies[j].x) * size[1], (item.y - enemies[j].y) * size[2]
        check(math.sqrt(dx * dx + dy * dy) >= item.size * 0.9, "icons around a circle do not pile up on either canvas size")
      end
    end
  end
  for key, it in pairs(ns.Test.intel) do
    check(it.x == (position[1] or nil) and it.y == (position[2] or nil), "display spacing never changes recorded locations")
  end
end

do -- A circle marks roughly where an enemy was last seen: it never grows.
  local s, ns = support.client()
  s.tick()
  local key = "Roamer-Realm"
  ns.enemies[key] = { key = key, display = "Roamer", class = "ROGUE" }
  ns.Test.RecordSighting(key, 0.5, 0.5, 80, "Me", s.now, "same area", "area")
  local fresh = s.zones(1000, 667)[1]
  s.now = s.now + 100
  local old = s.zones(1000, 667)[1]
  check(fresh and old and fresh.radius == old.radius, "the circle keeps its size as the sighting ages")
  check(fresh.radius * 1000 <= 40.5, "and stays within about 40 yards")
end
