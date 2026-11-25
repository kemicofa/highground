local _, ns = ...
local Util, Theme = ns.Util, ns.Theme

-- Map-unit pins for the shared pin layer (Pins.lua): approximate-position
-- circles and heat. Their XML templates are in Pins.xml.

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

-- Heat pins live in map units too: a soft blob three cells wide, so
-- neighbouring cells blend, under the enemy pins. Only the cell itself
-- takes the mouse.
local HeatPinMixin = CreateFromMixins(MapCanvasPinMixin)
_G[(ns.FRAME_PREFIX or "Highground") .. "HeatPinMixin"] = HeatPinMixin

function HeatPinMixin:OnLoad()
  self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
  self.Blob:SetTexture(ns.Core.HEAT_BLOB)
  if self.SetMouseClickEnabled then self:SetMouseClickEnabled(false) end
end

function HeatPinMixin:OnAcquired(item)
  self.item, item.pin = item, self
  local canvas = self:GetMap():GetCanvas()
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local sw, sh = math.max(8, item.size * w), math.max(8, item.size * h)
  local hit = item.hit or item.size
  local dx, dy = math.max(0, (sw - hit * w) / 2), math.max(0, (sh - hit * h) / 2)
  self:SetSize(sw, sh)
  self:SetHitRectInsets(dx, dx, dy, dy)
  Theme.Tint(self.Blob, item.ring or "hudDanger", item.alpha or 0.5)
  self:SetPosition(item.x, item.y)
end

HeatPinMixin.OnMouseEnter = ZonePinMixin.OnMouseEnter
function HeatPinMixin:SetHighlight() end
HeatPinMixin.OnMouseLeave = ZonePinMixin.OnMouseLeave
