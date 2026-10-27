local _, ns = ...
local Macros = ns.Macros

-- Catalog entries: builder options (macros/Builder.lua) plus class (nil =
-- every class), name (16 characters at most), desc, games ({ cata = true,
-- ... }, nil = every game), mode ("pvp" default, "pve" or "both") and the
-- target variants a card offers: arena (focus, arena 1-3), enemy (focus,
-- mouseover, target) or party (mouseover, party 1-2, yourself).
Macros.catalog = Macros.catalog or {}
local ARENAS = { cata = true, retail = true, tbc = true } -- WoW Forever and Classic Era have none
Macros.ARENA_GAMES = ARENAS
-- Largest arena bracket: 5v5 in Cata and The Burning Crusade, 3v3 on Retail.
Macros.ARENA_SIZE = { cata = 5, tbc = 5, retail = 3 }

-- Classes missing from a game: Forever and Classic Era have the nine classic
-- classes (The Burning Crusade too), Cata no Monk, Demon Hunter or Evoker.
Macros.CLASS_GAMES = {
  DEATHKNIGHT = { cata = true, retail = true },
  MONK = { retail = true }, DEMONHUNTER = { retail = true }, EVOKER = { retail = true },
}

-- Add catalog entries of a class (nil = general); mode is the default mode.
function Macros.Add(class, list, mode)
  for _, entry in ipairs(list) do
    entry.class = class
    entry.mode = entry.mode or mode
    entry.games = entry.games or Macros.CLASS_GAMES[class]
    Macros.catalog[#Macros.catalog + 1] = entry
  end
end

-- Per-game value: G(cata, retail, forever[, tbc]); nil = not in that game.
-- Classic Era uses the forever value; The Burning Crusade too, unless tbc
-- names a spell it added.
function Macros.G(cata, retail, forever, tbc)
  return { cata = cata, retail = retail, forever = forever, tbc = tbc }
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

-- PvE: on your focus (or the enemy under your mouse), then your target.
function Macros.Focus(name, desc, spell, extra)
  return With({ name = name, desc = desc, spell = spell, target = "focus", kind = "harm", fallback = true,
    enemy = true }, extra)
end

-- PvE: on the enemy under your mouse, then your target (taunts, dots).
function Macros.Mouseover(name, desc, spell, extra)
  return With({ name = name, desc = desc, spell = spell, target = "mouseover", kind = "harm", fallback = true,
    enemy = true }, extra)
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
  { name = "Focus Mouseover", desc = "Focus the unit under your mouse, or your target",
    lines = "/focus [@mouseover,exists,nodead][]", mode = "both" },
  { name = "Clear Focus", desc = "Drop your focus", lines = "/clearfocus", mode = "both" },
  { name = "Focus Arena 1", desc = "Focus arena enemy 1", lines = "/focus arena1", games = ARENAS },
  { name = "Focus Arena 2", desc = "Focus arena enemy 2", lines = "/focus arena2", games = ARENAS },
  { name = "Focus Arena 3", desc = "Focus arena enemy 3", lines = "/focus arena3", games = ARENAS },
  { name = "Target Arena 1", desc = "Target arena enemy 1", lines = "/target arena1", games = ARENAS },
  { name = "Target Arena 2", desc = "Target arena enemy 2", lines = "/target arena2", games = ARENAS },
  { name = "Target Arena 3", desc = "Target arena enemy 3", lines = "/target arena3", games = ARENAS },
  { name = "Target Enemy", desc = "Target the nearest enemy player", lines = "/targetenemyplayer" },
  { name = "Trinket 1", desc = "Use your top trinket slot", lines = "#showtooltip 13\n/use 13", mode = "both" },
  { name = "Trinket 2", desc = "Use your bottom trinket slot", lines = "#showtooltip 14\n/use 14", mode = "both" },
  { name = "Pet Attack Focus", desc = "Send your pet at your focus, or your target",
    lines = "/petattack [@focus,harm,nodead][]", mode = "both" },
  { name = "Mark Skull", desc = "Skull raid marker on your target", lines = "/tm 8", mode = "both" },
  { name = "Ping Attack", desc = "Attack ping on your target for your team", lines = "/ping [@target] attack",
    games = { retail = true, forever = true } },
})
