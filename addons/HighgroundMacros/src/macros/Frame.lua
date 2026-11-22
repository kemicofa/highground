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

-- Mode choices: PvP and PvE presets everywhere, ranked spells where spells
-- have ranks (Win.MODES).
local MODES_DEF = {
  Localization.Define({ key = "pvp", label = Locale:Get("macros.frame.players_pvp.defba5"), tooltip = Locale:Get("macros.frame.macros_for_fighting_other_players.45edff"), width = 110 },
    { label = "macros.frame.players_pvp.defba5", tooltip = "macros.frame.macros_for_fighting_other_players.45edff" }),
  Localization.Define({ key = "pve", label = Locale:Get("macros.frame.world_pve.9a4c20"), tooltip = Locale:Get("macros.frame.macros_for_quests_dungeons_and_raids.ddc930"), width = 110 },
    { label = "macros.frame.world_pve.9a4c20", tooltip = "macros.frame.macros_for_quests_dungeons_and_raids.ddc930" }),
  Localization.Define({ key = "ranks", label = Locale:Get("macros.frame.spell_ranks.18d642"), tooltip = Locale:Get("macros.frame.macros_that_use_your_highest_learned_spell.d35634"), width = 80, ranks = true },
    { label = "macros.frame.spell_ranks.18d642", tooltip = "macros.frame.macros_that_use_your_highest_learned_spell.d35634" }),
}

-- The control that shows a page tab now: its button, or the page menu when
-- the tabs collapse at large text (guide targets).
function Win.TabTarget(key)
  local w = Win.win
  return w and w.tabGroup:Target(key)
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
  local tabsTop = compact and 10 or HEAD + 6
  Kit.Place(w.tabGroup, "TOPLEFT", w, "TOPLEFT", 18, -tabsTop, w:GetWidth() - 36, w.tabGroup:GetHeight())
  w.tabGroup:Layout()
  local toolbar = tabsTop + w.tabGroup:GetHeight() + 6
  local modesWidth = 0
  for _, def in ipairs(MODES_DEF) do
    if w.modes[def.key] then modesWidth = modesWidth + def.width * scale + 6 end
  end
  modesWidth = modesWidth - 6
  Kit.Place(w.modeGroup, "TOPRIGHT", w, "TOPRIGHT", -18, -toolbar)
  w.modeGroup:Layout(modesWidth)
  Kit.Place(w.search, "TOPLEFT", w, "TOPLEFT", 18, -toolbar,
    math.max(100, math.min(200 * scale, w:GetWidth() - modesWidth - 66)), w.modeGroup:GetHeight())
  local listTop = toolbar + w.modeGroup:GetHeight() + 12
  -- Footer: actions sized to their labels on the left, the code switch right.
  w.showCode:SetSize(Kit.LabelWidth(w.showCode, 140 * scale), math.ceil(Kit.Scale(Z("control"))))
  Kit.Place(w.showCode, "BOTTOMRIGHT", w, "BOTTOMRIGHT", -S("lg"), S("md"))
  Kit.Place(w.footer, "BOTTOMLEFT", w, "BOTTOMLEFT", S("lg"), S("md"))
  w.footer:Layout(w:GetWidth() - S("lg") * 3 - w.showCode:GetWidth())
  local rowHeight = Win.CardHeight() * scale + GAP
  Win.visibleCards = math.max(1, math.min(Win.CARDS, math.floor((w:GetHeight() - listTop - FOOT - 14) / rowHeight)))
  w.rowHeight, w.cardHeight, w.cardScale = rowHeight, Win.CardHeight() * scale, scale
  w.cardOpts.max = Win.visibleCards
  w.list:ClearAllPoints()
  w.list:SetPoint("TOPLEFT", S("lg"), -listTop)
  w.list:SetPoint("TOPRIGHT", -S("lg"), -listTop)
  w.list:SetHeight(Win.visibleCards * rowHeight)
  w.list.bar:SetValueStep(rowHeight)
  for _, row in ipairs(w.rows) do Win.LayoutCard(row, scale) end
  Kit.Place(w.empty, "TOP", w.list, "TOP", 0, -48)
  w.empty:Layout(w:GetWidth() - 64)
  local p = Macros.BuildPanel and Macros.BuildPanel.frame
  if p then -- above the footer's Open WoW macros button
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", 24, compact and -52 or -LIST_TOP - 10)
    p:SetPoint("BOTTOMRIGHT", -24, S("md") + w.open:GetHeight() + 16)
  end
end
Host.OnFontScaleChange(Win.Refresh)

-- The list snaps to whole cards: Win.offset is the first card shown.
local snapping
local function Snap(value)
  local w = Win.win
  if snapping or not (w and w.rowHeight) then return end
  local offset = math.floor(value / w.rowHeight + 0.5)
  Win.offset = offset
  if math.abs(value - offset * w.rowHeight) > 0.001 then
    snapping = true; w.list:Scroll(offset * w.rowHeight); snapping = nil
  end
  Win.ShowRange()
end

function Win.Build()
  if Win.win then return Win.win end
  local w = Localization.BindWidget(Kit.Dialog(Host.PREFIX .. "MacroFrame", { title = Locale:Get("macros.frame.macros.8ae56f"), header = HEAD, savedKey = "macros",
    point = { "CENTER", "CENTER", 0, 40 }, width = Win.W,
    height = 720 }), { title = "macros.frame.macros.8ae56f" })
  Win.win = w
  w.slots = Theme.Text(w, "label", "textMuted")
  -- The declared tables themselves: their labels update in place, so the
  -- tabs and modes relabel after a language change.
  w.tabGroup = Kit.TabGroup(w, { items = TABS_DEF, onSelect = function(_, key) Win.SetTab(key); return true end })
  w.tabs = w.tabGroup.buttons
  -- PvP / PvE / ranked-spell presets beside the search.
  local modes = {}
  for _, def in ipairs(MODES_DEF) do
    if not def.ranks or Macros.Ranks.Supported() then
      modes[#modes + 1] = def
    end
  end
  w.modeGroup = Kit.Segmented(w, { choices = modes, value = Win.Mode(), onChange = function(_, key) Win.SetMode(key) end })
  w.modes = w.modeGroup.byKey
  w.search = Localization.BindWidget(Kit.Input(w, 120, "", { placeholder = Locale:Get("macros.frame.search.a62a7a"), onChange = function()
    Win.offset = 0; Win.Refresh()
  end }), { hint = "macros.frame.search.a62a7a" })

  -- Presets as recycled cards: only the visible ones exist (Kit.VirtualList).
  w.list = Kit.ScrollArea(w)
  w.list.onScroll = Snap
  w.cardOpts = { gap = GAP, max = Win.CARDS, rowHeight = function() return w.cardHeight or Win.CARD_H end,
    create = function(body)
      local r = Win.NewCard(body)
      Win.LayoutCard(r, w.cardScale or 1)
      return r
    end,
    render = function(r, e) Win.Fill(r, e) end }
  w.cards = Kit.VirtualList(w.list, w.cardOpts)
  w.rows = w.cards.rows
  w.list.view:SetScript("OnMouseWheel", function(_, delta) Win.Scroll(delta) end)
  pcall(w.EnableMouseWheel, w, true)
  w:SetScript("OnMouseWheel", function(_, delta) Win.Scroll(delta) end)
  w.empty = Kit.EmptyState(w, {})
  w.range = Theme.Text(w, "caption", "textMuted")
  w.range:SetPoint("BOTTOMRIGHT", -14, FOOT + 2)

  w.open = Localization.Bind(Kit.Button(w, Locale:Get("macros.frame.open_wow_macros.94c506"), nil, nil, { onClick = OpenMacroUI }), "macros.frame.open_wow_macros.94c506")
  w.exportAll = Localization.Bind(Kit.Button(w, Locale:Get("macros.frame.export_all.f146c7"), nil, nil, { onClick = function() Macros.Share.ShowExport(Macros.Existing()) end }), "macros.frame.export_all.f146c7")
  w.import = Localization.Bind(Kit.Button(w, Locale:Get("highground.root.import.d6fbc9"), nil, nil, { onClick = function() Macros.Share.ShowImport() end }), "highground.root.import.d6fbc9")
  w.history = Localization.Bind(Kit.Button(w, Locale:Get("macros.frame.undo_changes.6f5e31"), nil, nil, { onClick = function() Macros.Backups.Open() end }), "macros.frame.undo_changes.6f5e31")
  w.footer = Kit.Toolbar(w, { items = { w.open, w.exportAll, w.import, w.history }, gap = S("sm"), fitHeight = true })
  w.showCode = Localization.Bind(Kit.Button(w, Locale:Get("macros.frame.show_macro_code.2c34b1"), nil, nil, { onClick = function()
    Host.Set("macroShowCode", not Win.ShowCode())
    Win.Refresh()
  end }), "macros.frame.show_macro_code.2c34b1")
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
