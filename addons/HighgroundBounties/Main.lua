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
    if on == nil then return Util.Say(ns.Locale:Get("highground.display.leave_combat_first.8497e3")) end
    return Util.Say(ns.Locale:Format("highground.settings.nearby_enemies_preview_value2.57bba2", { value2 = (on and ns.Locale:Get("bounties.main.on_drag_it_into_place_hgb_nearby.0b2882") or "off") }))
  elseif arg == "clear" then
    ns.NearbyClear()
    return Util.Say(ns.Locale:Get("highground.settings.nearby_enemies_cleared.49b891"))
  elseif arg == "forget" then
    ns.NearbyHistory.Clear()
    return Util.Say(ns.Locale:Get("highground.settings.enemy_history_forgotten.8eb942"))
  end
  local n = 0
  for _ in pairs(ns.Nearby.seen) do n = n + 1 end
  Util.Say(ns.Locale:Format("bounties.main.nearby_enemies_value2_n_remembered_hgb_nearby.403bcb", { value2 = (Core.On("nearby") and "on" or "OFF"), n = n }))
end

ns.Standalone.Start({
  command = "HIGHGROUNDBOUNTIES",
  slash = { "/hgb", "/hgbounty" },
  help = ns.Localization.Define({
    ns.Locale:Get("bounties.main.hgb_open_or_close_the_bounty_board.18ce0d"),
    ns.Locale:Get("bounties.main.hgb_add_gold_name_note_personal_bounty.ac9988"),
    ns.Locale:Get("bounties.main.hgb_share_name_prepare_a_bounty_chat.bec85a"),
    ns.Locale:Get("bounties.main.hgb_export_name_prepare_a_bounty_link.2a573b"),
    ns.Locale:Get("bounties.main.hgb_import_code_review_a_bounty_link.0300de"),
    ns.Locale:Get("bounties.main.hgb_shared_realm_faction_bounties_opt_ins.d1644d"),
    ns.Locale:Get("bounties.main.hgb_submit_remove_claim_name_send_to.602ebf"),
    ns.Locale:Get("bounties.main.hgb_approve_reject_name_officers_on_guild.375a12"),
    ns.Locale:Get("bounties.main.hgb_claims_review_claims_approve_and_record.e9cd47"),
    ns.Locale:Get("bounties.main.hgb_gold_account_gold_breakdown_and_funding.2a1d73"),
    ns.Locale:Get("bounties.main.hgb_suggestions_review_recurring_attackers_and_reported.93fccd"),
    ns.Locale:Get("bounties.main.hgb_journal_enemy_encounters_notes_and_muted.213957"),
    ns.Locale:Get("bounties.main.hgb_list_sync_list_bounties_or_sync.194f83"),
    ns.Locale:Get("bounties.main.hgb_test_feature_stop_toggle_a_live.a6067c"),
    ns.Locale:Get("bounties.main.hgb_guide_chapter_stop_explore_the_bounty.336373"),
    ns.Locale:Get("bounties.main.hgb_on_off_bounty_alerts.926358"),
    ns.Locale:Get("bounties.main.hgb_nearby_on_off_test_clear_or.391a13"),
  }, { [1] = "bounties.main.hgb_open_or_close_the_bounty_board.18ce0d", [2] = "bounties.main.hgb_add_gold_name_note_personal_bounty.ac9988", [3] = "bounties.main.hgb_share_name_prepare_a_bounty_chat.bec85a", [4] = "bounties.main.hgb_export_name_prepare_a_bounty_link.2a573b", [5] = "bounties.main.hgb_import_code_review_a_bounty_link.0300de", [6] = "bounties.main.hgb_shared_realm_faction_bounties_opt_ins.d1644d", [7] = "bounties.main.hgb_submit_remove_claim_name_send_to.602ebf", [8] = "bounties.main.hgb_approve_reject_name_officers_on_guild.375a12", [9] = "bounties.main.hgb_claims_review_claims_approve_and_record.e9cd47", [10] = "bounties.main.hgb_gold_account_gold_breakdown_and_funding.2a1d73", [11] = "bounties.main.hgb_suggestions_review_recurring_attackers_and_reported.93fccd", [12] = "bounties.main.hgb_journal_enemy_encounters_notes_and_muted.213957", [13] = "bounties.main.hgb_list_sync_list_bounties_or_sync.194f83", [14] = "bounties.main.hgb_test_feature_stop_toggle_a_live.a6067c", [15] = "bounties.main.hgb_guide_chapter_stop_explore_the_bounty.336373", [16] = "bounties.main.hgb_on_off_bounty_alerts.926358", [17] = "bounties.main.hgb_nearby_on_off_test_clear_or.391a13" }),
  commands = { nearby = Nearby, journal = function() ns.EnemyJournal.Open() end },
  default = Bounty,
  settings = {
    hint = ns.Locale:Get("bounties.main.alerts_when_a_bounty_target_shows_up.bc398a"),
    basic = { "bounty", "bountySound", "nearby" },
    keys = { "bounty", "bountyMarks", "bountySound", "bountyAnnounce", "bountyTellGroup", "bountyAnyPlayer",
      "bountyShare", "bountyRealert", "bountyOfficerRank", "bountyDays",
      "nearby", "nearbyRows", "nearbyFade", "nearbyForget", "nearbySound", "nearbyStealth", "nearbyHistory", "sound",
      "bountyReceive", "bountyPublish", "bountyMinGold", "bountyDurationHours", "bountyAccountGold", "bountyRequireGold",
      "bountySuggestions", "bountyDeathShare", "bountySuggestionPersonal", "bountySuggestionGuildDeaths",
      "bountySuggestionVictims", "bountySuggestionWindow", "bountySuggestionCooldown" },
    buttons = { ns.Localization.Define({ ns.Locale:Get("highground.modules.open_bounty_board.69b5a7"), function() ns.Bounty.Board.Open() end }, { [1] = "highground.modules.open_bounty_board.69b5a7" }) },
  },
})
