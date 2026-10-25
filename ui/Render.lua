local _, ns = ...
local Core = ns.Core

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
  r.trinket:SetVertexColor(left and 0.55 or 1, left and 0.55 or 1, left and 0.55 or 1)
  if left then
    r.trinketText:SetText(math.ceil(left))
    r.trinketText:SetTextColor(1, 0.85, 0.3)
    r.trinketText:Show()
  else
    r.trinketText:Hide()
  end
end

-- Any time: refresh each row's visuals from its bound enemy. Rank numbers
-- follow the live order even when rows can't move (combat).
local rankOf = {}
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
  local reach = Core.Reach()
  local now = GetTime()
  for i = 1, Core.MAX_ROWS do
    local r = Core.rows[i]
    local e = r.entry
    if e and not Core.enemies[e.key] then
      e = nil
    end
    if e then
      local rank = rankOf[e]
      if rank ~= i then
        needsLayout = true
      end
      local isTop = e == firstAlive
      local color = e.dead and Core.GREY or ns.Util.ClassColor(e.class) or Core.GREY

      -- Position tile: number, accent on the kill target, flash on a move.
      r.rank:SetText(rank or "")
      if isTop then
        r.tile:SetColorTexture(Core.ACCENT[1], Core.ACCENT[2], Core.ACCENT[3], 1)
        r.rank:SetTextColor(0.05, 0.05, 0.06)
      elseif e.dead then
        r.tile:SetColorTexture(0.22, 0.22, 0.26, 1)
        r.rank:SetTextColor(0.6, 0.6, 0.65)
      else
        r.tile:SetColorTexture(unpack(Core.THEME.colors.surface))
        r.rank:SetTextColor(unpack(Core.MUTED))
      end
      if rank and e.shownRank and rank ~= e.shownRank then
        if rank < e.shownRank then
          r.tileFlash:SetColorTexture(0.25, 0.9, 0.45, 1)
        else
          r.tileFlash:SetColorTexture(1, 0.25, 0.25, 1)
        end
        r.tileFlashAnim:Stop()
        r.tileFlashAnim:Play()
      end
      e.shownRank = rank
      r.top:SetShown(isTop)
      r.topTint:SetShown(isTop)

      r.strip:SetColorTexture(color.r, color.g, color.b, 1)
      local si = e.specID and Core.specInfo[e.specID]
      if si and si.icon then
        r.icon:SetTexture(si.icon)
        r.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
      else
        -- Cata's SetAtlas can fail silently on a missing atlas, leaving the
        -- recycled row showing the previous enemy's icon: always draw something.
        local atlas = "classicon-" .. e.class:lower()
        local hasAtlas = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
        local tc = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[e.class]
        if not (hasAtlas and pcall(r.icon.SetAtlas, r.icon, atlas)) then
          if tc then
            r.icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            r.icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
          else
            r.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            r.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
          end
        end
      end
      r.icon:SetDesaturated(e.dead)

      r.name:SetText(e.display:match("^[^-]+"))
      r.name:SetTextColor(0.96, 0.96, 0.97, e.unit and 1 or 0.6)

      -- Spec tag, tinted by matchup: green = good for you, red = bad.
      local edge = e.edge or 0
      if edge > 0.05 then
        r.spec:SetTextColor(0.45, 0.9, 0.55)
      elseif edge < -0.05 then
        r.spec:SetTextColor(1, 0.45, 0.45)
      else
        r.spec:SetTextColor(Core.MUTED[1], Core.MUTED[2], Core.MUTED[3])
      end
      local cap = not e.dead and Core.Capping(e)
      if cap then
        r.spec:SetTextColor(1, 0.55, 0.1)
        r.spec:SetText(string.format("CAP %s%.1f", cap.est and "~" or "", math.max(0, cap.finish - now)))
      elseif e.carrier or e.testStacks then
        local stacks = Core.CarrierStacks(e)
        r.spec:SetTextColor(Core.PIP.carrier[2], Core.PIP.carrier[3], Core.PIP.carrier[4])
        r.spec:SetText(Core.obj.mode == "orb" and string.format("ORB %d%%", stacks or 30)
          or (stacks and string.format("FLAG x%d", stacks) or "FLAG"))
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
        r.cast:SetStatusBarColor(1, 0.55, 0.1, cap.est and 0.5 or 1)
        r.cast:Show()
      elseif e.cast and not e.dead and e.cast.finish > e.cast.start then
        r.cast:SetMinMaxValues(e.cast.start, e.cast.finish)
        r.cast:SetValue(e.cast.channel and (e.cast.finish - (now - e.cast.start)) or now)
        if e.cast.kickable then
          r.cast:SetStatusBarColor(1, 0.78, 0.2, 1)
        else
          r.cast:SetStatusBarColor(0.55, 0.56, 0.62, 1)
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
          r.dist:SetTextColor(0.96, 0.96, 0.97)
        else
          r.dist:SetTextColor(Core.MUTED[1], Core.MUTED[2], Core.MUTED[3])
        end
      elseif e.rangeRaw ~= nil and Core.issecret(e.rangeRaw) and r.rangeDot.SetAlphaFromBoolean then
        r.dist:SetText("")
        pcall(r.rangeDot.SetAlphaFromBoolean, r.rangeDot, e.rangeRaw, 1, 0)
      elseif e.plateUnit then
        r.dist:SetText("FAR")
        r.dist:SetTextColor(0.4, 0.41, 0.46)
      else
        r.dist:SetText("--")
        r.dist:SetTextColor(0.3, 0.31, 0.35)
      end

      -- Tactical state: dead, the kill target now, or the priority leader.
      if e.dead then
        r.gap:SetText("DEAD")
        r.gap:SetTextColor(0.75, 0.3, 0.3)
      elseif isTop then
        r.gap:SetText("NOW")
        r.gap:SetTextColor(Core.ACCENT[1], Core.ACCENT[2], Core.ACCENT[3])
      elseif e == leader then
        r.gap:SetText("PRIO")
        r.gap:SetTextColor(0.96, 0.96, 0.97)
      else
        r.gap:SetText("")
      end

      local pip = Core.ShowsElement("status") and Core.StatusPip(e)
      if pip then
        r.pip:SetVertexColor(pip[2], pip[3], pip[4], 0.18)
        r.pipText:SetText(pip == Core.PIP.carrier and Core.obj.mode == "orb" and "ORB" or pip[1])
        r.pipText:SetTextColor(pip[2], pip[3], pip[4])
        r.pip:Show()
        r.pipText:Show()
      else
        r.pip:Hide()
        r.pipText:Hide()
      end

      if e.marker then
        r.marker:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. e.marker)
        r.marker:Show()
      else
        r.marker:Hide()
      end
      Core.RenderTrinket(r, e)
      local allies = e.allyCount or 0
      r.allyText:SetText(allies > 0 and ("x" .. allies) or "")
      r.allyText:SetTextColor(1, allies >= 3 and 0.55 or 0.85, allies >= 3 and 0.2 or 0.85)
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
      if isTarget ~= r.isTarget then
        r.isTarget = isTarget
        r.sel:SetShown(isTarget)
        r.arrow:SetShown(isTarget)
      end

      -- Dead, defensive up or CC'd: don't commit -> dim the row.
      local dim = (e.dead and 0.4) or ((e.def or e.cc or e.immune) and 0.7) or 1
      r.content:SetAlpha(dim)
      r.hp:SetAlpha(dim)
    elseif r.entry then
      needsLayout = true
      r.content:SetAlpha(0.2)
      r.hp:SetAlpha(0.2)
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
  if Core.sniperTest.on then
    -- the test driver owns the scope
  elseif not Core.PriorityOn() then
    local unit = Core.TargetPlateUnit(true)
    Core.UpdateSniper(unit and { plateUnit = unit, key = Core.CanonUnit("target") } or nil)
  else
    Core.UpdateSniper(recommended, recommendedGo)
  end
  Core.UpdateHero(recommended, recommendedGo)
  Core.RefreshTooltip()

  -- Header: live dot while there's a roster; map tag + count on the right.
  local hasRoster = #Core.order > 0
  Core.liveDot:SetShown(hasRoster and not Core.Frameless())
  Core.liveText:SetShown(hasRoster)
  Core.liveText:SetText(Core.testMode and "TEST" or "LIVE")
  if hasRoster and not Core.liveDotAnim:IsPlaying() then
    Core.liveDotAnim:Play()
  elseif not hasRoster then
    Core.liveDotAnim:Stop()
  end
  local tag = Core.currentProfile and (Core.currentProfile.label:upper() .. (Core.isBlitz and "  \194\183  BLITZ" or "") .. "  \194\183  ")
    or ""
  Core.subtitle:SetText(hasRoster and (tag .. #Core.order) or (Core.rosterStatus or "waiting..."))
end
