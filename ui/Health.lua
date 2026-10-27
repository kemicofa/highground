local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme

-- Health is secret for enemies: values go straight into the StatusBar, never
-- compared. Primary: UnitHealthPercent (0..1, no curve dependency). Fallback:
-- UnitHealth / UnitHealthMax as the bar range (both may be secret; BGE does
-- the same). Failures are counted in WarboardDB.liveStats.health and the
-- first error text kept in WarboardDB.healthErr.
-- Health percentage (Cata only: retail health is secret). Bright while in
-- view, grey from the last reading, red under the execute threshold.
function Core.UpdateHealthText(r, e)
  local pct = ns.Caps.enemyStats and Core.ShowsElement("healthText") and not e.dead and (e.testHp or e.hpPct)
  if type(pct) ~= "number" then
    r.hpText:Hide()
    return
  end
  r.hpText:SetText(string.format("%d%%", math.floor(pct * 100 + 0.5)))
  if pct <= Core.db.executePct then
    Theme.Paint(r.hpText, "kill")
  elseif e.unit or e.testHp then
    Theme.Paint(r.hpText, "text")
  else
    Theme.Paint(r.hpText, "textMuted")
  end
  r.hpText:Show()
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

function Core.UpdateHealth(r, unit, color, testPct)
  if testPct then
    -- /wb test: a fixed, readable value.
    if r.hpMode ~= "pct" then
      r.hp:SetMinMaxValues(0, 1)
      r.hpMode = "pct"
    end
    r.hp:SetValue(testPct)
    r.hp:SetStatusBarColor(color.r, color.g, color.b, r.fillMode and 0.5 or 0.9)
    r.exec:SetAlpha(testPct > 0 and testPct <= Core.db.executePct and 1 or 0)
    return
  end
  if not unit then
    -- Unknown health: full, faded bar.
    if r.hpMode ~= "pct" then
      r.hp:SetMinMaxValues(0, 1)
      r.hpMode = "pct"
    end
    r.hp:SetValue(1)
    r.hp:SetStatusBarColor(color.r, color.g, color.b, r.fillMode and 0.12 or 0.28)
    r.exec:SetAlpha(0)
    return
  end
  r.hp:SetStatusBarColor(color.r, color.g, color.b, r.fillMode and 0.5 or 0.9)

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
    local okH, hp = pcall(UnitHealth, unit)
    local okM, maxHp = pcall(UnitHealthMax, unit)
    if okH and okM and type(hp) ~= "nil" and type(maxHp) ~= "nil" then
      local okSet, err = pcall(function()
        r.hp:SetMinMaxValues(0, maxHp)
        r.hp:SetValue(hp)
      end)
      r.hpMode = "abs"
      Core.Stat("health", okSet and "abs" or "absFail")
      if not okSet then
        Core.NoteHealthErr(err)
      end
    else
      Core.Stat("health", "noData")
    end
  end

  if Core.execCurve then
    local ok2, col = pcall(UnitHealthPercent, unit, true, Core.execCurve)
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
    if okH and okM and Core.plain(cur) and Core.plain(mx) and mx > 0 then
      r.exec:SetAlpha(cur / mx <= Core.db.executePct and 1 or 0)
    end
  end
end
