local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
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

-- Whether a catalog entry exists in a game (default: this one). Catalog
-- entries do not change, so each answer is built once per game.
local inGame = setmetatable({}, { __mode = "k" }) -- [entry] = { [game] = bool }
function Macros.InGame(entry, game)
  game = game or Host.Game()
  local known = inGame[entry]
  if known and known[game] ~= nil then return known[game] end
  local yes = not (entry.games and not Macros.ForGame(entry.games, game)) and Macros.Build(entry, game) ~= nil
  known = known or {}
  known[game], inGame[entry] = yes, known
  return yes
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

-- Per-game value: G(cata, retail, forever[, tbc[, classic]]); nil = not in
-- that game. Classic Era and The Burning Crusade use the forever value
-- unless their own names a spell; false = not there although Forever has it.
Macros.G = Macros.Config.G
-- CataRetail(x) = G(x, x); NotRetail(x) = G(x, nil, x): Cataclysm and the
-- vanilla-based games (Forever, Classic Era, TBC).
Macros.CataRetail, Macros.NotRetail = Macros.Config.CataRetail, Macros.Config.NotRetail
-- Entries only WoW Forever has: its new spells and talents (Penance,
-- Shank, Riptide, ...) that Classic Era and The Burning Crusade lack.
Macros.FOREVER = { forever = true, classic = false, tbc = false }
-- Shared by the PvP and PvE presets: games whose totems drop at your feet,
-- and the bear form a stance dance switches to.
Macros.DROP_TOTEMS = { cata = true, forever = true }
Macros.BEAR = Macros.G({ 1, "Bear Form" }, nil, { 1, "Dire Bear Form" })

-- Descriptions naming the spell use the client's name for it, as the
-- macro body does (Macros.Desc): desc = Macros.SPELL is that name alone,
-- desc = Macros.SpellDesc(key) a message with a {spell} argument.
Macros.SPELL = {}
function Macros.SpellDesc(key) return { spellKey = key } end
local function With(entry, extra)
  for k, v in pairs(extra or {}) do entry[k] = v end
  if entry.desc == Macros.SPELL then
    entry.desc, entry.spellDesc = nil, true
  elseif type(entry.desc) == "table" then
    entry.desc, entry.spellDesc = nil, entry.desc.spellKey
  elseif entry.desc then
    Localization.Define(entry, { desc = entry.desc })
  end
  return entry
end

-- A catalog entry's description in the selected language.
function Macros.Desc(entry)
  local how = entry.spellDesc
  if entry.desc or not how then return entry.desc end
  local spell = Macros.SpellFor(entry.spell, nil, entry.class)
  if how == true or not spell then return spell end
  return Locale:Format(how, { spell = spell })
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
  Localization.Define({ name = "Focus Mouseover", desc = Locale:Get("macros.general.focus_the_unit_under_your_mouse_or.595813"),
    lines = "/focus [@mouseover,exists,nodead][]", mode = "both" }, { desc = "macros.general.focus_the_unit_under_your_mouse_or.595813" }),
  Localization.Define({ name = "Clear Focus", desc = Locale:Get("macros.general.drop_your_focus.0b8c45"), lines = "/clearfocus", mode = "both" }, { desc = "macros.general.drop_your_focus.0b8c45" }),
  Localization.Define({ name = "Focus Arena 1", desc = Locale:Get("macros.general.focus_arena_enemy_1.48a47e"), lines = "/focus arena1", games = ARENAS }, { desc = "macros.general.focus_arena_enemy_1.48a47e" }),
  Localization.Define({ name = "Focus Arena 2", desc = Locale:Get("macros.general.focus_arena_enemy_2.1fb7f5"), lines = "/focus arena2", games = ARENAS }, { desc = "macros.general.focus_arena_enemy_2.1fb7f5" }),
  Localization.Define({ name = "Focus Arena 3", desc = Locale:Get("macros.general.focus_arena_enemy_3.3a6608"), lines = "/focus arena3", games = ARENAS }, { desc = "macros.general.focus_arena_enemy_3.3a6608" }),
  Localization.Define({ name = "Target Arena 1", desc = Locale:Get("macros.general.target_arena_enemy_1.209490"), lines = "/target arena1", games = ARENAS }, { desc = "macros.general.target_arena_enemy_1.209490" }),
  Localization.Define({ name = "Target Arena 2", desc = Locale:Get("macros.general.target_arena_enemy_2.c20124"), lines = "/target arena2", games = ARENAS }, { desc = "macros.general.target_arena_enemy_2.c20124" }),
  Localization.Define({ name = "Target Arena 3", desc = Locale:Get("macros.general.target_arena_enemy_3.652b9a"), lines = "/target arena3", games = ARENAS }, { desc = "macros.general.target_arena_enemy_3.652b9a" }),
  Localization.Define({ name = "Target Enemy", desc = Locale:Get("macros.general.target_the_nearest_enemy_player.a1dd21"), lines = "/targetenemyplayer" }, { desc = "macros.general.target_the_nearest_enemy_player.a1dd21" }),
  Localization.Define({ name = "Trinket 1", desc = Locale:Get("macros.general.use_your_top_trinket_slot.876b47"), lines = "#showtooltip 13\n/use 13", mode = "both" }, { desc = "macros.general.use_your_top_trinket_slot.876b47" }),
  Localization.Define({ name = "Trinket 2", desc = Locale:Get("macros.general.use_your_bottom_trinket_slot.1aa4d8"), lines = "#showtooltip 14\n/use 14", mode = "both" }, { desc = "macros.general.use_your_bottom_trinket_slot.1aa4d8" }),
  Localization.Define({ name = "Pet Attack Focus", desc = Locale:Get("macros.general.send_your_pet_at_your_focus_or.296b6f"),
    lines = "/petattack [@focus,harm,nodead][]", mode = "both" }, { desc = "macros.general.send_your_pet_at_your_focus_or.296b6f" }),
  Localization.Define({ name = "Mark Skull", desc = Locale:Get("macros.general.skull_raid_marker_on_your_target.17e18b"), lines = "/tm 8", mode = "both" }, { desc = "macros.general.skull_raid_marker_on_your_target.17e18b" }),
  Localization.Define({ name = "Ping Attack", desc = Locale:Get("macros.general.attack_ping_on_your_target_for_your.719d29"), lines = "/ping [@target] attack",
    games = { retail = true, forever = true, classic = false, tbc = false } }, { desc = "macros.general.attack_ping_on_your_target_for_your.719d29" }),
})
