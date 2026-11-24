local _, ns = ...
local O, Core = ns.Onboarding, ns.Core
local C = O.Coach

local Visible = C.Visible
local function Panel()
  return Visible(Core.frame) or Visible(ns.Flags.flagWin) or Visible(ns.Timers.resWin)
    or Visible(ns.QuickCalls and ns.QuickCalls.win)
end
local function Gear()
  for _, w in ipairs(ns.PanelControls.windows) do if Visible(w.gear) then return w.gear end end
  return Panel()
end

local function Placement()
  return {
    { id = "panel", title = ns.Locale:Get("highground.coachsamples.make_room_for_the_fight.155528"), target = Panel,
      text = ns.Locale:Get("highground.coachsamples.these_are_your_actual_panels_with_sample.a55717") },
    { id = "place", title = ns.Locale:Get("highground.coachsamples.try_moving_a_panel.baacba"), target = function() return Visible(Core.frame) and Core.head.bg or Panel() end,
      observe = Panel, event = "OnDragStop",
      text = ns.Locale:Get("highground.coachsamples.drag_the_highlighted_header_to_reposition_its.736570") },
    { id = "controls", title = ns.Locale:Get("highground.coachsamples.find_the_panel_controls.6ff118"), target = Gear, event = "OnEnter",
      text = ns.Locale:Get("highground.coachsamples.hover_the_cogwheel_to_read_its_shortcuts.71abde") },
    { id = "finish", title = ns.Locale:Get("highground.coachsamples.return_to_your_normal_layout.357764"), target = Panel,
      text = ns.Locale:Get("highground.coachsamples.done_removes_the_samples_and_restores_your.4be801") },
  }
end

local function Objectives()
  return {
    { id = "resurrection", sound = "resurrection", title = ns.Locale:Get("highground.coachsamples.your_next_resurrection.d9631f"), target = function() return ns.Timers.resWin.rows[1] end, event = "OnEnter",
      feature = "timers", settingLabel = ns.Locale:Get("highground.coachsamples.enable_battleground_timers_in_game.e230d9"),
      text = ns.Locale:Get("highground.coachsamples.you_marks_your_graveyard_stables_here_the.13aa3a") },
    { id = "estimate", title = ns.Locale:Get("highground.coachsamples.means_an_estimate.324005"), target = function() return ns.Timers.resWin.rows[3] end,
      text = ns.Locale:Get("highground.coachsamples.the_crest_shows_whose_graveyard_it_is.066ede") },
    { id = "capture", sound = "capture", title = ns.Locale:Get("highground.coachsamples.a_base_is_changing_hands.727ef3"), target = function() return ns.Timers.objWin.rows[1] end, event = "OnEnter",
      feature = "objectives", settingLabel = ns.Locale:Get("highground.coachsamples.enable_objective_timers_in_game.015f04"),
      text = ns.Locale:Get("highground.coachsamples.cap_is_the_countdown_after_a_base.cf7dc3") },
    { id = "score", sound = "objective", title = ns.Locale:Get("highground.coachsamples.plan_around_the_score.9c8157"), target = function() return ns.Timers.foreWin and ns.Timers.foreWin.block end, event = "OnEnter",
      feature = "forecast", settingLabel = ns.Locale:Get("highground.coachsamples.enable_win_forecast_in_game.2bd09b"),
      text = ns.Locale:Get("highground.coachsamples.forecast_shows_who_wins_and_when.5bea6d") },
    { id = "carrier", title = ns.Locale:Get("highground.coachsamples.find_the_enemy_flag_carrier.a2d424"), target = function() return ns.Flags.frows[2] end, event = "OnEnter",
      feature = "flags", settingLabel = ns.Locale:Get("highground.coachsamples.enable_flag_carrier_panel_in_game.91a521"),
      text = ns.Locale:Get("highground.coachsamples.the_crest_on_each_carrier_s_class.0bc6ea") },
  }
end

local function Arena()
  local function Duel() return ns.Arena.DuelMode() end
  return {
    { id = "opponents", title = ns.Locale:Get("highground.coachsamples.meet_your_opponents.da736c"), target = function() return ns.Arena.win end,
      feature = "arena", settingLabel = ns.Locale:Get("highground.coachsamples.enable_arena_duels_in_game.1681fb"),
      text = function() return Duel() and ns.Locale:Get("highground.coachsamples.this_sample_shows_a_duel_opponent_the.8b3cc3")
        or ns.Locale:Get("highground.coachsamples.these_sample_arena_opponents_show_the_panel.a0ce17") end },
    { id = "row", title = ns.Locale:Get("highground.coachsamples.target_now_keep_a_focus_for_later.e5ac6d"), target = function() return ns.Arena.rows[1] end, event = "OnEnter",
      text = ns.Locale:Get("highground.coachsamples.left_click_targets_this_opponent_right_click.e3ad6c") },
    { id = "health", title = ns.Locale:Get("highground.coachsamples.read_the_available_information.0bb233"), target = function() return ns.Arena.rows[1].bar end,
      text = ns.Locale:Get("highground.coachsamples.the_health_bar_and_row_details_show.3b37e7") },
    { id = "status", title = function() return Duel() and ns.Locale:Get("highground.coachsamples.follow_the_duel.c74373") or ns.Locale:Get("highground.coachsamples.watch_the_escape_trinket.3999d0") end,
      target = function() return Duel() and ns.Arena.rows[1] or ns.Arena.rows[1].trinket end,
      text = function() return Duel() and ns.Locale:Get("highground.coachsamples.the_status_follows_the_challenge_countdown_and.0f2d4c")
        or ns.Locale:Get("highground.coachsamples.the_trinket_icon_uses_client_reported_escape.c0b8c1") end },
    { id = "finish", title = ns.Locale:Get("highground.coachsamples.keep_your_attention_on_the_fight.45d72d"), target = function() return ns.Arena.win end,
      text = ns.Locale:Get("highground.coachsamples.the_panel_follows_the_activity_and_clears.182545") },
  }
end

function C.PanelSteps(context, chapter)
  if context == "world" then return C.NearbySteps() end
  if context == "arena" then return Arena() end
  if chapter == "objectives" then return Objectives() end
  return Placement()
end

-- History is the same browser used outside the tour, with isolated records.
function C.NearbySteps()
  local N, Nearby, B = C.Native, ns.Nearby, ns.Bounty
  local data = C.nearbySample or {}; C.nearbySample = data
  data.records = {
    ["Sneakypete-Sample"] = { class = "ROGUE", level = 60, zone = "Tarren Mill", guild = "Night Watch",
      times = 3, killedThem = 1, killedMe = 2, first = time() - 86400, last = time() - 1 },
    ["Holyhands-Sample"] = { class = "PRIEST", zone = "Hillsbrad Foothills", times = 1,
      killedThem = 0, killedMe = 0, first = time() - 3600, last = time() - 300 },
  }
  data.entries = function()
    local entries = {}
    for key, record in pairs(data.records) do
      entries[#entries + 1] = { key = key, title = Core.DisplayName(key, true), class = record.class,
        record = record, summary = record.zone, search = key .. " " .. record.zone .. " " .. (record.note or "") }
    end
    table.sort(entries, function(a, b) return a.record.last > b.record.last end)
    return entries
  end
  data.bounty = function(entry)
    if ns.Modules and not ns.Modules.Active("bounties") then
      return false, ns.Locale:Get("highground.coachsamples.enable_bounties_on_the_addons_page_then.b9de44")
    end
    B.Preview.StartGuided(nil, "create"); N.bountyOwned = true
    local w = B.Form.Open(entry.key, "personal", nil, true)
    N.Track(w); C.BountySample.Fit(w)
    return true, ns.Locale:Get("highground.coachsamples.sample_bounty_opened_your_real_records_stay.d38165")
  end
  -- World activity with sample zones (world/Activity.lua).
  local activity = C.activitySample or { entries = function() return ns.WorldActivity.Samples() end }
  C.activitySample = activity
  local function Activity()
    if data.win then ns.Kit.Windows.Close(data.win) end
    local w = ns.WorldActivity.Build(activity)
    w:Open(); N.Track(w); N.Fit(w)
    return w
  end
  local function History()
    if activity.win and activity.win:IsShown() then ns.Kit.Windows.Close(activity.win) end
    local w = ns.EnemyJournal.Build(data)
    w:Open(); N.Track(w); N.Fit(w)
    return w
  end
  local function Panel()
    if data.win then ns.Kit.Windows.Close(data.win) end
    if not ns.Setup.placement then ns.Setup.BeginPlacement(true) end
    Nearby.guide = { history = History }
    ns.Setup.PreviewContext("world")
    Nearby.preview = true; Nearby.Update()
  end
  local function Context() return data.win end
  -- Sample rows by name: their order follows the samples' ages.
  local function Row(name)
    for _, r in ipairs(Nearby.rows or {}) do
      if r.who == name and r:IsShown() then return r end
    end
    return Nearby.rows[1]
  end
  local function Form()
    local w = B.Form.previewWin
    if not (N.bountyOwned and w and w:IsVisible()) then data.bounty(data.entries()[1]); w = B.Form.previewWin end
    return w
  end
  local steps = {
    { id = "nearby", title = ns.Locale:Get("highground.coachsamples.a_fresh_sighting.df4c6a"), text = ns.Locale:Get("highground.coachsamples.sneakypete_was_just_observed_in_play_left.09919b"),
      enter = Panel, target = function() return Nearby.rows[1] end, context = function() return Nearby.win end,
      feature = "nearby", settingLabel = ns.Locale:Get("highground.coachsamples.enable_nearby_panel_in_game.a52135") },
    { id = "memory", title = ns.Locale:Get("highground.coachsamples.faded_means_last_seen_earlier.c06c8f"), text = ns.Locale:Get("highground.coachsamples.holyhands_is_an_older_sighting_being_on.8aaf10"),
      enter = Panel, target = function() return Row("Holyhands") end, context = function() return Nearby.win end },
    { id = "shared", title = ns.Locale:Get("guide.nearby.shared.title"), text = ns.Locale:Get("guide.nearby.shared.text"),
      enter = Panel, target = function() return Row("Ironhide") end, context = function() return Nearby.win end,
      feature = "nearbyShare", settingLabel = ns.Locale:Get("nearby.world.share_label") },
    { id = "marks", title = ns.Locale:Get("guide.nearby.marks.title"), text = ns.Locale:Get("guide.nearby.marks.text"),
      enter = Panel, target = function() return Nearby.win end, context = function() return Nearby.win end,
      feature = "nearbyMarks", settingLabel = ns.Locale:Get("marks.label") },
    { id = "sound", sound = "nearby", title = ns.Locale:Get("highground.coachsamples.choose_whether_nearby_makes_a_sound.01f030"), text = ns.Locale:Get("highground.coachsamples.this_button_toggles_sighting_and_stealth_sounds.fedc72"),
      enter = Panel, target = function() return Nearby.win.sound end, context = function() return Nearby.win end,
      hint = ns.Locale:Get("highground.coachsamples.this_is_your_real_sound_preference.c14faf") },
    { id = "history", title = ns.Locale:Get("highground.coachsamples.open_the_encounter_history.fa7844"), text = ns.Locale:Get("highground.coachsamples.history_keeps_enemies_after_they_leave_the.8369b8"),
      enter = Panel, target = function() return Nearby.win.history end, context = function() return Nearby.win end,
      advance = function() return data.win and data.win:IsVisible() end, requireAction = true, hint = ns.Locale:Get("highground.coachsamples.click_history.1abc37") },
    { id = "record", title = ns.Locale:Get("highground.coachsamples.read_the_selected_enemy_s_history.1bef57"), text = ns.Locale:Get("highground.coachsamples.the_record_shows_encounters_kills_deaths_and.586ee6"),
      enter = History, target = function() return data.win.profile and data.win.profile.stats end, context = Context },
    { id = "note", title = ns.Locale:Get("highground.coachsamples.keep_a_private_reminder.8900be"), text = ns.Locale:Get("highground.coachsamples.edit_note_adds_your_own_reminder_mute.5f57ca"),
      enter = History, target = function() return data.win.actions[1] end, context = Context,
      hint = ns.Locale:Get("highground.coachsamples.these_are_sample_records_trying_the_actions.2935af") },
    { id = "track", title = ns.Locale:Get("guide.nearby.track.title"), text = ns.Locale:Get("guide.nearby.track.text"),
      enter = History, target = function() return data.win.actions[5] end, context = Context,
      feature = "nearbyTrack", settingLabel = ns.Locale:Get("tracking.label") },
    { id = "activity", title = ns.Locale:Get("guide.nearby.activity.title"), text = ns.Locale:Get("guide.nearby.activity.text"),
      enter = Activity, target = function() return activity.win and activity.win.rows[1] end, context = function() return activity.win end },
    { id = "bounty", title = ns.Locale:Get("highground.coachsamples.add_a_bounty_from_this_enemy_record.f804f8"), text = ns.Locale:Get("highground.coachsamples.select_the_enemy_then_click_add_bounty.2f3947"),
      enter = History, target = function() return data.win.actions[3] end, context = Context,
      requireAction = true, advance = function() return N.bountyOwned and B.Form.previewWin:IsVisible() end, hint = ns.Locale:Get("highground.coachsamples.click_add_bounty.793100") },
    { id = "bounty_name", title = ns.Locale:Get("highground.coachsamples.the_selected_name_is_already_filled_in.f1aeab"), text = ns.Locale:Get("highground.coachsamples.check_the_name_choose_who_should_see.9a44df"),
      enter = function() Form().fields:Scroll(0) end, target = function() return B.Form.previewWin.name end,
      context = function() return B.Form.previewWin end, hint = ns.Locale:Get("highground.coachsamples.the_bounties_guide_covers_posting_tracking_and.08e143") },
  }
  if ns.Modules and not ns.Modules.Active("bounties") then
    for i = #steps, 1, -1 do
      if steps[i].id:match("^bounty") then table.remove(steps, i) end
    end
    steps[#steps].hint = ns.Locale:Get("highground.coachsamples.bounties_is_disabled_enable_it_on_addons.764c0f")
  end
  return steps
end
