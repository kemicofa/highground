local _, ns = ...

-- Bounty settings (bounty/): Highground, Highground Bounties and Highground Nearby.
-- See config/Options.lua.
ns.OptionsAdd({
  module = "bounties",
  pages = {
    bounty = { name = "Bounties: Settings", order = 6.6, hint = "Personal, guild, community and shared bounties alert when a target is spotted. Open the board with /hg bounty or its key binding. Guild and community submissions need moderator approval; shared receiving and publishing are separate opt-ins. Players pay the gold themselves." },
  },
  behavior = {
    { key = "bountyAccountGold", page = "bounty", def = true, type = "boolean", desc = "Track and use gold across account characters on this realm or Forever ruleset" },
    { key = "bountyRequireGold", page = "bounty", def = false, type = "boolean", desc = "Require enough available gold to create a bounty (off: warn and allow)" },
    { key = "bountyReceive", page = "bounty", def = false, type = "boolean", desc = "Receive shared realm/faction bounties (opt in)" },
    { key = "bountyPublish", page = "bounty", def = false, type = "boolean", desc = "Advertise my shared bounties; Create bounty enables publishing explicitly" },
    { key = "bountyMinGold", page = "bounty", def = 0, min = 0, max = 999999999, integer = true, unit = "gold", desc = "Minimum reward for shared sighting alerts and new guild, community or shared bounty notifications" },
    { key = "bountyDurationHours", page = "bounty", def = 24, min = 1, max = 720, integer = true, unit = "hours", desc = "Default duration for a new shared reward; added gold keeps the original expiry" },
    { key = "bountySound", page = "bounty", def = true, type = "boolean", desc = "Sound when a bounty target is spotted" },
    { key = "bountyAnnounce", page = "bounty", def = true, type = "boolean", desc = "Wanted poster popups for sightings and new matching bounties" },
    { key = "bountyTellGroup", page = "bounty", def = false, type = "boolean", desc = "Tell your party or raid when you spot a bounty target" },
    { key = "bountyAnyPlayer", page = "bounty", def = false, type = "boolean", desc = "Also alert for bounty targets you can't attack (same faction, or not flagged for PvP)" },
    { key = "bountyShare", page = "bounty", def = true, type = "boolean", desc = "Share open-world sightings with each bounty's guild or community" },
    { key = "bountyRealert", page = "bounty", def = 120, min = 10, max = 3600, unit = "seconds", desc = "Alert again after a bounty target is unseen for" },
    { key = "bountyOfficerRank", page = "bounty", def = 1, min = 0, max = 9, integer = true, unit = "guild rank (0 = guild master, 1 = the rank below)",
      desc = "Officers when guild rank permissions can't be read: ranks up to this one approve bounties" },
    { key = "bountyDays", page = "bounty", def = 14, min = 1, max = 90, integer = true, unit = "days", desc = "Bounties expire after" },
    { key = "bountySuggestions", page = "bounty", def = false, type = "boolean", desc = "Bounty suggestions: suggest recurring open-world attackers (opt in)" },
    { key = "bountyDeathShare", page = "bounty", def = false, type = "boolean", desc = "Bounty suggestions: share my attributed open-world deaths with guild addons (separate opt-in)" },
    { key = "bountySuggestionPersonal", page = "bounty", def = 3, min = 2, max = 20, integer = true, unit = "deaths", desc = "Suggest after this enemy kills me" },
    { key = "bountySuggestionGuildDeaths", page = "bounty", def = 5, min = 3, max = 100, integer = true, unit = "deaths", desc = "Guild suggestion: total deaths to the same enemy" },
    { key = "bountySuggestionVictims", page = "bounty", def = 3, min = 2, max = 20, integer = true, unit = "characters", desc = "Guild suggestion: minimum different victims (including me)" },
    { key = "bountySuggestionWindow", page = "bounty", def = 30, min = 5, max = 60, integer = true, unit = "minutes", desc = "Bounty suggestions: count deaths within the last" },
    { key = "bountySuggestionCooldown", page = "bounty", def = 60, min = 5, max = 1440, integer = true, unit = "minutes", desc = "Bounty suggestions: notify again for the same enemy after" },
  },
  features = {
    {
      { group = "Bounties", order = 5 },
      { key = "bounty", label = "Bounties", desc = "Personal, guild, community and shared bounties: sound and wanted poster when a target shows up. Bounty board: /hg bounty; settings in the Bounties section" },
      { key = "bountyMarks", label = "Bounty markers", desc = "Gold coin beside a bounty target's nameplate and a gold frame on their Highground rows", parent = "bounty" },
    },
  },
})
