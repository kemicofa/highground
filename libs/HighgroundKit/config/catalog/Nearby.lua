local _, ns = ...

-- Nearby enemies settings (world/Nearby.lua, world/History.lua): Highground,
-- Highground Nearby and Highground Bounties. See config/Options.lua.
ns.OptionsAdd({
  module = "nearby",
  firstRun = { nearby = true, nearbyRows = 5, nearbySound = true },
  pages = {
    nearby = { name = "Nearby: Settings", order = 6.5, hint = "Open-world list of hostile players you have seen. Choose its panels and alerts here; list size is on Nearby Appearance." },
  },
  behavior = {
    { key = "nearbyRows", page = "nearby", def = 10, min = 1, max = 20, integer = true, unit = "enemies", desc = "Enemies listed at most" },
    { key = "nearbyFade", page = "nearby", def = 60, min = 5, max = 600, unit = "seconds", desc = "Fade an enemy unseen for" },
    { key = "nearbyForget", page = "nearby", def = 300, min = 30, max = 3600, unit = "seconds", desc = "Remove an enemy unseen for" },
    { key = "nearbySound", page = "nearby", def = true, type = "boolean", desc = "Sound when a new enemy is spotted or an enemy enters or leaves stealth" },
    { key = "nearbyStealth", page = "nearby", def = true, type = "boolean", desc = "Tell me when a nearby enemy stealths or turns invisible, and when it fades" },
    { key = "nearbyHistory", page = "nearby", def = true, type = "boolean", desc = "Remember every enemy you meet, with kills both ways (saved); say when one you met before shows up" },
  },
  features = {
    {
      { group = "Open world", order = 4 },
      { key = "nearby", label = "Nearby enemies", desc = "Open-world list of hostile players you have seen, most recent first; settings in the Nearby section" },
    },
  },
})
