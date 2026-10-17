-- Game data comes from the scenario; addon logic is never substituted.
return function(sim, env)
  local noop = function() end
  local classes = {
    [1] = { "WARRIOR", 71, 72, 73 }, [2] = { "PALADIN", 65, 66, 70 },
    [3] = { "HUNTER", 253, 254, 255 }, [4] = { "ROGUE", 259, 260, 261 },
    [5] = { "PRIEST", 256, 257, 258 }, [6] = { "DEATHKNIGHT", 250, 251, 252 },
    [7] = { "SHAMAN", 262, 263, 264 }, [8] = { "MAGE", 62, 63, 64 },
    [9] = { "WARLOCK", 265, 266, 267 }, [10] = { "MONK", 268, 270, 269 },
    [11] = { "DRUID", 102, 103, 104, 105 }, [12] = { "DEMONHUNTER", 577, 581, 1480 },
    [13] = { "EVOKER", 1467, 1468, 1473 },
  }
  local function read(token, field, default)
    local unit = sim.units[token]
    if unit and unit[field] ~= nil then return unit[field] end
    return default
  end
  env.wipe = function(t) for key in pairs(t) do t[key] = nil end end
  env.tinsert, env.time = table.insert, function() return math.floor(sim.now) end
  env.date = function() return "12:00:00" end
  env.GetTime = function() return sim.now end
  env.GetNormalizedRealmName = function() return "Realm" end
  env.issecretvalue = function(value) return type(value) == "table" and value.secret == true end
  env.print = function(...) sim.messages[#sim.messages + 1] = table.concat({ ... }, " ") end
  env.strsplit = function(delimiter, text)
    local parts = {}; for part in (text .. delimiter):gmatch("(.-)" .. delimiter) do parts[#parts + 1] = part end
    return unpack(parts)
  end
  env.UNKNOWNOBJECT, env.LE_PARTY_CATEGORY_INSTANCE = "Unknown", 1
  env.UnitName = function(token) return read(token, "name"), read(token, "realm", "Realm") end
  env.UnitExists = function(token) return sim.units[token] ~= nil end
  env.UnitClass = function(token)
    local id = read(token, "classID", 8); return classes[id][1], classes[id][1], id
  end
  env.UnitFactionGroup = function(token)
    local faction = sim.faction or 1
    if read(token, "enemy", false) then faction = 1 - faction end
    return faction == 1 and "Alliance" or "Horde"
  end
  env.UnitIsDeadOrGhost = function(token) return read(token, "dead", false) or read(token, "ghost", false) end
  env.UnitIsGhost = function(token) return read(token, "ghost", false) end
  env.UnitIsPlayer = env.UnitExists
  env.UnitIsConnected = function(token) return read(token, "connected", true) end
  env.UnitIsUnit = function(a, b) return sim.units[a] ~= nil and sim.units[a] == sim.units[b] end
  env.UnitCanAttack = function(_, token) return read(token, "enemy", false) end
  env.UnitHealth = function(token) return read(token, "health", 100) end
  env.UnitHealthMax = function(token) return read(token, "maxHealth", 100) end
  env.UnitPowerMax = function(token) return read(token, "maxMana", 100000) end
  env.UnitPower = function(token) return read(token, "mana", 100000) end
  env.UnitPowerType = function(token) return read(token, "powerType", 0) end
  env.UnitLevel = function(token) return read(token, "level", sim.client == "cata" and 85 or 90) end
  env.UnitGUID = function(token) return read(token, "guid") end
  env.UnitPosition = noop
  env.UnitCastingInfo, env.UnitChannelInfo = noop, noop
  env.GetRaidTargetIndex = function(token) return read(token, "marker") end
  env.GetNumGroupMembers = function() return sim.members or 1 end
  env.GetRaidRosterInfo = function(i) return env.UnitName("raid" .. i) end
  env.IsInRaid = function() return sim.raid or false end
  env.IsInGroup = function() return sim.inBG end
  env.IsInInstance = function()
    if sim.inArena then return true, "arena" end
    return sim.inBG, sim.inBG and "pvp" or "none"
  end
  env.InCombatLockdown = function() return sim.combat end
  env.IsShiftKeyDown = function() return sim.shift or false end
  env.GetInstanceInfo = function() return sim.mapName, "pvp", 0, "", 10, 0, false, sim.instanceID end
  env.GetSubZoneText = function() return sim.area end
  env.GetZoneText = function() return sim.mapName end
  env.GetRealZoneText, env.GetMinimapZoneText = env.GetZoneText, env.GetSubZoneText
  env.GetNumClasses = function() return sim.client == "cata" and 10 or 13 end
  env.GetClassInfo = function(id)
    if classes[id] and (sim.client == "retail" or id < 10 or id == 11) then return classes[id][1], classes[id][1], id end
  end
  local function spec(id, index)
    local class = classes[id]; if not class or not class[index + 1] then return end
    local fallback = sim.ns.SpecFallbacks and sim.ns.SpecFallbacks[class[1]]
    return sim.client == "cata" and id * 1000 + index or class[index + 1],
      fallback and fallback[index].name or class[1] .. index, "", 1, "DAMAGER"
  end
  env.GetSpecializationInfoForClassID = spec
  env.C_SpecializationInfo = {
    GetNumSpecializationsForClassID = function(id) return #classes[id] - 1 end,
    GetSpecialization = function() return sim.specIndex end,
    GetSpecializationInfo = function(index) return spec(sim.units.player.classID, index) end,
  }
  env.GetNumBattlefieldScores = function() return #sim.scores end
  env.GetBattlefieldScore = function(index)
    local row = sim.scores[index]; if not row then return end
    return row.name, 0, 0, 0, 0, row.faction, "Human", "Class", row.classToken, 0, 0, 0, 0, 0, 0, row.talentSpec
  end
  env.GetBattlefieldArenaFaction = function() return sim.faction or 1 end
  env.GetBattlefieldInstanceRunTime = function() return (sim.now - sim.matchStart) * 1000 end
  env.RequestBattlefieldScoreData = function() sim.scoreRequests = sim.scoreRequests + 1 end
  env.SetBattlefieldScoreFaction = function(value) sim.scoreFilter = value end
  env.C_PvP = {
    IsRatedBattleground = function() return sim.rated end,
    IsSoloRBG = function() return sim.blitz end,
    IsMatchComplete = function() return sim.matchComplete end,
    GetActiveMatchState = function() return sim.inBG and 3 or 0 end,
  }
  if sim.client == "retail" then env.C_PvP.GetScoreInfo = function(i) return sim.scores[i] end end
  env.C_Spell = {
    GetSpellTexture = function(id) return "Interface\\Icons\\Spell" .. id end,
    IsSpellInRange = function(id, token)
      local answers = read(token, "rangeAnswers", {})
      if answers[id] ~= nil then return answers[id] end
      local cfg = sim.ns.Core.me.range
      for _, band in ipairs(cfg and cfg.bands or {}) do
        for _, spell in ipairs(band[2]) do if spell == id then return read(token, "yards", 100) <= band[1] end end
      end
    end,
    GetSpellName = function(id) return "Spell " .. id end,
  }
  env.C_UnitAuras = {
    GetAuraDataByIndex = function(token, i, filter) return read(token, filter == "HARMFUL" and "debuffs" or "buffs", {})[i] end,
    GetUnitAuras = function(token, filter) return read(token, "categories", {})[filter] or {} end,
  }
  env.C_NamePlate = { GetNamePlateForUnit = function(token) return sim.plates[token] end }
  env.C_ChatInfo = {
    RegisterAddonMessagePrefix = noop,
    SendAddonMessage = function(prefix, message, channel)
      sim.sent[#sim.sent + 1] = { prefix = prefix, message = message, channel = channel, at = sim.now }
    end,
  }
  env.CombatLogGetCurrentEventInfo = function() return unpack(sim.combatEvent or {}) end
  env.GetAreaSpiritHealerTime = function() return sim.healerTime end
  env.GetNumBattlefieldFlagPositions = function() return #sim.flagPositions end
  env.GetBattlefieldFlagPosition = function(i) return unpack(sim.flagPositions[i]) end
  env.C_AreaPoiInfo = {
    GetAreaPOIForMap = function() local ids = {}; for i in ipairs(sim.pois) do ids[#ids + 1] = i end; return ids end,
    GetAreaPOIInfo = function(_, i) return sim.pois[i] end,
  }
  env.C_DeathInfo = {
    GetGraveyardsForMap = function() return sim.graveyards end,
    GetDeathReleasePosition = function() return sim.releasePosition end,
  }
  env.C_UIWidgetManager = {}
  env.PlaySound = function(id) sim.sounds[#sim.sounds + 1] = id; return true end
  env.PlaySoundFile = env.PlaySound
  env.ChatFrame_OpenChat = function(text) sim.chatDraft = text end
  env.RAID_CLASS_COLORS, env.CLASS_ICON_TCOORDS, env.LOCALIZED_CLASS_NAMES_MALE = {}, {}, {}
  for _, class in pairs(classes) do
    env.RAID_CLASS_COLORS[class[1]] = { r = 0.5, g = 0.6, b = 1 }
    env.CLASS_ICON_TCOORDS[class[1]] = { 0, 1, 0, 1 }
    env.LOCALIZED_CLASS_NAMES_MALE[class[1]] = class[1]
  end
end
