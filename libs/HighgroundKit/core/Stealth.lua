local addon, ns = ...
local U, Core = ns.Util, ns.Core
local S = { GRACE = 2, REPEAT = 10 }
ns.Stealth = S

-- Shared by Nearby and the battleground/arena observers. Only the final
-- hiding aura ends stealth; Vanish and Invisibility have intermediate auras.
-- Names are English fallbacks; messages use the client's name (S.Name).
S.spells = {
  [1784] = { "Stealth", fades = true }, [1785] = { "Stealth", fades = true },
  [1786] = { "Stealth", fades = true }, [1787] = { "Stealth", fades = true },
  [115191] = { "Stealth", fades = true },
  [5215] = { "Prowl", fades = true }, [6783] = { "Prowl", fades = true }, [9913] = { "Prowl", fades = true },
  [1856] = { "Vanish" }, [1857] = { "Vanish" }, [11327] = { "Vanish" },
  [66] = { "Invisibility" }, [32612] = { "Invisibility", fades = true },
  [110959] = { "Greater Invisibility", fades = true },
  [58984] = { "Shadowmeld", fades = true },
  [199483] = { "Camouflage", fades = true },
}

-- The client's name for a hiding spell, or its English name.
function S.Name(id)
  local spell = S.spells[id or 0]
  return U.SpellName(id) or spell and spell[1]
end

local sounds = "Interface\\AddOns\\" .. addon .. "\\libs\\sounds\\"
local function Play(file)
  -- Newly installed files need a client restart. Until then, use the
  -- original in-game Stealth sound kit, never the raid-warning cue.
  if not U.call(PlaySoundFile, sounds .. file .. ".ogg", "Master") then
    U.call(PlaySound, 3325, "Master")
  end
end
function S.EnterSound() Play("stealth-enter") end
function S.ExitSound() Play("stealth-exit") end

local function Notify(e, spell, faded, nearby)
  if ns.NearbyHistory and ns.NearbyHistory.Muted and ns.NearbyHistory.Muted(e.name) then return end
  local class = U.ClassName(e.class)
  local who = e.name:match("^[^-]+") .. (class and (" (" .. class .. ")") or "")
  local text = faded and (ns.Locale:Format("shared.stealth.who_spell_faded.bf78ab", { who = who, spell = spell }))
    or (ns.Locale:Format("shared.stealth.who_used_spell_value4.f03a6c", { who = who, spell = spell, value4 = (nearby and ns.Locale:Get("shared.stealth.nearby.22c34d") or "") }))
  local sound = faded and S.ExitSound or S.EnterSound
  if U.Notify then U.Notify("stealth", e.name .. (faded and ":faded" or ""), text, sound)
  else
    U.Say(text, "warning")
    if sound and Core.On("sound") then sound() end
  end
end

-- Two records per enemy take turns, so each new hiding is a new e.hidden
-- (Nearby redraws on a change of record) without a table per cast.
function S.Hid(e, spellId, nearby)
  local spell = S.spells[U.value(spellId) or 0]
  if not (spell and e) then return end
  local now = GetTime()
  local quiet = e.hidden and now - e.hidden.at < S.REPEAT
  local name = S.Name(U.value(spellId))
  local h = e.hiddenSpare or {}
  e.hiddenSpare = e.hidden
  h.spell, h.id, h.at, h.checked, h.checkedAt = name, spellId, now, nil, nil
  e.hidden = h
  if not quiet then Notify(e, name, false, nearby) end
end

-- Read only public aura data. An unreadable result cannot confirm that a
-- hiding aura is absent; a visible enemy may still be stealthed.
local function AuraSpell(unit)
  local get = unit and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if not get then return nil, true end
  local readable = true
  for i = 1, 40 do
    local ok, aura = pcall(get, unit, i, "HELPFUL")
    if not ok then return nil, false end
    if U.secret(aura) then readable = false
    elseif not aura then return nil, readable
    elseif U.secret(aura.spellId) then readable = false
    elseif S.spells[aura.spellId or 0] then return aura.spellId, true end
  end
  return nil, false
end

-- A visible stealthed enemy can still have a readable aura. Never infer a
-- fade from an unreadable aura result. Confirmed combat-log removals bypass
-- both this check and the grace period, including an immediate stealth break.
local function StillHidden(unit, hidden)
  local id, readable = AuraSpell(unit)
  if id or not readable then return true end
  local get = unit and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
  if not get then return false end
  local name = U.SpellName(hidden.id) or hidden.spell
  local ok, aura = pcall(get, unit, name, "HELPFUL")
  return not ok or U.secret(aura) or type(aura) == "table"
end

function S.Observe(e, unit, nearby)
  if not e then return end
  local id, readable = AuraSpell(unit)
  if id then
    if not e.hidden then S.Hid(e, id, nearby)
    else e.hidden.id, e.hidden.spell = id, S.Name(id) end
  elseif readable and not ns.Caps.combatLog then
    S.Shown(e, unit, nearby)
  end
end

-- An aura update that removed nothing can't end a stealth seen at the
-- last check. info: UNIT_AURA's update details; unreadable counts as a removal.
local function NothingRemoved(info)
  if type(info) ~= "table" or U.secret(info) then return false end
  local full = info.isFullUpdate
  return type(info.removedAuraInstanceIDs) == "nil" and (type(full) == "nil" or not U.secret(full) and full == false)
end

-- StillHidden reads up to 40 auras: once per frame, and not again for
-- updates that removed nothing.
local function Hiding(unit, h, info)
  local now = GetTime()
  if h.checked and (NothingRemoved(info) or info == nil and h.checkedAt == now) then return true end
  local hidden = StillHidden(unit, h)
  h.checked, h.checkedAt = hidden or nil, now
  return hidden
end

function S.Shown(e, unit, nearby, confirmed, info)
  if not (e and e.hidden) then return end
  if not confirmed and (GetTime() - e.hidden.at < S.GRACE or Hiding(unit, e.hidden, info)) then return end
  local spell = e.hidden.spell
  e.hiddenSpare, e.hidden = e.hidden, nil
  Notify(e, spell, true, nearby)
end

function S.UnitKey(unit)
  return Core.FullUnitName(unit)
end

function S.Hostile(unit)
  return U.read(UnitIsPlayer, unit) and U.read(UnitCanAttack, "player", unit)
end

function S.HostileFlags(flags)
  return type(flags) == "number" and bit.band(flags, 0x40) ~= 0 and bit.band(flags, 0x400) ~= 0
end
