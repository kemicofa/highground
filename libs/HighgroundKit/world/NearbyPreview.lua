local _, ns = ...
local Nearby = ns.Nearby

---------------------------------------------------------------------------
-- Nearby's preview (`/hg nearby test`) and clear: sample rows that replace
-- the shown list while real sightings keep expiring (world/Nearby.lua).
---------------------------------------------------------------------------
-- sx, sy: the sample's spot on any open map (world/Map.lua).
local PREVIEW = {
  ns.Localization.Define({ name = "Sneakypete", class = "ROGUE", level = 60, guild = "Night Watch", zone = ns.Locale:Get("shared.preview.tarren_mill.f2b545"), ago = 1, sx = 0.46, sy = 0.42 }, { zone = "shared.preview.tarren_mill.f2b545" }),
  { name = "Frostbyte", class = "MAGE", level = 58, zone = "Southshore", ago = 25, sx = 0.465, sy = 0.425 },
  { name = "Ironhide", class = "WARRIOR", level = 60, guild = "Night Watch", ago = 40, by = "Guildmate", via = "guild", sx = 0.62, sy = 0.3 },
  ns.Localization.Define({ name = "Holyhands", class = "PALADIN", level = 60, guild = "Silver Hand", zone = ns.Locale:Get("shared.nearby.hillsbrad_fields.ead610"), ago = 140, sx = 0.3, sy = 0.66 }, { zone = "shared.nearby.hillsbrad_fields.ead610" }),
}

-- Sample sightings for the preview, last seen relative to now.
function Nearby.Samples(now)
  local list = {}
  for i, p in ipairs(PREVIEW) do list[i] = setmetatable({ last = now - p.ago }, { __index = p }) end
  return list
end

function ns.NearbyPreview()
  if ns.Modules and not ns.Modules.Require("nearby") then return false end
  if InCombatLockdown() then return nil end
  Nearby.preview = not Nearby.preview
  Nearby.Update()
  if ns.MapPins then ns.MapPins.Refresh() end -- samples on an open map
  return Nearby.preview
end

function ns.NearbyClear()
  wipe(Nearby.seen)
  Nearby.Update()
end
