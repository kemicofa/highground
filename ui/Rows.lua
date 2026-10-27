local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme

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
  r.hp.bg = Theme.Fill(r.hp, "BACKGROUND", "white", "band")
  r.hp.bg:SetAllPoints()

  local c = CreateFrame("Frame", nil, r)
  c:SetAllPoints()
  c:SetFrameLevel(r:GetFrameLevel() + 2)
  r.content = c

  -- Quiet row surfaces keep class color and tactical state easy to find.
  r.bg = Theme.Fill(c, "BACKGROUND", "textMuted", i % 2 == 0 and 0.055 or 0.09) -- zebra
  r.bg:SetAllPoints()
  r.topTint = Theme.Fill(c, "BACKGROUND", "accent", 0.14, 1)
  r.topTint:SetAllPoints()
  r.topTint:Hide()

  -- Quiet rank tile; accent on the kill target.
  r.tile = Theme.Fill(c, "BORDER", "surface")
  r.tile:SetPoint("TOPLEFT")
  r.tile:SetPoint("BOTTOMLEFT")
  -- Gained/lost places: the tile flashes green/red and fades (timing feed).
  r.tileFlash = Theme.Fill(c, "ARTWORK", "success")
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
  r.rank = Theme.Text(c, "heading", "textMuted")
  r.rank:SetPoint("CENTER", r.tile, "CENTER", 0, 0)
  r.rank:SetShadowOffset(0, 0)

  -- Class color beside the rank.
  r.strip = Theme.Fill(c, "ARTWORK", "border")
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
  r.pipText = Theme.Text(c, "label", "onAccent")
  r.pipText:SetPoint("CENTER", r.pip, "CENTER", 0, 0)
  r.pipText:SetShadowOffset(0, 0)

  r.gap = Theme.Text(c, "label")
  r.gap:SetJustifyH("RIGHT")

  r.dist = Theme.Text(c, "code")
  r.dist:SetJustifyH("RIGHT")
  -- Secret range answer: the game can light this dot, we can't read it.
  r.rangeDot = c:CreateTexture(nil, "OVERLAY")
  r.rangeDot:SetSize(5, 5)
  r.rangeDot:SetTexture(Core.CIRCLE)
  Theme.Tint(r.rangeDot, "success")
  r.rangeDot:SetPoint("RIGHT", r.dist, "RIGHT", 0, 0)
  r.rangeDot:SetAlpha(0)

  r.spec = Theme.Text(c, "body", "textMuted")

  -- PvP trinket (Cata): bright = ready, grey + seconds left = on cooldown.
  r.trinket = c:CreateTexture(nil, "ARTWORK")
  r.trinket:SetTexture(Core.TRINKET_ICON)
  r.trinket:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.trinket:Hide()
  r.trinketText = Theme.Text(c, "label", "gold") -- face and outline: Core.LayoutRow
  r.trinketText:SetPoint("CENTER", r.trinket, "CENTER", 0, 0)
  r.trinketText:SetShadowOffset(0, 0)
  r.trinketText:Hide()

  -- Teammates on it (x3) and targeting-you eye, after the spec.
  r.allyText = Theme.Text(c, "label")
  r.allyText:SetPoint("LEFT", r.spec, "RIGHT", 4, 0)
  r.allyText:SetWidth(30)
  r.allyText:SetJustifyH("LEFT")
  r.eye = c:CreateTexture(nil, "OVERLAY")
  r.eye:SetTexture("Interface\\Icons\\Ability_EyeOfTheOwl")
  r.eye:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.eye:SetAlpha(0)

  r.name = Theme.Text(c, "rowName")
  r.name:SetJustifyH("LEFT")

  -- Health percentage (Cata, where health is readable).
  r.hpText = Theme.Text(c, "heading")
  r.hpText:SetJustifyH("RIGHT")

  -- Mana: a bar along the bottom of the row (ui/Health.lua); placed by
  -- Core.LayoutRow for the Health style.
  r.mana = CreateFrame("StatusBar", nil, c)
  Core.StatusBar(r.mana)
  r.mana:SetMinMaxValues(0, 1)
  r.mana.bg = Theme.Fill(r.mana, "BACKGROUND", "black", "bar")
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
  r.exec = Core.TokenBorder(c, "kill")
  r.exec:SetAlpha(0)

  -- Live kill target outline.
  r.top = Core.TokenBorder(c, "accent")
  r.top:SetFrameLevel(c:GetFrameLevel() + 4)

  -- Your current target: thin, steady grey outline + small arrow outside the
  -- panel. Deliberately quieter than the kill target: targeting someone says
  -- nothing about whether they're the right kill.
  r.sel = Core.TokenBorder(c, "text", "bar")
  r.sel:SetFrameLevel(c:GetFrameLevel() + 5)
  r.sel:Hide()
  r.arrow = c:CreateTexture(nil, "OVERLAY")
  r.arrow:SetSize(12, 12)
  r.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
  Theme.Tint(r.arrow, "textMuted", 0.8)
  r.arrow:Hide()

  -- Kill window: restrained red fill and glow, plus a one-shot pop.
  r.goFill = Theme.Fill(c, "ARTWORK", "kill", nil, 7)
  r.goFill:SetAllPoints()
  r.goFill:SetBlendMode("ADD")
  r.goFill:SetAlpha(0)
  r.goGlow = Core.TokenBorder(c, "kill", nil, 2)
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
Core.hero.hover = Theme.Fill(Core.hero, "BORDER", "overlaySubtle")
Core.hero.hover:SetAllPoints()
Core.hero.hover:Hide()
Core.hero.clickNote = Theme.Text(Core.hero, "caption", "textMuted")
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
