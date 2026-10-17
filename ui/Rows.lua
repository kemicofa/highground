local _, ns = ...
local Core = ns.Core

function Core.CreateRow(i)
  local r = CreateFrame("Button", "WarboardRow" .. i, Core.frame, "SecureActionButtonTemplate")
  r.wbRow = true
  -- Addon secure buttons count as key presses: with ActionButtonUseKeyDown
  -- (default on) they only act on mouse-down, otherwise on mouse-up. Register
  -- both; SecureActionButton_OnClick runs the action on exactly one of them.
  r:RegisterForClicks("AnyDown", "AnyUp")
  r:SetAttribute("type1", "macro")
  r:SetAttribute("type2", "macro")
  -- Shift+click = call in chat (PostClick) without targeting: an empty macro.
  r:SetAttribute("shift-type1", "macro")
  r:SetAttribute("shift-macrotext1", "")
  Core.WrapRestore(r)
  r:Hide()

  -- Health sits below the content frame so that, filling the whole row
  -- (Health style: Fill), every text and icon stays on top of it.
  r.hp = CreateFrame("StatusBar", nil, r)
  r.hp:SetFrameLevel(r:GetFrameLevel() + 1)
  Core.StatusBar(r.hp)
  r.hp:SetMinMaxValues(0, 1)
  r.hp.bg = Core.Fill(r.hp, "BACKGROUND", 1, 1, 1, 0.06)
  r.hp.bg:SetAllPoints()

  local c = CreateFrame("Frame", nil, r)
  c:SetAllPoints()
  c:SetFrameLevel(r:GetFrameLevel() + 2)
  r.content = c

  -- Quiet row surfaces keep class color and tactical state easy to find.
  r.bg = Core.Fill(c, "BACKGROUND", 0.4, 0.55, 0.7, i % 2 == 0 and 0.055 or 0.09)
  r.bg:SetAllPoints()
  r.topTint = Core.Fill(c, "BACKGROUND", Core.ACCENT[1], Core.ACCENT[2], Core.ACCENT[3], 0.14, 1)
  r.topTint:SetAllPoints()
  r.topTint:Hide()

  -- Quiet rank tile; accent on the kill target.
  r.tile = Core.Fill(c, "BORDER", unpack(Core.THEME.colors.surface))
  r.tile:SetPoint("TOPLEFT")
  r.tile:SetPoint("BOTTOMLEFT")
  -- Gained/lost places: the tile flashes green/red and fades (timing feed).
  r.tileFlash = Core.Fill(c, "ARTWORK", 1, 1, 1, 1)
  r.tileFlash:SetAllPoints(r.tile)
  r.tileFlash:SetAlpha(0)
  do
    local g = r.tileFlash:CreateAnimationGroup()
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(1)
    a:SetToAlpha(0)
    a:SetDuration(1.8)
    a:SetSmoothing("IN")
    r.tileFlashAnim = g
  end
  r.rank = Core.Text(c, "mono", 13)
  r.rank:SetPoint("CENTER", r.tile, "CENTER", 0, 0)
  r.rank:SetShadowOffset(0, 0)

  -- Class color beside the rank.
  r.strip = Core.Fill(c, "ARTWORK", 1, 1, 1)
  r.strip:SetPoint("TOPLEFT", r.tile, "TOPRIGHT")
  r.strip:SetPoint("BOTTOMLEFT", r.tile, "BOTTOMRIGHT")
  r.strip:SetWidth(3)

  r.icon = c:CreateTexture(nil, "ARTWORK")

  -- Raid marker on the spec icon (top-left).
  r.marker = c:CreateTexture(nil, "OVERLAY", nil, 3)
  r.marker:SetPoint("TOPLEFT", r.icon, "TOPLEFT", -3, 3)
  r.marker:Hide()

  -- Top line: name and state. Bottom line: spec, ally pressure and range.
  r.pip = c:CreateTexture(nil, "OVERLAY")
  r.pip:SetTexture(Core.WHITE)
  r.pipText = Core.Text(c, "mono", 9)
  r.pipText:SetPoint("CENTER", r.pip, "CENTER", 0, 0)
  r.pipText:SetShadowOffset(0, 0)
  r.pipText:SetTextColor(0.05, 0.05, 0.06)

  r.gap = Core.Text(c, "mono", 9)
  r.gap:SetJustifyH("RIGHT")

  r.dist = Core.Text(c, "mono", 10)
  r.dist:SetJustifyH("RIGHT")
  -- Secret range answer: the game can light this dot, we can't read it.
  r.rangeDot = c:CreateTexture(nil, "OVERLAY")
  r.rangeDot:SetSize(5, 5)
  r.rangeDot:SetTexture(Core.CIRCLE)
  r.rangeDot:SetVertexColor(0.3, 0.95, 0.4)
  r.rangeDot:SetPoint("RIGHT", r.dist, "RIGHT", 0, 0)
  r.rangeDot:SetAlpha(0)

  r.spec = Core.Text(c, "medium", 11)

  -- PvP trinket (Cata): bright = ready, grey + seconds left = on cooldown.
  r.trinket = c:CreateTexture(nil, "ARTWORK")
  r.trinket:SetTexture(Core.TRINKET_ICON)
  r.trinket:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.trinket:Hide()
  r.trinketText = Core.Text(c, "mono", 9, "OUTLINE")
  r.trinketText:SetPoint("CENTER", r.trinket, "CENTER", 0, 0)
  r.trinketText:SetShadowOffset(0, 0)
  r.trinketText:Hide()

  -- Teammates on it (x3) and targeting-you eye, after the spec.
  r.allyText = Core.Text(c, "mono", 9)
  r.allyText:SetPoint("LEFT", r.spec, "RIGHT", 4, 0)
  r.allyText:SetWidth(30)
  r.allyText:SetJustifyH("LEFT")
  r.eye = c:CreateTexture(nil, "OVERLAY")
  r.eye:SetTexture("Interface\\Icons\\Ability_EyeOfTheOwl")
  r.eye:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.eye:SetAlpha(0)

  r.name = Core.Text(c, "semi", 15)
  r.name:SetJustifyH("LEFT")

  -- Health percentage (Cata, where health is readable).
  r.hpText = Core.Text(c, "mono", 13)
  r.hpText:SetJustifyH("RIGHT")

  -- Mana: a bar along the bottom of the row (ui/Health.lua); placed by
  -- Core.LayoutRow for the Health style.
  r.mana = CreateFrame("StatusBar", nil, c)
  Core.StatusBar(r.mana)
  r.mana:SetMinMaxValues(0, 1)
  r.mana.bg = Core.Fill(r.mana, "BACKGROUND", 0, 0, 0, 0.55)
  r.mana.bg:SetAllPoints()
  r.mana:Hide()

  -- Cast bar: hairline along the top, amber = kickable, grey = not.
  r.cast = CreateFrame("StatusBar", nil, c)
  r.cast:SetPoint("TOPLEFT", r.strip, "TOPRIGHT", 0, 0)
  r.cast:SetPoint("TOPRIGHT")
  r.cast:SetHeight(2)
  Core.StatusBar(r.cast)
  r.cast:Hide()

  -- Shown (via secret alpha) under the execute threshold.
  r.exec = Core.Border(c, 1, 0.15, 0.1, 1, 1)
  r.exec:SetAlpha(0)

  -- Live kill target outline.
  r.top = Core.Border(c, Core.ACCENT[1], Core.ACCENT[2], Core.ACCENT[3], 1, 1)
  r.top:SetFrameLevel(c:GetFrameLevel() + 4)

  -- Your current target: thin, steady grey outline + small arrow outside the
  -- panel. Deliberately quieter than the kill target: targeting someone says
  -- nothing about whether they're the right kill.
  r.sel = Core.Border(c, 0.8, 0.8, 0.85, 0.6, 1)
  r.sel:SetFrameLevel(c:GetFrameLevel() + 5)
  r.sel:Hide()
  r.arrow = c:CreateTexture(nil, "OVERLAY")
  r.arrow:SetSize(12, 12)
  r.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  r.arrow:SetVertexColor(0.75, 0.75, 0.8, 0.8)
  r.arrow:Hide()

  -- Kill window: restrained red fill and glow, plus a one-shot pop.
  r.goFill = Core.Fill(c, "ARTWORK", 1, 0.1, 0.05, 1, 7)
  r.goFill:SetAllPoints()
  r.goFill:SetBlendMode("ADD")
  r.goFill:SetAlpha(0)
  r.goGlow = Core.Border(c, 1, 0.15, 0.05, 1, 2)
  r.goGlow:SetFrameLevel(c:GetFrameLevel() + 6)
  r.goGlow:Hide()
  r.goFillAnim = Core.Bounce(r.goFill, 0.03, 0.16, 0.6)
  r.goGlowAnim = Core.Bounce(r.goGlow, 1, 0.45, 0.6)
  local pop = c:CreateAnimationGroup()
  local grow = pop:CreateAnimation("Scale")
  grow:SetScale(1.04, 1.2)
  grow:SetDuration(0.12)
  grow:SetOrder(1)
  grow:SetSmoothing("OUT")
  local shrink = pop:CreateAnimation("Scale")
  shrink:SetScale(1 / 1.04, 1 / 1.2)
  shrink:SetDuration(0.18)
  shrink:SetOrder(2)
  shrink:SetSmoothing("IN")
  r.goPop = pop

  r:SetScript("OnEnter", Core.ShowTooltip)
  r:SetScript("OnLeave", GameTooltip_Hide)
  r:SetScript("PostClick", function(self, button, down)
    if not down and button == "LeftButton" and IsShiftKeyDown() and self.entry then
      Core.CallTarget(self.entry)
    end
  end)
  Core.LayoutRow(r, i, false)
  return r
end
for i = 1, Core.MAX_ROWS do
  Core.rows[i] = Core.CreateRow(i)
end

-- Hero card click: a secure button laid over the card (left-click target,
-- right-click focus, shift-click call in chat). Like the rows, Blizzard only
-- lets its macro change out of combat: the card keeps the bound name during
-- combat and shows a changed recommendation separately.
Core.heroBtn = CreateFrame("Button", "WarboardHeroButton", Core.frame, "SecureActionButtonTemplate")
Core.heroBtn:SetAllPoints(Core.hero)
Core.heroBtn:SetFrameLevel(Core.hero:GetFrameLevel() + 10)
Core.heroBtn:RegisterForClicks("AnyDown", "AnyUp") -- see CreateRow
Core.heroBtn:SetAttribute("useOnKeyDown", false) -- mouse, keybind and /click all act on release
Core.heroBtn:SetAttribute("type1", "macro")
Core.heroBtn:SetAttribute("type2", "macro")
Core.heroBtn:SetAttribute("shift-type1", "macro")
Core.heroBtn:SetAttribute("shift-macrotext1", "")
Core.WrapRestore(Core.heroBtn)
Core.hero.hover = Core.Fill(Core.hero, "BORDER", 1, 1, 1, 0.05)
Core.hero.hover:SetAllPoints()
Core.hero.hover:Hide()
Core.hero.clickNote = Core.Text(Core.hero, "mono", 8)
Core.hero.clickNote:SetTextColor(Core.MUTED[1], Core.MUTED[2], Core.MUTED[3])
Core.heroBtn:SetScript("OnEnter", function(self)
  Core.hero.hover:Show()
  Core.ShowTooltip(self)
end)
Core.heroBtn:SetScript("OnLeave", function()
  Core.hero.hover:Hide()
  GameTooltip_Hide()
end)
Core.heroBtn:SetScript("PostClick", function(self, button, down)
  if not down and button == "LeftButton" and IsShiftKeyDown() and self.entry then
    Core.CallTarget(self.entry)
  end
end)
Core.LayoutHero(false)
