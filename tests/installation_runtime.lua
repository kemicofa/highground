-- Load installed ZIP contents in one simulated client, including dependency
-- order and per-addon SavedVariables restoration before ADDON_LOADED.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)")
local new = dofile(HERE .. "../tools/wowsim/battleground/runtime.lua")

return function(root, build, folders, saved, reverse, configure, disabled)
  local installed, order = {}, {}
  saved, disabled = saved or {}, disabled or {}
  for _, name in ipairs(folders) do
    local base = root .. "/" .. name .. "/"
    local path = base .. name .. (build == 40402 and "_Cata" or "") .. ".toc"
    local file = io.open(path)
    if not file then path = base .. name .. ".toc"; file = assert(io.open(path)) end
    local entry = { name = name, files = {}, metadata = {} }
    for line in file:lines() do
      local key, value = line:match("^##%s*([%w%-]+):%s*(.-)%s*$")
      if key then entry.metadata[key] = value
      elseif line:match("%S") and not line:match("^%s*#") then
        entry.files[#entry.files + 1] = base .. line:match("^%s*(.-)%s*$"):gsub("\\", "/")
      end
    end
    file:close()
    installed[name] = entry
    order[#order + 1] = name
  end
  table.sort(order, function(a, b) if reverse then return a > b else return a < b end end)
  local legacy = build == 40402 or build == 11508 or build == 20505
  local sim = new(legacy and "cata" or "retail", nil, function(s, e)
    s.addon, s.manifest = "Installation", root .. "/__empty.toc"
    s.namespaces, s.loadedAddons = {}, {}
    e.GetBuildInfo = function() return "test", "1", "", build end
    e.C_AddOns.GetAddOnMetadata = function(name, key) return installed[name] and installed[name].metadata[key] end
    e.C_AddOns.IsAddOnLoaded = function(name) return s.loadedAddons[name] == true end
    e.C_AddOns.DoesAddOnExist = function(name) return installed[name] ~= nil end
    e.C_AddOns.GetAddOnEnableState = function(name) return installed[name] and not disabled[name] and 2 or 0 end
    local create = e.CreateFrame
    e.CreateFrame = function(kind, name, ...)
      assert(not name or not e[name], "duplicate frame: " .. tostring(name))
      return create(kind, name, ...)
    end
    dofile(HERE .. "../tools/wowsim/geometry.lua")(s)
    if configure then configure(s, e) end
  end)
  local health = sim.assertHealthy
  function sim:assertHealthy()
    local active, variable = self.ns, self.savedVariable
    for name, namespace in pairs(self.namespaces) do
      self.ns, self.savedVariable = namespace, name .. "DB"
      health(self)
    end
    self.ns, self.savedVariable = active, variable
  end
  local loading = {}
  local function load(name)
    if sim.loadedAddons[name] or disabled[name] then return end
    assert(not loading[name], "dependency cycle: " .. name)
    local entry = assert(installed[name], "missing required addon: " .. name)
    loading[name] = true
    for dependency in (entry.metadata.Dependencies or ""):gmatch("[^,%s]+") do
      load(dependency)
      assert(sim.loadedAddons[dependency], "disabled required addon: " .. dependency)
    end
    for dependency in (entry.metadata.OptionalDeps or ""):gmatch("[^,%s]+") do
      if installed[dependency] then load(dependency) end
    end
    sim.addon, sim.ns, sim.metadata = name, {}, entry.metadata
    sim.namespaces[name] = sim.ns
    for _, path in ipairs(entry.files) do sim:load(path) end
    for _, field in ipairs({ "SavedVariables", "SavedVariablesPerCharacter" }) do
      for variable in (entry.metadata[field] or ""):gmatch("[^,%s]+") do sim.env[variable] = saved[variable] end
    end
    sim.loadedAddons[name] = true
    sim:event("ADDON_LOADED", name)
    loading[name] = nil
  end
  for _, name in ipairs(order) do load(name) end
  local primary = sim.loadedAddons.Highground and "Highground" or sim.loadedAddons.HighgroundBattlegrounds and "HighgroundBattlegrounds"
  for _, name in ipairs(order) do
    if not primary and sim.namespaces[name] and sim.namespaces[name].Core then primary = name end
  end
  sim.addon = assert(primary, "installation needs a UI addon")
  sim.ns, sim.savedVariable = sim.namespaces[sim.addon], sim.addon .. "DB"
  function sim:snapshot()
    local result = {}
    for _, entry in pairs(installed) do
      for _, field in ipairs({ "SavedVariables", "SavedVariablesPerCharacter" }) do
        for variable in (entry.metadata[field] or ""):gmatch("[^,%s]+") do result[variable] = self.env[variable] end
      end
    end
    local function copy(value)
      if type(value) ~= "table" then return value end
      local out = {}; for key, item in pairs(value) do out[key] = copy(item) end; return out
    end
    return copy(result)
  end
  sim:event("PLAYER_LOGIN")
  sim:event("PLAYER_ENTERING_WORLD")
  sim:advance(1)
  return sim
end
