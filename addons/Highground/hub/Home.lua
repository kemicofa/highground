local _, ns = ...
local Core, Theme, Kit, Hub = ns.Core, ns.Theme, ns.Kit, ns.Hub
local shortcuts = {
  { "addons", "Addons", "Visit, enable or learn each Highground addon" },
  { "alerts", "Alerts", "Choose warnings and sounds" },
}

function Hub.BuildHome(content)
  local h = CreateFrame("Frame", nil, content)
  h:SetAllPoints(); Hub.home = h
  h.card = Kit.Card(h, 144, { titleRole = "display", strip = "brand", featured = true })
  h.card:SetPoint("TOPLEFT"); h.card:SetPoint("RIGHT")
  h.card:EnableMouse(false)
  h.crest = Kit.Crest(h.card, 104)
  h.crest:SetPoint("LEFT", h.card, "LEFT", 16, 0)
  h.eyebrow = Theme.Text(h.card, "label", "accent")
  h.eyebrow:SetPoint("TOPLEFT", 140, -20)
  h.eyebrow:SetText("FIELD STATUS")
  h.where = h.card.title
  h.where:ClearAllPoints(); h.where:SetPoint("TOPLEFT", 140, -42); h.where:SetPoint("RIGHT", -16, 0)
  h.where:SetWordWrap(false)
  h.state = Theme.Text(h.card, "body", "textMuted")
  h.state:SetPoint("TOPLEFT", 140, -86); h.state:SetPoint("RIGHT", -16, 0)
  h.state:SetHeight(44); h.state:SetJustifyH("LEFT"); h.state:SetWordWrap(true)

  h.guide = Kit.Card(h, 156, { titleRole = "cardTitle" })
  h.guide:SetPoint("TOPLEFT", 0, -164); h.guide:SetPoint("RIGHT")
  h.guide.title:ClearAllPoints(); h.guide.title:SetPoint("TOPLEFT", 16, -16)
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
  title:SetPoint("TOPLEFT", 4, -340)
  h.shortcuts = {}
  for i, def in ipairs(shortcuts) do
    local key, y = def[1], -368 - math.floor((i - 1) / 2) * 82
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
    if key == "addons" and #ns.Modules.StandaloneAddons() > 0 then
      b:SetText("Extra addons found")
      b.hint:SetText("See what to remove and keep")
    end
    b.key = key; h.shortcuts[i] = b
  end
  h.tools = Kit.Button(h, "How addons work", 240, 30, { tone = "accent", onClick = function() ns.Onboarding.Start("addons") end })
  h.tools:SetPoint("TOPLEFT", 0, -468)
  h.community = Kit.Button(h, "Join Discord", 220, 30, { onClick = ns.Community.Join })
  h.community:SetPoint("LEFT", h.tools, "RIGHT", 12, 0)
  Kit.Tooltip(h.community, { "Highground Discord", "Copy the invite for addon help, discussions and bounty boards." })
  h.panelLock = Kit.Button(h, "", 190, 30, { onClick = function() ns.PanelControls.Toggle() end })
  h.panelLock:SetPoint("TOPRIGHT", 0, -468)
  Kit.Tooltip(h.panelLock, ns.PanelControls.Tooltip)
  h.help = Theme.Text(h, "body", "textMuted")
  h.help:SetPoint("TOPLEFT", 0, -518); h.help:SetPoint("RIGHT")
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
      or "Panels are off for this match. Open Battlegrounds settings to enable this type of match.")
  elseif kind == "arena" then
    h.where:SetText("ARENA")
    h.state:SetText(Core.On("arena") and "Left-click an opponent to target; right-click to focus."
      or "Your arena panel is off. Enable it in Arena settings.")
  elseif ns.Arena and ns.Arena.duel then
    h.where:SetText("DUEL")
    h.state:SetText(Core.On("arena") and "Duel panel active. Left-click target; right-click focus."
      or "Your duel panel is off. Enable it in Arena settings.")
  else
    h.where:SetText("OPEN WORLD")
    h.state:SetText("Panels open for battlegrounds, arenas and duels. Nearby enemies is "
      .. (Core.On("nearby") and "on." or "off; enable it in Nearby settings."))
  end
  h.card:SetStrip("brand")
  h.guide.title:SetText("You're ready to play")
  h.guideHint:SetText("No setup is required. Join a match through WoW's Player vs. Player window, or try example panels here first.")
  h.arrange:SetEnabled(not InCombatLockdown() and kind ~= "pvp" and kind ~= "arena")
  h.panelLock:SetText(ns.PanelControls.Action())
  h.help:SetText((ns.PanelControls.Locked() and "Panels locked. " or "Panels unlocked. ")
    .. ns.PanelControls.Hint() .. "\nYour settings and positions save automatically.")
end
