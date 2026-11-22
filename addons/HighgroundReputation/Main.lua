local _, ns = ...
ns.STANDBY_COMMAND = "/hg reputation"
ns.Standalone.Start({
  command = "HIGHGROUNDREPUTATION", slash = { "/hgrep", "/hgreputation" },
  help = ns.Localization.Define({ ns.Locale:Get("reputation.main.hgrep_communities_blacklists_proposals_and_moderation.9e3ae4"), ns.Locale:Get("reputation.main.hgrep_report_target_report_your_target.60168f"),
    "/hgrep communities | report target | sync | status | on | off" }, { [1] = "reputation.main.hgrep_communities_blacklists_proposals_and_moderation.9e3ae4", [2] = "reputation.main.hgrep_report_target_report_your_target.60168f" }),
  default = function(command, rest) ns.Reputation.Command(command .. (rest ~= "" and (" " .. rest) or "")) end,
  settings = ns.Localization.Define({ hint = ns.Locale:Get("reputation.main.player_reports_and_moderation_for_your_guild.eb46c0"),
    keys = {}, buttons = { ns.Localization.Define({ ns.Locale:Get("reputation.main.open_highground_reputation.41caef"), function() ns.Reputation.Open() end }, { [1] = "reputation.main.open_highground_reputation.41caef" }) } }, { hint = "reputation.main.player_reports_and_moderation_for_your_guild.eb46c0" }),
})
