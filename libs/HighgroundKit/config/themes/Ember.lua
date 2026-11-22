local _, ns = ...
local C = ns.ThemeColor

-- Smoked charcoal and brushed copper. Red is reserved for danger, never
-- used as the frame or action colour. Body type stays the shared weight.
ns.DefineTheme("ember", ns.Localization.Define({
  label = ns.Locale:Get("shared.ember.ember.20632b"),
  description = ns.Locale:Get("shared.ember.smoked_charcoal_warm_copper_light_and_sculpted.f5ee39"),
  color = {
    bg = C("211c1b"),
    surface = C("2c2522"),
    surfaceRaised = C("372f2b"),
    well = C("191615"),
    chipBg = C("211c1b"),
    border = C("5c4d43"),
    borderAccent = C("8c7060"),
    metalEdge = C("8c7060"),
    metalHighlight = C("eee5dd"),
    metalShadow = C("191615"),
    attackEdge = C("efa6a6"),
    controlBorder = C("a39486"),
    overlaySelected = C("d6ad8e", 0.12),
    text = C("eee5dd"),
    titleText = C("eee5dd"),
    textMuted = C("c5b8ad"),
    textDim = C("baad9f"),
    onAccent = C("211c1b"),
    accent = C("d6ad8e"),
    brand = C("d6ad8e"),
    gold = C("dbc395"),
    bounty = C("dbc395"),
    dead = C("baad9f"),
    sniperTheme = C("eba274"),
  },
  type = { titleSmall = { "bold", 12 }, title = { "bold", 16 }, display = { "bold", 24 } },
  alpha = { classRow = 0, healthFill = 0.12, topTint = 0.05, band = 0.05,
    ornament = 0.65, crest = 0, healthLine = 0, bevelLight = 0.06, bevelShade = 0.3,
    sheen = 0.03, glow = 0.24 },
}, { label = "shared.ember.ember.20632b", description = "shared.ember.smoked_charcoal_warm_copper_light_and_sculpted.f5ee39" }))
