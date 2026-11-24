local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme
local Util = ns.Util

---------------------------------------------------------------------------
-- Health and mana on a board row. Enemy health is secret on retail: values
-- go straight into the StatusBar, never compared. Primary:
-- UnitHealthPercent (0..1). Fallback: UnitHealth / UnitHealthMax as the bar
-- range (both may be secret). Failures are counted in
-- HighgroundDB.liveStats.health; the first error text is kept in
-- HighgroundDB.healthErr.
---------------------------------------------------------------------------

local PERCENT = {} -- "0%".."100%", formatted once
for i = 0, 100 do PERCENT[i] = i .. "%" end

-- The enemy's latest 0-100 reading (core/Units.lua) while in view, or
-- within Target behavior > Keep last seen health after it left.
local function Seen(e)
  if e.dead or type(e.hpSeen) == "nil" then return nil end
  if e.unit or GetTime() - (e.lastSeen or 0) < Core.O("healthMemory") then return e.hpSeen end
end

-- Readable 0-1 health for the Green to red bands: live or sample health,
-- else a plain last seen reading (Cata). nil on the Midnight client, where
-- the curve colour (e.hpTint) does it.
function Core.PlainHealth(e)
  local pct = e.testHp or e.hpPct
  if pct == nil then
    local seen = Seen(e)
    if Util.plain(seen) and type(seen) == "number" then pct = seen / 100 end
  end
  return pct
end

-- Health percentage. Plain on Cata and in previews: red under the execute
-- threshold. Secret on the Midnight client: the text widget formats it,
-- nothing here reads it. Bright while in view, grey from the last reading.
function Core.UpdateHealthText(r, e)
  if not (r.hpText and Core.ShowsElement("healthText")) or e.dead then
    if r.hpText then r.hpText:Hide() end
    return
  end
  local pct = e.testHp or e.hpPct
  if type(pct) == "number" then
    r.hpText:SetText(PERCENT[math.max(0, math.min(100, math.floor(pct * 100 + 0.5)))])
    Theme.Paint(r.hpText, pct <= Core.db.executePct and "kill" or (e.unit or e.testHp) and "text" or "textMuted")
    r.hpText:Show()
    return
  end
  local seen = Seen(e)
  if type(seen) == "nil" or not pcall(r.hpText.SetFormattedText, r.hpText, "%.0f%%", seen) then
    r.hpText:Hide()
    return
  end
  Theme.Paint(r.hpText, e.unit and "text" or "textMuted")
  r.hpText:Show()
end

-- Bar opacity: live, last seen and unknown health. Fill sits behind the row's
-- text; the Bar and Thin line styles are nearly opaque.
local FILL = { "healthFill", "healthStale", "healthUnseen" }
local SOLID = { "healthBar", "healthBarStale", "healthBarUnseen" }
local function Alpha(r, state)
  return Theme.Alpha((r.fillMode and FILL or SOLID)[state])
end

-- Class, faction or custom colour; Green to red from the curve colour read
-- with the health (secret on the Midnight client, never inspected).
local function Paint(r, e, color, alpha)
  local tint = e and e.hpTint
  if type(tint) == "table" and type(e.testHp or e.hpPct) ~= "number" then
    local ok, cr, cg, cb = pcall(tint.GetRGB, tint)
    if ok and pcall(r.hp.SetStatusBarColor, r.hp, cr, cg, cb, alpha) then return end
  end
  r.hp:SetStatusBarColor(color.r, color.g, color.b, alpha)
end

-- Mana bar (Cata: readable for mana users); faded once the reading is
-- older than ten seconds.
function Core.UpdateMana(r, e)
  local pct = Core.ShowsElement("mana") and not e.dead and e.manaPct
  if not pct then
    r.mana:Hide()
    return
  end
  r.mana:SetValue(pct)
  r.mana:SetStatusBarColor(Theme.Color("info", GetTime() - (e.manaAt or 0) < 10 and 0.9 or 0.35))
  r.mana:Show()
end

function Core.NoteHealthErr(err)
  if not Core.db.healthErr then
    Core.db.healthErr = tostring(err)
  end
end

-- Called per row on every render: protected without a closure per call.
local function SetAbsolute(bar, hp, maxHp)
  bar:SetMinMaxValues(0, maxHp)
  bar:SetValue(hp)
end

-- Last seen health (Target behavior: Keep last seen health): the reading
-- from when the enemy was last in view, muted. Secret on the Midnight
-- client, so it only goes into the bar.
local function DrawSeen(r, e, color)
  local seen = e and Seen(e)
  if type(seen) == "nil" then return false end
  if r.hpMode ~= "pct100" then
    r.hp:SetMinMaxValues(0, 100)
    r.hpMode = "pct100"
  end
  if not pcall(r.hp.SetValue, r.hp, seen) then return false end
  Paint(r, e, color, Alpha(r, 2))
  ns.Hud.HealthKnown(r.hp, true, true)
  r.exec:SetAlpha(0)
  return true
end

function Core.UpdateHealth(r, unit, color, testPct, e)
  ns.Hud.HealthKnown(r.hp, not not (unit or testPct))
  if testPct then
    -- /hg bg test: a fixed, readable value.
    if r.hpMode ~= "pct" then
      r.hp:SetMinMaxValues(0, 1)
      r.hpMode = "pct"
    end
    r.hp:SetValue(testPct)
    r.hp:SetStatusBarColor(color.r, color.g, color.b, Alpha(r, 1))
    r.exec:SetAlpha(testPct > 0 and testPct <= Core.db.executePct and 1 or 0)
    return
  end
  if not unit then
    if e and e.dead then
      -- Dead: an empty bar, not unknown health.
      if r.hpMode ~= "pct" then
        r.hp:SetMinMaxValues(0, 1)
        r.hpMode = "pct"
      end
      r.hp:SetValue(0)
      ns.Hud.HealthKnown(r.hp, true)
      r.exec:SetAlpha(0)
      return
    end
    if DrawSeen(r, e, color) then return end
    -- Unknown health: full, faded bar.
    if r.hpMode ~= "pct" then
      r.hp:SetMinMaxValues(0, 1)
      r.hpMode = "pct"
    end
    r.hp:SetValue(1)
    r.hp:SetStatusBarColor(color.r, color.g, color.b, Alpha(r, 3))
    r.exec:SetAlpha(0)
    return
  end
  Paint(r, e, color, Alpha(r, 1))

  -- Cata has no percentage API; use absolute health without recording a fault.
  local ok, pct = true, nil
  if UnitHealthPercent then ok, pct = pcall(UnitHealthPercent, unit, true) end
  local drawn = false
  if ok and type(pct) ~= "nil" then
    if r.hpMode ~= "pct" then
      r.hp:SetMinMaxValues(0, 1)
      r.hpMode = "pct"
    end
    local okSet, err = pcall(r.hp.SetValue, r.hp, pct)
    drawn = okSet
    Core.Stat("health", okSet and "pct" or "pctSetFail")
    if not okSet then
      Core.NoteHealthErr(err)
    end
  else
    Core.Stat("health", "pctFail")
    if not ok then
      Core.NoteHealthErr(pct)
    end
  end
  if not drawn then
    -- Raw values, possibly secret: only type() may look at them.
    local hp, maxHp = Util.call(UnitHealth, unit), Util.call(UnitHealthMax, unit)
    if type(hp) ~= "nil" and type(maxHp) ~= "nil" then
      local okSet, err = pcall(SetAbsolute, r.hp, hp, maxHp)
      drawn = okSet
      r.hpMode = "abs"
      Core.Stat("health", okSet and "abs" or "absFail")
      if not okSet then
        Core.NoteHealthErr(err)
      end
    else
      Core.Stat("health", "noData")
    end
  end

  ns.Hud.HealthKnown(r.hp, drawn)

  if Core.execCurve then
    local col = Util.call(UnitHealthPercent, unit, true, Core.execCurve)
    if type(col) == "table" then
      local okA, _, _, _, a = pcall(col.GetRGBA, col)
      if okA then
        pcall(r.exec.SetAlpha, r.exec, a)
      end
    end
  else
    -- No color curves (Cata): health is plain, compare directly.
    local frac = Util.HealthFraction(unit)
    if frac then
      r.exec:SetAlpha(frac <= Core.db.executePct and 1 or 0)
    end
  end
end
