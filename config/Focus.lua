local _, ns = ...

-- Teammates drawing enemy attention. Kept separate from offensive target
-- scoring and its sniper scope. Cata exposes the required target tokens.
ns.FocusConfig = {
  clients = { cata = true },
  limit = 3,
  minimumEnemies = 1,
  updateSeconds = 0.25,
  size = 30,
  offsetY = 14,
  color = ns.ThemeTokens.color.hudWarning,
  urgentColor = ns.ThemeTokens.color.hudDanger,
  urgentCount = 3,
  fallbackTexture = "Interface\\Icons\\Ability_Warrior_DefensiveStance",
}
