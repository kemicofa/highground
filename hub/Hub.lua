local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local S, Z = Theme.Space, Theme.Size
local Hub = {}
ns.Hub = Hub

---------------------------------------------------------------------------
-- Warboard hub: one window for everything, opened by /wb, /wb config and
-- the minimap button. It draws nothing twice: the settings pages, the
-- profiles page, the PvP macros window and the bounty board are borrowed
-- (reparented into the hub while shown, handed back afterwards), so the
-- Blizzard Options > AddOns > Warboard panel keeps working unchanged.
-- Not secure: opens and works in combat.
---------------------------------------------------------------------------
Hub.W, Hub.H, Hub.NAV_W = 960, 660, 190

local GAME_LABEL = { forever = "WOW FOREVER", cata = "CATACLYSM", retail = "RETAIL" }

-- Sidebar order. key: a settings page key (config/Options.lua) or a hub
-- section; label overrides the page name; cmd: the slash command that opens
-- the same window on its own (Home leaves those out of its previews).
local LAYOUT = {
  { key = "home", label = "Home" },
  { group = "Settings" },
  { key = "general", label = "Features" },
  { key = "appearance" },
  { key = "profiles", label = "Profiles" },
  { group = "Targeting" },
  { key = "behavior" }, { key = "priority" }, { key = "objectives" }, { key = "live" },
  { key = "cooldowns" }, { key = "tracking" }, { key = "burst" }, { key = "specs" }, { key = "multipliers" },
  { group = "Battleground and world" },
  { key = "timers" }, { key = "nearby" }, { key = "bounty" },
  { key = "bountyboard", label = "Bounty board", cmd = "bounty" },
  { group = "Tools" },
  { key = "macros", label = "PvP macros", cmd = "macros" },
  { key = "tools" },
}

-- Sections that are not settings pages: key -> frame().
local OWN = {
  home = function() return Hub.home end,
  profiles = function() return ns.Options.panel end,
  bountyboard = function() return ns.Bounty and ns.Bounty.Board and ns.Bounty.Board.Build() end,
  macros = function() return ns.Macros and ns.Macros.Window and ns.Macros.Window.Build() end,
}

-- Addon version from the TOC, "" when unknown.
function Hub.Version()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get("Warboard", "Version") or ""
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
      list[#list + 1] = { group = s.group }
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
local borrowed -- { frame, parent, points, shown, strata, extras, movable }

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
  if b.shown then f:Show() end
end
Hub.Return = Return

local function Borrow(f)
  if borrowed and borrowed.frame == f then return end
  Return()
  local b = { frame = f, parent = f:GetParent(), points = {}, shown = f:IsShown(), extras = {} }
  for i = 1, (f.GetNumPoints and f:GetNumPoints()) or 1 do
    local pt = { f:GetPoint(i) }
    if pt[1] then b.points[#b.points + 1] = pt end
  end
  b.strata = f.GetFrameStrata and f:GetFrameStrata()
  -- Windows lose their own close button and dragging while inside the hub.
  if f.close then f.close:Hide(); b.extras[#b.extras + 1] = f.close end
  if f.IsMovable then b.movable = f:IsMovable(); f:SetMovable(false) end
  borrowed = b
  f:SetParent(Hub.content)
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
  if borrowed and borrowed.frame == f and Hub.win then Hub.win:Hide() end
end

-- Window ---------------------------------------------------------------------
local function BuildNav(w)
  local head = Z("header")
  w.navFill = Theme.Fill(w, "BACKGROUND", "surface", "bar")
  w.navFill:SetPoint("TOPLEFT", 1, -head - 1)
  w.navFill:SetPoint("BOTTOMLEFT", 1, 1)
  w.navFill:SetWidth(Hub.NAV_W)
  w.nav, w.groups = {}, {}
  local y = -head - S("md") - S("xs")
  for _, s in ipairs(Hub.sections) do
    if s.group then
      local g = Kit.Caption(w, s.group)
      g:SetPoint("TOPLEFT", S("xl"), y - S("sm") - S("xs"))
      w.groups[#w.groups + 1] = g
      y = y - Z("row")
    else
      local b = Kit.Button(w, s.label, Hub.NAV_W - S("xl"), Z("control"),
        { tone = "panel", onClick = function() Hub.Show(s.key) end })
      b:SetPoint("TOPLEFT", S("md"), y)
      b.label:ClearAllPoints()
      b.label:SetPoint("LEFT", S("md") + S("xs"), 0)
      b.section = s
      w.nav[#w.nav + 1] = b
      y = y - Z("control") - S("xs")
    end
  end
end

function Hub.Build()
  if Hub.win then return Hub.win end
  local w = Kit.Dialog("WarboardHub", { title = "WARBOARD", width = Hub.W, height = Hub.H,
    strata = "HIGH", savedKey = "hub", onClose = function() Return() end })
  Hub.win = w
  w.blizzard = Kit.Button(w, "Blizzard settings", 120, Z("control"), { onClick = function()
    w:Hide()
    ns.Options.Open()
  end })
  w.blizzard:SetPoint("RIGHT", w.close, "LEFT", -S("md"), 0)

  Hub.content = w.content
  Hub.content:ClearAllPoints()
  Hub.content:SetPoint("TOPLEFT", Hub.NAV_W + S("lg"), -Z("header") - S("md"))
  Hub.content:SetPoint("BOTTOMRIGHT", -S("md") - S("xs"), S("md") + S("xs"))

  Hub.sections = Hub.Sections()
  BuildNav(w)
  if Hub.BuildHome then Hub.BuildHome(Hub.content) end
  return w
end

-- Nav button for a section key, label or page name (any case). An exact
-- key wins over a label that happens to match.
local function Find(w, key)
  local want = type(key) == "string" and key:lower()
  if not want then return nil end
  for _, b in ipairs(w.nav) do if b.section.key == key then return b end end
  for _, b in ipairs(w.nav) do
    local s = b.section
    local page = PageName(s.key)
    if s.key:lower() == want or s.label:lower() == want or (page and page:lower() == want) then return b end
  end
end

function Hub.Show(key)
  local w = Hub.Build()
  local section = (Find(w, key) or w.nav[1]).section
  Hub.current = section.key
  if Core.db then Core.db.hubSection = section.key end
  for _, b in ipairs(w.nav) do Kit.Paint(b, b.section == section and "accent" or "panel") end
  local f = section.frame and section.frame()
  if f == Hub.home then
    Return()
    Hub.home:Show()
    if Hub.RefreshHome then Hub.RefreshHome() end
  elseif f then
    if Hub.home then Hub.home:Hide() end
    Borrow(f)
  end
  local parts, version = {}, Hub.Version()
  if version ~= "" then parts[1] = "V" .. version end
  parts[#parts + 1] = GAME_LABEL[ns.GAME] or GAME_LABEL.retail
  parts[#parts + 1] = section.label:upper()
  w:SetSub(table.concat(parts, "  ·  "))
end

function Hub.Open(key)
  local w = Hub.Build()
  w:Show()
  Hub.Show(key or (Core.db and Core.db.hubSection) or "home")
end

function Hub.Toggle(key)
  local w = Hub.Build()
  local b = key and Find(w, key)
  if w:IsShown() and (not key or (b and b.section.key == Hub.current)) then w:Hide() else Hub.Open(key) end
end

-- The Blizzard panel takes its pages back when it opens.
if SettingsPanel and SettingsPanel.HookScript then
  SettingsPanel:HookScript("OnShow", function() if Hub.win then Hub.win:Hide() end end)
elseif InterfaceOptionsFrame and InterfaceOptionsFrame.HookScript then
  InterfaceOptionsFrame:HookScript("OnShow", function() if Hub.win then Hub.win:Hide() end end)
end

-- Key binding (Bindings.xml).
BINDING_NAME_WARBOARD_HUB = "Open or close Warboard"
Warboard_Hub = function() Hub.Toggle() end
