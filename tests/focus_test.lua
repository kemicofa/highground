local support = dofile("tests/focus/fixture.lua")
local equal = support.equal
assert(loadfile("tests/focus/ranking.lua"))(support)
assert(loadfile("tests/focus/markers.lua"))(support)

for _, s in ipairs(support.scenarios) do equal(s.db.pressureError, nil, "valid snapshots do not produce marker errors") end
print("focus: " .. support.count() .. " assertions passed across " .. #support.scenarios .. " scenarios")
