local _, ns = ...
local Core = ns.Core

-- Burst markers (Cata): while an enemy has a big offensive cooldown up, its
-- icon sits beside their nameplate with what to do about it: PURGE when your
-- class can remove that buff (read from the buff itself: Magic, stealable,
-- or Enrage for Tranquilizing Shot), otherwise CC. Which cooldowns show and
-- how is set per spell on the Burst markers page (kit `mark` = default),
-- independent of the Cooldown tracking page, which only drives scoring.
-- Like the healer cross, each marker is our own UIParent child anchored to
-- the plate; it sits to the LEFT so it never stacks with the cross or the
-- capture bar.
Core.burstMarks = {} -- pool
Core.BURST_MODES = { "auto", "purge", "cc", "off" }
Core.BURST_ANSWER = {
  purge = { "PURGE", 0.3, 0.85, 1 },
  cc = { "CC", 1, 0.32, 0.35 },
}
local SIZE, BORDER = 38, 3

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

-- Diagnosis (WarboardDB.burstDiag, newest first): every burst buff the
-- combat log sees land on an enemy, and what the marker made of it.
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

-- Fill in, for recent entries, whether the buff was read and what it showed.
local function DiagSeen(e, answer, b)
  for i = 1, math.min(5, #(Core.db.burstDiag or {})) do
    local d = Core.db.burstDiag[i]
    if d.key == e.key and not d.answer then
      for _, seen in ipairs(e.bursts or {}) do
        if seen.kit[1] == (Core.kitBySpell[d.spell] or {})[1] then
          d.read, d.dispel, d.steal = true, seen.dispel or "none", seen.steal
          d.nameplate = d.nameplate or e.plateUnit
        end
      end
      if answer and b and Core.kitBySpell[d.spell] == b.kit then d.answer = answer end
    end
  end
end

local function NewMark()
  local m = CreateFrame("Frame", nil, UIParent)
  m:SetSize(SIZE + BORDER * 2, SIZE + BORDER * 2)
  m:SetFrameStrata("HIGH")
  m:EnableMouse(false)
  m.border = m:CreateTexture(nil, "BACKGROUND")
  m.border:SetAllPoints()
  m.icon = m:CreateTexture(nil, "ARTWORK")
  m.icon:SetPoint("TOPLEFT", BORDER, -BORDER)
  m.icon:SetPoint("BOTTOMRIGHT", -BORDER, BORDER)
  m.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  m.text = m:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  m.text:SetPoint("TOP", m, "BOTTOM", 0, -1)
  m.pulse = Core.Bounce(m, 1, 0.6, 0.6)
  m:Hide()
  return m
end

-- /wb burst test: a sample marker on your target's nameplate.
Core.burstTest = false
local SAMPLE = { spell = 77801 } -- Demon Soul
local testDriver = CreateFrame("Frame")
testDriver:Hide()
local sinceTest = 0
testDriver:SetScript("OnUpdate", function(_, elapsed)
  sinceTest = sinceTest + elapsed
  if sinceTest < 0.1 then return end
  sinceTest = 0
  Core.Guard("burstmarks", Core.UpdateBurstMarks)
end)

function Core.SetBurstTest(on)
  Core.burstTest = on
  local okT, icon = pcall(GetSpellTexture, SAMPLE.spell)
  SAMPLE.icon = okT and icon or 134400 -- question mark
  testDriver:SetShown(on)
  Core.Guard("burstmarks", Core.UpdateBurstMarks)
end

function Core.UpdateBurstMarks()
  local used = 0
  local on = Core.On("burstMarks") and C_NamePlate and C_NamePlate.GetNamePlateForUnit
  local list = on and Core.enemies or {}
  if on and Core.burstTest then
    local okP, plateTarget = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    list = okP and plateTarget and { { key = "test", plateUnit = "target", test = true } } or {}
  end
  for _, e in pairs(list) do
    local answer, b
    if e.test then
      answer, b = "cc", SAMPLE
    elseif e.plateUnit then
      answer, b = Core.BurstAnswer(e)
    end
    if not e.test and e.bursts and Core.db.burstDiag then DiagSeen(e, answer, b) end
    local plate = answer and C_NamePlate.GetNamePlateForUnit(e.plateUnit)
    if plate and not (plate.IsForbidden and plate:IsForbidden()) then
      used = used + 1
      local m = Core.burstMarks[used] or NewMark()
      Core.burstMarks[used] = m
      if m.anchor ~= plate then
        m:ClearAllPoints()
        m:SetPoint("RIGHT", plate, "LEFT", -4, 0)
        m.anchor = plate
      end
      local look = Core.BURST_ANSWER[answer]
      m.border:SetColorTexture(look[2], look[3], look[4], 1)
      m.text:SetText(look[1])
      m.text:SetTextColor(look[2], look[3], look[4])
      m.icon:SetTexture(b.icon)
      m.key, m.answer, m.spell = e.key, answer, b.spell
      if not m:IsShown() then
        m:Show()
        m.pulse:Play()
      end
    end
  end
  for i = used + 1, #Core.burstMarks do
    local m = Core.burstMarks[i]
    m.anchor, m.key, m.answer, m.spell = nil, nil, nil, nil
    if m:IsShown() then
      m.pulse:Stop()
      m:Hide()
    end
  end
end
