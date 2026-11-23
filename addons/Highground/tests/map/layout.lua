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
    local enemies, counted = {}, 0
    for _, item in ipairs(items) do
      if item.sortKey then enemies[#enemies + 1] = item
      elseif item.label and item.label:match("^%+%d+$") then counted = counted + tonumber(item.label:sub(2)) end
    end
    check(#enemies + counted == (position[1] and 15 or 0), position[1] and "every stacked enemy is drawn or counted"
      or "enemies without a position get no pins")
    check(#s.zones(unpack(size)) == (position[1] and 1 or 0), "one shared circle for one area")
    local prior = {}
    for _, item in ipairs(again) do if item.sortKey then prior[item.sortKey] = item end end
    for i, item in ipairs(enemies) do
      check(item.x > 0 and item.x < 1 and item.y > 0 and item.y < 1, "stacked markers stay inside the map")
      check(item.x == prior[item.sortKey].x and item.y == prior[item.sortKey].y, "redraws keep a stable enemy order")
      check(item.label == "", "a crowd's ages move to the circle's tooltip")
      for j = 1, i - 1 do
        local dx, dy = (item.x - enemies[j].x) * size[1], (item.y - enemies[j].y) * size[2]
        check(math.sqrt(dx * dx + dy * dy) >= item.size * 0.6, "icons in a circle do not pile up on either canvas size")
      end
    end
  end
  for key, it in pairs(ns.Test.intel) do
    check(it.x == (position[1] or nil) and it.y == (position[2] or nil), "display spacing never changes recorded locations")
  end
end
