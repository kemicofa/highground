local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme

-- The card's primary name describes its secure click. Combat recommendations
-- continue updating in the note, enemy rows and nameplate scope.
function Core.UpdateHero(e, isGo)
  local pinned = Core.heroBtn.boundKey
  local clickPinned = InCombatLockdown() and pinned ~= (e and e.key)
  if clickPinned then
    Core.hero.clickNote:SetText(e and ("RECOMMENDED: " .. e.display:match("^[^-]+"):upper()) or "NO ELIGIBLE TARGET")
    Core.hero.clickNote:Show()
    e, isGo = pinned and Core.enemies[pinned] or nil, false
  else
    Core.hero.clickNote:Hide()
  end
  local show = e ~= nil
  -- Compact: one line (name, summary, distance); the click note takes the
  -- summary's place.
  local full = not Core.compact
  Core.heroBtn.entry = e
  Core.hero.empty:SetText(clickPinned and "Target click unavailable" or "Watching for an opening")
  Core.hero.emptySub:SetText(clickPinned and "Use enemy rows until combat ends" or "No eligible enemy in observed reach")
  Core.hero.empty:SetShown(not show)
  Core.hero.emptySub:SetShown(not show and full)
  Core.hero.label:SetShown(show and full)
  Core.hero.name:SetShown(show)
  Core.hero.sub:SetShown(show and (full or not clickPinned))
  Core.hero.detail:SetShown(show and full and not clickPinned)
  Core.hero.dist:SetShown(show)
  Core.hero.unitText:SetShown(show)
  Core.hero.hp:SetShown(show)
  for _, t in ipairs(Core.hero.meter) do
    t:SetShown(show and full)
  end
  if not show then
    Theme.Paint(Core.hero.strip, "border")
    Core.hero.exec:SetAlpha(0)
    if Core.hero.isGo then
      Core.hero.isGo = false
      Core.hero.goAnim:Stop()
      Core.hero.labelAnim:Stop()
      Core.hero.goFill:SetAlpha(0)
    end
    return
  end

  local color = ns.Util.ClassColor(e.class) or Core.GREY
  Core.ClassPaint(Core.hero.strip, color)
  Core.hero.name:SetText(e.display:match("^[^-]+"))
  Core.ClassPaint(Core.hero.name, color)

  local summary = { Core.ClassName(e) }
  if e.hpPct then summary[#summary + 1] = string.format("%d%% HP", math.floor(e.hpPct * 100 + 0.5)) end
  if (e.allyCount or 0) > 0 then summary[#summary + 1] = string.format("%d targeting", e.allyCount) end
  Core.hero.sub:SetText(table.concat(summary, "  \194\183  "))
  local bits = {}
  local stacks = Core.CarrierStacks(e)
  if e.carrier or e.testStacks then
    bits[#bits + 1] = Core.obj.mode == "orb" and string.format("ORB +%d%%", stacks or 30)
      or (stacks and string.format("FLAG x%d", stacks) or "FLAG")
  end
  if e.manaPct and Core.IsHealer(e) and e.manaPct * 100 <= Core.P("oomPct") then
    bits[#bits + 1] = string.format("%sOOM %d%%|r", Core.Hex("info"), math.floor(e.manaPct * 100 + 0.5))
  end
  if e.cast then
    bits[#bits + 1] = string.format("%s%s %s|r", Core.Hex("warning"), e.cast.name:upper(), e.cast.kickable and "\194\183 KICK" or "")
  end
  local where = ns.MapWhere and ns.MapWhere(e.key)
  if where and not e.unit then
    bits[#bits + 1] = Core.Hex("info") .. where:upper() .. "|r"
  end
  local down = Core.DownSummary(e, 3)
  if down then
    bits[#bits + 1] = Core.Hex("success") .. down .. "|r"
  end
  if e.onMe then
    bits[#bits + 1] = Core.Hex("danger") .. "on you|r"
  end
  if e.burnedAt and GetTime() - e.burnedAt < Core.O("spentWindow") then
    bits[#bits + 1] = string.format("%sdef spent %ds|r", Core.Hex("success"), math.floor(GetTime() - e.burnedAt))
  end
  Core.hero.detail:SetText(#bits > 0 and table.concat(bits, "  \194\183  ") or "Ready to engage")

  Core.hero.dist:SetText(e.yards or "--")
  local reach = Core.Reach()
  local lit = e.yards and math.max(1, math.min(Core.METER_SEGS,
    Core.METER_SEGS - math.floor((e.yards - 1) / (reach / Core.METER_SEGS)))) or 0
  for s, t in ipairs(Core.hero.meter) do
    Theme.Paint(t, s > lit and "overlaySelected" or isGo and "kill" or "accent")
  end
  Core.UpdateHealth(Core.hero, e.unit, Core.BarColor(color, nil, e.testHp or e.hpPct), e.testHp)

  if isGo then
    Core.hero.label:SetText("GO  \194\183  DEFENSIVE DOWN")
    Theme.Paint(Core.hero.label, "kill")
  else
    Core.hero.label:SetText(clickPinned and "COMBAT TARGET" or "KILL TARGET")
    Theme.Paint(Core.hero.label, "accent")
  end
  if isGo ~= (Core.hero.isGo or false) then
    Core.hero.isGo = isGo
    if isGo then
      Core.hero.goAnim:Play()
      Core.hero.labelAnim:Play()
    else
      Core.hero.goAnim:Stop()
      Core.hero.labelAnim:Stop()
      Core.hero.goFill:SetAlpha(0)
      Core.hero.label:SetAlpha(1)
    end
  end
end
