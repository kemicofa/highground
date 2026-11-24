-- Exercise the real data provider and pin mixin against a map canvas boundary.
return function(sim, env)
  env.CreateFromMixins = function(...)
    local result = {}
    for i = 1, select("#", ...) do for key, value in pairs(select(i, ...) or {}) do result[key] = value end end
    return result
  end
  env.MapCanvasPinMixin = {
    GetMap = function(pin) return pin:GetParent() end,
    SetPosition = function(pin, x, y)
      pin.x, pin.y = x, y
      local map = pin:GetParent()
      pin:ClearAllPoints(); pin:SetPoint("CENTER", map, "TOPLEFT", x * map:GetWidth(), -y * map:GetHeight())
    end,
  }
  env.MapCanvasDataProviderMixin = { GetMap = function(provider) return provider.map end }
  env.CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function() return x, y end } end
  env.C_Map = {
    GetBestMapForUnit = function() return sim.mapID end,
    -- Only the current map has a known name; others exist unnamed.
    GetMapInfo = function(id) return { name = (id == nil or id == sim.mapID) and sim.mapName or nil } end,
    GetPlayerMapPosition = function(_, token)
      local unit = sim.units[token]; return unit and unit.position
    end,
    GetWorldPosFromMapPos = function() end,
  }
  -- The game's UnitPositionFrame draws units where Lua never sees them: the
  -- simulated one records the units it was given and each one's alpha.
  local create = env.CreateFrame
  env.CreateFrame = function(kind, ...)
    local f = create(kind, ...)
    if kind == "UnitPositionFrame" then
      f.units, f.alpha = {}, {}
      function f:SetUiMapID(id) self.uiMapID = id end
      function f:ClearUnits() self.units, self.alpha = {}, {} end
      function f:AddUnit(unit, texture, width, _, _, _, _, alpha) self.units[unit], self.alpha[unit] = { texture = texture, size = width }, alpha end
      function f:FinalizeUnits() self.finalized = true end
      function f:SetUnitColor(unit, _, _, _, alpha)
        assert(self.units[unit], "colour for a unit never added: " .. unit)
        self.alpha[unit] = alpha
      end
    end
    return f
  end
  local function canvas(name)
    local map = env.CreateFrame("Frame", name, env.UIParent)
    map:SetSize(name == "WorldMapFrame" and 1000 or 300, name == "WorldMapFrame" and 667 or 200)
    map:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 20, -60)
    function map:GetCanvas() return self end
    function map:GetCanvasScale() return self.canvasScale or 1 end
    function map:GetGlobalPinScale() return 1 end
    map.providers, map.pins, map.pool = {}, {}, {}
    function map:GetMapID() return self.mapID or sim.mapID end
    function map:SetMapID(id)
      self.mapID = id
      for _, provider in ipairs(self.providers) do provider:OnMapChanged() end
    end
    function map:AddDataProvider(provider)
      provider.map = self; self.providers[#self.providers + 1] = provider
    end
    function map:RemoveAllPinsByTemplate(template)
      local keep = {}
      self.pool[template] = self.pool[template] or {}
      for _, pin in ipairs(self.pins) do
        if pin.template == template then
          pin:Hide(); table.insert(self.pool[template], pin)
        else
          keep[#keep + 1] = pin
        end
      end
      self.pins = keep
    end
    function map:RemovePin(pin)
      for i, active in ipairs(self.pins) do
        if active == pin then table.remove(self.pins, i); break end
      end
      self.pool[pin.template] = self.pool[pin.template] or {}
      pin:Hide(); table.insert(self.pool[pin.template], pin)
    end
    function map:AcquirePin(template, item)
      local pin = self.pool[template] and table.remove(self.pool[template])
      if not pin then
        local definition = assert(sim.templates[template], "Missing XML template: " .. template)
        pin = env.CreateFrame("Frame", nil, self)
        pin.template = template
        for key, value in pairs(assert(env[definition.mixin])) do pin[key] = value end
        for kind, key in definition.body:gmatch('<(%w+)%s+parentKey="([^"]+)"') do
          pin[key] = env.CreateFrame(kind, nil, pin)
        end
        pin:OnLoad()
        pin:EnableMouse(true)
        pin:SetScript("OnEnter", pin.OnMouseEnter); pin:SetScript("OnLeave", pin.OnMouseLeave)
      end
      pin:Show(); pin:OnAcquired(item)
      self.pins[#self.pins + 1] = pin
      return pin
    end
    return map
  end
  env.WorldMapFrame = canvas("WorldMapFrame")
  env.BattlefieldMapFrame = canvas("BattlefieldMapFrame")
  env.OpenWorldMap = function(id)
    env.WorldMapFrame:Show()
    env.WorldMapFrame:SetMapID(id or sim.mapID)
  end
end
