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
      if button.groupButton and not button.groupButton.expanded then ns.Hub.SetGroupExpanded(button.groupButton, true) end
      return button
    end
  end
end
local function Step(id, title, text, page, target, hint)
  return { id = id, title = title, text = text, hint = hint or "Changes here save immediately.",
    enter = function() N.Page(page) end, target = target, context = function() return ns.Hub.win end }
end
local function Box(key)
  for _, box in ipairs(ns.Options.featureBoxes) do if box.key == key and box:IsVisible() then return box end end
end
local function Features()
  local appearance = Step("appearance", "Open Appearance", "Click Appearance in the sidebar to change how your panels look.", "general",
    function() return N.Nav("appearance") end, "Click Appearance.")
  appearance.requireAction = true; appearance.advance = function() return ns.Hub.current == "appearance" end
  local theme = Step("theme", "Choose a readable theme", "Try a theme from this menu. The panels use it as soon as you select it.", "appearance", function() return ns.Options.appearance.themeSelect end)
  theme.enter = function() N.Page("appearance"); ns.Options.appearance.scroll:SetVerticalScroll(0) end
  local details = Step("details", "Open more appearance controls", "Fine-tuning includes spacing and which details each enemy row shows.", "appearance", function() return ns.Options.appearance.details end)
  details.enter = function()
    N.Page("appearance")
    local page = ns.Options.appearance
    local _, contentY = page.child:GetCenter()
    local _, buttonY = page.details:GetCenter()
    local offset = contentY + page.child:GetHeight() / 2 - buttonY - page.details:GetHeight() / 2 - 24
    local maximum = math.max(0, page.child:GetHeight() - page.scroll:GetHeight())
    page.scroll:SetVerticalScroll(math.min(maximum, math.max(0, offset)))
  end
  return {
    Step("group", "Choose the part you want to configure", "This menu groups the real settings by feature. Your current choices are already selected.", "general", function() return ns.Options.general.group end),
    Step("switch", "Keep the panels you want", "Checked means enabled. Use More options only when you want finer controls.", "general",
      function() return Box("killorder") or Box("timers") or ns.Options.general.group end),
    appearance,
    theme, details,
  }
end
local function Alerts()
  local function Open()
    N.changing = true
    local w = ns.Alerts.Open(); ns.Hub.Release(w); Kit.Windows.Show(w); N.Track(w); N.Fit(w)
    N.changing = nil
  end
  local function Context() return ns.Alerts.win end
  return {
    { id = "level", title = "Choose the warnings you want", text = "Essentials is a starting point. Text only keeps written alerts and silences alert sounds.",
      enter = Open, target = function() return ns.Alerts.win.mode end, context = Context, hint = "This changes your real alert preference." },
    { id = "customize", title = "Open the category switches", text = "Click Customize categories to choose text and sound separately for each event.",
      enter = function() Open(); ns.Alerts.win.expanded = false; ns.Alerts.win:Refresh() end,
      target = function() return ns.Alerts.win.customize end, context = Context,
      advance = function() return ns.Alerts.win.expanded == true end, requireAction = true, hint = "Click Customize categories." },
    { id = "channels", title = "Choose text, sound or both", text = "These switches apply within your chosen alert level. A muted category stays quiet.",
      enter = function() Open(); if not ns.Alerts.win.expanded then ns.Alerts.win.expanded = true; ns.Alerts.win:Refresh() end end,
      target = function() return ns.Alerts.win.rows[1].sound end, context = Context, hint = "Changes here save immediately." },
  }
end
local function Profiles()
  local function P() return ns.Options.panel end
  local more = Step("more", "Find sharing and automatic switching", "Click Sharing and more options for imports, exports and activity assignments.", "profiles", function() return P().more end, "Click Sharing and more options.")
  more.requireAction = true; more.advance = function() return P().advanced:IsVisible() end
  more.enter = function() N.Page("profiles"); P().expanded = false; P().RefreshProfiles() end
  return {
    Step("name", "A profile is an optional saved copy", "Your settings already save automatically. Enter a name here only when you want a reusable copy.", "profiles", function() return P().profileName end),
    Step("save", "Save your current setup", "Save profile stores the current settings under this name. Updating an existing name replaces that saved copy.", "profiles", function() return P().profileButtons.Save end,
      "Optional: this button saves a real profile. Next continues without saving."),
    Step("load", "Select first, then load", "Saved copies appear here. Choosing a name does not change your setup; Load profile applies it.", "profiles",
      function() return P().savedProfiles:IsVisible() and P().savedProfiles or P().profileList end),
    more,
  }
end
local function Addons()
  local function Page() return ns.Hub.BuildModules() end
  local steps = {
    Step("installation", "Highground is the only download you need", "Highground includes all six features. If you also installed separate standalone addons, we recommend removing those downloads. Keep Highground, every module folder and both required data addons. Disabling either data addon prevents Highground from loading.", "addons",
      function() return Page().notice or Page().hint end, "A disabled module does not activate a standalone copy. Nothing is removed by this guide."),
    Step("switches", "Choose which addons run", "These are the same per-character switches as WoW's AddOn List. All six modules are included in the Highground download.", "addons",
      function() return Page().rows[1] end, "These are real switches. You can continue without changing anything."),
    Step("pending", "Keep your settings when disabling an addon", "Changing a switch takes effect after reload. Saved panel preferences and records stay intact. Changing it back before reload cancels that change.", "addons",
      function() return Page().status end, "Profiles do not enable or disable addons."),
    Step("reload", "Reload when you are ready", "After changing a switch, Reload to apply appears here. Reload outside combat to start enabled modules and stop disabled ones. The guide never reloads automatically.", "addons",
      function() return Page().reload:IsShown() and Page().reload or Page().status end, "Next finishes this guide without reloading."),
  }
  steps[1].enter = function() N.Page("addons"); Page().scroll:Scroll(0) end
  steps[2].enter = function() N.Page("addons"); Page().scroll:Scroll(Page().switchOffset) end
  return steps
end

function N.Start(key)
  N.active = key
  if key == "macros" then
    N.openedMacroFrame = not (MacroFrame and MacroFrame:IsVisible())
    return C.MacroSteps()
  elseif key == "addons" then return Addons()
  elseif key == "features" then return Features()
  elseif key == "alerts" then return Alerts()
  elseif key == "profile" then return Profiles()
  elseif key == "records" then return C.RecordSteps()
  elseif key == "reputation" then return C.ReputationSteps()
  elseif key == "enemies" then return C.EnemySteps()
  elseif key == "nearby" then return C.NearbySteps() end
end
