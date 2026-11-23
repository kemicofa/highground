local _, ns = ...

---------------------------------------------------------------------------
-- Highground: obsidian steel, luminous gold and cool edge light. Class surfaces
-- identify players; labelled tactical signals stay independent of the brand.
-- Colours are sRGB, alpha is explicit. The shipped palettes are checked
-- against their composited surfaces by the accessibility simulations.
---------------------------------------------------------------------------
function ns.ThemeColor(hex, alpha)
  return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
    tonumber(hex:sub(5, 6), 16) / 255, alpha }
end
local C = ns.ThemeColor

ns.Themes = {
  highground = ns.Localization.Define({
    label = "Highground",
    description = ns.Locale:Get("shared.theme.obsidian_steel_luminous_gold_sculpted_borders_and.0cb03e"),
    color = {
      -- Surfaces: wells, panel, cards, raised controls.
      bg = C("080e19"),
      surface = C("111f30"),
      surfaceRaised = C("1b3148"),
      well = C("040912"),
      chipBg = C("050c16"), -- opaque: status ink is isolated from health fills
      border = C("3b5068"), -- decorative dividers
      borderAccent = C("b58a44"),
      metalEdge = C("b58a44"),
      metalHighlight = C("ffe5ac"),
      metalShadow = C("050c16"),
      attackEdge = C("ff626a"),
      controlBorder = C("7c91b0"), -- meaningful field / checkbox boundary
      focus = C("82b8f4"),
      overlaySubtle = C("ffffff", 0.025),
      overlayHover = C("ffffff", 0.045),
      overlaySelected = C("f4bb48", 0.12),
      overlayStrong = C("ffffff", 0.07),
      shadow = C("000000", 0.55),
      black = C("000000"),
      white = C("ffffff"),
      -- Text: dim is still readable; disabled opacity is a separate state.
      text = C("f4ebd8"),
      titleText = C("ffe3a0"),
      textMuted = C("bbc9dd"),
      textDim = C("a8b8cd"),
      onAccent = C("07111f"),
      -- Readable tactical ink; attackEdge is the brighter, non-text cue.
      accent = C("f4bb48"),
      gold = C("ffd978"),
      moneyGold = C("ffd45f"),
      moneySilver = C("c7c7cf"),
      moneyCopper = C("dc9c68"),
      success = C("9dd9ab"),
      warning = C("ffc47f"),
      pending = C("edbda0"),
      danger = C("ff9a9f"),
      kill = C("ff9a9f"),
      info = C("82b8f4"),
      brand = C("f4bb48"),
      bounty = C("ffd978"),
      -- Wanted posters keep paper and ink together in every palette.
      posterPaper = C("e4c994"),
      posterInset = C("d4b57b"),
      posterInk = C("352419"),
      posterMuted = C("654b31"),
      posterEdge = C("8c683d"),
      posterStamp = C("862e23"),
      posterWell = C("30271e"),
      error = C("ff9a9f"),
      factionA = C("82b8f4"),
      factionH = C("ff9a9f"),
      scopeGeneral = C("f4bb48"),
      scopeCharacter = C("cbb8ef"),
      healer = C("83e8a2"),
      healerEnemy = C("f26b6b"),
      chipImmune = C("ff9a9f"),
      chipDef = C("ffd978"),
      chipCc = C("82b8f4"),
      chipStun = C("ffc47f"),
      chipCarrier = C("cbb8ef"),
      chipSpent = C("9dd9ab"),
      chipBurst = C("ff9a9f"),
      chipPurge = C("99dce6"),
      -- World overlays always retain bright ink and a dark backing,
      -- including in Parchment. They do not sit on the panel palette.
      hudText = C("f4ebd8"),
      hudBg = C("07111f"),
      hudGold = C("ffd978"),
      hudWarning = C("ffc47f"),
      hudDanger = C("ff9a9f"),
      capPlate = C("ffc47f"),
      capPlateAlly = C("82b8f4"),
      mapMark = C("ffc47f"),
      mapLabel = C("bbc9dd"),
      -- Enemy map circles: the theme's hue, light enough for any map art.
      mapZone = C("f4bb48"),
      dead = C("a8b8cd"),
      -- The default "theme" marker ring. Colour themes give it their hue.
      sniperTheme = C("ffd36b"),
      -- Player-selected scope colours are identical in all themes.
      sniperMagenta = { 1, 0.15, 0.85 },
      sniperGold = C("ffd36b"),
      sniperBone = C("fff0cf"),
      sniperAim = C("ff454f"),
      sniperCyan = { 0.1, 0.95, 1 },
      sniperYellow = { 1, 0.95, 0.1 },
      sniperLime = { 0.55, 1, 0.1 },
      sniperOrange = { 1, 0.45, 0.05 },
    },
    -- Barlow for prose and labels, tabular JetBrains Mono for data.
    -- No role below 10px at 100% text size. All themes keep these sizes.
    type = {
      caption = { "semi", 10 },
      captionOutline = { "mono", 10, "OUTLINE" },
      label = { "mono", 10 },
      labelOutline = { "mono", 10, "OUTLINE" },
      code = { "mono", 11 },
      codeLarge = { "mono", 11 },
      timerSmall = { "mono", 11 },
      stat = { "mono", 12 },
      figure = { "mono", 13 },
      figureLarge = { "mono", 14 },
      readoutSmall = { "mono", 15 },
      timer = { "mono", 16 },
      badgeCount = { "mono", 16, "OUTLINE" },
      readout = { "mono", 24 },
      note = { "medium", 11 },
      body = { "medium", 12 },
      bodySmall = { "medium", 12 },
      bodyLarge = { "medium", 14 },
      detailSmall = { "semi", 11 },
      detail = { "semi", 12 },
      badgeLabel = { "semi", 11, "OUTLINE" },
      control = { "semi", 13 },
      input = { "semi", 14 },
      rowNameSmall = { "semi", 14 },
      rowName = { "semi", 15 },
      rowNameLarge = { "semi", 16 },
      headingSmall = { "bold", 11 },
      titleSmall = { "friz", 12 },
      heading = { "bold", 13 },
      cardName = { "bold", 15 },
      title = { "friz", 16 },
      cardTitle = { "bold", 17 },
      number = { "bold", 22 },
      display = { "friz", 24 },
      displayLarge = { "bold", 26 },
      posterTitle = { "friz", 22 },
      posterName = { "friz", 20 },
      posterReward = { "bold", 28 },
    },
    space = { xs = 2, sm = 4, md = 8, lg = 12, xl = 16 },
    -- Seconds: quick feedback, a little more time to orient to new content.
    motion = { press = 0.06, hover = 0.12, focus = 0.14, select = 0.16, enter = 0.24,
      menu = 0.20, page = 0.20, expand = 0.24, exit = 0.10, sweep = 0.72, pulse = 1.4,
      flash = 0.9, pop = 0.30, slide = 0.18, progress = 0.20 },
    size = {
      control = 24, controlRadius = 5, input = 26, header = 56, tab = 28, tabWidth = 84, accentBar = 3,
      close = 26, chip = 16, toggle = 16, row = 24, icon = 16, portrait = 32,
      strip = 3, line = 1, underline = 2, scrollbar = 3, chipWidth = 62, headerSmall = 40,
      -- Choice rows and their indicator box; scroll area gutter, hit strip and thumb.
      choice = 32, choiceBox = 12, scrollGutter = 16, scrollHit = 10, scrollThumb = 8, scrollThumbMin = 24,
    },
    -- Solid reading surfaces are deliberate. Only small decorative layers
    -- use transparency. Player-selected HUD opacity still takes precedence.
    alpha = { button = 1, card = 1, dialog = 1, menu = 1, chip = 0.10, chipEdge = 0.5, bar = 0.65, band = 0.04,
      disabled = 0.55, panelCog = 0.25, zebraEven = 0.02, zebraOdd = 0.035, row = 1, page = 1,
      healthFill = 0.08, healthUnseen = 0.04, classRow = 0.40, topTint = 0.025, bevelLight = 0.08, bevelShade = 0.35,
      ornament = 0.9, crest = 1, healthLine = 0.85, healthLineUnseen = 0.28,
      glow = 0.32, elevation = 0.55, sheen = 0.08, headerLight = 0.09, edgeLight = 0.8,
      enter = 0.88, menuEnter = 0, pageEnter = 0.94, markEnter = 0.55, flash = 0.14 },
  }, { description = "shared.theme.obsidian_steel_luminous_gold_sculpted_borders_and.0cb03e" }),
}

local function Copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = type(v) == "table" and Copy(v) or v end
  return out
end

-- Resolve shipped palettes once. Each gets independent, complete tables;
-- shared typography, geometry and semantic colours cannot silently drift.
function ns.DefineTheme(name, definition)
  local theme = Copy(ns.Themes.highground)
  for key, value in pairs(definition) do
    if type(value) == "table" and type(theme[key]) == "table" then
      for token, v in pairs(value) do theme[key][token] = type(v) == "table" and Copy(v) or v end
    else
      theme[key] = value
    end
  end
  ns.Themes[name] = theme
end

-- Stable live tables: references kept by the UI survive a theme switch.
ns.DEFAULT_THEME = "highground"
ns.ThemeTokens = Copy(ns.Themes.highground)
ns.ThemeTokens.name = "highground"
