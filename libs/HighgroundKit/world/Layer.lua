local _, ns = ...
local Util, Core = ns.Util, ns.Core
ns.WorldLayer = { epoch = 1, moved = 0 }
local Layer = ns.WorldLayer

---------------------------------------------------------------------------
-- Layers (`ns.Caps.layers`, WoW Forever): the game runs copies of a zone,
-- and players on another copy cannot see each other, so a sighting shared
-- from another layer sends you to an empty spot. The game has no layer API,
-- and since build 71037 creature GUIDs no longer name one. Each sighting
-- gets a status instead, judged when it arrives:
--   "same"  yours, or a group member's whom the game shows on your layer in
--           your zone (no UnitPhaseReason)
--   "other" a group member's whom the game marks as sharded, or yours from
--           before the game moved you
--   nil     unknown: guild, everyone, group members in another zone
-- Each status keeps the epoch it was judged in. A move (SHARD_TRANSFER) or
-- a loading screen starts a new epoch: then "same" turns "other" after a
-- move and unknown after a loading screen, and "other" turns unknown.
-- Lists, pins and heat leave other layers out unless `nearbyLayersAll`
-- (the map's Layers button, /hg nearby layers all|mine).
---------------------------------------------------------------------------
local SHARDING = Enum and Enum.PhaseReason and Enum.PhaseReason.Sharding or 1
local Plain = Util.plain

function Layer.Supported()
  return ns.Caps and ns.Caps.layers and true or false
end

-- What a stored status means now.
function Layer.Status(e)
  local layer, epoch = e.layer, e.epoch
  if not layer or epoch == Layer.epoch then return layer end
  if layer == "same" and epoch and Layer.moved > epoch then return "other" end
end

function Layer.All() return Core.O("nearbyLayersAll") and true or false end

-- Whether lists, pins and heat show this sighting.
function Layer.Shown(e)
  return not Layer.Supported() or Layer.All() or Layer.Status(e) ~= "other"
end

-- Stamp a sighting (or heat spot, kill) with a status judged now.
function Layer.Stamp(e, layer)
  e.layer, e.epoch = layer, Layer.epoch
  return e
end

-- The status of a sighting `sender` shared from zone map `mapID`: only a
-- group member standing in your zone is judged; the game compares layers
-- within a zone (LayerSwap's measurements, docs/forever-api.md).
function Layer.Of(sender, mapID)
  if not (sender and Layer.Supported() and type(UnitPhaseReason) == "function" and ns.UnitTokens) then return end
  local Share = ns.WorldShare
  local here = Share and Share.Here()
  if not here or here ~= mapID then return end
  local tokens, n = ns.UnitTokens.Group()
  for i = 1, n do
    local unit = tokens[i]
    if Core.CanonUnit(unit) == sender then
      local okM, best = pcall(C_Map.GetBestMapForUnit, unit)
      if not (okM and Plain(best) and type(best) == "number" and Share.ZoneMap(best) == here) then return end
      local ok, reason = pcall(UnitPhaseReason, unit)
      if not ok or Util.secret(reason) then return end
      if reason == nil then return "same" end
      return reason == SHARDING and "other" or nil
    end
  end
end

-- A short tag for a row: only another layer earns one.
function Layer.Tag(e)
  if Layer.Supported() and Layer.Status(e) == "other" then return ns.Locale:Get("layers.other_short") end
end

-- A tooltip line and its colour for a sighting, or nil for your own on
-- your layer.
function Layer.Line(e)
  if not Layer.Supported() then return end
  local status = Layer.Status(e)
  if status == "other" then return ns.Locale:Get("layers.other"), "warning" end
  if not e.by then return end
  if status == "same" then return ns.Locale:Get("layers.same"), "success" end
  return ns.Locale:Get("layers.unknown"), "textMuted"
end

-- How many of a list are on your layer, on another, of unknown layer.
function Layer.Count(list)
  local same, other, unknown = 0, 0, 0
  for _, e in pairs(list) do
    local status = Layer.Status(e)
    if status == "same" then same = same + 1
    elseif status == "other" then other = other + 1
    else unknown = unknown + 1 end
  end
  return same, other, unknown
end

-- Switch showing other layers (the map button, /hg nearby layers); false
-- where the game has none.
function Layer.SetAll(on)
  if not Layer.Supported() then return false end
  Core.SetTuning("option", "nearbyLayersAll", on and true or false)
  Layer.Changed()
  return true
end

-- Lists, pins and heat follow a new epoch or switch at once.
function Layer.Changed()
  if ns.WorldHeat then ns.WorldHeat.Refresh() end
  if ns.Nearby and ns.Nearby.win then ns.Nearby.Update() end
  if ns.MapPins then ns.MapPins.Refresh() end
  if Layer.chip and Layer.chip:IsShown() then Layer.Paint() end
end

local function NewEpoch(moved)
  Layer.epoch = Layer.epoch + 1
  if moved then Layer.moved = Layer.epoch end
  Layer.Changed()
end

---------------------------------------------------------------------------
-- The world map's Layers button: shows which layers the pins come from and
-- switches other layers on and off.
---------------------------------------------------------------------------
local function Listed()
  local Nearby = ns.Nearby
  if not Nearby then return {} end
  if Nearby.preview then return Nearby.Samples(GetTime()) end
  return Nearby.seen
end

function Layer.Paint()
  local b = Layer.chip
  local _, other = Layer.Count(Listed())
  local all = Layer.All()
  b:SetText(all and ns.Locale:Get("layers.button_all")
    or other > 0 and ns.Locale:Format("layers.button_hidden", { count = other })
    or ns.Locale:Get("layers.button_mine"))
end

local function Tip()
  local same, other, unknown = Layer.Count(Listed())
  return { ns.Locale:Get("layers.title"), ns.Locale:Get("layers.explain"),
    { ns.Locale:Format("layers.counts", { same = same, other = other, unknown = unknown }), "textMuted" },
    { ns.Locale:Get(Layer.All() and "layers.click_mine" or "layers.click_all"), "textDim" } }
end

local function Chip()
  if Layer.chip then return Layer.chip end
  local map = WorldMapFrame
  if not map then return end
  local Kit = ns.Kit
  local b = Kit.Button(map, "", 170, 22, { onClick = function() Layer.SetAll(not Layer.All()) end })
  b:SetPoint("TOPLEFT", map.ScrollContainer or map, "TOPLEFT", 8, -8)
  -- Above the map's pins, which climb many frame levels; it hides with the map.
  b:SetFrameStrata("DIALOG")
  Kit.Tooltip(b, Tip)
  Layer.chip = b
  return b
end

-- world/Map.lua's tick, once a second while a map is open.
function Layer.Tick()
  local Nearby = ns.Nearby
  local want = Layer.Supported() and WorldMapFrame and WorldMapFrame:IsShown() and Nearby
    and Core.On("nearby") and Core.On("nearbyMap") and (Nearby.preview or Nearby.State() == "tracking")
  if not want then
    if Layer.chip then Layer.chip:Hide() end
    return
  end
  local b = Chip()
  if not b then return end
  b:Show()
  Layer.Paint()
end

Util.Events({
  SHARD_TRANSFER = function() NewEpoch(true) end,
  PLAYER_ENTERING_WORLD = function() NewEpoch(false) end,
}, "world layers", "nearby")

-- Part of /hg nearby's sharing line (world/Share.lua).
function Layer.Summary()
  local _, other, unknown = Layer.Count(ns.Nearby and ns.Nearby.seen or {})
  return ns.Locale:Format(Layer.All() and "layers.summary_all" or "layers.summary_mine", { other = other, unknown = unknown })
end
