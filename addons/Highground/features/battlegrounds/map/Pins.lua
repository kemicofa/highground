local _, ns = ...
local Util, Theme = ns.Util, ns.Theme

-- Map pin layer shared by the intel map (map/Layer.lua) and the timers
-- (timers/Layer.lua). Uses Blizzard's own map system: a data provider added to
-- the world map and the battlefield map (Shift+M) that acquires pins from
-- an XML template (Pins.xml), exactly like Blizzard's flag pins. The map
-- canvas positions, scales and layers them, so they stay put at any zoom.
--
-- Producers register with MapPins.Add(fn); fn(mapID, width, height) returns
--   { x, y (0-1), ring = colour | nil, icon = atlas | texture, desat,
--     alpha, label, labelColor = colour, mark, size, tooltip = fn(lines),
--     zone = zone item it sits in }
-- or a zone { x, y, radius (0-1 of the map width), ring, alpha, tooltip }.
-- desat: true or a grey amount 0-1.
-- A colour is a theme token name or { r, g, b } (see Theme.Paint).
local MapPins = { stats = { draws = 0, pins = 0 } }
ns.MapPins = MapPins

local layers = {}
function MapPins.Add(fn)
  layers[#layers + 1] = fn
end

-- XML templates and their mixins are global: a standalone addon has its
-- own (<Folder>PinTemplate, <Folder>PinMixin, in its own Pins.xml).
local TEMPLATE = (ns.FRAME_PREFIX or "Highground") .. "PinTemplate"
local ZONE_TEMPLATE = (ns.FRAME_PREFIX or "Highground") .. "ZonePinTemplate"
local stats = MapPins.stats

local PinMixin = CreateFromMixins(MapCanvasPinMixin)
_G[(ns.FRAME_PREFIX or "Highground") .. "PinMixin"] = PinMixin

function PinMixin:OnLoad()
  self:SetScalingLimits(1, 0.9, 1.1)
  self:UseFrameLevelType("PIN_FRAME_LEVEL_VEHICLE_ABOVE_GROUP_MEMBER")
  Theme.Tint(self.Mark, "mapMark", 0.9) -- kill target ring
  -- Map typography stays the game font (ns.UIConfig.map): readable on any map art.
  self.Label:SetFont("Fonts\\ARIALN.TTF", ns.UIConfig.map.fontSize, "OUTLINE")
  self.Label:SetShadowColor(Theme.Color("black"))
  self.Label:SetShadowOffset(1, -1)
end

function PinMixin:OnAcquired(item)
  self.item, item.pin = item, self
  local size = item.size or 22
  self:SetSize(size, size)
  if item.ring then
    Theme.Tint(self.Ring, item.ring, 1)
    self.Ring:Show()
  else
    self.Ring:Hide()
  end
  local icon = item.icon
  self.Icon:SetSize(size * 0.68, size * 0.68)
  if type(icon) == "string" and not icon:find("\\", 1, true) then
    if not pcall(self.Icon.SetAtlas, self.Icon, icon) then
      self.Icon:SetTexture(nil)
    end
  else
    self.Icon:SetTexture(icon)
    self.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  local grey = tonumber(item.desat) or (item.desat and 1 or 0)
  if self.Icon.SetDesaturation then
    self.Icon:SetDesaturation(grey)
  else
    self.Icon:SetDesaturated(grey > 0)
  end
  self.Mark:SetShown(item.mark and true or false)
  self.Label:SetText(item.label or "")
  Theme.Paint(self.Label, item.labelColor or "white")
  self:SetAlpha(item.alpha or 1)
  self:SetPosition(item.x, item.y)
end

-- Hovering an enemy brings up the circle it can be in.
local function Highlight(item, on)
  local pin = item and item.zone and item.zone.pin
  if pin and pin.item == item.zone then pin:SetHighlight(on) end
end

function PinMixin:OnMouseEnter()
  local item = self.item
  Highlight(item, true)
  if not (item and item.tooltip) then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if Util.Guard("map pin tooltip", item.tooltip, GameTooltip) then
    GameTooltip:Show()
  end
end

function PinMixin:OnMouseLeave()
  Highlight(self.item, false)
  GameTooltip_Hide()
end

-- Zone pins live in map units: no scaling limits, so they grow and shrink
-- with the map while enemy pins keep their screen size. A faint fill inside a
-- thin outline in the theme's map colour (mapZone).
local ZonePinMixin = CreateFromMixins(MapCanvasPinMixin)
_G[(ns.FRAME_PREFIX or "Highground") .. "ZonePinMixin"] = ZonePinMixin

function ZonePinMixin:OnLoad()
  self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
  self.Rim:SetTexture(ns.Core.MAP_RING)
  -- How many enemies were last seen here; digits only, the map's font.
  self.Count:SetFont("Fonts\\ARIALN.TTF", ns.UIConfig.map.fontSize + 4, "OUTLINE")
  if self.SetMouseClickEnabled then self:SetMouseClickEnabled(false) end
end

function ZonePinMixin:OnAcquired(item)
  self.item, item.pin = item, self
  local canvas = self:GetMap():GetCanvas()
  local size = math.max(8, 2 * item.radius * canvas:GetWidth())
  self:SetSize(size, size)
  Theme.Tint(self.Disc, item.ring or "mapZone", 1)
  Theme.Tint(self.Rim, item.ring or "mapZone", 1)
  self.Count:SetText(item.count and item.count > 1 and tostring(item.count) or "")
  Theme.Paint(self.Count, "white")
  self:SetHighlight(false)
  self:SetPosition(item.x, item.y)
end

-- Subtle even when hovered, older circles fainter still (item.alpha).
-- Hovering also brings the enemies inside to full strength.
function ZonePinMixin:SetHighlight(on)
  local item = self.item
  local base = item and item.alpha or 1
  self.highlighted = on
  self.Disc:SetAlpha(on and 0.1 or 0.06 * base)
  self.Rim:SetAlpha(on and 0.7 or 0.45 * base)
  self.Count:SetAlpha(on and 1 or base)
  for _, m in ipairs(item and item.members or {}) do
    if m.pin and m.pin.item == m then m.pin:SetAlpha(on and 1 or m.alpha or 1) end
  end
end

function ZonePinMixin:OnMouseEnter()
  self:SetHighlight(true)
  local item = self.item
  if not (item and item.tooltip) then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  if Util.Guard("map zone tooltip", item.tooltip, GameTooltip) then
    GameTooltip:Show()
  end
end

function ZonePinMixin:OnMouseLeave()
  self:SetHighlight(false)
  GameTooltip_Hide()
end

-- Fight rings: a circle around a group member at their live position, drawn
-- by the game's UnitPositionFrame (Lua never learns where). Two frames per
-- map, fill and outline, made out of combat and never shown or hidden after.
-- Units are re-added after a roster, map or size change; otherwise a refresh
-- only sets colours, alpha 0 hiding a unit's ring.
local Rings = { frames = {} }
MapPins.Rings = Rings
local FILL = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local function RingLevel(map)
  local levels = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
  local ok, level = pcall(function() return levels:GetValidFrameLevel("PIN_FRAME_LEVEL_AREA_POI") end)
  return ok and type(level) == "number" and level or (map:GetCanvas():GetFrameLevel() or 0) + 1
end

function Rings.Attach(map)
  if Rings.frames[map] or not (map and map.GetCanvas) or InCombatLockdown() then return end
  local canvas = map:GetCanvas()
  local set = { units = {}, shown = {} }
  for i, texture in ipairs({ FILL, ns.Core.MAP_RING }) do
    local ok, f = pcall(CreateFrame, "UnitPositionFrame", nil, canvas)
    if not (ok and f and f.AddUnit and f.SetUnitColor) then return end
    f:SetAllPoints(canvas)
    f:EnableMouse(false) -- the map and its pins keep every hover and click
    f.ringTexture, f.ringLayer = texture, i
    set[i] = f
  end
  Rings.frames[map] = set
end

-- Whether this map can draw rings now (Blizzard hides group pins on some maps).
function Rings.Ready(map, mapID)
  local display = C_Map and C_Map.GetMapDisplayInfo
  return Rings.frames[map] ~= nil and not (display and Util.read(display, mapID) == true)
end

local function Rebuild(map, set, mapID, size)
  wipe(set.units)
  wipe(set.shown)
  local units, n = ns.UnitTokens.Group()
  set.units[1] = "player"
  for i = 1, n do
    if Util.read(UnitIsUnit, units[i], "player") ~= true then set.units[#set.units + 1] = units[i] end
  end
  for _, f in ipairs(set) do
    f:SetFrameLevel(RingLevel(map))
    f:SetUiMapID(mapID)
    f:ClearUnits()
    for _, unit in ipairs(set.units) do
      f:AddUnit(unit, f.ringTexture, size, size, 1, 1, 1, 0, f.ringLayer, false)
    end
    f:FinalizeUnits()
  end
  set.mapID, set.size, set.dirty = mapID, size, false
end

-- wanted[unit] = alpha; radius: 0-1 of the map width, as zone pins.
function Rings.Draw(map, mapID, wanted, radius)
  local set = Rings.frames[map]
  if not set then return end
  if radius and (set.dirty or set.mapID ~= mapID or math.abs(2 * radius * map:GetCanvas():GetWidth() - (set.size or 0)) > 1) then
    Rebuild(map, set, mapID, math.max(8, 2 * radius * map:GetCanvas():GetWidth()))
  end
  local r, g, b = Theme.Color("mapZone")
  for _, unit in ipairs(set.units) do
    local alpha = wanted[unit] or 0
    if alpha > 0 or set.shown[unit] then
      set[1]:SetUnitColor(unit, r, g, b, 0.1 * alpha)
      set[2]:SetUnitColor(unit, r, g, b, 0.7 * alpha)
      set.shown[unit] = alpha > 0 or nil
    end
  end
end

-- Data provider: refreshes its pins twice a second while the map is open.
-- Pins are updated in place, not released and acquired again: a hovered
-- pin stays shown and its tooltip follows. An enemy keeps its own pin
-- (sortKey); other pins of the same template are reused in order.
local providers = {}

local HighgroundDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

function HighgroundDataProviderMixin:RemoveAllData()
  self:GetMap():RemoveAllPinsByTemplate(ZONE_TEMPLATE)
  self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
  self.pins, self.shown = self.pins or {}, self.shown or {}
  wipe(self.pins); wipe(self.shown)
end

-- Reused between refreshes: this refresh's items, last refresh's pins (in
-- order and by enemy key), the pins taken, each template's next pin and the
-- ringed units' alpha.
local items, previous, previousKeys, used, claimed, cursor, wanted = {}, {}, {}, {}, {}, {}, {}
local function Usable(pin, template)
  return pin and pin.hgTemplate == template and not used[pin] and pin:IsShown()
end

function HighgroundDataProviderMixin:RefreshAllData()
  local map = self:GetMap()
  local mapID = map and map:GetMapID()
  if not mapID then
    self:RemoveAllData()
    return
  end
  -- Pins keep a near-constant screen size as the canvas zooms. Supply the
  -- displayed map dimensions so layers can reserve enough room for icons.
  local canvas = map.GetCanvas and map:GetCanvas()
  local scale = (map.GetCanvasScale and map:GetCanvasScale() or 1)
    / (map.GetGlobalPinScale and map:GetGlobalPinScale() or 1)
  local width = canvas and canvas:GetWidth() * scale
  local height = canvas and canvas:GetHeight() * scale
  wipe(items); wipe(wanted)
  -- Layers return ring items ({ unit, radius, alpha }) only when told the
  -- map can draw them; a guide preview never gets rings.
  local rings, radius = not self.preview and Rings.Ready(map, mapID), nil
  for _, fn in ipairs(self.preview and { self.preview } or layers) do
    local ok, list = Util.Guard("map layer", fn, mapID, width, height, nil, rings)
    if ok and type(list) == "table" then
      for _, item in ipairs(list) do
        if item.unit and rings then
          wanted[item.unit] = math.max(wanted[item.unit] or 0, item.alpha or 1)
          radius = math.max(radius or 0, item.radius)
        elseif item.x and item.y then items[#items + 1] = item end
      end
    elseif not ok then
      stats.lastError = tostring(list):match("^[^\n]*")
    end
  end
  self.pins, self.shown = self.pins or {}, self.shown or {}
  wipe(previous); wipe(previousKeys); wipe(used); wipe(claimed)
  for i, pin in ipairs(self.shown) do previous[i] = pin end
  for key, pin in pairs(self.pins) do previousKeys[key] = pin end
  wipe(self.pins); wipe(self.shown)
  -- Enemies first take back their own pin.
  for i, item in ipairs(items) do
    local pin = item.sortKey and previousKeys[item.sortKey]
    if Usable(pin, item.radius and ZONE_TEMPLATE or TEMPLATE) then used[pin], claimed[i] = true, pin end
  end
  cursor[TEMPLATE], cursor[ZONE_TEMPLATE] = 1, 1
  for i, item in ipairs(items) do
    local template = item.radius and ZONE_TEMPLATE or TEMPLATE
    local pin = claimed[i]
    while not pin and cursor[template] <= #previous do
      local candidate = previous[cursor[template]]
      cursor[template] = cursor[template] + 1
      if Usable(candidate, template) then pin = candidate; used[pin] = true end
    end
    if pin then
      pin:OnAcquired(item)
    else
      pin = map:AcquirePin(template, item)
      pin.hgTemplate, used[pin] = template, true
    end
    self.shown[#self.shown + 1] = pin
    if item.sortKey then self.pins[item.sortKey] = pin end
  end
  for _, pin in ipairs(previous) do
    if not used[pin] and pin:IsShown() then map:RemovePin(pin) end
  end
  -- A hovered pin's tooltip and highlight follow its new item.
  local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
  if owner and used[owner] then owner:OnMouseEnter() end
  Util.Guard("map rings", Rings.Draw, map, mapID, wanted, radius)
  stats.draws, stats.pins = stats.draws + 1, #items
end

function HighgroundDataProviderMixin:OnMapChanged()
  self:RefreshAllData()
end

-- Once per map frame; Nearby's world layer (world/Map.lua) attaches too.
local function Attach(mapFrame)
  if not (mapFrame and mapFrame.AddDataProvider) or providers[mapFrame] then
    return
  end
  local p = CreateFromMixins(HighgroundDataProviderMixin)
  mapFrame:AddDataProvider(p)
  providers[mapFrame] = p
  Util.Guard("map rings", Rings.Attach, mapFrame)
end
MapPins.Attach = Attach

-- A guide can supply isolated data to an actual map canvas. It still uses
-- this provider, the XML pin template, pooling and the normal pin renderer.
function MapPins.SetPreview(mapFrame, producer)
  Attach(mapFrame)
  local provider = providers[mapFrame]
  if not provider then return false end
  provider.preview = producer
  provider:RefreshAllData()
  return true
end

function MapPins.GetPin(mapFrame, key)
  local provider = providers[mapFrame]
  return provider and provider.pins and provider.pins[key]
end

function MapPins.Providers()
  local n = 0
  for _ in pairs(providers) do
    n = n + 1
  end
  return n
end

-- Refresh the open maps.
function MapPins.Refresh()
  for mapFrame, p in pairs(providers) do
    if mapFrame:IsShown() then
      local ok, err = Util.Guard("map pins", p.RefreshAllData, p)
      if not ok then
        stats.lastError = tostring(err):match("^[^\n]*")
      end
    end
  end
end

Util.Events({
  PLAYER_LOGIN = function()
    Attach(WorldMapFrame)
    Attach(BattlefieldMapFrame)
  end,
  ADDON_LOADED = function(_, name)
    if name == "Blizzard_BattlefieldMap" then
      Attach(BattlefieldMapFrame)
    elseif name == "Blizzard_WorldMap" then
      Attach(WorldMapFrame)
    end
  end,
  GROUP_ROSTER_UPDATE = function() for _, set in pairs(Rings.frames) do set.dirty = true end end,
  -- A map first opened in combat gets its rings afterwards.
  PLAYER_REGEN_ENABLED = function()
    for mapFrame in pairs(providers) do Util.Guard("map rings", Rings.Attach, mapFrame) end
  end,
}, "map pins", "battlegrounds")
-- Live pins redraw while a battleground is tracked; stopping clears them.
-- Guide samples and the test pin redraw when they change.
ns.PvPEvents.Every(0.5, MapPins.Refresh, "map pins", function() return ns.IsActive and ns.IsActive() end,
  "battlegrounds", MapPins.Refresh)

-- Older names used by other subsystems and tests.
ns.AddMapLayer = MapPins.Add
ns.pinStats = stats
ns.pinProviders = MapPins.Providers
