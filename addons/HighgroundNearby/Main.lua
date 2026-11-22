local _, ns = ...
local Core, Util, Nearby = ns.Core, ns.Util, ns.Nearby

---------------------------------------------------------------------------
-- /hgn and the settings page (start-up: libs/standalone/Main.lua). The
-- list itself shows on its own in the open world (world/Nearby.lua).
---------------------------------------------------------------------------
-- Nearby.List drops the forgotten ones first.
local function Remembered() return #Nearby.List(GetTime()) end

local function Switch(on)
  Core.SetFeature("nearby", on)
  Util.Guard("nearby", Nearby.Update)
  Util.Say(ns.Locale:Format("nearby.main.nearby_enemies_value2.a1e827", { value2 = (on and "on" or "OFF") }))
end

local function Preview()
  local on = ns.NearbyPreview()
  if on == nil then return Util.Say(ns.Locale:Get("highground.display.leave_combat_first.8497e3")) end
  Util.Say(ns.Locale:Format("nearby.main.preview_value2.ebc9a2", { value2 = (on and ns.Locale:Get("nearby.main.on_drag_the_list_into_place_hgn.4e42a1") or "off") }))
end

local function Clear()
  ns.NearbyClear()
  Util.Say(ns.Locale:Get("highground.settings.nearby_enemies_cleared.49b891"))
end

local function Forget()
  ns.NearbyHistory.Clear()
  Util.Say(ns.Locale:Get("highground.settings.enemy_history_forgotten.8eb942"))
end

ns.Standalone.Start({
  command = "HIGHGROUNDNEARBY",
  slash = { "/hgn", "/hgnearby" },
  help = ns.Localization.Define({
    ns.Locale:Get("nearby.main.hgn_whether_the_list_is_on_and.aeb06d"),
    ns.Locale:Get("nearby.main.hgn_on_hgn_off_show_or_hide.d7fcff"),
    ns.Locale:Get("nearby.main.hgn_test_a_preview_to_drag_into.c31e64"),
    ns.Locale:Get("nearby.main.hgn_journal_searchable_encounters_notes_and_muted.39a928"),
    ns.Locale:Get("nearby.main.hgn_bounty_bounty_board_contributions_and_claims.ddc3ea"),
    ns.Locale:Get("nearby.main.hgn_bounty_shared_opt_in_realm_faction.f577ad"),
    ns.Locale:Get("nearby.main.hgn_bounty_gold_account_gold_breakdown_and.3bf1cc"),
    ns.Locale:Get("nearby.main.hgn_bounty_export_name_prepare_a_bounty.3f20f2"),
    ns.Locale:Get("nearby.main.hgn_bounty_import_code_review_a_bounty.70e6f4"),
    ns.Locale:Get("nearby.main.hgn_bounty_test_feature_stop_toggle_a.58fcc4"),
    ns.Locale:Get("nearby.main.hgn_bounty_guide_chapter_stop_explore_the.b37a84"),
    ns.Locale:Get("nearby.main.hgn_bounty_suggestions_review_recurring_attackers_and.89d636"),
    ns.Locale:Get("nearby.main.hgn_clear_clear_recent_sightings_saved_history.b09c14"),
    ns.Locale:Get("nearby.main.hgn_forget_forget_the_history_of_enemies.0c6f62"),
    ns.Locale:Get("nearby.main.hgn_lock_lock_or_unlock_the_list.80ac31"),
    ns.Locale:Get("nearby.main.hgn_reset_put_the_list_back_where.a55551"),
  }, { [1] = "nearby.main.hgn_whether_the_list_is_on_and.aeb06d", [2] = "nearby.main.hgn_on_hgn_off_show_or_hide.d7fcff", [3] = "nearby.main.hgn_test_a_preview_to_drag_into.c31e64", [4] = "nearby.main.hgn_journal_searchable_encounters_notes_and_muted.39a928", [5] = "nearby.main.hgn_bounty_bounty_board_contributions_and_claims.ddc3ea", [6] = "nearby.main.hgn_bounty_shared_opt_in_realm_faction.f577ad", [7] = "nearby.main.hgn_bounty_gold_account_gold_breakdown_and.3bf1cc", [8] = "nearby.main.hgn_bounty_export_name_prepare_a_bounty.3f20f2", [9] = "nearby.main.hgn_bounty_import_code_review_a_bounty.70e6f4", [10] = "nearby.main.hgn_bounty_test_feature_stop_toggle_a.58fcc4", [11] = "nearby.main.hgn_bounty_guide_chapter_stop_explore_the.b37a84", [12] = "nearby.main.hgn_bounty_suggestions_review_recurring_attackers_and.89d636", [13] = "nearby.main.hgn_clear_clear_recent_sightings_saved_history.b09c14", [14] = "nearby.main.hgn_forget_forget_the_history_of_enemies.0c6f62", [15] = "nearby.main.hgn_lock_lock_or_unlock_the_list.80ac31", [16] = "nearby.main.hgn_reset_put_the_list_back_where.a55551" }),
  commands = {
    bounty = function(rest) ns.Commands.bounty(nil, "bounty " .. (rest or ""), ns.Bounty.Say) end,
    journal = function() ns.EnemyJournal.Open() end,
    on = function() Switch(true) end,
    off = function() Switch(false) end,
    test = Preview,
    clear = Clear,
    forget = Forget,
    lock = function()
      Core.SetPanelsLocked(not Core.db.locked)
      Util.Say(ns.Locale:Format("nearby.main.list_value2.67f9c4", { value2 = (Core.db.locked and "locked" or "unlocked") }))
    end,
    reset = function()
      ns.TimersWindowReset()
      Util.Say(ns.Locale:Get("nearby.main.list_position_reset.917b0f"))
    end,
  },
  default = function()
    Util.Say(ns.Locale:Format("nearby.main.nearby_enemies_value2_value4_remembered_hgn_on.3bcb49", { value2 = (Core.On("nearby") and "on" or "OFF"), value4 = Remembered() }))
  end,
  settings = ns.Localization.Define({
    hint = ns.Locale:Get("nearby.main.hostile_players_you_have_seen_in_the.2fc13d"),
    basic = { "nearby", "nearbyRows", "nearbySound" },
    keys = { "nearby", "nearbyRows", "nearbyFade", "nearbyForget", "nearbySound", "nearbyStealth", "nearbyHistory",
      "bounty", "bountyReceive", "bountyPublish", "bountyMinGold", "bountyDurationHours", "bountyAccountGold", "bountyRequireGold", "bountySound", "bountyAnnounce",
      "bountySuggestions", "bountyDeathShare", "bountySuggestionPersonal", "bountySuggestionGuildDeaths",
      "bountySuggestionVictims", "bountySuggestionWindow", "bountySuggestionCooldown" },
    buttons = { ns.Localization.Define({ ns.Locale:Get("nearby.main.preview_the_list.c52d30"), Preview }, { [1] = "nearby.main.preview_the_list.c52d30" }), ns.Localization.Define({ ns.Locale:Get("highground.hub.bounty_board.f37f61"), function() ns.Bounty.Board.Open() end, advanced = true }, { [1] = "highground.hub.bounty_board.f37f61" }),
      ns.Localization.Define({ ns.Locale:Get("highground.hub.enemy_journal.1dbc52"), function() ns.EnemyJournal.Open() end, advanced = true }, { [1] = "highground.hub.enemy_journal.1dbc52" }),
      ns.Localization.Define({ ns.Locale:Get("nearby.main.clear_recent_sightings.e0162d"), Clear, advanced = true }, { [1] = "nearby.main.clear_recent_sightings.e0162d" }) },
  }, { hint = "nearby.main.hostile_players_you_have_seen_in_the.2fc13d" }),
})
