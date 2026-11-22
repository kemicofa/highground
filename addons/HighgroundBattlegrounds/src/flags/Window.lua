local _, ns = ...
local Timers = ns.Timers
local Flags = ns.Flags
local Core, Theme, Kit, Hud, Util = ns.Core, ns.Theme, ns.Kit, ns.Hud, ns.Util

function Flags.BuildFlags()
  if Flags.flagWin or InCombatLockdown() then
    return
  end
  local prefix = ns.FRAME_PREFIX or "Highground"
  Flags.flagWin = Timers.MakeWindow(prefix .. "FlagsFrame", "FLAG CARRIERS", "flagsPoint", { "TOP", "TOP", -Timers.THEME.timers.spacing, -150 }, true)
  if not Flags.flagWin then
    return
  end
  Flags.frows = {}
  for i, team in ipairs({ "mine", "theirs" }) do
    local r = Hud.UnitRow(Flags.flagWin, prefix .. "FlagRow" .. i, { enemy = true, briefTip = true, tip = function(self)
      return self.side == "mine" and "Allied flag carrier · Protect this player" or "Enemy flag carrier · Stop this player"
    end })
    r.side = team
    r.team = team == "mine" and Timers.MyTeam() or Timers.Other(Timers.MyTeam())
    r.bar = CreateFrame("StatusBar", nil, r)
    Core.StatusBar(r.bar); r.bar:SetMinMaxValues(0, 1); r.bar:EnableMouse(false)
    Theme.Fill(r.bar, "BACKGROUND", "bg"):SetAllPoints()
    r.healthBorder = Kit.Outline(r.bar, "border")
    r.hpText = Theme.Text(r.bar, "label")
    r.hpText:SetJustifyH("RIGHT")
    r.healthTextBg = Theme.Fill(r.bar, "OVERLAY", "bg", 0.9)
    r.healthTextBg:SetPoint("TOPLEFT", r.hpText, "TOPLEFT", -3, 1)
    r.healthTextBg:SetPoint("BOTTOMRIGHT", r.hpText, "BOTTOMRIGHT", 3, -1)
    r.tag = Theme.Text(r, "label")
    r.tag:SetJustifyH("LEFT")
    r.right = Theme.Text(r, "label", "textMuted")
    r.right:SetJustifyH("RIGHT")
    Flags.frows[i] = r
  end
  Flags.flagWin.relayout = Flags.LayoutRows
  Flags.LayoutRows()
  Flags.SetMacros() -- stable arena targets must exist before the first combat pickup
end

-- Name, dedicated health and carrier status. Compact uses a thinner strip.
-- Keep protected rows fixed until combat ends, including text-size changes.
function Flags.LayoutRows()
  if not Flags.frows or InCombatLockdown() then return end
  local compact = Timers.Compact()
  local scale = math.max(1, Core.FontScale())
  Flags.layoutScale, Flags.layoutCompact = Core.FontScale(), compact
  Flags.FTOP = Timers.TOP
  Flags.FROW_H = (compact and Timers.THEME.compact.flags or Timers.THEME.flags).row + (scale - 1) * (compact and 28 or 52)
  Flags.flagWin:SetWidth(compact and Timers.WIN_W or math.max(Timers.WIN_W, 300 + (scale - 1) * 120))
  Flags.flagWin.title:ClearAllPoints()
  Flags.flagWin.title:SetPoint("LEFT", Flags.flagWin.brand, "RIGHT", 6, 0)
  Flags.flagWin.title:SetPoint("RIGHT", Flags.flagWin.gear, "LEFT", -6, 0)
  Flags.flagWin.title:SetText(compact and "FLAGS" or "FLAG CARRIERS")
  Flags.flagWin.info:Hide()
  for i, r in ipairs(Flags.frows) do
    local x, y = compact and 46 or 54, -Flags.FTOP - (i - 1) * (Flags.FROW_H + Timers.WIN_GAP)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", Timers.WIN_PAD, y)
    r:SetPoint("TOPRIGHT", -Timers.WIN_PAD, y)
    r:SetHeight(Flags.FROW_H)
    for _, region in ipairs({ r.tag, r.icon, r.right, r.name, r.bar, r.hpText }) do region:ClearAllPoints() end
    r.icon:SetSize(compact and 32 or 40, compact and 32 or 40)
    r.icon:SetPoint("TOPLEFT", 6, -6)
    Timers.Font(r.name, compact and "control" or "rowNameLarge")
    r.name:SetPoint("TOPLEFT", x, -4)
    r.name:SetPoint("TOPRIGHT", compact and -50 * scale or -6, -4)
    local barY = -(8 + (compact and 16 or 20) * scale)
    r.bar:SetPoint("TOPLEFT", x, barY); r.bar:SetPoint("TOPRIGHT", -6, barY)
    r.bar:SetHeight(compact and 5 or 18 * scale)
    r.tag:SetPoint("BOTTOMLEFT", x, 5); r.tag:SetWidth(48 * scale)
    r.right:SetPoint("BOTTOMLEFT", r.tag, "BOTTOMRIGHT", 6, 0); r.right:SetPoint("BOTTOMRIGHT", -6, 5)
    r.healthTextBg:SetShown(not compact and r.hpText:IsShown())
    if compact then
      r.hpText:SetPoint("TOPRIGHT", r, "TOPRIGHT", -6, -4)
    else
      r.hpText:SetPoint("RIGHT", -4, 0)
    end
  end
  Flags.flagWin:SetHeight(Flags.FTOP + 2 * (Flags.FROW_H + Timers.WIN_GAP) - Timers.WIN_GAP + Timers.WIN_PAD)
end

function Flags.UpdateFlags(now)
  local want = Flags.FlagsEnabled() and Flags.InBG() and Flags.FlagBG()
  if not want then
    Timers.SecureHide(Flags.flagWin)
    wipe(Flags.carriers)
    return
  end
  if not Flags.flagWin then
    Flags.BuildFlags()
    if not Flags.flagWin then
      return
    end
  end
  if Flags.layoutScale ~= Core.FontScale() or Flags.layoutCompact ~= Timers.Compact() then Flags.LayoutRows() end
  Flags.flagWin:SetAlpha(1)
  local me = Timers.MyTeam()
  local objective = Timers.Rules().objective
  for _, r in ipairs(Flags.frows) do
    r.team = r.side == "mine" and me or Timers.Other(me)
    local c = Flags.carriers[r.team]
    local col = Timers.TeamColor(r.team)
    r.tag:SetText(r.side == "mine" and "ALLY" or "ENEMY")
    Theme.Paint(r.tag, col)
    local unit = c and c.name and Flags.CarrierUnit(r.team, c.name)
    if not (c and c.name) then
      -- arena token without a chat message (e.g. joined mid-game)
      local u = Flags.CarrierUnit(r.team, nil)
      local okN, n
      if u then okN, n = true, ns.Core.UnitShort(u) end
      if okN and Timers.plain(n) and n then
        c = { name = n, since = nil }
        Flags.carriers[r.team] = c
        Flags.lastCarrier[r.team] = n
        unit = u
      end
    end
    if c and c.name then
      local short = c.name:match("^[^-]+")
      local class, specIcon
      if unit then
        local okC, _, cl = pcall(UnitClass, unit)
        class = okC and Timers.plain(cl) and cl or nil
      end
      if ns.EnemyKeyByName and r.team ~= me then
        local k = ns.EnemyKeyByName(c.name)
        local e = k and ns.enemies[k]
        class = class or (e and e.class)
        local si = e and e.specID and ns.Core and ns.Core.specInfo[e.specID]
        specIcon = si and si.icon
      end
      local cc = ns.Util.ClassColor(class)
      Hud.PaintEnemy(r.classBg, cc)
      Hud.PaintClass(r.name, cc)
      if specIcon then
        r.icon:SetTexture(specIcon)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.icon:Show()
      elseif class then
        Kit.ClassIcon(r.icon, class)
      else
        r.icon:SetTexture("Interface\\Icons\\INV_BannerPVP_0" .. (r.team == "A" and "2" or "1"))
        r.icon:SetTexCoord(0, 1, 0, 1)
        r.icon:Show()
      end
      local dead = unit and Util.read(UnitIsDeadOrGhost, unit)
      local hp, drawn = Hud.Health(r.bar, unit, dead)
      local bc = cc and Core.BarColor(cc, r.team, hp)
      Timers.BarColor(r.bar, bc or col, 1)
      Hud.HealthText(r.hpText, unit, hp, drawn, dead)
      r.hpText:Show()
      r.healthTextBg:SetShown(not Timers.Compact())
      r.name:SetText(short)
      local stacks = ns.FlagStacks and ns.FlagStacks()
      local parts = {}
      if stacks and objective == "flag" then
        parts[#parts + 1] = "x" .. stacks
      end
      if c.since then
        parts[#parts + 1] = Timers.Clock(now - c.since)
      end
      r.right:SetText(table.concat(parts, "  "))
      Theme.Paint(r.right, "textMuted")
    else
      Hud.PaintEnemy(r.classBg)
      Hud.PaintClass(r.name)
      r.icon:Hide()
      r.bar:SetValue(0)
      r.hpText:Hide(); r.healthTextBg:Hide()
      local dropped = c and c.dropped and now - c.dropped < 15
      r.name:SetText(dropped and "Flag dropped" or "No carrier seen")
      r.right:SetText(dropped and Timers.Clock(now - c.dropped) or "")
      Theme.Paint(r.right, "textMuted")
    end
    if r.macroFor ~= (c and c.name) or r.macroTeam ~= r.team then
      Flags.SetMacros()
    end
  end
  if Timers.SecureShow(Flags.flagWin) and ns.Dock then ns.Dock() end
end

Core.OnFontScaleChange(Flags.LayoutRows)
