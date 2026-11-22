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
  return { id = id, title = title, text = text, hint = hint or "Changes here save immediately.",
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
  local appearance = Step("appearance", bg and "Open this addon's Appearance" or "Open Shared appearance",
    bg and "Click Appearance under Battlegrounds to adjust enemy rows and target markers."
      or "Shared appearance controls the theme, fonts and accessibility for every enabled addon.", settingsKey,
    function() return N.Nav(appearanceKey) end, bg and "Click Appearance under Battlegrounds." or "Click Shared appearance.")
  appearance.requireAction = true; appearance.advance = function() return ns.Hub.current == appearanceKey end
  local theme = Step("theme", "Choose a shared theme", "Theme and accessibility apply to every addon. Individual panel controls stay in the addon's own section.", "appearance",
    function() return ns.Options.appearance.themeSelect end)
  theme.enter = function() N.Page("appearance"); ns.Options.appearance.scroll:SetVerticalScroll(0) end
  local details = Step("details", bg and "Fine-tune this addon's panels" or "Fine-tune shared styling",
    bg and "These dimensions and row details belong to Battlegrounds. Arena and Nearby have independent appearance pages."
      or "Bar textures, colours and borders are shared. Adjust each panel's size in its own addon's Appearance page.", appearanceKey, function() return Appearance().detailHeading end)
  details.enter = function()
    N.Page(appearanceKey)
    local page = Appearance()
    local _, contentY = page.child:GetCenter()
    local _, headingY = page.detailHeading:GetCenter()
    local offset = contentY + page.child:GetHeight() / 2 - headingY - page.detailHeading:GetHeight() / 2 - 24
    local maximum = math.max(0, page.child:GetHeight() - page.scroll:GetHeight())
    page.scroll:SetVerticalScroll(math.min(maximum, math.max(0, offset)))
  end
  local preview = Step("preview", ns.Locale:Get("appearance.preview.guide_title"),
    ns.Locale:Get("appearance.preview.guide_text"),
    appearanceKey, function() return Appearance().preview end, ns.Locale:Get("appearance.preview.guide_hint"))
  local language = Step("language", ns.Locale:Get("locale.guide.title"), ns.Locale:Get("locale.guide.text"), "general",
    function() return ns.Options.general.language.select end)
  language.enter = function()
    N.Page("general")
    local page = ns.Options.general
    local _, contentY = page.content:GetCenter()
    local _, languageY = page.language:GetCenter()
    local offset = contentY + page.content:GetHeight() / 2 - languageY - page.language:GetHeight() / 2 - 8
    local maximum = math.max(0, page.content:GetHeight() - page.scroll:GetHeight())
    page.scroll:SetVerticalScroll(math.min(maximum, math.max(0, offset)))
  end
  return {
    Step("group", "Settings live with their addon", "Use an addon's Settings, Appearance, Commands, and Previews and guide pages. Battleground panels use /hg bg test. Run /hg test or /hg test stop from Help and commands to toggle or stop all previews. Overview and enable controls whether the addon runs after reload. Shared preferences affect all addons.", settingsKey,
      function() return ns.Options.featurePages[bg and "battlegrounds" or "shared"].featureGroups[1].heading end),
    Step("switch", bg and "Keep the panels you want" or "Choose shared preferences",
      bg and "Checked means enabled. All available feature switches are shown here; scroll to see the rest." or "Checked means enabled. This switch shows the Highground minimap button.", settingsKey,
      function() return Box(bg and "killorder" or "minimap") end),
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
    { id = "level", title = "Choose the warnings you want", text = "Essentials is a starting point. Text only keeps written alerts and silences alert sounds.",
      enter = Open, target = function() return ns.Alerts.win.mode end, context = Context, hint = "This changes your real alert preference." },
    { id = "customize", title = "Go straight to an addon's alerts",
      text = "The Battlegrounds, Nearby and Bounties links open their text and sound controls directly. Disabled addons become available after you enable them in Addons and reload.",
      enter = Open, target = function() return ns.Alerts.win.addonLinks.battlegrounds end, context = Context,
      action = bg and function() return ns.Alerts.win.addonLinks.battlegrounds end or nil,
      advance = bg and function() return ns.Hub.win and ns.Hub.win:IsVisible() and ns.Hub.current == "battlegrounds-settings" end or nil,
      requireAction = bg, hint = bg and "Click Battlegrounds, or Next to open its alert controls." or "Enemy stealth stays available here even when an addon is disabled." },
    { id = "channels", title = "Choose text, sound or both", text = bg
        and "These switches belong to Battlegrounds settings. Nearby and Bounties have their own. Your shared alert level and master sound still apply."
        or "Enemy stealth applies across addons. Other alert categories live in their addon's Settings. Your shared alert level and master sound still apply.",
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
      context = function() return bg and ns.Hub.win or ns.Alerts.win end, hint = "Changes here save immediately." },
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
    local step = Step(id, title, text, "profiles", target, hint)
    step.enter = enter or Open
    return step
  end
  return {
    ProfileStep("name", "Name a reusable setup", "Your current settings already save automatically. New profile makes a separate copy. Default keeps your starting setup.", function() return P().profileName end, Create),
    ProfileStep("source", "Choose a starting point", "Start from current settings, Default or a playstyle preset. Choosing a source only changes this review.", function() return P().source end, Create),
    ProfileStep("contents", "Read everything included", "Scroll through the complete saved setup, including disabled options, defaults, alerts, appearance, positions and targeting.", function() return P().profileScroll end, Create),
    ProfileStep("save", "Create when you are ready", "Create and use profile saves the reviewed setup. Cancel leaves your current settings alone.", function() return P().profileButtons.Save end, Create,
      "Optional: this button saves a real profile. Next continues without saving."),
    ProfileStep("changes", "See exactly what an update changes", ns.Locale:Get("profiles.guide.diff"), function() return P().profileScroll end,
      function() Open(); P().BeginReviewExample() end, "Example only. No settings or saved profiles are changed."),
    ProfileStep("load", "Select, review, then use", "Selecting a saved profile does not apply it. Use profile applies it. Use saved copy restores the active profile; Update from current reviews replacing another profile.", function() return P().listScroll end,
      function() Open(); P().SelectProfile(ns.Core.db.activeProfile or "Default") end),
    ProfileStep("switching", "Choose when profiles load", "Automatic switching is always visible. Choose profiles for Battlegrounds, Arena and Open world for this character and specialization. Keep current settings leaves an activity unassigned.", function() return P().assignments end, Open,
      "These are real assignments. Choices save immediately; the toggle turns switching on or off."),
    ProfileStep("sharing", "Share a saved copy or current settings", "Import, Export and Share in chat are directly available. Export lets you choose a saved profile or current settings, then copy the code or draft a chat link.", function() return P().footer end),
  }
end
local function Addons()
  local function Page() return O.Build() end
  local function Card() return Page().cards.battlegrounds end
  local function Reveal(target)
    N.Page("addons")
    local page = Page()
    local _, bodyY = page.body:GetCenter()
    local _, targetY = target:GetCenter()
    page.scroll:Scroll(math.max(0, bodyY + page.body:GetHeight() / 2 - targetY - target:GetHeight() / 2 - 16))
  end
  local steps = {
    Step("installation", "Highground is the only download you need", "Addons brings the addon switches, settings shortcuts and guides together. Remove any separate standalone downloads. Keep every module folder and both required data addons. Disabling a data addon stops Highground from loading.", "addons",
      function() return Page().notice and Page().notice.title or Page().hint end, "A disabled module does not activate a standalone copy. Nothing is removed by this guide."),
    Step("switches", "Choose which addons run", "Enable addon is the same per-character switch as WoW's AddOn List. All six subaddons are included in the Highground download.", "addons",
      function() return Card().addon end, "These are real switches. You can continue without changing anything."),
    Step("visit", "Visit settings or replay a guide", "Visit opens this addon's overview and settings. Start, Resume or Replay opens its walkthrough and keeps its saved place.", "addons",
      function() return Card().visit end, "Visit leaves this walkthrough. Next continues without visiting."),
    Step("sections", "Recognize subaddons in the sidebar", "Each subaddon has a small crest and an accent stripe. Expand its section for Overview and enable, Settings, Appearance where available, Commands, and Previews and guide.", "addons",
      function() local button = N.Nav("module-battlegrounds"); return button and button.groupButton end,
      "Shared preferences, Saved setups and Help apply beyond an individual addon."),
    Step("pending", "Keep your settings when disabling an addon", "Changing a switch takes effect after reload. Saved panel preferences and records stay intact. Show panel on Nearby and Arena cards changes only the panel preference. Changing Enable addon back before reload cancels that change.", "addons",
      function() return Page().status end, "Profiles do not enable or disable addons."),
    Step("reload", "Reload when you are ready", "After changing a switch, Reload to apply appears on Addons. Reload outside combat to start enabled modules and stop disabled ones. The guide never reloads automatically.", "addons",
      function() return Page().reload:IsShown() and Page().reload or Page().status end, "Next continues without reloading."),
    Step("commands", "Find commands and their controls", "Each addon has a Commands page; Help and commands combines them. Each command uses one row. Hover for full syntax and aliases. The button opens settings, runs the action or opens labeled fields for its values.", "tools",
      function() return ns.Options.tools.commandRows[1].button end, "Browsing is safe. Action buttons can change real settings; this guide does not click them."),
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
    { id = "members", title = "Discover channel members",
      text = "Your own character counts immediately. A complete channel member list adds other members before their addon announcements arrive. Refresh members shows a loader and stays disabled while waiting. Try it to see a sample departure.",
      enter = Sample("members", "refresh"), target = function() return ns.Hub.users.refresh end, context = Context,
      event = "OnClick", hint = "This sample does not request a live member list or send messages." },
    { id = "versions", title = "Membership and version reports are different",
      text = "A channel member may not have a responding addon. Members without an announcement have their own count. Versions come only from received announcements; verify update notices in your addon manager.",
      enter = Sample("members", "versions"), target = function() return ns.Hub.users.versions end, context = Context },
    { id = "fallback", title = "Keep useful counts when a list is unavailable",
      text = "An incomplete or unavailable member list keeps the last complete list briefly, then falls back to recent announcements. Counts can include characters who have since left. Group and guild discovery still uses announcements.",
      enter = Sample("fallback", "roster"), target = function() return ns.Hub.users.roster end, context = Context,
      hint = "Close the guide to return to live counts. Discovery preferences are disabled only in this sample." },
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
