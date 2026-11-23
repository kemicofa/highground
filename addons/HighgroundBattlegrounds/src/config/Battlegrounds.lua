local _, ns = ...

-- Pure data registry. A TOC loads one class/client config, then this registry
-- and one file per battleground (config/battlegrounds/). Each battleground
-- lists the games it exists in under `games`: retail, forever and cata, each
-- with its own UI map and instance IDs and optional rules. A game without an
-- entry never resolves it, and rules never fall through from another game.
-- WoW Forever runs the retail client (ns.CLIENT) with its own content
-- (ns.GAME), so its entries are separate from retail's.
ns.BattlegroundConfigs = {}
ns.BATTLEGROUND_GAMES = { "retail", "forever", "cata" }
local index = {}
for _, game in ipairs(ns.BATTLEGROUND_GAMES) do index[game] = { ui = {}, inst = {} } end
local resolved = {}

-- Text shown to players in their language: T"key" in a config marks a value
-- as a catalog key. Registration swaps each marker for the translated text
-- and keeps the key, so a language change rewrites it.
local TEXT = {}
function ns.BattlegroundText(key)
  assert(type(key) == "string", "battleground text needs a catalog key")
  return setmetatable({ key = key }, TEXT)
end
local function Localize(t, seen)
  if seen[t] then return end
  seen[t] = true
  local fields
  for k, v in pairs(t) do
    if getmetatable(v) == TEXT then
      fields = fields or {}
      fields[k] = v.key
    elseif type(v) == "table" then
      Localize(v, seen)
    end
  end
  if fields then ns.Localization.Define(t, fields) end
end

-- Rules every battleground starts from in a game, before its own.
-- resurrection.shared: one clock for every graveyard (true), one per
-- graveyard (false); unset, Highground learns it from exact waves.
-- resurrection.startClock: graveyards there from the match start (both
-- starts, each side's first bases) spawned together and share a clock; a
-- captured base's graveyard starts its own at capture.
local GAME_DEFAULTS = {
  -- WoW Forever, observed 2026-11-23.
  forever = { resurrection = { startClock = true, shared = false } },
}

local PRIORITY = {
  ctf = ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.battlegrounds.ctf.281310"), objective = 1.5, focus = 1.3, impact = 1.2 }, { label = "battlegrounds.battlegrounds.ctf.281310" }),
  orb = ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.battlegrounds.orbs.23e1d8"), objective = 1.4, focus = 1.2 }, { label = "battlegrounds.battlegrounds.orbs.23e1d8" }),
  carry = ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.battlegrounds.flag_bases.1a6047"), objective = 1.2, impact = 1.2 }, { label = "battlegrounds.battlegrounds.flag_bases.1a6047" }),
  nodes = ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.battlegrounds.nodes.9e3254"), impact = 1.3, focus = 1.3 }, { label = "battlegrounds.battlegrounds.nodes.9e3254" }),
  carts = ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.battlegrounds.carts.715eeb"), impact = 1.3, focus = 1.3 }, { label = "battlegrounds.battlegrounds.carts.715eeb" }),
  resource = ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.battlegrounds.resources.87df60"), impact = 1.3, focus = 1.3 }, { label = "battlegrounds.battlegrounds.resources.87df60" }),
  epic = ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.battlegrounds.epic.b3efd0"), focus = 1.5, range = 1.5, impact = 0.8 }, { label = "battlegrounds.battlegrounds.epic.b3efd0" }),
}

local function Copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = Copy(v) end
  local fields = {}
  for k in pairs(value) do fields[k] = ns.Localization.Key(value, k) end
  if next(fields) then ns.Localization.Define(out, fields) end
  return out
end

-- Lists replace lists; named rule groups merge. False explicitly disables a
-- value inherited from shared rules (nil cannot be stored in a Lua table).
local function Merge(dst, src)
  for k, v in pairs(src or {}) do
    if type(v) == "table" and type(dst[k]) == "table" and v[1] == nil and dst[k][1] == nil then
      Merge(dst[k], v)
    else
      dst[k] = Copy(v)
    end
  end
  return dst
end

-- The client names a battleground in its own language: this game's maps
-- first, then the other games' IDs; the English gameName otherwise.
local function ClientName(config)
  local api = ns.Api
  if not (api and api.MapName) then return config.gameName end
  local order = { config.games[ns.GAME or ns.CLIENT] or {} }
  for _, game in ipairs(ns.BATTLEGROUND_GAMES) do order[#order + 1] = config.games[game] or {} end
  for _, maps in ipairs(order) do
    for _, id in ipairs(maps.ui or {}) do
      local name = api.MapName(id)
      if name then return name end
    end
    for _, id in ipairs(maps.inst or {}) do
      local name = api.InstanceName(id)
      if name then return name end
    end
  end
  return config.gameName
end

function ns.RegisterBattleground(config)
  assert(type(config.id) == "string" and not ns.BattlegroundConfigs[config.id], "duplicate/missing battleground id")
  assert(type(config.gameName or config.name) == "string" and PRIORITY[config.kind], "invalid battleground identity")
  assert(type(config.size) == "number" and config.size > 0, "battleground needs a team size")
  assert(config.clients == nil, config.id .. ": list games under `games` (retail, forever, cata), not `clients`")
  assert(type(config.games) == "table" and next(config.games), "battleground needs a game")
  for game, maps in pairs(config.games) do
    assert(index[game], "unsupported battleground game: " .. tostring(game))
    for _, kind in ipairs({ "ui", "inst" }) do
      for _, id in ipairs(maps[kind] or {}) do
        assert(type(id) == "number" and not index[game][kind][id], "duplicate/invalid map id: " .. tostring(id))
        index[game][kind][id] = config
      end
    end
  end
  Localize(config, {})
  config.name = config.name or ClientName(config)
  ns.BattlegroundConfigs[config.id] = config
end

-- The client each game runs on: Forever plays its content on the retail one.
local CLIENT_OF = { retail = "retail", forever = "retail", cata = "cata" }

-- The game being played on a client: this session's game when it runs on
-- that client, otherwise the client's own game.
local function GameOf(client, game)
  if game then return game end
  if ns.GAME and CLIENT_OF[ns.GAME] == client then return ns.GAME end
  return client
end

function ns.ResolveBattleground(ui, instance, client, mode, game)
  client = client or ns.CLIENT
  game = GameOf(client, game)
  local lookup = index[game]
  if not lookup then return nil end
  -- An instance ID is more reliable than a transient/stale UI map.
  local config = lookup.inst[instance] or lookup.ui[ui]
  if not config then return nil end
  mode = (client == "retail" and mode == "blitz" and "blitz") or (mode == "rated" and "rated") or "standard"
  local maps = config.games[game]
  local variant = maps.variants and maps.variants[instance]
  -- Learned state is keyed by client, not game: each game has its own saved
  -- variables, and Forever keeps the keys it learned under "retail".
  local key = client .. ":" .. config.id .. ":" .. (variant and variant.id or "default") .. ":" .. mode
  local cache = resolved[game] or {}
  resolved[game] = cache
  if cache[key] then return cache[key] end
  local rules = {
    resurrection = { period = 30 },
    capture = {},
    graveyards = { mode = "none" },
    scoring = { predict = false },
    map = {},
    priority = Copy(PRIORITY[config.kind]),
  }
  Merge(rules, GAME_DEFAULTS[game])
  Merge(rules, config.rules)
  Merge(rules, maps.rules)
  Merge(rules, variant and variant.rules)
  if mode == "blitz" then
    rules.priority.impact = (rules.priority.impact or 1) * 1.3
    Merge(rules, config.blitz)
  elseif mode == "rated" then
    -- Rated battlegrounds resurrect every 45 seconds.
    Merge(rules, { resurrection = { period = 45 } })
    Merge(rules, config.rated)
  end
  assert(rules.resurrection.period > 0, "invalid resurrection period")
  if rules.capture.seconds then assert(rules.capture.seconds > 0, "invalid capture time") end
  local bg = ns.Localization.Define({
    id = config.id, name = config.name, gameName = config.gameName, kind = config.kind, client = client, game = game, mode = mode,
    -- Players per team: rated battlegrounds are 10v10, Blitz 8v8.
    size = (mode == "blitz" and 8) or (mode == "rated" and 10) or config.size,
    variant = variant and variant.id,
    ui = maps.ui or {}, inst = maps.inst or {}, rulesKey = key, rules = rules,
    coverage = config.coverage,
  }, { coverage = ns.Localization.Key(config, "coverage") })
  cache[key] = bg
  return bg
end
