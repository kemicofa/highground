local _, ns = ...

-- A persistent class surface under enemy health and content. Its strength
-- is bounded by text contrast in ui/Contrast.lua, including custom colours.
ns.DefineTheme("classcolors", ns.Localization.Define({
  label = ns.Locale:Get("shared.classcolors.class_colors.9dea52"),
  description = ns.Locale:Get("shared.classcolors.highground_blue_and_gold_with_stronger_full.cc8f44"),
  alpha = { classRow = 0.55, healthFill = 0.08, topTint = 0.025, zebraEven = 0.01, zebraOdd = 0.015 },
}, { label = "shared.classcolors.class_colors.9dea52", description = "shared.classcolors.highground_blue_and_gold_with_stronger_full.cc8f44" }))
