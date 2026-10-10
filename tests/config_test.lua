local loadConfig = dofile("tests/load_config.lua")
local retail, cata = loadConfig("retail"), loadConfig("cata")
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

local standard = bg(retail, 2107)
local blitz = bg(retail, 2107, "blitz")
local classic = bg(cata, 529)
check(standard.rules.capture.seconds == 60, "Retail AB duration")
check(classic.rules.capture.seconds == 65, "retain configured Whitemane AB calibration")
check(blitz.rules.capture.seconds == 30, "Blitz AB duration")
check(blitz.rules.capture.holdSeconds == 45 and blitz.rules.capture.resetSeconds == 5, "Blitz ownership cycle")
check(not blitz.rules.scoring.predict, "fixed ownership prediction must not run in cycling Blitz")
check(standard.rules.scoring.predict and standard.rules.capture.holdSeconds == nil, "Blitz cannot mutate standard rules")
check(standard.rulesKey ~= blitz.rulesKey and standard.rulesKey ~= classic.rulesKey, "learned rates cannot mix clients or modes")
check(classic.rules.scoring.seedRates and not standard.rules.scoring.seedRates, "Cata rate seeds cannot leak into Retail")
check(bg(cata, 529, "blitz") == classic, "Cata has no Blitz mode")

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
retail.RegisterBattleground({ id = "fixture", name = "Fixture", kind = "nodes",
  clients = { retail = { inst = { 999999 }, rules = { graveyards = { names = {} }, capture = { seconds = false } } } },
  rules = { graveyards = { mode = "names", names = { "old" } }, capture = { seconds = 60 } },
})
local fixture = bg(retail, 999999).rules
check(next(fixture.graveyards.names) == nil, "an empty override list must clear inherited names")
check(fixture.graveyards.mode == "names" and fixture.capture.seconds == false, "named groups merge and false disables inherited rules")
print("Battleground configuration: " .. checks .. " checks passed")
