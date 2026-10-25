local _, ns = ...

-- Which game this is and what its API lets an addon see.
--
-- The TOC picks the class configuration, and that file names the client
-- rules (ns.CLIENT: "retail" or "cata") and, on WoW Forever, the game
-- (ns.GAME). Runtime code asks ns.Caps about a capability instead of
-- comparing client names, so a new game or a changed restriction is one row
-- here. ns.CLIENT still selects client-specific data: settings visibility,
-- battleground variants and class tables.
ns.GAME = ns.GAME or ns.CLIENT

local GAMES = {
  -- Midnight: enemy health, power, auras and casts are secret in a match and
  -- addons get no combat log.
  retail = {
    combatLog = false,       -- COMBAT_LOG_EVENT_UNFILTERED reaches addons
    enemyStats = false,      -- enemy health and power are readable numbers
    classicSpecs = false,    -- specs are classic talent trees (IDs from the client)
    pings = true,            -- team pings can mark the kill target
    blitz = true,            -- solo rated battlegrounds exist
    allBattlegrounds = false, -- track every battleground by default, not only rated ones
  },
  -- WoW Forever runs the Midnight client with classic content and no rated play.
  forever = {
    combatLog = false,
    enemyStats = false,
    classicSpecs = true,
    pings = true,
    blitz = false,
    allBattlegrounds = true,
  },
  cata = {
    combatLog = true,
    enemyStats = true,
    classicSpecs = true,
    pings = false,
    blitz = false,
    allBattlegrounds = true,
  },
}

ns.Caps = assert(GAMES[ns.GAME], "Warboard: no capabilities for this game")
