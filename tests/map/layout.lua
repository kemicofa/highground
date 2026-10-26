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
    check(#items == 15, "every stacked enemy remains visible")
    local prior = {}
    for _, item in ipairs(again) do prior[item.sortKey] = item end
    for i, item in ipairs(items) do
      check(item.x > 0 and item.x < 1 and item.y > 0 and item.y < 1, "stacked markers stay inside the map")
      check(item.x == prior[item.sortKey].x and item.y == prior[item.sortKey].y, "redraws keep a stable enemy order")
      for j = 1, i - 1 do
        local dx, dy = math.abs(item.x - items[j].x) * size[1], math.abs(item.y - items[j].y) * size[2]
        check(dx >= 39.9 or dy >= 41.9, "icons and age labels do not overlap on either canvas size")
      end
    end
  end
  for key, it in pairs(ns.Test.intel) do
    check(it.x == (position[1] or nil) and it.y == (position[2] or nil), "display spacing never changes recorded locations")
  end
end
