local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host

-- Catalog entries: builder options (macros/Builder.lua) plus class (nil =
-- every class), name (16 characters at most), desc, games ({ cata = true,
-- ... }, nil = every game), mode ("pvp" default, "pve" or "both") and the
-- target variants a card offers (macros/Window.lua): arena (focus, arena
-- 1-3; 4-5 behind +), enemy (focus, mouseover, target), party (mouseover,
-- party 1-2, yourself; 3-4 behind +) or assist (someone else's target).
Macros.catalog = Macros.catalog or {}
-- Games with arenas and their largest bracket, read from ns.Games
-- (config/Client.lua): Macros.ARENA_GAMES[game], Macros.ARENA_SIZE[game].
-- Lookups only: pairs over them finds nothing.
Macros.ARENA_SIZE = setmetatable({}, { __index = function(_, game)
  return game and Host.GameInfo(game).arenaSize
end })
Macros.ARENA_GAMES = setmetatable({}, { __index = function(_, game)
  return Macros.ARENA_SIZE[game] and true or nil
end })
local ARENAS = Macros.ARENA_GAMES

-- Classes missing from a game: Forever and Classic Era have the nine classic
-- classes (The Burning Crusade too), Cata no Monk, Demon Hunter or Evoker.
-- Keys are ns.Games keys (tests/simulation/scenarios/macrowindow.lua).
Macros.CLASS_GAMES = {
  DEATHKNIGHT = { cata = true, retail = true },
  MONK = { retail = true }, DEMONHUNTER = { retail = true }, EVOKER = { retail = true },
}

-- Whether a catalog entry is a preset of mode ("pvp" or "pve").
function Macros.InMode(entry, mode)
  local m = entry.mode or "pvp"
  return m == "both" or m == mode
end

-- Whether the player's switches show a catalog entry (script presets:
-- scriptMacros, macros/Scripts.lua).
function Macros.Allowed(entry)
  return not entry.script or Host.On("scriptMacros")
end

-- Whether a catalog entry exists in a game (default: this one).
function Macros.InGame(entry, game)
  game = game or Host.Game()
  if entry.games and not Macros.ForGame(entry.games, game) then return false end
  return Macros.Build(entry, game) ~= nil
end

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
Macros.G = Macros.Config.G

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
-- Casting several spells: #showtooltip the one with a cooldown, so the bar
-- shows its timer.
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
