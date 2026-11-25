local _, ns = ...
local C, Win = ns.Onboarding.Coach, ns.Macros.Window

local function MacroWindow()
  local w = Win.Build()
  ns.Hub.Release(w); ns.Kit.Windows.Show(w); C.Native.Track(w)
  C.Native.Fit(w)
  return w
end
local function Catalog()
  local w = MacroWindow()
  if Win.tab ~= "class" then Win.SetTab("class") end
  Win.Refresh()
  return w
end
local function Card()
  local w = Win.win
  for _, row in ipairs(w.rows) do if row:IsVisible() and row.entry then return row end end
end
local function MacroStep(id, title, text, enter, target, hint)
  return { id = id, title = title, text = text, enter = enter, target = target, hint = hint,
    context = function() return Win.win end }
end
function C.MacroSteps()
  local library = ns.Localization.Define(MacroStep("library", ns.Locale:Get("highground.coachtools.find_your_saved_macros.a022e5"), ns.Locale:Get("highground.coachtools.click_my_macros_to_see_the_macros.e3ce90"),
    Catalog, function() return Win.TabTarget("mine") end), { title = "highground.coachtools.find_your_saved_macros.a022e5", text = "highground.coachtools.click_my_macros_to_see_the_macros.e3ce90" })
  library.requireAction = true; library.advance = function() return Win.tab == "mine" end
  library.hint = C.TabHint(function() return Win.win.tabGroup end, "mine")
  local open = ns.Localization.Define(MacroStep("wow", ns.Locale:Get("highground.coachtools.open_wow_s_macro_window.42985e"), ns.Locale:Get("highground.coachtools.this_button_opens_the_game_s_own.386d0c"),
    function() MacroWindow(); if Win.tab ~= "mine" then Win.SetTab("mine") end end,
    function() return Win.win.open end, ns.Locale:Get("highground.coachtools.click_open_wow_macros_or_continue_to.2d0cfe")), { title = "highground.coachtools.open_wow_s_macro_window.42985e", text = "highground.coachtools.this_button_opens_the_game_s_own.386d0c", hint = "highground.coachtools.click_open_wow_macros_or_continue_to.2d0cfe" })
  open.event = "OnClick"
  return {
    ns.Localization.Define(MacroStep("class", ns.Locale:Get("highground.coachtools.start_with_for_my_class.13d241"), ns.Locale:Get("guide.macros.window"),
      Catalog, function() return Win.TabTarget("class") end), { title = "highground.coachtools.start_with_for_my_class.13d241", text = "guide.macros.window" }),
    ns.Localization.Define(MacroStep("preset", ns.Locale:Get("highground.coachtools.choose_an_ability_you_know.23be1f"), ns.Locale:Get("highground.coachtools.read_the_preset_s_purpose_ready_to.84c1f3"),
      Catalog, function() local r = Card(); return r and r.name or Win.win.empty end), { title = "highground.coachtools.choose_an_ability_you_know.23be1f", text = "highground.coachtools.read_the_preset_s_purpose_ready_to.84c1f3" }),
    ns.Localization.Define(MacroStep("target", ns.Locale:Get("highground.coachtools.choose_who_receives_the_ability.4cec27"), ns.Locale:Get("highground.coachtools.open_the_target_menu_focus_keeps_a.cc40a3"),
      Catalog, function() local r = Card(); return r and r.target:IsVisible() and r.target or r and r.desc or Win.win.empty end,
      function() local r = Card(); return r and not r.target:IsVisible() and ns.Locale:Get("highground.coachtools.this_preset_has_a_fixed_target_there.01a659") or ns.Locale:Get("highground.coachtools.a_focus_macro_needs_a_focus_set.332ba6") end), { title = "highground.coachtools.choose_who_receives_the_ability.4cec27", text = "highground.coachtools.open_the_target_menu_focus_keeps_a.cc40a3" }),
    ns.Localization.Define(MacroStep("save", ns.Locale:Get("highground.coachtools.use_macro_saves_it_to_wow.24ba41"), ns.Locale:Get("highground.coachtools.use_macro_saves_for_this_character_if.e141cd"),
      Catalog, function() local r = Card(); return r and r.use or Win.win.empty end,
      ns.Locale:Get("highground.coachtools.optional_this_is_a_real_save_button.43caf6")), { title = "highground.coachtools.use_macro_saves_it_to_wow.24ba41", text = "highground.coachtools.use_macro_saves_for_this_character_if.e141cd", hint = "highground.coachtools.optional_this_is_a_real_save_button.43caf6" }),
    ns.Localization.Define(MacroStep("casting", ns.Locale:Get("highground.coachtools.create_a_spell_macro_with_casting_options.03eb6c"),
      ns.Locale:Get("highground.coachtools.open_create_choose_cast_spell_and_enter.522dbb"),
      MacroWindow, function() return Win.TabTarget("build") end,
      ns.Locale:Get("highground.coachtools.this_cannot_guarantee_instant_only_casting_or.94311d")), { title = "highground.coachtools.create_a_spell_macro_with_casting_options.03eb6c", text = "highground.coachtools.open_create_choose_cast_spell_and_enter.522dbb", hint = "highground.coachtools.this_cannot_guarantee_instant_only_casting_or.94311d" }),
    library, open,
    ns.Localization.Define(MacroStep("bar", ns.Locale:Get("highground.coachtools.drag_its_icon_onto_your_action_bar.6782f5"), ns.Locale:Get("highground.coachtools.in_wow_s_macro_window_select_your.5d2c5e"),
      MacroWindow, function() return MacroFrame and MacroFrame:IsVisible() and MacroFrame or Win.win.open end,
      ns.Locale:Get("highground.coachtools.your_key_press_runs_the_macro_you.71aa62")), { title = "highground.coachtools.drag_its_icon_onto_your_action_bar.6782f5", text = "highground.coachtools.in_wow_s_macro_window_select_your.5d2c5e", hint = "highground.coachtools.your_key_press_runs_the_macro_you.71aa62" }),
  }
end

-- Quick calls use the real battleground panel. Only sends are simulated.
local Quick = ns.QuickCalls
function C.CallSteps()
  local function Context() return Quick.win end
  local function Enter(mode) return function() Quick.StartGuide(mode) end end
  local function Feedback(fallback)
    return function() return Quick.guide and Quick.guide.message and (ns.Locale:Format("highground.coachtools.sample_quick_guide_message.4afcf2", { Quick_guide_message = Quick.guide.message })) or fallback end
  end
  local function Clicked() return Quick.guide and Quick.guide.message ~= nil end
  return {
    { id = "location", title = ns.Locale:Get("highground.coachtools.this_is_the_battleground_quick_call_panel.bab402"),
      text = ns.Locale:Get("highground.coachtools.farm_is_your_current_location_in_this.1694a9"),
      enter = Enter("local"), context = Context, target = function() return Quick.win.area end,
      feature = "quickCalls", settingLabel = ns.Locale:Get("highground.coachtools.enable_quick_call_panel_in_game.ca26b6") },
    { id = "help", title = ns.Locale:Get("highground.coachtools.call_for_two_enemies.8b1761"),
      text = ns.Locale:Get("highground.coachtools.click_2_in_a_battleground_this_immediately.b7d37d"),
      enter = Enter("local"), context = Context, target = function() return Quick.win.buttons[3] end,
      hint = Feedback(ns.Locale:Get("highground.coachtools.try_2_this_sample_sends_nothing_to.a10a76")), complete = Clicked, event = "OnClick" },
    { id = "clear", title = ns.Locale:Get("highground.coachtools.tell_your_team_when_it_is_clear.d0105b"),
      text = ns.Locale:Get("highground.coachtools.click_all_clear_when_the_threat_has.e509b9"),
      enter = Enter("local"), context = Context, target = function() return Quick.win.buttons[5] end,
      hint = Feedback(ns.Locale:Get("highground.coachtools.try_all_clear.4d240d")), complete = Clicked, event = "OnClick" },
    { id = "destination", title = ns.Locale:Get("highground.coachtools.choose_where_enemies_are_going.8ba81f"),
      text = ns.Locale:Get("highground.coachtools.this_optional_row_calls_a_destination_instead.860171"),
      enter = Enter("destinations"), context = Context, target = function() return Quick.win.destination end,
      feature = "quickCallsDestinations", settingLabel = ns.Locale:Get("highground.coachtools.enable_destination_calls_in_game.a15323"),
      advance = function() return Quick.win.destination:GetValue() ~= "" end, requireAction = true,
      hint = ns.Locale:Get("guide.hint.destination") },
    { id = "count", title = ns.Locale:Get("highground.coachtools.send_the_destination_and_count.ff0796"),
      text = ns.Locale:Get("highground.coachtools.click_1_2_or_3_below_the.2f268e"),
      enter = function()
        if not Quick.guide or Quick.guide.mode ~= "destinations" then Quick.StartGuide("destinations") end
        if Quick.win.destination:GetValue() == "" then Quick.win.destination:SetValue("Blacksmith") end
      end,
      context = Context, target = function() return Quick.win.destinationButtons[2] end,
      hint = Feedback(ns.Locale:Get("highground.coachtools.try_2_under_the_destination.5583e6")), complete = Clicked, event = "OnClick" },
    { id = "carrier", title = ns.Locale:Get("highground.coachtools.call_the_flag_carrier_s_route.ef389d"),
      text = ns.Locale:Get("highground.coachtools.on_flag_maps_these_buttons_report_the.7ad88d"),
      enter = Enter("routes"), context = Context, target = function() return Quick.win.routeButtons[1] end,
      feature = "quickCallsRoutes", settingLabel = ns.Locale:Get("highground.coachtools.enable_flag_carrier_calls_in_game.1728da"),
      hint = Feedback(ns.Locale:Get("highground.coachtools.try_a_route_sample_messages_stay_here.d6e9d6")), complete = Clicked, event = "OnClick" },
  }
end
