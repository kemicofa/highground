local _, ns = ...
local Nearby = ns.Nearby

---------------------------------------------------------------------------
-- Nearby's preview (`/hg nearby test`) and clear: sample rows that replace
-- the shown list while real sightings keep expiring (world/Nearby.lua).
---------------------------------------------------------------------------
-- sx, sy: the sample's spot, placed around you (Nearby.SampleAt).
-- fight: the sample in fight mode (rank, kill target, health, on you).
local PREVIEW = {
  ns.Localization.Define({ name = "Sneakypete", class = "ROGUE", level = 60, guild = "Night Watch", zone = ns.Locale:Get("shared.preview.tarren_mill.f2b545"), ago = 1, sx = 0.46, sy = 0.42,
    fight = { rank = 2, hp = 0.8, onMe = true } }, { zone = "shared.preview.tarren_mill.f2b545" }),
  { name = "Frostbyte", class = "MAGE", level = 58, zone = "Southshore", ago = 25, sx = 0.465, sy = 0.425,
    fight = { rank = 1, kill = true, hp = 0.32 } },
  { name = "Ironhide", class = "WARRIOR", level = 60, guild = "Night Watch", ago = 40, by = "Guildmate", via = "guild", sx = 0.62, sy = 0.3,
    fight = { rank = 3, hp = 0.95 } },
  { name = "Bloodfang", class = "ROGUE", level = 60, guild = "Night Watch", zone = "Arathi Highlands", ago = 70, by = "Guildmate", via = "guild",
    tracked = true, r = 70, sx = 0.7, sy = 0.62 },
  -- A group member's, on another layer: hidden until the map's Layers button shows all.
  { name = "Duskblade", class = "ROGUE", level = 60, guild = "Night Watch", ago = 30, by = "Partymate", via = "group",
    layer = "other", sx = 0.56, sy = 0.52 },
  ns.Localization.Define({ name = "Holyhands", class = "PALADIN", level = 60, guild = "Silver Hand", zone = ns.Locale:Get("shared.nearby.hillsbrad_fields.ead610"), ago = 140, sx = 0.3, sy = 0.66 }, { zone = "shared.nearby.hillsbrad_fields.ead610" }),
}

-- Samples sit around you, as real sightings near you would: a sample's
-- offset from the centre of the coarse square holding Sneakypete is applied
-- to the centre of yours on your zone map (so the sample raid fills your
-- square), and the map layers translate it like real data, so the zone,
-- continent and world maps agree. Returns that zone map and position;
-- without a zone map, nil and the sample's own spot on the shown map.
Nearby.SAMPLE_X, Nearby.SAMPLE_Y = 0.475, 0.425
function Nearby.SampleAt(sx, sy)
  local Share = ns.WorldShare
  local map, x, y
  if Share then map, x, y = Share.Here() end
  if not map then return nil, sx, sy end
  x, y = Share.Cell(x or 0.5, y or 0.5)
  x, y = x + sx - Nearby.SAMPLE_X, y + sy - Nearby.SAMPLE_Y
  return map, math.min(0.99, math.max(0.01, x)), math.min(0.99, math.max(0.01, y))
end

-- The heatmap's crowd (world/Heat.lua), placed around you like the rows:
-- a raid around the fresh samples with a few beside it, a group by the
-- guild's and some stragglers. Kills: your side winning by the raid, the
-- enemy winning by the guild's group, an even fight to the south.
Nearby.HEAT_SAMPLES = {
  { x = 0.452, y = 0.405, ago = 1 }, { x = 0.46, y = 0.42, ago = 5 }, { x = 0.468, y = 0.41, ago = 10 },
  { x = 0.476, y = 0.43, ago = 15 }, { x = 0.484, y = 0.415, ago = 20 }, { x = 0.492, y = 0.44, ago = 30 },
  { x = 0.456, y = 0.445, ago = 40 }, { x = 0.472, y = 0.425, ago = 50 }, { x = 0.488, y = 0.405, ago = 60 },
  { x = 0.464, y = 0.435, ago = 90 }, { x = 0.44, y = 0.43, ago = 35 }, { x = 0.445, y = 0.41, ago = 110 },
  { x = 0.47, y = 0.455, ago = 75 }, { x = 0.62, y = 0.30, ago = 40 }, { x = 0.63, y = 0.31, ago = 70 },
  { x = 0.61, y = 0.32, ago = 150 }, { x = 0.30, y = 0.66, ago = 140 }, { x = 0.70, y = 0.62, ago = 70 },
  { x = 0.20, y = 0.25, ago = 260 },
}
Nearby.HEAT_KILLS = {
  { x = 0.46, y = 0.42, ago = 30, ours = true }, { x = 0.47, y = 0.43, ago = 200, ours = true },
  { x = 0.48, y = 0.41, ago = 600, ours = true }, { x = 0.465, y = 0.425, ago = 900, ours = false },
  { x = 0.62, y = 0.31, ago = 120, ours = false }, { x = 0.625, y = 0.305, ago = 400, ours = false },
  { x = 0.615, y = 0.315, ago = 1500, ours = false }, { x = 0.62, y = 0.30, ago = 2400, ours = true },
  { x = 0.52, y = 0.72, ago = 300, ours = true }, { x = 0.525, y = 0.715, ago = 1200, ours = false },
}

-- A sample's spot on the shown map, or nil when that map doesn't show it.
function Nearby.SampleOn(mapID, sx, sy)
  local map, x, y = Nearby.SampleAt(sx, sy)
  if not map then return x, y end
  return ns.WorldMap.Translate(map, mapID, x, y)
end

-- Sample sightings for the preview, last seen relative to now, judged in
-- the current layer epoch (world/Layer.lua); the other-layer sample only
-- where the game has layers. shown: only those your layer setting shows.
function Nearby.Samples(now, shown)
  local list, Layer = {}, ns.WorldLayer
  for _, p in ipairs(PREVIEW) do
    local e = setmetatable({ last = now - p.ago, epoch = Layer.epoch }, { __index = p })
    if (not p.layer or Layer.Supported()) and (not shown or Layer.Shown(e)) then list[#list + 1] = e end
  end
  return list
end

-- Show or hide the samples. fight: in fight mode, as in a world fight
-- (Battlegrounds → Open world → Preview). Samples start out of combat
-- only. Returns whether they show.
function Nearby.SetPreview(on, fight)
  if on and InCombatLockdown() then return Nearby.preview end
  Nearby.preview, Nearby.previewFight = on and true or false, on and fight or nil
  Nearby.Update()
  if ns.MapPins then ns.MapPins.Refresh() end -- samples on an open map
  return Nearby.preview
end

function ns.NearbyPreview()
  if ns.Modules and not ns.Modules.Require("nearby") then return false end
  if InCombatLockdown() then return nil end
  return Nearby.SetPreview(not Nearby.preview)
end

function ns.NearbyClear()
  wipe(Nearby.seen)
  if ns.WorldHeat then ns.WorldHeat.Clear() end
  Nearby.Update()
end
