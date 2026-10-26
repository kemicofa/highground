local _, ns = ...
local Core, Macros = ns.Core, ns.Macros
local W, Win = ns.Widgets, Macros.Window
local C = Core.THEME.colors

local HEAD, TABS, FOOT = 64, 34, 34
local LIST_TOP = HEAD + TABS + 6
local TABS_DEF = {
  { key = "class", label = "MY CLASS" },
  { key = "mine", label = "MY MACROS" },
  { key = "general", label = "GENERAL" },
  { key = "all", label = "ALL CLASSES" },
  { key = "build", label = "BUILD" },
}

local function OpenMacroUI()
  if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_MacroUI")
  elseif LoadAddOn then pcall(LoadAddOn, "Blizzard_MacroUI") end
  if ShowMacroFrame then pcall(ShowMacroFrame) end
end

function Win.Build()
  if Win.win then return Win.win end
  local w = CreateFrame("Frame", "WarboardMacroFrame", UIParent, "BackdropTemplate")
  Win.win = w
  w:SetSize(Win.W, LIST_TOP + Win.CARDS * (Win.CARD_H + 4) + 14 + FOOT)
  w:SetFrameStrata("DIALOG")
  w:SetBackdrop({ bgFile = Core.WHITE, edgeFile = Core.WHITE, edgeSize = 1 })
  w:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.97)
  w:SetBackdropBorderColor(C.accent[1] * 0.6, C.accent[2] * 0.6, C.accent[3] * 0.6, 1)
  w:SetMovable(true)
  w:SetClampedToScreen(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", w.StartMoving)
  w:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    if Core.db then Core.db.macroPoint = { p, rp, x, y } end
  end)
  local pt = Core.db and Core.db.macroPoint
  w:SetPoint(pt and pt[1] or "CENTER", UIParent, pt and pt[2] or "CENTER", pt and pt[3] or 0, pt and pt[4] or 40)
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "WarboardMacroFrame") end

  local band = Core.Fill(w, "BORDER", C.accent[1], C.accent[2], C.accent[3], 0.06)
  band:SetPoint("TOPLEFT", 1, -1)
  band:SetPoint("TOPRIGHT", -1, -1)
  band:SetHeight(HEAD)
  local bar = Core.Fill(w, "ARTWORK", C.accent[1], C.accent[2], C.accent[3], 1)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetSize(4, HEAD)
  w.title = Core.Text(w, "bold", 24)
  w.title:SetPoint("TOPLEFT", 18, -12)
  w.title:SetText("PVP MACROS")
  w.title:SetTextColor(unpack(C.text))
  w.sub = Core.Text(w, "mono", 9)
  w.sub:SetPoint("TOPLEFT", w.title, "BOTTOMLEFT", 1, -3)
  w.sub:SetTextColor(unpack(C.muted))
  w.slots = Core.Text(w, "mono", 9)
  w.slots:SetPoint("TOPRIGHT", -44, -18)
  w.slots:SetTextColor(unpack(C.muted))
  w.close = W.Button(w, "X", 24, 24, C.surface, function() w:Hide() end)
  w.close:SetPoint("TOPRIGHT", -10, -10)

  w.tabs = {}
  for i, def in ipairs(TABS_DEF) do
    local t = W.Tab(w, def.label, function() Win.SetTab(def.key) end)
    t:SetWidth(def.key == "all" and 96 or 84)
    t:SetPoint("TOPLEFT", 14 + (i - 1) * 92, -HEAD - 6)
    w.tabs[def.key] = t
  end
  w.search = W.Input(w, 120, "")
  w.search:SetPoint("TOPRIGHT", -14, -HEAD - 8)
  w.search.hint = Core.Text(w.search, "mono", 9)
  w.search.hint:SetPoint("LEFT", 8, 0)
  w.search.hint:SetText("SEARCH")
  w.search.hint:SetTextColor(unpack(C.muted))
  w.search:SetScript("OnTextChanged", function(self)
    self.hint:SetShown(self:GetText() == "")
    Win.offset = 0
    Win.Refresh()
  end)

  w.rows = {}
  for i = 1, Win.CARDS do
    local r = Win.NewCard(w)
    r:SetPoint("TOPLEFT", 12, -LIST_TOP - (i - 1) * (Win.CARD_H + 4))
    r:SetPoint("RIGHT", w, "RIGHT", -12, 0)
    w.rows[i] = r
  end
  pcall(w.EnableMouseWheel, w, true)
  w:SetScript("OnMouseWheel", function(_, delta)
    Win.offset = math.max(0, Win.offset - delta)
    Win.Refresh()
  end)
  w.empty = Core.Text(w, "semi", 15)
  w.empty:SetPoint("TOP", 0, -LIST_TOP - 80)
  w.empty:SetTextColor(unpack(C.muted))
  w.range = Core.Text(w, "mono", 8)
  w.range:SetPoint("BOTTOMRIGHT", -14, FOOT + 2)
  w.range:SetTextColor(unpack(C.muted))

  w.open = W.Button(w, "Open WoW macros", 120, 20, C.surface, OpenMacroUI)
  w.open:SetPoint("BOTTOMLEFT", 12, 8)
  w.exportAll = W.Button(w, "Export all", 80, 20, C.surface, function() Macros.Share.ShowExport(Macros.Existing()) end)
  w.exportAll:SetPoint("LEFT", w.open, "RIGHT", 6, 0)
  w.import = W.Button(w, "Import", 64, 20, C.surface, function() Macros.Share.ShowImport() end)
  w.import:SetPoint("LEFT", w.exportAll, "RIGHT", 4, 0)
  w.help = Core.Text(w, "mono", 8)
  w.help:SetPoint("BOTTOMRIGHT", -14, 13)
  w.help:SetTextColor(unpack(C.muted))
  w.help:SetText("|cff218c85■|r IN GENERAL  ·  |cff805cd9■|r IN CHARACTER  ·  |cffffd11a□|r SHOWN  ·  SAME NAME = UPDATED")
  if Macros.BuildPanel then Macros.BuildPanel.Create(w, LIST_TOP) end
  w:SetScript("OnShow", function() Win.Refresh() end)
  w:Hide()
  return w
end

function Win.Open(tab)
  local w = Win.Build()
  if tab then Win.tab = tab end
  if Core.UpdateMe then pcall(Core.UpdateMe) end
  w:Show()
  Win.Refresh()
end

function Win.Toggle()
  local w = Win.Build()
  if ns.Hub then ns.Hub.Release(w) end
  if w:IsShown() then w:Hide() else Win.Open() end
end

-- /wb macros [build | mine | export | import]
function ns.Commands.macros(arg)
  if arg == "export" then return Macros.Share.ShowExport(Macros.Existing()) end
  if arg == "import" then return Macros.Share.ShowImport() end
  Win.Open((arg == "build" or arg == "mine") and arg or nil)
end
