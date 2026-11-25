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
    enemyAuras = true,       -- enemy auras are readable in a match (unverified on Retail)
    enemyStats = false,      -- enemy health and power are readable numbers
    classicSpecs = false,    -- specs are classic talent trees (IDs from the client)
    pings = true,            -- team pings can mark the kill target
    enemyMarks = true,       -- raid target icons can go on enemy players (unverified on Retail)
    matchSharing = true,     -- addon messages reach teammates during a battleground match (unverified on Retail)
    blitz = true,            -- solo rated battlegrounds exist
    allBattlegrounds = true, -- track every battleground by default, not only rated ones
    orbs = true,             -- Temple of Kotmogu's orbs exist
    spellRanks = false,      -- spells have ranks (each rank its own spell ID)
    inspectTalents = false,  -- inspected teammates' talent points name their healers
    layers = false,          -- open-world layers: SHARD_TRANSFER moves, group phase marks (world/Layer.lua)
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
    -- Reading enemy auras in a match errors: "Auras cannot be accessed when
    -- secret while tainted" (live, 2026-11-24).
    enemyAuras = false,
    enemyStats = false,
    classicSpecs = true,
    pings = true,
    -- Players can mark teammates but not enemy players (live, 2026-11-24).
    enemyMarks = false,
    -- Chat lockdown for the whole match (bg profiler, three matches 2026-11-23/24).
    matchSharing = false,
    blitz = false,
    allBattlegrounds = true,
    orbs = false,
    spellRanks = true,
    -- Every teammate's group role is DAMAGER in a match; an inspect reads
    -- their talent points there (live, 2026-11-24).
    inspectTalents = true,
    -- Layers since launch; creature GUIDs stopped naming them in build 71037
    -- (LayerSwap's measurements, docs/forever-api.md).
    layers = true,
  },
  cata = {
    addonChannel = false,   -- discover on custom chat, send data by whisper
    combatLog = true,
    enemyAuras = true,
    enemyStats = true,
    classicSpecs = true,
    pings = false,
    enemyMarks = true,
    matchSharing = true,
    blitz = false,
    allBattlegrounds = true,
    orbs = false,
    spellRanks = false, -- ranks were removed in 4.0
    inspectTalents = false,
    layers = false,
  },
  classic = {
    addonChannel = false,
    combatLog = true,
    enemyAuras = true,
    enemyStats = true,
    classicSpecs = true,
    pings = false,
    enemyMarks = true,
    matchSharing = true,
    blitz = false,
    allBattlegrounds = true,
    orbs = false,
    spellRanks = true,
    inspectTalents = false,
    layers = false,
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
  retail = ns.Localization.Define({ name = "Retail", label = ns.Locale:Get("shared.client.retail.325e08"), arenaSize = 3 }, { label = "shared.client.retail.325e08" }),
  forever = ns.Localization.Define({ name = "WoW Forever", label = ns.Locale:Get("shared.client.wow_forever.e388cd") }, { label = "shared.client.wow_forever.e388cd" }),
  cata = ns.Localization.Define({ name = "Cataclysm", label = ns.Locale:Get("shared.client.cataclysm.d66e99"), arenaSize = 5 }, { label = "shared.client.cataclysm.d66e99" }),
  classic = ns.Localization.Define({ name = "Classic Era", label = ns.Locale:Get("shared.client.classic_era.706f31"), contentOf = "forever" }, { label = "shared.client.classic_era.706f31" }),
  tbc = ns.Localization.Define({ name = "The Burning Crusade", label = ns.Locale:Get("shared.client.burning_crusade.3c962a"), arenaSize = 5, contentOf = "forever" }, { label = "shared.client.burning_crusade.3c962a" }),
}

---------------------------------------------------------------------------
-- Moved game APIs. Retail and WoW Forever (the Midnight client) moved many
-- globals into C_ namespaces and removed or deprecated the old names;
-- Cataclysm Classic has most namespaces too. ns.Api.Fn prefers the
-- namespaced function and falls back to the global, looked up per call so
-- late-loading clients and test stubs are honoured. Wrappers below also
-- even out argument differences. Hot paths may keep a direct local where
-- the capability (ns.Caps) already guarantees the function.
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

-- Game settings (C_CVar since 8.0). Values are strings; nil when this client
-- has no such setting. SetCVar returns whether the client accepted it.
function Api.GetCVar(name) return Call(Api.Fn("C_CVar", "GetCVar"), name) end
function Api.SetCVar(name, value) return Call(Api.Fn("C_CVar", "SetCVar"), name, value) end

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

-- Points spent per talent tree of your active loadout (or of the last
-- inspected player), in tree order: { { name = "Subtlety", spent = 30 }, ... }.
-- WoW Forever draws its three classic trees as groups of one trait tree.
-- Nil without such groups.
local INSPECT_CONFIG = -1 -- Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID
local function TalentTreePoints(inspect)
  local traits, secret = G.C_Traits, G.issecretvalue
  local config = inspect and INSPECT_CONFIG or Call(Api.Fn("C_ClassTalents", "GetActiveConfigID"))
  local info = config and traits.GetConfigInfo(config)
  local tree = info and info.treeIDs and info.treeIDs[1]
  local groups = tree and traits.GetGroupDisplayInfoByTreeID(tree)
  if not groups or #groups == 0 then return end
  table.sort(groups, function(a, b) return a.orderIndex < b.orderIndex end)
  local ids, spent, points = {}, {}, {}
  for i, group in ipairs(groups) do ids[i] = group.groupID end
  for _, group in ipairs(traits.GetGroupCurrencyInfo(config, ids)) do
    local currency = group.currencyInfos[1]
    spent[group.traitNodeGroupID] = currency and currency.spent
  end
  for i, group in ipairs(groups) do
    local n = spent[group.groupID] or 0
    if secret and secret(n) then return end
    points[i] = { name = group.displayName, spent = n }
  end
  return points
end
function Api.TalentTreePoints() return Call(TalentTreePoints) end
-- After INSPECT_READY: the inspected player's points, read the same way.
function Api.InspectTalentTreePoints() return Call(TalentTreePoints, true) end

-- Map names in the client's language: a UI map (C_Map) or an instance
-- (GetRealZoneText); nil when the client does not know the ID.
local function Name(value) if type(value) == "string" and value ~= "" then return value end end
function Api.MapName(uiMapID)
  local info = Call(Api.Fn("C_Map", "GetMapInfo"), uiMapID)
  return type(info) == "table" and Name(info.name) or nil
end
function Api.InstanceName(instanceID)
  local fn = G.GetRealZoneText
  return type(fn) == "function" and Name((Call(fn, instanceID))) or nil
end
