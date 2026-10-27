local _, ns = ...

-- What each game's API allows. The class configuration sets ns.CLIENT
-- ("retail" or "cata", selects data) and, on WoW Forever, ns.GAME. Classic
-- Era ("classic") and The Burning Crusade ("tbc") run only Warboard Macros,
-- which sets them itself (addons/WarboardMacros/Bootstrap.lua).
-- Runtime code checks ns.Caps, not client names.
ns.GAME = ns.GAME or ns.CLIENT

local GAMES = {
  -- Midnight: enemy health, power, auras and casts are secret; no combat log.
  retail = {
    combatLog = false,       -- COMBAT_LOG_EVENT_UNFILTERED reaches addons
    enemyStats = false,      -- enemy health and power are readable numbers
    classicSpecs = false,    -- specs are classic talent trees (IDs from the client)
    pings = true,            -- team pings can mark the kill target
    blitz = true,            -- solo rated battlegrounds exist
    allBattlegrounds = false, -- track every battleground by default, not only rated ones
    spellRanks = false,      -- spells have ranks (each rank its own spell ID)
  },
  -- Midnight client, classic content, no rated play.
  forever = {
    combatLog = false,
    enemyStats = false,
    classicSpecs = true,
    pings = true,
    blitz = false,
    allBattlegrounds = true,
    spellRanks = true,
  },
  cata = {
    combatLog = true,
    enemyStats = true,
    classicSpecs = true,
    pings = false,
    blitz = false,
    allBattlegrounds = true,
    spellRanks = false, -- ranks were removed in 4.0
  },
  classic = {
    combatLog = true,
    enemyStats = true,
    classicSpecs = true,
    pings = false,
    blitz = false,
    allBattlegrounds = true,
    spellRanks = true,
  },
}
GAMES.tbc = GAMES.classic

ns.Caps = assert(GAMES[ns.GAME], "Warboard: no capabilities for this game")
