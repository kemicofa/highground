local _, ns = ...
local Core = ns.Core

-- Burst answers (Cata): while an enemy has a big offensive cooldown up, what
-- to do about it. PURGE when your class can remove that buff (read from the
-- buff itself: Magic, stealable, or Enrage for Tranquilizing Shot),
-- otherwise CC. Which cooldowns count and how is set per spell on the Burst
-- markers page (kit `mark` = default), independent of the Cooldown tracking
-- page, which only drives scoring. Drawn by ui/BurstMarks.lua.
Core.BURST_MODES = { "auto", "purge", "cc", "off" }

-- What your class can strip from an enemy: { magic, enrage, steal }.
Core.PURGERS = {
  SHAMAN = { magic = true }, -- Purge
  PRIEST = { magic = true }, -- Dispel Magic
  MAGE = { steal = true }, -- Spellsteal
  HUNTER = { magic = true, enrage = true }, -- Tranquilizing Shot
  WARLOCK = { magic = true, pet = 19505 }, -- Felhunter's Devour Magic
}

function Core.BurstMode(kit)
  local saved = Core.db and Core.db.burstModes and Core.db.burstModes[kit[1]]
  return saved or kit.mark or "off"
end

function Core.CanStrip(b)
  local p = Core.PURGERS[Core.me.class]
  if not p then return false end
  if p.pet then
    local ok, known = pcall(IsSpellKnown, p.pet, true)
    if not (ok and known) then return false end
  end
  if p.steal then return b.steal == true or (b.steal == nil and b.dispel == "Magic") end
  return (p.magic and b.dispel == "Magic") or (p.enrage and b.dispel == "Enrage") or false
end

-- The answer for this enemy right now: "purge" / "cc" and the burst it is
-- for, or nil. A purge beats a CC; no CC call on someone already controlled.
function Core.BurstAnswer(e)
  if e.dead or not e.bursts or not Core.On("burstMarks") then return nil end
  local cc
  for _, b in ipairs(e.bursts) do
    local mode = Core.BurstMode(b.kit)
    if mode ~= "off" then
      if mode ~= "cc" and Core.CanStrip(b) then return "purge", b end
      if (mode == "auto" or mode == "cc") and not cc then cc = b end
    end
  end
  if cc and not (e.immune or e.cc or e.stun or e.crowdControlled) then return "cc", cc end
end

---------------------------------------------------------------------------
-- Diagnosis (WarboardDB.burstDiag, newest first): every burst buff the
-- combat log sees land on an enemy, and what the marker made of it.
---------------------------------------------------------------------------
function Core.NoteBurst(dstName, spellId)
  local kit = Core.kitBySpell[spellId]
  local e = kit and kit[3] == "burst" and Core.enemies[Core.Canon(dstName) or ""]
  if not e then return end
  local list = Core.db.burstDiag or {}
  Core.db.burstDiag = list
  table.insert(list, 1, { t = date("%H:%M:%S"), who = dstName, spell = spellId, name = kit[4],
    mode = kit.mark and Core.BurstMode(kit) or "no buff", key = e.key, nameplate = e.plateUnit })
  while #list > 20 do table.remove(list) end
end

-- Fill in, for recent entries on e, whether the buff was read and the
-- answer (Core.BurstAnswer) it got.
function Core.NoteBurstSeen(e, answer, b)
  local list = Core.db and Core.db.burstDiag
  if not (list and e.bursts) then return end
  for i = 1, math.min(5, #list) do
    local d = list[i]
    if d.key == e.key and not d.answer then
      for _, seen in ipairs(e.bursts) do
        if seen.kit[1] == (Core.kitBySpell[d.spell] or {})[1] then
          d.read, d.dispel, d.steal = true, seen.dispel or "none", seen.steal
          d.nameplate = d.nameplate or e.plateUnit
        end
      end
      if answer and b and Core.kitBySpell[d.spell] == b.kit then d.answer = answer end
    end
  end
end
