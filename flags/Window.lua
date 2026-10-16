local _, ns = ...
local Timers = ns.Timers
local Flags = ns.Flags

function Flags.BuildFlags()
  local UI = ns.UI
  if Flags.flagWin or not UI or InCombatLockdown() then
    return
  end
  Flags.flagWin = Timers.MakeWindow("WarboardFlagsFrame", "FLAG CARRIERS", "flagsPoint", { "TOP", "TOP", -Timers.THEME.timers.spacing, -150 }, true)
  if not Flags.flagWin then
    return
  end
  Flags.frows = {}
  for i, team in ipairs({ "mine", "theirs" }) do
    local r = CreateFrame("Button", "WarboardFlagRow" .. i, Flags.flagWin, "SecureActionButtonTemplate")
    r:SetPoint("TOPLEFT", Timers.WIN_PAD, -Flags.FTOP - (i - 1) * (Flags.FROW_H + Timers.WIN_GAP))
    r:SetPoint("RIGHT", -Timers.WIN_PAD, 0)
    r:SetHeight(Flags.FROW_H)
    r:RegisterForClicks("AnyDown", "AnyUp")
    r:SetAttribute("type1", "macro")
    r:SetAttribute("type2", "macro")
    r.side = team
    r.team = team == "mine" and Timers.MyTeam() or Timers.Other(Timers.MyTeam())
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetPoint("TOPLEFT")
    r.bar:SetPoint("BOTTOMRIGHT")
    r.bar:SetStatusBarTexture(UI.WHITE)
    r.bar:SetMinMaxValues(0, 1)
    r.bar:EnableMouse(false)
    local bg = UI.Fill(r.bar, "BACKGROUND", unpack(Timers.THEME.colors.surface))
    bg:SetAllPoints()
    r.tag = UI.Text(r.bar, "mono", 9)
    r.tag:SetPoint("BOTTOMLEFT", 44, 8)
    r.tag:SetWidth(40)
    r.tag:SetJustifyH("LEFT")
    r.icon = r.bar:CreateTexture(nil, "OVERLAY")
    r.icon:SetSize(28, 28)
    r.icon:SetPoint("LEFT", 8, 0)
    r.right = UI.Text(r.bar, "mono", 10)
    r.right:SetPoint("BOTTOMRIGHT", -7, 8)
    r.name = UI.Text(r.bar, "semi", 16)
    r.name:SetPoint("TOPLEFT", 44, -6)
    r.name:SetPoint("RIGHT", -7, 0)
    r.name:SetJustifyH("LEFT")
    r:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(self.side == "mine" and "Your team's flag carrier" or "Enemy flag carrier", 1, 0.82, 0)
      GameTooltip:AddLine("Left-click: target   Right-click: focus", 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", GameTooltip_Hide)
    Flags.frows[i] = r
  end
  Flags.flagWin:SetHeight(Flags.FTOP + 2 * (Flags.FROW_H + Timers.WIN_GAP) - Timers.WIN_GAP + Timers.WIN_PAD)
  Flags.SetMacros() -- stable arena targets must exist before the first combat pickup
end

function Flags.UpdateFlags(now)
  local want = Flags.FlagsEnabled() and Flags.InBG() and Flags.FlagBG()
  if not want then
    if Flags.flagWin then
      if InCombatLockdown() then Flags.flagWin:SetAlpha(0) else Flags.flagWin:Hide() end
    end
    wipe(Flags.carriers)
    return
  end
  if not Flags.flagWin then
    Flags.BuildFlags()
    if not Flags.flagWin then
      return
    end
  end
  Flags.flagWin:SetAlpha(1)
  local me = Timers.MyTeam()
  local objective = Timers.Rules().objective
  for _, r in ipairs(Flags.frows) do
    r.team = r.side == "mine" and me or Timers.Other(me)
    local c = Flags.carriers[r.team]
    local col = Timers.TeamColor(r.team)
    r.tag:SetText(r.side == "mine" and "OURS" or "THEIRS")
    r.tag:SetTextColor(col[1], col[2], col[3])
    local unit = c and c.name and Flags.CarrierUnit(r.team, c.name)
    if not (c and c.name) then
      -- arena token without a chat message (e.g. joined mid-game)
      local u = Flags.CarrierUnit(r.team, nil)
      local okN, n
      if u then okN, n = pcall(UnitName, u) end
      if okN and Timers.plain(n) and n then
        c = { name = n, since = nil }
        Flags.carriers[r.team] = c
        Flags.lastCarrier[r.team] = n
        unit = u
      end
    end
    if c and c.name then
      local short = c.name:match("^[^-]+")
      local class
      if unit then
        local okC, _, cl = pcall(UnitClass, unit)
        class = okC and Timers.plain(cl) and cl or nil
      end
      if not class and ns.EnemyKeyByName and r.team ~= me then
        local k = ns.EnemyKeyByName(c.name)
        class = k and ns.enemies[k] and ns.enemies[k].class
      end
      local cc = class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
      if class then
        if not pcall(r.icon.SetAtlas, r.icon, "classicon-" .. class:lower()) then
          r.icon:SetTexture(nil)
        end
      else
        r.icon:SetTexture("Interface\\Icons\\INV_BannerPVP_0" .. (r.team == "A" and "2" or "1"))
      end
      r.icon:Show()
      local hp
      if unit then
        local okH, h = pcall(UnitHealth, unit)
        local okM, m = pcall(UnitHealthMax, unit)
        if okH and okM and Timers.plain(h) and Timers.plain(m) and m and m > 0 then
          hp = h / m
        end
      end
      r.bar:SetValue(hp or 1)
      if cc then
        r.bar:SetStatusBarColor(cc.r, cc.g, cc.b, hp and 0.2 or 0.08)
      else
        r.bar:SetStatusBarColor(col[1], col[2], col[3], hp and 0.2 or 0.08)
      end
      r.name:SetText(short)
      local stacks = ns.FlagStacks and ns.FlagStacks()
      local parts = {}
      if hp then
        parts[#parts + 1] = string.format("%d%%", hp * 100 + 0.5)
      end
      if stacks and objective == "flag" then
        parts[#parts + 1] = "x" .. stacks
      end
      if c.since then
        parts[#parts + 1] = Timers.Clock(now - c.since)
      end
      r.right:SetText(table.concat(parts, "  "))
      r.right:SetTextColor(hp and hp < 0.35 and 1 or 0.97, hp and hp < 0.35 and 0.35 or 0.97,
        hp and hp < 0.35 and 0.3 or 0.98)
    else
      r.icon:Hide()
      r.bar:SetValue(0)
      local dropped = c and c.dropped and now - c.dropped < 15
      r.name:SetText(dropped and "flag dropped" or (objective == "carry" and "" or "at base"))
      r.right:SetText(dropped and Timers.Clock(now - c.dropped) or "")
      r.right:SetTextColor(0.6, 0.6, 0.65)
    end
    if r.macroFor ~= (c and c.name) or r.macroTeam ~= r.team then
      Flags.SetMacros()
    end
  end
  if not Flags.flagWin:IsShown() and not InCombatLockdown() then
    Timers.PlaceWin(Flags.flagWin)
    Flags.flagWin:Show()
  end
end
