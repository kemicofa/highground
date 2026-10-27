local _, ns = ...
local Core, Macros, Theme, Kit = ns.Core, ns.Macros, ns.Theme, ns.Kit
local Win = Macros.Window
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- The macros window frame (WarboardMacroFrame): a Kit.Dialog with tabs,
-- search, the card list, the builder and the footer. The hub borrows it
-- (hub/Hub.lua), hiding its close button meanwhile.
---------------------------------------------------------------------------
local HEAD, TABS, FOOT = 64, 34, 34
local LIST_TOP = HEAD + TABS + 6
local GAP = 4 -- between cards
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

-- Footer legend; the swatches are inline colour codes, so rebuilt on a
-- theme change.
local function Legend()
  local w = Win.win
  if not w then return end
  w.help:SetText(Theme.Hex("scopeGeneral") .. "■|r IN GENERAL  ·  " .. Theme.Hex("scopeCharacter")
    .. "■|r IN CHARACTER  ·  " .. Theme.Hex("gold") .. "□|r SHOWN  ·  SAME NAME = UPDATED")
end
Theme.OnChange(Legend)

function Win.Build()
  if Win.win then return Win.win end
  local w = Kit.Dialog("WarboardMacroFrame", { title = "PVP MACROS", header = HEAD, savedKey = "macros",
    point = { "CENTER", "CENTER", 0, 40 }, width = Win.W,
    height = LIST_TOP + Win.CARDS * (Win.CARD_H + GAP) + 14 + FOOT })
  Win.win = w
  -- Inside the hub the frame is pinned (not movable): don't save a
  -- hub-relative position as the window's own.
  w:SetScript("OnDragStop", function(self)
    if not self:IsMovable() then return end
    self:StopMovingOrSizing()
    Kit.SavePoint("macros", self)
  end)
  w.slots = Theme.Text(w, "label", "textMuted")
  w.slots:SetPoint("TOPRIGHT", -44, -18)

  w.tabs = {}
  for i, def in ipairs(TABS_DEF) do
    local t = Kit.Tab(w, def.label, function() Win.SetTab(def.key) end)
    t:SetWidth(def.key == "all" and 96 or Z("tabWidth"))
    t:SetPoint("TOPLEFT", 14 + (i - 1) * 92, -HEAD - 6)
    w.tabs[def.key] = t
  end
  w.search = Kit.Input(w, 120, "")
  w.search:SetPoint("TOPRIGHT", -14, -HEAD - S("md"))
  w.search.hint = Theme.Text(w.search, "label", "textMuted")
  w.search.hint:SetPoint("LEFT", S("md"), 0)
  w.search.hint:SetText("SEARCH")
  w.search:SetScript("OnTextChanged", function(self)
    self.hint:SetShown(self:GetText() == "")
    Win.offset = 0
    Win.Refresh()
  end)

  w.rows = {}
  for i = 1, Win.CARDS do
    local r = Win.NewCard(w)
    r:SetPoint("TOPLEFT", S("lg"), -LIST_TOP - (i - 1) * (Win.CARD_H + GAP))
    r:SetPoint("RIGHT", w, "RIGHT", -S("lg"), 0)
    w.rows[i] = r
  end
  pcall(w.EnableMouseWheel, w, true)
  w:SetScript("OnMouseWheel", function(_, delta)
    Win.offset = math.max(0, Win.offset - delta)
    Win.Refresh()
  end)
  w.empty = Theme.Text(w, "rowName", "textMuted")
  w.empty:SetPoint("TOP", 0, -LIST_TOP - 80)
  w.range = Theme.Text(w, "caption", "textMuted")
  w.range:SetPoint("BOTTOMRIGHT", -14, FOOT + 2)

  local h = Z("row")
  w.open = Kit.Button(w, "Open WoW macros", 120, h, { onClick = OpenMacroUI })
  w.open:SetPoint("BOTTOMLEFT", S("lg"), S("md"))
  w.exportAll = Kit.Button(w, "Export all", 80, h, { onClick = function() Macros.Share.ShowExport(Macros.Existing()) end })
  w.exportAll:SetPoint("LEFT", w.open, "RIGHT", S("sm") + S("xs"), 0)
  w.import = Kit.Button(w, "Import", 64, h, { onClick = function() Macros.Share.ShowImport() end })
  w.import:SetPoint("LEFT", w.exportAll, "RIGHT", S("sm"), 0)
  w.help = Theme.Text(w, "caption", "textMuted")
  w.help:SetPoint("BOTTOMRIGHT", -14, 13)
  Legend()
  if Macros.BuildPanel then Macros.BuildPanel.Create(w, LIST_TOP) end
  w:SetScript("OnShow", function() Win.Refresh() end)
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
