local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local Theme, Kit = Host.Theme, Host.Kit
local Win = Macros.Window
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- The macros window frame (<PREFIX>MacroFrame): a Kit.Dialog with tabs,
-- the PVP / PVE / RANKS switch, search, the card list, the builder and
-- the footer. The Highground window borrows it (hub/Hub.lua), hiding its
-- close button meanwhile.
---------------------------------------------------------------------------
local HEAD, TABS, FOOT = 64, 76, 76
local LIST_TOP = HEAD + TABS + 6
local GAP = 4 -- between cards
local TABS_DEF = {
  { key = "class", label = "For my class" },
  { key = "mine", label = "My macros" },
  { key = "general", label = "Utility" },
  { key = "all", label = "All classes" },
  { key = "build", label = "Create" },
}

local function OpenMacroUI()
  if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_MacroUI")
  elseif LoadAddOn then pcall(LoadAddOn, "Blizzard_MacroUI") end
  if ShowMacroFrame then pcall(ShowMacroFrame) end
end

-- The hub already names this page. Reclaim the duplicated header while
-- composing, but keep it in the standalone window and preset browser.
function Win.Layout()
  local w = Win.win
  if not w then return end
  local compact = Win.tab == "build" and not w:IsMovable()
  local scale = math.max(1, Host.FontScale())
  w.slots:SetShown(Win.tab == "mine")
  w.headerRight = Win.tab == "mine" and w.slots or nil
  w.LayoutHeader()
  for _, region in ipairs({ w.title, w.sub, w.head, w.bar, w.rule }) do region:SetShown(not compact) end
  for i, def in ipairs(TABS_DEF) do
    local tab = w.tabs[def.key]
    local width = (w:GetWidth() - 36 - 16) / #TABS_DEF
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", 18 + (i - 1) * (width + 4), compact and -10 or -HEAD - 6)
    tab:SetSize(width, 26 * math.min(scale, 1.25))
  end
  local toolbar = HEAD + 42 + (scale - 1) * 12
  w.search:ClearAllPoints(); w.search:SetPoint("TOPLEFT", 18, -toolbar)
  w.search:SetSize(200 * scale, 26 * scale)
  local x = -18
  for _, def in ipairs({ { "ranks", 80 }, { "pve", 110 }, { "pvp", 110 } }) do
    local t = w.modes[def[1]]
    t:ClearAllPoints(); t:SetPoint("TOPRIGHT", x, -toolbar)
    t:SetSize(def[2] * scale, 26 * scale)
    if def[1] ~= "ranks" or Macros.Ranks.Supported() then x = x - def[2] * scale - 6 end
  end
  w.search:SetWidth(math.max(100, math.min(200 * scale, w:GetWidth() + x - 30)))
  local listTop = toolbar + 38 * scale
  local previous
  for _, def in ipairs({ { w.open, 150 }, { w.exportAll, 80 }, { w.import, 64 }, { w.history, 100 } }) do
    local button = def[1]
    if button then
      button:SetSize(def[2] * scale, Z("row") * math.min(scale, 1.25))
      button:ClearAllPoints()
      if previous then button:SetPoint("LEFT", previous, "RIGHT", 8, 0)
      else button:SetPoint("BOTTOMLEFT", S("lg"), S("md")) end
      if button == w.open or button == w.history or Win.tab == "mine" then previous = button end
    end
  end
  w.showCode:SetSize(140 * scale, Z("row") * math.min(scale, 1.25))
  local rowHeight = Win.CardHeight() * scale + GAP
  Win.visibleCards = math.max(1, math.min(Win.CARDS, math.floor((w:GetHeight() - listTop - FOOT - 14) / rowHeight)))
  for i, row in ipairs(w.rows) do
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", S("lg"), -listTop - (i - 1) * rowHeight)
    row:SetPoint("RIGHT", w, "RIGHT", -S("lg"), 0)
    Win.LayoutCard(row, scale)
  end
  local p = Macros.BuildPanel and Macros.BuildPanel.frame
  if p then
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", 24, compact and -52 or -LIST_TOP - 10)
    p:SetPoint("BOTTOMRIGHT", -24, 24)
  end
end
Host.OnFontScaleChange(Win.Refresh)

function Win.Build()
  if Win.win then return Win.win end
  local w = Kit.Dialog(Host.PREFIX .. "MacroFrame", { title = "MACROS", header = HEAD, savedKey = "macros",
    point = { "CENTER", "CENTER", 0, 40 }, width = Win.W,
    height = 720 })
  Win.win = w
  w.slots = Theme.Text(w, "label", "textMuted")
  w.slots:SetPoint("TOPRIGHT", -44, -18)
  -- PvP / PvE / ranked-spell presets, under the slot counts.
  w.modes = {}
  local x = -44
  for _, def in ipairs({ { "ranks", 54 }, { "pve", 44 }, { "pvp", 44 } }) do
    local mode = def[1]
    local label = ({ pvp = "Players (PvP)", pve = "World (PvE)", ranks = "Spell ranks" })[mode]
    local t = Kit.Tab(w, label, function() Win.SetMode(mode) end)
    Kit.Tooltip(t, { label, mode == "pvp" and "Macros for fighting other players."
      or mode == "pve" and "Macros for quests, dungeons and raids." or "Macros that use your highest learned spell rank." })
    t:SetWidth(def[2])
    t:SetPoint("TOPRIGHT", x, -34)
    x = x - def[2] - 6
    w.modes[mode] = t
  end

  w.tabs = {}
  for i, def in ipairs(TABS_DEF) do
    local t = Kit.Tab(w, def.label, function() Win.SetTab(def.key) end)
    t:SetWidth(def.key == "build" and 120 or 100)
    t:SetPoint("TOPLEFT", 18 + (i - 1) * 104, -HEAD - 6)
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
  w:SetScript("OnMouseWheel", function(_, delta) Win.Scroll(delta) end)
  w.empty = Theme.Text(w, "rowName", "textMuted")
  w.empty:SetPoint("TOPLEFT", 32, -LIST_TOP - 80); w.empty:SetPoint("RIGHT", -32, 0)
  w.empty:SetJustifyH("CENTER"); w.empty:SetWordWrap(true)
  w.range = Theme.Text(w, "caption", "textMuted")
  w.range:SetPoint("BOTTOMRIGHT", -14, FOOT + 2)

  local h = Z("row")
  w.open = Kit.Button(w, "Open WoW macros", 120, h, { onClick = OpenMacroUI })
  w.open:SetPoint("BOTTOMLEFT", S("lg"), S("md"))
  w.exportAll = Kit.Button(w, "Export all", 80, h, { onClick = function() Macros.Share.ShowExport(Macros.Existing()) end })
  w.exportAll:SetPoint("LEFT", w.open, "RIGHT", S("sm") + S("xs"), 0)
  w.import = Kit.Button(w, "Import", 64, h, { onClick = function() Macros.Share.ShowImport() end })
  w.import:SetPoint("LEFT", w.exportAll, "RIGHT", S("sm"), 0)
  w.history = Kit.Button(w, "Undo changes", 100, h, { onClick = function() Macros.Backups.Open() end })
  w.history:SetPoint("LEFT", w.import, "RIGHT", S("sm"), 0)
  w.showCode = Kit.Button(w, "Show macro code", 140, h, { onClick = function()
    Host.Set("macroShowCode", not Win.ShowCode())
    Win.Refresh()
  end })
  w.showCode:SetPoint("BOTTOMRIGHT", -S("lg"), S("md"))
  Kit.Tooltip(w.showCode, { "Preset code", "Show highlighted macro code on every preset card. Your choice is remembered. Changing a target updates its code preview." })
  w.help = Theme.Text(w, "body", "textMuted")
  w.help:SetPoint("BOTTOMLEFT", 14, 42); w.help:SetPoint("RIGHT", -14, 0)
  w.help:SetHeight(32); w.help:SetJustifyH("LEFT"); w.help:SetWordWrap(true)
  if Macros.BuildPanel then Macros.BuildPanel.Create(w, LIST_TOP) end
  w:SetScript("OnShow", function() Win.Refresh() end)
  w:SetScript("OnSizeChanged", function() Win.Refresh() end)
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

-- /hg macros [pvp | pve | presets | build | mine | export | import | ranks]
-- (presets: the ranked-spell presets; ranks: move buttons and macros up).
-- Highground Macros routes /hgm [arg] here (its Main.lua).
Host.Command("macros", function(arg)
  if arg == "history" then return Macros.Backups.Open() end
  if arg == "export" then return Macros.Share.ShowExport(Macros.Existing()) end
  if arg == "import" then return Macros.Share.ShowImport() end
  if arg == "presets" then arg = "ranks" elseif arg == "ranks" then return Macros.Ranks.Command() end
  if Win.MODES[arg] then
    Win.SetMode(arg)
    if Win.tab == "mine" or Win.tab == "build" then Win.tab = "class" end
  end
  Win.Open((arg == "build" or arg == "mine") and arg or nil)
end)
