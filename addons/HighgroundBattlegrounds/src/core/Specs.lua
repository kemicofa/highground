local _, ns = ...
local Core = ns.Core

-- Specs
---------------------------------------------------------------------------
Core.specByName = {} -- [classToken][localized spec name] = specID
Core.classSpecs = {} -- [classToken] = { specID, ... }
Core.specInfo = {} -- [specID] = { name, icon, role, class }
Core.specIndex = {} -- [specID] = talent-tree index within its class

function Core.BuildSpecLookup()
  local function readInfo(get, ...)
    if type(get) ~= "function" then return end
    local ok, id, name, _, icon, role = pcall(get, ...)
    if ok and type(id) == "number" and id > 0 and type(name) == "string" and name ~= "" then
      return id, name, icon, role
    end
  end
  for _, classID in ipairs(ns.ClassIDs) do
    local _, classFile = GetClassInfo(classID)
    if classFile then
      local byIndex = ns.SpecsByIndex and ns.SpecsByIndex[classFile]
      local fallbacks = ns.SpecFallbacks and ns.SpecFallbacks[classFile]
      Core.specByName[classFile] = {}
      Core.classSpecs[classFile] = {}
      -- Cata has exactly three talent trees even when the modern count API
      -- is absent or returns zero. Retail continues to use its client count.
      local count = byIndex and #byIndex or ns.Api.NumSpecializationsForClassID(classID) or 0
      for i = 1, count do
        local fallback = fallbacks and fallbacks[i]
        -- Forever lists trees by fixed ID: its client may still number specs
        -- like retail (four druid specs), which would shift the trees.
        local specID, name, icon, role
        if not ns.PreferSpecFallbacks then specID, name, icon, role = readInfo(GetSpecializationInfoForClassID, classID, i) end
        if not specID and fallback then
          specID, name, icon, role = readInfo(GetSpecializationInfoByID, fallback[1])
          if not specID then
            specID, name, role, icon = fallback[1], fallback[2], fallback[3], fallback[4]
          end
        end
        if specID then
          Core.specByName[classFile][name] = specID
          if fallback then
            Core.specByName[classFile][fallback[2]] = specID
            if fallback[5] then Core.specByName[classFile][fallback[5]] = specID end
          end
          Core.classSpecs[classFile][i] = specID
          Core.specInfo[specID] = { name = name, icon = icon, role = role, class = classFile }
          Core.specIndex[specID] = i
          -- Cata data is keyed by talent-tree index, not spec ID.
          if byIndex and byIndex[i] then
            ns.Specs[specID] = byIndex[i]
          end
        end
      end
    end
  end
end

function Core.BaseProfile(specID)
  return ns.Specs[specID] or ns.RoleDefaults[Core.specInfo[specID] and Core.specInfo[specID].role or "DAMAGER"]
end

-- Spec ratings can be overridden in the options page
-- (HighgroundDB.specRatings[specID] = { k = squishiness, i = kill value }).
Core.profileCache = {}
function Core.Profile(specID)
  local base = Core.BaseProfile(specID)
  local ov = Core.db and Core.db.specRatings and Core.db.specRatings[specID]
  if not ov then
    return base
  end
  local c = Core.profileCache[specID]
  if not c then
    c = setmetatable({ k = ov.k or base.k, i = ov.i or base.i }, { __index = base })
    Core.profileCache[specID] = c
  end
  return c
end

-- Tree index with the most points in a trait-tree loadout (WoW Forever,
-- whose specialization index stays on the first tree): yours, or the
-- points list of an inspected player. False with no points spent, nil
-- when the client has no tree groups.
function Core.SpentTree(cls, points)
  points = points or ns.Api.TalentTreePoints()
  if not points then return end
  local byName, tree, most = Core.specByName[cls] or {}, false, 0
  for i, t in ipairs(points) do
    if t.spent > most then
      local id = byName[t.name]
      tree, most = id and Core.specIndex[id] or i, t.spent
    end
  end
  return tree
end

function Core.UpdateMe()
  local _, cls = UnitClass("player")
  Core.me.class = cls
  local idx = ns.Api.Specialization()
  if ns.SpecsByIndex then
    -- Cata's talent-tab IDs can differ from specialization IDs. Resolve the
    -- selected tree through the same catalog used for enemy scoreboard names.
    local trees = Core.classSpecs[cls] or {}
    local tree = Core.SpentTree(cls)
    if tree == nil then tree = idx end
    if tree ~= false and not trees[tree] then tree = GetPrimaryTalentTree and GetPrimaryTalentTree() end
    if tree ~= false and not trees[tree] and GetTalentTabInfo then
      tree = nil
      local most = 0
      for t = 1, 3 do
        local ok, _, _, _, _, spent = pcall(GetTalentTabInfo, t)
        if ok and type(spent) == "number" and spent > most then
          tree, most = t, spent
        end
      end
    end
    Core.me.specID = trees[tree]
  else
    Core.me.specID = type(idx) == "number" and idx > 0 and ns.Api.SpecializationInfo(idx) or nil
  end
  local p = Core.me.specID and ns.Specs[Core.me.specID]
  Core.me.dmg = p and p.dmg or "magic"
  Core.me.melee = p and p.melee or false
  Core.me.range = ns.RangeConfig(cls, Core.me.specID)
end

-- Spec from an earlier match: our own history first, then BattleGroundEnemiesFixed's.
function Core.HistoricSpec(key, class)
  local h = ns.Scope.Saved("history", "social")[key]
  local name = type(h) == "table" and h.class == class and type(h.spec) == "string" and h.spec or nil
  if not name and not ns.Caps.rulesetRealms then
    local bge = BattleGroundEnemiesDB and BattleGroundEnemiesDB.global
    local ph = bge and bge.PlayerHistory and bge.PlayerHistory[key]
    if ph and ph.classToken == class and type(ph.lastSpec) == "string" then
      name = ph.lastSpec
    end
  end
  return name and Core.specByName[class] and Core.specByName[class][name]
end

function Core.RecordSpecMana(e, id)
  if not ns.SpecInferenceConfig then return end
  local observed = e.specManaObservation
  local tree = id and Core.specIndex[id]
  if not tree or not observed or GetTime() - observed.at > ns.SpecInferenceConfig.mana.observationSeconds then return end
  e.sampledSpecs = e.sampledSpecs or {}
  if e.sampledSpecs[tree] then return end
  ns.RecordSpecMana(ns.Scope.Saved("fingerprints", "rules"), e.class, tree, observed.mana, observed.level)
  e.sampledSpecs[tree] = true
end

-- Combat log (Cata): an enemy casting a talent-tree ability. Only a
-- scoreboard spec outranks it.
function Core.SpecFromLog(srcName, spellName)
  local e = Core.enemies[Core.Canon(srcName) or ""]
  if not e or e.specSrc == "live" or not ns.SpecFromCast then return end
  local tree, reason = ns.SpecFromCast(e.class, spellName)
  local id = tree and Core.classSpecs[e.class] and Core.classSpecs[e.class][tree]
  if id then e.specID, e.specSrc, e.specReason = id, "cast", reason end
end

---------------------------------------------------------------------------
-- Druid forms (WoW Forever). Enemy buffs, casts and specs are hidden there,
-- but not a druid's power type: mana in caster or Moonkin form, rage in
-- bear, energy in cat. Mostly on mana over a match suggests Restoration (a
-- healer stays out of form); mostly rage or energy suggests Feral. Moonkin
-- form, which only Balance has, shows in the druid's model where the game
-- lets addons read it; otherwise Balance reads as Restoration until tagged.
-- The weakest evidence: the scoreboard, casts, buffs, history and tags win.
---------------------------------------------------------------------------
Core.FORM_MIN_SAMPLES = 40 -- scans seeing the druid (10 s at the 0.25 s tick)
Core.FORM_HEALER, Core.FORM_HEALER_KEEP = 0.75, 0.6 -- mana share to guess, then keep, Restoration
Core.FORM_FERAL, Core.FORM_FERAL_KEEP = 0.5, 0.6 -- mana share at most to guess, then keep, Feral
local FORM_MANA = { [0] = true, [1] = false, [3] = false } -- power types: mana, rage, energy
local FORM_BALANCE, FORM_FERAL, FORM_HEALER = 1, 2, 3 -- classic tree order
local FORM_REASON = {
  [FORM_BALANCE] = "battlegrounds.specs.being_seen_in_moonkin_form.c2d018",
  [FORM_HEALER] = "battlegrounds.specs.little_time_in_cat_or_bear_form.bc14c5",
  [FORM_FERAL] = "battlegrounds.specs.much_time_in_cat_or_bear_form.fb8b7a",
}

-- Moonkin model file IDs. Tauren and Night Elf druids are thought to share
-- one; a later druid race may bring its own. Model IDs read from enemy
-- druids are counted in HighgroundDB.liveStats.druidModels to find it.
Core.MOONKIN_MODELS = { [7581785] = true } -- read from a Tauren outside a match, 2026-11-24
Core.MODEL_EVERY = 5 -- seconds between model reads of one druid
Core.MODEL_WAIT = 2 -- seconds before an unloaded model counts as unread
Core.MODEL_TRIES = 5 -- unread models before giving up, unless one was read
local model, reading, unread, modelRead -- one hidden model, one read at a time

local function Model()
  if model == nil then
    model = false
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
    if ok and m and type(m.SetUnit) == "function" and type(m.GetModelFileID) == "function" then
      m:SetSize(1, 1); m:SetPoint("BOTTOMLEFT"); m:SetAlpha(0)
      m:SetScript("OnModelLoaded", function() Core.ReadDruidModel() end)
      model = m
    end
  end
  return model or nil
end

-- The file ID of the model last asked for; nil while it loads or is secret.
function Core.ReadDruidModel()
  local r = reading
  if not (r and model) then return end
  local ok, id = pcall(model.GetModelFileID, model)
  id = ok and ns.Util.value(id) or nil
  if type(id) == "number" and id > 0 then
    reading, modelRead, r.e.modelAt = nil, true, GetTime()
    Core.Stat("druidModels", id)
    if Core.MOONKIN_MODELS[id] then r.e.moonkin = true end
  elseif GetTime() - r.at >= Core.MODEL_WAIT then
    reading, unread, r.e.modelAt = nil, (unread or 0) + 1, GetTime()
    Core.Stat("druidModels", "unread")
  end
end

local function AskModel(e, unit)
  if reading then
    Core.ReadDruidModel()
    if reading then return end
  end
  if e.moonkin or not modelRead and (unread or 0) >= Core.MODEL_TRIES then return end
  if GetTime() - (e.modelAt or -Core.MODEL_EVERY) < Core.MODEL_EVERY or not Model() then return end
  reading = { e = e, at = GetTime() }
  if not pcall(model.SetUnit, model, unit) then reading = nil; unread = (unread or 0) + 1 end
end

function Core.EstimateDruidForm(e, ptype, level, unit)
  if e.class ~= "DRUID" or FORM_MANA[ptype] == nil then return end
  e.formSeen = (e.formSeen or 0) + 1
  if FORM_MANA[ptype] then
    e.formMana = (e.formMana or 0) + 1
    if unit then AskModel(e, unit) end
  end
  local src = e.specSrc
  if src ~= nil and src ~= "form" then return end
  if not e.moonkin and e.formSeen < Core.FORM_MIN_SAMPLES then return end
  local share, current = (e.formMana or 0) / e.formSeen, src == "form" and e.formTree
  local tree
  if e.moonkin then
    tree = FORM_BALANCE -- Restoration and Feral have no Moonkin form
  elseif share >= Core.FORM_HEALER or current == FORM_HEALER and share >= Core.FORM_HEALER_KEEP then
    -- Cat form comes at level 20: younger druids are all on mana.
    if not (type(level) == "number" and level < 20) then tree = FORM_HEALER end
  elseif share <= Core.FORM_FERAL or current == FORM_FERAL and share <= Core.FORM_FERAL_KEEP then
    tree = FORM_FERAL
  end
  local id = tree and Core.classSpecs.DRUID and Core.classSpecs.DRUID[tree]
  if id then
    e.specID, e.specSrc, e.specReason, e.formTree = id, "form", ns.Locale:Get(FORM_REASON[tree]), tree
  elseif src == "form" then
    e.specID, e.specSrc, e.specReason, e.formTree = nil, nil, nil, nil
  end
end

function Core.EstimateSpec(e, auras)
  if not ns.SpecInferenceConfig then return end
  if e.specSrc == "live" then
    if GetTime() - (e.liveSpecAt or -math.huge) <= 3 then Core.RecordSpecMana(e, e.specID) end
    return
  end
  if e.specSrc == "cast" then return end -- a talent-tree cast outranks buffs and mana
  if auras and auras.specConflict then
    if e.specSrc == "aura" or e.specSrc == "mana" then
      e.specID, e.specSrc, e.specReason = nil, nil, nil
      if Core.ApplySpecTag then Core.ApplySpecTag(e) end
    end
    return
  end
  local tree, reason, source
  if auras and auras.specTree then
    tree, reason, source = auras.specTree, auras.specReason, "aura"
  elseif e.specSrc == "aura" or e.specSrc == "hist" or e.specSrc == "tag" then
    return -- keep stronger evidence when its buff expires or the unit leaves sight
  elseif e.specManaObservation then
    local observed = e.specManaObservation
    tree, reason = ns.SpecFromMana(ns.Scope.Saved("fingerprints", "rules"), e.class, observed.mana, observed.level)
    if not tree then
      tree, reason = ns.SpecFromRole(e.class, observed.mana, observed.level, auras and auras.markers)
    end
    source = "mana"
  else
    return
  end
  local id = tree and Core.classSpecs[e.class] and Core.classSpecs[e.class][tree]
  if id then
    e.specID, e.specSrc, e.specReason = id, source, reason
  elseif e.specSrc == "mana" then
    e.specID, e.specSrc, e.specReason = nil, nil, nil
  end
end
