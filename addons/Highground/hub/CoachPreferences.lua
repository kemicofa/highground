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
      or "Bar textures, colours and borders are shared. Adjust each panel's size in its own addon's Appearance page.", appearanceKey, function() return Appearance().details end)
  details.enter = function()
    N.Page(appearanceKey)
    local page = Appearance()
    local _, contentY = page.child:GetCenter()
    local _, buttonY = page.details:GetCenter()
    local offset = contentY + page.child:GetHeight() / 2 - buttonY - page.details:GetHeight() / 2 - 24
    local maximum = math.max(0, page.child:GetHeight() - page.scroll:GetHeight())
    page.scroll:SetVerticalScroll(math.min(maximum, math.max(0, offset)))
  end
  return {
    Step("group", "Settings live with their addon", "Use an addon's Settings, Appearance, and Previews and guide pages. Overview and enable controls whether the addon runs after reload. Shared preferences affect all addons.", settingsKey,
      function() return ns.Options.featurePages[bg and "battlegrounds" or "shared"].featureGroups[1].heading end),
    Step("switch", bg and "Keep the panels you want" or "Choose shared preferences",
      bg and "Checked means enabled. More options reveals the detailed feature switches." or "Checked means enabled. This switch shows the Highground minimap button.", settingsKey,
      function() return Box(bg and "killorder" or "minimap") end),
    appearance, theme, details,
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
    { id = "customize", title = "Open the category switches", text = "Click Choose addon alerts to find each addon’s text and sound controls.",
      enter = function() Open(); ns.Alerts.win.expanded = false; ns.Alerts.win:Refresh() end,
      target = function() return ns.Alerts.win.customize end, context = Context,
      advance = function() return ns.Alerts.win.expanded == true end, requireAction = true, hint = "Click Choose addon alerts." },
    { id = "channels", title = "Choose text, sound or both", text = bg
        and "These switches belong to Battlegrounds settings. Nearby and Bounties have their own. Your shared alert level and master sound still apply."
        or "Enemy stealth applies across addons. Other alert categories live in their addon's Settings. Your shared alert level and master sound still apply.",
      enter = function()
        if bg then
          N.Page("battlegrounds-settings")
          local page = ns.Options.featurePages.battlegrounds
          page.scroll:SetVerticalScroll(math.max(0, page.content:GetHeight() - page.scroll:GetHeight()))
        else
          Open(); local w = ns.Alerts.win; w.expanded = true; w:Refresh()
          w.scroll:SetVerticalScroll(math.max(0, w.body:GetHeight() - w.scroll:GetHeight()))
        end
      end,
      target = function()
        if bg then return ns.Options.featurePages.battlegrounds.alertRows[1].sound end
        for _, row in ipairs(ns.Alerts.win.rows) do if row.key == "stealth" then return row.sound end end
      end,
      context = function() return bg and ns.Hub.win or ns.Alerts.win end, hint = "Changes here save immediately." },
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
    Step("installation", "Highground is the only download you need", "Highground includes all six features. Remove any separate standalone downloads. Keep every module folder and both required data addons. Disabling a data addon stops Highground from loading.", "addons",
      function() return Page().notice and Page().notice.title or Page().hint end, "A disabled module does not activate a standalone copy. Nothing is removed by this guide."),
    Step("switches", "Choose which addons run", "These are the same per-character switches as WoW's AddOn List and Enable addon on each subaddon card in the Feature guide. All six modules are included in the Highground download.", "addons",
      function() return Page().rows[1] end, "These are real switches. You can continue without changing anything."),
    Step("pending", "Keep your settings when disabling an addon", "Changing a switch takes effect after reload. Saved panel preferences and records stay intact. Show panel on Nearby and Arena guide cards changes only the panel preference. Changing Enable addon back before reload cancels that change.", "addons",
      function() return Page().status end, "Profiles do not enable or disable addons."),
    Step("reload", "Reload when you are ready", "After changing a switch, Reload to apply appears here and in the Feature guide. Reload outside combat to start enabled modules and stop disabled ones. The guide never reloads automatically.", "addons",
      function() return Page().reload:IsShown() and Page().reload or Page().status end, "Next finishes this guide without reloading."),
  }
  steps[1].enter = function() N.Page("addons"); Page().scroll:Scroll(0) end
  steps[2].enter = function() N.Page("addons"); Page().scroll:Scroll(Page().switchOffset) end
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
      text = "Your own character counts immediately. A complete channel member list adds other members before their addon announcements arrive. Click Refresh members to see a sample departure.",
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
