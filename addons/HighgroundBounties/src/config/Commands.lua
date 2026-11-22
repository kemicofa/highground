local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
local A, L = C.Action, C.Link
local function Name() return { { label = ns.Locale:Get("bounties.commands.player_name_or_target.6b1bab"), default = "target" } } end
C.Register("bounties", "highground.modules.bounties.eba0bf", {
  C.Tool("bounty", "bounties.commands.open_or_close_the_bounty_board.4b3051", "bountyboard", "highground.modules.open_bounty_board.69b5a7", { aliases = { "bounty board" } }),
  A("bounty shared", "bounties.commands.open_shared_realm_faction_bounties.a77741", "bounties.commands.open_shared_bounties.dbb58f", { aliases = { "bounty shared board" } }),
  C.Tool("bounty add", "bounties.commands.create_a_personal_bounty_optionally_with_gold.2e500f", "bountyboard", "bounties.commands.create_a_bounty.de852e", { usage = "[GOLD] NAME [; note]" }),
  C.Tool("bounty shared add", "bounties.commands.publish_a_shared_pledge_with_an_expiry.84d8df", "bountyboard", "bounties.commands.create_a_shared_bounty.36ee9b", { usage = "GOLD DURATION NAME [; note]" }),
  L("bounty shared receive", "bounties.commands.enable_or_disable_receiving_shared_bounties.81dd5a", "bounty", "bounties.commands.shared_bounty_receiving.243c41", { usage = "on|off" }),
  L("bounty shared publish", "bounties.commands.enable_or_disable_publishing_shared_bounties.94c901", "bounty", "bounties.commands.shared_bounty_publishing.2b1c5d", { usage = "on|off" }),
  L("bounty shared threshold", "bounties.commands.set_the_minimum_shared_bounty_gold_value.56080d", "bounty", "bounties.commands.shared_bounty_alert_threshold.915e6a", { usage = "GOLD" }),
  A("bounty share", "bounties.commands.prepare_a_bounty_chat_link_review_it.4ce1f0", "bounties.commands.prepare_bounty_share.7044fc", { usage = "NAME", fields = Name() }),
  A("bounty export", "bounties.commands.prepare_a_bounty_code_and_post_to.30edc1", "bounties.commands.export_a_bounty.147381", { usage = "NAME", fields = Name() }),
  A("bounty import", "bounties.commands.review_a_bounty_link_code_or_complete.768028", "bounties.commands.import_a_bounty.c82590", { usage = "[CODE]" }),
  A("bounty submit", "bounties.commands.submit_a_personal_bounty_to_your_guild.65c6e2", "bounties.commands.submit_bounty_to_guild.1c6e4f", { usage = "NAME", fields = Name() }),
  A("bounty remove", "bounties.commands.remove_a_bounty_you_can_manage.aa0252", "bounties.commands.remove_a_bounty.61532c", ns.Localization.Define({ usage = "NAME", fields = Name(), confirm = ns.Locale:Get("bounties.commands.remove_this_bounty.bf6bbc") }, { confirm = "bounties.commands.remove_this_bounty.bf6bbc" })),
  A("bounty claim", "bounties.commands.report_a_bounty_kill_for_review.27a3af", "bounties.commands.report_bounty_kill.69ced6", { usage = "NAME", fields = Name() }),
  A("bounty approve", "bounties.commands.officers_approve_a_pending_bounty_submission.8f2f69", "bounties.commands.approve_bounty_submission.3b9cd9", { usage = "NAME", fields = Name() }),
  A("bounty reject", "bounties.commands.officers_reject_a_pending_bounty_submission.d78b6b", "bounties.commands.reject_bounty_submission.b60e34", ns.Localization.Define({ usage = "NAME", fields = Name(), confirm = ns.Locale:Get("bounties.commands.reject_this_bounty_submission.cf8ced") }, { confirm = "bounties.commands.reject_this_bounty_submission.cf8ced" })),
  A("bounty shared claim", "bounties.commands.report_a_shared_bounty_kill.f7912b", "bounties.commands.report_shared_bounty_kill.981424", { usage = "NAME", fields = Name() }),
  A("bounty shared withdraw", "bounties.commands.withdraw_your_shared_bounty_contribution.22ccaf", "bounties.commands.withdraw_shared_contribution.004beb", ns.Localization.Define({ usage = "NAME", fields = Name(), confirm = ns.Locale:Get("bounties.commands.withdraw_your_shared_contribution.c919b0") }, { confirm = "bounties.commands.withdraw_your_shared_contribution.c919b0" })),
  A("bounty claims", "bounties.commands.review_kill_claims_and_record_approval_or.f73f4c", "bounties.commands.review_claims_and_payments.261ea5", { aliases = { "bounty shared claims" } }),
  A("bounty gold", "bounties.commands.inspect_account_gold_and_funding_settings.66b5c0", "bounties.commands.open_gold_and_funding.3acd41"),
  A("bounty suggestions", "bounties.commands.review_attackers_death_reports_and_bounty_drafts.0e2626", "bounties.commands.open_bounty_suggestions.cb7504"),
  L("bounty test", "bounties.commands.start_a_named_sample_scene_or_stop.c90c0c", "bounties-previews", "bounties.commands.bounty_preview_controls.7666b1", { usage = "[FEATURE|stop]" }),
  A("bounty guide", "bounties.commands.open_a_sample_chapter_of_the_bounty.27f4b1", "bounties.commands.choose_bounty_sample_chapter.041b4d", { usage = "[CHAPTER|stop]",
    fields = { ns.Localization.Define({ label = ns.Locale:Get("bounties.commands.chapter.46b005"), choices = function()
      local choices = { { key = "stop", label = ns.Locale:Get("bounties.commands.stop_bounty_tour.040220") } }
      for _, scene in ipairs(ns.Bounty.Preview.scenes) do choices[#choices + 1] = { key = scene.key, label = scene.label } end
      return choices
    end }, { label = "bounties.commands.chapter.46b005" }) } }),
  A("guide bounties", "bounties.commands.choose_the_posting_or_hunting_guide_each.91a069", "bounties.commands.choose_bounty_guide.8e5508"),
  A("guide bounty_post", "bounties.commands.start_or_resume_posting_and_claim_review.194f13", "highground.toursteps.start_posting_guide.4cedfa"),
  A("guide bounty_hunt", "bounties.commands.start_or_resume_hunting_and_claiming_lessons.fdaa22", "highground.toursteps.start_hunting_guide.46a876"),
  A("bounty list", "bounties.commands.print_current_bounties_in_chat.31f7d0", "bounties.commands.print_bounty_list.7f367e"),
  A("bounty sync", "bounties.commands.request_current_guild_bounties.6cda4c", "bounties.commands.request_guild_bounties.c3d630"),
  A("bounty shared sync", "bounties.commands.request_shared_realm_faction_bounties.3ea9cd", "bounties.commands.request_shared_bounties.3b7f15"),
  L("bounty on", "bounties.commands.enable_or_disable_bounty_alerts.2ebb59", "bounty", "bounties.commands.bounty_alert_switch.e09f01", { aliases = { "bounty off" } }),
}, {
  ns.Localization.Define({ cmd = "bounty test", label = ns.Locale:Get("bounties.commands.wanted_poster.7eedfa"), desc = ns.Locale:Get("bounties.commands.toggle_a_live_style_bounty_sighting_with.ab1ac9") }, { label = "bounties.commands.wanted_poster.7eedfa", desc = "bounties.commands.toggle_a_live_style_bounty_sighting_with.ab1ac9" }),
  ns.Localization.Define({ kind = "open", cmd = "bounty", label = ns.Locale:Get("highground.hub.bounty_board.f37f61"), desc = ns.Locale:Get("bounties.commands.open_or_close_the_bounty_board.63d142") }, { label = "highground.hub.bounty_board.f37f61", desc = "bounties.commands.open_or_close_the_bounty_board.63d142" }),
})
