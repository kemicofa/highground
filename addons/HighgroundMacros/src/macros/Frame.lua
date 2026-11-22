local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
local Macros = ns.Macros
local Host = Macros.Host
local Theme, Kit = Host.Theme, Host.Kit
local Win = Macros.Window
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- The macros window frame (<PREFIX>MacroFrame): a Kit.Dialog with tabs,
-- the PVP / PVE / RANKS switch, search, the card list, the builder and
-- the footer. Highground configuration launches this separate window;
-- the editor keeps its own close button, navigation and saved position.
---------------------------------------------------------------------------
local HEAD, TABS, FOOT = 64, 76, 76
local LIST_TOP = HEAD + TABS + 6
local GAP = 4 -- between cards
local TABS_DEF = {
  Localization.Define({ key = "class", label = Locale:Get("macros.frame.for_my_class.db3adc") }, { label = "macros.frame.for_my_class.db3adc" }),
  Localization.Define({ key = "mine", label = Locale:Get("macros.frame.my_macros.20710c") }, { label = "macros.frame.my_macros.20710c" }),
  Localization.Define({ key = "general", label = Locale:Get("macros.frame.utility.891895") }, { label = "macros.frame.utility.891895" }),
  Localization.Define({ key = "all", label = Locale:Get("highground.tracking.all_classes.341576") }, { label = "highground.tracking.all_classes.341576" }),
  Localization.Define({ key = "build", label = Locale:Get("macros.frame.create.6e157c") }, { label = "macros.frame.create.6e157c" }),
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
  w.header:SetActions(Win.tab == "mine" and { w.slots } or nil)
  w.header:SetShown(not compact)
  for _, region in ipairs({ w.title, w.sub, w.head, w.bar, w.rule }) do region:SetShown(not compact) end
  Kit.LayoutGrid(w.tabList, { width = w:GetWidth() - 36, columns = #TABS_DEF, gap = 4,
    height = 26 * math.min(scale, 1.25), x = 18, y = compact and -10 or -HEAD - 6 })
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
  w.rowHeight = rowHeight
  w.list:ClearAllPoints()
  w.list:SetPoint("TOPLEFT", S("lg"), -listTop)
  w.list:SetPoint("TOPRIGHT", -S("lg"), -listTop)
  w.list:SetHeight(Win.visibleCards * rowHeight)
  w.list.bar:SetValueStep(rowHeight)
  for _, row in ipairs(w.rows) do Win.LayoutCard(row, scale) end
  local p = Macros.BuildPanel and Macros.BuildPanel.frame
  if p then -- above the footer's Open WoW macros button
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", 24, compact and -52 or -LIST_TOP - 10)
    p:SetPoint("BOTTOMRIGHT", -24, S("md") + w.open:GetHeight() + 16)
  end
end
Host.OnFontScaleChange(Win.Refresh)

function Win.Build()
  if Win.win then return Win.win end
  local w = Localization.BindWidget(Kit.Dialog(Host.PREFIX .. "MacroFrame", { title = Locale:Get("macros.frame.macros.8ae56f"), header = HEAD, savedKey = "macros",
    point = { "CENTER", "CENTER", 0, 40 }, width = Win.W,
    height = 720 }), { title = "macros.frame.macros.8ae56f" })
  Win.win = w
  w.slots = Theme.Text(w, "label", "textMuted")
  -- PvP / PvE / ranked-spell presets, under the slot counts.
  w.modes = {}
  local x = -44
  for _, def in ipairs({ { "ranks", 54 }, { "pve", 44 }, { "pvp", 44 } }) do
    local mode = def[1]
    local label = ({ pvp = Locale:Get("macros.frame.players_pvp.defba5"), pve = Locale:Get("macros.frame.world_pve.9a4c20"), ranks = Locale:Get("macros.frame.spell_ranks.18d642") })[mode]
    local t = Kit.Tab(w, label, function() Win.SetMode(mode) end)
    Kit.Tooltip(t, function() return { label, mode == "pvp" and Locale:Get("macros.frame.macros_for_fighting_other_players.45edff")
      or mode == "pve" and Locale:Get("macros.frame.macros_for_quests_dungeons_and_raids.ddc930") or Locale:Get("macros.frame.macros_that_use_your_highest_learned_spell.d35634") } end)
    t:SetWidth(def[2])
    t:SetPoint("TOPRIGHT", x, -34)
    x = x - def[2] - 6
    w.modes[mode] = t
  end

  w.tabs, w.tabList = {}, {}
  for i, def in ipairs(TABS_DEF) do
    local t = Kit.Tab(w, def.label, function() Win.SetTab(def.key) end)
    t:SetWidth(def.key == "build" and 120 or 100)
    t:SetPoint("TOPLEFT", 18 + (i - 1) * 104, -HEAD - 6)
    w.tabs[def.key] = t
    w.tabList[i] = t
  end
  w.search = Localization.BindWidget(Kit.Input(w, 120, "", { placeholder = Locale:Get("macros.frame.search.a62a7a"), onChange = function()
    Win.offset = 0; Win.Refresh()
  end }), { hint = "macros.frame.search.a62a7a" })
  w.search:SetPoint("TOPRIGHT", -14, -HEAD - S("md"))

  w.list = Kit.ScrollArea(w)
  w.rows = {}
  for i = 1, Win.CARDS do w.rows[i] = Win.NewCard(w.list.body) end
  w.list.onScroll = function(value)
    if w.refreshing or not w.rowHeight then return end
    local offset = math.floor(value / w.rowHeight + 0.5)
    if offset ~= Win.offset or value ~= offset * w.rowHeight then
      Win.offset = offset
      Win.Refresh()
    end
  end
  w.list.view:SetScript("OnMouseWheel", function(_, delta) Win.Scroll(delta) end)
  pcall(w.EnableMouseWheel, w, true)
  w:SetScript("OnMouseWheel", function(_, delta) Win.Scroll(delta) end)
  w.empty = Theme.Text(w, "rowName", "textMuted")
  w.empty:SetPoint("TOPLEFT", 32, -LIST_TOP - 80); w.empty:SetPoint("RIGHT", -32, 0)
  w.empty:SetJustifyH("CENTER"); w.empty:SetWordWrap(true)
  w.range = Theme.Text(w, "caption", "textMuted")
  w.range:SetPoint("BOTTOMRIGHT", -14, FOOT + 2)

  local h = Z("row")
  w.open = Localization.Bind(Kit.Button(w, Locale:Get("macros.frame.open_wow_macros.94c506"), 120, h, { onClick = OpenMacroUI }), "macros.frame.open_wow_macros.94c506")
  w.open:SetPoint("BOTTOMLEFT", S("lg"), S("md"))
  w.exportAll = Localization.Bind(Kit.Button(w, Locale:Get("macros.frame.export_all.f146c7"), 80, h, { onClick = function() Macros.Share.ShowExport(Macros.Existing()) end }), "macros.frame.export_all.f146c7")
  w.exportAll:SetPoint("LEFT", w.open, "RIGHT", S("sm") + S("xs"), 0)
  w.import = Localization.Bind(Kit.Button(w, Locale:Get("highground.root.import.d6fbc9"), 64, h, { onClick = function() Macros.Share.ShowImport() end }), "highground.root.import.d6fbc9")
  w.import:SetPoint("LEFT", w.exportAll, "RIGHT", S("sm"), 0)
  w.history = Localization.Bind(Kit.Button(w, Locale:Get("macros.frame.undo_changes.6f5e31"), 100, h, { onClick = function() Macros.Backups.Open() end }), "macros.frame.undo_changes.6f5e31")
  w.history:SetPoint("LEFT", w.import, "RIGHT", S("sm"), 0)
  w.showCode = Localization.Bind(Kit.Button(w, Locale:Get("macros.frame.show_macro_code.2c34b1"), 140, h, { onClick = function()
    Host.Set("macroShowCode", not Win.ShowCode())
    Win.Refresh()
  end }), "macros.frame.show_macro_code.2c34b1")
  w.showCode:SetPoint("BOTTOMRIGHT", -S("lg"), S("md"))
  Kit.Tooltip(w.showCode, function() return { Locale:Get("macros.frame.preset_code.39e462"), Locale:Get("macros.frame.show_highlighted_macro_code_on_every_preset.e76426") } end)
  w.help = Theme.Text(w, "body", "textMuted")
  w.help:SetPoint("BOTTOMLEFT", 14, 42); w.help:SetPoint("RIGHT", -14, 0)
  w.help:SetHeight(32); w.help:SetJustifyH("LEFT"); w.help:SetWordWrap(true)
  if Macros.BuildPanel then Macros.BuildPanel.Create(w, LIST_TOP) end
  w:SetScript("OnShow", function() Win.Refresh() end)
  w:SetScript("OnSizeChanged", function() Win.Refresh() end)
  Win.AttachRoutes(w)
  return w
end

function Win.Open(tab)
  if Host.Require and not Host.Require() then return end
  local w = Win.Build()
  if tab then Win.SetTab(tab) end
  Host.UpdatePlayer()
  Kit.Windows.Show(w)
  Win.Refresh()
end

function Win.Toggle()
  if Host.Require and not Host.Require() then return end
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
    Win.Navigate((Win.tab == "mine" or Win.tab == "build") and "class" or Win.tab, arg)
  end
  Win.Open((arg == "build" or arg == "mine") and arg or nil)
end)
