local _, ns = ...
local Core, Util = ns.Core, ns.Util

---------------------------------------------------------------------------
-- /hgb and the settings page (shared start-up: standalone/Main.lua). Bounty
-- subcommands are Highground's /hg bounty (commands/Bounty.lua).
---------------------------------------------------------------------------
local function Bounty(cmd, rest)
  ns.Commands.bounty(nil, "bounty " .. cmd .. " " .. (rest or ""), ns.Bounty.Say)
end

-- /hgb nearby [on, off, test or clear]: the nearby-enemies list, as
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
    "/hgb submit, remove, claim NAME: send to your guild, take down, or report a kill",
    "/hgb approve, reject NAME: officers, on guild submissions",
    "/hgb list, sync, test: list bounties, ask your guild for its list, test the alert",
    "/hgb on, off: bounty alerts",
    "/hgb nearby [on, off, test or clear]: the nearby-enemies list",
  },
  commands = { nearby = Nearby },
  default = Bounty,
  settings = {
    hint = "Alerts when a bounty target shows up, coins on their nameplates and the bounty board (/hgb). "
      .. "Your bounties alert only you until a guild officer approves them. Players pay the gold themselves.",
    keys = { "bounty", "bountyMarks", "bountySound", "bountyAnnounce", "bountyTellGroup", "bountyAnyPlayer",
      "bountyShare", "bountyRealert", "bountyOfficerRank", "bountyDays",
      "nearby", "nearbyRows", "nearbyFade", "nearbyForget", "nearbySound", "sound" },
    buttons = { { "Open bounty board", function() ns.Bounty.Board.Open() end } },
  },
})
