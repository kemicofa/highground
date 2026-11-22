local _, ns = ...
local C, O, Kit, Core = ns.Onboarding.Coach, ns.Onboarding, ns.Kit, ns.Core
local N = { windows = {} }
C.Native = N

function N.Track(w)
  if not w then return end
  N.windows[w] = true
  N.current = w
  return w
end
function N.Fit(w)
  if not w then return end
  if not w.coachHome then
    w.coachHome = { width = w:GetWidth(), height = w:GetHeight(), points = {} }
    for i = 1, w:GetNumPoints() do w.coachHome.points[i] = { w:GetPoint(i) } end
  end
  local width = math.min(w.coachHome.width, math.max(600, UIParent:GetWidth() - 500))
  w:SetSize(width, math.min(w.coachHome.height, UIParent:GetHeight() - 48))
  w:ClearAllPoints(); w:SetPoint("LEFT", UIParent, "LEFT", 24, 0)
end
-- Scroll so the target sits margin below the top of its scrolled content.
-- Kit scroll areas clamp themselves; native scroll frames are clamped here.
function N.Reveal(scroll, content, target, margin)
  local _, contentY = content:GetCenter()
  local _, targetY = target:GetCenter()
  if not (contentY and targetY) then return end
  local offset = math.max(0, contentY + content:GetHeight() / 2 - targetY - target:GetHeight() / 2 - margin)
  if scroll.Scroll then return scroll:Scroll(offset) end
  scroll:SetVerticalScroll(math.min(math.max(0, content:GetHeight() - scroll:GetHeight()), offset))
end
function N.Stop()
  if ns.Options.panel.EndReviewExample then ns.Options.panel.EndReviewExample() end
  ns.Nearby.guide = nil
  if N.bountyOwned then ns.Bounty.Preview.Stop(); N.bountyOwned = nil end
  for _, w in pairs({ C.nearbySample and C.nearbySample.noteWindow, C.matchSample and C.matchSample.timeline }) do
    Kit.Windows.Close(w)
  end
  N.active, N.current, N.changing = nil, nil, true
  for w in pairs(N.windows) do
    Kit.Windows.Close(w)
    if w.coachHome then
      local home = w.coachHome; w.coachHome = nil
      w:ClearAllPoints(); w:SetSize(home.width, home.height)
      for _, point in ipairs(home.points) do w:SetPoint(unpack(point)) end
    end
  end
  wipe(N.windows)
  if N.openedMacroFrame and MacroFrame then MacroFrame:Hide() end
  N.openedMacroFrame, N.changing = nil, nil
end
function N.Page(key)
  N.changing = true
  if ns.Hub.current ~= key or not (ns.Hub.win and ns.Hub.win:IsVisible()) then ns.Hub.Open(key) end
  N.Track(ns.Hub.win)
  N.changing = nil
end
function N.Nav(key)
  for _, button in ipairs(ns.Hub.win.nav) do
    if button.section.key == key then
      if button.groupButton then
        ns.Hub.SetGroupExpanded(button.groupButton, true)
        if ns.Motion.IsPlaying(button.groupButton) then ns.Motion.Finish(button.groupButton) end
      end
      local scroll = ns.Hub.win.navScroll
      local _, y = button:GetCenter()
      local _, viewY = scroll.view:GetCenter()
      if y and viewY then
        local top, bottom = y + button:GetHeight() / 2, y - button:GetHeight() / 2
        local viewTop, viewBottom = viewY + scroll.view:GetHeight() / 2, viewY - scroll.view:GetHeight() / 2
        local offset = scroll.view:GetVerticalScroll()
        if top > viewTop then scroll:Scroll(offset + viewTop - top)
        elseif bottom < viewBottom then scroll:Scroll(offset + viewBottom - bottom) end
      end
      return button
    end
  end
end
local function Step(id, title, text, page, target, hint)
  return { id = id, title = title, text = text, hint = hint or ns.Locale:Get("highground.coachpreferences.changes_here_save_immediately.a4d86e"),
    enter = function()
      N.Page(page)
      local settings = ns.Options.byKey[page]
      if settings then settings.scroll:SetVerticalScroll(0) end
    end, target = target, context = function() return ns.Hub.win end }
end
local function Box(key)
  for _, box in ipairs(ns.Options.featureBoxes) do if box.key == key and box:IsVisible() then return box end end
end
local function Features()
  local bg = ns.Modules.Active("battlegrounds")
  local settingsKey, appearanceKey = bg and "battlegrounds-settings" or "general", bg and "battlegrounds-appearance" or "appearance"
  local function Appearance() return ns.Options.byKey[appearanceKey] end
  local appearance = ns.Localization.Define(Step("appearance", bg and ns.Locale:Get("highground.coachpreferences.open_this_addon_s_appearance.f257e1") or ns.Locale:Get("highground.coachpreferences.open_shared_appearance.31a605"),
    bg and ns.Locale:Get("highground.coachpreferences.click_appearance_under_battlegrounds_to_adjust_enemy.54bf82")
      or ns.Locale:Get("highground.coachpreferences.shared_appearance_controls_the_theme_fonts_and.47799d"), settingsKey,
    function() return N.Nav(appearanceKey) end, bg and ns.Locale:Get("highground.coachpreferences.click_appearance_under_battlegrounds.189abb") or ns.Locale:Get("highground.coachpreferences.click_shared_appearance.962763")), { title = bg and "highground.coachpreferences.open_this_addon_s_appearance.f257e1" or "highground.coachpreferences.open_shared_appearance.31a605", text = bg and "highground.coachpreferences.click_appearance_under_battlegrounds_to_adjust_enemy.54bf82"
      or "highground.coachpreferences.shared_appearance_controls_the_theme_fonts_and.47799d", hint = bg and "highground.coachpreferences.click_appearance_under_battlegrounds.189abb" or "highground.coachpreferences.click_shared_appearance.962763" })
  appearance.requireAction = true; appearance.advance = function() return ns.Hub.current == appearanceKey end
  local theme = ns.Localization.Define(Step("theme", ns.Locale:Get("highground.coachpreferences.choose_a_shared_theme.8b4434"), ns.Locale:Get("highground.coachpreferences.theme_and_accessibility_apply_to_every_addon.aba586"), "appearance",
    function() return ns.Options.appearance.themeSelect end), { title = "highground.coachpreferences.choose_a_shared_theme.8b4434", text = "highground.coachpreferences.theme_and_accessibility_apply_to_every_addon.aba586" })
  theme.enter = function() N.Page("appearance"); ns.Options.appearance.scroll:SetVerticalScroll(0) end
  local details = ns.Localization.Define(Step("details", bg and ns.Locale:Get("highground.coachpreferences.fine_tune_this_addon_s_panels.60828e") or ns.Locale:Get("highground.coachpreferences.fine_tune_shared_styling.b1faf5"),
    bg and ns.Locale:Get("highground.coachpreferences.these_dimensions_and_row_details_belong_to.538aec")
      or ns.Locale:Get("highground.coachpreferences.bar_textures_colours_and_borders_are_shared.cbec37"), appearanceKey, function() return Appearance().detailHeading end), { title = bg and "highground.coachpreferences.fine_tune_this_addon_s_panels.60828e" or "highground.coachpreferences.fine_tune_shared_styling.b1faf5", text = bg and "highground.coachpreferences.these_dimensions_and_row_details_belong_to.538aec"
      or "highground.coachpreferences.bar_textures_colours_and_borders_are_shared.cbec37" })
  details.enter = function()
    N.Page(appearanceKey)
    local page = Appearance()
    N.Reveal(page.scroll, page.child, page.detailHeading, 24)
  end
  local preview = Step("preview", ns.Locale:Get("appearance.preview.guide_title"),
    ns.Locale:Get("appearance.preview.guide_text"),
    appearanceKey, function() return Appearance().preview end, ns.Locale:Get("appearance.preview.guide_hint"))
  local language = ns.Localization.Define(Step("language", ns.Locale:Get("locale.guide.title"), ns.Locale:Get("locale.guide.text"), "general",
    function() return ns.Options.general.language.select end), { title = "locale.guide.title", text = "locale.guide.text" })
  language.enter = function()
    N.Page("general")
    local page = ns.Options.general
    N.Reveal(page.scroll, page.content, page.language, 8)
  end
  return {
    ns.Localization.Define(Step("group", ns.Locale:Get("highground.coachpreferences.settings_live_with_their_addon.f2c359"), ns.Locale:Get("highground.coachpreferences.use_an_addon_s_settings_appearance_commands.b1a987"), settingsKey,
      function() return ns.Options.featurePages[bg and "battlegrounds" or "shared"].featureGroups[1].heading end), { title = "highground.coachpreferences.settings_live_with_their_addon.f2c359", text = "highground.coachpreferences.use_an_addon_s_settings_appearance_commands.b1a987" }),
    ns.Localization.Define(Step("switch", bg and ns.Locale:Get("highground.coachpreferences.keep_the_panels_you_want.abbf0b") or ns.Locale:Get("highground.coachpreferences.choose_shared_preferences.f69dd0"),
      bg and ns.Locale:Get("highground.coachpreferences.checked_means_enabled_all_available_feature_switches.16b69f") or ns.Locale:Get("highground.coachpreferences.checked_means_enabled_this_switch_shows_the.de650b"), settingsKey,
      function() return Box(bg and "killorder" or "minimap") end), { title = bg and "highground.coachpreferences.keep_the_panels_you_want.abbf0b" or "highground.coachpreferences.choose_shared_preferences.f69dd0", text = bg and "highground.coachpreferences.checked_means_enabled_all_available_feature_switches.16b69f" or "highground.coachpreferences.checked_means_enabled_this_switch_shows_the.de650b" }),
    appearance, preview, theme, details, language,
  }
end
local function Alerts()
  local bg = ns.Modules.Active("battlegrounds")
  local function Open()
    N.changing = true
    local w = ns.Alerts.Open(); ns.Hub.Release(w); Kit.Windows.Show(w); N.Track(w); N.Fit(w)
    N.changing = nil
  end
  local function Context() return ns.Alerts.win end
  return {
    { id = "level", title = ns.Locale:Get("highground.coachpreferences.choose_the_warnings_you_want.2794f4"), text = ns.Locale:Get("highground.coachpreferences.essentials_is_a_starting_point_text_only.1f45b3"),
      enter = Open, target = function() return ns.Alerts.win.mode end, context = Context, hint = ns.Locale:Get("highground.coachpreferences.this_changes_your_real_alert_preference.ecd3f5") },
    { id = "customize", title = ns.Locale:Get("highground.coachpreferences.go_straight_to_an_addon_s_alerts.46dd58"),
      text = ns.Locale:Get("highground.coachpreferences.the_battlegrounds_nearby_and_bounties_links_open.676c0b"),
      enter = Open, target = function() return ns.Alerts.win.addonLinks.battlegrounds end, context = Context,
      action = bg and function() return ns.Alerts.win.addonLinks.battlegrounds end or nil,
      advance = bg and function() return ns.Hub.win and ns.Hub.win:IsVisible() and ns.Hub.current == "battlegrounds-settings" end or nil,
      requireAction = bg, hint = bg and ns.Locale:Get("highground.coachpreferences.click_battlegrounds_or_next_to_open_its.68ede3") or ns.Locale:Get("highground.coachpreferences.enemy_stealth_stays_available_here_even_when.63bf57") },
    { id = "channels", title = ns.Locale:Get("highground.coachpreferences.choose_text_sound_or_both.306e9e"), text = bg
        and ns.Locale:Get("highground.coachpreferences.these_switches_belong_to_battlegrounds_settings_nearby.0373c0")
        or ns.Locale:Get("highground.coachpreferences.enemy_stealth_applies_across_addons_other_alert.fa92cd"),
      enter = function()
        if bg then
          N.changing = true
          ns.Hub.Open({ name = "battlegrounds-settings", params = { section = "alerts" } })
          N.Track(ns.Hub.win)
          N.changing = nil
        else
          Open()
        end
      end,
      target = function()
        if bg then return ns.Options.featurePages.battlegrounds.alertRows[1].sound end
        for _, row in ipairs(ns.Alerts.win.rows) do if row.key == "stealth" then return row.sound end end
      end,
      context = function() return bg and ns.Hub.win or ns.Alerts.win end, hint = ns.Locale:Get("highground.coachpreferences.changes_here_save_immediately.a4d86e") },
    { id = "sample", title = ns.Locale:Get("alerts.sample.guide_title"),
      text = ns.Locale:Get("alerts.sample.guide_text"),
      enter = Open, target = function() return ns.Alerts.win.rows[1].play end,
      context = Context, hint = ns.Locale:Get("alerts.sample.guide_hint") },
  }
end
local function Profiles()
  local function P() return ns.Options.panel end
  local function Open() N.Page("profiles"); P().EndReviewExample() end
  local function Create() Open(); if P().mode ~= "create" then P().NewProfile() end end
  local function ProfileStep(id, title, text, target, enter, hint)
    local step = ns.Localization.Define(Step(id, ns.Locale:Get(title), ns.Locale:Get(text), "profiles", target, hint and ns.Locale:Get(hint)),
      { title = title, text = text, hint = hint })
    step.enter = enter or Open
    return step
  end
  local function L(key) return "profiles.guide." .. key end
  return {
    ProfileStep("default", L("default_title"), L("default_text"), function() return P().defaultInfo end,
      function() Open(); P().SelectProfile("Default") end),
    ProfileStep("name", L("name_title"), L("name_text"), function() return P().profileName end, Create),
    ProfileStep("source", L("source_title"), L("source_text"), function() return P().source end, Create),
    ProfileStep("contents", L("contents_title"), L("contents_text"), function() return P().profileScroll end, Create),
    ProfileStep("save", L("save_title"), L("save_text"), function() return P().profileButtons.Save end, Create, L("save_hint")),
    ProfileStep("changes", L("diff_title"), L("diff"), function() return P().profileScroll end,
      function() Open(); P().BeginReviewExample() end, L("diff_hint")),
    ProfileStep("load", L("load_title"), L("load_text"), function() return P().listScroll end,
      function() Open(); P().SelectProfile(ns.Core.db.activeProfile or "Default") end),
    ProfileStep("switching", L("switching_title"), L("switching_text"), function() return P().assignmentScroll end, Open, L("switching_hint")),
    ProfileStep("sharing", L("sharing_title"), L("sharing_text"), function() return P().footer end),
  }
end
local function Addons()
  local function Page() return O.Build() end
  local function Card() return Page().cards.battlegrounds end
  local function Reveal(target)
    N.Page("addons")
    local page = Page()
    N.Reveal(page.scroll, page.body, target, 16)
  end
  local steps = {
    ns.Localization.Define(Step("installation", ns.Locale:Get("highground.coachpreferences.highground_is_the_only_download_you_need.f138df"), ns.Locale:Get("highground.coachpreferences.addons_brings_the_addon_switches_settings_shortcuts.df8aff"), "addons",
      function() return Page().notice and Page().notice.title or Page().hint end, ns.Locale:Get("highground.coachpreferences.a_disabled_module_does_not_activate_a.e4cf84")), { title = "highground.coachpreferences.highground_is_the_only_download_you_need.f138df", text = "highground.coachpreferences.addons_brings_the_addon_switches_settings_shortcuts.df8aff", hint = "highground.coachpreferences.a_disabled_module_does_not_activate_a.e4cf84" }),
    ns.Localization.Define(Step("switches", ns.Locale:Get("highground.coachpreferences.choose_which_addons_run.892aae"), ns.Locale:Get("highground.coachpreferences.enable_addon_is_the_same_per_character.e05474"), "addons",
      function() return Card().addon end, ns.Locale:Get("highground.coachpreferences.these_are_real_switches_you_can_continue.862243")), { title = "highground.coachpreferences.choose_which_addons_run.892aae", text = "highground.coachpreferences.enable_addon_is_the_same_per_character.e05474", hint = "highground.coachpreferences.these_are_real_switches_you_can_continue.862243" }),
    ns.Localization.Define(Step("visit", ns.Locale:Get("highground.coachpreferences.visit_settings_or_replay_a_guide.e879b6"), ns.Locale:Get("highground.coachpreferences.visit_opens_this_addon_s_overview_and.64e863"), "addons",
      function() return Card().visit end, ns.Locale:Get("highground.coachpreferences.visit_leaves_this_walkthrough_next_continues_without.da36c5")), { title = "highground.coachpreferences.visit_settings_or_replay_a_guide.e879b6", text = "highground.coachpreferences.visit_opens_this_addon_s_overview_and.64e863", hint = "highground.coachpreferences.visit_leaves_this_walkthrough_next_continues_without.da36c5" }),
    ns.Localization.Define(Step("sections", ns.Locale:Get("highground.coachpreferences.recognize_subaddons_in_the_sidebar.8ccd1c"), ns.Locale:Get("highground.coachpreferences.each_subaddon_has_a_small_crest_and.3b587c"), "addons",
      function() local button = N.Nav("module-battlegrounds"); return button and button.groupButton end,
      ns.Locale:Get("highground.coachpreferences.shared_preferences_saved_setups_and_help_apply.3e1969")), { title = "highground.coachpreferences.recognize_subaddons_in_the_sidebar.8ccd1c", text = "highground.coachpreferences.each_subaddon_has_a_small_crest_and.3b587c", hint = "highground.coachpreferences.shared_preferences_saved_setups_and_help_apply.3e1969" }),
    ns.Localization.Define(Step("pending", ns.Locale:Get("highground.coachpreferences.keep_your_settings_when_disabling_an_addon.518274"), ns.Locale:Get("highground.coachpreferences.changing_a_switch_takes_effect_after_reload.145c67"), "addons",
      function() return Page().status end, ns.Locale:Get("highground.coachpreferences.profiles_do_not_enable_or_disable_addons.a7920d")), { title = "highground.coachpreferences.keep_your_settings_when_disabling_an_addon.518274", text = "highground.coachpreferences.changing_a_switch_takes_effect_after_reload.145c67", hint = "highground.coachpreferences.profiles_do_not_enable_or_disable_addons.a7920d" }),
    ns.Localization.Define(Step("reload", ns.Locale:Get("highground.coachpreferences.reload_when_you_are_ready.225a57"), ns.Locale:Get("highground.coachpreferences.after_changing_a_switch_reload_to_apply.8a851b"), "addons",
      function() return Page().reload:IsShown() and Page().reload or Page().status end, ns.Locale:Get("highground.coachpreferences.next_continues_without_reloading.acc474")), { title = "highground.coachpreferences.reload_when_you_are_ready.225a57", text = "highground.coachpreferences.after_changing_a_switch_reload_to_apply.8a851b", hint = "highground.coachpreferences.next_continues_without_reloading.acc474" }),
    ns.Localization.Define(Step("commands", ns.Locale:Get("highground.coachpreferences.find_commands_and_their_controls.a1ca25"), ns.Locale:Get("highground.coachpreferences.each_addon_has_a_commands_page_help.cc07e2"), "tools",
      function() return ns.Options.tools.commandRows[1].button end, ns.Locale:Get("highground.coachpreferences.browsing_is_safe_action_buttons_can_change.33ba22")), { title = "highground.coachpreferences.find_commands_and_their_controls.a1ca25", text = "highground.coachpreferences.each_addon_has_a_commands_page_help.cc07e2", hint = "highground.coachpreferences.browsing_is_safe_action_buttons_can_change.33ba22" }),
  }
  steps[1].enter = function() N.Page("addons"); Page().scroll:Scroll(0) end
  steps[2].enter = function() Reveal(Card().addon) end
  steps[3].enter = function() Reveal(Card().visit) end
  return steps
end

local function Users()
  local function Sample(mode, target)
    return function()
      ns.Hub.UsersSample(mode); N.Page("users")
      local w = ns.Hub.users
      local _, _, _, _, y = w[target]:GetPoint(1)
      w.scroll:Scroll(-(y or 0) - 24)
    end
  end
  local function Context() return ns.Hub.win end
  return {
    { id = "members", title = ns.Locale:Get("highground.coachpreferences.discover_channel_members.5df463"),
      text = ns.Locale:Get("highground.coachpreferences.your_own_character_counts_immediately_a_complete.2a1246"),
      enter = Sample("members", "refresh"), target = function() return ns.Hub.users.refresh end, context = Context,
      event = "OnClick", hint = ns.Locale:Get("highground.coachpreferences.this_sample_does_not_request_a_live.d4e060") },
    { id = "versions", title = ns.Locale:Get("highground.coachpreferences.membership_and_version_reports_are_different.84c36a"),
      text = ns.Locale:Get("highground.coachpreferences.a_channel_member_may_not_have_a.590af5"),
      enter = Sample("members", "versions"), target = function() return ns.Hub.users.versions end, context = Context },
    { id = "fallback", title = ns.Locale:Get("highground.coachpreferences.keep_useful_counts_when_a_list_is.120802"),
      text = ns.Locale:Get("highground.coachpreferences.an_incomplete_or_unavailable_member_list_keeps.d5bf62"),
      enter = Sample("fallback", "roster"), target = function() return ns.Hub.users.roster end, context = Context,
      hint = ns.Locale:Get("highground.coachpreferences.close_the_guide_to_return_to_live.65ab77") },
  }
end

function N.Start(key)
  N.active = key
  if key == "macros" then
    N.openedMacroFrame = not (MacroFrame and MacroFrame:IsVisible())
    return C.MacroSteps()
  elseif key == "addons" then return Addons()
  elseif key == "users" then return Users()
  elseif key == "features" then return Features()
  elseif key == "alerts" then return Alerts()
  elseif key == "profile" then return Profiles()
  elseif key == "records" then return C.RecordSteps()
  elseif key == "reputation" then return C.ReputationSteps()
  elseif key == "enemies" then return C.EnemySteps()
  elseif key == "nearby" then return C.NearbySteps() end
end
