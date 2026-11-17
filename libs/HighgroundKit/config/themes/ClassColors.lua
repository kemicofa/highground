local _, ns = ...

-- A persistent class surface under enemy health and content. Its strength
-- is bounded by text contrast in ui/Contrast.lua, including custom colours.
ns.DefineTheme("classcolors", {
  label = "Class Colors",
  description = "Highground blue and gold with stronger full-row class colours.",
  alpha = { classRow = 0.55, healthFill = 0.08, topTint = 0.025, zebraEven = 0.01, zebraOdd = 0.015 },
})
