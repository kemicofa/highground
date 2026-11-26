-- Run from addons/Highground:
--   luajit ../../tools/performance_history.lua [cata|retail|forever] [characters] [matches] [events] [waiting|archived] [open]
-- Lua heap held by a full match history after login: characters with
-- matches each, every match with events observed events (unique text, about
-- 40 characters, so nothing is shared). waiting: every timeline in
-- HighgroundDB, as before the archive or without it; archived: summaries in
-- HighgroundDB and timelines in the unloaded archive (HighgroundMatchData).
-- open: then open match history. Login fires PLAYER_ENTERING_WORLD outside
-- instances. "Saved history" is the heap the saved tables hold (repeatable);
-- "retained" is the whole simulated session, widgets included, and varies
-- by about 1 MiB between runs: compare before and after a change, not with
-- WoW's memory meter.
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local client = arg[1] or "retail"
local characters, matches, events = tonumber(arg[2]) or 1, tonumber(arg[3]) or 100, tonumber(arg[4]) or 200
local mode, open = arg[5] or "waiting", arg[6] == "open"
assert(client == "cata" or client == "retail" or client == "forever", "expected cata, retail or forever")
assert(mode == "waiting" or mode == "archived", "expected waiting or archived")

local function configure(_, env)
  if client == "forever" then env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", 16001 end end
end
local function clear()
  local chunks = package.loaded["wowsim.chunks"]
  for path in pairs(chunks) do chunks[path] = nil end
end

-- The character key and game, from a session that is then dropped.
local probe = new(client == "cata" and "cata" or "retail", {}, configure)
local key, game = probe.ns.Scope.Character(), probe.ns.GAME
probe = nil
clear()

local BASES = { "Stables", "Blacksmith", "Farm", "Gold Mine", "Lumber Mill" }
local function Scope(c) return c == 1 and key or key .. ":alt" .. c end
local function Started(m) return 1700000000 - m * 3000 end
local function Timeline(c, m)
  local timeline = {}
  for e = 1, events do
    timeline[e] = { at = e * 7, text = string.format("%s assaulted the %s (%d.%d.%d)", "Player" .. e % 37, BASES[e % 5 + 1], c, m, e) }
  end
  return timeline
end

local function History()
  local all = {}
  for c = 1, characters do
    local list = {}
    for m = 1, matches do
      local started = Started(m)
      list[m] = { id = started .. ":529:" .. m, map = 529, name = "Arathi Basin", kind = "pvp", character = "Me-Realm",
        game = game, scope = Scope(c), spec = 71, specName = "Arms", started = started, team = 1, clock = 100,
        updated = started + 1500, lastDuration = 1500, duration = 1500, finished = started + 1500, result = "Win",
        stats = { killingBlows = 4, honorableKills = 31, deaths = 5, honorGained = 412, damageDone = 48211, healingDone = 3120 } }
      if mode == "archived" then list[m].archived = events else list[m].events = Timeline(c, m) end
    end
    all[Scope(c)] = { matches = list }
  end
  return { scoped = { character = all } }
end

-- The archive's file is read only when it loads.
local function Archive()
  local all = {}
  for c = 1, characters do
    local timelines = {}
    for m = 1, matches do timelines[Started(m) .. ":529:" .. m] = { started = Started(m), events = Timeline(c, m) } end
    all[Scope(c)] = { timelines = timelines }
  end
  return { version = 1, scoped = { character = all } }
end

-- Heap held by build()'s result.
local function Size(build)
  collectgarbage("collect"); collectgarbage("collect")
  local start = collectgarbage("count")
  local value = build()
  collectgarbage("collect"); collectgarbage("collect")
  return value, collectgarbage("count") - start
end

collectgarbage("collect")
local initial = collectgarbage("count")
local saved, savedSize = Size(History)
local archiveSize = 0
local sim = new(client == "cata" and "cata" or "retail", saved, function(s, env)
  configure(s, env)
  s.addonSaved = setmetatable({}, { __index = function(_, name)
    if name ~= "HighgroundMatchArchiveDB" or mode ~= "archived" then return end
    local archive
    archive, archiveSize = Size(Archive)
    return archive
  end })
end)
saved = nil
sim:event("PLAYER_ENTERING_WORLD")
sim:advance(1)
if open then sim:command("history") end
clear()
collectgarbage("collect"); collectgarbage("collect")
local loaded = sim.addons and sim.addons.HighgroundMatchData ~= nil
print(string.format("%s, %d character(s) x %d matches x %d events, %s%s: saved history %.0f KiB, archive %s, %.0f KiB retained",
  client, characters, matches, events, mode, open and ", history opened" or "", savedSize,
  not loaded and "not loaded" or mode == "waiting" and "loaded (timelines moved in)" or string.format("loaded (%.0f KiB)", archiveSize),
  collectgarbage("count") - initial))
