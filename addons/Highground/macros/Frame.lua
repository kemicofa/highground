local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local Theme, Kit = Host.Theme, Host.Kit
local Win = Macros.Window
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- The macros window frame (WarboardMacroFrame): a Kit.Dialog with tabs,
-- the PvP / PvE switch, search, the card list, the builder and the footer. The hub borrows it
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
  local w = Kit.Dialog(Host.PREFIX .. "MacroFrame", { title = "MACROS", header = HEAD, savedKey = "macros",
    point = { "CENTER", "CENTER", 0, 40 }, width = Win.W,
    height = LIST_TOP + Win.CARDS * (Win.CARD_H + GAP) + 14 + FOOT })
  Win.win = w
  w.slots = Theme.Text(w, "label", "textMuted")
  w.slots:SetPoint("TOPRIGHT", -44, -18)
  -- PvP / PvE / ranked-spell presets, under the slot counts.
  w.modes = {}
  local x = -44
  for _, def in ipairs({ { "ranks", 54 }, { "pve", 44 }, { "pvp", 44 } }) do
    local mode = def[1]
    local t = Kit.Tab(w, mode:upper(), function() Win.SetMode(mode) end)
    t:SetWidth(def[2])
    t:SetPoint("TOPRIGHT", x, -34)
    x = x - def[2] - 6
    w.modes[mode] = t
  end

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
  Host.UpdatePlayer()
  w:Show()
  Win.Refresh()
end

function Win.Toggle()
  local w = Win.Build()
  Host.Release(w)
  if w:IsShown() then w:Hide() else Win.Open() end
end

-- /wb macros [pvp | pve | presets | build | mine | export | import | ranks]
-- (presets: the ranked-spell presets; ranks: move buttons and macros up)
Host.Command("macros", function(arg)
  if arg == "export" then return Macros.Share.ShowExport(Macros.Existing()) end
  if arg == "import" then return Macros.Share.ShowImport() end
  if arg == "presets" then arg = "ranks" elseif arg == "ranks" then return Macros.Ranks.Command() end
  if Win.MODES[arg] then
    Win.SetMode(arg)
    if Win.tab == "mine" or Win.tab == "build" then Win.tab = "class" end
  end
  Win.Open((arg == "build" or arg == "mine") and arg or nil)
end)
