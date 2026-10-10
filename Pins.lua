local _, ns = ...

-- Map pin layer shared by the intel map (Map.lua) and the timers
-- (Timers.lua). Uses Blizzard's own map system: a data provider added to
-- the world map and the battlefield map (Shift+M) that acquires pins from
-- an XML template (Pins.xml), exactly like Blizzard's flag pins. The map
-- canvas positions, scales and layers them, so they stay put at any zoom.
--
-- Producers register with ns.AddMapLayer(fn); fn(mapID) returns a list of
--   { x, y (0-1), ring = {r,g,b} | nil, icon = atlas | texture, desat,
--     alpha, label, labelColor = {r,g,b}, mark, size, tooltip = fn(lines) }

local layers = {}
function ns.AddMapLayer(fn)
  layers[#layers + 1] = fn
end

local TEMPLATE = "WarboardPinTemplate"

WarboardPinMixin = CreateFromMixins(MapCanvasPinMixin)

function WarboardPinMixin:OnLoad()
  self:SetScalingLimits(1, 0.9, 1.1)
  self:UseFrameLevelType("PIN_FRAME_LEVEL_VEHICLE_ABOVE_GROUP_MEMBER")
  self.Mark:SetVertexColor(1, 0.42, 0.12, 0.9) -- kill target ring
end

function WarboardPinMixin:OnAcquired(item)
  self.item = item
  local size = item.size or 22
  self:SetSize(size, size)
  if item.ring then
    self.Ring:SetVertexColor(item.ring[1], item.ring[2], item.ring[3], 1)
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
  self.Icon:SetDesaturated(item.desat and true or false)
  self.Mark:SetShown(item.mark and true or false)
  self.Label:SetText(item.label or "")
  local c = item.labelColor or { 1, 1, 1 }
  self.Label:SetTextColor(c[1], c[2], c[3])
  self:SetAlpha(item.alpha or 1)
  self:SetPosition(item.x, item.y)
end

function WarboardPinMixin:OnMouseEnter()
  local item = self.item
  if not (item and item.tooltip) then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  local ok = pcall(item.tooltip, GameTooltip)
  if ok then
    GameTooltip:Show()
  end
end

function WarboardPinMixin:OnMouseLeave()
  GameTooltip_Hide()
end

-- Data provider: rebuilds its pins twice a second while the map is open.
local providers = {}
local stats = { draws = 0, pins = 0 }
ns.pinStats = stats

local WarboardDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

function WarboardDataProviderMixin:RemoveAllData()
  self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
end

function WarboardDataProviderMixin:RefreshAllData()
  self:RemoveAllData()
  local map = self:GetMap()
  local mapID = map and map:GetMapID()
  if not mapID then
    return
  end
  local n = 0
  for _, fn in ipairs(layers) do
    local ok, items = pcall(fn, mapID)
    if ok and type(items) == "table" then
      for _, item in ipairs(items) do
        if item.x and item.y then
          map:AcquirePin(TEMPLATE, item)
          n = n + 1
        end
      end
    elseif not ok then
      stats.lastError = tostring(items)
    end
  end
  stats.draws, stats.pins = stats.draws + 1, n
end

function WarboardDataProviderMixin:OnMapChanged()
  self:RefreshAllData()
end

local function Attach(mapFrame)
  if not (mapFrame and mapFrame.AddDataProvider) or providers[mapFrame] then
    return
  end
  local p = CreateFromMixins(WarboardDataProviderMixin)
  mapFrame:AddDataProvider(p)
  providers[mapFrame] = p
end

ns.pinProviders = function()
  local n = 0
  for _ in pairs(providers) do
    n = n + 1
  end
  return n
end

-- Refresh open maps; called by the producers' driver (Timers.lua / Map.lua).
function ns.RefreshMapPins()
  for mapFrame, p in pairs(providers) do
    if mapFrame:IsShown() then
      local ok, err = pcall(p.RefreshAllData, p)
      if not ok then
        stats.lastError = tostring(err)
      end
    end
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, name)
  if event == "PLAYER_LOGIN" then
    Attach(WorldMapFrame)
    Attach(BattlefieldMapFrame)
  elseif name == "Blizzard_BattlefieldMap" then
    Attach(BattlefieldMapFrame)
  elseif name == "Blizzard_WorldMap" then
    Attach(WorldMapFrame)
  end
end)
local t = 0
f:SetScript("OnUpdate", function(_, dt)
  t = t + dt
  if t >= 0.5 then
    t = 0
    ns.RefreshMapPins()
  end
end)
