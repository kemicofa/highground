local _, ns = ...
local Core = ns.Core
local Util = ns.Util

---------------------------------------------------------------------------
-- Units: what the visible unit tokens tell about each enemy (range, death,
-- auras, health, mana, their target, marker, cast), read by ScanUnits.
---------------------------------------------------------------------------

-- Returns the raw in-range answer (true/false, possibly secret) or nil.
function Core.RangeCheck(list, unit)
  if not (list and C_Spell and C_Spell.IsSpellInRange) then
    return nil
  end
  for _, id in ipairs(list) do
    local r = Util.call(C_Spell.IsSpellInRange, id, unit)
    if type(r) ~= "nil" then -- type() is safe on secret booleans
      Core.Stat("range", Core.issecret(r) and "secret" or "plain")
      return r
    end
  end
  Core.Stat("range", "none")
end

-- Nearest distance band (yards) the unit is in, using your class's spells.
-- Returns yards (plain), or nil + the first secret answer seen (display only).
function Core.NearestBand(unit)
  local cfg = (Core.me.range or ns.RangeBands[Core.me.class])
  if not cfg then
    return nil
  end
  local secretAnswer
  for _, band in ipairs(cfg.bands) do
    local r = Core.RangeCheck(band[2], unit)
    if Core.plain(r) then
      if r == true then
        return band[1]
      end
    elseif type(r) ~= "nil" and type(secretAnswer) == "nil" then
      secretAnswer = r
    end
  end
  return nil, secretAnswer
end

-- Tokens that can show an enemy, best first: the first match wins.
local SCAN = { "target", "focus", "mouseover", "softenemy" }
for i = 1, 4 do SCAN[#SCAN + 1] = ns.UnitTokens.arena[i] end
for i = 1, 40 do SCAN[#SCAN + 1] = ns.UnitTokens.nameplate[i] end
local TARGET_OF = ns.UnitTokens.target
local NONE = {}
-- Health as 0-100 on the Midnight client: secret, but drawable and printable.
local SCALE_100 = UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100
-- Druid power types guess a spec where nothing else can (core/Specs.lua).
local FORMS = ns.Caps.classicSpecs and not ns.Caps.enemyAuras

-- Loss of control on any unit token (WoW Forever: readable for enemies,
-- nameplates and teammates' targets while their auras are refused). Only
-- the count is plain; the kind, timer and spell are secret, and the plain
-- priority/displayType don't tell kinds apart (live 2026-11-24: Gouge,
-- Cheap Shot and Kidney Shot all 5/2). nil when unreadable.
local function LossOfControl(unit)
  local L = C_LossOfControl
  local n = L and L.GetActiveLossOfControlDataCountByUnit and Util.read(L.GetActiveLossOfControlDataCountByUnit, unit)
  if type(n) == "number" then return n > 0 end
end

-- Readings reused per enemy instead of new tables every tick. Fields are
-- rewritten on each reading; e.cast / e.specManaObservation point at them
-- only while current.
local function CastInfo(e, name, icon, start, finish, channel, kickable, spell)
  local c = e.castInfo or {}
  e.castInfo = c
  c.name, c.icon, c.start, c.finish, c.channel, c.kickable, c.spell = name, icon, start, finish, channel, kickable, spell
  c.capture = nil
  return c
end
local function ManaObservation(e, mana, level, at)
  local o = e.manaObservation or {}
  e.manaObservation = o
  o.mana, o.level, o.at = mana, level, at
  return o
end

-- Player keys of unit tokens during one tick. ScanUnits resolves every
-- visible token; plates, teammates' targets, carriers and markers then ask
-- for the same ones. Only inside the tick's frame: after it, an event can
-- point a token at someone else.
local tickKeys, tickAt = {}, nil
function Core.OpenTickKeys() wipe(tickKeys); tickAt = GetTime() end
function Core.CloseTickKeys() tickAt = nil end
function Core.TickKey(unit)
  if tickAt == nil or tickAt ~= GetTime() then return Core.CanonUnit(unit) end
  local key = tickKeys[unit]
  if key == nil then
    key = Core.CanonUnit(unit) or false
    tickKeys[unit] = key
  end
  return key or nil
end

-- Auras are read again only when they may have changed: an enemy newly in
-- view or on another token, or an aura change. Cata's combat log names the
-- enemy (core/CombatLog.lua). Target, focus, arena and nameplate tokens get
-- UNIT_AURA (core/Events.lua), else every two seconds; raid targets,
-- mouseover and the soft target get none, so at least once a second.
local AURA_EVENTS = { target = true, focus = true }
for i = 1, 4 do AURA_EVENTS[ns.UnitTokens.arena[i]] = true end
for i = 1, 40 do AURA_EVENTS[ns.UnitTokens.nameplate[i]] = true end
Core.AURA_EVERY, Core.AURA_RECHECK = 1, 2
local auraTokens = {} -- [token] = true after its UNIT_AURA
function Core.AuraEvent(unit) auraTokens[unit] = true end
local function AurasStale(e, unit, now)
  if not e.wasVisible or e.auraUnit ~= unit or e.auraDirty then return true end
  local age = now - (e.auraAt or -math.huge)
  if AURA_EVENTS[unit] then return auraTokens[unit] or age >= Core.AURA_RECHECK end
  return age >= Core.AURA_EVERY
end
local function AurasRead(e, unit, now)
  e.auraUnit, e.auraAt, e.auraDirty = unit, now, nil
  auraTokens[unit] = nil
end

-- Green to red on the Midnight client: the curve's colour at the unit's
-- health, only handed to the bar. Read once per tick by the rows and the
-- hero card that draw it (ui/Health.lua).
function Core.HealthTint(e, unit)
  local now = GetTime()
  if e.hpTintAt ~= now then
    e.hpTintAt = now
    e.hpTint = SCALE_100 and Core.healthCurve and Core.EnemyColorMode() == "health"
      and Util.call(UnitHealthPercent, unit, true, Core.healthCurve) or nil
  end
  return e.hpTint
end

local function Claim(unit)
  local key = Core.TickKey(unit)
  if key and Core.enemies[key] and not Core.unitFor[key] then
    Core.unitFor[key] = unit
    return 1
  end
  return 0
end

function Core.ScanUnits()
  local now = GetTime()
  for _, e in pairs(Core.enemies) do ns.FilterCooldownState(e, Core.db) end
  wipe(Core.unitFor)
  local visible = 0
  for i = 1, #SCAN do
    local unit = SCAN[i]
    if Util.read(UnitExists, unit) then visible = visible + Claim(unit) end
  end
  -- Teammates' targets come last: an enemy only a teammate targets still
  -- has live health while your client can see it. Messages can't share it
  -- (secret on the Midnight client, chat lockdown in matches).
  local group, n = ns.UnitTokens.Group()
  for i = 1, n do
    local unit = TARGET_OF[group[i]]
    if Util.read(UnitIsVisible, unit) then visible = visible + Claim(unit) end
  end
  Core.db.liveStats = Core.db.liveStats or {}
  Core.db.liveStats.maxVisible = math.max(Core.db.liveStats.maxVisible or 0, visible)

  -- Whom enemies target, by player key: you, and teammates who heal.
  local myKey = Core.TickKey("player")
  local healers = Core.TeamHealers and Core.TeamHealers() or NONE
  for key, e in pairs(Core.enemies) do
    local unit = Core.unitFor[key]
    e.unit = unit
    if unit then
      local specAuras
      local wasDead = e.dead
      e.dead = Util.read(UnitIsDeadOrGhost, unit) or false
      if e.dead and not wasDead then
        -- Seen dying: dead until seen alive or the rez wave, also where no
        -- combat log reports deaths (Retail, WoW Forever).
        e.diedAt = GetTime()
        Core.SapCall(e)
      end
      if ns.Defensives then
        -- Cata: classify auras by spellId (config/cata/Auras.lua lists).
        local a = e.auraReading
        if not (a and a.readable) or AurasStale(e, unit, now) or not Core.ReadingCurrent(a) then
          local hadDef = e.def and e.wasVisible
          local defSpell = e.defSpell
          a = Core.ReadAurasByList(unit, e.class, e)
          if a.readable then
            AurasRead(e, unit, now)
            -- Swap the active-cooldown buffers: the reading becomes current.
            a.activeCooldowns, e.activeCooldowns = e.activeCooldowns, a.activeCooldowns
            e.immune = a.immune or false
            e.def, e.cc, e.stun, e.burst = a.def or false, a.cc or false, a.stun or false, a.burst or false
            e.defScale = a.defScale
            e.defIcon, e.burstIcon = a.defIcon, a.burstIcon
            e.defSpell, e.burstSpell = a.defSpell, a.burstSpell
            e.bursts = a.bursts
            if hadDef and not e.def then
              e.burnedAt = now
              e.burnedSpell = defSpell
            end
          end
        end
        specAuras = a
      else
        -- WoW Forever refuses enemy auras in a match: don't ask (each call
        -- would error), the loss-of-control count below stands in for CC.
        if not ns.Caps.enemyAuras then
          e.def, e.burst, e.defIcon, e.burstIcon, e.auraCC = false, false, nil, nil, nil
        elseif AurasStale(e, unit, now) then
          AurasRead(e, unit, now)
          -- A refused first read refuses the rest: one error, not four.
          local def, defIcon = Core.FirstAura(unit, "HELPFUL|BIG_DEFENSIVE")
          local ext, extIcon, burst, burstIcon, cc
          if def ~= nil then
            ext, extIcon = Core.FirstAura(unit, "HELPFUL|EXTERNAL_DEFENSIVE")
            -- "Important" buffs minus defensives are mostly offensive cooldowns.
            burst, burstIcon = Core.FirstAura(unit, "HELPFUL|IMPORTANT|!BIG_DEFENSIVE|!EXTERNAL_DEFENSIVE")
            cc = Core.FirstAura(unit, "HARMFUL|CROWD_CONTROL")
          end
          local hadDef = e.def and e.wasVisible
          e.def = def == true or ext == true
          -- Defensive aura faded while we watched: they just spent it.
          if hadDef and not e.def and def ~= nil then e.burnedAt = now end
          e.burst = burst == true
          -- Icons may be secret: never truth-tested, only handed on.
          e.burstIcon, e.defIcon = nil, nil
          if e.burst then e.burstIcon = burstIcon end
          if def then e.defIcon = defIcon elseif ext then e.defIcon = extIcon end
          e.auraCC = cc
        end
        -- The Retail category includes stuns as well as breakable CC. A
        -- category alone cannot justify a "do not break" score penalty.
        -- Auras refused (WoW Forever): the loss-of-control count says the
        -- same, with the same unknown kind.
        local was = e.crowdControlled
        if e.auraCC == nil then
          e.crowdControlled = LossOfControl(unit) or false
          if e.crowdControlled ~= was and ns.LossOfControlChanged then ns.LossOfControlChanged(e) end -- bg profiler
        else
          e.crowdControlled = e.auraCC
        end
        e.cc, e.stun = false, false
      end
      -- Readable max health supports the gear proxy. Cata's max mana can
      -- support a spec estimate once confirmed examples have been collected.
      local mana = Util.read(UnitPowerMax, unit, 0)
      if mana ~= nil then
        e.maxMana = mana
      end
      local hp = Util.read(UnitHealthMax, unit)
      if hp ~= nil then
        e.maxHP = hp
        e.hpSamples = e.hpSamples or {}
        if hp ~= e.hpSamples[#e.hpSamples] then
          table.insert(e.hpSamples, hp)
          if #e.hpSamples > 15 then
            table.remove(e.hpSamples, 1)
          end
          e.hpMedian = Core.Median(e.hpSamples)
        end
      end
      -- Current health: plain on Cata (scores + exec), secret on retail.
      e.hpPct = Util.HealthFraction(unit)
      -- 0-100 for the board, kept after the unit is gone (e.lastSeen): plain
      -- on Cata, secret on the Midnight client and only ever drawn.
      if e.dead then
        e.hpSeen = nil
      elseif SCALE_100 then
        e.hpSeen = Util.call(UnitHealthPercent, unit, true, SCALE_100)
      else
        e.hpSeen = e.hpPct and e.hpPct * 100
      end
      -- Green to red: drawn rows read it (Core.HealthTint). An enemy without
      -- a row keeps a reading at most a second old for its last seen bar.
      if e.dead then
        e.hpTint = nil
      elseif SCALE_100 and now - (e.hpTintAt or -math.huge) >= 1 then
        Core.HealthTint(e, unit)
      end
      -- Mana (plain on Cata). Only while mana is their shown power: a
      -- shapeshifted druid reports 0 mana in cat/bear form.
      local ptype = Util.read(UnitPowerType, unit)
      if ns.SpecInferenceConfig then
        e.specManaObservation = nil
        local level = Util.read(UnitLevel, unit)
        if ptype == 0 and type(mana) == "number" and mana > 0 and type(level) == "number" and level > 0 then
          e.specManaObservation = ManaObservation(e, mana, level, GetTime())
        end
        Core.EstimateSpec(e, specAuras)
      end
      if FORMS then Core.EstimateDruidForm(e, ptype, Util.read(UnitLevel, unit), unit) end
      if ptype == 0 then
        local mp = Util.read(UnitPower, unit, 0)
        if mp ~= nil and mana ~= nil and mana > 0 then
          e.manaPct, e.manaAt = mp / mana, GetTime()
        end
      end
      if not e.dead then
        e.diedAt = nil
      end
      -- Is this enemy targeting you or a teammate who heals? UnitIsUnit is
      -- secret on the Midnight client, but the name of an enemy's target is
      -- plain (WoW Forever, live 2026-11-24), so player keys decide there.
      -- A secret answer without a readable name only lights the row's eye.
      -- Never truth-test a possibly-secret value ("x and y or z" does): only
      -- plain() / type() / issecret() may touch it before it's known plain.
      local onMe = Util.call(UnitIsUnit, TARGET_OF[unit], "player")
      local targetKey
      if not Core.plain(onMe) or next(healers) then targetKey = Core.TickKey(TARGET_OF[unit]) end
      e.onMeRaw = onMe
      if Core.plain(onMe) then
        e.onMe = onMe == true
      else
        e.onMe = targetKey ~= nil and targetKey == myKey
      end
      e.onHealer = not e.onMe and targetKey and healers[targetKey] and targetKey or nil
      -- Raid marker (team calls). Remembered while out of sight, and kept
      -- when the call fails (raw pcall: nil from the game clears it).
      local okMark, mark = pcall(GetRaidTargetIndex, unit)
      if okMark and Core.plain(mark) then
        e.marker = mark
      elseif okMark and mark == nil then
        e.marker = nil
      end
      -- Distance: nearest band in yards (plain) drives the kill target;
      -- a secret answer can only light the range pip.
      local yards, secretAnswer = Core.NearestBand(unit)
      e.yards = yards
      e.rangeRaw = secretAnswer
      local cfg = (Core.me.range or ns.RangeBands[Core.me.class])
      e.range = nil
      if yards then
        e.range = (cfg and yards <= cfg.attackYards) and "attack" or "reach"
      end
      -- Cast bar (plain on Cata; secret values on retail are skipped).
      e.cast = nil
      local okC, cName, _, cIcon, cStart, cEnd, _, _, cNoInt, cSpell = pcall(UnitCastingInfo, unit)
      local channel = false
      if not (okC and Core.plain(cName)) then
        okC, cName, _, cIcon, cStart, cEnd, _, cNoInt, cSpell = pcall(UnitChannelInfo, unit)
        channel = true
      end
      if okC and Core.plain(cName) and Core.plain(cStart) and Core.plain(cEnd) then
        e.cast = CastInfo(e, cName, cIcon, cStart / 1000, cEnd / 1000, channel,
          not (Core.plain(cNoInt) and cNoInt), Core.plain(cSpell) and cSpell or nil)
      end
      Core.UpdateCapture(e, unit)
      e.lastSeen = GetTime()
      e.wasVisible = true
    else
      e.wasVisible = false
      e.range, e.rangeRaw, e.yards = nil, nil, nil
      e.onMe, e.onMeRaw, e.onHealer = false, nil, nil
      e.cast = nil
      if GetTime() - (e.lastSeen or 0) > 4 then
        -- Out of sight for a while: drop stale aura state.
        e.def, e.cc, e.defIcon, e.burst, e.burstIcon, e.stun, e.hpPct = false, false, nil, false, nil, false, nil
        e.bursts = nil
        e.immune = false
        -- Died (combat log) -> dead until seen alive or the 30s rez wave.
        e.crowdControlled = false
        e.dead = e.diedAt ~= nil and GetTime() - e.diedAt < 35
        if e.dead then e.hpSeen, e.hpTint = nil, nil end
      end
    end
  end
end
