local _, ns = ...
ns.Commands = {}
ns.BOUNTY_CMD = "/hgn bounty"
ns.BOUNTY_SOUND_FALLBACK = true
local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
if not ns.STANDBY and loaded and loaded("HighgroundBounties") then
  ns.STANDBY = true
  ns.STANDBY_LABEL, ns.STANDBY_COMMAND = "Highground Bounties", "/hgb"
end
