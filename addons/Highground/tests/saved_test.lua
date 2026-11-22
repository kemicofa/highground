local t = dofile("../../tools/harness.lua")("saved data")
local ns = {}
assert(loadfile("libs/core/Saved.lua"))("Highground", ns)
local Saved = ns.Saved

t.test("copies are deep, plain and never aliased", function()
  local shared = { 1, 2 }
  local source = { a = shared, b = shared, f = print, nested = { deep = { x = true } }, [print] = 1 }
  local copy = Saved.Copy(source)
  assert(copy ~= source and copy.a ~= shared and copy.a ~= copy.b, "every table is a new copy")
  t.equal(copy.a[2], 2, "values copied")
  t.equal(copy.f, nil, "functions dropped")
  t.equal(copy[print], nil, "function keys dropped")
  t.equal(copy.nested.deep.x, true, "nested values copied")
  local cycle = {}
  cycle.self = cycle
  local level, depth = Saved.Copy(cycle), 0
  while level do depth, level = depth + 1, level.self end
  t.equal(depth, 16, "cycles end at the depth limit")
end)

t.test("tables are repaired without replacing valid ones", function()
  local db = { list = { 1 }, broken = "oops" }
  local list = Saved.Table(db, "list")
  t.equal(list[1], 1, "valid table kept")
  t.equal(type(Saved.Table(db, "broken")), "table", "wrong type replaced")
  t.equal(type(Saved.Table(db, "missing")), "table", "missing table created")
end)

t.test("defaults fill gaps and fix types but keep user values", function()
  local defaults = { rows = 40, sound = true, mode = "essential", alerts = { channels = {}, volume = 1 } }
  local db = { rows = 12, sound = false, mode = 7, alerts = { volume = "loud", extra = "kept" } }
  Saved.Defaults(db, defaults)
  t.equal(db.rows, 12, "user number kept")
  t.equal(db.sound, false, "explicit false kept")
  t.equal(db.mode, "essential", "wrong type reset")
  t.equal(db.alerts.volume, 1, "nested wrong type reset")
  t.equal(db.alerts.extra, "kept", "unknown nested values kept")
  assert(db.alerts.channels ~= defaults.alerts.channels, "default tables are copied")
  db.alerts.channels.x = true
  t.equal(defaults.alerts.channels.x, nil, "changing saved data never changes defaults")
  local fresh = Saved.Defaults({}, defaults)
  assert(fresh.alerts ~= defaults.alerts, "fresh tables are copies too")
  local damaged = Saved.Defaults({ alerts = "x" }, defaults)
  t.equal(damaged.alerts.volume, 1, "a damaged table is replaced by a copy")
end)

t.test("checks clear damaged values so defaults apply again", function()
  local db = { rows = "many", fade = 0 / 0, forget = math.huge, size = 999, small = 5, ok = 8, on = 1, flag = false,
    positions = "x", windows = {}, extra = "kept" }
  local cleared = Saved.Check(db, { rows = "number", fade = "number", forget = "number",
    size = { type = "number", min = 1, max = 20 }, small = { type = "number", min = 1, max = 20 },
    ok = { type = "number", min = 1, max = 20 }, on = "boolean", flag = "boolean", positions = "table",
    windows = "table", missing = "string" })
  t.equal(cleared, 6, "six damaged fields")
  for _, key in ipairs({ "rows", "fade", "forget", "size", "on", "positions" }) do t.equal(db[key], nil, key .. " cleared") end
  t.equal(db.small, 5, "in-range number kept")
  t.equal(db.flag, false, "false kept")
  t.equal(type(db.windows), "table", "table kept")
  t.equal(db.extra, "kept", "fields outside the schema are untouched")
end)

t.test("migrations run once, tolerate damaged markers and skip newer data", function()
  local runs = 0
  local function Upgrade(db) runs = runs + 1; db.rows = 40 end
  local db = {}
  Saved.Migrate(db, "rowsVersion", 2, Upgrade)
  Saved.Migrate(db, "rowsVersion", 2, Upgrade)
  t.equal(runs, 1, "one run")
  t.equal(db.rowsVersion, 2, "version recorded")
  db.rowsVersion = "2"
  Saved.Migrate(db, "rowsVersion", 2, Upgrade)
  t.equal(runs, 2, "a damaged marker reruns the idempotent upgrade")
  t.equal(db.rowsVersion, 2, "and repairs the marker")
  db.rowsVersion = 5
  Saved.Migrate(db, "rowsVersion", 2, Upgrade)
  t.equal(runs, 2, "data from a newer release is not downgraded")
  t.equal(Saved.Count({ 1, 2, x = 3 }), 3, "count")
  t.equal(Saved.Count("x"), 0, "count of a damaged value")
  t.equal(Saved.Room({ 1, 2 }, 2), false, "full collection")
  t.equal(Saved.Room({ 1 }, 2), true, "room left")
end)

t.finish("Saved data: " .. t.tests .. " tests, " .. t.checks .. " checks")
