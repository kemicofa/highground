local _, ns = ...

-- Pure data registry. A TOC loads one class/client config, then this registry
-- and one file per battleground. Rules never fall through to another client.
-- WoW Forever runs the retail client with its own content: `games.forever`
-- overrides retail rules there, and a client entry with `game` exists only
-- in that game.
ns.BattlegroundConfigs = {}
local index = { retail = { ui = {}, inst = {} }, cata = { ui = {}, inst = {} } }
local resolved = {}

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

-- The client names a battleground in its own language: this client's map
-- first, then another client's IDs; the English gameName otherwise.
local function ClientName(config)
  local api, own = ns.Api, config.clients[ns.CLIENT]
  if api and api.MapName then
    for _, maps in ipairs({ own or {}, config.clients.retail or {}, config.clients.cata or {} }) do
      for _, id in ipairs(maps.ui or {}) do
        local name = api.MapName(id)
        if name then return name end
      end
      for _, id in ipairs(maps.inst or {}) do
        local name = api.InstanceName(id)
        if name then return name end
      end
    end
  end
  return config.gameName
end

function ns.RegisterBattleground(config)
  assert(type(config.id) == "string" and not ns.BattlegroundConfigs[config.id], "duplicate/missing battleground id")
  assert(type(config.gameName or config.name) == "string" and PRIORITY[config.kind], "invalid battleground identity")
  assert(type(config.size) == "number" and config.size > 0, "battleground needs a team size")
  assert(type(config.clients) == "table" and next(config.clients), "battleground needs a client")
  assert(config.games == nil or type(config.games) == "table", "battleground games must be a table")
  for client, maps in pairs(config.clients) do
    assert(index[client], "unsupported battleground client: " .. tostring(client))
    assert(maps.game == nil or type(maps.game) == "string", "client game must be a name")
    for _, kind in ipairs({ "ui", "inst" }) do
      for _, id in ipairs(maps[kind] or {}) do
        assert(type(id) == "number" and not index[client][kind][id], "duplicate/invalid map id: " .. tostring(id))
        index[client][kind][id] = config
      end
    end
  end
  config.name = config.name or ClientName(config)
  ns.BattlegroundConfigs[config.id] = config
end

function ns.ResolveBattleground(ui, instance, client, mode, game)
  client = client or ns.CLIENT
  game = game or (client == ns.CLIENT and ns.GAME) or client
  local lookup = index[client]
  if not lookup then return nil end
  -- An instance ID is more reliable than a transient/stale UI map.
  local config = lookup.inst[instance] or lookup.ui[ui]
  if not config then return nil end
  mode = (client == "retail" and mode == "blitz" and "blitz") or (mode == "rated" and "rated") or "standard"
  local maps = config.clients[client]
  if maps.game and maps.game ~= game then return nil end
  local variant = maps.variants and maps.variants[instance]
  -- Learned state needs no game: each game has its own saved variables.
  local key = client .. ":" .. config.id .. ":" .. (variant and variant.id or "default") .. ":" .. mode
  local cache = resolved[game] or {}
  resolved[game] = cache
  if cache[key] then return cache[key] end
  local rules = {
    -- shared: one clock for every graveyard (true), one per graveyard
    -- (false); unset, Highground learns it from exact waves. startClock:
    -- graveyards there from the match start (both starts, each side's first
    -- bases) spawned together and share a clock; a captured base's
    -- graveyard starts its own at capture. WoW Forever, observed 2026-11-23.
    resurrection = { period = 30, startClock = game == "forever" or nil },
    capture = {},
    graveyards = { mode = "none" },
    scoring = { predict = false },
    map = {},
    priority = Copy(PRIORITY[config.kind]),
  }
  if rules.resurrection.startClock then rules.resurrection.shared = false end
  Merge(rules, config.rules)
  Merge(rules, maps.rules)
  Merge(rules, config.games and config.games[game])
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
    id = config.id, name = config.name, gameName = config.gameName, kind = config.kind, client = client, mode = mode,
    -- Players per team: rated battlegrounds are 10v10, Blitz 8v8.
    size = (mode == "blitz" and 8) or (mode == "rated" and 10) or config.size,
    variant = variant and variant.id,
    ui = maps.ui or {}, inst = maps.inst or {}, rulesKey = key, rules = rules,
    coverage = config.coverage,
  }, { coverage = ns.Localization.Key(config, "coverage") })
  cache[key] = bg
  return bg
end
