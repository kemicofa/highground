local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme
local Paint = Theme.Paint

-- PvP trinket (Cata cooldown tracking): bright when ready (or never seen
-- used), grey with the seconds until it is back while on cooldown.
function Core.RenderTrinket(r, e)
  local entry = ns.KitCommon and ns.KitCommon[1]
  if not (entry and Core.db.cooldowns ~= false and ns.CooldownTracked(Core.db, entry[1]) and Core.ShowsElement("trinket")) then
    r.trinket:Hide()
    r.trinketText:Hide()
    return
  end
  local left = Core.CdLeft(e, entry)
  r.trinket:Show()
  r.trinket:SetDesaturated(left ~= nil)
  Theme.Tint(r.trinket, left and "textMuted" or "white")
  if left then
    r.trinketText:SetText(math.ceil(left))
    r.trinketText:Show()
  else
    r.trinketText:Hide()
  end
end

-- Any time: refresh each row's visuals from its bound enemy. Rank numbers
-- follow priority independently of display order and combat bindings.
-- One reused values table per row message.
local CAP, ORB, FLAG = {}, {}, {}
local function Fill(t, a, x, b, y)
  t[a] = x
  if b then t[b] = y end
  return t
end
local MARKERS = {}
for i = 1, 8 do MARKERS[i] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. i end
local rankOf = {}
local header = {} -- inputs of the subtitle text last written
-- A language change rewrites the subtitle on the next render.
ns.Localization.Watch(header, function() header.error = nil end)
local ownTarget = {} -- the scope's entry while the priority panel is off
function Core.Render()
  wipe(rankOf)
  local topLive = -math.huge
  local recommended, recommendedGo = Core.PickHeroTarget()
  local firstAlive = Core.killNow
  local leader
  for i, e in ipairs(Core.order) do
    rankOf[e] = i
    if not e.dead then
      leader = leader or e
      if Core.Eligible(e) and e.live > topLive then
        topLive = e.live
      end
    end
  end
  local inCombat = InCombatLockdown()
  local needsLayout = false
  local targetKey = UnitExists("target") and Core.CanonUnit("target") or nil
  local focusKey = UnitExists("focus") and Core.CanonUnit("focus") or nil
  local reach = Core.Reach()
  local now = GetTime()
  for i = 1, Core.MAX_ROWS do
    local r = Core.rows[i]
    local e = r.entry
    local wanted = i <= Core.db.rows and Core.displayOrder[i] or nil
    if e ~= wanted then needsLayout = true end
    if e and not Core.enemies[e.key] then
      e = nil
    end
    if e then
      local rank = rankOf[e]
      local isTop = e == firstAlive
      local classColor = ns.Util.ClassColor(e.class)
      local color = e.dead and Core.GREY or classColor or Core.GREY
      ns.Hud.PaintEnemy(r.classBg, classColor and color)

      -- Priority rank: accent on the kill target, flash on a rank change.
      r.rank:SetText(rank or "")
      if isTop then
        Paint(r.tile, "accent")
        Paint(r.rank, "onAccent")
      elseif e.dead then
        Paint(r.tile, "border")
        Paint(r.rank, "textMuted")
      else
        Paint(r.tile, "surface")
        Paint(r.rank, "textMuted")
      end
      if rank and e.shownRank and rank ~= e.shownRank then
        if rank < e.shownRank then
          Paint(r.tileFlash, "success")
        else
          Paint(r.tileFlash, "danger")
        end
        r.tileFlashAnim:Stop()
        r.tileFlashAnim:Play()
      end
      e.shownRank = rank
      r.top:SetShown(isTop)
      r.topTint:SetShown(isTop)

      Core.ClassPaint(r.strip, color)
      local si = e.specID and Core.specInfo[e.specID]
      if si and si.icon then
        r.icon:SetTexture(si.icon)
        r.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
      elseif not ns.Kit.ClassIcon(r.icon, e.class) then
        r.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        r.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
      end
      r.icon:SetShown(Core.ShowsElement("icon"))
      r.icon:SetDesaturated(e.dead)

      r.name:SetText(Core.ShortName(e))
      Paint(r.name, "text", not e.unit and 0.6 or nil)
      if ns.Bounty then ns.Bounty.MarkRow(r, not Core.testMode and e.key or nil) end

      -- Spec tag, tinted by matchup: green = good for you, red = bad.
      local edge = e.edge or 0
      if edge > 0.05 then
        Paint(r.spec, "success")
      elseif edge < -0.05 then
        Paint(r.spec, "danger")
      else
        Paint(r.spec, "textMuted")
      end
      local cap = not e.dead and Core.Capping(e)
      if cap then
        Paint(r.spec, "pending")
        r.spec:SetText(ns.Locale:Format("highground.render.cap_value1_value2.fa74a0", Fill(CAP, "value1", string.format("%s", cap.est and "~" or ""), "value2", string.format("%.1f", math.max(0, cap.finish - now)))))
      elseif e.carrier or e.testStacks then
        local stacks = Core.CarrierStacks(e)
        Paint(r.spec, "chipCarrier")
        r.spec:SetText(Core.obj.mode == "orb" and ns.Locale:Format("highground.render.orb_value1.c2d0ce", Fill(ORB, "value1", string.format("%d", stacks or 30)))
          or (stacks and ns.Locale:Format("highground.hero.flag_x_stacks.037f27", Fill(FLAG, "stacks", string.format("%d", stacks))) or ns.Locale:Get("highground.render.flag.aaabc0")))
      elseif e.specID then
        local p = ns.Specs[e.specID]
        r.spec:SetText(ns.SpecLabel(e, (p and p.short) or Core.SPEC_SHORT[e.specID] or (si and si.name:upper()) or ""))
      elseif not (type(e.specLive) == "string" and pcall(r.spec.SetText, r.spec, e.specLive)) then
        -- Live spec is secret mid-match: the game can draw it, we can't read it.
        r.spec:SetText("?")
      end

      Core.UpdateHealth(r, not e.dead and e.unit or nil, e.dead and color or Core.BarColor(color, nil, e.testHp or e.hpPct),
        not e.dead and e.testHp or nil)
      Core.UpdateHealthText(r, e)
      Core.UpdateMana(r, e)
      if cap and cap.finish > cap.start then
        r.cast:SetMinMaxValues(cap.start, cap.finish)
        r.cast:SetValue(now)
        r.cast:SetStatusBarColor(Theme.Color("pending", cap.est and 0.5 or 1))
        r.cast:Show()
      elseif e.cast and not e.dead and e.cast.finish > e.cast.start then
        r.cast:SetMinMaxValues(e.cast.start, e.cast.finish)
        r.cast:SetValue(e.cast.channel and (e.cast.finish - (now - e.cast.start)) or now)
        if e.cast.kickable then
          r.cast:SetStatusBarColor(Theme.Color("warning", 1))
        else
          r.cast:SetStatusBarColor(Theme.Color("textMuted", 1))
        end
        r.cast:Show()
      else
        r.cast:Hide()
      end

      -- Yards: white within reach, muted beyond, "--" unseen.
      r.rangeDot:SetAlpha(0)
      if e.yards then
        r.dist:SetText(e.yards)
        if Core.InReach(e) then
          Paint(r.dist, "text")
        else
          Paint(r.dist, "textMuted")
        end
      elseif e.rangeRaw ~= nil and Core.issecret(e.rangeRaw) and r.rangeDot.SetAlphaFromBoolean then
        r.dist:SetText("")
        pcall(r.rangeDot.SetAlphaFromBoolean, r.rangeDot, e.rangeRaw, 1, 0)
      elseif e.plateUnit then
        ns.Localization.Bind(r.dist, "highground.render.far.dca1e7")
        Paint(r.dist, "textDim")
      else
        r.dist:SetText("--")
        Paint(r.dist, "textDim")
      end

      -- Tactical state: dead, the kill target now, or the priority leader.
      if e.dead then
        ns.Localization.Bind(r.gap, "highground.render.dead.9d6c23")
        Paint(r.gap, "danger")
      elseif isTop then
        ns.Localization.Bind(r.gap, "highground.render.now.9841c4")
        Paint(r.gap, "accent")
      elseif e == leader then
        ns.Localization.Bind(r.gap, "highground.render.top.b48813")
        Paint(r.gap, "text")
      else
        r.gap:SetText("")
      end

      local pip = Core.ShowsElement("status") and Core.StatusPip(e)
      if pip then
        Theme.Tint(r.pip, "chipBg")
        r.pipText:SetText(pip == Core.PIP.carrier and Core.obj.mode == "orb" and ns.Locale:Get("highground.render.orb.97a4d7") or pip[1])
        Paint(r.pipText, pip[5])
        r.pip:Show()
        r.pipText:Show()
      else
        r.pip:Hide()
        r.pipText:Hide()
      end

      if e.marker and MARKERS[e.marker] then
        r.marker:SetTexture(MARKERS[e.marker])
        r.marker:Show()
      else
        r.marker:Hide()
      end
      Core.RenderTrinket(r, e)
      local allies = e.allyCount or 0
      r.allyText:SetText(allies > 0 and ("x" .. allies) or "")
      Paint(r.allyText, allies >= 3 and "pending" or "text")
      if e.onMe then
        r.eye:SetAlpha(1)
      elseif e.onMeRaw ~= nil and Core.issecret(e.onMeRaw) and r.eye.SetAlphaFromBoolean then
        pcall(r.eye.SetAlphaFromBoolean, r.eye, e.onMeRaw, 1, 0)
      else
        r.eye:SetAlpha(0)
      end

      -- GO = best LIVE target right now (within a small margin) whose
      -- defensive just faded, and who is within your reach.
      local go = Core.IsGo(e, topLive, now)
      if go ~= r.go then
        r.go = go
        r.goGlow:SetShown(go)
        if go then
          r.goFillAnim:Play()
          r.goGlowAnim:Play()
          r.goPop:Play()
        else
          r.goFillAnim:Stop()
          r.goGlowAnim:Stop()
          r.goFill:SetAlpha(0)
        end
      end
      -- One sound per kill window (per defensive spent).
      if go and e.goAlertedFor ~= e.burnedAt then
        e.goAlertedFor = e.burnedAt
        if Core.On("sound") and Core.PriorityOn() then
          Core.PlayGoSound()
        end
      end

      local isTarget = targetKey ~= nil and e.key == targetKey
      local isFocus = focusKey ~= nil and e.key == focusKey
      r.focusEdge:SetShown(isFocus)
      r.marks:SetText(isTarget and (isFocus and ns.Locale:Get("highground.render.t_f.f13775") or ns.Locale:Get("highground.render.tgt.e2afb7")) or isFocus and ns.Locale:Get("highground.render.foc.a6c566") or "")
      Paint(r.marks, isTop and "onAccent" or isFocus and not isTarget and "focus" or "text")
      if isTarget ~= r.isTarget then
        r.isTarget = isTarget
        r.sel:SetShown(isTarget)
        r.arrow:SetShown(isTarget)
      end

      -- Dead, defensive up or CC'd: don't commit -> dim the row.
      local dim = (e.dead and 0.4) or ((e.def or e.cc or e.immune) and 0.7) or 1
      r.content:SetAlpha(dim)
      r.hp:SetAlpha(dim)
      Core.SetSurfaceAlpha(r.classBg, dim)
    elseif r.entry then
      needsLayout = true
      r.content:SetAlpha(0.2)
      r.hp:SetAlpha(0.2)
      Core.SetSurfaceAlpha(r.classBg, 0.2)
    end
    if not e and r.go then
      r.go = false
      r.goGlow:Hide()
      r.goFillAnim:Stop()
      r.goGlowAnim:Stop()
      r.goFill:SetAlpha(0)
    end
    if not e and r.isTarget then
      r.isTarget = false
      r.sel:Hide()
      r.arrow:Hide()
    end
    if not e then
      r.focusEdge:Hide()
      r.marks:SetText("")
    end
  end
  -- Enemies added below the bound rows keep every rank in place, so also
  -- relayout when fewer rows are bound than there are enemies to show.
  local bound = 0
  for i = 1, Core.MAX_ROWS do
    if Core.rows[i].entry then bound = bound + 1 end
  end
  if bound ~= math.min(#Core.order, Core.db.rows, Core.MAX_ROWS) then
    needsLayout = true
  end
  if needsLayout and not inCombat then
    Core.Layout()
    return Core.Render()
  end
  Core.lockIcon:SetShown(inCombat and needsLayout)
  Core.callEntry = recommended
  if Core.guidedTest then
    Core.sniper:Hide()
  elseif Core.sniperTest.on then
    -- the test driver owns the scope
  elseif not Core.PriorityOn() then
    local unit = Core.TargetPlateUnit(true)
    ownTarget.plateUnit, ownTarget.key = unit, unit and Core.CanonUnit("target")
    Core.UpdateSniper(unit and ownTarget or nil)
  else
    Core.UpdateSniper(recommended, recommendedGo)
  end
  Core.UpdateHero(recommended, recommendedGo)
  Core.RefreshTooltip()

  -- Header: live dot while there's a roster; map tag + count on the right.
  local hasRoster = #Core.order > 0
  Core.liveDot:SetShown(hasRoster and not Core.Frameless())
  Core.liveText:SetShown(hasRoster)
  Core.liveText:SetText(Core.testMode and ns.Locale:Get("highground.render.test.984816") or ns.Locale:Get("highground.panel.live.6990f0"))
  if hasRoster and not Core.liveDotAnim:IsPlaying() then
    Core.liveDotAnim:Play()
  elseif not hasRoster then
    Core.liveDotAnim:Stop()
  end
  -- An error notice owns the subtitle (Core.Tick); otherwise rebuild the
  -- text only when the battleground, Blitz, row counts or status change.
  if Core.lastError then
    header.error = true
    return
  end
  local label, blitz, total, status = Core.currentProfile and Core.currentProfile.label, Core.isBlitz == true,
    #Core.order, Core.rosterStatus
  if header.error ~= false or header.label ~= label or header.blitz ~= blitz or header.bound ~= bound
    or header.total ~= total or header.status ~= status then
    header.error, header.label, header.blitz, header.bound, header.total, header.status =
      false, label, blitz, bound, total, status
    local tag = label and (label:upper() .. (blitz and ns.Locale:Get("highground.render.blitz.8994ea") or "") .. "  \194\183  ") or ""
    local count = bound < total and (bound .. "/" .. total) or tostring(total)
    Core.subtitle:SetText(hasRoster and (tag .. count) or (status or ns.Locale:Get("highground.render.waiting_for_enemies.2f88ce")))
  end
end
