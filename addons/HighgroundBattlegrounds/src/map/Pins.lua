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
  self.item = item
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
-- with the map while enemy pins keep their screen size. Faint until hovered.
local ZonePinMixin = CreateFromMixins(MapCanvasPinMixin)
_G[(ns.FRAME_PREFIX or "Highground") .. "ZonePinMixin"] = ZonePinMixin

function ZonePinMixin:OnLoad()
  self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
  Theme.Tint(self.Rim, "black", 0.55) -- a soft dark edge around the faint fill
  if self.SetMouseClickEnabled then self:SetMouseClickEnabled(false) end
end

function ZonePinMixin:OnAcquired(item)
  self.item, item.pin = item, self
  local canvas = self:GetMap():GetCanvas()
  local size = math.max(8, 2 * item.radius * canvas:GetWidth())
  self:SetSize(size, size)
  Theme.Tint(self.Disc, item.ring or "mapLabel", 0.22)
  self:SetHighlight(false)
  self:SetPosition(item.x, item.y)
end

function ZonePinMixin:SetHighlight(on)
  self:SetAlpha(on and 1 or (self.item and self.item.alpha or 0.3))
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

-- Data provider: rebuilds its pins twice a second while the map is open.
local providers = {}

local HighgroundDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

function HighgroundDataProviderMixin:RemoveAllData()
  self:GetMap():RemoveAllPinsByTemplate(ZONE_TEMPLATE)
  self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
  self.pins = self.pins or {}
  wipe(self.pins)
end

function HighgroundDataProviderMixin:RefreshAllData()
  self:RemoveAllData()
  local map = self:GetMap()
  local mapID = map and map:GetMapID()
  if not mapID then
    return
  end
  -- Pins keep a near-constant screen size as the canvas zooms. Supply the
  -- displayed map dimensions so layers can reserve enough room for icons.
  local canvas = map.GetCanvas and map:GetCanvas()
  local scale = (map.GetCanvasScale and map:GetCanvasScale() or 1)
    / (map.GetGlobalPinScale and map:GetGlobalPinScale() or 1)
  local width = canvas and canvas:GetWidth() * scale
  local height = canvas and canvas:GetHeight() * scale
  local n = 0
  for _, fn in ipairs(self.preview and { self.preview } or layers) do
    local ok, items = Util.Guard("map layer", fn, mapID, width, height)
    if ok and type(items) == "table" then
      for _, item in ipairs(items) do
        if item.x and item.y then
          local pin = map:AcquirePin(item.radius and ZONE_TEMPLATE or TEMPLATE, item)
          if item.sortKey then self.pins[item.sortKey] = pin end
          n = n + 1
        end
      end
    elseif not ok then
      stats.lastError = tostring(items):match("^[^\n]*")
    end
  end
  stats.draws, stats.pins = stats.draws + 1, n
end

function HighgroundDataProviderMixin:OnMapChanged()
  self:RefreshAllData()
end

local function Attach(mapFrame)
  if not (mapFrame and mapFrame.AddDataProvider) or providers[mapFrame] then
    return
  end
  local p = CreateFromMixins(HighgroundDataProviderMixin)
  mapFrame:AddDataProvider(p)
  providers[mapFrame] = p
end

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
}, "map pins", "battlegrounds")
-- Live pins redraw while a battleground is tracked; stopping clears them.
-- Guide samples and the test pin redraw when they change.
ns.PvPEvents.Every(0.5, MapPins.Refresh, "map pins", function() return ns.IsActive and ns.IsActive() end,
  "battlegrounds", MapPins.Refresh)

-- Older names used by other subsystems and tests.
ns.AddMapLayer = MapPins.Add
ns.pinStats = stats
ns.pinProviders = MapPins.Providers
