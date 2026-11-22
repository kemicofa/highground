local ADDON, ns = ... -- ADDON: this addon's folder name
local Theme, Kit = ns.Theme, ns.Kit
local S, Z = Theme.Space, Theme.Size
local Hub = {}
ns.Hub = Hub

---------------------------------------------------------------------------
-- Highground configuration, opened by /hg, /hg config and the minimap
-- button. Settings, profiles and the guide are borrowed while shown, so
-- Blizzard Options > AddOns > Highground keeps working. Addon workspaces
-- open separately through the buttons on their configuration pages.
-- Not secure: opens and works in combat.
---------------------------------------------------------------------------
Hub.W, Hub.H, Hub.NAV_W = 960, 700, 190

-- Sidebar order. key: a settings page key (config/Options.lua) or a hub
-- section; label overrides the page name; cmd: the slash command that opens
-- the same window on its own (Home leaves those out of its previews).
local LAYOUT = {
  ns.Localization.Define({ key = "home", label = ns.Locale:Get("highground.hub.home.70f8bb") }, { label = "highground.hub.home.70f8bb" }),
  ns.Localization.Define({ key = "addons", label = ns.Locale:Get("highground.hub.addons.f32c2d"), cmd = "guide" }, { label = "highground.hub.addons.f32c2d" }),
  ns.Localization.Define({ group = "Battlegrounds", module = "battlegrounds", collapsed = true }, { groupLabel = "highground.modules.battlegrounds.2de13e" }),
  ns.Localization.Define({ key = "module-battlegrounds", label = ns.Locale:Get("highground.hub.overview_and_enable.6d2675") }, { label = "highground.hub.overview_and_enable.6d2675" }),
  ns.Localization.Define({ key = "battlegrounds-settings", label = ns.Locale:Get("highground.hub.settings.c7f73b") }, { label = "highground.hub.settings.c7f73b" }),
  ns.Localization.Define({ key = "battlegrounds-appearance", label = ns.Locale:Get("highground.hub.appearance.41def7") }, { label = "highground.hub.appearance.41def7" }),
  ns.Localization.Define({ key = "battlegrounds-previews", label = ns.Locale:Get("highground.hub.previews_and_guide.e53405") }, { label = "highground.hub.previews_and_guide.e53405" }),
  ns.Localization.Define({ key = "battlegrounds-commands", label = ns.Locale:Get("highground.hub.commands.45e5f3") }, { label = "highground.hub.commands.45e5f3" }),
  { key = "timers" },
  { key = "behavior" }, { key = "priority" }, { key = "objectives" }, { key = "live" },
  { key = "cooldowns" }, { key = "tracking" }, { key = "burst" }, { key = "specs" }, { key = "multipliers" },
  ns.Localization.Define({ group = "Arena", module = "arena", collapsed = true }, { groupLabel = "highground.modules.arena.1a4ba8" }),
  ns.Localization.Define({ key = "module-arena", label = ns.Locale:Get("highground.hub.overview_and_enable.6d2675") }, { label = "highground.hub.overview_and_enable.6d2675" }),
  ns.Localization.Define({ key = "arena-settings", label = ns.Locale:Get("highground.hub.settings.c7f73b") }, { label = "highground.hub.settings.c7f73b" }),
  ns.Localization.Define({ key = "arena-appearance", label = ns.Locale:Get("highground.hub.appearance.41def7") }, { label = "highground.hub.appearance.41def7" }),
  ns.Localization.Define({ key = "arena-previews", label = ns.Locale:Get("highground.hub.previews_and_guide.e53405") }, { label = "highground.hub.previews_and_guide.e53405" }),
  ns.Localization.Define({ key = "arena-commands", label = ns.Locale:Get("highground.hub.commands.45e5f3") }, { label = "highground.hub.commands.45e5f3" }),
  ns.Localization.Define({ group = "Nearby", module = "nearby", collapsed = true }, { groupLabel = "highground.modules.nearby.f1536c" }),
  ns.Localization.Define({ key = "module-nearby", label = ns.Locale:Get("highground.hub.overview_and_enable.6d2675") }, { label = "highground.hub.overview_and_enable.6d2675" }),
  ns.Localization.Define({ key = "nearby", label = ns.Locale:Get("highground.hub.settings.c7f73b") }, { label = "highground.hub.settings.c7f73b" }),
  ns.Localization.Define({ key = "nearby-appearance", label = ns.Locale:Get("highground.hub.appearance.41def7") }, { label = "highground.hub.appearance.41def7" }),
  ns.Localization.Define({ key = "nearby-previews", label = ns.Locale:Get("highground.hub.previews_and_guide.e53405") }, { label = "highground.hub.previews_and_guide.e53405" }),
  ns.Localization.Define({ key = "nearby-commands", label = ns.Locale:Get("highground.hub.commands.45e5f3") }, { label = "highground.hub.commands.45e5f3" }),
  ns.Localization.Define({ group = "Bounties", module = "bounties", collapsed = true }, { groupLabel = "highground.modules.bounties.eba0bf" }),
  ns.Localization.Define({ key = "module-bounties", label = ns.Locale:Get("highground.hub.overview_and_enable.6d2675") }, { label = "highground.hub.overview_and_enable.6d2675" }),
  ns.Localization.Define({ key = "bounty", label = ns.Locale:Get("highground.hub.settings.c7f73b") }, { label = "highground.hub.settings.c7f73b" }),
  ns.Localization.Define({ key = "bounties-appearance", label = ns.Locale:Get("highground.hub.appearance.41def7") }, { label = "highground.hub.appearance.41def7" }),
  ns.Localization.Define({ key = "bounties-previews", label = ns.Locale:Get("highground.hub.previews_and_guide.e53405") }, { label = "highground.hub.previews_and_guide.e53405" }),
  ns.Localization.Define({ key = "bounties-commands", label = ns.Locale:Get("highground.hub.commands.45e5f3") }, { label = "highground.hub.commands.45e5f3" }),
  ns.Localization.Define({ group = "Reputation", module = "reputation", collapsed = true }, { groupLabel = "highground.modules.reputation.5f2160" }),
  ns.Localization.Define({ key = "module-reputation", label = ns.Locale:Get("highground.hub.overview_and_enable.6d2675") }, { label = "highground.hub.overview_and_enable.6d2675" }),
  ns.Localization.Define({ key = "reputation-settings", label = ns.Locale:Get("highground.hub.settings.c7f73b") }, { label = "highground.hub.settings.c7f73b" }),
  ns.Localization.Define({ key = "reputation-previews", label = ns.Locale:Get("highground.hub.previews_and_guide.e53405") }, { label = "highground.hub.previews_and_guide.e53405" }),
  ns.Localization.Define({ key = "reputation-commands", label = ns.Locale:Get("highground.hub.commands.45e5f3") }, { label = "highground.hub.commands.45e5f3" }),
  ns.Localization.Define({ group = "Macros", module = "macros", collapsed = true }, { groupLabel = "highground.modules.macros.899bd6" }),
  ns.Localization.Define({ key = "module-macros", label = ns.Locale:Get("highground.hub.overview_and_enable.6d2675") }, { label = "highground.hub.overview_and_enable.6d2675" }),
  ns.Localization.Define({ key = "macros-settings", label = ns.Locale:Get("highground.hub.settings.c7f73b") }, { label = "highground.hub.settings.c7f73b" }),
  ns.Localization.Define({ key = "macros-previews", label = ns.Locale:Get("highground.hub.previews_and_guide.e53405") }, { label = "highground.hub.previews_and_guide.e53405" }),
  ns.Localization.Define({ key = "macros-commands", label = ns.Locale:Get("highground.hub.commands.45e5f3") }, { label = "highground.hub.commands.45e5f3" }),
  ns.Localization.Define({ group = "Shared preferences", collapsed = true }, { groupLabel = "shared.options.shared_preferences.74ed51" }),
  ns.Localization.Define({ key = "general", label = ns.Locale:Get("highground.hub.general.9239ee") }, { label = "highground.hub.general.9239ee" }),
  ns.Localization.Define({ key = "appearance", label = ns.Locale:Get("highground.hub.shared_appearance.78b3c9") }, { label = "highground.hub.shared_appearance.78b3c9" }),
  ns.Localization.Define({ key = "alerts", label = ns.Locale:Get("highground.hub.alerts.d0efe0"), cmd = "alerts" }, { label = "highground.hub.alerts.d0efe0" }),
  ns.Localization.Define({ group = "Saved setups", collapsed = true }, { groupLabel = "highground.toursteps.saved_setups.427978" }),
  ns.Localization.Define({ key = "setup", label = ns.Locale:Get("highground.hub.playstyle_presets.469bdc"), cmd = "setup" }, { label = "highground.hub.playstyle_presets.469bdc" }),
  ns.Localization.Define({ key = "profiles", label = ns.Locale:Get("highground.hub.profiles.0c2a93") }, { label = "highground.hub.profiles.0c2a93" }),
  ns.Localization.Define({ group = "Help", collapsed = true }, { groupLabel = "battlegrounds.quickcalls.help.c47ae1" }),
  ns.Localization.Define({ key = "users", label = ns.Locale:Get("highground.hub.addon_users.1e4e6f"), cmd = "users" }, { label = "highground.hub.addon_users.1e4e6f" }),
  { key = "tools" },
}

-- Sections that are not settings pages: key -> frame().
local OWN = {
  addons = function() return ns.Onboarding.Open(true) end,
  users = function() return Hub.BuildUsers() end,
  home = function() return Hub.home end,
  setup = function() return ns.Setup.Open(true) end,
  alerts = function() return ns.Alerts.Open(true) end,
  profiles = function() return ns.Options.panel end,
}
for _, def in ipairs(ns.Modules.list) do
  OWN["module-" .. def.key] = function() return Hub.BuildModules(def.key) end
end

-- Addon version from the TOC, "" when unknown.
function Hub.Version()
  return ns.Api.AddOnMetadata(ADDON, "Version") or ""
end

local function PageName(key)
  local def = ns.OptionsConfig.pages[key]
  return def and def.name
end

-- The registered settings page for a page key, else nil.
local function FindPage(key)
  local name = PageName(key)
  for _, p in ipairs(ns.Options.pages) do
    if p.key == key or (name and p.name == name) then return p end
  end
end

local function KeyOf(page)
  if page.key then return page.key end
  for key, def in pairs(ns.OptionsConfig.pages) do
    if def.name == page.name then return key end
  end
  return page.name
end

-- Sidebar: { key, label, frame(), cmd } or { group = "Title" }. Pages this
-- client lacks are left out; pages added later land at the end.
function Hub.Sections()
  local list, used = {}, {}
  local function add(s, page)
    list[#list + 1] = { key = s.key, cmd = s.cmd, label = s.label or (page and page.name) or s.key,
      labelKey = ns.Localization.Key(s, "label") or (page and ns.Localization.Key(ns.OptionsConfig.pages[page.key], "name")),
      frame = page and function() return page.frame end or OWN[s.key] }
    if page then used[page] = true end
  end
  for _, s in ipairs(LAYOUT) do
    if s.group then
      list[#list + 1] = { group = s.group, labelKey = ns.Localization.Key(s, "groupLabel"), module = s.module, collapsed = s.collapsed }
    elseif OWN[s.key] then
      add(s)
    else
      local page = FindPage(s.key)
      if page then add(s, page) end
    end
  end
  for _, p in ipairs(ns.Options.pages) do
    if not used[p] then add({ key = KeyOf(p) }, p) end
  end
  return list
end

-- Borrowing ------------------------------------------------------------------
local borrowed -- { frame, parent, points, strata, extras }

local function Return()
  local b = borrowed
  if not b then return end
  borrowed = nil
  local f = b.frame
  f:Hide()
  f:SetParent(b.parent)
  f:ClearAllPoints()
  for _, pt in ipairs(b.points) do f:SetPoint(unpack(pt)) end
  if b.strata then f:SetFrameStrata(b.strata) end
  for _, hidden in ipairs(b.extras) do hidden:Show() end
  Kit.UnmountPage(f)
end
Hub.Return = Return

local function Borrow(f)
  if borrowed and borrowed.frame == f then return end
  Return()
  local b = { frame = f, parent = f:GetParent(), points = {}, extras = {} }
  for i = 1, (f.GetNumPoints and f:GetNumPoints()) or 1 do
    local pt = { f:GetPoint(i) }
    if pt[1] then b.points[#b.points + 1] = pt end
  end
  b.strata = f.GetFrameStrata and f:GetFrameStrata()
  -- The hub supplies close and history controls while it owns this window.
  if f.close then f.close:Hide(); b.extras[#b.extras + 1] = f.close end
  if f.header then
    for _, button in ipairs(f.header.navigation or {}) do
      if button:IsShown() then
        button:Hide(); b.extras[#b.extras + 1] = button
      end
    end
  end
  -- Dragging the borrowed window moves the hub; the hub's shadow is the only one.
  Kit.MountPage(f, Hub.win)
  borrowed = b
  f:SetParent(Hub.content)
  ns.Motion.Stop(f, 1)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", Hub.content, "TOPLEFT", 0, 0)
  f:SetPoint("BOTTOMRIGHT", Hub.content, "BOTTOMRIGHT", 0, 0)
  if f.SetFrameStrata then f:SetFrameStrata(Hub.win:GetFrameStrata()) end
  f:Show()
end
Hub.Borrow = Borrow

-- A standalone command for a window the hub holds: close the hub so the
-- window goes back and opens on its own.
function Hub.Release(f)
  if borrowed and borrowed.frame == f and Hub.win then Hub.win:Hide(); Return() end
end

-- Window ---------------------------------------------------------------------
function Hub.Build()
  if Hub.win then return Hub.win end
  local w = Kit.Dialog("HighgroundHub", { title = "HIGHGROUND", crest = true, width = Hub.W, height = Hub.H,
    onResume = function() Hub.Open() end,
    strata = "HIGH", savedKey = "hub", onClose = function()
      ns.Motion.Stop(Hub.content, 1)
      if not Kit.Windows.switching then Return() end
    end })
  Hub.win = w

  Hub.content = w.content
  Hub.content:ClearAllPoints()
  Hub.content:SetPoint("TOPLEFT", Hub.NAV_W + S("lg"), -Z("header") - S("md"))
  Hub.content:SetPoint("BOTTOMRIGHT", -S("md") - S("xs"), S("md") + S("xs"))
  Hub.content:HookScript("OnHide", function(self) ns.Motion.Stop(self, 1) end)

  Hub.sections = Hub.Sections()
  Hub.BuildNav(w)
  ns.Options.Profiles.AttachContext(w, { Hub.content, w.navScroll, w.navFill })
  if Hub.BuildHome then Hub.BuildHome(Hub.content) end
  Hub.BuildRoutes(w)
  return w
end

-- The Blizzard panel takes its pages back when it opens.
if SettingsPanel and SettingsPanel.HookScript then
  SettingsPanel:HookScript("OnShow", function() if Hub.win then Hub.win:Hide() end end)
elseif InterfaceOptionsFrame and InterfaceOptionsFrame.HookScript then
  InterfaceOptionsFrame:HookScript("OnShow", function() if Hub.win then Hub.win:Hide() end end)
end

-- Key binding (Bindings.xml).
ns.Localization.Define(_G, { BINDING_NAME_HIGHGROUND_HUB = "highground.hub.open_or_close_highground.5d9ad2" })
Highground_Hub = function() Hub.Toggle() end
