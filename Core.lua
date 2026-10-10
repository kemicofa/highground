local ADDON, ns = ...

-- Warboard: rated-battleground kill priority for Midnight (12.1).
--
-- What Midnight lets an addon do in a rated PvP match (Blizzard API docs,
-- Gethe/wow-ui-source live branch):
--   * scoreboard name + classToken are NeverSecret -> roster + class are usable
--   * talentSpec is SecretInActivePvPMatch -> spec comes from post-match history
--   * UnitName on enemy players is readable in PvP -> nameplate/target mapping
--   * UnitHealth* are secret -> may only be DISPLAYED (StatusBar, curve alpha),
--     never compared, so health cannot change the ordering
--   * enemy cooldowns / CLEU are gone -> only active BIG/EXTERNAL defensive and
--     CROWD_CONTROL auras on a visible unit are detectable (if counts readable)
-- Everything that feeds the sort is non-secret; secrets go straight to widgets.

local issecret = issecretvalue or function() return false end
local function plain(v)
  return not issecret(v) and v ~= nil
end

-- Some clients strip globals that Blizzard's own UI still documents (the
-- Whitemane Cata 4.4.2 client has no RequestBattlefieldScoreData), so look
-- them up at call time and never pass a possibly-nil global to C_Timer.
local function RequestScores()
  local f = RequestBattlefieldScoreData or (C_PvP and C_PvP.RequestBattlefieldScoreData)
  if f then
    pcall(f)
  end
end

-- Globals Warboard calls; ADDON_LOADED records any this client lacks
-- (WarboardDB.apiMissing, shown by /wb err) so a stripped one shows up at
-- once instead of as an error deep in a match.
local API_USED = {
  "GetNumBattlefieldScores", "GetBattlefieldScore", "SetBattlefieldScoreFaction", "RequestBattlefieldScoreData",
  "GetBattlefieldInstanceRunTime", "GetBattlefieldArenaFaction", "GetNumGroupMembers", "GetRaidRosterInfo",
  "IsInRaid", "UnitName", "UnitExists", "UnitIsDeadOrGhost", "UnitHealth", "UnitHealthMax", "UnitPowerMax",
  "UnitIsUnit", "GetRaidTargetIndex", "UnitClass", "UnitFactionGroup", "IsInInstance", "GetInstanceInfo",
  "GetNumClasses", "GetClassInfo", "GetSpecializationInfoForClassID", "GetSpecialization",
  "GetSpecializationInfo", "InCombatLockdown", "PlaySound", "PlaySoundFile", "GetNormalizedRealmName",
  "IsShiftKeyDown", "CombatLogGetCurrentEventInfo", "CreateColor",
}

BINDING_HEADER_WARBOARD = "Warboard"
_G["BINDING_NAME_CLICK WarboardTargetButton:LeftButton"] = "Target kill-order #1"
_G["BINDING_NAME_CLICK WarboardMarkButton:LeftButton"] = "Ping/mark kill target"
_G["BINDING_NAME_CLICK WarboardFocusButton:LeftButton"] = "Focus kill target"

-- Game flavor. Retail (Midnight) hides most enemy data behind secret
-- values; Cataclysm Classic 4.4.2 (e.g. Whitemane Gilneas, loaded through
-- Warboard_Cata.toc + config/cata/Classes.lua) exposes health, specs and the combat
-- log, so it gets extra live signals.
local IS_RETAIL = ns.CLIENT == "retail"
ns.IS_RETAIL = IS_RETAIL

local DEFAULTS = {
  rows = 10,
  scale = 1,
  locked = false,
  allBGs = not IS_RETAIL, -- retail: rated BGs only; Cata: every battleground
  executePct = 0.35,
  sound = true,
  sniper = true,
  pressure = true,
  pressureCount = 3,
  sniperY = -62,
  sniperVersion = 4,
  sniperColor = "magenta",
  callChannel = "s",
  markIcon = 8, -- raid marker index used by WarboardMarkButton (8 = skull)
  markMode = IS_RETAIL and "ping" or "icon", -- "ping" (team ping, retail only) or "icon" (raid target icon)
  pingType = "attack",
  sniperScale = 1,
  sniperSound = 1, -- index into SNIPER_SOUNDS; 0 = off
  soundVersion = 2,
  liveSort = false,
  history = {},
}

local db
local enemies = {} -- [canonName] = entry
local order = {} -- sorted entries
ns.order = order
local unitFor = {} -- [canonName] = unit token visible this tick
local me = {}
local active, testMode = false, false
local allyFaction
local boundKey -- who the secure target button currently points at
local lastError -- first error seen this session (see Guard)

-- Readability counters, saved for diagnosis (WarboardDB.liveStats).
local function Stat(group, kind)
  db.liveStats = db.liveStats or {}
  local g = db.liveStats[group] or {}
  db.liveStats[group] = g
  g[kind] = (g[kind] or 0) + 1
end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------
local myRealm
local function Canon(name)
  if type(name) ~= "string" or issecret(name) or name == "" then
    return nil
  end
  local short, realm = name:match("^([^-]+)-(.+)$")
  if short then
    return short .. "-" .. realm:gsub("%s", "")
  end
  return name .. "-" .. (myRealm or "")
end

local function DisplayName(key)
  local short, realm = key:match("^([^-]+)-(.+)$")
  if realm == myRealm then
    return short
  end
  return key
end

local function CanonUnit(unit)
  local ok, name, realm = pcall(UnitName, unit)
  if not ok or not plain(name) or (realm ~= nil and issecret(realm)) then
    return nil
  end
  if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then
    return nil
  end
  if type(realm) == "string" and realm ~= "" then
    return Canon(name .. "-" .. realm)
  end
  return Canon(name)
end

---------------------------------------------------------------------------
-- Specs
---------------------------------------------------------------------------
local specByName = {} -- [classToken][localized spec name] = specID
local classSpecs = {} -- [classToken] = { specID, ... }
local specInfo = {} -- [specID] = { name, icon, role, class }
local specIndex = {} -- [specID] = talent-tree index within its class

local function BuildSpecLookup()
  local numSpecs = (C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID)
    or GetNumSpecializationsForClassID
  if not numSpecs or not GetSpecializationInfoForClassID then return end
  for _, classID in ipairs(ns.ClassIDs) do
    local _, classFile = GetClassInfo(classID)
    if classFile then
      specByName[classFile] = {}
      classSpecs[classFile] = {}
      for i = 1, numSpecs(classID) or 0 do
        local specID, name, _, icon, role = GetSpecializationInfoForClassID(classID, i)
        if specID and name then
          specByName[classFile][name] = specID
          table.insert(classSpecs[classFile], specID)
          specInfo[specID] = { name = name, icon = icon, role = role, class = classFile }
          specIndex[specID] = i
          -- Cata data is keyed by talent-tree index, not spec ID.
          local byIndex = ns.SpecsByIndex and ns.SpecsByIndex[classFile]
          if byIndex and byIndex[i] then
            ns.Specs[specID] = byIndex[i]
          end
        end
      end
    end
  end
end

local function BaseProfile(specID)
  return ns.Specs[specID] or ns.RoleDefaults[specInfo[specID] and specInfo[specID].role or "DAMAGER"]
end

-- Spec ratings can be overridden in the options page
-- (WarboardDB.specRatings[specID] = { k = squishiness, i = kill value }).
local profileCache = {}
local function Profile(specID)
  local base = BaseProfile(specID)
  local ov = db and db.specRatings and db.specRatings[specID]
  if not ov then
    return base
  end
  local c = profileCache[specID]
  if not c then
    c = setmetatable({ k = ov.k or base.k, i = ov.i or base.i }, { __index = base })
    profileCache[specID] = c
  end
  return c
end

local function UpdateMe()
  local _, cls = UnitClass("player")
  me.class = cls
  local getSpec = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
  local getInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
  local idx = getSpec and getSpec()
  me.specID = idx and getInfo and getInfo(idx) or nil
  if not me.specID then
    -- Whitemane's 4.4.2 client has neither: use the primary talent tree, or
    -- the tree with the most points spent.
    local tree = GetPrimaryTalentTree and GetPrimaryTalentTree()
    if not tree and GetTalentTabInfo then
      local most = 0
      for t = 1, 3 do
        local ok, _, _, _, _, spent = pcall(GetTalentTabInfo, t)
        if ok and type(spent) == "number" and spent > most then
          tree, most = t, spent
        end
      end
    end
    me.specID = tree and classSpecs[cls] and classSpecs[cls][tree] or nil
  end
  local p = me.specID and ns.Specs[me.specID]
  me.dmg = p and p.dmg or "magic"
  me.melee = p and p.melee or false
  me.range = ns.RangeConfig(cls, me.specID)
end

-- Spec from an earlier match: our own history first, then BattleGroundEnemiesFixed's.
local function HistoricSpec(key, class)
  local h = db.history[key]
  local name = h and h.class == class and h.spec
  if not name then
    local bge = BattleGroundEnemiesDB and BattleGroundEnemiesDB.global
    local ph = bge and bge.PlayerHistory and bge.PlayerHistory[key]
    if ph and ph.classToken == class and type(ph.lastSpec) == "string" then
      name = ph.lastSpec
    end
  end
  return name and specByName[class] and specByName[class][name]
end

---------------------------------------------------------------------------
-- Objectives: flag / orb carriers and their stacks
--
-- Carrier stacks can't be read off enemy units in Midnight (aura data is
-- secret), so they're simulated like BattleGroundEnemiesFixed does:
--   WSG / Twin Peaks: one shared Focused Assault clock, starts when BOTH flags
--     are held, +1 stack per 30s (15s in Blitz); drops keep it running; a
--     capture, both flags home, or match end resets it.
--   Temple of Kotmogu: per-orb clock, 30% on pickup, +30% per 15s held.
--   Eye of the Storm / Deephaul Ravine: carrier only, no stacking debuff.
-- Carrier identity: BG system chat (English client) + arena1-4 tokens, which
-- Blizzard assigns to objective carriers in battlegrounds.
---------------------------------------------------------------------------
-- Battleground identity. UI map IDs (C_Map.GetBestMapForUnit) are the ones
-- BattleGroundEnemiesFixed verified in-game; instance IDs (8th return of
-- GetInstanceInfo) are the fallback. What the game actually reports is saved
-- to WarboardDB.mapSeen so unknown/new maps can be added.
-- Identities and client/mode rules live in config/battlegrounds/*.lua.
local currentBG, currentProfile, isBlitz, mapKey

local function DetectMap()
  local ui = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local name, _, _, _, _, _, _, inst = GetInstanceInfo()
  isBlitz = IS_RETAIL and C_PvP and C_PvP.IsSoloRBG and C_PvP.IsSoloRBG() or false
  local bg = ns.ResolveBattleground(ui, inst, ns.CLIENT, isBlitz and "blitz" or "standard")
  local key = bg and bg.rulesKey or (tostring(ui) .. ":" .. tostring(inst) .. ":" .. tostring(isBlitz))
  if key == mapKey then
    return false
  end
  mapKey = key
  currentBG = bg
  currentProfile = currentBG and currentBG.rules.priority or nil
  db.mapSeen = db.mapSeen or {}
  db.mapSeen[tostring(name)] = { ui = ui, inst = inst, matched = currentBG and currentBG.name or false }
  return true
end

local obj = { mode = nil, assaultStart = nil, allyHas = false, hordeHas = false, trusted = false }

local function ObjectiveStart()
  DetectMap()
  obj.mode = currentBG and currentBG.rules.objective or nil
  ns.flagRespawnAt = nil
  obj.assaultStart, obj.allyHas, obj.hordeHas = nil, false, false
  -- Joined mid-match: an unseen assault clock may already be running, so
  -- don't trust stack counts until both flags are seen home.
  local runtime = GetBattlefieldInstanceRunTime and GetBattlefieldInstanceRunTime() or 0
  obj.trusted = runtime < 90000
end

local function FlagStacks()
  if obj.mode ~= "flag" or not obj.assaultStart then
    return nil
  end
  return ns.AssaultStacks(time() - obj.assaultStart, currentBG and currentBG.rules.flags)
end

-- Stack value shown/scored for a carrier: flag stack count, or orb %.
local function CarrierStacks(e)
  if e.testStacks then
    return e.testStacks
  end
  if not e.carrier then
    return nil
  end
  if obj.mode == "flag" then
    return FlagStacks()
  elseif obj.mode == "orb" and e.orbSince then
    local rules = currentBG and currentBG.rules.orbs
    if rules then
      return rules.initialPercent + math.floor((time() - e.orbSince) / rules.interval) * rules.stepPercent
    end
  end
end

local function EnemyByChatName(name)
  if type(name) ~= "string" then
    return nil
  end
  name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local key = Canon(name)
  if key and enemies[key] then
    return enemies[key]
  end
  local found
  for _, e in pairs(enemies) do
    if e.display:match("^[^-]+") == name then
      if found then
        return nil -- ambiguous short name
      end
      found = e
    end
  end
  return found
end

local function ClearCarriers()
  for _, e in pairs(enemies) do
    e.carrier, e.orbSince = false, nil
  end
end

local function ResetAssault()
  obj.assaultStart, obj.allyHas, obj.hordeHas = nil, false, false
  obj.trusted = true
end

local function OnObjectiveChat(event, msg)
  if not active or not obj.mode or type(msg) ~= "string" or issecret(msg) then
    return
  end
  if obj.mode == "carry" then
    -- Eye of the Storm (and Deephaul Ravine): one neutral flag.
    --   "X has taken the flag!"  "The flag has been dropped."
    --   "The Alliance have captured the flag!"  (respawns after 21s)
    local taker = msg:match("^(.+) has taken the flag!")
    if taker then
      ClearCarriers()
      local e = EnemyByChatName(taker)
      if e then
        e.carrier = true -- your own team's carrier: no enemy carrier
      end
      return
    end
    if msg:find("flag has been dropped") or msg:find("flag has been reset") or msg:find("captured the") then
      ClearCarriers()
      if msg:find("captured the") then
        local rules = currentBG and currentBG.rules.flags
        ns.flagRespawnAt = rules and rules.respawnSeconds and (GetTime() + rules.respawnSeconds) or nil
      end
      return
    end
  end
  if event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
    if msg:find("placed at their bases") or msg:find("wins") then
      ResetAssault()
      ClearCarriers()
    end
    return
  end
  local allianceChannel = event == "CHAT_MSG_BG_SYSTEM_ALLIANCE"

  if obj.mode == "orb" then
    local who = msg:match("^(.-) has taken the")
    local e = who and EnemyByChatName(who)
    if e then
      e.carrier, e.orbSince, e.carrierSeen = true, time(), GetTime()
    end
    return
  end

  local picker = msg:match("picked up by (.+)!")
  local dropper = msg:match("dropped by (.+)!")
  if picker then
    local e = EnemyByChatName(picker)
    if e then
      ClearCarriers() -- one enemy carrier at a time on flag maps
      e.carrier = true
    end
    if obj.mode == "flag" then
      if allianceChannel then obj.hordeHas = true else obj.allyHas = true end
      if obj.trusted and obj.allyHas and obj.hordeHas and not obj.assaultStart then
        obj.assaultStart = time()
      end
    end
  elseif dropper then
    local e = EnemyByChatName(dropper)
    if e then
      e.carrier = false
    end
    if obj.mode == "flag" then
      if allianceChannel then obj.hordeHas = false else obj.allyHas = false end
    end
  elseif msg:find("returned to its base") then
    if obj.mode == "flag" then
      if allianceChannel then obj.hordeHas = false else obj.allyHas = false end
      if not obj.allyHas and not obj.hordeHas then
        ResetAssault()
      end
    end
  elseif msg:find("captured the") then
    ClearCarriers()
    if obj.mode == "flag" then
      ResetAssault()
    end
  end
end

-- Arena tokens point at objective carriers anywhere on the map.
local function ScanCarrierTokens()
  if not obj.mode then
    return
  end
  local now = GetTime()
  -- Orbs have no reliable drop message: a carrier whose arena token has been
  -- gone for 3s, or who died, no longer holds an orb (it resets on drop).
  if obj.mode == "orb" then
    for _, e in pairs(enemies) do
      if e.carrier and (e.dead or now - (e.carrierSeen or 0) > 3) then
        e.carrier, e.orbSince = false, nil
      end
    end
  end
  for i = 1, 4 do
    local unit = "arena" .. i
    local ok, exists = pcall(UnitExists, unit)
    if ok and plain(exists) and exists then
      local key = CanonUnit(unit)
      local e = key and enemies[key]
      if e then
        if obj.mode ~= "orb" and not e.carrier then
          ClearCarriers()
        end
        e.carrier = true
        e.carrierSeen = now
        if obj.mode == "orb" and not e.orbSince then
          e.orbSince = time() -- pickup missed: seed at base value
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Scoring
---------------------------------------------------------------------------
local function SpecScore(specID, class, reasons)
  local p = Profile(specID)
  local k, i = p.k, p.i
  local matchups = me.specID and ns.Matchups[me.specID]
  if matchups then
    local m = matchups[specID]
    if m then
      k = k + m[1]
      if reasons then table.insert(reasons, m[2]) end
    end
    return 6 * k + 4 * i, p, k - p.k
  end
  if me.dmg == "phys" then
    local armor = ns.Armor[class]
    if armor == "plate" then
      k = k - 0.7
      if reasons then table.insert(reasons, "plate vs your physical dmg") end
    elseif armor == "cloth" then
      k = k + 0.5
      if reasons then table.insert(reasons, "cloth: good vs physical") end
    end
    if p.physDR then
      k = k - 0.6
      if reasons then table.insert(reasons, "has physical immunity/DR") end
    end
  elseif p.magDR then
    k = k - 0.6
    if reasons then table.insert(reasons, "has magic immunity/DR") end
  end
  if me.melee and p.kite then
    k = k - 0.8
    if reasons then table.insert(reasons, "kites melee (S2 slow nerfs)") end
  end
  return 6 * k + 4 * i, p, k - p.k
end

local BURN_WINDOW = 60
local KILL_WINDOW = 12 -- seconds after a defensive fades that count as "go now"
local SWAP_MARGIN = 4 -- points a lower enemy must lead by to overtake (see Recompute)

-- Score components. Each is multiplied by its coefficient (db.weights,
-- default 1.0; /wb weight NAME X). BASE parts order the list, LIVE parts only
-- drive icons and the GO alert (unless /wb live).
local WEIGHTS = {
  { key = "kill", desc = "how easy the spec is to kill", base = true },
  { key = "impact", desc = "value of killing the spec (healers, S-tier)", base = true },
  { key = "matchup", desc = "your spec vs theirs", base = true },
  { key = "gear", desc = "undergeared (max HP) - INACTIVE: Blizzard hides enemy max HP in BGs", base = true },
  { key = "objective", desc = "flag/orb carrier + stacks", base = true },
  { key = "marker", desc = "raid skull / cross", base = true },
  { key = "spent", desc = "defensive just spent (live)" },
  { key = "focus", desc = "teammates on it (live)" },
  { key = "burst", desc = "bursting (live)" },
  { key = "range", desc = "how close to you (live): picks the kill target" },
  { key = "defensive", desc = "defensive up penalty (live)" },
  { key = "cc", desc = "in CC penalty (live)" },
  { key = "stun", desc = "stunned/silenced: free damage (live, Cata)" },
  { key = "health", desc = "low health (live, Cata: secret on retail)" },
  { key = "cooldowns", desc = "trinket / immunity / defensives on cooldown (combat log, Cata)" },
  { key = "cast", desc = "casting a heal or CC you can kick (live)" },
  { key = "healerOOM", desc = "healer out of mana (live, Cata)" },
}

-- Every point value the scoring uses, editable in Options > AddOns >
-- Warboard (or /wb points). Overrides live in WarboardDB.points; a value
-- set back to its default is dropped. cata = only meaningful on Cata Classic.
local POINTS = {
  { group = "Who they are (list order)" },
  { key = "killPer", def = 6, desc = "Per killability point (spec rating 1-10)" },
  { key = "impactPer", def = 4, desc = "Per impact point (spec rating 1-10)" },
  { key = "matchupPer", def = 6, desc = "Per point of matchup edge (your spec vs theirs)" },
  { key = "unknownSpec", def = -3, desc = "Spec unknown (ranked by class average)" },
  { key = "gearPer", def = 6, desc = "Per undergeared step (inactive on retail)" },
  { group = "Objectives and team calls" },
  { key = "flagCarrier", def = 30, desc = "Flag carrier" },
  { key = "flagPerStack", def = 3, desc = "Per Focused Assault stack" },
  { key = "orbCarrier", def = 20, desc = "Orb carrier" },
  { key = "orbPerPct", def = 0.3, step = 0.1, desc = "Per +1% damage taken from the orb" },
  { key = "skull", def = 40, desc = "Skull marker" },
  { key = "cross", def = 15, desc = "Cross marker" },
  { group = "Live (kill target right now)" },
  { key = "spent", def = 15, desc = "Defensive just spent (fades over 60s)" },
  { range = true }, -- one row per distance band, filled in below
  { key = "rangeFar", def = 4, desc = "Visible, beyond your spell ranges" },
  { key = "rangeUnseen", def = -20, desc = "Not visible" },
  { key = "focusPerAlly", def = 3, desc = "Per teammate on them" },
  { key = "focusMaxAllies", def = 5, desc = "Teammates counted at most" },
  { key = "burst", def = 8, desc = "Bursting (offensive cooldown up)" },
  { key = "defensiveUp", def = -25, desc = "Defensive active" },
  { key = "ccUp", def = -15, desc = "In breakable CC" },
  { key = "stun", def = 12, desc = "Stunned / silenced", cata = true },
  { key = "healthMax", def = 30, desc = "Low health (at 0%, scales with missing health)", cata = true },
  { key = "execute", def = 10, desc = "Under the execute threshold (extra)", cata = true },
  { key = "castPriority", def = 8, desc = "Casting a big heal / CC you can kick", cata = true },
  { key = "castHealer", def = 5, desc = "Healer casting anything you can kick", cata = true },
  { key = "healerOOM", def = -20, desc = "Healer out of mana (can't heal: lower priority)", cata = true },
  { key = "oomPct", def = 5, desc = "... counts as out of mana at or below this % mana", cata = true },
  { group = "Cooldowns seen used (combat log)", cata = true },
  { key = "trinketDown", def = 8, desc = "PvP trinket down", cata = true },
  { key = "immuneDown", def = 14, desc = "Immunity down (Ice Block, bubble, Cloak...)", cata = true },
  { key = "defDown", def = 6, desc = "Other defensive down", cata = true },
  { key = "mobilityDown", def = 5, desc = "Escape down (Blink, Disengage...) when you're melee", cata = true },
  { key = "kitCap", def = 30, desc = "Cap for the cooldowns above", cata = true },
  { key = "carrierKeyDown", def = 10, desc = "Boomkin/feral Barkskin down", cata = true },
  { key = "carrierKeyBase", def = 20, desc = "... on a flag/orb carrier", cata = true },
  { key = "carrierKeyPerStack", def = 4, desc = "... per carrier stack", cata = true },
  { key = "carrierKeyCap", def = 50, desc = "... cap", cata = true },
  { group = "Timers" },
  { key = "dieHpPct", def = 30, desc = "Good time to die: your health at or below this %" },
  { key = "dieResMax", def = 10, desc = "... and your graveyard's next res within this many seconds" },
  { key = "dieResMin", def = 2, desc = "... but at least this many (time to die and release)" },
}
do
  -- Distance bands come from your client's data (retail and Cata differ).
  local list = {}
  for _, row in ipairs(POINTS) do
    if row.range then
      for _, b in ipairs(ns.ProximityBonus) do
        list[#list + 1] = { key = "range" .. b[1], def = b[2], desc = string.format("Within %d yd", b[1]) }
      end
    else
      list[#list + 1] = row
    end
  end
  POINTS = list
end
local POINT_DEFAULT = {}
for _, row in ipairs(POINTS) do
  if row.key then
    POINT_DEFAULT[row.key] = row.def
  end
end
ns.POINTS = POINTS

local P
function P(key)
  local v = db.points and db.points[key]
  if v ~= nil then
    return v
  end
  return POINT_DEFAULT[key] or 0
end

local function W(key)
  local w = (db.weights and db.weights[key]) or 1
  if currentProfile and currentProfile[key] then
    w = w * currentProfile[key]
  end
  return w
end

-- Gear proxy: max HP vs the median of visible non-tank enemies. Dormant in
-- practice: despite the API docs, UnitHealthMax on enemy players came back
-- secret in every BG recorded (0 plain samples), so gearRef stays nil. Kept in
-- case Blizzard relaxes it; costs nothing while inactive.
local gearRef -- median max HP, recomputed each Recompute
local function Median(list)
  local copy = {}
  for i, v in ipairs(list) do
    copy[i] = v
  end
  table.sort(copy)
  local n = #copy
  if n == 0 then
    return nil
  end
  return n % 2 == 1 and copy[(n + 1) / 2] or (copy[n / 2] + copy[n / 2 + 1]) / 2
end

local function UpdateGearRef()
  local hps = {}
  for _, e in pairs(enemies) do
    local tank = e.specID and specInfo[e.specID] and specInfo[e.specID].role == "TANK"
    if e.hpMedian and not tank then
      hps[#hps + 1] = e.hpMedian
    end
  end
  gearRef = #hps >= 4 and Median(hps) or nil
end

local function SpellName(id)
  local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
  return name or tostring(id)
end

-- Cata class kits (config/cata/Classes.lua): which cooldowns an enemy has, and which
-- the combat log has seen them use. kitBySpell maps every ID an ability can
-- show up as (cast, aura, racial variant) to its kit entry.
local kitBySpell = {}
local function BuildKits()
  local function add(entry, class)
    entry.class = class
    kitBySpell[entry[1]] = entry
    for _, id in ipairs(entry.alt or {}) do
      kitBySpell[id] = entry
    end
  end
  for _, entry in ipairs(ns.KitCommon or {}) do
    add(entry, nil)
  end
  for class, list in pairs(ns.Kits or {}) do
    for _, entry in ipairs(list) do
      add(entry, class)
    end
  end
end

-- This enemy's kit: shared entries + their class's, filtered to their spec
-- (unknown spec -> every entry of the class).
local function KitFor(e)
  local out = {}
  if not ns.Kits or db.cooldowns == false then -- Cooldowns feature switch
    return out
  end
  for _, entry in ipairs(ns.KitCommon or {}) do
    out[#out + 1] = entry
  end
  local idx = e.specID and specIndex[e.specID]
  for _, entry in ipairs(ns.Kits[e.class] or {}) do
    if not entry.spec or not idx or entry.spec == idx then
      out[#out + 1] = entry
    end
  end
  return out
end

-- Seconds until a kit entry is back, or nil when ready / never seen used.
local function CdLeft(e, entry)
  local readyAt = e.cds and e.cds[entry[1]]
  local left = readyAt and readyAt - GetTime()
  return left and left > 0 and left or nil
end

local function Clock(sec)
  return string.format("%d:%02d", math.floor(sec / 60), math.floor(sec % 60))
end

-- Points while down: no trinket = CC them, no immunity = it sticks.
local KIT_POINTS = { trinket = "trinketDown", immune = "immuneDown", def = "defDown" }
-- Objective stacks as a count: flag Focused Assault stacks, or orb +30% steps.
local function StackCount(e)
  local stacks = CarrierStacks(e)
  if not stacks then
    return 0
  end
  return obj.mode == "orb" and math.max(0, math.floor(stacks / 30) - 1) or stacks
end

local function CooldownBonus(e)
  local pts, extra, names = 0, 0, {}
  local idx = e.specID and specIndex[e.specID]
  for _, entry in ipairs(KitFor(e)) do
    local left = CdLeft(e, entry)
    if left and entry.carrierKey and (not idx or entry.carrierKey[idx]) then
      -- Their carrier defensive is down: on a stacked carrier, kill NOW.
      if e.carrier or e.testStacks then
        local n = StackCount(e)
        extra = extra + math.min(P("carrierKeyCap"), P("carrierKeyBase") + P("carrierKeyPerStack") * n)
        names[#names + 1] = string.format("%s %s ON CARRIER (%d stacks)", entry[4], Clock(left), n)
      else
        extra = extra + P("carrierKeyDown")
        names[#names + 1] = entry[4] .. " " .. Clock(left)
      end
    elseif left and (KIT_POINTS[entry[3]] or (entry[3] == "mobility" and me.melee)) then
      -- Escapes only matter when you have to stay in melee.
      -- Per-spell override (Options > Defensives) beats the type's value.
      local ov = db.points and db.points["kit" .. entry[1]]
      pts = pts + (ov or P(KIT_POINTS[entry[3]] or "mobilityDown"))
      names[#names + 1] = entry[4] .. " " .. Clock(left)
    end
  end
  return math.min(pts, P("kitCap")) + extra, #names > 0 and ("down: " .. table.concat(names, ", ")) or nil
end

-- Short "what's missing" line for the hero card: NO TRINKET . NO CLOAK . KICK DOWN
local SUMMARY_KINDS = { trinket = 1, immune = 2, external = 3, def = 4, interrupt = 5 }
local function DownSummary(e, max)
  local list = {}
  for _, entry in ipairs(KitFor(e)) do
    local kind = SUMMARY_KINDS[entry[3]] or (entry[3] == "mobility" and me.melee and 6)
    if kind and CdLeft(e, entry) then
      list[#list + 1] = entry
    end
  end
  table.sort(list, function(a, b)
    return (SUMMARY_KINDS[a[3]] or 6) < (SUMMARY_KINDS[b[3]] or 6)
  end)
  local out = {}
  for i = 1, math.min(#list, max or 4) do
    local entry = list[i]
    out[i] = (entry[3] == "interrupt" and (entry[4] .. " down") or ("no " .. entry[4])):upper()
  end
  return #out > 0 and table.concat(out, "  \194\183  ") or nil
end

local function IsHealer(e)
  local si = e.specID and specInfo[e.specID]
  local p = e.specID and ns.Specs[e.specID]
  return (si and si.role == "HEALER") or (p and p.healer) or false
end

local function Score(e)
  local reasons, comp = {}, {}
  local function add(key, pts, reason)
    if pts and pts ~= 0 then
      comp[key] = (comp[key] or 0) + pts * W(key)
      if reason then
        table.insert(reasons, reason)
      end
    end
  end

  if e.specID then
    local p = Profile(e.specID)
    local _, _, delta = SpecScore(e.specID, e.class, reasons)
    add("kill", P("killPer") * p.k)
    add("impact", P("impactPer") * p.i)
    add("matchup", P("matchupPer") * (delta or 0))
    e.edge, e.note = delta, p.note
  else
    -- Unknown spec: average the class's non-tank specs.
    local sk, si, sd, n = 0, 0, 0, 0
    for _, id in ipairs(classSpecs[e.class] or {}) do
      if not (specInfo[id] and specInfo[id].role == "TANK") then
        local p = Profile(id)
        local _, _, delta = SpecScore(id, e.class)
        sk, si, sd, n = sk + p.k, si + p.i, sd + (delta or 0), n + 1
      end
    end
    if n > 0 then
      add("kill", P("killPer") * sk / n + P("unknownSpec"))
      add("impact", P("impactPer") * si / n)
      add("matchup", P("matchupPer") * sd / n)
    else
      add("kill", P("killPer") * 5)
    end
    e.edge = nil
    e.note = "Spec unknown (hidden mid-match, no history)"
  end

  if gearRef and e.hpMedian then
    local pct = (gearRef - e.hpMedian) / gearRef -- >0 = less HP than median
    local k = math.max(-1.5, math.min(1.5, pct * 7.5))
    if math.abs(pct) >= 0.05 then
      add("gear", P("gearPer") * k, string.format("%s max HP %+.0f%% vs enemy median%s", pct > 0 and "low" or "high",
        -pct * 100, pct > 0 and " (undergeared?)" or ""))
    else
      add("gear", P("gearPer") * k)
    end
  end

  if e.carrier or e.testStacks then
    local stacks = CarrierStacks(e)
    if obj.mode == "orb" then
      -- Kotmogu: the orb's damage-taken bonus grows the longer it's held, so
      -- a long-held orb is the easiest kill on the map: 0.3 pts per % taken
      -- (+30% -> +9, +150% -> +45, +300% -> +90) on top of the carrier bonus.
      add("objective", P("orbCarrier") + (stacks or 30) * P("orbPerPct"),
        string.format("ORB CARRIER (+%d%% dmg taken)", stacks or 30))
    else
      add("objective", P("flagCarrier") + (stacks or 0) * P("flagPerStack"),
        string.format("FLAG CARRIER%s", stacks and (" (" .. stacks .. " Focused Assault stacks)") or ""))
    end
  end

  if e.marker == 8 then
    add("marker", P("skull"), "SKULL: team kill target")
  elseif e.marker == 7 then
    add("marker", P("cross"), "X: team secondary target")
  end

  local base = 0
  for _, v in pairs(comp) do
    base = base + v
  end
  e.base = base

  local burnedAgo = e.burnedAt and (GetTime() - e.burnedAt)
  if burnedAgo and burnedAgo < BURN_WINDOW then
    add("spent", P("spent") * (1 - burnedAgo / BURN_WINDOW), string.format("defensive spent %ds ago: GO", burnedAgo))
  end
  -- Proximity: dominant for the live kill target (who to hit NOW).
  if e.yards then
    local bonus = P("rangeFar")
    for _, b in ipairs(ns.ProximityBonus) do
      if e.yards <= b[1] then
        bonus = P("range" .. b[1])
        break
      end
    end
    add("range", bonus, string.format("~%d yd from you", e.yards))
  elseif e.plateUnit then
    -- "Visible" = nameplate on screen. Merely targeting/focusing/mousing over
    -- a far enemy must not make them the kill target.
    add("range", P("rangeFar"), "on screen (beyond your spell ranges)")
  elseif not e.dead then
    add("range", P("rangeUnseen"))
  end
  if (e.allyCount or 0) > 0 then
    add("focus", math.min(e.allyCount, P("focusMaxAllies")) * P("focusPerAlly"),
      string.format("%d %s on it (not counting you)", e.allyCount, e.allyCount == 1 and "teammate" or "teammates"))
  end
  if e.onMe then
    table.insert(reasons, "targeting YOU")
  end
  if e.burst then
    add("burst", P("burst"), "bursting: pressure forces a defensive")
  end
  if e.def then
    add("defensive", P("defensiveUp"), "DEFENSIVE ACTIVE: swap")
  end
  if e.cc then
    add("cc", P("ccUp"), "in CC: don't break it")
  end
  if e.crowdControlled and not e.cc and not e.stun then
    table.insert(reasons, "crowd controlled (type unknown)")
  end
  if e.stun and not e.dead then
    add("stun", P("stun"), "stunned/silenced: free damage")
  end
  if e.hpPct and not e.dead then
    local pts = (1 - e.hpPct) * P("healthMax")
    if e.hpPct <= db.executePct then
      pts = pts + P("execute")
    end
    add("health", pts, string.format("%d%% health", math.floor(e.hpPct * 100 + 0.5)))
  end
  -- Healer out of mana can't heal: killing them matters less right now.
  -- Last reading kept 10s while out of sight.
  if e.manaPct and not e.dead and GetTime() - (e.manaAt or 0) < 10 and IsHealer(e)
    and e.manaPct * 100 <= P("oomPct") then
    add("healerOOM", P("healerOOM"), string.format("healer OOM (%d%% mana): low priority", math.floor(e.manaPct * 100 + 0.5)))
  end
  if e.cast and e.cast.kickable and not e.dead then
    local prio = e.cast.spell and ns.KickPriority and ns.KickPriority[e.cast.spell]
    if prio or IsHealer(e) then
      add("cast", prio and P("castPriority") or P("castHealer"), "casting " .. e.cast.name .. ": kick / pressure")
    end
  end
  local cdPts, cdWhy = CooldownBonus(e)
  e.cdText = cdWhy
  if cdPts > 0 then
    add("cooldowns", cdPts, cdWhy)
  end

  local live = 0
  for _, v in pairs(comp) do
    live = live + v
  end
  if e.dead then
    live = -100
  end
  e.live, e.reasons, e.comp = live, reasons, comp
  e.score = db.liveSort and live or e.base
end

---------------------------------------------------------------------------
-- Roster (scoreboard)
---------------------------------------------------------------------------
-- One scoreboard row as a table. Retail: C_PvP.GetScoreInfo. Cata Classic
-- 4.4.2 only has GetBattlefieldScore; talentSpec is its 16th return and is
-- readable mid-match there.
local function ScoreInfo(idx)
  if C_PvP and C_PvP.GetScoreInfo then
    return C_PvP.GetScoreInfo(idx)
  end
  local name, _, _, _, _, faction, _, _, classToken, _, _, _, _, _, _, talentSpec = GetBattlefieldScore(idx)
  if name then
    return { name = name, faction = faction, classToken = type(classToken) == "string" and classToken:upper() or nil,
      talentSpec = talentSpec }
  end
end

local function RaidNames()
  local set = {}
  set[Canon(UnitName("player")) or ""] = true
  for i = 1, GetNumGroupMembers() or 0 do
    local name = GetRaidRosterInfo(i)
    local key = Canon(name)
    if key then
      set[key] = true
    end
  end
  return set
end

local resettingFilter = false
local rosterStatus -- why the roster is empty, shown in /wb err and probe

local function RefreshRoster()
  if testMode then
    return
  end
  local n = GetNumBattlefieldScores() or 0
  local rows = {}
  -- Why rows get skipped, saved for diagnosis (WarboardDB.rosterDebug).
  local dbg = { t = date("%H:%M:%S"), scores = n, noInfo = 0, badName = 0, badClass = 0, badFaction = 0 }
  for idx = 1, n do
    local info = ScoreInfo(idx)
    if not info then
      dbg.noInfo = dbg.noInfo + 1
    else
      local key = Canon(info.name)
      local class, faction = info.classToken, info.faction
      if not key then
        dbg.badName = dbg.badName + 1
      elseif not plain(class) then
        dbg.badClass = dbg.badClass + 1
      elseif not plain(faction) then
        dbg.badFaction = dbg.badFaction + 1
      else
        rows[#rows + 1] = { key = key, class = class, faction = faction, spec = info.talentSpec }
      end
    end
  end
  dbg.rows = #rows
  dbg.allyFaction = allyFaction
  local ok, st = pcall(C_PvP.GetActiveMatchState)
  dbg.matchState = ok and plain(st) and st or nil
  db.rosterDebug = dbg
  if n == 0 then
    rosterStatus = "no scoreboard yet"
    return
  end

  -- Scoreboard filtered to one team (a faction tab was clicked): reset it to
  -- both teams once the scoreboard window is closed, and keep current state.
  local factions, nf = {}, 0
  for _, r in ipairs(rows) do
    if not factions[r.faction] then
      factions[r.faction] = true
      nf = nf + 1
    end
  end
  if nf < 2 then
    local board = PVPMatchScoreboard or WorldStateScoreFrame
    if not (board and board:IsShown()) and SetBattlefieldScoreFaction and not resettingFilter then
      resettingFilter = true
      pcall(SetBattlefieldScoreFaction, -1)
      resettingFilter = false
      RequestScores()
    end
    rosterStatus = nf == 0 and "scoreboard rows unreadable" or "enemy team not on scoreboard yet"
    dbg.status = rosterStatus
    return
  end

  -- Your own scoreboard row is the most reliable team source: scoreboard
  -- names are NeverSecret, while group roster names may come back secret.
  if allyFaction == nil then
    local myKey = Canon(UnitName("player"))
    for _, r in ipairs(rows) do
      if r.key == myKey then
        allyFaction = r.faction
        break
      end
    end
  end
  if allyFaction == nil then
    local raid, votes = RaidNames(), {}
    for _, r in ipairs(rows) do
      if raid[r.key] then
        votes[r.faction] = (votes[r.faction] or 0) + 1
      end
    end
    local best, bestN = nil, 1 -- need at least two matching group members
    for f, c in pairs(votes) do
      if c > bestN then
        best, bestN = f, c
      end
    end
    allyFaction = best
  end
  if allyFaction == nil and GetBattlefieldArenaFaction then
    local ok, f = pcall(GetBattlefieldArenaFaction)
    if ok and plain(f) and factions[f] then
      allyFaction = f
    end
  end
  if allyFaction == nil then
    rosterStatus = "can't tell which team is yours"
    dbg.status = rosterStatus
    return
  end
  rosterStatus = nil

  -- A read with only one team means Blizzard's scoreboard is filtered (a
  -- faction tab was clicked, e.g. while dead) or still loading. Never drop
  -- enemies on such a read; reset the filter once the scoreboard is closed.
  local allyRows, enemyRows = 0, 0
  for _, r in ipairs(rows) do
    if r.faction == allyFaction then
      allyRows = allyRows + 1
    else
      enemyRows = enemyRows + 1
    end
  end
  if allyRows == 0 or enemyRows == 0 then
    local board = PVPMatchScoreboard or WorldStateScoreFrame
    if not (board and board:IsShown()) and SetBattlefieldScoreFaction and not resettingFilter then
      resettingFilter = true
      SetBattlefieldScoreFaction(-1)
      resettingFilter = false
      RequestScores()
    end
    return
  end

  local seen = {}
  for _, r in ipairs(rows) do
    if r.faction ~= allyFaction then
      seen[r.key] = true
      local e = enemies[r.key]
      if not e then
        e = { key = r.key, display = DisplayName(r.key) }
        enemies[r.key] = e
      end
      e.class = r.class
      local spec = r.spec
      -- Raw scoreboard spec, possibly secret: only ever handed to SetText.
      e.specLive = nil
      if type(spec) == "string" then e.specLive = spec end
      if plain(spec) and type(spec) == "string" and spec ~= "" and specByName[r.class] then
        e.specID = specByName[r.class][spec] or e.specID
        e.specSrc = "live"
      end
      if not e.specID then
        e.specID = HistoricSpec(r.key, r.class)
        e.specSrc = e.specID and "hist" or nil
      end
    end
  end
  for key in pairs(enemies) do
    if not seen[key] then
      enemies[key] = nil
    end
  end
end

-- After the match, specs are no longer secret: remember them for next time.
local function HarvestHistory()
  for idx = 1, GetNumBattlefieldScores() or 0 do
    local info = ScoreInfo(idx)
    if info then
      local key = Canon(info.name)
      local class, spec = info.classToken, info.talentSpec
      if key and plain(class) and plain(spec) and type(spec) == "string" and spec ~= "" then
        db.history[key] = { class = class, spec = spec, t = time() }
        local e = enemies[key]
        if e and (e.maxMana or e.maxHP) and not e.fingerprinted then
          e.fingerprinted = true
          db.fingerprints = db.fingerprints or {}
          local fp = class .. "/" .. spec
          local list = db.fingerprints[fp] or {}
          db.fingerprints[fp] = list
          list[#list + 1] = { mana = e.maxMana, hp = e.maxHP }
          if #list > 50 then
            table.remove(list, 1)
          end
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Live unit state (only things Midnight still exposes)
---------------------------------------------------------------------------
local function CountAuras(unit, filter)
  if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then
    return nil
  end
  local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter)
  if not ok or type(list) ~= "table" then
    -- Never counted before: tells /wb why whether aura flags can work at all.
    Stat("auras", ok and "notTable" or "error")
    if not ok and not db.auraErr then
      db.auraErr = tostring(list)
    end
    return nil
  end
  local ok2, n = pcall(function()
    return #list
  end)
  if ok2 and plain(n) then
    Stat("auras", "plain")
    return n, list
  end
  Stat("auras", "secret")
end

-- Cata Classic: no aura categories, but every aura carries its spellId.
local function ReadAurasByList(unit)
  local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  local r = {}
  if not get then
    return r
  end
  for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
    for i = 1, 40 do
      local ok, a = pcall(get, unit, i, filter)
      if not ok or not a then
        break
      end
      local id = a.spellId
      if filter == "HELPFUL" then
        if ns.Defensives[id] then
          r.def = true
          r.defIcon = r.defIcon or a.icon
        elseif ns.Burst[id] then
          r.burst = true
          r.burstIcon = r.burstIcon or a.icon
        end
      elseif ns.SoftCC[id] then
        r.cc = true
      elseif ns.HardCC[id] then
        r.stun = true
      end
    end
  end
  Stat("auras", "plain")
  return r
end

-- Map enemies to their nameplate token (for the world-space sniper scope).
local function ScanPlates()
  for _, e in pairs(enemies) do
    e.plateUnit = nil
  end
  for i = 1, 40 do
    local unit = "nameplate" .. i
    local ok, exists = pcall(UnitExists, unit)
    if ok and plain(exists) and exists then
      local key = CanonUnit(unit)
      local e = key and enemies[key]
      if e and not e.plateUnit then
        e.plateUnit = unit
      end
    end
  end
end

-- Who your team is hitting: UnitName on "raidNtarget" resolves enemy players
-- by name (readable in PvP), so we can count allies per enemy.
local function ScanAllyTargets()
  for _, e in pairs(enemies) do
    e.allyCount = 0
  end
  -- Teammates only: your own target must not bump an enemy's score, or
  -- simply targeting someone would pull the kill target onto them.
  local myName = UnitName("player")
  local function count(unit, owner)
    local okN, ownerName = pcall(UnitName, owner)
    if okN and plain(ownerName) and ownerName == myName then
      return
    end
    local key = CanonUnit(unit)
    local e = key and enemies[key]
    if e then
      e.allyCount = e.allyCount + 1
    end
  end
  local n = GetNumGroupMembers() or 0
  if IsInRaid() then
    for i = 1, n do
      count("raid" .. i .. "target", "raid" .. i)
    end
  else
    for i = 1, math.max(n - 1, 0) do
      count("party" .. i .. "target", "party" .. i)
    end
  end
end

-- Returns the raw in-range answer (true/false, possibly secret) or nil.
local function RangeCheck(list, unit)
  if not (list and C_Spell and C_Spell.IsSpellInRange) then
    return nil
  end
  for _, id in ipairs(list) do
    local ok, r = pcall(C_Spell.IsSpellInRange, id, unit)
    if ok and type(r) ~= "nil" then -- type() is safe on secret booleans
      Stat("range", issecret(r) and "secret" or "plain")
      return r
    end
  end
  Stat("range", "none")
end

-- Nearest distance band (yards) the unit is in, using your class's spells.
-- Returns yards (plain), or nil + the first secret answer seen (display only).
local function NearestBand(unit)
  local cfg = (me.range or ns.RangeBands[me.class])
  if not cfg then
    return nil
  end
  local secretAnswer
  for _, band in ipairs(cfg.bands) do
    local r = RangeCheck(band[2], unit)
    if plain(r) then
      if r == true then
        return band[1]
      end
    elseif type(r) ~= "nil" and type(secretAnswer) == "nil" then
      secretAnswer = r
    end
  end
  return nil, secretAnswer
end

local function ScanUnits()
  wipe(unitFor)
  local visible = 0
  local function try(unit)
    local ok, exists = pcall(UnitExists, unit)
    if ok and plain(exists) and exists then
      local key = CanonUnit(unit)
      if key and enemies[key] and not unitFor[key] then
        unitFor[key] = unit
        visible = visible + 1
      end
    end
  end
  try("target")
  try("focus")
  try("mouseover")
  try("softenemy")
  for i = 1, 4 do
    try("arena" .. i)
  end
  for i = 1, 40 do
    try("nameplate" .. i)
  end
  db.liveStats = db.liveStats or {}
  db.liveStats.maxVisible = math.max(db.liveStats.maxVisible or 0, visible)

  for key, e in pairs(enemies) do
    local unit = unitFor[key]
    e.unit = unit
    if unit then
      local okDead, dead = pcall(UnitIsDeadOrGhost, unit)
      e.dead = okDead and plain(dead) and dead or false
      if ns.Defensives then
        -- Cata: classify auras by spellId (config/cata/Classes.lua lists).
        local hadDef = e.def and e.wasVisible
        local a = ReadAurasByList(unit)
        e.def, e.cc, e.stun, e.burst = a.def or false, a.cc or false, a.stun or false, a.burst or false
        e.defIcon, e.burstIcon = a.defIcon, a.burstIcon
        if hadDef and not e.def then
          e.burnedAt = GetTime()
        end
      else
        local nDef = CountAuras(unit, "HELPFUL|BIG_DEFENSIVE")
        local nExt, extList = CountAuras(unit, "HELPFUL|EXTERNAL_DEFENSIVE")
        local nCC = CountAuras(unit, "HARMFUL|CROWD_CONTROL")
        local hadDef = e.def and e.wasVisible
        e.def = ((nDef or 0) + (nExt or 0)) > 0
        -- The Retail category includes stuns as well as breakable CC. A
        -- category alone cannot justify a "do not break" score penalty.
        e.crowdControlled = (nCC or 0) > 0
        e.cc, e.stun = false, false
        -- Defensive aura faded while we watched: they just spent it.
        if hadDef and not e.def and nDef ~= nil then
          e.burnedAt = GetTime()
        end
        -- "Important" buffs minus defensives are mostly offensive cooldowns.
        local nBurst, burstList = CountAuras(unit, "HELPFUL|IMPORTANT|!BIG_DEFENSIVE|!EXTERNAL_DEFENSIVE")
        e.burst = (nBurst or 0) > 0
        e.burstIcon = e.burst and burstList and burstList[1] and burstList[1].icon or nil
        e.defIcon = nil
        if e.def then
          local _, defList = CountAuras(unit, "HELPFUL|BIG_DEFENSIVE")
          local list = (nDef or 0) > 0 and defList or extList
          e.defIcon = list and list[1] and list[1].icon
        end
      end
      -- Max mana/health are readable on enemy players; recorded so specs can
      -- later be inferred from them (paired with post-match specs).
      local okM, mana = pcall(UnitPowerMax, unit, 0)
      if okM and plain(mana) then
        e.maxMana = mana
      end
      local okH, hp = pcall(UnitHealthMax, unit)
      if okH and plain(hp) then
        e.maxHP = hp
        e.hpSamples = e.hpSamples or {}
        if hp ~= e.hpSamples[#e.hpSamples] then
          table.insert(e.hpSamples, hp)
          if #e.hpSamples > 15 then
            table.remove(e.hpSamples, 1)
          end
          e.hpMedian = Median(e.hpSamples)
        end
      end
      -- Current health: plain on Cata (scores + exec), secret on retail.
      local okC, cur = pcall(UnitHealth, unit)
      e.hpPct = nil
      if okC and okH and plain(cur) and plain(hp) and hp > 0 then
        e.hpPct = cur / hp
      end
      -- Mana (plain on Cata). Only while mana is their shown power: a
      -- shapeshifted druid reports 0 mana in cat/bear form.
      local okT, ptype = pcall(UnitPowerType, unit)
      if okT and plain(ptype) and ptype == 0 then
        local okP, mp = pcall(UnitPower, unit, 0)
        local okX, mpMax = pcall(UnitPowerMax, unit, 0)
        if okP and okX and plain(mp) and plain(mpMax) and mpMax > 0 then
          e.manaPct, e.manaAt = mp / mpMax, GetTime()
        end
      end
      if not e.dead then
        e.diedAt = nil
      end
      -- Is this enemy targeting you? Plain -> icon + reason; secret -> icon only.
      local okMe, onMe = pcall(UnitIsUnit, unit .. "target", "player")
      -- Never truth-test a possibly-secret value ("x and y or z" does): only
      -- plain() / type() / issecret() may touch it before it's known plain.
      e.onMeRaw = nil
      if okMe then
        e.onMeRaw = onMe
      end
      e.onMe = false
      if okMe and plain(onMe) and onMe == true then
        e.onMe = true
      end
      -- Raid marker (team calls). Remembered while out of sight.
      local okMark, mark = pcall(GetRaidTargetIndex, unit)
      if okMark and plain(mark) then
        e.marker = mark
      elseif okMark and mark == nil then
        e.marker = nil
      end
      -- Distance: nearest band in yards (plain) drives the kill target;
      -- a secret answer can only light the range pip.
      local yards, secretAnswer = NearestBand(unit)
      e.yards = yards
      e.rangeRaw = secretAnswer
      local cfg = (me.range or ns.RangeBands[me.class])
      e.range = nil
      if yards then
        e.range = (cfg and yards <= cfg.attackYards) and "attack" or "reach"
      end
      -- Cast bar (plain on Cata; secret values on retail are skipped).
      e.cast = nil
      local okC, cName, _, cIcon, cStart, cEnd, _, _, cNoInt, cSpell = pcall(UnitCastingInfo, unit)
      local channel = false
      if not (okC and plain(cName)) then
        okC, cName, _, cIcon, cStart, cEnd, _, cNoInt, cSpell = pcall(UnitChannelInfo, unit)
        channel = true
      end
      if okC and plain(cName) and plain(cStart) and plain(cEnd) then
        e.cast = {
          name = cName, icon = cIcon, start = cStart / 1000, finish = cEnd / 1000, channel = channel,
          kickable = not (plain(cNoInt) and cNoInt), spell = plain(cSpell) and cSpell or nil,
        }
      end
      e.lastSeen = GetTime()
      e.wasVisible = true
    else
      e.wasVisible = false
      e.range, e.rangeRaw, e.yards = nil, nil, nil
      e.onMe, e.onMeRaw = false, nil
      e.cast = nil
      if GetTime() - (e.lastSeen or 0) > 4 then
        -- Out of sight for a while: drop stale aura state.
        e.def, e.cc, e.defIcon, e.burst, e.burstIcon, e.stun, e.hpPct = false, false, nil, false, nil, false, nil
        -- Died (combat log) -> dead until seen alive or the 30s rez wave.
        e.crowdControlled = false
        e.dead = e.diedAt ~= nil and GetTime() - e.diedAt < 35
      end
    end
  end
end

---------------------------------------------------------------------------
-- UI: a motorsport timing tower.
--
--   WARBOARD    * LIVE                    CTF . 10   header
--   | TARGET                            15 YD |
--   | NAMEHERE                     [][][][][] |      hero: live kill target
--   | Holy Priest . 2 on it                   |
--   [ 1 ]| [i] NAME          HOLY   6  KILL (D)      rows: position tile,
--   [ 2 ]| [i] NAME         RESTO  30   +12 (S)      class strip, spec,
--   [ 3 ]| [i] NAME          FURY  --   +19          yards, gap to P1, pip
--
-- Flat black slabs, condensed type, one accent. Position tiles flash
-- green/red when an enemy gains/loses places, like a live timing feed.
-- Status pips work like tyre compounds: one letter, one color.
---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\Warboard\\media\\"
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"
local FONTS = {
  bold = MEDIA .. "BarlowCondensed-Bold.ttf",
  semi = MEDIA .. "BarlowCondensed-SemiBold.ttf",
  medium = MEDIA .. "BarlowCondensed-Medium.ttf",
  mono = MEDIA .. "JetBrainsMono-Bold.ttf",
}
local WHITE = "Interface\\Buttons\\WHITE8x8"
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local ICON_LOCK = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"
local ACCENT = { 1, 0.42, 0.12 }
local INK = { 0.035, 0.035, 0.045 }
local MUTED = { 0.55, 0.56, 0.62 }

-- Status pips (tyre-compound style): letter + color, highest priority wins.
local PIP = {
  def = { "D", 1, 0.84, 0.1 }, -- defensive up: swap
  cc = { "C", 0.35, 0.65, 1 }, -- known breakable CC
  control = { "C", 0.35, 0.65, 1 }, -- Retail CC category; subtype unknown
  stun = { "!", 1, 0.55, 0.1 }, -- stunned / silenced: free damage (Cata)
  notrinket = { "T", 0.2, 0.85, 0.8 }, -- PvP trinket on cooldown: CC sticks (Cata)
  carrier = { "F", 0.72, 0.4, 1 }, -- flag / orb carrier
  spent = { "S", 0.3, 0.9, 0.45 }, -- defensive just spent
  burst = { "B", 1, 0.25, 0.25 }, -- offensive cooldowns up
}

local ROW_H, GAP, PAD, WIDTH = 22, 1, 6, 272
local HEAD_H, HERO_H = 24, 60
local LIST_TOP = HEAD_H + HERO_H + 6 -- first row's offset from the panel top
local TILE_W = 24
local METER_SEGS = 6

-- Bundled fonts are new files: the client only sees them after a full
-- restart (not /reload). Until then SetFont fails -> Arial Narrow.
local function Text(parent, face, size, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  local okCall, ok = pcall(fs.SetFont, fs, FONTS[face] or FONT_FALLBACK, size, flags or "")
  if not (okCall and ok) then
    fs:SetFont(FONT_FALLBACK, size, flags or "")
  end
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.85)
  fs:SetWordWrap(false)
  return fs
end

local function Border(parent, r, g, b, a, size)
  size = size or 1
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetPoint("TOPLEFT", -size, size)
  f:SetPoint("BOTTOMRIGHT", size, -size)
  f:SetBackdrop({ edgeFile = WHITE, edgeSize = size })
  f:SetBackdropBorderColor(r, g, b, a or 1)
  return f
end

local function Fill(parent, layer, r, g, b, a, sub)
  local t = parent:CreateTexture(nil, layer, nil, sub)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

local function Bounce(target, from, to, dur)
  local g = target:CreateAnimationGroup()
  g:SetLooping("BOUNCE")
  local a = g:CreateAnimation("Alpha")
  a:SetFromAlpha(from)
  a:SetToAlpha(to)
  a:SetDuration(dur)
  a:SetSmoothing("IN_OUT")
  return g
end

local frame = CreateFrame("Frame", "WarboardFrame", UIParent, "BackdropTemplate")
frame:SetSize(WIDTH, LIST_TOP + PAD)
frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
frame:SetBackdropColor(INK[1], INK[2], INK[3], 0.94)
frame:SetBackdropBorderColor(1, 1, 1, 0.08)
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
  if not db.locked then
    self:StartMoving()
  end
end)
frame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  db.point = { p, rp, x, y }
end)
frame:Hide()

-- Header: brand block, title, live dot; map tag + count on the right.
local headBg = Fill(frame, "BORDER", 1, 1, 1, 0.035)
headBg:SetPoint("TOPLEFT", 1, -1)
headBg:SetPoint("TOPRIGHT", -1, -1)
headBg:SetHeight(HEAD_H - 1)

local brand = Fill(frame, "ARTWORK", ACCENT[1], ACCENT[2], ACCENT[3])
brand:SetSize(3, 12)
brand:SetPoint("LEFT", frame, "TOPLEFT", PAD + 1, -HEAD_H / 2)

local title = Text(frame, "bold", 14)
title:SetPoint("LEFT", brand, "RIGHT", 6, 0)
title:SetText("WARBOARD")
title:SetTextColor(0.97, 0.97, 0.98)

local liveDot = frame:CreateTexture(nil, "OVERLAY")
liveDot:SetSize(6, 6)
liveDot:SetTexture(CIRCLE)
liveDot:SetVertexColor(1, 0.2, 0.2)
liveDot:SetPoint("LEFT", title, "RIGHT", 8, 0)
local liveDotAnim = Bounce(liveDot, 1, 0.2, 0.8)
local liveText = Text(frame, "mono", 8)
liveText:SetPoint("LEFT", liveDot, "RIGHT", 4, 0)
liveText:SetTextColor(1, 0.35, 0.35)
liveText:SetText("LIVE")

local subtitle = Text(frame, "semi", 11)
subtitle:SetPoint("RIGHT", frame, "TOPRIGHT", -PAD - 1, -HEAD_H / 2)
subtitle:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

local lockIcon = frame:CreateTexture(nil, "OVERLAY")
lockIcon:SetSize(11, 11)
lockIcon:SetPoint("RIGHT", subtitle, "LEFT", -4, 0)
lockIcon:SetTexture(ICON_LOCK)
lockIcon:Hide()

-- Hero card: the live kill target, big. Plain (non-secure) frame, so it
-- updates freely in combat; the target keybind / mark button act on it.
local hero = CreateFrame("Frame", nil, frame)
hero:SetPoint("TOPLEFT", PAD, -HEAD_H - 3)
hero:SetPoint("TOPRIGHT", -PAD, -HEAD_H - 3)
hero:SetHeight(HERO_H)
do
  local bg = Fill(hero, "BACKGROUND", 1, 1, 1, 0.045)
  bg:SetAllPoints()
  hero.strip = Fill(hero, "ARTWORK", 1, 1, 1)
  hero.strip:SetPoint("TOPLEFT")
  hero.strip:SetPoint("BOTTOMLEFT")
  hero.strip:SetWidth(4)

  hero.label = Text(hero, "mono", 9)
  hero.label:SetPoint("TOPLEFT", 12, -7)
  hero.name = Text(hero, "bold", 24)
  hero.name:SetPoint("TOPLEFT", 11, -16)
  hero.name:SetPoint("RIGHT", hero, "RIGHT", -86, 0)
  hero.name:SetJustifyH("LEFT")
  hero.sub = Text(hero, "medium", 11)
  hero.sub:SetPoint("BOTTOMLEFT", 12, 8)
  hero.sub:SetPoint("RIGHT", hero, "RIGHT", -10, 0)
  hero.sub:SetJustifyH("LEFT")
  hero.sub:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

  hero.unitText = Text(hero, "mono", 9)
  hero.unitText:SetPoint("TOPRIGHT", -9, -12)
  hero.unitText:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
  hero.unitText:SetText("YD")
  hero.dist = Text(hero, "mono", 22)
  hero.dist:SetPoint("BOTTOMRIGHT", hero.unitText, "BOTTOMLEFT", -2, -2)

  -- Proximity meter: more lit segments = closer (signal-strength style).
  hero.meter = {}
  for s = 1, METER_SEGS do
    local t = Fill(hero, "ARTWORK", 1, 1, 1)
    t:SetSize(9, 4)
    t:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -9 - (METER_SEGS - s) * 11, -38)
    hero.meter[s] = t
  end

  hero.hp = CreateFrame("StatusBar", nil, hero)
  hero.hp:SetPoint("BOTTOMLEFT", 4, 0)
  hero.hp:SetPoint("BOTTOMRIGHT")
  hero.hp:SetHeight(2)
  hero.hp:SetStatusBarTexture(WHITE)
  hero.hp:SetMinMaxValues(0, 1)
  hero.exec = Border(hero, 1, 0.15, 0.1, 1, 1)
  hero.exec:SetAlpha(0)

  hero.goFill = Fill(hero, "ARTWORK", 1, 0.1, 0.05, 1, 7)
  hero.goFill:SetAllPoints()
  hero.goFill:SetBlendMode("ADD")
  hero.goFill:SetAlpha(0)
  hero.goAnim = Bounce(hero.goFill, 0.05, 0.4, 0.28)
  hero.labelAnim = Bounce(hero.label, 1, 0.25, 0.28)

  hero.empty = Text(hero, "bold", 15)
  hero.empty:SetPoint("CENTER", 0, 7)
  hero.empty:SetTextColor(0.42, 0.43, 0.48)
  hero.empty:SetText("NOBODY IN REACH")
  hero.emptySub = Text(hero, "medium", 11)
  hero.emptySub:SetPoint("TOP", hero.empty, "BOTTOM", 0, -3)
  hero.emptySub:SetTextColor(0.36, 0.37, 0.42)
  hero.emptySub:SetText("holding priority order")
end

-- Shared look for the other Warboard windows (Timers.lua's res timers).
ns.UI = { Text = Text, Fill = Fill, WHITE = WHITE, INK = INK, ACCENT = ACCENT, MUTED = MUTED }

local execCurve
local function BuildCurve()
  if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then
    return
  end
  execCurve = C_CurveUtil.CreateColorCurve()
  execCurve:SetType(Enum.LuaCurveType.Step)
  execCurve:AddPoint(0, CreateColor(1, 0, 0, 1))
  execCurve:AddPoint(db.executePct, CreateColor(1, 0, 0, 0))
end

-- Sniper scope floating above the kill target's nameplate in the world.
-- Nameplate-addon safe (Plater, Kui, Platynator...): the scope is our own
-- UIParent child that is only ANCHORED to the plate; we never reparent, hook,
-- resize or add children to any nameplate, and it ignores the mouse.
-- Built from plain lines (no external art): crosshair with a center gap,
-- corner brackets, center dot. Pulses; bigger/brighter during a kill window.
local sniper = CreateFrame("Frame", "WarboardSniper", UIParent)
sniper:SetSize(52, 52)
sniper:SetFrameStrata("HIGH")
sniper:EnableMouse(false)
sniper:Hide()
sniper.parts = {} -- colored strokes
do
  -- Each stroke = black outline underneath + colored core on top, so it reads
  -- on any background (grass, snow, water, spell effects).
  local OUT = 2 -- outline width on each side
  local function Stroke(w, h, point, rel, x, y)
    local o = sniper:CreateTexture(nil, "ARTWORK")
    o:SetColorTexture(0, 0, 0, 0.9)
    o:SetSize(w + OUT * 2, h + OUT * 2)
    o:SetPoint(point, sniper, rel or "CENTER", x + (point:find("LEFT") and -OUT or point:find("RIGHT") and OUT or 0),
      y + (point:find("TOP") and OUT or point:find("BOTTOM") and -OUT or 0))
    local c = sniper:CreateTexture(nil, "OVERLAY")
    c:SetColorTexture(1, 1, 1, 1)
    c:SetSize(w, h)
    c:SetPoint(point, sniper, rel or "CENTER", x, y)
    table.insert(sniper.parts, c)
  end
  local S, G, T = 26, 7, 4 -- half-size, center gap, stroke thickness
  Stroke(T, S - G, "BOTTOM", nil, 0, G) -- up
  Stroke(T, S - G, "TOP", nil, 0, -G) -- down
  Stroke(S - G, T, "RIGHT", nil, -G, 0) -- left
  Stroke(S - G, T, "LEFT", nil, G, 0) -- right
  Stroke(5, 5, "CENTER", nil, 0, 0) -- dot
  local B = 11 -- bracket arm length
  for _, c in ipairs({ { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }) do
    local cx, cy = c[1] * S, c[2] * S
    Stroke(B, T, c[1] < 0 and "LEFT" or "RIGHT", nil, cx, cy + (c[2] > 0 and -T / 2 or T / 2))
    Stroke(T, B, c[2] > 0 and "TOP" or "BOTTOM", nil, cx + (c[1] < 0 and T / 2 or -T / 2), cy)
  end
  local pulse = sniper:CreateAnimationGroup()
  pulse:SetLooping("BOUNCE")
  local a = pulse:CreateAnimation("Alpha")
  a:SetFromAlpha(1)
  a:SetToAlpha(0.6)
  a:SetDuration(0.6)
  a:SetSmoothing("IN_OUT")
  sniper.pulse = pulse
end

-- High-contrast colors that rarely appear in BG scenery.
local SNIPER_COLORS = {
  magenta = { 1, 0.15, 0.85 },
  cyan = { 0.1, 0.95, 1 },
  yellow = { 1, 0.95, 0.1 },
  lime = { 0.55, 1, 0.1 },
  white = { 1, 1, 1 },
  orange = { 1, 0.45, 0.05 },
}
local SNIPER_GO_COLOR = { 1, 0.08, 0.05 }

-- Lock-on sounds: our own synthesized file first, then SoundKit IDs
-- (see SoundKitConstants.lua).
local SNIPER_SOUNDS = {
  { file = "Interface\\AddOns\\Warboard\\sounds\\lockon.ogg", name = "Warboard lock-on" },
  { id = 3175, name = "ping" }, -- MAP_PING
  { id = 37666, name = "boss whisper" }, -- UI_RAID_BOSS_WHISPER_WARNING
  { id = 12889, name = "alarm" }, -- ALARM_CLOCK_WARNING_3
  { id = 76995, name = "prestige" }, -- UI_PVP_HONOR_PRESTIGE_OPEN_WINDOW
}

local function PlaySniperSound()
  local snd = SNIPER_SOUNDS[db.sniperSound or 0]
  if snd and snd.file then
    -- New files are only visible after a full client restart; until then
    -- PlaySoundFile returns false, so fall back to a built-in chime.
    if not PlaySoundFile(snd.file, "Master") then
      PlaySound(37666, "Master")
    end
  elseif snd then
    PlaySound(snd.id, "Master")
  end
end

-- Kill-window sting (custom file; raid warning until the client has been
-- restarted once and can see the new file).
local PlayGoSound
local GO_SOUND = "Interface\\AddOns\\Warboard\\sounds\\go.ogg"
PlayGoSound = function()
  if not PlaySoundFile(GO_SOUND, "Master") then
    PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
  end
end

local function UpdateSniper(e, isGo)
  local plate = db.sniper and e and e.plateUnit and C_NamePlate and C_NamePlate.GetNamePlateForUnit
    and C_NamePlate.GetNamePlateForUnit(e.plateUnit)
  if not plate or (plate.IsForbidden and plate:IsForbidden()) then
    sniper.unit = nil
    sniper:Hide()
    sniper.pulse:Stop()
    return
  end
  sniper.unit = e.plateUnit
  -- Lock-on sound only when the scope moves to a NEW enemy: the same enemy's
  -- nameplate dropping out and back in stays silent.
  local key = e.key or CanonUnit(e.plateUnit)
  if key and key ~= sniper.soundKey then
    sniper.soundKey = key
    PlaySniperSound()
  end
  if sniper.anchor ~= plate or sniper.anchorY ~= db.sniperY then
    sniper:ClearAllPoints()
    -- On the body: centered below the nameplate (the plate floats over the
    -- head), clear of overhead orb/flag effects. /wb sniper y N adjusts.
    if not pcall(sniper.SetPoint, sniper, "CENTER", plate, "BOTTOM", 0, db.sniperY) then
      sniper:Hide()
      return
    end
    sniper.anchor, sniper.anchorY = plate, db.sniperY
  end
  local col = isGo and SNIPER_GO_COLOR or SNIPER_COLORS[db.sniperColor] or SNIPER_COLORS.magenta
  for _, t in ipairs(sniper.parts) do
    t:SetVertexColor(col[1], col[2], col[3])
  end
  sniper:SetScale((db.sniperScale or 1) * (isGo and 1.3 or 1))
  if not sniper:IsShown() then
    sniper:Show()
    sniper.pulse:Play()
  end
end

-- /wb sniper test: scope on your current target's nameplate, anywhere
-- (open world, no panel). /wb go toggles the kill-window look while testing.
local sniperTest = { on = false, go = false }
local sniperDriver = CreateFrame("Frame")
sniperDriver:Hide()
sniperDriver.elapsed = 0
sniperDriver:SetScript("OnUpdate", function(self, dt)
  self.elapsed = self.elapsed + dt
  if self.elapsed < 0.1 then
    return
  end
  self.elapsed = 0
  local unit
  if UnitExists("target") and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    unit = plate and plate.namePlateUnitToken
    if not unit then
      for i = 1, 40 do
        local ok, same = pcall(UnitIsUnit, "nameplate" .. i, "target")
        if ok and plain(same) and same == true then
          unit = "nameplate" .. i
          break
        end
      end
    end
  end
  UpdateSniper(unit and { plateUnit = unit } or nil, sniperTest.go)
end)

-- Target calling. Addons can't send chat during a PvP match (chat messaging
-- lockdown), so we PRE-FILL your chat box and you press Enter: the message is
-- then sent by you, not by addon code.
local CALL_CHANNELS = { s = "/s ", i = "/i ", raid = "/raid ", y = "/y ", party = "/p " }
local callEntry -- current kill target (GO entry or kill-now), set by Render
local killNow -- live kill target: best e.live, sticky (see PickKillNow)
local KILL_SWITCH_MARGIN = 8

local function CallTarget(e)
  e = e or callEntry
  if not e then
    print("|cffff5533Warboard|r no kill target to call")
    return
  end
  local name = e.display:match("^[^-]+")
  local si = e.specID and specInfo[e.specID]
  local who = si and (si.name .. " " .. (LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class))
    or (LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class)
  local extra = ""
  local stacks = CarrierStacks(e)
  if e.carrier and obj.mode == "orb" then
    extra = string.format(" - ORB +%d%%", stacks or 30)
  elseif e.carrier then
    extra = stacks and string.format(" - FLAG CARRIER %d stacks", stacks) or " - FLAG CARRIER"
  elseif e.burnedAt and GetTime() - e.burnedAt < KILL_WINDOW then
    extra = " - defensive down, GO"
  end
  local msg = string.format("{rt8} KILL %s (%s)%s {rt8}", name, who, extra)
  local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if open then
    open((CALL_CHANNELS[db.callChannel] or "/s ") .. msg)
  end
end
Warboard_Call = function()
  CallTarget()
end
BINDING_NAME_WARBOARD_CALL = "Call kill target in chat (press Enter to send)"

-- Rows are secure buttons: left-click targets, right-click focuses. Blizzard
-- forbids changing their macro, position or visibility in combat, so each row
-- stays bound to one enemy until combat ends; only its visuals and rank number
-- update live. Visuals sit on a plain child frame so alpha changes stay legal.
local MAX_ROWS = 15
local rows = {}
local layoutPending = false

local function ShowTooltip(self)
  local e = self.entry
  if not e then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[e.class]
  GameTooltip:AddDoubleLine(e.display, string.format("%.0f  |cff888888live %.0f|r", e.base or 0, e.live or 0), c and c.r or 1, c and c.g or 1,
    c and c.b or 1, ACCENT[1], ACCENT[2], ACCENT[3])
  local si = e.specID and specInfo[e.specID]
  local cls = LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class
  if si then
    GameTooltip:AddLine(si.name .. " " .. cls .. (e.specSrc == "hist" and "  |cff888888(from history)|r" or ""),
      0.8, 0.8, 0.8)
  else
    GameTooltip:AddLine(cls .. "  |cff888888(spec hidden: ranked by class)|r", 0.8, 0.8, 0.8)
  end
  if e.note then
    GameTooltip:AddLine(e.note, 0.6, 0.85, 1, true)
  end
  local where = ns.MapWhere and ns.MapWhere(e.key)
  if where then
    GameTooltip:AddLine("Location: " .. where, 0.55, 0.8, 1)
  end
  if e.cast then
    GameTooltip:AddLine(string.format("Casting %s%s", e.cast.name, e.cast.kickable and "" or " (can't be kicked)"),
      1, 0.82, 0.25)
  end
  -- Class breakdown: down (seen used) first, green = opportunity.
  local kit = KitFor(e)
  if #kit > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Cooldowns (combat log)", 0.55, 0.56, 0.62)
    local downs, ready = {}, {}
    for _, entry in ipairs(kit) do
      local left = CdLeft(e, entry)
      if left then
        downs[#downs + 1] = { entry, left }
      else
        ready[#ready + 1] = entry
      end
    end
    for _, d in ipairs(downs) do
      GameTooltip:AddDoubleLine(d[1][4], "DOWN " .. Clock(d[2]), 0.3, 0.9, 0.45, 0.3, 0.9, 0.45)
    end
    for _, entry in ipairs(ready) do
      GameTooltip:AddDoubleLine(entry[4], "ready", 0.75, 0.75, 0.78, 0.45, 0.45, 0.5)
    end
  end
  for _, reason in ipairs(e.reasons or {}) do
    GameTooltip:AddLine("• " .. reason, 0.85, 0.85, 0.85, true)
  end
  if e.comp then
    local parts = {}
    for _, w in ipairs(WEIGHTS) do
      local v = e.comp[w.key]
      if v and math.abs(v) >= 0.5 then
        parts[#parts + 1] = string.format("%s %+.0f", w.key, v)
      end
    end
    GameTooltip:AddLine(table.concat(parts, "  "), 0.55, 0.55, 0.6, true)
  end
  if not e.unit then
    GameTooltip:AddLine("Out of sight: health and auras unknown", 0.5, 0.5, 0.5, true)
  end
  local cfg = (me.range or ns.RangeBands[me.class])
  local reach = cfg and (cfg.reachYards or cfg.attackYards) or 40
  if e == killNow then
    GameTooltip:AddLine(string.format("KILL TARGET: best live score within %d yd", reach), ACCENT[1], ACCENT[2],
      ACCENT[3], true)
  elseif e.dead then
    GameTooltip:AddLine("Dead", 0.5, 0.5, 0.5)
  elseif not ns.InReach(e) then
    GameTooltip:AddLine(e.yards and string.format("Not kill target: ~%d yd, beyond your %d yd reach", e.yards, reach)
      or string.format("Not kill target: not within %d yd (or not visible)", reach), 0.6, 0.6, 0.6, true)
  elseif killNow then
    GameTooltip:AddLine(string.format("In reach, but %s scores higher (live %.0f vs %.0f)",
      killNow.display:match("^[^-]+"), killNow.live or 0, e.live or 0), 0.6, 0.6, 0.6, true)
  end
  GameTooltip:AddLine("|cff66ff66Left|r target   |cff66ff66Right|r focus   |cff66ff66Shift|r call in chat", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

-- "Target X, focus/mark it, then go back to your target": with NO target
-- before the click, /targetlasttarget has nothing to return to and leaves
-- you on the enemy. A secure snippet (allowed in combat) checks at click
-- time and ends the macro with /targetlasttarget or /cleartarget.
-- Buttons store the macro without its last line in "wb-<attribute>".
local restoreHeader = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
local RESTORE_SNIPPET = [[
  local attr = (button == "RightButton") and "macrotext2" or "macrotext"
  local body = self:GetAttribute("wb-" .. attr)
  if body and body ~= "" then
    if UnitExists("target") then
      self:SetAttribute(attr, body .. "\n/targetlasttarget")
    else
      self:SetAttribute(attr, body .. "\n/cleartarget")
    end
  end
]]
local function WrapRestore(btn)
  if restoreHeader.WrapScript then
    pcall(restoreHeader.WrapScript, restoreHeader, btn, "OnClick", RESTORE_SNIPPET)
  end
end

-- Set a target-then-return macro: the fallback text (if the snippet can't
-- run) plus the body the snippet completes.
local function SetReturnMacro(btn, attr, body)
  btn:SetAttribute("wb-" .. attr, body or "")
  btn:SetAttribute(attr, body and (body .. "\n/targetlasttarget") or "")
end

local function CreateRow(i)
  local r = CreateFrame("Button", "WarboardRow" .. i, frame, "SecureActionButtonTemplate")
  r:SetSize(WIDTH - PAD * 2, ROW_H)
  r:SetPoint("TOPLEFT", PAD, -LIST_TOP - (i - 1) * (ROW_H + GAP))
  -- Addon secure buttons count as key presses: with ActionButtonUseKeyDown
  -- (default on) they only act on mouse-down, otherwise on mouse-up. Register
  -- both; SecureActionButton_OnClick runs the action on exactly one of them.
  r:RegisterForClicks("AnyDown", "AnyUp")
  r:SetAttribute("type1", "macro")
  r:SetAttribute("type2", "macro")
  -- Shift+click = call in chat (PostClick) without targeting: an empty macro.
  r:SetAttribute("shift-type1", "macro")
  r:SetAttribute("shift-macrotext1", "")
  WrapRestore(r)
  r:Hide()

  local c = CreateFrame("Frame", nil, r)
  c:SetAllPoints()
  r.content = c

  -- Zebra slab; tinted with the accent on the kill target.
  r.bg = Fill(c, "BACKGROUND", 1, 1, 1, i % 2 == 0 and 0.025 or 0.045)
  r.bg:SetAllPoints()
  r.topTint = Fill(c, "BACKGROUND", ACCENT[1], ACCENT[2], ACCENT[3], 0.14, 1)
  r.topTint:SetAllPoints()
  r.topTint:Hide()

  -- Position tile: light slab + dark number; accent on the kill target.
  r.tile = Fill(c, "BORDER", 0.92, 0.92, 0.94)
  r.tile:SetPoint("TOPLEFT")
  r.tile:SetPoint("BOTTOMLEFT")
  r.tile:SetWidth(TILE_W)
  -- Gained/lost places: the tile flashes green/red and fades (timing feed).
  r.tileFlash = Fill(c, "ARTWORK", 1, 1, 1, 1)
  r.tileFlash:SetAllPoints(r.tile)
  r.tileFlash:SetAlpha(0)
  do
    local g = r.tileFlash:CreateAnimationGroup()
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0)
    a:SetDuration(1.8)
    a:SetSmoothing("IN")
    r.tileFlashAnim = g
  end
  r.rank = Text(c, "bold", 14)
  r.rank:SetPoint("CENTER", r.tile, "CENTER", 0, 0)
  r.rank:SetShadowOffset(0, 0)

  -- Team color: class strip right of the tile.
  r.strip = Fill(c, "ARTWORK", 1, 1, 1)
  r.strip:SetPoint("TOPLEFT", r.tile, "TOPRIGHT")
  r.strip:SetPoint("BOTTOMLEFT", r.tile, "BOTTOMRIGHT")
  r.strip:SetWidth(3)

  r.icon = c:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(16, 16)
  r.icon:SetPoint("LEFT", r.strip, "RIGHT", 5, 1)

  -- Raid marker on the spec icon (top-left).
  r.marker = c:CreateTexture(nil, "OVERLAY", nil, 3)
  r.marker:SetSize(10, 10)
  r.marker:SetPoint("TOPLEFT", r.icon, "TOPLEFT", -3, 3)
  r.marker:Hide()

  -- Right cluster, right to left: pip, gap to P1, yards, spec.
  r.pip = c:CreateTexture(nil, "OVERLAY")
  r.pip:SetSize(13, 13)
  r.pip:SetPoint("RIGHT", -5, 1)
  r.pip:SetTexture(CIRCLE)
  r.pipText = Text(c, "mono", 8)
  r.pipText:SetPoint("CENTER", r.pip, "CENTER", 0, 0)
  r.pipText:SetShadowOffset(0, 0)
  r.pipText:SetTextColor(0.05, 0.05, 0.06)

  r.gap = Text(c, "mono", 10)
  r.gap:SetPoint("RIGHT", r.pip, "LEFT", -5, 0)
  r.gap:SetWidth(32)
  r.gap:SetJustifyH("RIGHT")

  r.dist = Text(c, "mono", 10)
  r.dist:SetPoint("RIGHT", r.gap, "LEFT", -3, 0)
  r.dist:SetWidth(20)
  r.dist:SetJustifyH("RIGHT")
  -- Secret range answer: the game can light this dot, we can't read it.
  r.rangeDot = c:CreateTexture(nil, "OVERLAY")
  r.rangeDot:SetSize(5, 5)
  r.rangeDot:SetTexture(CIRCLE)
  r.rangeDot:SetVertexColor(0.3, 0.95, 0.4)
  r.rangeDot:SetPoint("RIGHT", r.dist, "RIGHT", 0, 0)
  r.rangeDot:SetAlpha(0)

  r.spec = Text(c, "medium", 10)
  r.spec:SetPoint("RIGHT", r.dist, "LEFT", -6, 0)
  r.spec:SetJustifyH("RIGHT")

  -- Teammates on it (x3) and targeting-you eye, left of the spec.
  r.allyText = Text(c, "mono", 9)
  r.allyText:SetPoint("RIGHT", r.spec, "LEFT", -4, 0)
  r.eye = c:CreateTexture(nil, "OVERLAY")
  r.eye:SetSize(11, 11)
  r.eye:SetTexture("Interface\\Icons\\Ability_EyeOfTheOwl")
  r.eye:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.eye:SetPoint("RIGHT", r.allyText, "LEFT", -3, 0)
  r.eye:SetAlpha(0)

  r.name = Text(c, "semi", 13)
  r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
  r.name:SetPoint("RIGHT", r.eye, "LEFT", -3, 0)
  r.name:SetJustifyH("LEFT")

  -- Health: hairline along the bottom (secret values go straight in).
  r.hp = CreateFrame("StatusBar", nil, c)
  r.hp:SetPoint("BOTTOMLEFT", r.strip, "BOTTOMRIGHT", 0, 0)
  r.hp:SetPoint("BOTTOMRIGHT")
  r.hp:SetHeight(2)
  r.hp:SetStatusBarTexture(WHITE)
  r.hp:SetMinMaxValues(0, 1)
  r.hp.bg = Fill(r.hp, "BACKGROUND", 1, 1, 1, 0.06)
  r.hp.bg:SetAllPoints()

  -- Cast bar: hairline along the top, amber = kickable, grey = not.
  r.cast = CreateFrame("StatusBar", nil, c)
  r.cast:SetPoint("TOPLEFT", r.strip, "TOPRIGHT", 0, 0)
  r.cast:SetPoint("TOPRIGHT")
  r.cast:SetHeight(2)
  r.cast:SetStatusBarTexture(WHITE)
  r.cast:Hide()

  -- Shown (via secret alpha) under the execute threshold.
  r.exec = Border(c, 1, 0.15, 0.1, 1, 1)
  r.exec:SetAlpha(0)

  -- Live kill target outline.
  r.top = Border(c, ACCENT[1], ACCENT[2], ACCENT[3], 1, 1)
  r.top:SetFrameLevel(c:GetFrameLevel() + 4)

  -- Your current target: thin, steady grey outline + small arrow outside the
  -- panel. Deliberately quieter than the kill target: targeting someone says
  -- nothing about whether they're the right kill.
  r.sel = Border(c, 0.8, 0.8, 0.85, 0.6, 1)
  r.sel:SetFrameLevel(c:GetFrameLevel() + 5)
  r.sel:Hide()
  r.arrow = c:CreateTexture(nil, "OVERLAY")
  r.arrow:SetSize(12, 12)
  r.arrow:SetPoint("RIGHT", r, "LEFT", -PAD - 1, 0)
  r.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  r.arrow:SetVertexColor(0.75, 0.75, 0.8, 0.8)
  r.arrow:Hide()

  -- Kill window: red fill + glow pulsing fast, plus a one-shot pop.
  r.goFill = Fill(c, "ARTWORK", 1, 0.1, 0.05, 1, 7)
  r.goFill:SetAllPoints()
  r.goFill:SetBlendMode("ADD")
  r.goFill:SetAlpha(0)
  r.goGlow = Border(c, 1, 0.15, 0.05, 1, 2)
  r.goGlow:SetFrameLevel(c:GetFrameLevel() + 6)
  r.goGlow:Hide()
  r.goFillAnim = Bounce(r.goFill, 0.05, 0.4, 0.28)
  r.goGlowAnim = Bounce(r.goGlow, 1, 0.2, 0.28)
  local pop = c:CreateAnimationGroup()
  local grow = pop:CreateAnimation("Scale")
  grow:SetScale(1.04, 1.2)
  grow:SetDuration(0.12)
  grow:SetOrder(1)
  grow:SetSmoothing("OUT")
  local shrink = pop:CreateAnimation("Scale")
  shrink:SetScale(1 / 1.04, 1 / 1.2)
  shrink:SetDuration(0.18)
  shrink:SetOrder(2)
  shrink:SetSmoothing("IN")
  r.goPop = pop

  r:SetScript("OnEnter", ShowTooltip)
  r:SetScript("OnLeave", GameTooltip_Hide)
  r:SetScript("PostClick", function(self, button, down)
    if not down and button == "LeftButton" and IsShiftKeyDown() and self.entry then
      CallTarget(self.entry)
    end
  end)
  return r
end
for i = 1, MAX_ROWS do
  rows[i] = CreateRow(i)
end

-- Hero card click: a secure button laid over the card (left-click target,
-- right-click focus, shift-click call in chat). Like the rows, Blizzard only
-- lets its macro change out of combat: UpdateTargetButton keeps it on the
-- kill target, and the card says so when combat pinned it to someone else.
local heroBtn = CreateFrame("Button", "WarboardHeroButton", frame, "SecureActionButtonTemplate")
heroBtn:SetAllPoints(hero)
heroBtn:SetFrameLevel(hero:GetFrameLevel() + 10)
heroBtn:RegisterForClicks("AnyDown", "AnyUp") -- see CreateRow
heroBtn:SetAttribute("type1", "macro")
heroBtn:SetAttribute("type2", "macro")
heroBtn:SetAttribute("shift-type1", "macro")
heroBtn:SetAttribute("shift-macrotext1", "")
WrapRestore(heroBtn)
hero.hover = Fill(hero, "BORDER", 1, 1, 1, 0.05)
hero.hover:SetAllPoints()
hero.hover:Hide()
hero.clickNote = Text(hero, "mono", 8)
hero.clickNote:SetPoint("BOTTOMRIGHT", hero, "BOTTOMRIGHT", -9, 8)
hero.clickNote:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
heroBtn:SetScript("OnEnter", function(self)
  hero.hover:Show()
  ShowTooltip(self)
end)
heroBtn:SetScript("OnLeave", function()
  hero.hover:Hide()
  GameTooltip_Hide()
end)
heroBtn:SetScript("PostClick", function(self, button, down)
  if not down and button == "LeftButton" and IsShiftKeyDown() and self.entry then
    CallTarget(self.entry)
  end
end)

-- Health is secret for enemies: values go straight into the StatusBar, never
-- compared. Primary: UnitHealthPercent (0..1, no curve dependency). Fallback:
-- UnitHealth / UnitHealthMax as the bar range (both may be secret; BGE does
-- the same). Failures are counted in WarboardDB.liveStats.health and the
-- first error text kept in WarboardDB.healthErr.
local function NoteHealthErr(err)
  if not db.healthErr then
    db.healthErr = tostring(err)
  end
end

local function UpdateHealth(r, unit, color)
  if not unit then
    -- Unknown health: full, faded bar.
    if r.hpMode ~= "pct" then
      r.hp:SetMinMaxValues(0, 1)
      r.hpMode = "pct"
    end
    r.hp:SetValue(1)
    r.hp:SetStatusBarColor(color.r, color.g, color.b, 0.28)
    r.exec:SetAlpha(0)
    return
  end
  r.hp:SetStatusBarColor(color.r, color.g, color.b, 0.9)

  local ok, pct = pcall(UnitHealthPercent, unit, true)
  local drawn = false
  if ok and type(pct) ~= "nil" then
    if r.hpMode ~= "pct" then
      r.hp:SetMinMaxValues(0, 1)
      r.hpMode = "pct"
    end
    local okSet, err = pcall(r.hp.SetValue, r.hp, pct)
    drawn = okSet
    Stat("health", okSet and "pct" or "pctSetFail")
    if not okSet then
      NoteHealthErr(err)
    end
  else
    Stat("health", "pctFail")
    if not ok then
      NoteHealthErr(pct)
    end
  end
  if not drawn then
    local okH, hp = pcall(UnitHealth, unit)
    local okM, maxHp = pcall(UnitHealthMax, unit)
    if okH and okM and type(hp) ~= "nil" and type(maxHp) ~= "nil" then
      local okSet, err = pcall(function()
        r.hp:SetMinMaxValues(0, maxHp)
        r.hp:SetValue(hp)
      end)
      r.hpMode = "abs"
      Stat("health", okSet and "abs" or "absFail")
      if not okSet then
        NoteHealthErr(err)
      end
    else
      Stat("health", "noData")
    end
  end

  if execCurve then
    local ok2, col = pcall(UnitHealthPercent, unit, true, execCurve)
    if ok2 and type(col) == "table" then
      local okA, _, _, _, a = pcall(col.GetRGBA, col)
      if okA then
        pcall(r.exec.SetAlpha, r.exec, a)
      end
    end
  else
    -- No color curves (Cata): health is plain, compare directly.
    local okH, cur = pcall(UnitHealth, unit)
    local okM, mx = pcall(UnitHealthMax, unit)
    if okH and okM and plain(cur) and plain(mx) and mx > 0 then
      r.exec:SetAlpha(cur / mx <= db.executePct and 1 or 0)
    end
  end
end

-- Out of combat only: bind rows to the current order, set their macros,
-- show/hide them and resize the panel.
local function Layout()
  if InCombatLockdown() then
    layoutPending = true
    return
  end
  layoutPending = false
  local shown = math.min(#order, db.rows, MAX_ROWS)
  for i = 1, MAX_ROWS do
    local r = rows[i]
    local e = i <= shown and order[i] or nil
    if r.entry ~= e or (e and r.boundName ~= e.key) then
      r.entry = e
      r.boundName = e and e.key
      local name = e and DisplayName(e.key)
      r:SetAttribute("macrotext1", name and ("/targetexact " .. name) or "")
      -- /focus takes a unit, not a name: target by exact name, focus that,
      -- then return to the previous target.
      SetReturnMacro(r, "macrotext2", name and ("/targetexact " .. name .. "\n/focus"))
    end
    r:SetShown(e ~= nil)
  end
  frame:SetHeight(LIST_TOP + math.max(shown, 0) * (ROW_H + GAP) - (shown > 0 and GAP or 0) + PAD)
end

local GREY = { r = 0.5, g = 0.5, b = 0.5 }

-- Within reach: a plain range answer puts the enemy inside your class's
-- reachYards. This is a hard gate, not a score: whether you target, focus
-- or mouse over someone never matters, only how far away they are.
local function InReach(e)
  if not e.yards or e.dead then
    return false
  end
  local cfg = (me.range or ns.RangeBands[me.class])
  return e.yards <= ((cfg and (cfg.reachYards or cfg.attackYards)) or 40)
end
ns.InReach = InReach

-- Live kill target: among enemies within reach, the one with the best live
-- score (proximity, priority, defensives, CC, objective). Nobody within
-- reach -> no kill target (the list order is still the priority). Sticky:
-- only switch when another leads by KILL_SWITCH_MARGIN, or the current one
-- died / left the roster / left your reach.
local function PickKillNow()
  local best
  for _, e in ipairs(order) do
    if InReach(e) and (not best or e.live > best.live) then
      best = e
    end
  end
  if killNow and (not enemies[killNow.key] or not InReach(killNow)) then
    killNow = nil
  end
  if not killNow or (best and best ~= killNow and best.live > killNow.live + KILL_SWITCH_MARGIN) then
    killNow = best
  end
  return killNow
end

-- Short spec tags for the tower (by specID: locale-proof).
local SPEC_SHORT = {
  [250] = "BLOOD", [251] = "FROST", [252] = "UNHOLY", [577] = "HAVOC", [581] = "VENG", [1480] = "DEVOUR",
  [102] = "BAL", [103] = "FERAL", [104] = "GUARD", [105] = "RESTO", [1467] = "DEV", [1468] = "PRES",
  [1473] = "AUG", [253] = "BM", [254] = "MM", [255] = "SURV", [62] = "ARCANE", [63] = "FIRE", [64] = "FROST",
  [268] = "BREW", [269] = "WW", [270] = "MW", [65] = "HOLY", [66] = "PROT", [70] = "RET", [256] = "DISC",
  [257] = "HOLY", [258] = "SHADOW", [259] = "SIN", [260] = "OUTLAW", [261] = "SUB", [262] = "ELE",
  [263] = "ENH", [264] = "RESTO", [265] = "AFF", [266] = "DEMO", [267] = "DESTRO", [71] = "ARMS",
  [72] = "FURY", [73] = "PROT",
}

local function StatusPip(e)
  if e.dead then
    return nil
  elseif e.def then
    return PIP.def
  elseif e.cc then
    return PIP.cc
  elseif e.stun then
    return PIP.stun
  elseif e.crowdControlled then
    return PIP.control
  elseif e.carrier or e.testStacks then
    return PIP.carrier
  elseif e.burnedAt and GetTime() - e.burnedAt < BURN_WINDOW then
    return PIP.spent
  elseif ns.KitCommon and CdLeft(e, ns.KitCommon[1]) then
    return PIP.notrinket
  elseif e.burst then
    return PIP.burst
  end
end

local function Reach()
  local cfg = (me.range or ns.RangeBands[me.class])
  return cfg and (cfg.reachYards or cfg.attackYards) or 40
end

local function ClassName(e)
  local cls = LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class
  local si = e.specID and specInfo[e.specID]
  return si and (si.name .. " " .. cls) or cls
end

-- Hero card: the live kill target (or "nobody in reach").
local function UpdateHero(e, isGo)
  local show = e ~= nil
  heroBtn.entry = e
  -- Click is pinned (combat) to someone other than the card: say who.
  local pinned = heroBtn.boundKey
  if pinned ~= (e and e.key) and (pinned or e) then
    local who = pinned and enemies[pinned]
    hero.clickNote:SetText("CLICK: " .. (who and who.display:match("^[^-]+"):upper() or "NONE") .. " (COMBAT)")
    hero.clickNote:Show()
    if who then
      heroBtn.entry = who
    end
  else
    hero.clickNote:Hide()
  end
  hero.empty:SetShown(not show)
  hero.emptySub:SetShown(not show)
  hero.label:SetShown(show)
  hero.name:SetShown(show)
  hero.sub:SetShown(show)
  hero.dist:SetShown(show)
  hero.unitText:SetShown(show)
  hero.hp:SetShown(show)
  for _, t in ipairs(hero.meter) do
    t:SetShown(show)
  end
  if not show then
    hero.strip:SetColorTexture(0.25, 0.25, 0.3, 1)
    hero.exec:SetAlpha(0)
    if hero.isGo then
      hero.isGo = false
      hero.goAnim:Stop()
      hero.labelAnim:Stop()
      hero.goFill:SetAlpha(0)
    end
    return
  end

  local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[e.class] or GREY
  hero.strip:SetColorTexture(color.r, color.g, color.b, 1)
  hero.name:SetText(e.display:match("^[^-]+"):upper())
  hero.name:SetTextColor(color.r, color.g, color.b)

  local bits = { ClassName(e) }
  local stacks = CarrierStacks(e)
  if e.carrier or e.testStacks then
    bits[#bits + 1] = obj.mode == "orb" and string.format("ORB +%d%%", stacks or 30)
      or (stacks and string.format("FLAG x%d", stacks) or "FLAG")
  end
  if e.hpPct then
    bits[#bits + 1] = string.format("%d%% hp", math.floor(e.hpPct * 100 + 0.5))
  end
  if e.manaPct and IsHealer(e) and e.manaPct * 100 <= P("oomPct") then
    bits[#bits + 1] = string.format("|cff6fa8ffOOM %d%%|r", math.floor(e.manaPct * 100 + 0.5))
  end
  if (e.allyCount or 0) > 0 then
    bits[#bits + 1] = string.format("%d on it", e.allyCount)
  end
  if e.cast then
    bits[#bits + 1] = string.format("|cffffc433%s %s|r", e.cast.name:upper(), e.cast.kickable and "\194\183 KICK" or "")
  end
  local where = ns.MapWhere and ns.MapWhere(e.key)
  if where and not e.unit then
    bits[#bits + 1] = "|cff8cc8ff" .. where:upper() .. "|r"
  end
  local down = DownSummary(e, 3)
  if down then
    bits[#bits + 1] = "|cff4de673" .. down .. "|r"
  end
  if e.onMe then
    bits[#bits + 1] = "|cffff5555on you|r"
  end
  if e.burnedAt and GetTime() - e.burnedAt < BURN_WINDOW then
    bits[#bits + 1] = string.format("|cff4de673def spent %ds|r", math.floor(GetTime() - e.burnedAt))
  end
  hero.sub:SetText(table.concat(bits, "  \194\183  "))

  hero.dist:SetText(e.yards)
  local reach = Reach()
  local lit = math.max(1, math.min(METER_SEGS, METER_SEGS - math.floor((e.yards - 1) / (reach / METER_SEGS))))
  local mc = isGo and { 1, 0.15, 0.1 } or ACCENT
  for s, t in ipairs(hero.meter) do
    if s <= lit then
      t:SetColorTexture(mc[1], mc[2], mc[3], 1)
    else
      t:SetColorTexture(1, 1, 1, 0.1)
    end
  end
  UpdateHealth(hero, e.unit, color)

  if isGo then
    hero.label:SetText("GO  \194\183  DEFENSIVE DOWN")
    hero.label:SetTextColor(1, 0.25, 0.15)
  else
    hero.label:SetText("KILL TARGET")
    hero.label:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
  end
  if isGo ~= (hero.isGo or false) then
    hero.isGo = isGo
    if isGo then
      hero.goAnim:Play()
      hero.labelAnim:Play()
    else
      hero.goAnim:Stop()
      hero.labelAnim:Stop()
      hero.goFill:SetAlpha(0)
      hero.label:SetAlpha(1)
    end
  end
end

-- Any time: refresh each row's visuals from its bound enemy. Rank numbers
-- follow the live order even when rows can't move (combat).
local rankOf = {}
local function Render()
  wipe(rankOf)
  local topLive = -math.huge
  local firstAlive = PickKillNow()
  local leader
  for i, e in ipairs(order) do
    rankOf[e] = i
    if not e.dead then
      leader = leader or e
      if e.live > topLive then
        topLive = e.live
      end
    end
  end
  local inCombat = InCombatLockdown()
  local needsLayout = false
  local targetKey = UnitExists("target") and CanonUnit("target") or nil
  local reach = Reach()
  local now = GetTime()
  local goEntry
  for i = 1, MAX_ROWS do
    local r = rows[i]
    local e = r.entry
    if e and not enemies[e.key] then
      e = nil
    end
    if e then
      local rank = rankOf[e]
      if rank ~= i then
        needsLayout = true
      end
      local isTop = e == firstAlive
      local color = e.dead and GREY or (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[e.class] or GREY

      -- Position tile: number, accent on the kill target, flash on a move.
      r.rank:SetText(rank or "")
      if isTop then
        r.tile:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
        r.rank:SetTextColor(0.05, 0.05, 0.06)
      elseif e.dead then
        r.tile:SetColorTexture(0.22, 0.22, 0.26, 1)
        r.rank:SetTextColor(0.6, 0.6, 0.65)
      else
        r.tile:SetColorTexture(0.92, 0.92, 0.94, 1)
        r.rank:SetTextColor(0.05, 0.05, 0.06)
      end
      if rank and e.shownRank and rank ~= e.shownRank then
        if rank < e.shownRank then
          r.tileFlash:SetColorTexture(0.25, 0.9, 0.45, 1)
        else
          r.tileFlash:SetColorTexture(1, 0.25, 0.25, 1)
        end
        r.tileFlashAnim:Stop()
        r.tileFlashAnim:Play()
      end
      e.shownRank = rank
      r.top:SetShown(isTop)
      r.topTint:SetShown(isTop)

      r.strip:SetColorTexture(color.r, color.g, color.b, 1)
      local si = e.specID and specInfo[e.specID]
      if si and si.icon then
        r.icon:SetTexture(si.icon)
        r.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
      else
        local okAtlas, set = pcall(r.icon.SetAtlas, r.icon, "classicon-" .. e.class:lower())
        local tc = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[e.class]
        if (not okAtlas or set == false) and tc then
          r.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
          r.icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        end
      end
      r.icon:SetDesaturated(e.dead)

      r.name:SetText(e.display:match("^[^-]+"):upper())
      r.name:SetTextColor(0.96, 0.96, 0.97, e.unit and 1 or 0.6)

      -- Spec tag, tinted by matchup: green = good for you, red = bad.
      local edge = e.edge or 0
      if edge > 0.05 then
        r.spec:SetTextColor(0.45, 0.9, 0.55)
      elseif edge < -0.05 then
        r.spec:SetTextColor(1, 0.45, 0.45)
      else
        r.spec:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
      end
      if e.carrier or e.testStacks then
        local stacks = CarrierStacks(e)
        r.spec:SetTextColor(PIP.carrier[2], PIP.carrier[3], PIP.carrier[4])
        r.spec:SetText(obj.mode == "orb" and string.format("ORB %d%%", stacks or 30)
          or (stacks and string.format("FLAG x%d", stacks) or "FLAG"))
      elseif e.specID then
        local p = ns.Specs[e.specID]
        r.spec:SetText((p and p.short) or SPEC_SHORT[e.specID] or (si and si.name:upper()) or "")
      elseif not (type(e.specLive) == "string" and pcall(r.spec.SetText, r.spec, e.specLive)) then
        -- Live spec is secret mid-match: the game can draw it, we can't read it.
        r.spec:SetText("?")
      end

      UpdateHealth(r, not e.dead and e.unit or nil, color)
      if e.cast and not e.dead and e.cast.finish > e.cast.start then
        r.cast:SetMinMaxValues(e.cast.start, e.cast.finish)
        r.cast:SetValue(e.cast.channel and (e.cast.finish - (now - e.cast.start)) or now)
        if e.cast.kickable then
          r.cast:SetStatusBarColor(1, 0.78, 0.2, 1)
        else
          r.cast:SetStatusBarColor(0.55, 0.56, 0.62, 1)
        end
        r.cast:Show()
      else
        r.cast:Hide()
      end

      -- Yards: white within reach, muted beyond, "--" unseen.
      r.rangeDot:SetAlpha(0)
      if e.yards then
        r.dist:SetText(e.yards)
        if InReach(e) then
          r.dist:SetTextColor(0.96, 0.96, 0.97)
        else
          r.dist:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
        end
      elseif e.rangeRaw ~= nil and issecret(e.rangeRaw) and r.rangeDot.SetAlphaFromBoolean then
        r.dist:SetText("")
        pcall(r.rangeDot.SetAlphaFromBoolean, r.rangeDot, e.rangeRaw, 1, 0)
      elseif e.plateUnit then
        r.dist:SetText("FAR")
        r.dist:SetTextColor(0.4, 0.41, 0.46)
      else
        r.dist:SetText("--")
        r.dist:SetTextColor(0.3, 0.31, 0.35)
      end

      -- Gap to P1 (score), or the row's role in the race.
      if e.dead then
        r.gap:SetText("OUT")
        r.gap:SetTextColor(0.75, 0.3, 0.3)
      elseif isTop then
        r.gap:SetText("KILL")
        r.gap:SetTextColor(ACCENT[1], ACCENT[2], ACCENT[3])
      elseif e == leader then
        r.gap:SetText("P1")
        r.gap:SetTextColor(0.96, 0.96, 0.97)
      else
        r.gap:SetText(string.format("+%d", math.floor(math.max(0, (leader and leader.score or 0) - (e.score or 0)) + 0.5)))
        r.gap:SetTextColor(0.75, 0.76, 0.8)
      end

      local pip = StatusPip(e)
      if pip then
        r.pip:SetVertexColor(pip[2], pip[3], pip[4])
        r.pipText:SetText(pip == PIP.carrier and obj.mode == "orb" and "O" or pip[1])
        r.pip:Show()
        r.pipText:Show()
      else
        r.pip:Hide()
        r.pipText:Hide()
      end

      if e.marker then
        r.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. e.marker)
        r.marker:Show()
      else
        r.marker:Hide()
      end
      local allies = e.allyCount or 0
      r.allyText:SetText(allies > 0 and ("x" .. allies) or "")
      r.allyText:SetTextColor(1, allies >= 3 and 0.55 or 0.85, allies >= 3 and 0.2 or 0.85)
      if e.onMe then
        r.eye:SetAlpha(1)
      elseif e.onMeRaw ~= nil and issecret(e.onMeRaw) and r.eye.SetAlphaFromBoolean then
        pcall(r.eye.SetAlphaFromBoolean, r.eye, e.onMeRaw, 1, 0)
      else
        r.eye:SetAlpha(0)
      end

      -- GO = best LIVE target right now (within a small margin) whose
      -- defensive just faded, and who is within your reach.
      local go = e.live >= topLive - SWAP_MARGIN and not e.dead and not e.def and not e.cc
        and e.burnedAt ~= nil and now - e.burnedAt < KILL_WINDOW
        and InReach(e)
      if go then
        goEntry = e
      end
      if go ~= r.go then
        r.go = go
        r.goGlow:SetShown(go)
        if go then
          r.goFillAnim:Play()
          r.goGlowAnim:Play()
          r.goPop:Play()
        else
          r.goFillAnim:Stop()
          r.goGlowAnim:Stop()
          r.goFill:SetAlpha(0)
        end
      end
      -- One sound per kill window (per defensive spent).
      if go and e.goAlertedFor ~= e.burnedAt then
        e.goAlertedFor = e.burnedAt
        if db.sound then
          PlayGoSound()
        end
      end

      local isTarget = targetKey ~= nil and e.key == targetKey
      if isTarget ~= r.isTarget then
        r.isTarget = isTarget
        r.sel:SetShown(isTarget)
        r.arrow:SetShown(isTarget)
      end

      -- Dead, defensive up or CC'd: don't commit -> dim the row.
      r.content:SetAlpha((e.dead and 0.4) or ((e.def or e.cc) and 0.7) or 1)
    elseif r.entry then
      needsLayout = true
      r.content:SetAlpha(0.2)
    end
    if not e and r.go then
      r.go = false
      r.goGlow:Hide()
      r.goFillAnim:Stop()
      r.goGlowAnim:Stop()
      r.goFill:SetAlpha(0)
    end
    if not e and r.isTarget then
      r.isTarget = false
      r.sel:Hide()
      r.arrow:Hide()
    end
  end
  if #order ~= 0 and not rows[1].entry then
    needsLayout = true
  end
  if needsLayout and not inCombat then
    Layout()
    return Render()
  end
  lockIcon:SetShown(inCombat and needsLayout)
  callEntry = goEntry or firstAlive
  if db.killorder == false then
    UpdateSniper(nil)
  elseif not sniperTest.on then
    UpdateSniper(goEntry or firstAlive, goEntry ~= nil)
  end
  UpdateHero(goEntry or firstAlive, goEntry ~= nil)

  -- Header: live dot while there's a roster; map tag + count on the right.
  local hasRoster = #order > 0
  liveDot:SetShown(hasRoster)
  liveText:SetShown(hasRoster)
  liveText:SetText(testMode and "TEST" or "LIVE")
  if hasRoster and not liveDotAnim:IsPlaying() then
    liveDotAnim:Play()
  elseif not hasRoster then
    liveDotAnim:Stop()
  end
  local tag = currentProfile and (currentProfile.label:upper() .. (isBlitz and "  \194\183  BLITZ" or "") .. "  \194\183  ")
    or ""
  subtitle:SetText(hasRoster and (tag .. #order) or (rosterStatus or "waiting..."))
end

---------------------------------------------------------------------------
-- Secure "target #1" button (bind under Key Bindings > AddOns > Warboard).
-- Attributes can only change out of combat, so it is refreshed then.
---------------------------------------------------------------------------
local targetBtn = CreateFrame("Button", "WarboardTargetButton", UIParent, "SecureActionButtonTemplate")
targetBtn:RegisterForClicks("AnyDown", "AnyUp")
targetBtn:SetAttribute("type", "macro")
-- /click from a macro sends an UP click; with ActionButtonUseKeyDown on, a
-- secure button would only act on DOWN and ignore it. Act on up instead:
-- works for /click, key bindings (down+up -> fires once on up) and mouse.
targetBtn:SetAttribute("useOnKeyDown", false)

-- Mark button: /click WarboardMarkButton (macro or keybind). Targets the
-- kill target, puts your marker on it via /tm (secure slash command), then
-- returns to your previous target. Like all secure buttons it can only be
-- re-pointed out of combat. /tm toggles, so it's skipped when the enemy
-- already wears that marker.
local markBtn = CreateFrame("Button", "WarboardMarkButton", UIParent, "SecureActionButtonTemplate")
markBtn:RegisterForClicks("AnyDown", "AnyUp")
markBtn:SetAttribute("type", "macro")
markBtn:SetAttribute("useOnKeyDown", false) -- see targetBtn
local markBound -- "key:icon:alreadyMarked" currently baked into the macro

-- Focus button: /click WarboardFocusButton or its keybind. Focuses the kill
-- target and returns to your previous target (/focus takes no name).
local focusBtn = CreateFrame("Button", "WarboardFocusButton", UIParent, "SecureActionButtonTemplate")
focusBtn:RegisterForClicks("AnyDown", "AnyUp")
focusBtn:SetAttribute("type", "macro")
focusBtn:SetAttribute("useOnKeyDown", false) -- see targetBtn

-- Pre-rename names, so existing macros (/click KillOrderTargetButton...)
-- keep working: /click looks buttons up by global name.
WrapRestore(focusBtn)
WrapRestore(markBtn)
_G.KillOrderTargetButton = targetBtn
_G.KillOrderMarkButton = markBtn
_G.KillOrderFocusButton = focusBtn

local function UpdateTargetButton()
  if InCombatLockdown() then
    return
  end
  -- Pick fresh: Render (which also picks) runs after this in the tick, so
  -- reading killNow here would lag a tick or fall back to the list order.
  local top = PickKillNow()
  if not top then
    for _, e in ipairs(order) do
      if not e.dead then
        top = e
        break
      end
    end
  end
  -- Hero card: only the live kill target (nothing when nobody is in reach).
  local heroKey = killNow and killNow.key
  if heroKey ~= heroBtn.boundKey then
    heroBtn.boundKey = heroKey
    local name = heroKey and DisplayName(heroKey)
    heroBtn:SetAttribute("macrotext1", name and ("/targetexact " .. name) or "")
    SetReturnMacro(heroBtn, "macrotext2", name and ("/targetexact " .. name .. "\n/focus"))
  end
  local key = top and top.key
  if key ~= boundKey then
    boundKey = key
    targetBtn:SetAttribute("macrotext", key and ("/targetexact " .. DisplayName(key)) or "")
    SetReturnMacro(focusBtn, "macrotext", key and ("/targetexact " .. DisplayName(key) .. "\n/focus"))
  end

  local icon = db.markIcon or 8
  local ping = db.markMode ~= "icon"
  local already = not ping and top and top.marker == icon
  local sig = tostring(key) .. ":" .. (ping and ("ping-" .. db.pingType) or icon) .. ":" .. tostring(already)
  if sig ~= markBound then
    markBound = sig
    local text = ""
    if key and not already then
      local action = ping and ("/ping [@target] " .. (db.pingType or "attack")) or ("/tm " .. icon)
      text = "/targetexact " .. DisplayName(key) .. "\n" .. action
    end
    SetReturnMacro(markBtn, "macrotext", text ~= "" and text or nil)
  end
end

---------------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------------
-- Hysteresis: start from the previous order and only swap neighbours when
-- the lower one leads by more than SWAP_MARGIN. Close calls stay put; big
-- events (carrier, defensive spent, kill window) still bubble through.

local function Recompute()
  UpdateGearRef()
  if not db.liveSort then
    wipe(order)
    for _, e in pairs(enemies) do
      Score(e)
      order[#order + 1] = e
    end
    table.sort(order, function(a, b)
      if a.base ~= b.base then
        return a.base > b.base
      end
      return a.key < b.key
    end)
    return
  end
  local prev = {}
  for i, e in ipairs(order) do
    prev[e] = i
  end
  local newcomers = {}
  wipe(order)
  for _, e in pairs(enemies) do
    Score(e)
    if prev[e] then
      order[#order + 1] = e
    else
      newcomers[#newcomers + 1] = e
    end
  end
  table.sort(order, function(a, b)
    return prev[a] < prev[b]
  end)
  table.sort(newcomers, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.key < b.key
  end)
  -- Newcomers are placed by score (no hysteresis for them).
  for _, e in ipairs(newcomers) do
    local pos = #order + 1
    for i, o in ipairs(order) do
      if e.score > o.score then
        pos = i
        break
      end
    end
    table.insert(order, pos, e)
  end
  local swapped = true
  while swapped do
    swapped = false
    for i = 1, #order - 1 do
      local a, b = order[i], order[i + 1]
      local margin = (a.dead or b.dead) and 0 or SWAP_MARGIN
      if b.score > a.score + margin then
        order[i], order[i + 1] = b, a
        swapped = true
      end
    end
  end
end

-- Each stage runs protected: one failing stage must not freeze the panel.
-- Errors are kept in WarboardDB.errors (read after /reload) and in /wb err.
local function Guard(stage, fn)
  local ok, err = xpcall(fn, function(e)
    return tostring(e) .. "\n" .. (debugstack and debugstack(2, 6, 0) or "")
  end)
  if not ok then
    db.errors = db.errors or {}
    local key = stage .. ": " .. tostring(err):match("^[^\n]*")
    local rec = db.errors[key]
    if rec then
      rec.count = rec.count + 1
    else
      db.errors[key] = { count = 1, first = date("%H:%M:%S"), trace = err }
      lastError = key
    end
  end
  return ok
end

local lastRosterPoll = 0

local function Tick()
  if not active then
    return
  end
  if not testMode then
    if DetectMap() then
      ObjectiveStart()
    end
    -- Poll the scoreboard too: UPDATE_BATTLEFIELD_SCORE doesn't always fire
    -- (e.g. in the starting area before gates open).
    local now = GetTime()
    if now - lastRosterPoll >= 2 then
      lastRosterPoll = now
      Guard("roster", RefreshRoster)
    end
    Guard("carriers", ScanCarrierTokens)
    Guard("scan", ScanUnits)
    Guard("allies", ScanAllyTargets)
  end
  Guard("plates", ScanPlates)
  Guard("score", Recompute)
  Guard("targetbtn", UpdateTargetButton)
  Guard("render", Render)
  if lastError then
    subtitle:SetText("|cffff4040error|r /wb err")
  end
end

local ticker, scoreTicker
local function SetActive(on)
  if on == active then
    return
  end
  active = on
  if on then
    UpdateMe()
    if not testMode then
      ObjectiveStart()
    end
    if InCombatLockdown() then
      layoutPending = true
    else
      frame:SetShown(db.killorder ~= false) -- Kill Order feature switch
    end
    ticker = C_Timer.NewTicker(0.25, Tick)
    if not testMode then
      scoreTicker = C_Timer.NewTicker(5, RequestScores)
      RequestScores()
    end
    Tick()
  else
    if ticker then ticker:Cancel() end
    if scoreTicker then scoreTicker:Cancel() end
    ticker, scoreTicker = nil, nil
    sniper:Hide()
    sniper.soundKey = nil
    if InCombatLockdown() then
      layoutPending = true
    else
      frame:Hide()
    end
  end
end

local function InRatedBG()
  local _, instanceType = IsInInstance()
  if instanceType ~= "pvp" then
    return false
  end
  if db.allBGs then
    return true
  end
  if not C_PvP then return false end
  return (C_PvP.IsRatedBattleground and C_PvP.IsRatedBattleground())
    or (C_PvP.IsRatedMap and C_PvP.IsRatedMap())
    or (C_PvP.IsSoloRBG and C_PvP.IsSoloRBG())
    or false
end

local function CheckZone()
  if testMode then
    return
  end
  local on = InRatedBG()
  if not on then
    wipe(enemies)
    allyFaction = nil
    currentBG, currentProfile, mapKey = nil, nil, nil
    obj.mode, obj.assaultStart = nil, nil
    ns.flagRespawnAt = nil
  end
  SetActive(on)
end

local function StartTest()
  testMode = true
  wipe(enemies)
  -- Borrow names from visible nameplates (NPCs are fine) so row clicks
  -- actually target something; pad with fake names.
  local nearby, seenName = {}, {}
  for i = 1, 40 do
    local ok, name = pcall(UnitName, "nameplate" .. i)
    if ok and plain(name) and type(name) == "string" and name ~= "" and not seenName[name] then
      seenName[name] = true
      nearby[#nearby + 1] = name
    end
  end
  local pool = { 1468, 270, 257, 105, 65, 254, 261, 102, 252, 70, 71, 258, 63, 577, 73 }
  if not IS_RETAIL then
    -- Classic spec IDs differ: take one spec per class from the client.
    pool = {}
    local classes = { "PRIEST", "SHAMAN", "PALADIN", "DRUID", "MAGE", "HUNTER", "ROGUE", "WARLOCK", "DEATHKNIGHT", "WARRIOR" }
    for n, cls in ipairs(classes) do
      local ids = classSpecs[cls]
      if ids and #ids > 0 then
        pool[#pool + 1] = ids[(n % #ids) + 1]
      end
    end
  end
  for n = 1, 10 do
    local id = pool[n]
    local si = specInfo[id]
    if si then
      local key = nearby[n] and Canon(nearby[n]) or ("Enemy" .. n .. "-Test")
      enemies[key] = {
        key = key, display = key, class = si.class,
        specID = (n ~= 7) and id or nil, specSrc = (n % 3 == 0) and "hist" or "live",
        def = (n == 2), cc = (n == 5), dead = (n == 9), burst = (n == 6),
        burnedAt = (n == 4) and GetTime() - 10 or nil,
        range = (n == 1 or n == 3) and "attack" or (n == 4) and "reach" or nil,
        yards = (n == 1 or n == 3) and 5 or (n == 4) and 30 or nil,
        testStacks = (n == 7) and 4 or nil,
        allyCount = (n == 1) and 4 or (n == 3) and 1 or 0,
        onMe = (n == 2 or n == 6),
        marker = (n == 1) and 8 or (n == 5) and 7 or nil,
        -- Preview a live health bar using your own health.
        unit = (n == 1 or n == 3 or n == 4) and "player" or nil,
      }
    end
  end
  SetActive(false)
  SetActive(true)
end

---------------------------------------------------------------------------
-- Options page: Options > AddOns > Warboard (also /wb config or the gear
-- in the panel header). Every point value + the per-component multipliers.
---------------------------------------------------------------------------
local optionsCategory
local optionsPanel = CreateFrame("Frame", "WarboardOptions")
optionsPanel.name = "Warboard"
optionsPanel:Hide()

local function Fmt(v)
  if math.floor(v) == v then
    return tostring(v)
  end
  return (string.format("%.2f", v):gsub("0+$", ""))
end

local function PointsChanged()
  if active then
    Tick()
  end
end

-- Main page (profiles, reset) + one sub-page per group, listed under
-- Warboard in the options sidebar. Rows of every page share Get/Set/Refresh.
local optionsPages = {}; -- { name, frame } registered as sub-categories
(function()
  local p = optionsPanel
  local head = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  head:SetPoint("TOPLEFT", 16, -16)
  head:SetText("Warboard")
  local hint = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
  hint:SetText("Profiles here; point values on the pages under Warboard in the list on the left.")
  hint:SetTextColor(0.7, 0.7, 0.75)

  local resetAll = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  resetAll:SetSize(110, 22)
  resetAll:SetPoint("TOPRIGHT", -16, -14)
  resetAll:SetText("Reset all")

  local pageList = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  pageList:SetPoint("TOPLEFT", 16, -120)
  pageList:SetPoint("RIGHT", -16, 0)
  pageList:SetJustifyH("LEFT")
  pageList:SetSpacing(4)

  -- Feature switches.
  local fh = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fh:SetPoint("TOPLEFT", 16, -160)
  fh:SetText("Features")
  local FEATURES = {
    { key = "killorder", label = "Kill Order", desc = "priority panel, kill target card, sniper scope" },
    { key = "sniper", label = "Sniper scope", desc = "crosshair over the kill target's nameplate" },
    { key = "pressure", label = "Enemy focus markers", desc = "shield badges on the teammates drawing enemy attention", cata = true },
    { key = "intel", label = "Intel map", desc = "shared enemy positions on the map" },
    { key = "intelShare", label = "Share intel with teammates", desc = "send your sightings / res timers to Warboard users" },
    { key = "timers", label = "Timers", desc = "res waves and base captures (own window + map)" },
    { key = "objectives", label = "Bases window", desc = "captures in progress + who wins, when, and what it takes" },
    { key = "flags", label = "Flags window", desc = "flag carriers, click to target / focus (hides Blizzard's carrier frames in BGs)" },
    { key = "hideTracker", label = "Hide quest tracker in BGs", desc = "the objectives sidebar, back when you leave" },
    { key = "cooldowns", label = "Cooldown tracking", desc = "enemy trinkets / immunities / defensives (combat log)", cata = true },
    { key = "dieAlert", label = "Good time to die alert", desc = "low health + your res wave a few seconds away" },
  }
  local fy = -180
  p.featureBoxes = {}
  for _, f in ipairs(FEATURES) do
    if not (f.cata and IS_RETAIL) then
      local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
      cb:SetSize(24, 24)
      cb:SetPoint("TOPLEFT", 16, fy)
      local label = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
      label:SetText(f.label .. "  |cff888888" .. f.desc .. "|r")
      cb:SetScript("OnClick", function(self)
        db[f.key] = self:GetChecked() and true or false
        if f.key == "killorder" then
          if InCombatLockdown() then
            layoutPending = true -- secure panel: applied when combat ends
          else
            frame:SetShown(active and db.killorder ~= false)
          end
        end
        PointsChanged()
      end)
      cb.key = f.key
      p.featureBoxes[#p.featureBoxes + 1] = cb
      fy = fy - 26
    end
  end

  local rows = {} -- every value row on every page
  local function Get(row)
    if row.kind == "kitspell" then
      row.def = P(row.kindKey) -- follows the type's value unless overridden
      local v = db.points and db.points[row.key]
      return v ~= nil and v or row.def
    end
    if row.kind == "spec" then
      return Profile(row.specID)[row.stat]
    end
    if row.kind == "weight" then
      return (db.weights and db.weights[row.key]) or 1
    end
    return P(row.key)
  end
  local function Set(row, v)
    v = math.floor(v * 100 + 0.5) / 100
    if row.kind == "spec" then
      v = math.max(0, math.min(15, v))
      db.specRatings = db.specRatings or {}
      local ov = db.specRatings[row.specID] or {}
      ov[row.stat] = (v ~= row.def) and v or nil
      db.specRatings[row.specID] = next(ov) and ov or nil
      wipe(profileCache)
      PointsChanged()
      return
    end
    if row.kind == "kitspell" then
      db.points = db.points or {}
      db.points[row.key] = (v ~= P(row.kindKey)) and v or nil
      PointsChanged()
      return
    end
    if row.kind == "weight" then
      db.weights = db.weights or {}
      db.weights[row.key] = (v ~= 1) and v or nil
    else
      db.points = db.points or {}
      db.points[row.key] = (v ~= row.def) and v or nil
    end
    PointsChanged()
  end
  local function Refresh(row)
    local v = Get(row)
    row.box:SetText(Fmt(v))
    row.box:SetCursorPosition(0)
    local changed = v ~= row.def
    row.reset:SetShown(changed)
    row.label:SetTextColor(changed and 1 or 0.85, changed and 0.82 or 0.85, changed and 0.3 or 0.85)
  end
  local function RefreshAllRows()
    for _, row in ipairs(rows) do
      Refresh(row)
    end
  end
  -- -/box/+ behaviour shared by both row styles.
  local function Wire(row, minus, plus, step)
    minus:SetScript("OnClick", function()
      Set(row, Get(row) - step * (IsShiftKeyDown() and 5 or 1))
      Refresh(row)
    end)
    plus:SetScript("OnClick", function()
      Set(row, Get(row) + step * (IsShiftKeyDown() and 5 or 1))
      Refresh(row)
    end)
    row.reset:SetScript("OnClick", function()
      Set(row, row.def)
      Refresh(row)
    end)
    row.box:SetScript("OnEnterPressed", function(self)
      local v = tonumber(self:GetText())
      if v then
        Set(row, v)
      end
      Refresh(row)
      self:ClearFocus()
    end)
    row.box:SetScript("OnEscapePressed", function(self)
      Refresh(row)
      self:ClearFocus()
    end)
    row.box:SetScript("OnEditFocusLost", function()
      Refresh(row)
    end)
    rows[#rows + 1] = row
  end

  -- A sub-page: title, hint, its own scroll area.
  local function MakePage(name, text)
    local page = { name = name, y = -4 }
    local f = CreateFrame("Frame", nil)
    f:Hide()
    page.frame = f
    local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("Warboard: " .. name)
    local h = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    h:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
    h:SetPoint("RIGHT", -16, 0)
    h:SetJustifyH("LEFT")
    h:SetText(text .. "  Applies instantly; shift-click -/+ for bigger steps.")
    h:SetTextColor(0.7, 0.7, 0.75)
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -56)
    scroll:SetPoint("BOTTOMRIGHT", -30, 10)
    page.child = CreateFrame("Frame", nil, scroll)
    page.child:SetSize(560, 10)
    scroll:SetScrollChild(page.child)
    f:SetScript("OnSizeChanged", function(_, w)
      page.child:SetWidth(math.max(400, (w or 600) - 50))
    end)
    f:SetScript("OnShow", function()
      if page.build then
        page.build()
        page.build = nil
      end
      RefreshAllRows()
    end)
    optionsPages[#optionsPages + 1] = page
    return page
  end

  local function Row(page, row)
    local f = CreateFrame("Frame", nil, page.child)
    f:SetPoint("TOPLEFT", 8, page.y)
    f:SetPoint("RIGHT", page.child, "RIGHT", -8, 0)
    f:SetHeight(24)
    page.y = page.y - 26
    page.child:SetHeight(-page.y + 10)
    row.label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.label:SetPoint("LEFT", 8, 0)
    row.label:SetText(row.desc)
    local plus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    plus:SetSize(24, 20)
    plus:SetPoint("RIGHT", -110, 0)
    plus:SetText("+")
    row.box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    row.box:SetSize(52, 20)
    row.box:SetPoint("RIGHT", plus, "LEFT", -6, 0)
    row.box:SetAutoFocus(false)
    row.box:SetJustifyH("CENTER")
    local minus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    minus:SetSize(24, 20)
    minus:SetPoint("RIGHT", row.box, "LEFT", -8, 0)
    minus:SetText("-")
    local dflt = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    dflt:SetPoint("LEFT", plus, "RIGHT", 8, 0)
    dflt:SetText("default " .. Fmt(row.def))
    row.reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    row.reset:SetSize(20, 20)
    row.reset:SetPoint("RIGHT", 0, 0)
    row.reset:SetText("x")
    row.label:SetPoint("RIGHT", minus, "LEFT", -8, 0)
    row.label:SetJustifyH("LEFT")
    Wire(row, minus, plus, row.step or 1)
  end

  -- Point pages: one per POINTS group.
  local PAGE_HINTS = {
    "Base ranking: how easy a spec is to kill, how much the kill matters, your matchup.",
    "Flag / orb carriers and the team's raid markers.",
    "What picks the kill target right now: distance, defensives, CC, health, casts.",
    "Enemy cooldowns the combat log saw them use.",
    "Res-wave alerts.",
  }
  local PAGE_NAMES = { "Who they are", "Objectives", "Live signals", "Cooldowns", "Timers" }
  local page, n = nil, 0
  for _, def in ipairs(POINTS) do
    if def.group then
      n = n + 1
      page = not (def.cata and IS_RETAIL) and MakePage(PAGE_NAMES[n] or def.group, PAGE_HINTS[n] or def.group) or nil
    elseif page and not (def.cata and IS_RETAIL) then
      Row(page, { kind = "point", key = def.key, def = def.def, step = def.step, desc = def.desc })
    end
  end

  local mult = MakePage("Multipliers", "x per score component, on top of the points (also tilted per map type).")
  for _, w in ipairs(WEIGHTS) do
    Row(mult, { kind = "weight", key = w.key, def = 1, step = 0.1, desc = w.key .. ": " .. w.desc })
  end

  -- Spec ratings: squishy + value side by side; built on first view (spec
  -- names are only known after login).
  local function SpecStepper(f, anchor, row)
    row.label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", anchor, "RIGHT", 14, 0)
    row.label:SetText(row.stat == "k" and "squishy" or "value")
    local minus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    minus:SetSize(20, 18)
    minus:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
    minus:SetText("-")
    row.box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    row.box:SetSize(30, 18)
    row.box:SetPoint("LEFT", minus, "RIGHT", 8, 0)
    row.box:SetAutoFocus(false)
    row.box:SetJustifyH("CENTER")
    local plus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    plus:SetSize(20, 18)
    plus:SetPoint("LEFT", row.box, "RIGHT", 4, 0)
    plus:SetText("+")
    row.reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    row.reset:SetSize(18, 18)
    row.reset:SetPoint("LEFT", plus, "RIGHT", 2, 0)
    row.reset:SetText("x")
    Wire(row, minus, plus, 1)
    return row.reset
  end
  local specs = MakePage("Spec ratings", "1-10. squishy = how easy to kill, value = how much the kill matters.")
  specs.build = function()
    local classes = {}
    for class in pairs(classSpecs) do
      classes[#classes + 1] = class
    end
    table.sort(classes, function(a, b)
      return (LOCALIZED_CLASS_NAMES_MALE[a] or a) < (LOCALIZED_CLASS_NAMES_MALE[b] or b)
    end)
    for _, class in ipairs(classes) do
      local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
      for _, specID in ipairs(classSpecs[class]) do
        local si = specInfo[specID]
        local base = BaseProfile(specID)
        local f = CreateFrame("Frame", nil, specs.child)
        f:SetPoint("TOPLEFT", 8, specs.y)
        f:SetPoint("RIGHT", specs.child, "RIGHT", -8, 0)
        f:SetHeight(22)
        specs.y = specs.y - 24
        local name = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        name:SetPoint("LEFT", 8, 0)
        name:SetWidth(190)
        name:SetJustifyH("LEFT")
        name:SetText((si and si.name or specID) .. " " .. (LOCALIZED_CLASS_NAMES_MALE[class] or class))
        if c then
          name:SetTextColor(c.r, c.g, c.b)
        end
        local last = SpecStepper(f, name, { kind = "spec", specID = specID, stat = "k", def = base.k })
        SpecStepper(f, last, { kind = "spec", specID = specID, stat = "i", def = base.i })
      end
    end
    specs.child:SetHeight(-specs.y + 10)
  end

  -- Defensives: every class's defensive kit (Cata kits), grouped by class,
  -- with type, cooldown, specs and an editable point value per spell.
  if ns.Kits then
    local KIND_LABEL = { trinket = "trinket", immune = "immunity", def = "defensive", external = "external" }
    local KIND_KEY = { trinket = "trinketDown", immune = "immuneDown", def = "defDown" }
    local defs = MakePage("Defensives", "Points while each spell is down (seen used). Blank = uses its type's value from Cooldowns; external = cast on a teammate, shown only.")
    defs.build = function()
      local function Line(text, r, g, b)
        local fs = defs.child:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fs:SetPoint("TOPLEFT", 8, defs.y - 6)
        fs:SetText(text)
        if r then
          fs:SetTextColor(r, g, b)
        end
        defs.y = defs.y - 26
      end
      local function SpellRow(class, entry)
        local spec = entry.spec and classSpecs[class] and classSpecs[class][entry.spec]
        local specName = spec and specInfo[spec] and specInfo[spec].name or "all specs"
        local desc = string.format("%s  |cff888888%s, %s cd, %s|r", entry[4], KIND_LABEL[entry[3]], Clock(entry[2]), specName)
        if KIND_KEY[entry[3]] then
          Row(defs, { kind = "kitspell", key = "kit" .. entry[1], kindKey = KIND_KEY[entry[3]], def = P(KIND_KEY[entry[3]]), desc = desc })
        else
          local fs = defs.child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
          fs:SetPoint("TOPLEFT", 16, defs.y - 4)
          fs:SetText(desc .. "  |cff888888(shown only)|r")
          defs.y = defs.y - 26
        end
      end
      Line("Everyone")
      for _, entry in ipairs(ns.KitCommon or {}) do
        SpellRow(nil, entry)
      end
      local classes = {}
      for class in pairs(ns.Kits) do
        classes[#classes + 1] = class
      end
      table.sort(classes, function(a, b)
        return (LOCALIZED_CLASS_NAMES_MALE[a] or a) < (LOCALIZED_CLASS_NAMES_MALE[b] or b)
      end)
      for _, class in ipairs(classes) do
        local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
        Line(LOCALIZED_CLASS_NAMES_MALE[class] or class, c and c.r, c and c.g, c and c.b)
        -- All-spec spells first, then per spec in tree order.
        local list = {}
        for _, entry in ipairs(ns.Kits[class]) do
          if KIND_LABEL[entry[3]] then
            list[#list + 1] = entry
          end
        end
        table.sort(list, function(a, b)
          return (a.spec or 0) < (b.spec or 0)
        end)
        for _, entry in ipairs(list) do
          SpellRow(class, entry)
        end
      end
      defs.child:SetHeight(-defs.y + 10)
    end
  end

  local ORDER = { ["Who they are"] = 1, ["Objectives"] = 2, ["Live signals"] = 3, ["Cooldowns"] = 4,
    ["Timers"] = 4.5, ["Defensives"] = 5, ["Spec ratings"] = 6, ["Multipliers"] = 7 }
  table.sort(optionsPages, function(a, b)
    return (ORDER[a.name] or 99) < (ORDER[b.name] or 99)
  end)
  local names = {}
  for _, pg in ipairs(optionsPages) do
    names[#names + 1] = "|cffffd100" .. pg.name .. "|r"
  end
  pageList:SetText("Pages: " .. table.concat(names, "   "))

  resetAll:SetScript("OnClick", function()
    db.specRatings = {}
    wipe(profileCache)
    db.points, db.weights = {}, {}
    RefreshAllRows()
    PointsChanged()
  end)
  p:SetScript("OnShow", function()
    for _, cb in ipairs(p.featureBoxes) do
      cb:SetChecked(db[cb.key] ~= false)
    end
    if p.RefreshProfiles then
      p.RefreshProfiles()
    end
  end)
  p.RefreshAll = function()
    RefreshAllRows()
    if p.RefreshProfiles then
      p.RefreshProfiles()
    end
  end
end)()

---------------------------------------------------------------------------
-- Profiles: export/import strings + named profiles saved in-game.
--
-- Export format (plain text, safe to share; parsed as key=value, never run):
--   WB1;f=cata;p.killPer=7;w.range=1.2;s.MAGE.1.k=8;o.executePct=0.35
--   p. = point value   w. = multiplier   s.CLASS.tree.k|i = spec rating
--   o. = other setting   f = client flavor (spec ratings only import into
--   the same flavor: retail and Cata specs differ)
-- Only values that differ from the defaults are written.
---------------------------------------------------------------------------
-- Wrapped in a function: the main chunk is near Lua's 200-local limit.
local Profiles = {}; -- what the slash command needs
(function()
  local FLAVOR = IS_RETAIL and "retail" or "cata"
  local PROFILE_OPTIONS = { executePct = 0.35 }

  -- Current settings as a plain table (what a profile stores).
  local function Snapshot()
    local snap = { points = {}, weights = {}, specs = {}, options = {}, flavor = FLAVOR }
    for k, v in pairs(db.points or {}) do
      snap.points[k] = v
    end
    for k, v in pairs(db.weights or {}) do
      snap.weights[k] = v
    end
    for specID, ov in pairs(db.specRatings or {}) do
      local si = specInfo[specID]
      local idx = specIndex[specID]
      if si and idx then
        for stat, v in pairs(ov) do
          snap.specs[si.class .. "." .. idx .. "." .. stat] = v
        end
      end
    end
    for k, def in pairs(PROFILE_OPTIONS) do
      if db[k] ~= nil and db[k] ~= def then
        snap.options[k] = db[k]
      end
    end
    return snap
  end

  -- Replace current settings with a snapshot. Returns skipped-spec count.
  local function ApplySnapshot(snap)
    db.points, db.weights, db.specRatings = {}, {}, {}
    for k, v in pairs(snap.points or {}) do
      if POINT_DEFAULT[k] ~= nil or k:match("^kit%d+$") then
        db.points[k] = v
      end
    end
    for k, v in pairs(snap.weights or {}) do
      db.weights[k] = v
    end
    local skipped = 0
    for key, v in pairs(snap.specs or {}) do
      local class, idx, stat = key:match("^(%u+)%.(%d+)%.([ki])$")
      local specID = class and snap.flavor == FLAVOR and classSpecs[class] and classSpecs[class][tonumber(idx)]
      if specID then
        db.specRatings[specID] = db.specRatings[specID] or {}
        db.specRatings[specID][stat] = v
      else
        skipped = skipped + 1
      end
    end
    for k, def in pairs(PROFILE_OPTIONS) do
      db[k] = (snap.options and snap.options[k]) or def
    end
    wipe(profileCache)
    BuildCurve()
    PointsChanged()
    optionsPanel.RefreshAll()
    return skipped
  end

  local function SortedPairs(t)
    local keys = {}
    for k in pairs(t) do
      keys[#keys + 1] = k
    end
    table.sort(keys)
    local i = 0
    return function()
      i = i + 1
      return keys[i], t[keys[i]]
    end
  end

  local function ExportString(snap)
    local parts = { "WB1", "f=" .. snap.flavor }
    for prefix, t in SortedPairs({ p = snap.points, w = snap.weights, s = snap.specs, o = snap.options }) do
      for k, v in SortedPairs(t) do
        parts[#parts + 1] = prefix .. "." .. k .. "=" .. Fmt(v)
      end
    end
    return table.concat(parts, ";")
  end

  -- Returns snapshot, or nil + error text. Unknown keys are ignored.
  local function ParseString(text)
    text = (text or ""):gsub("%s+", "")
    -- WB1 = Warboard; KO1 = strings exported before the rename (same format).
    if not (text:match("^WB1;") or text:match("^KO1;") or text == "WB1" or text == "KO1") then
      return nil, "not a Warboard profile (should start with WB1;)"
    end
    local snap = { points = {}, weights = {}, specs = {}, options = {}, flavor = FLAVOR }
    local n = 0
    for token in text:gmatch("[^;]+") do
      local k, v = token:match("^([%w%.]+)=([%w%.%-]+)$")
      if k == "f" then
        snap.flavor = v
      elseif k then
        local prefix, key = k:match("^(%a)%.(.+)$")
        local num = tonumber(v)
        local into = ({ p = snap.points, w = snap.weights, s = snap.specs, o = snap.options })[prefix or ""]
        if into and num then
          into[key] = num
          n = n + 1
        end
      end
    end
    return snap, nil, n
  end

  -- Copy/paste window (one for export and import).
  local share = CreateFrame("Frame", "WarboardShare", UIParent, "BackdropTemplate")
  share:SetSize(460, 240)
  share:SetPoint("CENTER")
  share:SetFrameStrata("DIALOG")
  share:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  share:SetBackdropColor(INK[1], INK[2], INK[3], 0.97)
  share:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
  share:EnableMouse(true)
  share:SetMovable(true)
  share:RegisterForDrag("LeftButton")
  share:SetScript("OnDragStart", share.StartMoving)
  share:SetScript("OnDragStop", share.StopMovingOrSizing)
  share:Hide()
  tinsert(UISpecialFrames, "WarboardShare") -- Escape closes it
  do
    share.title = Text(share, "bold", 14)
    share.title:SetPoint("TOPLEFT", 12, -10)
    share.hint = Text(share, "medium", 11)
    share.hint:SetPoint("TOPLEFT", share.title, "BOTTOMLEFT", 0, -3)
    share.hint:SetPoint("RIGHT", -12, 0)
    share.hint:SetJustifyH("LEFT")
    share.hint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    local sc = CreateFrame("ScrollFrame", "WarboardShareScroll", share, "UIPanelScrollFrameTemplate")
    sc:SetPoint("TOPLEFT", 12, -48)
    sc:SetPoint("BOTTOMRIGHT", -32, 40)
    local bg = Fill(share, "BACKGROUND", 1, 1, 1, 0.05)
    bg:SetPoint("TOPLEFT", sc, -4, 4)
    bg:SetPoint("BOTTOMRIGHT", sc, 24, -4)
    share.box = CreateFrame("EditBox", nil, sc)
    share.box:SetMultiLine(true)
    share.box:SetAutoFocus(false)
    share.box:SetFontObject(ChatFontNormal)
    share.box:SetWidth(400)
    share.box:SetScript("OnEscapePressed", function()
      share:Hide()
    end)
    sc:SetScrollChild(share.box)
    share.apply = CreateFrame("Button", nil, share, "UIPanelButtonTemplate")
    share.apply:SetSize(110, 22)
    share.apply:SetPoint("BOTTOMRIGHT", -12, 10)
    local close = CreateFrame("Button", nil, share, "UIPanelButtonTemplate")
    close:SetSize(80, 22)
    close:SetPoint("RIGHT", share.apply, "LEFT", -6, 0)
    close:SetText("Close")
    close:SetScript("OnClick", function()
      share:Hide()
    end)
    share.status = Text(share, "medium", 11)
    share.status:SetPoint("BOTTOMLEFT", 12, 14)
    share.status:SetPoint("RIGHT", close, "LEFT", -8, 0)
    share.status:SetJustifyH("LEFT")
  end

  local function Say(msg)
    print("|cffff5533Warboard|r " .. msg)
  end

  local function ImportText(text)
    local snap, err, n = ParseString(text)
    if not snap then
      return false, err
    end
    local skipped = ApplySnapshot(snap)
    local msg = string.format("imported %d values", n - skipped)
    if skipped > 0 then
      msg = msg .. string.format(" (%d spec ratings skipped: made on %s, this is %s)", skipped, snap.flavor, FLAVOR)
    end
    return true, msg
  end

  local function ShowExport()
    share.title:SetText("EXPORT PROFILE")
    share.hint:SetText("Ctrl+C to copy. Only values you changed are included.")
    local text = ExportString(Snapshot())
    share.box:SetText(text)
    share.apply:Hide()
    share.status:SetText("")
    share:Show()
    share.box:SetFocus()
    share.box:HighlightText()
  end

  local function ShowImport()
    share.title:SetText("IMPORT PROFILE")
    share.hint:SetText("Paste a WB1;... string (Ctrl+V), then Import. Replaces your current values.")
    share.box:SetText("")
    share.apply:SetText("Import")
    share.apply:Show()
    share.apply:SetScript("OnClick", function()
      local ok, msg = ImportText(share.box:GetText())
      share.status:SetText(ok and ("|cff4de673" .. msg .. "|r") or ("|cffff5555" .. msg .. "|r"))
      if ok then
        Say(msg)
      end
    end)
    share.status:SetText("")
    share:Show()
    share.box:SetFocus()
  end

  -- Named profiles (WarboardDB.profiles[name] = snapshot).
  local function SaveProfile(name)
    db.profiles = db.profiles or {}
    db.profiles[name] = Snapshot()
  end

  local function LoadProfile(name)
    local snap = db.profiles and db.profiles[name]
    if not snap then
      return false
    end
    ApplySnapshot(snap)
    db.activeProfile = name
    return true
  end

  -- Profile bar on the options page.
  do
    local p = optionsPanel
    local function Btn(text, w)
      local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
      b:SetSize(w or 70, 22)
      b:SetText(text)
      return b
    end
    local label = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", 16, -62)
    label:SetText("Profile")
    local name = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    name:SetSize(120, 20)
    name:SetPoint("LEFT", label, "RIGHT", 12, 0)
    name:SetAutoFocus(false)
    local save, load, del = Btn("Save"), Btn("Load"), Btn("Delete")
    save:SetPoint("LEFT", name, "RIGHT", 6, 0)
    load:SetPoint("LEFT", save, "RIGHT", 4, 0)
    del:SetPoint("LEFT", load, "RIGHT", 4, 0)
    local import, export = Btn("Import", 80), Btn("Export", 80)
    export:SetPoint("TOPRIGHT", -16, -58)
    import:SetPoint("RIGHT", export, "LEFT", -4, 0)
    local list = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    list:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    list:SetPoint("RIGHT", -16, 0)
    list:SetJustifyH("LEFT")

    p.RefreshProfiles = function()
      local names = {}
      for n in SortedPairs(db.profiles or {}) do
        names[#names + 1] = n == db.activeProfile and ("|cffffd100" .. n .. "|r") or n
      end
      list:SetText(#names > 0 and ("Saved: " .. table.concat(names, ", ")) or "No saved profiles yet")
      if name:GetText() == "" and db.activeProfile then
        name:SetText(db.activeProfile)
      end
    end
    local function Name()
      local n = (name:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
      return n ~= "" and n or nil
    end
    save:SetScript("OnClick", function()
      local n = Name()
      if n then
        SaveProfile(n)
        db.activeProfile = n
        Say("saved profile " .. n)
        p.RefreshProfiles()
      end
    end)
    load:SetScript("OnClick", function()
      local n = Name()
      if n and LoadProfile(n) then
        Say("loaded profile " .. n)
      elseif n then
        Say("no profile named " .. n)
      end
    end)
    del:SetScript("OnClick", function()
      local n = Name()
      if n and db.profiles and db.profiles[n] then
        db.profiles[n] = nil
        if db.activeProfile == n then
          db.activeProfile = nil
        end
        Say("deleted profile " .. n)
        name:SetText("")
        p.RefreshProfiles()
      end
    end)
    import:SetScript("OnClick", ShowImport)
    export:SetScript("OnClick", ShowExport)
  end
  Profiles.ShowExport = ShowExport
  Profiles.ShowImport = ShowImport
  Profiles.ImportText = ImportText
  Profiles.SaveProfile = SaveProfile
  Profiles.LoadProfile = LoadProfile
  Profiles.SortedPairs = SortedPairs
end)()

local function RegisterOptions()
  if Settings and Settings.RegisterCanvasLayoutCategory then
    optionsCategory = Settings.RegisterCanvasLayoutCategory(optionsPanel, "Warboard")
    for _, page in ipairs(optionsPages) do
      Settings.RegisterCanvasLayoutSubcategory(optionsCategory, page.frame, page.name)
    end
    Settings.RegisterAddOnCategory(optionsCategory)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(optionsPanel)
    for _, page in ipairs(optionsPages) do
      page.frame.name, page.frame.parent = page.name, optionsPanel.name
      InterfaceOptions_AddCategory(page.frame)
    end
  end
end

local function OpenOptions()
  if optionsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(optionsCategory:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(optionsPanel)
  end
end

-- Gear in the panel header.
do
  local gear = CreateFrame("Button", nil, frame)
  gear:SetSize(14, 14)
  gear:SetPoint("RIGHT", frame, "TOPRIGHT", -PAD - 1, -HEAD_H / 2)
  gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  gear:GetNormalTexture():SetVertexColor(MUTED[1], MUTED[2], MUTED[3])
  gear:SetScript("OnEnter", function(self)
    self:GetNormalTexture():SetVertexColor(1, 1, 1)
  end)
  gear:SetScript("OnLeave", function(self)
    self:GetNormalTexture():SetVertexColor(MUTED[1], MUTED[2], MUTED[3])
  end)
  gear:SetScript("OnClick", function()
    OpenOptions()
  end)
  subtitle:ClearAllPoints()
  subtitle:SetPoint("RIGHT", gear, "LEFT", -5, 0)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- Cata only (retail has no combat log). Enemy defensives: cast -> on
-- cooldown for its known duration; aura fading -> "spent: GO", even out of
-- sight. Deaths -> dead until the rez wave.
local function OnCombatLog()
  local _, sub, _, _, srcName, _, _, _, dstName, _, _, spellId = CombatLogGetCurrentEventInfo()
  if sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_AURA_APPLIED" or sub == "SPELL_INTERRUPT" then
    local entry = kitBySpell[spellId]
    local e = entry and enemies[Canon(srcName) or ""]
    if e and (entry.class == nil or entry.class == e.class) then
      ns.TrackCooldown(e, entry, sub, GetTime())
    end
  elseif sub == "SPELL_AURA_REMOVED" then
    local e = ns.Defensives[spellId] and enemies[Canon(dstName) or ""]
    if e then
      e.burnedAt = GetTime()
    end
  elseif sub == "UNIT_DIED" then
    local e = enemies[Canon(dstName) or ""]
    if e then
      e.dead, e.diedAt = true, GetTime()
    end
  end
end

local ev = CreateFrame("Frame")
local function Reg(event)
  pcall(ev.RegisterEvent, ev, event)
end

ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    WarboardDB = WarboardDB or {}
    db = WarboardDB
    for k, v in pairs(DEFAULTS) do
      if db[k] == nil then
        db[k] = type(v) == "table" and {} or v
      end
    end
    if (db.sniperVersion or 1) < 4 then
      db.sniperY, db.sniperVersion = -62, 4 -- scope sits on the upper torso
    end
    if (db.soundVersion or 1) < 2 then
      db.sniperSound, db.soundVersion = 1, 2 -- custom lock-on sound is the new default
    end
    myRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    db.apiMissing = {}
    for _, name in ipairs(API_USED) do
      if type(_G[name]) ~= "function" then
        db.apiMissing[#db.apiMissing + 1] = name
      end
    end
    BuildSpecLookup()
    BuildKits()
    db.points = db.points or {}
    RegisterOptions()
    BuildCurve()
    frame:SetScale(db.scale)
    frame:ClearAllPoints()
    if db.point then
      frame:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
    else
      frame:SetPoint("RIGHT", UIParent, "RIGHT", -260, 80)
    end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    if event == "PLAYER_ENTERING_WORLD" and not testMode then
      ns.MatchSerial = (ns.MatchSerial or 0) + 1
      wipe(enemies)
      wipe(order)
      allyFaction, currentBG, currentProfile, mapKey = nil, nil, nil, nil
      obj.mode, obj.assaultStart = nil, nil
      ns.flagRespawnAt = nil
      if active then ObjectiveStart() end
    end
    myRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or myRealm
    if not ns.MapWhere and not ns.mapWarned then
      ns.mapWarned = true
      print("|cffff5533Warboard|r intel map not loaded yet: restart the game client fully once (new file).")
    end
    CheckZone()
  elseif event == "UPDATE_BATTLEFIELD_SCORE" then
    if not active then
      CheckZone()
    end
    if active then
      Guard("roster", RefreshRoster)
    end
    if C_PvP.IsMatchComplete and C_PvP.IsMatchComplete() then
      HarvestHistory()
    end
  elseif event == "PVP_MATCH_COMPLETE" then
    HarvestHistory()
  elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE"
    or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
    OnObjectiveChat(event, arg1)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    if arg1 == sniper.unit then
      sniper:Hide()
      sniper.pulse:Stop()
      sniper.anchor, sniper.unit = nil, nil
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    if active then
      Tick()
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    UpdateTargetButton()
    if layoutPending then
      frame:SetShown(active and db.killorder ~= false)
      Layout()
    end
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED" then
    UpdateMe()
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if active and not testMode then
      OnCombatLog()
    end
  end
end)

Reg("ADDON_LOADED")
Reg("PLAYER_ENTERING_WORLD")
Reg("ZONE_CHANGED_NEW_AREA")
Reg("UPDATE_BATTLEFIELD_SCORE")
Reg("PVP_MATCH_COMPLETE")
Reg("PLAYER_REGEN_ENABLED")
Reg("PLAYER_TARGET_CHANGED")
Reg("NAME_PLATE_UNIT_REMOVED")
Reg("CHAT_MSG_BG_SYSTEM_ALLIANCE")
Reg("CHAT_MSG_BG_SYSTEM_HORDE")
Reg("CHAT_MSG_BG_SYSTEM_NEUTRAL")
Reg("PLAYER_SPECIALIZATION_CHANGED")
Reg("ACTIVE_TALENT_GROUP_CHANGED")
if not IS_RETAIL and CombatLogGetCurrentEventInfo and ns.Defensives then
  Reg("COMBAT_LOG_EVENT_UNFILTERED")
end

---------------------------------------------------------------------------
-- Slash
---------------------------------------------------------------------------
-- /wb probe: report which APIs return readable vs secret values right now,
-- on your target. Results are also saved to WarboardDB.lastProbe.
local function Probe(say)
  local out = {}
  local function show(label, f, ...)
    local res = { pcall(f, ...) }
    local text
    if not res[1] then
      text = "ERROR " .. tostring(res[2])
    else
      local parts = {}
      for i = 2, math.max(#res, 2) do
        local v = res[i]
        if v == nil then
          parts[#parts + 1] = "nil"
        elseif issecret(v) then
          parts[#parts + 1] = "SECRET"
        elseif type(v) == "table" then
          local okLen, n = pcall(function() return #v end)
          parts[#parts + 1] = okLen and plain(n) and ("table#" .. n) or "table(SECRET len)"
        else
          parts[#parts + 1] = tostring(v)
        end
      end
      text = table.concat(parts, ", ")
    end
    out[#out + 1] = label .. " = " .. text
    say(label .. " = |cffffff00" .. text .. "|r")
  end
  local _, instanceType = IsInInstance()
  show("instance", function() return instanceType end)
  show("IsRatedBattleground", C_PvP.IsRatedBattleground)
  show("IsSoloRBG", C_PvP.IsSoloRBG)
  show("GetActiveMatchState", C_PvP.GetActiveMatchState)
  show("addon active / enemies / allyFaction", function()
    local n = 0
    for _ in pairs(enemies) do n = n + 1 end
    return active, n, tostring(allyFaction)
  end)
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    show("InChatMessagingLockdown", C_ChatInfo.InChatMessagingLockdown)
  end
  show("NumBattlefieldScores", GetNumBattlefieldScores)
  show("rows per team (faction:count)", function()
    local counts = {}
    for i = 1, GetNumBattlefieldScores() or 0 do
      local info = ScoreInfo(i)
      local f = info and info.faction
      if plain(f) then
        counts[f] = (counts[f] or 0) + 1
      end
    end
    local parts = {}
    for f, c in pairs(counts) do
      parts[#parts + 1] = f .. ":" .. c
    end
    return table.concat(parts, " ")
  end)
  if (GetNumBattlefieldScores() or 0) > 0 then
    show("score[1].name/class/spec/faction", function()
      local i = ScoreInfo(1)
      if i then return i.name, i.classToken, i.talentSpec, i.faction end
    end)
  end
  local u = "target"
  if not UnitExists(u) then
    say("no target: target an enemy player and run /wb probe again for unit checks")
  else
    show("UnitName", UnitName, u)
    show("UnitClass", UnitClass, u)
    show("UnitIsPlayer", UnitIsPlayer, u)
    show("UnitCanAttack", UnitCanAttack, "player", u)
    show("CanonUnit / in roster", function()
      local k = CanonUnit(u)
      return k, k and enemies[k] ~= nil
    end)
    show("UnitIsDeadOrGhost", UnitIsDeadOrGhost, u)
    show("UnitHealthPercent", UnitHealthPercent, u, true)
    show("BIG_DEFENSIVE auras", C_UnitAuras.GetUnitAuras, u, "HELPFUL|BIG_DEFENSIVE")
    show("EXTERNAL_DEFENSIVE auras", C_UnitAuras.GetUnitAuras, u, "HELPFUL|EXTERNAL_DEFENSIVE")
    show("CROWD_CONTROL auras", C_UnitAuras.GetUnitAuras, u, "HARMFUL|CROWD_CONTROL")
    show("IMPORTANT (non-def) auras", C_UnitAuras.GetUnitAuras, u, "HELPFUL|IMPORTANT|!BIG_DEFENSIVE|!EXTERNAL_DEFENSIVE")
    show("GetRaidTargetIndex", GetRaidTargetIndex, u)
    show("UnitPowerMax mana", UnitPowerMax, u, 0)
    show("UnitHealthMax", UnitHealthMax, u)
    show("UnitPowerType", UnitPowerType, u)
    show("target's target is you", UnitIsUnit, u .. "target", "player")
    show("raid1target name", UnitName, "raid1target")
    show("nearest band (yards) / secret answer", NearestBand, u)
  end
  show("rows bound (row1 macro)", function()
    return WarboardRow1 and WarboardRow1:GetAttribute("macrotext1")
  end)
  db.lastProbe = { t = date("%Y-%m-%d %H:%M:%S"), lines = out }
  say("saved to SavedVariables (written on /reload or logout)")
end

SLASH_WARBOARD1 = "/wb"
SLASH_WARBOARD2 = "/warboard"
SLASH_WARBOARD3 = "/ko" -- pre-rename aliases
SLASH_WARBOARD4 = "/killorder"
SlashCmdList.WARBOARD = function(msg)
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  local function say(s)
    print("|cffff5533Warboard|r " .. s)
  end
  if cmd == "why" then
    -- Why the kill target is who it is: every enemy, best live score first.
    local cfg = (me.range or ns.RangeBands[me.class])
    local reach = cfg and (cfg.reachYards or cfg.attackYards) or 40
    say(string.format("kill target = best live score among enemies within %d yd (%s). Your target doesn't count.",
      reach, me.class or "?"))
    say("kill target: " .. (killNow and killNow.display or "none (nobody in reach)"))
    local list = {}
    for _, e in ipairs(order) do
      list[#list + 1] = e
    end
    table.sort(list, function(a, b)
      return (a.live or 0) > (b.live or 0)
    end)
    for i = 1, math.min(#list, 10) do
      local e = list[i]
      local parts = {}
      for _, w in ipairs(WEIGHTS) do
        local v = e.comp and e.comp[w.key]
        if v and math.abs(v) >= 0.5 then
          parts[#parts + 1] = string.format("%s%+.0f", w.key, v)
        end
      end
      local where = e.dead and "dead" or e.yards and string.format("%dyd", e.yards)
        or e.plateUnit and ">range" or "unseen"
      say(string.format("%s%d. %s  live %.0f  %s  %s%s", e == killNow and "|cffff6b1f" or "", i,
        e.display:match("^[^-]+"), e.live or 0, where, table.concat(parts, " "), e == killNow and "|r" or ""))
    end
    local a = db.liveStats and db.liveStats.auras
    say(string.format("aura reads: plain %d, secret %d, error %d%s", a and a.plain or 0, a and a.secret or 0,
      a and a.error or 0, db.auraErr and (" (" .. db.auraErr .. ")") or ""))
  elseif cmd == "intel" and not ns.MapWhere then
    say("|cffff5555intel map not loaded|r: Map.lua is a new file. Quit and restart the game client fully (/reload is not enough).")
  elseif cmd == "timers" then
    if arg == "off" or arg == "on" then
      db.timers = arg == "on"
    elseif arg == "reset" and ns.TimersWindowReset then
      ns.TimersWindowReset()
      say("res timers and bases windows moved back to their default spots")
    end
    say("timers " .. (db.timers == false and "OFF" or "on") .. (ns.TimersStatus and (" | " .. ns.TimersStatus()) or " (Timers.lua not loaded: restart the client)"))
  elseif cmd == "intel" then
    -- /wb intel [on|off|share on|share off|test]
    if arg == "test" and ns.IntelTest then
      say(ns.IntelTest() and "test pin ON: open the map, an orange rogue pin should sit mid-map" or "test pin off")
    elseif arg == "off" then
      db.intel = false
    elseif arg == "on" then
      db.intel = true
    elseif arg == "share off" then
      db.intelShare = false
    elseif arg == "share on" then
      db.intelShare = true
    end
    say(string.format("intel map %s, sharing with teammates %s", db.intel == false and "OFF" or "on",
      db.intelShare == false and "OFF" or "on"))
    if ns.IntelStatus then
      say(ns.IntelStatus())
    end
  elseif cmd == "export" then
    Profiles.ShowExport()
  elseif cmd == "import" then
    if arg ~= "" then
      -- /wb import WB1;... (lowercased by the slash parser: re-read raw)
      local raw = (msg or ""):match("^%S+%s+(.+)$")
      local ok, res = Profiles.ImportText(raw)
      say(res)
    else
      Profiles.ShowImport()
    end
  elseif cmd == "profile" then
    local sub, name = arg:match("^(%S*)%s*(.-)$")
    local rawName = (msg or ""):match("^%S+%s+%S+%s+(.+)$") -- keep the name's case
    if sub == "save" and rawName then
      Profiles.SaveProfile(rawName)
      db.activeProfile = rawName
      say("saved profile " .. rawName)
    elseif sub == "load" and rawName then
      say(Profiles.LoadProfile(rawName) and ("loaded profile " .. rawName) or ("no profile named " .. rawName))
    elseif sub == "delete" and rawName and db.profiles and db.profiles[rawName] then
      db.profiles[rawName] = nil
      say("deleted profile " .. rawName)
    else
      local names = {}
      for n in Profiles.SortedPairs(db.profiles or {}) do
        names[#names + 1] = n
      end
      say(#names > 0 and ("profiles: " .. table.concat(names, ", ")) or "no saved profiles")
      say("/wb profile save|load|delete NAME, /wb export, /wb import")
    end
  elseif cmd == "config" or cmd == "options" then
    OpenOptions()
  elseif cmd == "points" then
    -- /wb points            list overrides
    -- /wb points KEY N      set   (/wb points KEY reset)
    local key, val = arg:match("^(%S+)%s*(%S*)$")
    local real
    for k in pairs(POINT_DEFAULT) do
      if key and k:lower() == key:lower() then
        real = k
      end
    end
    if not key then
      local n = 0
      for k, v in pairs(db.points or {}) do
        n = n + 1
        say(string.format("%s = %s (default %s)", k, Fmt(v), Fmt(POINT_DEFAULT[k] or 0)))
      end
      say(n == 0 and "all points at default. /wb config to edit, /wb points KEY N to set" or "/wb points KEY reset")
    elseif not real then
      say("unknown key; see Options > AddOns > Warboard")
    elseif val == "reset" or val == "" then
      db.points[real] = nil
      say(real .. " reset to " .. Fmt(POINT_DEFAULT[real]))
      PointsChanged()
    elseif tonumber(val) then
      db.points[real] = tonumber(val) ~= POINT_DEFAULT[real] and tonumber(val) or nil
      say(real .. " = " .. val)
      PointsChanged()
    end
  elseif cmd == "kit" then
    -- Class breakdown for your target (or the kill target).
    local key = UnitExists("target") and CanonUnit("target")
    local e = (key and enemies[key]) or killNow
    if not e then
      say("target an enemy (or have a kill target) first")
    elseif not ns.Kits then
      say("cooldown tracking needs the combat log (Cata Classic only)")
    else
      say(e.display .. " (" .. (e.specID and specInfo[e.specID] and specInfo[e.specID].name or "?") .. " " .. e.class .. ")")
      for _, entry in ipairs(KitFor(e)) do
        local left = CdLeft(e, entry)
        say(string.format("  %-20s %s", entry[4], left and ("|cff4de673DOWN " .. Clock(left) .. "|r") or "ready"))
      end
    end
  elseif cmd == "err" then
    if db.apiMissing and #db.apiMissing > 0 then
      say("missing on this client: " .. table.concat(db.apiMissing, ", "))
    end
    local n = 0
    for key, rec in pairs(db.errors or {}) do
      n = n + 1
      say(string.format("|cffff4040%s|r x%d (since %s)", key, rec.count, rec.first))
    end
    say(n == 0 and "no errors recorded" or "full traces saved: /reload so they can be read from SavedVariables")
    for group, g in pairs(db.liveStats or {}) do
      if type(g) == "table" then
        local parts = {}
        for k, v in pairs(g) do
          parts[#parts + 1] = k .. "=" .. v
        end
        say(group .. ": " .. table.concat(parts, " "))
      end
    end
    if db.liveStats and db.liveStats.maxVisible then
      say("most enemies visible at once: " .. db.liveStats.maxVisible)
    end
    if db.healthErr then
      say("health error: " .. db.healthErr)
    end
    say("roster: " .. (rosterStatus or "ok") .. string.format(" | active=%s enemies=%d allyFaction=%s",
      tostring(active), (function() local c = 0 for _ in pairs(enemies) do c = c + 1 end return c end)(),
      tostring(allyFaction)))
  elseif cmd == "clearerr" then
    db.errors, lastError = nil, nil
    say("errors cleared")
  elseif cmd == "probe" then
    Probe(say)
  elseif cmd == "test" then
    if testMode then
      testMode = false
      SetActive(false)
      wipe(enemies)
      CheckZone()
      say("test mode off")
    else
      StartTest()
      local real = 0
      for key in pairs(enemies) do
        if not key:find("-Test", 1, true) then
          real = real + 1
        end
      end
      say(string.format("test mode on: %d rows use nearby nameplate names (clickable), rest are fake. /wb test again to stop", real))
      if real == 0 then
        say("no nameplates nearby: show nameplates (V) near NPCs for clickable rows and the sniper scope, or use /wb sniper test")
      end
    end
  elseif cmd == "weights" or (cmd == "weight" and arg == "") then
    for _, w in ipairs(WEIGHTS) do
      say(string.format("%-9s x%.1f  |cff888888%s|r", w.key, W(w.key), w.desc))
    end
    say("/wb weight NAME X  (0-5)  |  /wb weight reset")
  elseif cmd == "weight" then
    local name, val = arg:match("^(%S+)%s*(.-)$")
    if name == "reset" then
      db.weights = {}
      say("all coefficients reset to 1.0")
    else
      local known
      for _, w in ipairs(WEIGHTS) do
        if w.key == name then
          known = w
        end
      end
      local x = tonumber(val)
      if known and x then
        db.weights = db.weights or {}
        db.weights[name] = math.max(0, math.min(5, x))
        say(string.format("%s coefficient: x%.1f", name, db.weights[name]))
      else
        say("unknown weight or value. /wb weights to list")
      end
    end
  elseif cmd == "call" then
    if CALL_CHANNELS[arg] then
      db.callChannel = arg
      say("calls go to " .. CALL_CHANNELS[arg] .. "(press Enter to send)")
    elseif arg == "" then
      CallTarget()
    else
      say("/wb call  = call now  |  /wb call s|i|raid|party|y  = channel")
    end
  elseif cmd == "mark" then
    local sub, val = arg:match("^(%S*)%s*(.-)$")
    local names = { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" }
    local pings = { attack = true, warning = true, assist = true, onmyway = true }
    if sub == "icon" and tonumber(val) and tonumber(val) >= 1 and tonumber(val) <= 8 then
      db.markIcon, db.markMode = tonumber(val), "icon"
      markBound = nil
      UpdateTargetButton()
      say("mark button: raid icon " .. names[db.markIcon])
    elseif sub == "ping" then
      if pings[val] then
        db.pingType = val
      end
      db.markMode = "ping"
      markBound = nil
      UpdateTargetButton()
      say("mark button: " .. db.pingType .. " ping  (/wb mark ping attack|warning|assist|onmyway)")
    else
      say("Macro:  /click WarboardMarkButton   (pings/marks the kill target, keeps your target)")
      say("Now: " .. (db.markMode == "icon" and ("raid icon " .. names[db.markIcon or 8]) or (db.pingType .. " ping"))
        .. "   |  /wb mark ping attack|warning|assist|onmyway  |  /wb mark icon 1-8")
      say("Mark + call:  /click WarboardMarkButton  then  /wb call  on the next line")
      say("Re-points out of combat only. Raid icons may need lead/assist; pings don't.")
      local mt = markBtn:GetAttribute("macrotext")
      say("Button currently does: " .. ((mt and mt ~= "") and mt:gsub("\n", " | ")
        or "|cffff4040nothing|r (no kill target yet: in a BG, or /wb test first)"))
    end
  elseif cmd == "map" then
    mapKey = nil
    DetectMap()
    local ui = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local name, _, _, _, _, _, _, inst = GetInstanceInfo()
    say(string.format("%s  uiMap=%s instance=%s", tostring(name), tostring(ui), tostring(inst)))
    if currentBG then
      local tilts = {}
      for k, v in pairs(currentProfile or {}) do
        if k ~= "label" then tilts[#tilts + 1] = k .. " x" .. v end
      end
      say(string.format("profile: %s (%s)%s  %s", currentBG.name, currentProfile.label, isBlitz and " +Blitz" or "",
        table.concat(tilts, ", ")))
    else
      say("no battleground profile for this map (default weights)")
    end
  elseif cmd == "live" then
    db.liveSort = not db.liveSort
    say("live re-ordering: " .. (db.liveSort and "on (defensives/CC/burst/range move rows)" or "off (stable order, live state shown as icons)"))
  elseif cmd == "pressure" then
    if ns.PressureCommand then
      ns.PressureCommand(arg, say)
    else
      say("Enemy focus markers have not loaded; restart the game after updating the addon.")
    end
  elseif cmd == "sniper" then
    local sub, val = arg:match("^(%S*)%s*(.-)$")
    if sub == "test" then
      sniperTest.on = not sniperTest.on
      sniperTest.go = false
      if sniperTest.on then
        sniperDriver:Show()
        say("sniper test ON: target anything with a visible nameplate (V / Shift+V). /wb go = kill-window look. /wb sniper test = stop")
      else
        sniperDriver:Hide()
        UpdateSniper(nil)
        say("sniper test off")
      end
    elseif sub == "color" then
      if SNIPER_COLORS[val] then
        db.sniperColor = val
        say("sniper color: " .. val)
      else
        local names = {}
        for k in pairs(SNIPER_COLORS) do names[#names + 1] = k end
        table.sort(names)
        say("/wb sniper color NAME  (" .. table.concat(names, ", ") .. ")")
      end
    elseif sub == "size" and tonumber(val) then
      db.sniperScale = math.max(0.5, math.min(3, tonumber(val)))
      say("sniper size: x" .. db.sniperScale)
    elseif sub == "sound" then
      local n = tonumber(val)
      if n and n >= 0 and n <= #SNIPER_SOUNDS then
        db.sniperSound = n
        PlaySniperSound()
        say("lock-on sound: " .. (SNIPER_SOUNDS[n] and SNIPER_SOUNDS[n].name or "off"))
      else
        local list = {}
        for i, snd in ipairs(SNIPER_SOUNDS) do
          list[#list + 1] = i .. "=" .. snd.name
        end
        say("/wb sniper sound N  (" .. table.concat(list, ", ") .. ", 0=off)")
      end
    elseif sub == "y" and tonumber(val) then
      db.sniperY = math.max(-200, math.min(120, tonumber(val)))
      say("sniper offset from nameplate bottom: " .. db.sniperY .. " (negative = lower, onto the body)")
    else
      db.sniper = not db.sniper
      say("sniper scope over the kill target: " .. (db.sniper and "on" or "off") .. "  (/wb sniper y N to raise/lower)")
    end
  elseif cmd == "sound" then
    db.sound = not db.sound
    say("kill-window sound: " .. (db.sound and "on" or "off"))
  elseif cmd == "go" and sniperTest.on then
    sniperTest.go = not sniperTest.go
    if sniperTest.go and db.sound then
      PlayGoSound()
    end
    say("sniper test: kill-window look " .. (sniperTest.go and "on" or "off"))
  elseif cmd == "go" then
    -- Preview the kill-window alert on the current #1.
    local top = order[1]
    if top then
      top.burnedAt = GetTime()
      top.range = top.range or "attack"
      top.def, top.cc, top.dead = false, false, false
      if testMode then
        Tick()
      end
      say("kill-window preview on " .. top.display .. (testMode and "" or " (live data may override)"))
    else
      say("no enemies listed: try /wb test first")
    end
  elseif cmd == "lock" then
    db.locked = true
    say("locked")
  elseif cmd == "unlock" then
    db.locked = false
    say("unlocked: drag to move")
  elseif cmd == "all" then
    db.allBGs = not db.allBGs
    say("all battlegrounds: " .. (db.allBGs and "on" or "off (rated only)"))
    CheckZone()
  elseif cmd == "rows" and tonumber(arg) then
    db.rows = math.max(1, math.min(15, tonumber(arg)))
    say("rows: " .. db.rows)
  elseif cmd == "scale" and tonumber(arg) then
    db.scale = math.max(0.5, math.min(2, tonumber(arg)))
    frame:SetScale(db.scale)
  elseif cmd == "exec" and tonumber(arg) then
    db.executePct = math.max(5, math.min(90, tonumber(arg))) / 100
    BuildCurve()
    say(string.format("execute highlight below %d%%", db.executePct * 100))
  elseif cmd == "reset" then
    db.point = nil
    frame:ClearAllPoints()
    frame:SetPoint("RIGHT", UIParent, "RIGHT", -260, 80)
  else
    UpdateMe()
    local si = me.specID and specInfo[me.specID]
    say(string.format("you: %s %s (%s, %s)", si and si.name or "?", me.class or "?", me.dmg,
      me.melee and "melee" or "ranged"))
    say("/wb intel | config | profile | export | import | points | why | kit | test | go | call | mark | probe | map | sound | sniper | pressure | weights | live | lock | unlock | all | rows N | scale X | exec PCT | reset")
    say("Keybind 'Target kill-order #1' under Key Bindings > AddOns.")
  end
end

-- For Map.lua (intel map): read-only views of Core state.
ns.enemies = enemies
ns.specInfo = specInfo
ns.CanonUnit = CanonUnit
ns.GetDB = function()
  return db
end
ns.IsActive = function()
  return active and not testMode
end
ns.GetKillNow = function()
  return killNow
end
ns.GetAllyFaction = function()
  return allyFaction
end
ns.FlagStacks = FlagStacks
ns.GetBG = function()
  return currentBG
end
ns.P = P

-- Resolved rules are immutable configuration for the current client and mode.
ns.GetBGRules = function()
  return currentBG and currentBG.rules
end
