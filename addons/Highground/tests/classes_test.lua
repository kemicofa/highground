-- Class configuration per client. Run from addons/Highground:
-- luajit tests/classes_test.lua
local t = dofile("../../tools/harness.lua")()
local test = t.test

local function loadConfig(client)
  local ns = {}
  assert(loadfile("features/battlegrounds/config/Shared.lua"))("Highground", ns)
  assert(loadfile("features/battlegrounds/config/" .. client .. "/Classes.lua"))("Highground", ns)
  if client == "cata" then
    assert(loadfile("features/battlegrounds/config/cata/Auras.lua"))("Highground", ns)
    assert(loadfile("features/battlegrounds/config/cata/Kits.lua"))("Highground", ns)
  end
  return ns
end

local retail, cata
test("shared configuration contains no client mechanics", function()
  local ns = {}
  assert(loadfile("features/battlegrounds/config/Shared.lua"))("Highground", ns)
  assert(ns.Armor and ns.RoleDefaults)
  for key in pairs(ns) do
    assert(key == "Armor" or key == "RoleDefaults", "client data leaked into Shared: " .. key)
  end
end)

test("each client loads without the other client's configuration", function()
  retail, cata = loadConfig("retail"), loadConfig("cata")
  assert(retail.CLIENT == "retail" and cata.CLIENT == "cata")
  assert(retail.Specs[1480] and retail.Specs[270] and retail.Specs[1468])
  assert(retail.SpecsByIndex == nil and retail.Kits == nil and retail.Defensives == nil)
  assert(next(cata.Specs) == nil, "Cata spec IDs must be populated from its own talent trees")
  assert(cata.SpecsByIndex.MONK == nil and cata.SpecsByIndex.DEMONHUNTER == nil)
  assert(cata.SpecsByIndex.EVOKER == nil and next(cata.Matchups) == nil)
  for _, ns in ipairs({ retail, cata }) do
    assert(ns.Armor and ns.RoleDefaults and ns.RangeBands and ns.ProximityBonus)
    assert(ns.Specs and ns.Matchups)
  end
  assert(retail.RangeBands ~= cata.RangeBands and retail.ProximityBonus ~= cata.ProximityBonus)
end)

test("all Cata classes have three independent talent profiles and a class kit", function()
  local classes = {
    "DEATHKNIGHT", "DRUID", "HUNTER", "MAGE", "PALADIN",
    "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
  }
  local seen, count = {}, 0
  for _, class in ipairs(classes) do
    local profiles = assert(cata.SpecsByIndex[class], class)
    assert(#profiles == 3, class .. " talent tree count")
    assert(cata.RangeBands[class] and cata.Kits[class] and cata.Armor[class])
    for _, profile in ipairs(profiles) do
      assert(profile.k and profile.i and profile.short)
      assert(({ phys = true, magic = true, mixed = true })[profile.dmg], class .. " invalid damage type")
      assert(not seen[profile], "talent profiles must not share a mutable table")
      seen[profile] = true
    end
  end
  for _ in pairs(cata.SpecsByIndex) do count = count + 1 end
  assert(count == #classes)
end)

test("melee hybrid specs override caster attack and reach ranges", function()
  for _, id in ipairs({ 103, 104, 263, 255 }) do
    local profile = retail.Specs[id]
    assert(profile.melee and profile.range.attackYards == 5)
    assert(profile.range.reachYards < 40, "melee target selection must exclude the caster-only 40-yard band")
  end
  for _, class in ipairs({ "DRUID", "SHAMAN" }) do
    local melee = cata.SpecsByIndex[class][2]
    assert(melee.melee and melee.range.attackYards == 5)
    assert(melee.range.reachYards < cata.RangeBands[class].reachYards)
    assert(cata.SpecsByIndex[class][1].range == nil, "caster tree should retain class range")
  end
  assert(retail.Specs[255].melee and not cata.SpecsByIndex.HUNTER[3].melee,
    "Survival is melee only on Retail")
end)

test("ranged specs in melee classes use damage probes beyond melee", function()
  local devourer = retail.Specs[1480].range
  assert(devourer.attackYards == 25 and devourer.reachYards == 25)
  assert(devourer.bands[1][1] == 25 and devourer.bands[1][2][1] == 473662)
  assert(devourer.bands ~= retail.RangeBands.DEMONHUNTER.bands)
  assert(retail.Specs[65].range.attackYards == 30)
  assert(retail.Specs[270].range.attackYards == 40)
  assert(cata.SpecsByIndex.PALADIN[1].range.attackYards == 30)
  assert(retail.Specs[70].range == nil and cata.SpecsByIndex.PALADIN[3].range == nil)
end)

test("every recognized Cata defensive has a matching cooldown entry", function()
  local bySpell = {}
  for class, kit in pairs(cata.Kits) do
    for _, entry in ipairs(kit) do
      assert(entry[2] > 0, class .. " cooldown duration")
      assert(not entry.spec or cata.SpecsByIndex[class][entry.spec], class .. " invalid talent tree")
      for _, id in ipairs({ entry[1], unpack(entry.alt or {}) }) do
        assert(not bySpell[id], "ambiguous cooldown alias " .. id)
        bySpell[id] = entry
      end
    end
  end
  for id, defensive in pairs(cata.Defensives) do
    local entry = assert(bySpell[id], "untracked defensive " .. id)
    assert(entry[2] == defensive[1], "defensive and kit durations disagree for " .. id)
  end
  assert(bySpell[31850].spec == 2 and bySpell[31850][3] == "def", "Ardent Defender belongs to Protection")
  assert(bySpell[81782] == bySpell[62618], "Barrier aura and cast must share one cooldown")
end)

t.finish(string.format("Class configuration: %d tests passed", t.tests))
