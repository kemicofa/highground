local _, ns = ...
local Core, Options = ns.Core, ns.Options
Options.Profiles = {}
local Profiles = Options.Profiles
local FLAVOR = ns.CLIENT

function Profiles.Snapshot()
  local snap = { points = {}, weights = {}, specs = {}, options = {}, flavor = FLAVOR }
  for key, value in pairs(Core.db.points or {}) do snap.points[key] = value end
  for key, value in pairs(Core.db.weights or {}) do snap.weights[key] = value end
  for id, values in pairs(Core.db.specRatings or {}) do
    local info, index = Core.specInfo[id], Core.specIndex[id]
    if info and index then
      for stat, value in pairs(values) do snap.specs[info.class .. "." .. index .. "." .. stat] = value end
    end
  end
  for key, def in pairs(Core.SettingDefs.option) do
    if Core.O(key) ~= def.def then snap.options[key] = Core.O(key) end
  end
  return snap
end

-- Fully validate into a separate table before replacing any current values.
-- Unknown/retired keys are ignored for older profiles; known invalid values
-- reject the entire import. Cross-client spec ratings remain isolated.
function Profiles.Prepare(snap)
  if type(snap) ~= "table" then return nil, "invalid profile" end
  local prepared = { points = {}, weights = {}, specRatings = {} }
  local count, skipped = 0, 0
  for field, kind in pairs({ points = "point", weights = "weight", options = "option" }) do
    local source = snap[field] or {}
    if type(source) ~= "table" then return nil, "invalid " .. field end
    local copy = {}
    for key, value in pairs(source) do copy[key] = value end
    if field == "points" then ns.NormalizePointSettings(copy) end
    for key, value in pairs(copy) do
      if Core.SettingDefs[kind][key] then
        local checked, err = Core.ValidateSetting(kind, key, value)
        if checked == nil then return nil, err end
        if kind == "option" then prepared[key] = checked else prepared[field][key] = checked end
        count = count + 1
      else
        skipped = skipped + 1
      end
    end
  end
  for key, def in pairs(Core.SettingDefs.option) do
    if prepared[key] == nil then prepared[key] = def.def end
  end
  if snap.specs ~= nil and type(snap.specs) ~= "table" then return nil, "invalid spec ratings" end
  for key, value in pairs(snap.specs or {}) do
    local class, index, stat
    if type(key) == "string" then class, index, stat = key:match("^(%u+)%.(%d+)%.([ki])$") end
    local id = class and (snap.flavor or FLAVOR) == FLAVOR and Core.classSpecs[class] and Core.classSpecs[class][tonumber(index)]
    if id then
      local checked, err = Core.ValidateSetting("spec", stat, value)
      if checked == nil then return nil, err end
      prepared.specRatings[id] = prepared.specRatings[id] or {}
      prepared.specRatings[id][stat] = checked
      count = count + 1
    else
      skipped = skipped + 1
    end
  end
  local ok, err = Core.ValidateRelations(prepared, prepared.points)
  if not ok then return nil, err end
  return prepared, nil, count, skipped
end

function Profiles.Apply(prepared)
  Core.db.points, Core.db.weights, Core.db.specRatings = prepared.points, prepared.weights, prepared.specRatings
  for key in pairs(Core.SettingDefs.option) do Core.db[key] = prepared[key] end
  wipe(Core.profileCache)
  Core.BuildCurve()
  Options.PointsChanged()
  Options.panel.RefreshAll()
end

function Profiles.SortedPairs(t)
  local keys = {}
  for key in pairs(t) do keys[#keys + 1] = key end
  table.sort(keys)
  local index = 0
  return function()
    index = index + 1
    return keys[index], t[keys[index]]
  end
end

function Profiles.ExportString(snap)
  local parts = { "WB1", "f=" .. snap.flavor }
  for prefix, values in Profiles.SortedPairs({ p = snap.points, w = snap.weights, s = snap.specs, o = snap.options }) do
    for key, value in Profiles.SortedPairs(values) do
      parts[#parts + 1] = prefix .. "." .. key .. "=" .. (type(value) == "boolean" and tostring(value) or Options.Format(value))
    end
  end
  return table.concat(parts, ";")
end

function Profiles.ParseString(text)
  text = (text or ""):gsub("%s+", "")
  if not (text:match("^WB1;") or text:match("^KO1;") or text == "WB1" or text == "KO1") then
    return nil, "not a Warboard profile (should start with WB1;)"
  end
  local snap = { points = {}, weights = {}, specs = {}, options = {}, flavor = FLAVOR }
  for token in text:gmatch("[^;]+") do
    if token ~= "WB1" and token ~= "KO1" then
      local key, value = token:match("^([%w%.]+)=(.+)$")
      if not key then return nil, "invalid profile entry: " .. token end
      if key == "f" then
        if value ~= "cata" and value ~= "retail" then return nil, "unknown profile client" end
        snap.flavor = value
      else
        local prefix, name = key:match("^(%a)%.(.+)$")
        local into = ({ p = snap.points, w = snap.weights, s = snap.specs, o = snap.options })[prefix or ""]
        if into then
          local parsed = tonumber(value)
          if value == "true" then parsed = true elseif value == "false" then parsed = false end
          into[name] = parsed == nil and value or parsed
        end
      end
    end
  end
  return snap
end
