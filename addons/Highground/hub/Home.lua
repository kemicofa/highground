local _, ns = ...
local Core, Theme, Kit, Hub = ns.Core, ns.Theme, ns.Kit, ns.Hub
local shortcuts = {
  { "general", "Panels and features", "Choose what appears during play" },
  { "alerts", "Alerts", "Choose warnings and sounds" },
}

function Hub.BuildHome(content)
  local h = CreateFrame("Frame", nil, content)
  h:SetAllPoints(); Hub.home = h
  h.card = Kit.Card(h, 96, { titleRole = "heading" })
  h.card:SetPoint("TOPLEFT"); h.card:SetPoint("RIGHT")
  h.card:EnableMouse(false)
  h.where = h.card.title
  h.state = Theme.Text(h.card, "body", "textMuted")
  h.state:SetPoint("TOPLEFT", 16, -42); h.state:SetPoint("RIGHT", -16, 0)
  h.state:SetHeight(44); h.state:SetJustifyH("LEFT"); h.state:SetWordWrap(true)

  h.guide = Kit.Card(h, 140, { titleRole = "heading" })
  h.guide:SetPoint("TOPLEFT", 0, -112); h.guide:SetPoint("RIGHT")
  h.guide:EnableMouse(false)
  h.guideHint = Theme.Text(h.guide, "body", "textMuted")
  h.guideHint:SetPoint("TOPLEFT", 16, -46); h.guideHint:SetPoint("RIGHT", -16, 0)
  h.guideHint:SetHeight(40); h.guideHint:SetJustifyH("LEFT"); h.guideHint:SetWordWrap(true)
  h.start = Kit.Button(h.guide, "Back to game", 190, 32, { tone = "accent", onClick = function()
    Hub.win:Hide()
  end })
  h.start:SetPoint("BOTTOMLEFT", 16, 16)
  h.arrange = Kit.Button(h.guide, "Preview and move panels", 270, 32, { onClick = function()
    ns.PanelControls.Arrange()
  end })
  h.arrange:SetPoint("BOTTOMRIGHT", -16, 16)
  Kit.Tooltip(h.arrange, function()
    local allowed, problem = ns.Setup.CanArrange()
    return { "Arrange panels", allowed and "Show example panels and drag their headers into place." or problem }
  end)

  local title = Kit.Section(h, "Optional changes")
  title:SetPoint("TOPLEFT", 4, -274)
  h.shortcuts = {}
  for i, def in ipairs(shortcuts) do
    local key, y = def[1], -308 - math.floor((i - 1) / 2) * 82
    local b = Kit.Button(h, def[2], 330, 72, { onClick = function() Hub.Show(key) end })
    if i % 2 == 1 then
      b:SetPoint("TOPLEFT", h, "TOPLEFT", 0, y); b:SetPoint("TOPRIGHT", h, "TOP", -8, y)
    else
      b:SetPoint("TOPLEFT", h, "TOP", 8, y); b:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, y)
    end
    b.label:ClearAllPoints(); b.label:SetPoint("TOPLEFT", 16, -12)
    b.label:SetPoint("RIGHT", -16, 0); b.label:SetJustifyH("LEFT")
    b.hint = Theme.Text(b, "body", "textMuted")
    b.hint:SetPoint("TOPLEFT", 16, -40); b.hint:SetPoint("RIGHT", -16, 0)
    b.hint:SetJustifyH("LEFT"); b.hint:SetText(def[3])
    b.key = key; h.shortcuts[i] = b
  end
  h.tools = Kit.Button(h, "Quick guide", 190, 30, { onClick = function() Hub.Show("checklist") end })
  h.tools:SetPoint("TOPLEFT", 0, -410)
  h.panelLock = Kit.Button(h, "", 190, 30, { onClick = function() ns.PanelControls.Toggle() end })
  h.panelLock:SetPoint("TOPRIGHT", 0, -410)
  Kit.Tooltip(h.panelLock, ns.PanelControls.Tooltip)
  h.help = Theme.Text(h, "body", "textMuted")
  h.help:SetPoint("TOPLEFT", 0, -460); h.help:SetPoint("RIGHT")
  h.help:SetHeight(48); h.help:SetJustifyH("LEFT"); h.help:SetJustifyV("TOP"); h.help:SetWordWrap(true)
  h:Hide()
end

function Hub.RefreshHome()
  local h = Hub.home
  if not h then return end
  local _, kind = IsInInstance()
  local bg = ns.GetBG and ns.GetBG()
  local active = ns.IsActive and ns.IsActive()
  if kind == "pvp" then
    h.where:SetText((bg and bg.name or "Battleground"):upper())
    h.state:SetText(active and "Click an enemy's name to target them. Use your abilities as usual."
      or "Panels are off for this match. Open Panels and features, then Battleground, to enable this type of match.")
  elseif kind == "arena" then
    h.where:SetText("ARENA")
    h.state:SetText(not ns.Games[ns.GAME].arenaSize and "This game does not support arenas."
      or Core.On("arena") and "Click an enemy in the arena panel to target them. Right-click sets a focus target."
      or "Your arena panel is off. Enable it under Panels and features → Arena.")
  else
    h.where:SetText("OPEN WORLD")
    h.state:SetText("Match panels appear in battlegrounds and arenas. Nearby enemies is "
      .. (Core.On("nearby") and "on." or "off; enable it in Panels and features."))
  end
  h.card:SetStrip(active and "accent" or "textMuted")
  h.guide.title:SetText("You're ready to play")
  h.guideHint:SetText("No setup is required. Join a match through WoW's Player vs. Player window, or try example panels here first.")
  h.arrange:SetEnabled(not InCombatLockdown() and kind ~= "pvp" and kind ~= "arena")
  h.panelLock:SetText(ns.PanelControls.Action())
  h.help:SetText((ns.PanelControls.Locked() and "Panels locked. " or "Panels unlocked. ")
    .. ns.PanelControls.Hint() .. "\nYour settings and positions save automatically.")
end
