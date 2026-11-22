local _, ns = ...

-- What each game's API allows. The class configuration sets ns.CLIENT
-- ("retail" or "cata", selects data) and, on WoW Forever, ns.GAME. Classic
-- Era ("classic") and The Burning Crusade ("tbc") run only Highground Macros,
-- whose client detection lives in libs/standalone/Bootstrap.lua.
-- Runtime code checks ns.Caps, not client names.
ns.GAME = ns.GAME or ns.CLIENT

local GAMES = {
  -- Midnight: enemy health, power, auras and casts are secret; no combat log.
  retail = {
    addonChannel = true,    -- addon messages can use a custom realm channel
    combatLog = false,       -- COMBAT_LOG_EVENT_UNFILTERED reaches addons
    enemyStats = false,      -- enemy health and power are readable numbers
    classicSpecs = false,    -- specs are classic talent trees (IDs from the client)
    pings = true,            -- team pings can mark the kill target
    blitz = true,            -- solo rated battlegrounds exist
    allBattlegrounds = true, -- track every battleground by default, not only rated ones
    spellRanks = false,      -- spells have ranks (each rank its own spell ID)
  },
  -- Midnight client, classic content, no rated play.
  forever = {
    addonChannel = true,
    -- Forever reports outgoing messages restricted even when they send.
    -- Treat that flag as diagnostic; chat lockdown still blocks sending.
    addonRestrictionAdvisory = true,
    rulesetRealms = true,   -- economies and bounty lists follow the active ruleset
    hideRealmNames = true, -- retain internal suffixes, omit them from player-facing names
    -- Some Forever builds omit the compiler used by RestrictedExecution.
    -- WrapScript still succeeds there, but its first click fails before
    -- SecureActionButton can run. Re-enable snippets if the client fixes it.
    secureSnippets = type(loadstring_untainted) == "function",
    combatLog = false,
    enemyStats = false,
    classicSpecs = true,
    pings = true,
    blitz = false,
    allBattlegrounds = true,
    spellRanks = true,
  },
  cata = {
    addonChannel = false,   -- discover on custom chat, send data by whisper
    combatLog = true,
    enemyStats = true,
    classicSpecs = true,
    pings = false,
    blitz = false,
    allBattlegrounds = true,
    spellRanks = false, -- ranks were removed in 4.0
  },
  classic = {
    addonChannel = false,
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

ns.Caps = assert(GAMES[ns.GAME], "no capabilities for this game: " .. tostring(ns.GAME))
ns.GameCaps = GAMES -- every game's, for checks about another game (macro compiler)

-- What each game is called and what it holds, for any addon of the
-- repository. name: in sentences; label: upper-case UI label; arenaSize:
-- largest arena bracket (nil: no arenas); contentOf: the game whose spells
-- and presets it shares when it has none of its own.
ns.Games = {
  retail = { name = "Retail", label = "RETAIL", arenaSize = 3 },
  forever = { name = "WoW Forever", label = "WOW FOREVER" },
  cata = { name = "Cataclysm", label = "CATACLYSM", arenaSize = 5 },
  classic = { name = "Classic Era", label = "CLASSIC ERA", contentOf = "forever" },
  tbc = { name = "The Burning Crusade", label = "BURNING CRUSADE", arenaSize = 5, contentOf = "forever" },
}

---------------------------------------------------------------------------
-- Moved game APIs. Retail and WoW Forever (the Midnight client) moved many
-- globals into C_ namespaces and removed or deprecated the old names;
-- Cataclysm Classic has most namespaces too. ns.Api.Fn prefers the
-- namespaced function and falls back to the global, looked up per call so
-- late-loading clients and test stubs are honoured. Wrappers below also
-- even out argument differences. Hot paths may keep a direct local where
-- the capability (ns.Caps) already guarantees the function.
-- core/Modules.lua and standalone/Bootstrap.lua load before this file and
-- keep their own fallbacks.
---------------------------------------------------------------------------
local Api = {}
ns.Api = Api
-- This file's global environment (the game's _G; a fixture's own table).
local G = getfenv and getfenv(1) or _G

-- Function space.name, else the global (default name); nil when neither.
function Api.Fn(space, name, global)
  local t = G[space]
  local fn = type(t) == "table" and t[name]
  if type(fn) ~= "function" then fn = G[global or name] end
  if type(fn) == "function" then return fn end
end

local function Call(fn, ...)
  if not fn then return end
  local ok, a, b, c, d, e, f, g = pcall(fn, ...)
  if ok then return a, b, c, d, e, f, g end
end

-- Add-ons (C_AddOns since 10.1; the globals are gone on Retail).
function Api.AddOnMetadata(addon, field) return Call(Api.Fn("C_AddOns", "GetAddOnMetadata"), addon, field) end
function Api.IsAddOnLoaded(addon) return Call(Api.Fn("C_AddOns", "IsAddOnLoaded"), addon) end
function Api.LoadAddOn(addon) return Call(Api.Fn("C_AddOns", "LoadAddOn"), addon) end

-- Chat: C_ChatInfo.SendChatMessage replaces the deprecated global.
-- Returns whether the client accepted the call.
function Api.SendChatMessage(text, chatType, language, target)
  local fn = Api.Fn("C_ChatInfo", "SendChatMessage")
  if not fn then return false end
  local ok, result = pcall(fn, text, chatType, language, target)
  return ok and result ~= false
end

-- Items (C_Item since 11.0).
function Api.ItemCount(item) return tonumber((Call(Api.Fn("C_Item", "GetItemCount"), item))) or 0 end
function Api.IsEquippedItem(item) return Call(Api.Fn("C_Item", "IsEquippedItem"), item) == true end
function Api.ItemName(id)
  local byID = Api.Fn("C_Item", "GetItemNameByID")
  if byID then return (Call(byID, id)) end
  return (Call(Api.Fn("C_Item", "GetItemInfo"), id))
end

-- Spells. C_SpellBook.IsSpellKnown takes a spell bank instead of isPet.
-- Not checked in game on every client: if it errors or answers nil, the
-- isPet form (the global, else the namespaced one) answers instead.
function Api.IsSpellKnown(spellID, pet)
  local book = G.C_SpellBook
  local modern = type(book) == "table" and book.IsSpellKnown
  if type(modern) ~= "function" then modern = nil end
  local bank = G.Enum and G.Enum.SpellBookSpellBank
  if modern and type(bank) == "table" then
    local ok, known = pcall(modern, spellID, pet and bank.Pet or bank.Player)
    if ok and known ~= nil then return known and true or false end
  end
  local legacy = G.IsSpellKnown
  if type(legacy) ~= "function" then legacy = modern end
  return Call(legacy, spellID, pet and true or nil) == true
end

-- Your specialization index and its ID (C_SpecializationInfo on Midnight).
function Api.Specialization() return Call(Api.Fn("C_SpecializationInfo", "GetSpecialization")) end
function Api.SpecializationInfo(index)
  return Call(Api.Fn("C_SpecializationInfo", "GetSpecializationInfo"), index)
end
function Api.NumSpecializationsForClassID(classID)
  return Call(Api.Fn("C_SpecializationInfo", "GetNumSpecializationsForClassID"), classID)
end

