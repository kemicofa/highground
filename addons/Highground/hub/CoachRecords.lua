local _, ns = ...
local C = ns.Onboarding.Coach

function C.RecordSteps()
  local H, N = ns.MatchHistory, C.Native
  local data = C.matchSample or {}; C.matchSample = data
  data.records = {
    { id = "warsong", name = "Warsong Gulch", result = "Win", character = "Example", game = "Sample",
      started = time() - 3600, duration = 840, spec = 71, stats = { killingBlows = 3, honorableKills = 12, deaths = 2,
        honorGained = 240, damageDone = 48500, healingDone = 3200 },
      events = { { at = 0, text = ns.Locale:Get("highground.coachrecords.joined_warsong_gulch.06bcbe") }, { at = 242, text = ns.Locale:Get("highground.coachrecords.your_team_captured_the_flag.27a3c4") }, { at = 840, text = ns.Locale:Get("highground.coachrecords.victory.e71f15") } } },
    { id = "arathi", name = "Arathi Basin", result = "Left early", character = "Example", game = "Sample",
      started = time() - 7200, duration = 250, spec = 71, stats = {},
      events = { { at = 0, text = ns.Locale:Get("highground.coachrecords.joined_arathi_basin.aa8cb9") }, { at = 250, text = ns.Locale:Get("highground.coachrecords.left_before_the_result_was_observed.305ce8") } } },
  }
  data.entries = function()
    local entries, summary = H.Entries(data.records); data.summary = ns.Locale:Format("highground.coachrecords.sample_records_summary.ea5f24", { summary = summary })
    return entries
  end
  local function Open()
    local w = H.Build(data); w:Open(); N.Track(w); N.Fit(w)
    return w
  end
  local function Context() return data.win end
  return {
    { id = "find", title = ns.Locale:Get("highground.coachrecords.find_a_previous_match.8646a0"), text = ns.Locale:Get("highground.coachrecords.search_by_map_result_or_character_these.9f622d"),
      enter = Open, target = function() return data.win.search end, context = Context },
    { id = "result", title = ns.Locale:Get("highground.coachrecords.choose_a_match_to_inspect.91330e"), text = ns.Locale:Get("highground.coachrecords.select_warsong_gulch_or_arathi_basin_left.1fabad"),
      enter = Open, target = function() return data.win.rows[1] end, context = Context },
    { id = "summary", title = ns.Locale:Get("highground.coachrecords.read_the_match_summary.37a497"), text = ns.Locale:Get("highground.coachrecords.the_card_shows_the_result_your_specialization.b2cebf"),
      enter = Open, target = function() return data.win.profile and data.win.profile.stats end, context = Context },
    { id = "timeline", title = ns.Locale:Get("highground.coachrecords.open_the_recorded_timeline.0c1d7f"), text = ns.Locale:Get("highground.coachrecords.full_timeline_lists_the_objective_events_observed.333047"),
      enter = Open, target = function() return data.win.actions[1] end, context = Context,
      requireAction = true, advance = function() return data.timeline and data.timeline:IsVisible() end, hint = ns.Locale:Get("highground.coachrecords.click_full_timeline.66d8b7") },
    { id = "events", title = ns.Locale:Get("highground.coachrecords.follow_what_happened.8a200e"), text = ns.Locale:Get("highground.coachrecords.times_are_measured_from_joining_the_match.2d3547"),
      enter = function()
        if data.timeline and data.timeline:IsVisible() then N.Track(data.timeline); N.Fit(data.timeline)
        else Open() end
      end,
      target = function() return data.timeline and data.timeline:IsVisible() and data.timeline.box or data.win.actions[1] end,
      context = function() return data.timeline and data.timeline:IsVisible() and data.timeline or data.win end },
  }
end

-- A separate source drives the native Reputation windows. Only these local
-- examples can change; no live model, listener, transport or handler is swapped.
local W, K = ns.Reputation, ns.Kit
local R = { provider = { ready = true, UI = { mode = "organizations", page = 1 } } }
C.ReputationSample = R
local P, U = R.provider, R.provider.UI
for _, key in ipairs({ "CATEGORIES", "REPLY_INTERVALS", "DEFAULT_REPLY", "Text", "Copy", "Target", "CategoryText" }) do P[key] = W[key] end
U.Label = W.UI.Label
function U.Dialog(key, title, width, height)
  local f = W.UI.Dialog(key, title, width, height, true)
  f:SetSub(ns.Locale:Get("highground.coachrecords.sample_organization_nothing_is_sent.4c6fc7"))
  f:HookScript("OnShow", function() C.Native.Track(f); C.Native.Fit(f) end)
  return f
end
function U.Refresh() return W.UI.Refresh(P) end
function U.RefreshDialogs() return W.UI.RefreshDialogs(P) end
function U.CommunityChoices(_, all) return W.UI.CommunityChoices(P, all) end
function U.Result(f, value, err) return W.UI.Result(f, value, err, P) end
function U.GetRouter() return W.UI.GetRouter(P) end
function U.SetMode(mode, organization) return W.UI.SetMode(mode, organization, P) end
function U.SelectTab(mode, organization) return W.UI.SelectTab(mode, organization, P) end
function U.ReturnToOrganizations() return W.UI.ReturnToOrganizations(P) end
function U.GoPage(delta) return W.UI.GoPage(delta, P) end
function U.BuildOverview(f) return W.UI.BuildOverview(f, P) end
function U.RefreshOverview(_, org, c) return W.UI.RefreshOverview(P, org, c) end
function P.Build() return W.Build(P) end
function P.Open() return W.Open(false, P) end
function P.Joined(c) return R.data and c == R.data.community and c.enabled == true end
function P.Get(id) return R.data and (not id or id == R.data.community.id) and R.data.community or nil end
function P.List() return P.Joined(P.Get()) and { P.Get() } or {} end
function P.Name() return ns.Locale:Get("highground.coachrecords.silverwing_scouts_sample.260512") end
function P.Role(c) return P.Joined(c) and (R.data.moderator and ns.Locale:Get("highground.coachrecords.officer.f58330") or ns.Locale:Get("highground.coachrecords.member.6853c9")) or nil end
function P.CanModerate(c) return P.Joined(c) and c.activated == true and R.data.moderator == true end
function P.MemberCount() return 3 end
function P.Status() return R.data.message or ns.Locale:Get("highground.coachrecords.sample_reports_decisions_and_settings_stay_in.1a734c") end
function P.Changed() U.Refresh(); U.RefreshDialogs() end
function P.Say(message) R.data.message = message; U.Refresh() end
function P.Enable() R.data.community.enabled, R.data.community.activated = true, true; P.Changed(); return R.data.community end
function P.Follow() R.data.community.enabled = true; P.Changed(); return R.data.community end
function P.Discover() end
function P.Availability()
  if not P.Joined(P.Get()) then return { code = "paused", label = ns.Locale:Get("highground.coachrecords.off_on_this_account.264e67"), message = ns.Locale:Get("highground.coachrecords.enable_the_sample_explicitly_in_overview_nothing.4584b9") } end
  return { ready = true, label = ns.Locale:Get("highground.coachrecords.enabled_moderator_online.21d494"), message = ns.Locale:Get("highground.coachrecords.a_sample_moderator_can_receive_this_proposal.a2aac7") }
end
function P.DeliveryText() return ns.Locale:Get("highground.coachrecords.received_awaiting_review.ed989d") end
function P.Disable() R.data.community.enabled = false; P.Changed() end
function P.RequestSync()
  local data, request = R.data, {}
  C_Timer.After(0.6, function()
    if R.data == data then request.completed = true end
  end)
  return request
end
function P.SendReports() end
function P.OpenNative() P.Say(ns.Locale:Get("highground.coachrecords.sample_guild_real_membership_and_roles_are.154a50")) end
function P.ReplyInterval()
  for _, choice in ipairs(P.REPLY_INTERVALS) do if P.db.settings.replyInterval == choice.key then return choice.key end end
  return 0
end
P.organizations = {
  CanModerate = function() return R.data.moderator == true end,
  Role = function() return R.data.moderator and "moderator" or "member" end,
  List = function() return { { id = P.Get().id, name = P.Name(), kind = "guild" } } end,
  Get = function(id) return id == P.Get().id and { id = id, name = P.Name(), kind = "guild" } end,
  Members = function() return { { name = "Sample Member-Example", role = ns.Locale:Get("highground.coachrecords.member.6853c9"), online = true },
    { name = "Sample Officer-Example", role = ns.Locale:Get("highground.coachrecords.officer.f58330"), online = true }, { name = "Sample Scout-Example", role = ns.Locale:Get("highground.coachrecords.member.6853c9"), online = false } } end,
}
function P.FindCase(_, target)
  local row = R.data.row
  return row and W.Same(row.target, target) and row or nil
end
function P.OwnReport(c, target)
  local row = P.FindCase(c, target)
  return row and row.reports.sample or nil
end
function P.Rows(_, mode)
  local row = R.data.row
  return row and (mode == "history" or mode == "proposals" and row.pending > 0 or mode == "blacklist" and row.active)
    and { row } or {}
end
function P.Submit(c, target, categories, note)
  if not P.Joined(c) then return nil, ns.Locale:Get("highground.coachrecords.enable_the_sample_organization_first.ed51ab") end
  if not W.ValidTarget(target) then return nil, ns.Locale:Get("highground.coachrecords.select_an_exact_player_identity.d6a825") end
  categories = W.Categories(categories)
  if not categories then return nil, ns.Locale:Get("highground.coachrecords.choose_at_least_one_category.2d9bda") end
  local row = P.FindCase(c, target) or { target = W.Copy(target), reports = {}, actions = {}, count = 1 }
  local report = { by = "Sample Member-Example", categories = categories, note = W.Text(note, 280), delivery = ns.Locale:Get("highground.coachrecords.received_in_sample.cb63da") }
  row.reports.sample, row.pending, row.state = report, 1, row.active and "blacklisted" or "proposed"
  R.data.row, R.data.submissions = row, R.data.submissions + 1
  P.Changed(); return report
end
function P.Decide(c, target, kind, categories, note)
  if not P.CanModerate(c) then return nil, ns.Locale:Get("highground.coachrecords.only_a_sample_officer_can_do_this.c89711") end
  if not W.ValidTarget(target) then return nil, ns.Locale:Get("highground.coachrecords.select_an_exact_player_identity.d6a825") end
  if not ({ ban = true, revoke = true, dismiss = true })[kind] then return nil, ns.Locale:Get("highground.coachrecords.unknown_moderation_action.65e380") end
  categories, note = W.Categories(categories), W.Text(note, 280)
  if kind == "ban" and not categories then return nil, ns.Locale:Get("highground.coachrecords.choose_at_least_one_category.2d9bda") end
  if kind ~= "ban" and note == "" then return nil, ns.Locale:Get("highground.coachrecords.a_reason_is_required.6b13e9") end
  local row = P.FindCase(c, target) or { target = W.Copy(target), reports = {}, actions = {}, count = 0 }
  local op = { id = "sample:" .. (#row.actions + 1), clock = #row.actions + 1, kind = kind,
    at = time(), by = "Sample Officer-Example", categories = categories or {}, note = note }
  row.actions[#row.actions + 1] = op
  if kind == "ban" then row.active = op elseif kind == "revoke" then row.active = nil end
  row.pending, row.state = 0, row.active and "blacklisted" or kind == "revoke" and "revoked" or "dismissed"
  R.data.row, R.data.decisions = row, R.data.decisions + 1
  P.Changed(); return op
end
function P.OpenReport(target, community)
  W.OpenReport(target or R.data.target, community, P)
  if not P.OwnReport(community, target or R.data.target) then
    U.report.categories.other:SetChecked(true, true)
    ns.Localization.Bind(U.report.note, "highground.coachrecords.example_encounter_for_learning_the_report_workflow.94648b")
  end
end
function P.OpenDetails(c, row) return W.OpenDetails(c, row, P) end
function P.OpenReason(c, target, kind) return W.OpenReason(c, target, kind, P) end
function R.Stop()
  W.UI.CloseDialogs(P)
  if U.window then K.Windows.Forget(U.window); U.window:Hide() end
  R.data = nil
end
function R.Ensure()
  if R.data then return end
  R.data = { community = { id = "guild:sample@guide", enabled = false, activated = true, synced = true }, submissions = 0, decisions = 0,
    target = assert(W.Target(ns.Caps.hideRealmNames and ns.Locale:Get("highground.coachrecords.practice_player.b18360") or "PracticePlayer", "Example")) }
  P.db = { settings = {} }
  U.mode, U.page = "organizations", 1
  if U.router then U.router:Reset({ name = "organizations" }) end
end
local function Visible(f) return f and f:IsVisible() end
local function DetailsClosed() return not Visible(U.details) and not Visible(U.reason) and not Visible(U.report) end
local function Context()
  for _, key in ipairs({ "reason", "report", "details", "window" }) do if Visible(U[key]) then return U[key] end end
end
local function Open(mode, moderator)
  R.Ensure()
  R.data.moderator = moderator == true
  if mode ~= "organizations" then P.Enable() end
  P.Open(); U.SetMode(mode, P.Get().id); C.Native.Track(U.window); C.Native.Fit(U.window)
end
local function Proposal()
  if not R.data.row or R.data.row.pending == 0 then
    P.Submit(P.Get(), R.data.target, { other = true }, ns.Locale:Get("highground.coachrecords.example_encounter_for_learning_the_report_workflow.94648b"))
  end
end
local function Decision()
  if not R.data.row or not R.data.row.active then
    Proposal(); P.Decide(P.Get(), R.data.row.target, "ban", { other = true }, ns.Locale:Get("highground.coachrecords.reviewed_example_encounter.76b276"))
  end
end
local function Details(approved)
  if Visible(U.details) then return end
  Open(approved and "blacklist" or "proposals", true)
  if approved then Decision() else Proposal() end
  P.OpenDetails(P.Get(), R.data.row)
end
function C.ReputationSteps()
  local function Tab(key)
    local group = (key == "settings" or key == "organizations") and U.window.workspaceTabs or U.window.pageTabs
    return group:Target(key)
  end
  local function Step(id, title, text, enter, target, advance, hint)
    return { id = id, title = title, text = text, enter = enter, target = target, context = Context,
      requireAction = advance ~= nil, advance = advance, hint = hint }
  end
  return {
    ns.Localization.Define(Step("organization", ns.Locale:Get("highground.coachrecords.choose_your_guild_or_community.30ffee"), ns.Locale:Get("guide.reputation.window"),
      function() Open("organizations"); P.Disable() end, function() return U.window.rows[1].action end,
      function() return U.mode == "overview" end, ns.Locale:Get("highground.coachrecords.click_open_this_sample_never_sends_reports.e73433")), { title = "highground.coachrecords.choose_your_guild_or_community.30ffee", text = "guide.reputation.window" }),
    ns.Localization.Define(Step("participation", ns.Locale:Get("highground.coachrecords.choose_when_to_participate.9f3f08"), ns.Locale:Get("highground.coachrecords.overview_keeps_participation_controls_together_this_sample.6c5705"),
      function() Open("overview"); P.Disable() end, function() return U.window.disable end,
      function() return P.Joined(P.Get()) end, ns.Locale:Get("highground.coachrecords.click_enable_on_this_account.1f09c9")), { title = "highground.coachrecords.choose_when_to_participate.9f3f08", text = "highground.coachrecords.overview_keeps_participation_controls_together_this_sample.6c5705" }),
    ns.Localization.Define(Step("updates", ns.Locale:Get("highground.coachrecords.wait_for_an_update_check.da8d86"), ns.Locale:Get("highground.coachrecords.check_for_updates_shows_a_loader_and.ecb9e2"),
      function() Open("overview"); U.window.updateCheck:Cancel(); U.window.updateCheck.state = "idle"; U.window.sync:RefreshBusy() end,
      function() return U.window.sync end,
      function() return U.window.updateCheck.state == "succeeded" end, ns.Locale:Get("highground.coachrecords.click_check_for_updates_and_wait_for.1e42f3")), { title = "highground.coachrecords.wait_for_an_update_check.da8d86", text = "highground.coachrecords.check_for_updates_shows_a_loader_and.ecb9e2" }),
    ns.Localization.Define(Step("report_open", ns.Locale:Get("highground.coachrecords.open_the_report_form.7db0de"), ns.Locale:Get("highground.coachrecords.report_player_opens_the_same_form_used.de1668"),
      function() Open("blacklist") end, function() return U.window.add end,
      function() return Visible(U.report) end, ns.Locale:Get("highground.coachrecords.click_report_player.a03a47")), { title = "highground.coachrecords.open_the_report_form.7db0de", text = "highground.coachrecords.report_player_opens_the_same_form_used.de1668" }),
    ns.Localization.Define(Step("proposal", ns.Locale:Get("highground.coachrecords.submit_a_proposal.5b9a99"), ns.Locale:Get("highground.coachrecords.check_the_player_category_and_note_then.309f30"),
      function()
        R.Ensure(); R.submissionStart = R.data.submissions
        if not Visible(U.report) then Open("blacklist"); P.OpenReport(nil, P.Get()) end
      end, function() return U.report.submit end,
      function()
        if not Visible(U.report) then return R.data.submissions > R.submissionStart and "proposals_open" or "report_open" end
      end, ns.Locale:Get("highground.coachrecords.edit_the_sample_report_then_click_submit.445d86")), { title = "highground.coachrecords.submit_a_proposal.5b9a99", text = "highground.coachrecords.check_the_player_category_and_note_then.309f30" }),
    ns.Localization.Define(Step("proposals_open", ns.Locale:Get("highground.coachrecords.find_pending_reports.448e9a"), ns.Locale:Get("highground.coachrecords.the_proposals_tab_lists_reports_awaiting_review.f792b8"),
      function() Open("blacklist"); Proposal() end, function() return Tab("proposals") end,
      function() return U.mode == "proposals" end, ns.Locale:Get("highground.coachrecords.choose_proposals_in_the_tabs_or_page.725998")), { title = "highground.coachrecords.find_pending_reports.448e9a", text = "highground.coachrecords.the_proposals_tab_lists_reports_awaiting_review.f792b8" }),
    ns.Localization.Define(Step("moderation", ns.Locale:Get("highground.coachrecords.enable_moderation_when_you_are_ready.1ef1b7"), ns.Locale:Get("highground.coachrecords.sample_officer_view_if_you_already_participate.dc1f5a"),
      function() Open("overview", true); P.Get().activated = false; P.Changed() end,
      function() return U.window.openReports end,
      function() return P.CanModerate(P.Get()) and U.mode == "proposals" end, ns.Locale:Get("highground.coachrecords.click_enable_moderation_your_real_role_stays.9c4ac2")), { title = "highground.coachrecords.enable_moderation_when_you_are_ready.1ef1b7", text = "highground.coachrecords.sample_officer_view_if_you_already_participate.dc1f5a" }),
    ns.Localization.Define(Step("details_open", ns.Locale:Get("highground.coachrecords.inspect_the_proposal.78f73b"), ns.Locale:Get("highground.coachrecords.sample_officer_view_details_opens_the_player.b61867"),
      function() Open("proposals", true); Proposal() end, function() return U.window.rows[1].action end,
      function() return Visible(U.details) end, ns.Locale:Get("highground.coachrecords.click_details.96898c")), { title = "highground.coachrecords.inspect_the_proposal.78f73b", text = "highground.coachrecords.sample_officer_view_details_opens_the_player.b61867" }),
    ns.Localization.Define(Step("review", ns.Locale:Get("highground.coachrecords.review_before_approving.2cea1b"), ns.Locale:Get("highground.coachrecords.read_the_report_and_its_note_review.8aa605"),
      function() Details(false) end, function() return Visible(U.reason) and U.reason.submit or U.details.approve end,
      function()
        if Visible(U.report) then return "approve" end
        if DetailsClosed() then return R.data.row.pending == 0 and "overview_open" or "details_open" end
      end, function() return Visible(U.reason) and ns.Locale:Get("highground.coachrecords.enter_a_reason_then_save_or_close.f18b52") or ns.Locale:Get("highground.coachrecords.click_review_blacklist.fb943a") end), { title = "highground.coachrecords.review_before_approving.2cea1b", text = "highground.coachrecords.read_the_report_and_its_note_review.8aa605" }),
    ns.Localization.Define(Step("approve", ns.Locale:Get("highground.coachrecords.save_the_decision.6d54c0"), ns.Locale:Get("highground.coachrecords.an_officer_chooses_the_approved_categories_and.42ee1f"),
      function()
        R.Ensure(); R.decisionStart = R.data.decisions
        if not Visible(U.report) then Details(false); P.OpenReport(R.data.row.target, P.Get()) end
      end, function() return U.report.submit end,
      function()
        if not Visible(U.report) then return R.data.decisions > R.decisionStart and "return" or "review" end
      end, ns.Locale:Get("highground.coachrecords.click_save_blacklist_decision.24f82e")), { title = "highground.coachrecords.save_the_decision.6d54c0", text = "highground.coachrecords.an_officer_chooses_the_approved_categories_and.42ee1f" }),
    ns.Localization.Define(Step("return", ns.Locale:Get("highground.coachrecords.return_to_the_list.9ec75d"), ns.Locale:Get("highground.coachrecords.the_sample_decision_is_recorded_close_this.926c96"),
      function()
        R.Ensure(); if not Visible(U.details) then Open("proposals", true); Decision() end
        Details(true); P.OpenDetails(P.Get(), R.data.row)
      end, function() return Visible(U.reason) and U.reason.submit or U.details.close end,
      function() if DetailsClosed() then return R.data.row.active and "blacklist_open" or "overview_open" end end,
      ns.Locale:Get("highground.coachrecords.click_the_window_s_close_button.eb02ad")), { title = "highground.coachrecords.return_to_the_list.9ec75d", text = "highground.coachrecords.the_sample_decision_is_recorded_close_this.926c96" }),
    ns.Localization.Define(Step("blacklist_open", ns.Locale:Get("highground.coachrecords.find_approved_entries.fb5abc"), ns.Locale:Get("highground.coachrecords.blacklist_contains_approved_decisions_a_proposal_alone.6f4aee"),
      function() Open("proposals", true); Decision() end, function() return Tab("blacklist") end,
      function() return U.mode == "blacklist" end, ns.Locale:Get("highground.coachrecords.choose_blacklist_in_the_tabs_or_page.a761fc")), { title = "highground.coachrecords.find_approved_entries.fb5abc", text = "highground.coachrecords.blacklist_contains_approved_decisions_a_proposal_alone.6f4aee" }),
    ns.Localization.Define(Step("decision", ns.Locale:Get("highground.coachrecords.read_the_approved_record.b6067f"), ns.Locale:Get("highground.coachrecords.open_details_to_see_the_public_reason.cc88a4"),
      function() Open("blacklist", true); Decision() end, function() return U.window.rows[1].action end,
      function() return Visible(U.details) end, ns.Locale:Get("highground.coachrecords.click_details.96898c")), { title = "highground.coachrecords.read_the_approved_record.b6067f", text = "highground.coachrecords.open_details_to_see_the_public_reason.cc88a4" }),
    ns.Localization.Define(Step("history", ns.Locale:Get("highground.coachrecords.decisions_keep_their_history.7db17a"), ns.Locale:Get("highground.coachrecords.the_history_records_who_approved_the_entry.c4ced1"),
      function() Details(true) end, function() return Visible(U.reason) and U.reason.submit or U.details.close end,
      DetailsClosed, function() return Visible(U.reason) and ns.Locale:Get("highground.coachrecords.enter_a_reason_then_save_or_close.f18b52") or ns.Locale:Get("highground.coachrecords.close_the_player_history.0bfe71") end), { title = "highground.coachrecords.decisions_keep_their_history.7db17a", text = "highground.coachrecords.the_history_records_who_approved_the_entry.c4ced1" }),
    ns.Localization.Define(Step("overview_open", ns.Locale:Get("highground.coachrecords.manage_participation_in_one_place.5d3765"), ns.Locale:Get("highground.coachrecords.return_to_overview_to_pause_this_organization.69eaa8"),
      function() Open("blacklist", true) end, function() return Tab("overview") end,
      function() return U.mode == "overview" end, ns.Locale:Get("highground.coachrecords.choose_overview_in_the_tabs_or_page.38f079")), { title = "highground.coachrecords.manage_participation_in_one_place.5d3765", text = "highground.coachrecords.return_to_overview_to_pause_this_organization.69eaa8" }),
    ns.Localization.Define(Step("pause", ns.Locale:Get("highground.coachrecords.turn_participation_off_without_losing_records.898411"), ns.Locale:Get("highground.coachrecords.disabling_stops_this_organization_s_sharing_and.c5cfe6"),
      function() Open("overview", true) end, function() return U.window.disable end,
      function() return not P.Joined(P.Get()) end, ns.Locale:Get("highground.coachrecords.click_disable_on_this_account.ade7e5")), { title = "highground.coachrecords.turn_participation_off_without_losing_records.898411", text = "highground.coachrecords.disabling_stops_this_organization_s_sharing_and.c5cfe6" }),
    ns.Localization.Define(Step("resume", ns.Locale:Get("highground.coachrecords.turn_participation_back_on_when_you_choose.477fe0"), ns.Locale:Get("highground.coachrecords.the_same_control_turns_participation_back_on.58c9f3"),
      function() Open("overview", true); P.Disable() end, function() return U.window.disable end,
      function() return P.Joined(P.Get()) end, ns.Locale:Get("highground.coachrecords.click_enable_on_this_account.1f09c9")), { title = "highground.coachrecords.turn_participation_back_on_when_you_choose.477fe0", text = "highground.coachrecords.the_same_control_turns_participation_back_on.58c9f3" }),
    ns.Localization.Define(Step("settings_open", ns.Locale:Get("highground.coachrecords.choose_your_personal_preferences.c4b70b"), ns.Locale:Get("highground.coachrecords.the_preferences_tab_controls_chat_filtering_whisper.f9bdd7"),
      function() Open("blacklist", true); if not R.data.row then Decision() end end, function() return Tab("settings") end,
      function() return U.mode == "settings" end, ns.Locale:Get("highground.coachrecords.choose_preferences_in_the_top_tabs_or.0f1f00")), { title = "highground.coachrecords.choose_your_personal_preferences.c4b70b", text = "highground.coachrecords.the_preferences_tab_controls_chat_filtering_whisper.f9bdd7" }),
    ns.Localization.Define(Step("settings", ns.Locale:Get("highground.coachrecords.try_the_display_settings.2f58e9"), ns.Locale:Get("highground.coachrecords.these_are_the_real_settings_controls_with.05a843"),
      function() Open("settings", true); U.window.settings:SetVerticalScroll(0) end,
      function() return U.window.toggles.filter end, nil, ns.Locale:Get("highground.coachrecords.try_preferences_again_the_page_and_your.4c90f3")), { title = "highground.coachrecords.try_the_display_settings.2f58e9", text = "highground.coachrecords.these_are_the_real_settings_controls_with.05a843" }),
    ns.Localization.Define(Step("settings_return", ns.Locale:Get("highground.coachrecords.return_to_your_organization.170575"), ns.Locale:Get("highground.coachrecords.choose_organizations_to_return_to_the_page.cc33a5"),
      function() Open("blacklist", true); Open("settings", true) end, function() return Tab("organizations") end,
      function() return U.mode ~= "settings" end, ns.Locale:Get("highground.coachrecords.choose_organizations_finishing_closes_the_sample_nothing.45341c")), { title = "highground.coachrecords.return_to_your_organization.170575", text = "highground.coachrecords.choose_organizations_to_return_to_the_page.cc33a5" }),
  }
end
