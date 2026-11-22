local _, ns = ...

-- SavedVariables can hold anything after a bad import, a manual edit or a
-- different release. These helpers repair shapes without discarding valid
-- user values, copy defaults instead of aliasing them, bound collections
-- and run versioned upgrades once. They never create saved data on reads.
local Saved = {}
ns.Saved = Saved

local SCALAR = { string = true, number = true, boolean = true }

-- A deep copy of plain data. Functions, userdata and nesting beyond 16
-- levels (including cycles) are left out; shared subtables become copies.
function Saved.Copy(value, depth)
  if type(value) ~= "table" then return value end
  depth = depth or 0
  if depth >= 16 then return nil end
  local out = {}
  for key, child in pairs(value) do
    if SCALAR[type(key)] and (SCALAR[type(child)] or type(child) == "table") then
      out[key] = Saved.Copy(child, depth + 1)
    end
  end
  return out
end

-- parent[key] as a table, replacing a missing or wrong-typed value.
function Saved.Table(parent, key)
  local value = parent[key]
  if type(value) ~= "table" then
    value = {}
    parent[key] = value
  end
  return value
end

-- Fill missing or wrong-typed fields from defaults. Values of the right
-- type are kept; default tables merge recursively and are always copied.
function Saved.Defaults(db, defaults)
  for key, default in pairs(defaults) do
    local value = db[key]
    if type(default) == "table" then
      if type(value) == "table" then Saved.Defaults(value, default) else db[key] = Saved.Copy(default) end
    elseif type(value) ~= type(default) then
      db[key] = default
    end
  end
  return db
end

-- Clear fields that do not match schema[key], so the caller's defaults apply
-- again. A rule is a type name ("string", "number", "boolean", "table") or
-- { type = "number", min = a, max = b }. NaN and infinite numbers count as
-- damaged. Returns how many fields were cleared.
function Saved.Check(db, schema)
  local cleared = 0
  for key, rule in pairs(schema) do
    local value, kind = db[key], type(rule) == "table" and rule.type or rule
    local bad = value ~= nil and type(value) ~= kind
    if not bad and kind == "number" and value ~= nil then
      bad = value ~= value or math.abs(value) == math.huge
        or type(rule) == "table" and (rule.min and value < rule.min or rule.max and value > rule.max) or false
    end
    if bad then db[key], cleared = nil, cleared + 1 end
  end
  return cleared
end

-- Number of keys in a table (0 for anything else).
function Saved.Count(map)
  local count = 0
  if type(map) == "table" then for _ in pairs(map) do count = count + 1 end end
  return count
end

-- Whether a keyed collection may take a new key without exceeding limit.
function Saved.Room(map, limit)
  return Saved.Count(map) < limit
end

-- Run fn(db) once per version. db[field] records the last applied version;
-- a missing or damaged value counts as 1, the first release. Upgrades must
-- be idempotent: a damaged marker runs them again.
function Saved.Migrate(db, field, version, fn)
  local current = db[field]
  if type(current) ~= "number" or current ~= current then current = 1 end
  if current < version then
    fn(db)
    db[field] = version
  end
end
