local root = arg[1] or "."
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
  local toc = flavor == "retail" and "Highground.toc" or "Highground_Cata.toc"
  for line in io.lines(root .. "/" .. toc) do
    line = line:match("^%s*(.-)%s*$")
    if line == "features/battlegrounds/core/State.lua" then break end
    if line:match("%.lua$") then assert(loadfile(root .. "/" .. line))("Highground", ns) end
  end
  assert(ns.CLIENT == flavor and ns.RangeConfig and ns.AssaultStacks and ns.TrackCooldown)
  local state = { classID = 11, index = 2, now = 100, visible = true, answers = {}, auras = {}, buffs = {} }
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
    ns = ns, me = {}, db = { executePct = 0.35, history = {} }, enemies = { Enemy = enemy }, unitFor = {},
    classSpecs = {}, specByName = {}, specInfo = {}, specIndex = {},
    O = function(key)
      for _, def in ipairs(ns.OptionsConfig.behavior) do if key == def.key then return def.def end end
    end,
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
    Canon = function(name) return name end,
    DisplayName = function(name) return name end,
    UnitName = function() return "Player" end,
    date = function() return "12:00:00" end,
    GetNumBattlefieldScores = function() return #(state.scores or {}) end,
    GetBattlefieldScore = function(index)
      local row = state.scores[index]
      return row.name, 0, 0, 0, 0, row.faction, "Human", "Class", row.classToken,
        0, 0, 0, 0, 0, 0, row.talentSpec
    end,
    UnitExists = function(unit) return state.visible and unit == "target" end,
    CanonUnit = function() return "Enemy" end,
    GetTime = function() return state.now end,
    CombatLogGetCurrentEventInfo = function()
      return state.now, state.event, nil, nil, state.source or "Enemy", nil, nil, nil,
        state.destination or "Enemy", nil, nil, state.spellID, state.spellName
    end,
    time = function() return state.now end,
    UnitIsDeadOrGhost = function() return false end,
    UnitPowerMax = function() return state.maxMana end,
    UnitPower = function() return state.mana or state.maxMana end,
    UnitLevel = function() return state.level end,
    UnitHealthMax = function() end, UnitHealth = function() end,
    UnitPowerType = function() return state.powerType end,
    UnitIsUnit = function(a, b) return a == b end,
    GetRaidTargetIndex = function() end, UnitCastingInfo = function() end, UnitChannelInfo = function() end,
    C_Spell = { IsSpellInRange = function(id) return state.answers[id] end },
    C_UnitAuras = {
      GetUnitAuras = function(_, filter)
        return filter == "HARMFUL|CROWD_CONTROL" and state.auras or {}
      end,
      GetAuraDataByIndex = function(_, index, filter)
        return (filter == "HARMFUL" and state.auras or state.buffs)[index]
      end,
    },
    Profile = function(id) return ns.Specs[id] end,
    MatchupEdge = function() return 0 end,
    W = function() return 1 end,
    P = function(name)
      local values = { killPer = 6, impactPer = 4, matchupPer = 6,
        stun = 12, rangeFar = 4, rangeUnseen = -20, burst = 8, defensiveUp = -25, spent = 15 }
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
  ns.Core = env
  env.On = function(key) return env.db[key] ~= false end
  assert(loadfile("libs/ui/Theme.lua"))("Highground", ns) -- colours for alerts
  for _, name in ipairs({ "Specs", "Objectives", "Cooldowns", "Scoring", "Roster", "Auras", "Units", "Capping", "SapCall", "Targeting", "CombatLog" }) do
    -- Scoring and Targeting are Highground's own; the rest is the battleground engine.
    local own = name == "Scoring" or name == "Targeting"
    local chunk = assert(loadfile((own and "core/" or "features/battlegrounds/core/") .. name .. ".lua"))
    setfenv(chunk, env)("Highground", ns)
  end
  local core = ns.Core
  core.BuildKits()
  return state, ns, env, core, enemy
end

return client, classes
