local _, ns = ...
local Core = ns.Core
local C = Core.THEME.colors
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
Hub.W, Hub.H, Hub.NAV_W, Hub.HEAD = 960, 660, 190, 56

-- Sidebar: { key, label, frame() } or { group = "Title" }.
function Hub.Sections()
  local O = ns.Options
  local function page(name)
    return function()
      for _, p in ipairs(O.pages) do if p.name == name then return p.frame end end
    end
  end
  local list = {
    { key = "home", label = "Home", frame = function() return Hub.home end },
    { group = "Settings" },
    { key = "general", label = "Features", frame = page("General") },
    { key = "appearance", label = "Appearance", frame = page("Appearance") },
    { key = "profiles", label = "Profiles", frame = function() return O.panel end },
    { group = "Targeting" },
  }
  local seen = { General = true, Appearance = true }
  local targeting = { "Target behavior", "Target priority", "Objectives", "Live signals", "Cooldowns",
    "Cooldown tracking", "Burst markers", "Spec ratings", "Advanced multipliers" }
  local function add(name, key)
    for _, p in ipairs(O.pages) do
      if p.name == name and not seen[name] then
        seen[name] = true
        list[#list + 1] = { key = key or name, label = name, frame = page(name) }
      end
    end
  end
  for _, name in ipairs(targeting) do add(name) end
  list[#list + 1] = { group = "Battleground and world" }
  for _, name in ipairs({ "Resurrection alerts", "Nearby enemies", "Guild bounties" }) do add(name) end
  list[#list + 1] = { key = "bountyboard", label = "Bounty board", frame = function()
    return ns.Bounty and ns.Bounty.Board and ns.Bounty.Board.Build()
  end }
  list[#list + 1] = { group = "Tools" }
  list[#list + 1] = { key = "macros", label = "PvP macros", frame = function()
    return ns.Macros and ns.Macros.Window and ns.Macros.Window.Build()
  end }
  add("Test and commands", "tools")
  -- Pages added later land here rather than going missing.
  for _, p in ipairs(O.pages) do if not seen[p.name] then add(p.name) end end
  return list
end

-- Borrowing ------------------------------------------------------------------
local borrowed -- { frame, parent, points, shown, strata, extras }

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
function Hub.Build()
  if Hub.win then return Hub.win end
  local W = ns.Widgets
  local w = CreateFrame("Frame", "WarboardHub", UIParent, "BackdropTemplate")
  Hub.win = w
  w:SetSize(Hub.W, Hub.H)
  w:SetFrameStrata("HIGH")
  w:SetBackdrop({ bgFile = Core.WHITE, edgeFile = Core.WHITE, edgeSize = 1 })
  w:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.98)
  w:SetBackdropBorderColor(C.accent[1] * 0.6, C.accent[2] * 0.6, C.accent[3] * 0.6, 1)
  w:SetMovable(true)
  w:SetClampedToScreen(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", w.StartMoving)
  w:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    if Core.db then Core.db.hubPoint = { p, rp, x, y } end
  end)
  local pt = Core.db and Core.db.hubPoint
  w:SetPoint(pt and pt[1] or "CENTER", UIParent, pt and pt[2] or "CENTER", pt and pt[3] or 0, pt and pt[4] or 0)
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "WarboardHub") end
  w:SetScript("OnHide", function() Return() end)

  local band = Core.Fill(w, "BORDER", C.accent[1], C.accent[2], C.accent[3], 0.07)
  band:SetPoint("TOPLEFT", 1, -1)
  band:SetPoint("TOPRIGHT", -1, -1)
  band:SetHeight(Hub.HEAD)
  local bar = Core.Fill(w, "ARTWORK", C.accent[1], C.accent[2], C.accent[3], 1)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetSize(4, Hub.HEAD)
  w.title = Core.Text(w, "bold", 24)
  w.title:SetPoint("TOPLEFT", 18, -10)
  w.title:SetText("WARBOARD")
  w.title:SetTextColor(unpack(C.text))
  w.sub = Core.Text(w, "mono", 9)
  w.sub:SetPoint("TOPLEFT", w.title, "BOTTOMLEFT", 1, -2)
  w.sub:SetTextColor(unpack(C.muted))
  w.close = W.Button(w, "X", 26, 26, C.surface, function() w:Hide() end)
  w.close:SetPoint("TOPRIGHT", -12, -14)
  w.blizzard = W.Button(w, "Blizzard settings", 120, 22, C.surface, function()
    w:Hide()
    ns.Options.Open()
  end)
  w.blizzard:SetPoint("RIGHT", w.close, "LEFT", -8, 0)

  local nav = Core.Fill(w, "BACKGROUND", C.surface[1], C.surface[2], C.surface[3], 0.55)
  nav:SetPoint("TOPLEFT", 1, -Hub.HEAD - 1)
  nav:SetPoint("BOTTOMLEFT", 1, 1)
  nav:SetWidth(Hub.NAV_W)
  Hub.content = CreateFrame("Frame", nil, w)
  Hub.content:SetPoint("TOPLEFT", Hub.NAV_W + 12, -Hub.HEAD - 8)
  Hub.content:SetPoint("BOTTOMRIGHT", -10, 10)

  w.nav = {}
  local y = -Hub.HEAD - 10
  for _, s in ipairs(Hub.Sections()) do
    if s.group then
      local g = Core.Text(w, "mono", 8)
      g:SetPoint("TOPLEFT", 16, y - 6)
      g:SetText(s.group:upper())
      g:SetTextColor(unpack(C.muted))
      y = y - 20
    else
      local b = W.Button(w, s.label, Hub.NAV_W - 16, 22, C.panel, function() Hub.Show(s.key) end)
      b:SetPoint("TOPLEFT", 8, y)
      b.label:ClearAllPoints()
      b.label:SetPoint("LEFT", 10, 0)
      b.section = s
      w.nav[#w.nav + 1] = b
      y = y - 24
    end
  end
  if Hub.BuildHome then Hub.BuildHome(Hub.content) end
  w:Hide()
  return w
end

function Hub.Show(key)
  local w = Hub.Build()
  local section
  for _, b in ipairs(w.nav) do if b.section.key == key then section = b.section end end
  section = section or w.nav[1].section
  Hub.current = section.key
  if Core.db then Core.db.hubSection = section.key end
  for _, b in ipairs(w.nav) do
    local on = b.section == section
    ns.Widgets.Paint(b, on and C.accent or C.panel, on and C.panel or C.text)
  end
  local f = section.frame and section.frame()
  if f == Hub.home then
    Return()
    Hub.home:Show()
    if Hub.RefreshHome then Hub.RefreshHome() end
  elseif f then
    if Hub.home then Hub.home:Hide() end
    Borrow(f)
  end
  local version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Warboard", "Version"))
    or (GetAddOnMetadata and GetAddOnMetadata("Warboard", "Version")) or ""
  w.sub:SetText(("V" .. version .. "  ·  " .. (ns.GAME == "forever" and "WOW FOREVER" or ns.GAME == "cata"
    and "CATACLYSM" or "RETAIL") .. "  ·  " .. section.label:upper()):gsub("^V  ·  ", ""))
end

function Hub.Open(key)
  local w = Hub.Build()
  w:Show()
  Hub.Show(key or (Core.db and Core.db.hubSection) or "home")
end

function Hub.Toggle(key)
  local w = Hub.Build()
  if w:IsShown() and (not key or key == Hub.current) then w:Hide() else Hub.Open(key) end
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
