-- Exercise the real data provider and pin mixin against a map canvas boundary.
return function(sim, env)
  env.CreateFromMixins = function(...)
    local result = {}
    for i = 1, select("#", ...) do for key, value in pairs(select(i, ...) or {}) do result[key] = value end end
    return result
  end
  env.MapCanvasPinMixin = {}
  env.MapCanvasDataProviderMixin = { GetMap = function(provider) return provider.map end }
  env.CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function() return x, y end } end
  env.C_Map = {
    GetBestMapForUnit = function() return sim.mapID end,
    GetMapInfo = function() return { name = sim.mapName } end,
    GetPlayerMapPosition = function(_, token)
      local unit = sim.units[token]; return unit and unit.position
    end,
    GetWorldPosFromMapPos = function() end,
  }
  local function canvas(name)
    local map = env.CreateFrame("Frame", name, env.UIParent)
    map:SetSize(name == "WorldMapFrame" and 1000 or 300, name == "WorldMapFrame" and 667 or 200)
    function map:GetCanvas() return self end
    function map:GetCanvasScale() return self.canvasScale or 1 end
    function map:GetGlobalPinScale() return 1 end
    map.providers, map.pins, map.pool = {}, {}, {}
    function map:GetMapID() return sim.mapID end
    function map:AddDataProvider(provider)
      provider.map = self; self.providers[#self.providers + 1] = provider
    end
    function map:RemoveAllPinsByTemplate(template)
      for _, pin in ipairs(self.pins) do
        if pin.template == template then pin:Hide(); self.pool[#self.pool + 1] = pin end
      end
      self.pins = {}
    end
    function map:AcquirePin(template, item)
      local pin = table.remove(self.pool)
      if not pin then
        local definition = assert(sim.templates[template], "Missing XML template: " .. template)
        pin = env.CreateFrame("Frame", nil, self)
        pin.template = template
        for key, value in pairs(assert(env[definition.mixin])) do pin[key] = value end
        for kind, key in definition.body:gmatch('<(%w+)%s+parentKey="([^"]+)"') do
          pin[key] = env.CreateFrame(kind, nil, pin)
        end
        pin:OnLoad()
      end
      pin:Show(); pin:OnAcquired(item)
      self.pins[#self.pins + 1] = pin
      return pin
    end
    return map
  end
  env.WorldMapFrame = canvas("WorldMapFrame")
  env.BattlefieldMapFrame = canvas("BattlefieldMapFrame")
end
