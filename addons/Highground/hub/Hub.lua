local ADDON, ns = ... -- ADDON: this addon's folder name
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local S, Z = Theme.Space, Theme.Size
local Hub = {}
ns.Hub = Hub

---------------------------------------------------------------------------
-- Highground hub: one window for everything, opened by /hg, /hg config and
-- the minimap button. It draws nothing twice: the settings pages, the
-- profiles page, the macros window and the bounty board are borrowed
-- (reparented into the hub while shown, handed back afterwards), so the
-- Blizzard Options > AddOns > Highground panel keeps working unchanged.
-- Not secure: opens and works in combat.
---------------------------------------------------------------------------
Hub.W, Hub.H, Hub.NAV_W = 960, 700, 190

-- Sidebar order. key: a settings page key (config/Options.lua) or a hub
-- section; label overrides the page name; cmd: the slash command that opens
-- the same window on its own (Home leaves those out of its previews).
local LAYOUT = {
  { key = "home", label = "Home" },
  { key = "addons", label = "Addons" },
  { key = "checklist", label = "Feature guide", cmd = "guide" },
  { group = "Battlegrounds", collapsed = true },
  { key = "module-battlegrounds", label = "Overview and enable" },
  { key = "battlegrounds-settings", label = "Settings" },
  { key = "battlegrounds-appearance", label = "Appearance" },
  { key = "battlegrounds-previews", label = "Previews and guide" },
  { key = "battlegrounds-commands", label = "Commands" },
  { key = "history", label = "Match history", cmd = "history" },
  { key = "timers" },
  { key = "behavior" }, { key = "priority" }, { key = "objectives" }, { key = "live" },
  { key = "cooldowns" }, { key = "tracking" }, { key = "burst" }, { key = "specs" }, { key = "multipliers" },
  { group = "Arena", collapsed = true },
  { key = "module-arena", label = "Overview and enable" },
  { key = "arena-settings", label = "Settings" },
  { key = "arena-appearance", label = "Appearance" },
  { key = "arena-previews", label = "Previews and guide" },
  { key = "arena-commands", label = "Commands" },
  { group = "Nearby", collapsed = true },
  { key = "module-nearby", label = "Overview and enable" },
  { key = "nearby", label = "Settings" },
  { key = "nearby-appearance", label = "Appearance" },
  { key = "nearby-previews", label = "Previews and guide" },
  { key = "nearby-commands", label = "Commands" },
  { key = "journal", label = "Enemy journal", cmd = "journal" },
  { group = "Bounties", collapsed = true },
  { key = "module-bounties", label = "Overview and enable" },
  { key = "bounty", label = "Settings" },
  { key = "bounties-appearance", label = "Appearance" },
  { key = "bounties-previews", label = "Previews and guide" },
  { key = "bounties-commands", label = "Commands" },
  { key = "bountyboard", label = "Bounty board", cmd = "bounty" },
  { group = "Reputation", collapsed = true },
  { key = "module-reputation", label = "Overview and enable" },
  { key = "reputation-settings", label = "Settings" },
  { key = "reputation-previews", label = "Previews and guide" },
  { key = "reputation-commands", label = "Commands" },
  { key = "reputation", label = "Player reputation", cmd = "reputation" },
  { group = "Macros", collapsed = true },
  { key = "module-macros", label = "Overview and enable" },
  { key = "macros-settings", label = "Settings" },
  { key = "macros-previews", label = "Previews and guide" },
  { key = "macros-commands", label = "Commands" },
  { key = "macros", label = "Macro builder", cmd = "macros" },
  { group = "Shared preferences", collapsed = true },
  { key = "general", label = "General" },
  { key = "appearance", label = "Shared appearance" },
  { key = "alerts", label = "Alerts", cmd = "alerts" },
  { group = "Saved setups", collapsed = true },
  { key = "setup", label = "Playstyle presets", cmd = "setup" },
  { key = "profiles", label = "Profiles" },
  { group = "Help", collapsed = true },
  { key = "users", label = "Addon users", cmd = "users" },
  { key = "tools" },
}

-- Sections that are not settings pages: key -> frame().
local OWN = {
  addons = function() return Hub.BuildModules() end,
  users = function() return Hub.BuildUsers() end,
  home = function() return Hub.home end,
  checklist = function() return ns.Onboarding.Open(true) end,
  setup = function() return ns.Setup.Open(true) end,
  alerts = function() return ns.Alerts.Open(true) end,
  history = function() return ns.MatchHistory.Open(true) end,
  journal = function() return ns.EnemyJournal and ns.EnemyJournal.Open(true) end,
  profiles = function() return ns.Options.panel end,
  bountyboard = function() return ns.Bounty and ns.Bounty.Board and ns.Bounty.Board.Build() end,
  reputation = function() return ns.Reputation and ns.Reputation.Open(true) end,
  ["reputation-settings"] = function()
    local frame = ns.Reputation and ns.Reputation.Open(true)
    if frame then ns.Reputation.UI.SetMode("settings") end
    return frame
  end,
  macros = function() return ns.Macros and ns.Macros.Window and ns.Macros.Window.Build() end,
}
for _, def in ipairs(ns.Modules.list) do
  OWN["module-" .. def.key] = function() return Hub.BuildModules(def.key) end
end

-- Addon version from the TOC, "" when unknown.
function Hub.Version()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get(ADDON, "Version") or ""
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
      frame = page and function() return page.frame end or OWN[s.key] }
    if page then used[page] = true end
  end
  for _, s in ipairs(LAYOUT) do
    if s.group then
      list[#list + 1] = { group = s.group, collapsed = s.collapsed }
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
local borrowed -- { frame, parent, points, strata, extras, movable }

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
  if b.movable ~= nil and f.SetMovable then f:SetMovable(b.movable) end
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
  if f.IsMovable then b.movable = f:IsMovable(); f:SetMovable(false) end
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
BINDING_NAME_HIGHGROUND_HUB = "Open or close Highground"
Highground_Hub = function() Hub.Toggle() end
