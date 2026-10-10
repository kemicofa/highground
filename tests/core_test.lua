-- Run from the addon directory: luajit tests/core_test.lua
-- Exercise the real Core functions without constructing protected WoW UI.
-- Client APIs are fixtures; configuration is loaded in each TOC's order.
local root = arg[1] or "."
local checks, failures = 0, 0
local function test(name, run)
  local ok, err = pcall(run)
  checks = checks + 1
  if ok then
    print("PASS " .. name)
  else
    failures = failures + 1
    io.stderr:write("FAIL " .. name .. ": " .. tostring(err) .. "\n")
  end
end

local file = assert(io.open(root .. "/Core.lua"))
local source = file:read("*a")
file:close()
local function section(first, following)
  local start = assert(source:find(first, 1, true), first)
  local finish = assert(source:find(following, start + #first, true), following)
  return source:sub(start, finish - 1)
end

local classes = {
  [1] = { "WARRIOR", { 71, 72, 73 } }, [2] = { "PALADIN", { 65, 66, 70 } },
  [3] = { "HUNTER", { 253, 254, 255 } }, [4] = { "ROGUE", { 259, 260, 261 } },
  [5] = { "PRIEST", { 256, 257, 258 } }, [6] = { "DEATHKNIGHT", { 250, 251, 252 } },
  [7] = { "SHAMAN", { 262, 263, 264 } }, [8] = { "MAGE", { 62, 63, 64 } },
  [9] = { "WARLOCK", { 265, 266, 267 } }, [10] = { "MONK", { 268, 270, 269 } },
  [11] = { "DRUID", { 102, 103, 104, 105 } }, [12] = { "DEMONHUNTER", { 577, 581, 1480 } },
  [13] = { "EVOKER", { 1467, 1468, 1473 } },
}

local function client(flavor)
  local ns = {}
  local toc = flavor == "retail" and "Warboard.toc" or "Warboard_Cata.toc"
  for line in io.lines(root .. "/" .. toc) do
    line = line:match("^%s*(.-)%s*$")
    if line == "Core.lua" then break end
    if line:match("%.lua$") then assert(loadfile(root .. "/" .. line))("Warboard", ns) end
  end
  assert(ns.CLIENT == flavor and ns.RangeConfig and ns.AssaultStacks and ns.TrackCooldown)
  local state = { classID = 11, index = 2, now = 100, visible = true, answers = {}, auras = {} }
  local function classInfo(id)
    if flavor == "cata" and (id == 10 or id > 11) then return nil end
    return classes[id]
  end
  local function specInfo(id, index)
    local class = classInfo(id)
    if not class then return nil end
    local spec = flavor == "retail" and class[2][index] or index <= 3 and id * 1000 + index
    if spec then return spec, class[1] .. index, "Description", 1, "DAMAGER" end
  end
  local enemy = { key = "Enemy", class = "MAGE", specID = flavor == "retail" and 62 or 8001 }
  local env = setmetatable({
    ns = ns, me = {}, db = { executePct = 0.35 }, enemies = { Enemy = enemy }, unitFor = {},
    classSpecs = {}, specByName = {}, specInfo = {}, specIndex = {},
    BURN_WINDOW = 60,
    plain = function(v) return v ~= nil and not (type(v) == "table" and v.secret) end,
    issecret = function(v) return type(v) == "table" and v.secret == true end,
    Stat = function() end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
    UnitClass = function() return classes[state.classID][1], classes[state.classID][1] end,
    GetNumClasses = function() return flavor == "retail" and 13 or 10 end,
    GetClassInfo = function(id)
      local class = classInfo(id)
      if class then return class[1], class[1], id end
    end,
    GetSpecializationInfoForClassID = specInfo,
    UnitExists = function(unit) return state.visible and unit == "target" end,
    CanonUnit = function() return "Enemy" end,
    GetTime = function() return state.now end,
    time = function() return state.now end,
    UnitIsDeadOrGhost = function() return false end,
    UnitPowerMax = function() end, UnitHealthMax = function() end, UnitHealth = function() end,
    UnitPowerType = function() end, UnitIsUnit = function() return false end,
    GetRaidTargetIndex = function() end, UnitCastingInfo = function() end, UnitChannelInfo = function() end,
    C_Spell = { IsSpellInRange = function(id) return state.answers[id] end },
    C_UnitAuras = {
      GetUnitAuras = function(_, filter)
        return filter == "HARMFUL|CROWD_CONTROL" and state.auras or {}
      end,
      GetAuraDataByIndex = function(_, index, filter)
        return filter == "HARMFUL" and state.auras[index] or nil
      end,
    },
    Profile = function(id) return ns.Specs[id] end,
    SpecScore = function() return 0, nil, 0 end,
    W = function() return 1 end,
    P = function(name)
      local values = { killPer = 6, impactPer = 4, matchupPer = 6, ccUp = -15,
        stun = 12, rangeFar = 4, rangeUnseen = -20 }
      return values[name] or 0
    end,
    CooldownBonus = function() return 0 end,
    IsHealer = function() return false end,
  }, { __index = _G })
  env.C_SpecializationInfo = {
    GetNumSpecializationsForClassID = function(id)
      local class = classInfo(id)
      return class and (flavor == "cata" and 3 or #class[2]) or 0
    end,
    GetSpecialization = function() return state.index end,
    GetSpecializationInfo = function(index) return specInfo(state.classID, index) end,
  }
  local program = section("local function BuildSpecLookup(", "local function BaseProfile(")
    .. section("local function UpdateMe(", "-- Spec from an earlier match:")
    .. section("local function CountAuras(", "-- Map enemies to their nameplate token")
    .. section("local function RangeCheck(", "local MEDIA =")
    .. section("local function InReach(", "ns.InReach = InReach")
    .. section("local function Score(e)", "-- Roster (scoreboard)")
    .. section("local function FlagStacks(", "-- Stack value shown/scored for a carrier:")
    .. "\nreturn { BuildSpecLookup = BuildSpecLookup, UpdateMe = UpdateMe, ScanUnits = ScanUnits,"
    .. " NearestBand = NearestBand, InReach = InReach, Score = Score, FlagStacks = FlagStacks }"
  local factory = assert(loadstring(program, "@Core.lua (test extraction)"))
  setfenv(factory, env)
  local core = factory()
  return state, ns, env, core, enemy
end

test("Retail melee/caster spec switches change real range selection", function()
  local s, _, env, core = client("retail")
  core.BuildSpecLookup()
  for _, case in ipairs({ { 11, 2, 8921, false }, { 11, 1, 8921, true },
    { 7, 2, 188196, false }, { 7, 1, 188196, true }, { 3, 3, 185358, false }, { 3, 2, 19434, true } }) do
    s.classID, s.index, s.answers = case[1], case[2], { [case[3]] = true }
    core.UpdateMe()
    local yards = core.NearestBand("target")
    assert(yards == 40)
    assert(core.InReach({ yards = yards }) == case[4], "wrong reach for spec " .. env.me.specID)
    if not case[4] then assert(env.me.range.attackYards == 5) end
  end
end)

test("Devourer uses its own 25-yard attack probe in ScanUnits", function()
  local s, _, env, core, enemy = client("retail")
  s.classID, s.index, s.answers = 12, 3, { [473662] = true }
  core.UpdateMe()
  core.ScanUnits()
  assert(env.me.range.attackYards == 25 and enemy.yards == 25 and enemy.range == "attack")
  assert(core.InReach(enemy) and not core.InReach({ yards = 30 }))
end)

test("Retail crowd-control category remains neutral in scoring", function()
  local s, _, _, core, enemy = client("retail")
  core.UpdateMe()
  core.ScanUnits()
  core.Score(enemy)
  local baseline = enemy.live
  s.auras = { { spellId = 853 } } -- Hammer of Justice: non-breakable stun
  core.ScanUnits()
  core.Score(enemy)
  assert(enemy.crowdControlled and enemy.cc == false and enemy.stun == false)
  assert(enemy.comp.cc == nil and enemy.comp.stun == nil and enemy.live == baseline)
  assert(not table.concat(enemy.reasons, " "):find("don't break", 1, true))
  s.visible, s.now = false, 106
  core.ScanUnits()
  assert(not enemy.crowdControlled, "stale generic CC must clear after losing sight")
end)

test("Cata maps all 30 talent trees including class ID 11", function()
  local _, ns, env, core = client("cata")
  core.BuildSpecLookup()
  local total = 0
  for classID, class in pairs(classes) do
    local profiles = ns.SpecsByIndex[class[1]]
    if profiles then
      for index, profile in ipairs(profiles) do
        assert(ns.Specs[classID * 1000 + index] == profile, "missing Cata " .. class[1] .. " tree " .. index)
        assert(env.classSpecs[class[1]][index] == classID * 1000 + index)
        total = total + 1
      end
    end
  end
  assert(total == 30)
end)

test("Cata primary-tree fallback supplies mapped melee range", function()
  local s, _, env, core = client("cata")
  core.BuildSpecLookup()
  env.C_SpecializationInfo.GetSpecialization = nil
  env.C_SpecializationInfo.GetSpecializationInfo = nil
  env.GetPrimaryTalentTree = function() return s.index end
  core.UpdateMe()
  assert(env.me.specID == 11002 and env.me.melee and env.me.range.attackYards == 5)
  assert(not core.InReach({ yards = 40 }))
  s.index = 1
  core.UpdateMe()
  assert(env.me.specID == 11001 and core.InReach({ yards = 40 }))
end)

test("Cata points-spent fallback selects its own talent-tree profile", function()
  local _, _, env, core = client("cata")
  core.BuildSpecLookup()
  env.C_SpecializationInfo.GetSpecialization = nil
  env.C_SpecializationInfo.GetSpecializationInfo = nil
  env.GetTalentTabInfo = function(index)
    return index, "Tree", "Description", 1, ({ 2, 31, 8 })[index]
  end
  core.UpdateMe()
  assert(env.me.specID == 11002 and env.me.melee and env.me.range.attackYards == 5)
end)

test("missing specialization APIs retain a usable class range fallback", function()
  local _, ns, env, core = client("cata")
  env.C_SpecializationInfo = nil
  env.GetSpecializationInfoForClassID = nil
  core.BuildSpecLookup()
  core.UpdateMe()
  assert(env.me.specID == nil and env.me.class == "DRUID")
  assert(env.me.range == ns.RangeBands.DRUID and core.InReach({ yards = 40 }))
end)

test("Cata retains separate breakable CC and stun scoring", function()
  local s, _, _, core, enemy = client("cata")
  core.BuildSpecLookup()
  core.UpdateMe()
  s.auras = { { spellId = 853 } }
  core.ScanUnits()
  core.Score(enemy)
  assert(enemy.stun and not enemy.cc and enemy.comp.stun == 12)
  s.auras = { { spellId = 118 } }
  core.ScanUnits()
  core.Score(enemy)
  assert(enemy.cc and not enemy.stun and enemy.comp.cc == -15)
end)

test("actual flag stack caller honors Cata, Retail and Blitz boundaries", function()
  for _, flavor in ipairs({ "cata", "retail" }) do
    local s, ns, env, core = client(flavor)
    for _, mode in ipairs({ "standard", "blitz" }) do
      env.currentBG = assert(ns.ResolveBattleground(1460, 489, flavor, mode))
      env.obj = { mode = "flag", assaultStart = 100 }
      local rules = env.currentBG.rules.flags
      s.now = 100 + rules.firstStackSeconds - 1
      assert(core.FlagStacks() == nil)
      s.now = s.now + 1
      assert(core.FlagStacks() == 1)
      s.now = s.now + rules.stackInterval
      assert(core.FlagStacks() == 2)
      if flavor == "cata" then
        assert(rules.firstStackSeconds == 180 and rules.stackInterval == 60)
        s.now = 10000
        assert(core.FlagStacks() == 10)
      end
      env.obj.assaultStart = nil
      assert(core.FlagStacks() == nil)
    end
  end
end)

test("aura duplicates cannot extend a known defensive cooldown", function()
  local _, ns = client("cata")
  local enemy, barrier = {}, { 62618, 180, "external", "Barrier" }
  ns.TrackCooldown(enemy, barrier, "SPELL_CAST_SUCCESS", 100)
  ns.TrackCooldown(enemy, barrier, "SPELL_AURA_APPLIED", 106)
  ns.TrackCooldown(enemy, barrier, "SPELL_AURA_APPLIED", 120)
  assert(enemy.cds[62618] == 280)
  ns.TrackCooldown(enemy, barrier, "SPELL_CAST_SUCCESS", 400)
  assert(enemy.cds[62618] == 580, "a real later cast must start a new timer")
  local reset = { 11958, 480, "def", "Cold Snap", resets = { 45438 } }
  enemy.cds[45438] = 500
  ns.TrackCooldown(enemy, reset, "SPELL_CAST_SUCCESS", 401)
  assert(enemy.cds[45438] == nil and enemy.cds[11958] == 881)
end)

print(string.format("Core regressions: %d tests, %d failures", checks, failures))
if failures > 0 then os.exit(1) end
