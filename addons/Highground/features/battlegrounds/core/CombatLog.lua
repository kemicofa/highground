local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
-- Combat-log names to roster keys. Core.Canon builds a new string per call,
-- and the same few dozen names cast and lose auras many times a second.
-- At most 256 names, forgotten when your realm changes.
local keys, count, keysRealm = {}, 0, nil
local function Enemy(name)
  if type(name) ~= "string" or Core.issecret(name) then return nil end
  if count >= 256 or keysRealm ~= Core.myRealm then
    wipe(keys)
    count, keysRealm = 0, Core.myRealm
  end
  local key = keys[name]
  if key == nil then
    key = Core.Canon(name) or false
    keys[name], count = key, count + 1
  end
  return key and Core.enemies[key]
end

-- Aura changes: the unit scan reads that enemy's auras again (core/Units.lua),
-- also on raid targets and mouseover, which get no UNIT_AURA.
local AURA_CHANGES = { SPELL_AURA_APPLIED = true, SPELL_AURA_REMOVED = true, SPELL_AURA_REFRESH = true,
  SPELL_AURA_APPLIED_DOSE = true, SPELL_AURA_REMOVED_DOSE = true, SPELL_AURA_BROKEN = true,
  SPELL_AURA_BROKEN_SPELL = true }
-- The subevents read here; others skip the guarded call (core/Events.lua).
Core.LOG_SUBEVENTS = { SPELL_CAST_START = true, SPELL_CAST_SUCCESS = true, SPELL_CAST_FAILED = true,
  SPELL_INTERRUPT = true, UNIT_DIED = true }
for sub in pairs(AURA_CHANGES) do Core.LOG_SUBEVENTS[sub] = true end

-- Cata only (retail has no combat log). Enemy defensives: cast -> on
-- cooldown for its known duration; aura fading -> "spent: GO", even out of
-- sight. Deaths -> dead until the rez wave.
function Core.OnCombatLog()
  local _, sub, _, _, srcName, _, _, _, dstName, _, _, spellId, spellName = ns.PvPEvents.Log()
  if AURA_CHANGES[sub] then
    local target = Enemy(dstName)
    if target then target.auraDirty = true end
  end
  if sub == "SPELL_CAST_START" or sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_CAST_FAILED" then
    Core.CaptureFromLog(sub, srcName, spellId, spellName)
    if sub ~= "SPELL_CAST_FAILED" then Core.SpecFromLog(Enemy(srcName), spellName) end
  elseif sub == "SPELL_INTERRUPT" then
    Core.CaptureEnded(dstName)
  end
  if sub == "SPELL_AURA_APPLIED" and Core.NoteBurst then Core.NoteBurst(dstName, spellId) end
  if sub == "SPELL_CAST_SUCCESS" or sub == "SPELL_AURA_APPLIED" or sub == "SPELL_INTERRUPT" then
    local entry = Core.kitBySpell[spellId]
    local e = entry and Enemy(srcName)
    if e and (entry.class == nil or entry.class == e.class) then
      ns.TrackCooldown(e, entry, sub, GetTime())
    end
  elseif sub == "SPELL_AURA_REMOVED" then
    local target = Enemy(dstName)
    if target and target.activeCooldowns then target.activeCooldowns[ns.CooldownKey(spellId)] = nil end
    if target and ns.DefensiveWeight(spellId, Core.me.dmg) > 0 and ns.CooldownTracked(Core.db, spellId) then
      target.burnedAt, target.burnedSpell = GetTime(), spellId
    end
  elseif sub == "UNIT_DIED" then
    local e = Enemy(dstName)
    if e then
      e.dead, e.diedAt = true, GetTime()
      Core.SapCall(e)
    end
  end
end
