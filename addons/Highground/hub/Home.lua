local _, ns = ...
local Core, Theme, Kit, Hub = ns.Core, ns.Theme, ns.Kit, ns.Hub
local S = Theme.Space
local shortcuts = {
  { "addons", "Addons", "Visit, enable or learn each Highground addon" },
  { "alerts", "Alerts", "Choose warnings and sounds" },
}
local PAD, CREST, CARD_H, GUIDE_H, SHORTCUT_H = S("xl"), 104, 144, 156, 72
local TEXT_X = PAD + CREST + S("xl") + S("sm")

local function Paragraph(parent, role, color)
  local text = Kit.Paragraph(parent, role, color)
  text:SetJustifyV("TOP")
  return text
end

-- Wrapped text at width; its height follows the text so nothing is clipped.
local function Fit(text, width)
  text:SetWidth(math.max(1, width))
  local height = math.ceil(text:GetStringHeight())
  text:SetHeight(math.max(1, height))
  return height
end

function Hub.BuildHome(content)
  local h = CreateFrame("Frame", nil, content)
  h:SetAllPoints(); Hub.home = h
  -- Larger text can need more room than the window; scroll instead of overlapping.
  h.scroll = Kit.ScrollArea(h, { gutter = S("lg") })
  h.scroll:SetAllPoints()
  local body = h.scroll.body
  h.card = Kit.Card(body, CARD_H, { titleRole = "display", strip = "brand", featured = true })
  h.card:EnableMouse(false)
  h.crest = Kit.Crest(h.card, CREST)
  h.crest:SetPoint("LEFT", h.card, "LEFT", PAD, 0)
  h.eyebrow = Theme.Text(h.card, "label", "accent")
  h.eyebrow:SetText("FIELD STATUS")
  h.where = h.card.title
  h.where:SetWordWrap(false)
  h.state = Paragraph(h.card, "body", "textMuted")

  h.guide = Kit.Card(body, GUIDE_H, { titleRole = "cardTitle" })
  h.guide:EnableMouse(false)
  h.guideHint = Paragraph(h.guide, "body", "textMuted")
  h.start = Kit.Button(h.guide, "Back to game", 190, 32, { tone = "accent", onClick = function()
    Hub.win:Hide()
  end })
  h.arrange = Kit.Button(h.guide, "Preview and move panels", 270, 32, { onClick = function()
    ns.PanelControls.Arrange()
  end })
  Kit.Tooltip(h.arrange, function()
    local allowed, problem = ns.Setup.CanArrange()
    return { "Arrange panels", allowed and "Show example panels and drag their headers into place." or problem }
  end)

  h.section = Kit.Section(body, "Optional changes")
  h.section.rule:ClearAllPoints()
  h.section.rule:SetPoint("LEFT", h.section, "RIGHT", S("md"), 0); h.section.rule:SetPoint("RIGHT", body, "RIGHT")
  h.shortcuts = {}
  for i, def in ipairs(shortcuts) do
    local key = def[1]
    local b = Kit.Button(body, def[2], 330, SHORTCUT_H, { onClick = function() Hub.Show(key) end })
    b.label:SetJustifyH("LEFT")
    b.hint = Paragraph(b, "body", "textMuted")
    b.hint:SetText(def[3])
    if key == "addons" and #ns.Modules.StandaloneAddons() > 0 then
      b:SetText("Extra addons found")
      b.hint:SetText("See what to remove and keep")
    end
    b.key = key; h.shortcuts[i] = b
  end
  h.tools = Kit.Button(body, "How addons work", 240, 30, { tone = "accent", onClick = function() ns.Onboarding.Start("addons") end })
  h.community = Kit.Button(body, "Join Discord", 220, 30, { onClick = ns.Community.Join })
  Kit.Tooltip(h.community, { "Highground Discord", "Copy the invite for addon help, discussions and bounty boards." })
  h.panelLock = Kit.Button(body, "", 190, 30, { onClick = function() ns.PanelControls.Toggle() end })
  Kit.Tooltip(h.panelLock, ns.PanelControls.Tooltip)
  h.help = Paragraph(body, "body", "textMuted")
  h.scroll.onLayout = function(_, width) Hub.LayoutHome(width) end
  Core.OnFontScaleChange(function() if h:IsVisible() then h.scroll:Refresh() end end)
  h:Hide()
end

-- Stack the sections from measured text. At ordinary sizes this keeps the
-- original proportions; larger text grows each block instead of clipping.
function Hub.LayoutHome(width)
  local h = Hub.home
  if not h then return end
  local body, place = h.scroll.body, Kit.Place
  local control = math.ceil(Kit.Scale(32))
  local column = width - TEXT_X - PAD
  place(h.eyebrow, "TOPLEFT", h.card, "TOPLEFT", TEXT_X, -(PAD + S("sm")))
  local y = PAD + S("sm") + math.ceil(h.eyebrow:GetStringHeight()) + S("md") + S("xs")
  h.where:ClearAllPoints(); h.where:SetPoint("TOPLEFT", TEXT_X, -y); h.where:SetPoint("RIGHT", -PAD, 0)
  y = y + math.ceil(h.where:GetStringHeight()) + S("lg")
  place(h.state, "TOPLEFT", h.card, "TOPLEFT", TEXT_X, -y)
  y = y + Fit(h.state, column) + PAD
  local cardHeight = math.max(CARD_H, y, CREST + PAD * 2)
  place(h.card, "TOPLEFT", body, "TOPLEFT", 0, 0, width, cardHeight)

  local top = cardHeight + S("xl") + S("sm")
  h.guide.title:ClearAllPoints(); h.guide.title:SetPoint("TOPLEFT", PAD, -PAD); h.guide.title:SetPoint("RIGHT", -PAD, 0)
  y = PAD + math.ceil(h.guide.title:GetStringHeight()) + S("md") + S("xs")
  place(h.guideHint, "TOPLEFT", h.guide, "TOPLEFT", PAD, -y)
  y = y + Fit(h.guideHint, width - PAD * 2) + S("lg")
  -- Actions sit on the card's bottom edge; narrow layouts stack them.
  local startWidth = Kit.LabelWidth(h.start, 190)
  local arrangeWidth = Kit.LabelWidth(h.arrange, 270)
  local stacked = startWidth + arrangeWidth + S("lg") > width - PAD * 2
  local actions = stacked and control * 2 + S("md") or control
  local guideHeight = math.max(GUIDE_H, y + actions + PAD)
  place(h.arrange, "BOTTOMLEFT", h.guide, "BOTTOMLEFT", stacked and PAD or width - PAD - arrangeWidth, PAD, arrangeWidth, control)
  place(h.start, "BOTTOMLEFT", h.guide, "BOTTOMLEFT", PAD, PAD + (stacked and control + S("md") or 0), startWidth, control)
  place(h.guide, "TOPLEFT", body, "TOPLEFT", 0, -top, width, guideHeight)

  top = top + guideHeight + S("xl") + S("sm")
  place(h.section, "TOPLEFT", body, "TOPLEFT", S("sm"), -top)
  top = top + S("xl") + S("lg")
  local half = (width - PAD) / 2
  local shortcutHeight = SHORTCUT_H
  for _, b in ipairs(h.shortcuts) do
    b.label:ClearAllPoints(); b.label:SetPoint("TOPLEFT", PAD, -S("lg")); b.label:SetPoint("RIGHT", -PAD, 0)
    local labelHeight = math.ceil(b.label:GetStringHeight())
    place(b.hint, "TOPLEFT", b, "TOPLEFT", PAD, -(S("lg") + labelHeight + S("lg")))
    shortcutHeight = math.max(shortcutHeight, S("lg") * 3 + labelHeight + Fit(b.hint, half - PAD * 2))
  end
  for i, b in ipairs(h.shortcuts) do
    local row, columnIndex = math.floor((i - 1) / 2), (i - 1) % 2
    place(b, "TOPLEFT", body, "TOPLEFT", columnIndex * (half + PAD), -(top + row * (shortcutHeight + S("md") + S("xs"))),
      half, shortcutHeight)
  end
  local rows = math.ceil(#h.shortcuts / 2)
  top = top + rows * shortcutHeight + (rows - 1) * (S("md") + S("xs")) + S("xl") + S("lg")

  -- One row of actions: the usual widths, else just their labels, else wrap.
  local actionHeight = math.ceil(Kit.Scale(30))
  local tools, community, lock = Kit.LabelWidth(h.tools, 240), Kit.LabelWidth(h.community, 220), Kit.LabelWidth(h.panelLock, 190)
  if tools + community + lock + S("lg") * 2 > width then
    tools, community, lock = Kit.LabelWidth(h.tools), Kit.LabelWidth(h.community), Kit.LabelWidth(h.panelLock)
  end
  place(h.tools, "TOPLEFT", body, "TOPLEFT", 0, -top, tools, actionHeight)
  local x = tools + S("lg")
  if x + community + S("lg") + lock > width then
    top = top + actionHeight + S("md"); x = 0
  end
  place(h.community, "TOPLEFT", body, "TOPLEFT", x, -top, community, actionHeight)
  if x + community + S("lg") + lock > width then top = top + actionHeight + S("md") end
  place(h.panelLock, "TOPLEFT", body, "TOPLEFT", width - lock, -top, lock, actionHeight)
  top = top + actionHeight + S("xl") + S("sm")
  place(h.help, "TOPLEFT", body, "TOPLEFT", 0, -top)
  top = top + Fit(h.help, width) + S("md")
  if math.abs(body:GetHeight() - top) > 0.001 then body:SetHeight(top) end
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
  -- Routes show Home before its window; measure as soon as it is selected.
  if h:IsShown() then h.scroll:Refresh() end
end
