local _, ns = ...
local Core, Theme, Kit, Motion, Hub = ns.Core, ns.Theme, ns.Kit, ns.Motion, ns.Hub
local S, Z = Theme.Space, Theme.Size

local function NavButton(parent, label, onClick)
  local b = Kit.Button(parent, label, Hub.NAV_W - 32, Z("control"), { tone = "panel", onClick = onClick })
  b.label:ClearAllPoints()
  b.label:SetPoint("LEFT", S("md") + S("xs"), 0)
  b.label:SetPoint("RIGHT", -S("md"), 0)
  b.label:SetJustifyH("LEFT")
  b.label:SetWordWrap(false)
  b.edge:SetShown(false)
  b.bevel:SetShown(false)
  return b
end

local function PaintGroup(b)
  local active = false
  for _, child in ipairs(b.groupItems) do
    if child.section.key == Hub.current then active = true end
  end
  Kit.Paint(b, active and not b.expanded and "selected" or "panel", active and "accent" or "text")
  local angle = b.expansion * math.pi / 2
  for i, stroke in ipairs(b.chevron) do
    local sign = i == 1 and 1 or -1
    stroke:ClearAllPoints()
    stroke:SetPoint("CENTER", b, "RIGHT", -S("lg") + sign * 2 * math.sin(angle), sign * 2 * math.cos(angle))
    stroke:SetRotation((i == 1 and -1 or 1) * math.pi / 4 - angle)
    Theme.Paint(stroke, active and "accent" or "textMuted")
  end
end

-- Each group has a clipped body. Its contents keep their normal row sizes;
-- only the viewport grows, moving following sections without overlapping.
local function LayoutGroup(w, b, width, height, y)
  local full = #b.groupItems * (height + S("xs")) + S("sm")
  local extent = full * b.expansion
  b.clip:ClearAllPoints()
  b.clip:SetPoint("TOPLEFT", S("md"), y)
  b.clip:SetSize(width - 32, math.max(0.01, extent))
  b.clip:SetShown(extent > 0)
  b.body:SetSize(width - 32, full)
  b.body:SetAlpha(b.expansion)
  for i, child in ipairs(b.groupItems) do
    local top = (i - 1) * (height + S("xs"))
    child:ClearAllPoints()
    child:SetPoint("TOPLEFT", S("xl"), -top)
    child:SetSize(width - 32 - S("xl"), height)
    child:SetShown(extent > 0)
    -- A clipped or exiting row cannot catch a click intended for another
    -- section. Don't dim disabled rows: the body's fade supplies feedback.
    local interactive = b.expanded and top + height <= extent + 0.001
    if child.navInteractive ~= interactive then
      child.navInteractive = interactive
      child:EnableMouse(interactive)
      if not interactive then child:ResetFeedback() end
    end
  end
  b.guide:SetHeight(math.max(1, full - S("sm") * 2))
  PaintGroup(b)
  return y - extent
end

function Hub.LayoutNav(w)
  local scale = math.max(1, Core.FontScale())
  local width = 32 + (Hub.NAV_W - 32) * scale
  local height, y = Z("control") * math.min(1.25, scale), -S("xs")
  w.navFill:SetWidth(width)
  w.navScroll:SetWidth(width)
  w.content:SetPoint("TOPLEFT", width + S("lg"), -Z("header") - S("md"))
  for _, item in ipairs(w.navItems) do
    if not item.groupButton then
      item:ClearAllPoints()
      if item.section or item.groupTitle then
        item:SetPoint("TOPLEFT", S("md"), y)
        item:SetSize(width - 32, height)
        y = y - height - S("xs")
        if item.groupTitle then y = LayoutGroup(w, item, width, height, y) end
      else
        item:SetPoint("TOPLEFT", S("xl"), y - S("sm") - S("xs"))
        y = y - Z("row") * math.min(1.25, scale)
      end
    end
  end
  w.navBody:SetHeight(-y + S("md"))
  w.navScroll:Refresh()
  w.blizzard:SetSize(120 * scale, height)
  w.LayoutHeader()
end

function Hub.SetGroupExpanded(b, expanded)
  expanded = not not expanded
  if b.expanded == expanded then return end
  b.expanded = expanded
  -- State and hit testing update at once; geometry follows the same clock
  -- as the chevron and fade. Retargeting uses the currently drawn fraction.
  Hub.LayoutNav(Hub.win)
  Motion.Value(b, b.expansion, expanded and 1 or 0, "expand", b.ApplyExpansion)
end

local function Group(w, title)
  local b = NavButton(w.navBody, title, function(self) Hub.SetGroupExpanded(self, not self.expanded) end)
  b.groupTitle, b.expanded, b.expansion = title, false, 0
  b.groupItems, b.chevron = {}, {}
  b.label:SetPoint("RIGHT", -S("xl") - S("md"), 0)
  for i = 1, 2 do
    local stroke = Theme.Fill(b, "ARTWORK", "textMuted")
    stroke:SetSize(S("sm") + S("xs"), Z("underline"))
    b.chevron[i] = stroke
  end
  b.clip = CreateFrame("ScrollFrame", nil, w.navBody)
  b.body = CreateFrame("Frame", nil, b.clip)
  b.clip:SetScrollChild(b.body)
  b.clip:EnableMouseWheel(true)
  b.clip:SetScript("OnMouseWheel", function(_, delta)
    local view = w.navScroll.view
    view:GetScript("OnMouseWheel")(view, delta)
  end)
  b.guide = Theme.Fill(b.body, "ARTWORK", "border")
  b.guide:SetPoint("TOPLEFT", S("md") + S("xs"), -S("xs"))
  b.guide:SetWidth(Z("line"))
  function b:ApplyExpansion(value)
    self.expansion = value
    Hub.LayoutNav(w)
  end
  return b
end

function Hub.BuildNav(w)
  local head = Z("header")
  w.navFill = Theme.Fill(w, "BACKGROUND", "surface", "bar")
  w.navFill:SetPoint("TOPLEFT", 1, -head - 1)
  w.navFill:SetPoint("BOTTOMLEFT", 1, 1)
  w.navFill:SetWidth(Hub.NAV_W)
  w.nav, w.groups, w.navItems, w.navGroups = {}, {}, {}, {}
  local scroll = Kit.ScrollArea(w)
  scroll:SetPoint("TOPLEFT", 0, -head - S("md"))
  scroll:SetPoint("BOTTOMLEFT", 0, S("md"))
  scroll:SetWidth(Hub.NAV_W)
  w.navScroll, w.navBody = scroll, scroll.body
  local groupButton
  for _, s in ipairs(Hub.sections) do
    if s.group then
      if s.collapsed then
        groupButton = Group(w, s.group)
        w.navGroups[#w.navGroups + 1] = groupButton
        w.navItems[#w.navItems + 1] = groupButton
      else
        groupButton = nil
        local g = Kit.Caption(w.navBody, s.group)
        w.groups[#w.groups + 1] = g
        w.navItems[#w.navItems + 1] = g
      end
    else
      local b = NavButton(groupButton and groupButton.body or w.navBody, s.label, function() Hub.Show(s.key) end)
      b.section, b.groupButton = s, groupButton
      if groupButton then groupButton.groupItems[#groupButton.groupItems + 1] = b end
      w.nav[#w.nav + 1] = b
      w.navItems[#w.navItems + 1] = b
    end
  end
  w:HookScript("OnHide", function()
    for _, b in ipairs(w.navGroups) do Motion.Finish(b) end
  end)
  Core.OnFontScaleChange(function() Hub.LayoutNav(w) end)
  Hub.LayoutNav(w)
end
