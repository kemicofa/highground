local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme

-- The card's primary name describes its secure click. Combat recommendations
-- continue updating in the note, enemy rows and nameplate scope.
local summary, bits = {}, {}
-- One reused values table per message: the card renders four times a second.
local HP, ALLIES, ORB, FLAG, MANA, CAST, ONYOU, SPENT, PINNED = {}, {}, {}, {}, {}, {}, {}, {}, {}
local function Fill(t, a, x, b, y, c, z)
  t[a] = x
  if b then t[b] = y end
  if c then t[c] = z end
  return t
end
function Core.UpdateHero(e, isGo)
  local pinned = Core.heroBtn.boundKey
  local clickPinned = InCombatLockdown() and pinned ~= (e and e.key)
  if clickPinned then
    Core.hero.clickNote:SetText(e and (ns.Locale:Format("highground.hero.recommended_value2.896f3f", Fill(PINNED, "value2", ns.Text.Upper(Core.ShortName(e))))) or ns.Locale:Get("highground.hero.no_eligible_target.ba6986"))
    Core.hero.clickNote:Show()
    e, isGo = pinned and Core.enemies[pinned] or nil, false
  else
    Core.hero.clickNote:Hide()
  end
  local show = e ~= nil
  Core.hero.glow:SetColor(isGo and "attackEdge" or "accent")
  Core.hero.glow:SetActive(show, isGo)
  Core.hero.rim:SetColor(show and (isGo and "attackEdge" or "borderAccent") or "border")
  if e and (Core.hero.effectKey ~= e.key or (isGo and not Core.hero.isGo)) then Core.hero.sweep:Play() end
  Core.hero.effectKey = e and e.key
  if not show then Core.hero.sweep:Stop() end
  -- Compact: one line (name, summary, distance); the click note takes the
  -- summary's place.
  local full = not Core.compact
  Core.heroBtn.entry = e
  Core.hero.empty:SetText(clickPinned and ns.Locale:Get("highground.hero.target_click_unavailable.e0c599") or ns.Locale:Get("highground.hero.no_suggested_target.cfc610"))
  Core.hero.emptySub:SetText(clickPinned and ns.Locale:Get("highground.hero.click_an_enemy_row_until_combat_ends.179de0") or ns.Locale:Get("highground.hero.wait_for_an_opening_or_move_closer.bc097c"))
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
    ns.Hud.PaintEnemy(Core.hero.classBg)
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

  local classColor = ns.Util.ClassColor(e.class)
  local color = classColor or Core.GREY
  ns.Hud.PaintEnemy(Core.hero.classBg, classColor)
  Core.ClassPaint(Core.hero.strip, color)
  Core.hero.name:SetText(Core.ShortName(e))
  Core.ClassPaint(Core.hero.name, color)

  wipe(summary); wipe(bits)
  summary[1] = Core.ClassName(e)
  if e.hpPct then summary[#summary + 1] = ns.Locale:Format("highground.hero.value1_hp.d9b092", Fill(HP, "value1", string.format("%d", math.floor(e.hpPct * 100 + 0.5)))) end
  if (e.allyCount or 0) > 0 then summary[#summary + 1] = ns.Locale:Format("highground.hero.e_allycount_targeting.06ff4d", Fill(ALLIES, "e_allyCount", string.format("%d", e.allyCount))) end
  Core.hero.sub:SetText(table.concat(summary, "  \194\183  "))
  local stacks = Core.CarrierStacks(e)
  if e.carrier or e.testStacks then
    bits[#bits + 1] = Core.obj.mode == "orb" and ns.Locale:Format("highground.hero.orb_value1.789117", Fill(ORB, "value1", string.format("%d", stacks or 30)))
      or (stacks and ns.Locale:Format("highground.hero.flag_x_stacks.037f27", Fill(FLAG, "stacks", string.format("%d", stacks))) or "FLAG")
  end
  if e.manaPct and Core.IsHealer(e) and e.manaPct * 100 <= Core.P("oomPct") then
    bits[#bits + 1] = ns.Locale:Format("highground.hero.value1_low_mana_value2_r.4c0bc6", Fill(MANA, "value1", string.format("%s", Core.Hex("info")), "value2", string.format("%d", math.floor(e.manaPct * 100 + 0.5))))
  end
  if e.cast then
    bits[#bits + 1] = ns.Locale:Format("highground.hero.value1_value2_value3_r.a04848", Fill(CAST, "value1", string.format("%s", Core.Hex("warning")), "value2", string.format("%s", ns.Text.Upper(e.cast.name)), "value3", string.format("%s", e.cast.kickable and ns.Locale:Get("highground.hero.interrupt.cf2920") or "")))
  end
  local where = ns.MapWhere and ns.MapWhere(e.key)
  if where and not e.unit then
    bits[#bits + 1] = Core.Hex("info") .. ns.Text.Upper(where) .. "|r"
  end
  local down = Core.DownSummary(e, 3)
  if down then
    bits[#bits + 1] = Core.Hex("success") .. down .. "|r"
  end
  if e.onMe then
    bits[#bits + 1] = ns.Locale:Format("highground.hero.value1_on_you_r.843eff", Fill(ONYOU, "value1", Core.Hex("danger")))
  end
  if e.burnedAt and GetTime() - e.burnedAt < Core.O("spentWindow") then
    bits[#bits + 1] = ns.Locale:Format("highground.hero.value1_protection_ended_value2_s_ago_r.89844e", Fill(SPENT, "value1", string.format("%s", Core.Hex("success")), "value2", string.format("%d", math.floor(GetTime() - e.burnedAt))))
  end
  Core.hero.detail:SetText(#bits > 0 and table.concat(bits, "  \194\183  ") or ns.Locale:Get("highground.hero.ready_to_engage.b36859"))

  Core.hero.dist:SetText(e.yards or "--")
  local reach = Core.Reach()
  local lit = e.yards and math.max(1, math.min(Core.METER_SEGS,
    Core.METER_SEGS - math.floor((e.yards - 1) / (reach / Core.METER_SEGS)))) or 0
  for s, t in ipairs(Core.hero.meter) do
    Theme.Paint(t, s > lit and "overlaySelected" or isGo and "kill" or "accent")
  end
  Core.UpdateHealth(Core.hero, e.unit, Core.BarColor(color, nil, e.testHp or e.hpPct), e.testHp, e)

  if isGo then
    ns.Localization.Bind(Core.hero.label, "highground.hero.attack_protection_ended.fbaaee")
    Theme.Paint(Core.hero.label, "kill")
  else
    Core.hero.label:SetText(clickPinned and ns.Locale:Get("highground.hero.click_target_fixed_in_combat.8b81a6") or ns.Locale:Get("highground.hero.suggested_target.63e353"))
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
