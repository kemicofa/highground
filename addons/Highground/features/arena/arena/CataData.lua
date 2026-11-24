local _, ns = ...
if ns.CLIENT ~= "cata" then return end
local D = { categories = {}, reset = 20 }
ns.ArenaCataData = D
-- Cataclysm categories and conservative 15–20s reset window verified
-- against DRList's Cata data: github.com/wardz/DRList-1.0/tree/master/DRList-1.0
-- These groups are separate: Blind shares fear; Cyclone does not.
local groups = {
  stun = { 853, 408, 1833, 5211, 9005, 22570, 47481, 91797, 30283, 46968, 12809, 85388, 20549, 89766 },
  incap = { 118, 28271, 28272, 61305, 61721, 61780, 2637, 3355, 19386, 6770, 1776, 51514, 20066, 710, 9484, 49203 },
  fear = { 5782, 5484, 8122, 5246, 20511, 2094, 6358, 10326, 1513 },
  root = { 339, 19975, 122, 33395, 96293, 96294, 64695, 63685 },
  silence = { 47476, 34490, 15487, 1330, 55021, 18469, 24259, 31935 },
  horror = { 64044, 6789 }, cyclone = { 33786 }, scatter = { 19503, 31661 },
  disarm = { 676, 51722,
    64058 },
}
for category, ids in pairs(groups) do for _, id in ipairs(ids) do D.categories[id] = { category } end end
D.categories[44572] = { "stun", "freeze/ring" }
D.categories[82691] = { "incap", "freeze/ring" }
-- Base cooldowns. Talents and resets can shorten them; the panel labels
-- these estimates and never claims that an unseen interrupt is ready.
D.interrupts = { [1766] = 10, [6552] = 10, [47528] = 10, [96231] = 10,
  [2139] = 24, [57994] = 15, [80964] = 60, [80965] = 60, [19647] = 24, [34490] = 20 }
