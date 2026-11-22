local _, ns = ...
local Core = ns.Core
local Util = ns.Util

---------------------------------------------------------------------------
-- Auras and plates: aura counts by category (retail) or by spell ID (Cata),
-- enemy nameplate tokens and how many teammates target each enemy.
---------------------------------------------------------------------------
local function Length(list) return #list end

function Core.CountAuras(unit, filter)
  if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then
    return nil
  end
  local ok, list = pcall(C_UnitAuras.GetUnitAuras, unit, filter)
  if not ok or type(list) ~= "table" then
    -- Never counted before: tells /hg why whether aura flags can work at all.
    Core.Stat("auras", ok and "notTable" or "error")
    if not ok and not Core.db.auraErr then
      Core.db.auraErr = tostring(list)
    end
    return nil
  end
  local n = Util.read(Length, list)
  if n ~= nil then
    Core.Stat("auras", "plain")
    return n, list
  end
  Core.Stat("auras", "secret")
end

-- One reading per owner (an enemy entry), reused on every scan: all fields
-- are reset here. activeCooldowns is a buffer the caller may swap out.
local FILTERS = { "HELPFUL", "HARMFUL" }
local function Reading(owner)
  local r = owner and owner.auraReading or {}
  if owner then owner.auraReading = r end
  local active, markerSet = r.activeCooldowns or {}, r.markerSet or {}
  wipe(r); wipe(active); wipe(markerSet)
  r.activeCooldowns, r.markerSet = active, markerSet
  return r
end

-- Cata Classic: no aura categories, but every aura carries its spellId.
function Core.ReadAurasByList(unit, class, owner)
  local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  local r = Reading(owner)
  local hints = ns.SpecInferenceConfig and ns.SpecInferenceConfig.auras[class]
  local markers = ns.SpecInferenceConfig and ns.SpecInferenceConfig.markers and ns.SpecInferenceConfig.markers[class]
  if not get then
    return r
  end
  r.readable = true
  for _, filter in ipairs(FILTERS) do
    for i = 1, 40 do
      local ok, a = pcall(get, unit, i, filter)
      if not ok then r.readable = false end
      if not ok or not a then
        break
      end
      local id = a.spellId
      if filter == "HELPFUL" then
        local defensive = ns.Defensives[id]
        if defensive and defensive.immunity == "all" then r.immune = true end
        local kit = Core.kitBySpell[id]
        if kit then r.activeCooldowns[kit[1]] = true end
        -- Big offensive buffs for the burst markers, with how they can be removed.
        if kit and kit.mark then
          r.bursts = r.bursts or {}
          r.bursts[#r.bursts + 1] = { kit = kit, spell = id, icon = a.icon,
            dispel = Core.plain(a.dispelName) and a.dispelName or nil, steal = Core.plain(a.isStealable) and a.isStealable or nil }
        end
        local hint = hints and hints[id]
        -- External/stealable buffs cannot identify their recipient's spec.
        local own = false
        local marker = markers and markers[id]
        if (hint or marker) and a.sourceUnit then
          own = Util.read(UnitIsUnit, a.sourceUnit, unit) == true
        end
        if marker and own then
          r.markers = r.markerSet
          r.markers[marker] = true
        end
        if hint and own and not a.isStealable then
          if r.specTree and r.specTree ~= hint[1] then r.specConflict = true end
          r.specTree, r.specReason = hint[1], ns.Locale:Format("battlegrounds.auras.value1_buff.ec59d9", { value1 = hint[2] })
        end
        -- Cloak against a warrior, Spell Reflect against a rogue: not a defensive.
        local weight = ns.Defensives[id] and ns.DefensiveWeight(id, Core.me.dmg) or 0
        if weight > 0 and ns.CooldownTracked(Core.db, id) then
          r.def = true
          r.defScale = math.max(r.defScale or 0, weight)
          r.defIcon = r.defIcon or a.icon
          r.defSpell = r.defSpell or id
        elseif ns.Burst[id] and ns.CooldownTracked(Core.db, id) then
          r.burst = true
          r.burstIcon = r.burstIcon or a.icon
          r.burstSpell = r.burstSpell or id
        end
      elseif ns.ImmuneCC[id] then
        r.immune = true
      elseif ns.SoftCC[id] then
        r.cc = true
      elseif ns.HardCC[id] then
        r.stun = true
      end
    end
  end
  if r.specConflict then r.specTree, r.specReason = nil, nil end
  Core.Stat("auras", "plain")
  return r
end

-- Map enemies to their nameplate token (for the world-space sniper scope).
local PLATES = ns.UnitTokens.nameplate
function Core.ScanPlates()
  for _, e in pairs(Core.enemies) do
    e.plateUnit = nil
  end
  for i = 1, #PLATES do
    local unit = PLATES[i]
    if Util.read(UnitExists, unit) then
      local key = Core.CanonUnit(unit)
      local e = key and Core.enemies[key]
      if e and not e.plateUnit then
        e.plateUnit = unit
      end
    end
  end
end

-- Who your team is hitting: UnitName on "raidNtarget" resolves enemy players
-- by name (readable in PvP), so we can count allies per enemy.
local TARGET_OF = ns.UnitTokens.target
function Core.ScanAllyTargets()
  for _, e in pairs(Core.enemies) do
    e.allyCount = 0
  end
  -- Teammates only: your own target must not bump an enemy's score, or
  -- simply targeting someone would pull the kill target onto them.
  local myName = UnitName("player")
  local units, n = ns.UnitTokens.Group()
  for i = 1, n do
    local owner = units[i]
    local ownerName = Util.read(UnitName, owner)
    if ownerName == nil or ownerName ~= myName then
      local key = Core.CanonUnit(TARGET_OF[owner])
      local e = key and Core.enemies[key]
      if e then
        e.allyCount = e.allyCount + 1
      end
    end
  end
end
