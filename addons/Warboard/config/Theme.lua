local _, ns = ...

---------------------------------------------------------------------------
-- Design tokens. Every colour, type role and spacing used by the UI is
-- named here; code asks for a name (ui/Theme.lua), never a number.
--   color: { r, g, b[, a] }   type: { face, size[, flags] }
--   space / size: pixels
-- A theme may set only some tokens: the rest come from "warboard". The
-- themes shipped with Warboard (config/themes/) set every token.
-- darkFrames: for a light theme, the theme whose colours are used on
-- Blizzard's dark frames (tooltips, chat): Theme.TipColor, Theme.TipHex.
-- Theme files are the only files with numeric colours or |cff codes
-- (tests/validate.py).
---------------------------------------------------------------------------
ns.Themes = {
  warboard = {
    label = "Warboard",
    color = {
      -- Surfaces
      bg = { 0.025, 0.043, 0.067 }, -- panel and dialog fill
      surface = { 0.07, 0.10, 0.145 }, -- header bands, rows, buttons
      surfaceRaised = { 0.10, 0.14, 0.20 },
      border = { 0.19, 0.26, 0.34 },
      borderAccent = { 0.15, 0.51, 0.48 }, -- dialog edge (accent, dimmed)
      well = { 0, 0, 0, 0.35 }, -- sunken text areas
      overlaySubtle = { 1, 1, 1, 0.04 }, -- card hover
      overlayHover = { 1, 1, 1, 0.08 },
      overlaySelected = { 1, 1, 1, 0.12 },
      overlayStrong = { 1, 1, 1, 0.15 }, -- chip backing
      shadow = { 0, 0, 0, 0.85 }, -- text shadow
      black = { 0, 0, 0 }, -- Border colour choices
      white = { 1, 1, 1 },
      -- Text
      text = { 0.94, 0.97, 1 },
      textMuted = { 0.58, 0.67, 0.76 },
      textDim = { 0.4, 0.45, 0.5 },
      onAccent = { 0.05, 0.05, 0.06 }, -- text on accent or gold fills
      -- Signals
      accent = { 0.25, 0.85, 0.80 },
      gold = { 1, 0.82, 0.1 },
      success = { 0.4, 0.9, 0.55 },
      warning = { 1, 0.72, 0.28 },
      pending = { 1, 0.62, 0.2 },
      danger = { 1, 0.32, 0.35 },
      kill = { 1, 0.15, 0.1 }, -- kill / execute red
      info = { 0.45, 0.72, 1 },
      -- Chat (ns.Util.Say)
      brand = { 1, 0.333, 0.2 }, -- Warboard chat prefix
      bounty = { 1, 0.82, 0.1 },
      error = { 1, 0.333, 0.333 },
      -- Game
      factionA = { 0.35, 0.8, 1 },
      factionH = { 1, 0.32, 0.3 },
      scopeGeneral = { 0.13, 0.55, 0.52 },
      scopeCharacter = { 0.5, 0.36, 0.85 },
      healer = { 0.2, 1, 0.35 },
      -- Status chips (Core.PIP)
      chipImmune = { 1, 0.4, 0.35 },
      chipDef = { 1, 0.78, 0.3 },
      chipCc = { 0.45, 0.72, 1 },
      chipStun = { 1, 0.64, 0.25 },
      chipCarrier = { 0.78, 0.56, 1 },
      chipSpent = { 0.4, 0.9, 0.6 },
      chipBurst = { 1, 0.32, 0.35 },
      chipPurge = { 0.3, 0.85, 1 },
      -- World overlays (nameplates, world map)
      hudText = { 0.94, 0.97, 1 }, -- text over the game world
      hudBg = { 0.025, 0.043, 0.067 }, -- badge fill over the world
      hudGold = { 1, 0.82, 0.1 }, -- bounty nameplate mark
      hudWarning = { 1, 0.72, 0.28 }, -- pressure badge
      hudDanger = { 1, 0.32, 0.35 }, -- pressure badge, urgent
      capPlate = { 1, 0.55, 0.1 }, -- enemy capping
      capPlateAlly = { 0.3, 0.7, 1 }, -- teammate capping
      mapMark = { 1, 0.42, 0.12 }, -- kill-target ring and test pin
      mapLabel = { 0.75, 0.75, 0.8 }, -- pin age labels
      dead = { 0.5, 0.5, 0.5 }, -- dead enemies instead of the class colour
      -- Sniper scope choices (/wb sniper color): a player pick, not styled
      -- per theme, so every theme keeps these.
      sniperMagenta = { 1, 0.15, 0.85 },
      sniperCyan = { 0.1, 0.95, 1 },
      sniperYellow = { 1, 0.95, 0.1 },
      sniperLime = { 0.55, 1, 0.1 },
      sniperOrange = { 1, 0.45, 0.05 },
    },
    -- Faces: bold, semi, medium (Barlow Condensed), mono (JetBrains Mono),
    -- friz (Friz Quadrata, the game's own). Flags: "OUTLINE" etc.
    type = {
      caption = { "mono", 8 },
      captionOutline = { "mono", 8, "OUTLINE" }, -- compact trinket timer
      label = { "mono", 9 },
      labelOutline = { "mono", 9, "OUTLINE" }, -- trinket timer over its icon
      code = { "mono", 10 },
      codeLarge = { "mono", 11 }, -- macro builder text
      timerSmall = { "mono", 11 }, -- compact clocks, nearby distances
      stat = { "mono", 12 }, -- arena right column
      figure = { "mono", 13 }, -- enemy rank
      figureLarge = { "mono", 14 }, -- enemy health %
      readoutSmall = { "mono", 15 }, -- compact kill-target distance
      timer = { "mono", 16 }, -- battleground clocks
      badgeCount = { "mono", 16, "OUTLINE" }, -- pressure shield count
      readout = { "mono", 24 }, -- kill-target distance
      note = { "medium", 10 },
      body = { "medium", 11 },
      bodySmall = { "medium", 12 },
      bodyLarge = { "medium", 13 },
      detailSmall = { "semi", 10 },
      detail = { "semi", 11 },
      badgeLabel = { "semi", 11, "OUTLINE" }, -- pressure shield caption
      control = { "semi", 12 },
      input = { "semi", 13 },
      rowNameSmall = { "semi", 14 }, -- battleground timer place
      rowName = { "semi", 15 },
      rowNameLarge = { "semi", 16 }, -- carrier and arena names
      headingSmall = { "bold", 10 },
      titleSmall = { "bold", 12 },
      heading = { "bold", 13 },
      cardName = { "bold", 15 }, -- macro cards, compact kill target
      title = { "bold", 16 },
      cardTitle = { "bold", 17 },
      number = { "bold", 22 },
      display = { "bold", 24 },
      displayLarge = { "bold", 26 }, -- bounty purse
    },
    space = { xs = 2, sm = 4, md = 8, lg = 12, xl = 16 },
    size = {
      control = 22, input = 24, header = 56, tab = 26, tabWidth = 84, accentBar = 4,
      close = 24, chip = 15, toggle = 14, row = 20, icon = 16, portrait = 32,
      strip = 3, line = 1, underline = 2, scrollbar = 2, chipWidth = 62, headerSmall = 40,
    },
    -- Alpha of fills that are not tokens of their own.
    -- page: settings page fill (0: the settings panel shows through).
    alpha = { button = 0.9, card = 0.85, dialog = 0.97, menu = 0.98, chip = 0.16, bar = 0.6, band = 0.06,
      disabled = 0.45, zebraEven = 0.055, zebraOdd = 0.09, row = 0.9, page = 0 },
  },
}

-- Active tokens: stable tables updated in place by Theme.Use (ui/Theme.lua),
-- so a colour table kept at load time follows a theme switch.
local function Copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = type(v) == "table" and Copy(v) or v end
  return out
end
ns.ThemeTokens = Copy(ns.Themes.warboard)
ns.ThemeTokens.name = "warboard"
