local _, ns = ...
local C = ns.ThemeColor

-- Near-black wells, neutral graphite panels and violet light. Neutral grey
-- keeps class surfaces true; violet stays clear of the tactical colours
-- and also replaces bounty gold, as Azeroth does with its accent.
ns.DefineTheme("dark", ns.Localization.Define({
  label = ns.Locale:Get("shared.dark.dark.ae1ef0"),
  description = ns.Locale:Get("shared.dark.near_black_panels_graphite_surfaces_and_violet.268f9a"),
  color = {
    bg = C("0b0b0d"),
    surface = C("151518"),
    surfaceRaised = C("202024"),
    well = C("060607"),
    chipBg = C("08080a"),
    border = C("38383f"),
    borderAccent = C("7f6fb8"),
    metalEdge = C("7f6fb8"),
    metalHighlight = C("ece9f5"),
    metalShadow = C("060607"),
    controlBorder = C("8b8b96"),
    overlaySelected = C("b9a5ff", 0.12),
    text = C("ededf0"),
    titleText = C("dcd2ff"),
    textMuted = C("b6b6c0"),
    textDim = C("a6a6b1"),
    onAccent = C("0b0b0d"),
    accent = C("b9a5ff"),
    brand = C("b9a5ff"),
    gold = C("b9a5ff"),
    bounty = C("b9a5ff"),
    hudBg = C("0b0b0d"),
    mapLabel = C("b6b6c0"),
    dead = C("a6a6b1"),
  },
  type = { titleSmall = { "bold", 12 }, title = { "bold", 16 }, display = { "bold", 24 } },
  alpha = { crest = 0, ornament = 0.7, topTint = 0.03, bevelLight = 0.06, bevelShade = 0.4,
    sheen = 0.04, glow = 0.28 },
}, { label = "shared.dark.dark.ae1ef0", description = "shared.dark.near_black_panels_graphite_surfaces_and_violet.268f9a" }))
