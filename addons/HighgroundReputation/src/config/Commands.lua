local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
C.Register("reputation", "highground.modules.reputation.5f2160", {
  C.Tool("reputation", "reputation.commands.reports_moderation_and_chat_filtering_for_guilds.a1c183", "reputation", "highground.toursteps.open_player_reputation.37164b"),
  C.Action("reputation communities", "reputation.commands.open_the_organization_directory_and_account_enable.e98a18", "reputation.commands.open_organizations.0716b4", { aliases = { "reputation organizations" } }),
  C.Action("reputation manage", "reputation.commands.open_blizzard_s_guild_communities_ui.b72eee", "reputation.commands.manage_native_organizations.599707"),
  C.Action("reputation report", "reputation.commands.open_a_report_for_your_target_or.47920a", "reputation.commands.prepare_player_report.81c61f", { usage = "[target|NAME]",
    fields = { ns.Localization.Define({ label = ns.Locale:Get("bounties.commands.player_name_or_target.6b1bab"), default = "target" }, { label = "bounties.commands.player_name_or_target.6b1bab" }) } }),
  C.Action("reputation sync", "reputation.commands.request_updates_from_online_native_moderators.a9045e", "reputation.commands.request_reputation_updates.5d8dc3"),
  C.Action("reputation status", "reputation.commands.print_the_selected_organization_s_sharing_status.e6c734", "reputation.commands.show_sharing_status.10b8a6"),
  C.Link("reputation on", "reputation.commands.enable_or_disable_reputation_chat_filtering.d1dbab", "reputation-settings", "reputation.commands.chat_filtering_switch.62082f", { aliases = { "reputation off" } }),
  C.Action("reputation help", "reputation.commands.print_reputation_command_help.a1fab2", "reputation.commands.print_reputation_help.19cad8"),
})
