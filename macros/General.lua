local _, ns = ...
local Macros = ns.Macros

-- Catalog entries: builder options (macros/Builder.lua) plus class (nil =
-- every class), name (16 characters at most), desc, games ({ cata = true,
-- ... }, nil = every game) and arena (offer Focus and Arena 1-3 variants).
Macros.catalog = Macros.catalog or {}
local ARENAS = { cata = true, retail = true } -- WoW Forever has no arenas
Macros.ARENA_GAMES = ARENAS

-- Classes missing from a game: Forever has the nine classic classes, Cata no
-- Monk, Demon Hunter or Evoker.
Macros.CLASS_GAMES = {
  DEATHKNIGHT = { cata = true, retail = true },
  MONK = { retail = true }, DEMONHUNTER = { retail = true }, EVOKER = { retail = true },
}

function Macros.Add(class, list)
  for _, entry in ipairs(list) do
    entry.class = class
    entry.games = entry.games or Macros.CLASS_GAMES[class]
    Macros.catalog[#Macros.catalog + 1] = entry
  end
end

-- Per-game value: G(cata, retail, forever); nil = not in that game.
function Macros.G(cata, retail, forever)
  return { cata = cata, retail = retail, forever = forever }
end

local function With(entry, extra)
  for k, v in pairs(extra or {}) do entry[k] = v end
  return entry
end

-- On an enemy: focus (or arena 1-3), falling back to your target.
function Macros.Enemy(name, desc, spell, extra)
  return With({ name = name, desc = desc, spell = spell, target = "focus", kind = "harm", fallback = true,
    arena = true }, extra)
end

-- On an ally: mouseover (or party 1-2, yourself), then your target, then you.
function Macros.Ally(name, desc, spell, extra)
  return With({ name = name, desc = desc, spell = spell, target = "mouseover", kind = "help", fallback = true,
    self = true, party = true }, extra)
end

-- On yourself or no target (stopcasting, toggles, forms).
function Macros.Self(name, desc, spell, extra)
  return With({ name = name, desc = desc, spell = spell }, extra)
end

-- Ground-targeted at your cursor.
function Macros.Cursor(name, desc, spell, extra)
  return With({ name = name, desc = desc, spell = spell, target = "cursor" }, extra)
end

-- A fixed body (one string, or one per game); needs lists required spells.
function Macros.Raw(name, desc, lines, extra)
  return With({ name = name, desc = desc, lines = lines }, extra)
end

Macros.Add(nil, {
  { name = "Focus Mouseover", desc = "Focus the player under your mouse, or your target",
    lines = "/focus [@mouseover,exists,nodead][]" },
  { name = "Clear Focus", desc = "Drop your focus", lines = "/clearfocus" },
  { name = "Focus Arena 1", desc = "Focus arena enemy 1", lines = "/focus arena1", games = ARENAS },
  { name = "Focus Arena 2", desc = "Focus arena enemy 2", lines = "/focus arena2", games = ARENAS },
  { name = "Focus Arena 3", desc = "Focus arena enemy 3", lines = "/focus arena3", games = ARENAS },
  { name = "Target Arena 1", desc = "Target arena enemy 1", lines = "/target arena1", games = ARENAS },
  { name = "Target Arena 2", desc = "Target arena enemy 2", lines = "/target arena2", games = ARENAS },
  { name = "Target Arena 3", desc = "Target arena enemy 3", lines = "/target arena3", games = ARENAS },
  { name = "Target Enemy", desc = "Target the nearest enemy player", lines = "/targetenemyplayer" },
  { name = "Trinket 1", desc = "Use your top trinket slot", lines = "#showtooltip 13\n/use 13" },
  { name = "Trinket 2", desc = "Use your bottom trinket slot", lines = "#showtooltip 14\n/use 14" },
  { name = "Pet Attack Focus", desc = "Send your pet at your focus, or your target",
    lines = "/petattack [@focus,harm,nodead][]" },
  { name = "Mark Skull", desc = "Skull raid marker on your target", lines = "/tm 8" },
  { name = "Ping Attack", desc = "Attack ping on your target for your team", lines = "/ping [@target] attack",
    games = { retail = true, forever = true } },
  { name = "WB Kill Target", desc = "Warboard: target the recommended kill target",
    lines = "/click WarboardTargetButton" },
  { name = "WB Focus Kill", desc = "Warboard: focus the kill target and keep your target",
    lines = "/click WarboardFocusButton" },
  { name = "WB Mark Kill", desc = "Warboard: ping or mark the kill target", lines = "/click WarboardMarkButton" },
  { name = "WB Call Kill", desc = "Warboard: call the kill target in chat", lines = "/wb call" },
})
