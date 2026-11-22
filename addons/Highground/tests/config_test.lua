local loadConfig = dofile("tests/load_config.lua")
local retail, cata = loadConfig("retail"), loadConfig("cata")
-- WoW Forever loads the retail manifest; its build reports interface 16001.
GetBuildInfo = function() return "1.60.1", "71037", "Nov 20 2026", 16001 end
local forever = loadConfig("retail")
GetBuildInfo = nil
local checks = 0
local function check(condition, message)
  assert(condition, message)
  checks = checks + 1
end
local function bg(ns, instance, mode)
  return assert(ns.ResolveBattleground(nil, instance, ns.CLIENT, mode))
end

-- The registry contains 16 definitions: 15 Retail and all 8 original Cata BGs.
local definitions, clients = 0, { retail = 0, cata = 0 }
for _, config in pairs(retail.BattlegroundConfigs) do
  definitions = definitions + 1
  check(type(config.coverage) == "string", config.id .. " needs documented coverage")
  for client, maps in pairs(config.clients) do
    clients[client] = clients[client] + 1
    for _, id in ipairs(maps.inst or {}) do
      local resolved = retail.ResolveBattleground(nil, id, client)
      check(resolved and resolved.id == config.id, "instance mapping " .. id)
    end
    for _, id in ipairs(maps.ui or {}) do
      local resolved = retail.ResolveBattleground(id, nil, client)
      check(resolved and resolved.id == config.id, "UI map mapping " .. id)
    end
  end
end
check(definitions == 16 and clients.retail == 15 and clients.cata == 8, "BG coverage")
check(cata.ResolveBattleground(417, 998) == nil, "Cata must not resolve Retail Temple")
check(retail.ResolveBattleground(128, 607) == nil, "Retail must not resolve retired Strand")
check(retail.ResolveBattleground(2444, nil) == nil, "outdoor Slayer's Rise is not the BG")
check(bg(retail, 2799).id == "slayers_rise", "Slayer's Rise instance")
check(retail.ResolveBattleground(519, 1105) == nil, "legacy Deepwind rules cannot masquerade as modern map")
check(bg(retail, 2245).rules.scoring.bases == 5, "modern Deepwind has five bases")

check(forever.GAME == "forever" and forever.CLIENT == "retail", "Forever runs on the retail client")
local av, foreverAV = bg(retail, 30), bg(forever, 30)
check(av.rules.capture.seconds == 240 and foreverAV.rules.capture.seconds == 300, "Forever AV captures take 300 seconds")
check(foreverAV.rules.graveyards.mode == "names", "Forever AV keeps the retail rules it does not override")
check(retail.ResolveBattleground(nil, 30, "retail", nil, "forever").rules.capture.seconds == 300
  and bg(retail, 30).rules.capture.seconds == 240, "an explicit game resolves separately")

local standard = bg(retail, 2107)
local blitz = bg(retail, 2107, "blitz")
local classic = bg(cata, 529)
check(standard.rules.capture.seconds == 60, "Retail AB duration")
check(classic.rules.capture.seconds == 65, "retain configured Cata AB calibration")
check(blitz.rules.capture.seconds == 30, "Blitz AB duration")
check(blitz.rules.capture.holdSeconds == 45 and blitz.rules.capture.resetSeconds == 5, "Blitz ownership cycle")
check(not blitz.rules.scoring.predict, "fixed ownership prediction must not run in cycling Blitz")
check(standard.rules.scoring.predict and standard.rules.capture.holdSeconds == nil, "Blitz cannot mutate standard rules")
check(standard.rulesKey ~= blitz.rulesKey and standard.rulesKey ~= classic.rulesKey, "learned rates cannot mix clients or modes")
check(classic.rules.scoring.seedRates and not standard.rules.scoring.seedRates, "Cata rate seeds cannot leak into Retail")
check(bg(cata, 529, "blitz") == classic, "Cata has no Blitz mode")
for _, rated in ipairs({ bg(cata, 489, "rated"), bg(cata, 529, "rated"), bg(retail, 2107, "rated") }) do
  check(rated.mode == "rated" and rated.rules.resurrection.period == 45, "rated battlegrounds resurrect every 45 seconds")
end
check(bg(cata, 489).rules.resurrection.period == 30, "rated period cannot leak into standard games")
check(bg(cata, 529, "rated").rulesKey ~= classic.rulesKey, "rated games learn separately")

local warsong = bg(cata, 489).rules.graveyards
check(warsong.single and warsong.static and #warsong.static == 2, "Cata Warsong has one match graveyard per faction")
check(warsong.static[1].id == 771 and warsong.static[1].team == "A"
  and warsong.static[2].id == 772 and warsong.static[2].team == "H", "Warsong excludes prematch flag-room spawns")
check(not bg(retail, 2106).rules.graveyards.static and not bg(retail, 489).rules.graveyards.static,
  "Cata Warsong positions cannot leak into Retail maps")

local twinGYs = bg(cata, 726).rules.graveyards.static
check(twinGYs and #twinGYs == 4, "Cata Twin Peaks defines both graveyards for each faction")
check(not bg(retail, 726).rules.graveyards.static, "Cata graveyard IDs cannot leak into Retail")
local gyIDs, teams = {}, { A = 0, H = 0 }
for _, gy in ipairs(twinGYs) do
  check(not gyIDs[gy.id] and gy.label and gy.x > 0 and gy.x < 1 and gy.y > 0 and gy.y < 1,
    "static graveyards need unique IDs, names and valid map positions")
  gyIDs[gy.id], teams[gy.team] = true, teams[gy.team] + 1
end
check(teams.A == 2 and teams.H == 2, "Twin Peaks must keep two distinct Horde and Alliance locations")

local gilneas = bg(cata, 761).rules.graveyards
check(gilneas.static and #gilneas.static == 2 and gilneas.nodes and #gilneas.nodes == 3,
  "Cata Gilneas needs two permanent starts and three ownership-controlled graveyards")
check(not bg(retail, 761).rules.graveyards.static and not bg(retail, 761).rules.graveyards.nodes,
  "verified Cata Gilneas data cannot leak into Retail")
local gilneasIDs = {}
for _, list in ipairs({ gilneas.static, gilneas.nodes }) do
  for _, gy in ipairs(list) do
    check(not gilneasIDs[gy.id] and gy.label and gy.x > 0 and gy.x < 1 and gy.y > 0 and gy.y < 1,
      "Gilneas graveyards need unique IDs, labels and valid map positions")
    gilneasIDs[gy.id] = true
  end
end
for _, gy in ipairs(gilneas.nodes) do
  check(gy.node and gy.node.name and gy.node.x and gy.node.y
    and (gy.x ~= gy.node.x or gy.y ~= gy.node.y), "Gilneas resurrection points are separate from capture flags")
end

for _, ns in ipairs({ retail, cata }) do
  local normal, rated = bg(ns, 566), bg(ns, 968)
  check(not normal.rules.capture.seconds, "normal Eye uses proximity control")
  check(rated.rules.capture.seconds == 60, "rated Eye uses timed flag assaults")
  check(normal.rulesKey ~= rated.rulesKey, "Eye variants need separate caches")
end
for _, instance in ipairs({ 727, 1803, 2656 }) do
  local rules = bg(retail, instance).rules
  check(rules.graveyards.mode == "none", "resource/cart POIs must not become graveyards")
  check(not rules.capture.seconds and not rules.scoring.predict, "unsupported objectives must not get invented timers")
end
local ok = pcall(retail.RegisterBattleground, { id = "arathi_basin", name = "Duplicate", kind = "nodes", clients = { retail = {} } })
check(not ok, "duplicate config must fail at load time")
retail.RegisterBattleground({ id = "fixture", name = "Fixture", kind = "nodes", size = 10,
  clients = { retail = { inst = { 999999 }, rules = { graveyards = { names = {} }, capture = { seconds = false } } } },
  rules = { graveyards = { mode = "names", names = { "old" } }, capture = { seconds = 60 } },
})
local fixture = bg(retail, 999999).rules
check(next(fixture.graveyards.names) == nil, "an empty override list must clear inherited names")
check(fixture.graveyards.mode == "names" and fixture.capture.seconds == false, "named groups merge and false disables inherited rules")
-- Battleground names come from the client in its language; English without one.
check(bg(retail, 2107).name == "Arathi Basin" and bg(cata, 489).name == "Warsong Gulch", "English names without a client")
local zones = { [1339] = "Ущелье Песни Войны", [1366] = "Arathibecken" }
C_Map = { GetMapInfo = function(id) return zones[id] and { name = zones[id] } or nil end }
GetRealZoneText = function(id) return id == 30 and "奥特兰克山谷" or nil end
local localized = loadConfig("retail")
C_Map, GetRealZoneText = nil, nil
check(bg(localized, 2106).name == "Ущелье Песни Войны", "Russian name from the UI map")
check(bg(localized, 2107).name == "Arathibecken", "German name from the UI map")
check(bg(localized, 30).name == "奥特兰克山谷", "Chinese name from the instance")
check(bg(localized, 1191).name == "Ashran", "a map the client does not name keeps English")

print("Battleground configuration: " .. checks .. " checks passed")
