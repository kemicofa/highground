local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public
local Demo = {}
B.Preview = Demo

-- Session-local examples. Never insert these records into stores, allocate
-- real IDs, emit model events, or pass them to the publishing/claim services.
function Demo.Ensure()
  Demo.state = Demo.state or { accountGold = true, requireGold = false, receive = true,
    publish = true, minGold = 500, capture = "pending", kills = 1, visited = {}, samples = {}, messages = {} }
  return Demo.state
end

function Demo.Sample(kind)
  local realm, now = ns.Core.myRealm or "Realm", P.Now()
  local U = ns.Util
  local unit = U.read(UnitIsPlayer, "target") and U.read(UnitIsVisible, "target")
    and ns.Core.CanonUnit("target") and "target" or "player"
  local name, poster = ns.Core.CanonUnit(unit) or ("WantedPreview-" .. realm), "PosterPreview-" .. realm
  local _, class = U.call(UnitClass, unit)
  class = U.value(class)
  local portraitLabel = U.read(UnitIsUnit, unit, "player") and ns.Locale:Get("shared.previewsamples.your_character_sample.2e9b8b") or ns.Locale:Get("shared.previewsamples.selected_character_sample.f27c86")
  local b = { name = name, by = poster, gold = 500, state = "approved", at = now,
    approver = "OfficerPreview-" .. realm, class = class, note = ns.Locale:Get("shared.previewsamples.camps_the_road_near_tarren_mill.633320"), previewPortraitLabel = portraitLabel }
  local row = { name = name, by = poster, gold = 500, state = "approved", scope = "guild",
    owner = ns.Locale:Get("shared.copy.posted_by_posterpreview.56afe6"), visibility = ns.Locale:Get("reputation.window.guild.54241a"), status = b.note, note = b.note, guild = b,
    class = class, previewPortraitLabel = portraitLabel }
  if kind == "nearby" or kind == "create" or kind == "gold" or kind == "suggestions" then
    b.by, b.state = B.Me(), "personal"
    row.by, row.state, row.scope = b.by, b.state, "mine"
    row.guild, row.personal, row.owner, row.visibility = nil, b, ns.Locale:Get("shared.boardmodel.your_bounty.2ec6d8"), ns.Locale:Get("shared.boardmodel.only_me.7631b1")
    row.status = ns.Locale:Get("shared.previewsamples.seen_now_tarren_mill.256718")
    if kind == "create" then b.killsRequired, b.killMethods = 1, "" end
  elseif kind ~= "guild" then
    local contributions = {}
    for i, gold in ipairs({ 500, 250 }) do
      contributions[i] = { id = "preview-offer-" .. i, contributor = "preview-account-" .. i,
        name = name, by = (i == 1 and "PosterPreview-" or "ScoutPreview-") .. realm, gold = gold,
        note = b.note, state = "active", createdAt = now, expiresAt = now + (i == 1 and 7200 or 86400),
        funds = "available", checkedAt = now, killsRequired = 3, killMethods = "execute" }
    end
    b = { name = name, gold = 750, pledgedGold = 750, state = "public", contributions = contributions,
      by = poster, note = b.note, expiresAt = now + 7200, class = class, previewPortraitLabel = portraitLabel,
      killsRequired = 3, killMethods = "execute" }
    if kind == "pot" then
      b.mega = true
      contributions[2].contract = B.Pot.Contract(contributions[1])
      contributions[2].expiresAt = contributions[1].expiresAt
    end
    row.guild, row.shared, row.gold, row.state, row.scope = nil, b, 750, "public", "public"
    row.owner, row.visibility = ns.Locale:Get("shared.previewsamples.2_contributions_from_other_players.49cd41"), "Shared"
    row.status = ns.Locale:Get("shared.previewsamples.750g_funds_reported_available_each_contribution_has.f4c87c")
  end
  row.preview = true
  return row, b
end

function Demo.BoardSamples()
  local out, realm = {}, ns.Core.myRealm or "Realm"
  local examples = {
    { "nearby", "RoguePreview", "ROGUE", 250, "Southshore" },
    { "nearby", "MagePreview", "MAGE", 750, ns.Locale:Get("shared.previewsamples.arathi_highlands.bc8405") },
    { "guild", "RaiderPreview", "WARRIOR", 1000, ns.Locale:Get("shared.previewsamples.stranglethorn_vale.82d36d") },
    { "guild", "ScoutPreview", "HUNTER", 300, "Ashenvale", "pending" },
    { "shared", "WarlockPreview", "WARLOCK", 900, ns.Locale:Get("shared.previewsamples.the_hinterlands.ae2a20") },
    { "shared", "PaladinPreview", "PALADIN", 1500, ns.Locale:Get("shared.previewsamples.eastern_plaguelands.555e2b") },
  }
  for i, def in ipairs(examples) do
    local row, b = Demo.Sample(def[1])
    b.name, b.class, b.gold = def[2] .. "-" .. realm, def[3], def[4]
    b.note, b.previewPortraitLabel = ns.Locale:Format("shared.previewsamples.sample_target_last_seen_in_value2.d63c99", { value2 = def[5] }), ns.Locale:Get("shared.previewsamples.sample_target.650520")
    row.name, row.class, row.gold, row.note = b.name, b.class, b.gold, b.note
    row.status, row.location, row.previewPortraitLabel = b.note, ns.Locale:Format("shared.previewsamples.last_seen_value2.b31bec", { value2 = def[5] }), b.previewPortraitLabel
    if def[6] then
      b.state, b.approver, row.state = def[6], nil, def[6]
      row.status = ns.Locale:Get("shared.previewflows.awaiting_officer_approval.5ee88d")
    end
    if b.contributions then
      b.pledgedGold = b.gold
      for j, contribution in ipairs(b.contributions) do
        contribution.id, contribution.name = "preview-board-" .. i .. "-" .. j, b.name
        contribution.gold, contribution.note = b.gold * (j == 1 and 2 or 1) / 3, b.note
      end
      row.status = ns.Locale:Format("shared.previewsamples.value1_funds_reported_available_each_contribution_has.ea0853", { value1 = ns.Util.Gold(b.gold) })
    end
    out[#out + 1] = { row, b }
  end
  return out
end

function Demo.Claims()
  local realm, now = ns.Core.myRealm or "Realm", P.Now()
  local out = {}
  for i, state in ipairs({ "claimed", "claimed", "claimed", "approved", "paid", "rejected" }) do
    local mine = i > 2
    out[i] = { id = "preview-claim-" .. i, pledge = "preview-offer-" .. i,
      name = i <= 2 and Demo.bounty and Demo.bounty.name
        or ({ "WantedPreview-", "WantedPreview-", "RaiderPreview-", "RoguePreview-", "MagePreview-", "ScoutPreview-" })[i] .. realm,
      gold = i == 1 and 500 or 250, by = mine and B.Me() or ((i == 1 and "PosterPreview-" or "ScoutPreview-") .. realm),
      claimant = mine and ("HunterPreview-" .. realm) or B.Me(),
      public = true, previewManage = mine, received = true, state = state, claimedAt = now, killedAt = now,
      evidence = ns.Caps.combatLog and "observed killing blow" or "honor credit",
      cause = ns.Caps.combatLog and { event = "SPELL_DAMAGE", spellID = 5308, spellName = "Execute" } or nil,
      killsRequired = 3, killMethods = "execute",
      reviewedBy = state ~= "claimed" and B.Me() or nil, paidAt = state == "paid" and now or nil }
  end
  return out
end

function Demo.Wallet()
  local state, realm, now = Demo.state or {}, ns.Core.myRealm or "Realm", P.Now()
  local rows = {
    { name = B.Me(), current = true, balance = 1253742, seenAt = now },
    { name = "BankerPreview-" .. realm, balance = 17506218, seenAt = now - 3600 },
    { name = "ScoutPreview-" .. realm, balance = 3249925, seenAt = now - 86400 },
  }
  local enabled, total = state.accountGold ~= false, 0
  for _, row in ipairs(rows) do if enabled or row.current then total = total + row.balance end end
  local reserved = 7500000
  return { rows = rows, enabled = enabled, required = state.requireGold == true,
    total = total, reserved = reserved, available = math.max(0, total - reserved) }
end

function Demo.Reports()
  local name, now, realm = Demo.bounty.name, P.Now(), ns.Core.myRealm or "Realm"
  return { name = name, total = 5, personal = 2, guildDeaths = 3, guildVictimCount = 2,
    status = ns.Locale:Get("shared.previewsamples.5_reported_deaths_tarren_mill.b6b173"), victims = { [B.Me()] = 2, ["ScoutPreview-" .. realm] = 3 },
    reports = { { at = now - 60, victim = ns.Core.DisplayName(B.Me()), zone = "Tarren Mill", source = "recap" },
      { at = now - 300, victim = "ScoutPreview", zone = "Hillsbrad Foothills", source = "combat" } } }
end

Demo.scenes = {
  ns.Localization.Define({ key = "nearby", label = ns.Locale:Get("shared.previewsamples.nearby_alerts.429ece"), title = ns.Locale:Get("shared.previewsamples.spot_a_wanted_player.3f246b"),
    description = ns.Locale:Get("shared.previewsamples.see_the_wanted_popup_portrait_nearby_highlight.04e33a"),
    detail = ns.Locale:Get("shared.previewsamples.portraits_use_your_selected_player_or_your.6ec2ed") }, { label = "shared.previewsamples.nearby_alerts.429ece", title = "shared.previewsamples.spot_a_wanted_player.3f246b", description = "shared.previewsamples.see_the_wanted_popup_portrait_nearby_highlight.04e33a", detail = "shared.previewsamples.portraits_use_your_selected_player_or_your.6ec2ed" }),
  ns.Localization.Define({ key = "board", label = ns.Locale:Get("shared.previewsamples.wanted_board.b69f07"), title = ns.Locale:Get("shared.previewsamples.wanted_cards_and_full_posters.c0244c"),
    description = ns.Locale:Get("shared.previewsamples.click_the_wanted_card_or_view_bounty.b1ae32"),
    detail = ns.Locale:Get("shared.previewsamples.start_tracking_adds_a_target_to_my.e9b443") }, { label = "shared.previewsamples.wanted_board.b69f07", title = "shared.previewsamples.wanted_cards_and_full_posters.c0244c", description = "shared.previewsamples.click_the_wanted_card_or_view_bounty.b1ae32", detail = "shared.previewsamples.start_tracking_adds_a_target_to_my.e9b443" }),
  ns.Localization.Define({ key = "create", label = ns.Locale:Get("shared.previewsamples.create_terms.1ea507"), title = ns.Locale:Get("shared.previewsamples.build_a_sample_bounty.01af6d"),
    description = ns.Locale:Get("shared.previewsamples.three_steps_target_reward_review_nothing_is.cc55e8"),
    detail = ns.Locale:Get("shared.previewsamples.save_returns_to_the_tour_sharing_is.631c62") }, { label = "shared.previewsamples.create_terms.1ea507", title = "shared.previewsamples.build_a_sample_bounty.01af6d", description = "shared.previewsamples.three_steps_target_reward_review_nothing_is.cc55e8", detail = "shared.previewsamples.save_returns_to_the_tour_sharing_is.631c62" }),
  ns.Localization.Define({ key = "gold", label = ns.Locale:Get("shared.form.account_gold.d091f7"), title = ns.Locale:Get("shared.previewsamples.use_gold_across_your_characters.423446"),
    description = ns.Locale:Get("shared.previewsamples.see_a_sample_wallet_and_the_bag.2652f4"),
    detail = ns.Locale:Get("shared.previewsamples.account_tracking_is_on_by_default_requiring.faa230") }, { label = "shared.form.account_gold.d091f7", title = "shared.previewsamples.use_gold_across_your_characters.423446", description = "shared.previewsamples.see_a_sample_wallet_and_the_bag.2652f4", detail = "shared.previewsamples.account_tracking_is_on_by_default_requiring.faa230" }),
  ns.Localization.Define({ key = "guild", label = ns.Locale:Get("shared.previewsamples.guild_approval.d5172b"), title = ns.Locale:Get("shared.previewsamples.submit_and_approve_a_guild_bounty.93c32d"),
    description = ns.Locale:Get("shared.previewsamples.try_awaiting_approval_officer_approval_and_rejection.1aed32"),
    detail = ns.Locale:Get("shared.previewsamples.approved_guild_rewards_can_show_a_new.36cbe4") }, { label = "shared.previewsamples.guild_approval.d5172b", title = "shared.previewsamples.submit_and_approve_a_guild_bounty.93c32d", description = "shared.previewsamples.try_awaiting_approval_officer_approval_and_rejection.1aed32", detail = "shared.previewsamples.approved_guild_rewards_can_show_a_new.36cbe4" }),
  ns.Localization.Define({ key = "shared", label = ns.Locale:Get("shared.previewsamples.shared_arrivals.7e4e7c"), title = ns.Locale:Get("shared.previewsamples.a_bounty_matches_your_filters.542556"),
    description = ns.Locale:Get("shared.previewsamples.use_start_tracking_or_ignore_on_the.ac8ad1"),
    detail = ns.Locale:Get("shared.previewsamples.the_notification_minimum_counts_rewards_with_current.7ea6f7") }, { label = "shared.previewsamples.shared_arrivals.7e4e7c", title = "shared.previewsamples.a_bounty_matches_your_filters.542556", description = "shared.previewsamples.use_start_tracking_or_ignore_on_the.ac8ad1", detail = "shared.previewsamples.the_notification_minimum_counts_rewards_with_current.7ea6f7" }),
  ns.Localization.Define({ key = "pot", label = ns.Locale:Get("shared.details.add_gold.f9a980"), title = ns.Locale:Get("shared.previewsamples.grow_a_bounty_s_pot.fc063b"),
    description = ns.Locale:Get("shared.previewsamples.add_a_sample_contribution_review_the_original.3e1e7c"),
    detail = ns.Locale:Get("shared.previewsamples.accepting_the_terms_means_the_original_poster.cb648e") }, { label = "shared.details.add_gold.f9a980", title = "shared.previewsamples.grow_a_bounty_s_pot.fc063b", description = "shared.previewsamples.add_a_sample_contribution_review_the_original.3e1e7c", detail = "shared.previewsamples.accepting_the_terms_means_the_original_poster.cb648e" }),
  ns.Localization.Define({ key = "exchange", label = ns.Locale:Get("shared.previewsamples.share_import.d10b63"), title = ns.Locale:Get("shared.previewsamples.copy_a_bounty_link_and_review_an.e6954f"),
    description = ns.Locale:Get("shared.previewsamples.sharing_outside_the_addon_is_optional_copy.b960a6"),
    detail = ns.Locale:Get("shared.previewsamples.choose_select_link_to_copy_press_ctrl.75c0bf") }, { label = "shared.previewsamples.share_import.d10b63", title = "shared.previewsamples.copy_a_bounty_link_and_review_an.e6954f", description = "shared.previewsamples.sharing_outside_the_addon_is_optional_copy.b960a6", detail = "shared.previewsamples.choose_select_link_to_copy_press_ctrl.75c0bf" }),
  ns.Localization.Define({ key = "kill", label = ns.Locale:Get("shared.previewsamples.kills_reports.48e18a"), title = ns.Locale:Get("shared.previewsamples.detected_kills_create_reports_automatically.0ec7e1"),
    description = ns.Locale:Get("shared.previewsamples.use_view_sample_report_to_follow_review.4dce46"),
    detail = ns.Locale:Get("shared.previewsamples.readable_killing_blows_are_confirmed_locally_named.83de2e") }, { label = "shared.previewsamples.kills_reports.48e18a", title = "shared.previewsamples.detected_kills_create_reports_automatically.0ec7e1", description = "shared.previewsamples.use_view_sample_report_to_follow_review.4dce46", detail = "shared.previewsamples.readable_killing_blows_are_confirmed_locally_named.83de2e" }),
  ns.Localization.Define({ key = "claims", label = ns.Locale:Get("shared.board.claims_payments.f83748"), title = ns.Locale:Get("shared.previewsamples.follow_reports_through_review_and_payment.7bf30e"),
    description = ns.Locale:Get("shared.previewsamples.browse_hunter_and_poster_examples_awaiting_review.ee1784"),
    detail = ns.Locale:Get("shared.previewsamples.hunters_cannot_approve_their_own_reports_the.8e822e") }, { label = "shared.board.claims_payments.f83748", title = "shared.previewsamples.follow_reports_through_review_and_payment.7bf30e", description = "shared.previewsamples.browse_hunter_and_poster_examples_awaiting_review.ee1784", detail = "shared.previewsamples.hunters_cannot_approve_their_own_reports_the.8e822e" }),
  ns.Localization.Define({ key = "suggestions", label = ns.Locale:Get("shared.board.suggestions.861edb"), title = ns.Locale:Get("shared.previewsamples.review_enemies_suggested_by_death_reports.470074"),
    description = ns.Locale:Get("shared.previewsamples.inspect_sample_reports_review_a_prefilled_bounty.a7057d"),
    detail = ns.Locale:Get("shared.previewsamples.suggestions_combine_your_deaths_and_participating_guild.4596f6") }, { label = "shared.board.suggestions.861edb", title = "shared.previewsamples.review_enemies_suggested_by_death_reports.470074", description = "shared.previewsamples.inspect_sample_reports_review_a_prefilled_bounty.a7057d", detail = "shared.previewsamples.suggestions_combine_your_deaths_and_participating_guild.4596f6" }),
}
