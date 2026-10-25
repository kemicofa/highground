local _, ns = ...

-- What each game's API allows. The class configuration sets ns.CLIENT
-- ("retail" or "cata", selects data) and, on WoW Forever, ns.GAME.
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
  },
  -- Midnight client, classic content, no rated play.
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
