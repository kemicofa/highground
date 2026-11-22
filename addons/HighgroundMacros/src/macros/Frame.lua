local _, ns = ...
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

-- Mode choices: PvP and PvE presets everywhere, ranked spells where spells
-- have ranks (Win.MODES).
local MODES_DEF = {
  { key = "pvp", label = "Players (PvP)", tooltip = "Macros for fighting other players.", width = 110 },
  { key = "pve", label = "World (PvE)", tooltip = "Macros for quests, dungeons and raids.", width = 110 },
  { key = "ranks", label = "Spell ranks", tooltip = "Macros that use your highest learned spell rank.", width = 80, ranks = true },
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
  local w = Kit.Dialog(Host.PREFIX .. "MacroFrame", { title = "MACROS", header = HEAD, savedKey = "macros",
    point = { "CENTER", "CENTER", 0, 40 }, width = Win.W,
    height = 720 })
  Win.win = w
  w.slots = Theme.Text(w, "label", "textMuted")
  local tabs = {}
  for i, def in ipairs(TABS_DEF) do tabs[i] = { key = def.key, label = def.label } end
  w.tabGroup = Kit.TabGroup(w, { items = tabs, onSelect = function(_, key) Win.SetTab(key); return true end })
  w.tabs = w.tabGroup.buttons
  -- PvP / PvE / ranked-spell presets beside the search.
  local modes = {}
  for _, def in ipairs(MODES_DEF) do
    if not def.ranks or Macros.Ranks.Supported() then
      modes[#modes + 1] = { key = def.key, label = def.label, tooltip = def.tooltip }
    end
  end
  w.modeGroup = Kit.Segmented(w, { choices = modes, value = Win.Mode(), onChange = function(_, key) Win.SetMode(key) end })
  w.modes = w.modeGroup.byKey
  w.search = Kit.Input(w, 120, "", { placeholder = "SEARCH", onChange = function()
    Win.offset = 0; Win.Refresh()
  end })

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

  w.open = Kit.Button(w, "Open WoW macros", nil, nil, { onClick = OpenMacroUI })
  w.exportAll = Kit.Button(w, "Export all", nil, nil, { onClick = function() Macros.Share.ShowExport(Macros.Existing()) end })
  w.import = Kit.Button(w, "Import", nil, nil, { onClick = function() Macros.Share.ShowImport() end })
  w.history = Kit.Button(w, "Undo changes", nil, nil, { onClick = function() Macros.Backups.Open() end })
  w.footer = Kit.Toolbar(w, { items = { w.open, w.exportAll, w.import, w.history }, gap = S("sm") })
  w.showCode = Kit.Button(w, "Show macro code", nil, nil, { onClick = function()
    Host.Set("macroShowCode", not Win.ShowCode())
    Win.Refresh()
  end })
  Kit.Tooltip(w.showCode, { "Preset code", "Show highlighted macro code on every preset card. Your choice is remembered. Changing a target updates its code preview." })
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
