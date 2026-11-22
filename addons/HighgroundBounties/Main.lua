local _, ns = ...
local Core, Util = ns.Core, ns.Util

---------------------------------------------------------------------------
-- /hgb and the settings page (start-up: libs/standalone/Main.lua). Bounty
-- subcommands share Highground's /hg bounty handler (libs/bounty/Commands.lua).
---------------------------------------------------------------------------
local function Bounty(cmd, rest)
  ns.Commands.bounty(nil, "bounty " .. cmd .. " " .. (rest or ""), ns.Bounty.Say)
end

-- /hgb nearby [on, off, test, clear or forget]: the nearby-enemies list, as
-- /hg nearby in Highground (commands/Settings.lua).
local function Nearby(rest)
  local arg = (rest or ""):lower()
  if arg == "on" or arg == "off" then
    Core.SetFeature("nearby", arg == "on")
    Util.Guard("nearby", ns.Nearby.Update)
  elseif arg == "test" then
    local on = ns.NearbyPreview()
    if on == nil then return Util.Say("leave combat first") end
    return Util.Say("nearby enemies preview " .. (on and "ON: drag it into place, /hgb nearby test again to hide" or "off"))
  elseif arg == "clear" then
    ns.NearbyClear()
    return Util.Say("nearby enemies cleared")
  elseif arg == "forget" then
    ns.NearbyHistory.Clear()
    return Util.Say("enemy history forgotten")
  end
  local n = 0
  for _ in pairs(ns.Nearby.seen) do n = n + 1 end
  Util.Say("nearby enemies " .. (Core.On("nearby") and "on" or "OFF") .. " (" .. n .. " remembered)"
    .. " | /hgb nearby on | off | test | clear")
end

ns.Standalone.Start({
  command = "HIGHGROUNDBOUNTIES",
  slash = { "/hgb", "/hgbounty" },
  help = {
    "/hgb: open or close the bounty board",
    "/hgb add [GOLD] NAME [; note]: personal bounty; NAME can be \"target\"",
    "/hgb share NAME: prepare a bounty chat link for others to preview and import",
    "/hgb export NAME: prepare a bounty link and post to copy outside the game",
    "/hgb import [CODE]: review a bounty link, code or complete post before importing",
    "/hgb shared: realm/faction bounties, opt-ins, contributions and expiry",
    "/hgb submit, remove, claim NAME: send to your guild, take down, or report a kill",
    "/hgb approve, reject NAME: officers, on guild submissions",
    "/hgb claims: review claims, approve and record manual payments",
    "/hgb gold: account gold breakdown and funding settings",
    "/hgb suggestions: review recurring attackers and reported deaths",
    "/hgb journal: enemy encounters, notes and muted alerts",
    "/hgb list, sync: list bounties or sync your guild",
    "/hgb test [FEATURE|stop]: toggle a live-style preview; poster, match, kill, board or other sample UI",
    "/hgb guide [CHAPTER|stop]: explore the bounty feature tour",
    "/hgb on, off: bounty alerts",
    "/hgb nearby [on, off, test, clear or forget]: the nearby-enemies list and its history",
  },
  commands = { nearby = Nearby, journal = function() ns.EnemyJournal.Open() end },
  default = Bounty,
  settings = {
    hint = "Alerts when a bounty target shows up, coins on their nameplates and the bounty board (/hgb). "
      .. "Private targets alert only you. Guild and community submissions need moderator approval; shared rewards require publishing opt-in. Players pay the gold themselves.",
    basic = { "bounty", "bountySound", "bountyPosterTheme", "nearby" },
    keys = { "bounty", "bountyMarks", "bountySound", "bountyAnnounce", "bountyPosterTheme", "bountyTellGroup", "bountyAnyPlayer",
      "bountyShare", "bountyRealert", "bountyOfficerRank", "bountyDays",
      "nearby", "nearbyRows", "nearbyFade", "nearbyForget", "nearbySound", "nearbyStealth", "nearbyHistory", "sound",
      "bountyReceive", "bountyPublish", "bountyMinGold", "bountyDurationHours", "bountyAccountGold", "bountyRequireGold",
      "bountySuggestions", "bountyDeathShare", "bountySuggestionPersonal", "bountySuggestionGuildDeaths",
      "bountySuggestionVictims", "bountySuggestionWindow", "bountySuggestionCooldown" },
    buttons = { { "Open bounty board", function() ns.Bounty.Board.Open() end } },
  },
})
