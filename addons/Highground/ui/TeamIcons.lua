local _, ns = ...
local Core, Kit, Theme = ns.Core, ns.Kit, ns.Theme

---------------------------------------------------------------------------
-- Team icons window (/hg icons): one row per group member with their icon.
-- The group leader clicks a row to choose an icon in the picker; everyone
-- else sees the icons and why they can't change them. The picker also
-- opens at the cursor from the Set team icon key and /hg icon. /hg icons
-- test shows sample teammates whose icons stay in the window.
---------------------------------------------------------------------------
local W = { items = {}, units = {} }
ns.TeamIcons = W
local ROW, GAP, BADGE = 30, 4, 22

-- Sample teammates: two with the same icon show the second outline colour.
local function Samples()
  local marks = {}
  local list = {
    { key = "sample:Brann", name = "Brann", class = "WARRIOR", icon = "flag" },
    { key = "sample:Lunara", name = "Lunara", class = "PRIEST", icon = "healer" },
    { key = "sample:Thornik", name = "Thornik", class = "SHAMAN", icon = "healer" },
    { key = "sample:Sylra", name = "Sylra", class = "DRUID", icon = "DRUID" },
    { key = "sample:Kael", name = "Kael", class = "MAGE", icon = "squadA" },
    { key = "sample:Vex", name = "Vex", class = "ROGUE" },
  }
  for _, item in ipairs(list) do
    if item.icon then Core.MarkTeamIcon(marks, item.key, item.icon) end
  end
  return list, marks
end

local function Marks()
  if W.sample then return W.sampleMarks end
  return Core.TeamIconMarks()
end

-- Why the window can't change icons now, else nil. Samples always can.
function W.Lock()
  if W.sample then return end
  return Core.TeamIconLock()
end

local function Items()
  wipe(W.items)
  if W.sample then
    for _, item in ipairs(W.samples) do W.items[#W.items + 1] = item end
    return W.items
  end
  for _, unit in ipairs(Core.TeamUnits(W.units)) do
    local key = Core.TeamKey(unit)
    local _, class = ns.Util.call(UnitClass, unit)
    if key then
      W.items[#W.items + 1] = { unit = unit, key = key, name = Core.DisplayName(Core.FullUnitName(unit)),
        class = Core.plain(class) and class or nil }
    end
  end
  return W.items
end

---------------------------------------------------------------------------
-- Picker: class, role and other icons, then No icon. One at a time.
---------------------------------------------------------------------------
local P
local COLUMNS, CELL, PAD = 7, 30, 4

local function Pick(icon)
  local target = P and P.target
  if not target then return end
  if target.sample then
    Core.MarkTeamIcon(W.sampleMarks, target.key, icon)
    W.Refresh()
  else
    local ok, why = Core.SetTeamIcon(target.unit, icon)
    if not ok then ns.Util.Say(W.WhyText(why)) end
  end
  P:Hide()
end

local function IconButton(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(CELL, CELL)
  b.badge = Core.MakeTeamIcon(b, CELL)
  b.badge:SetAllPoints()
  b.badge:Show()
  b.selected = Core.TokenBorder(b, "accent")
  b.selected:Hide()
  local hover = Theme.Fill(b, "HIGHLIGHT", "white", 0.18)
  hover:SetAllPoints()
  b:SetScript("OnClick", function(self) Pick(self.icon) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    Theme.TipLine(GameTooltip, Core.TeamIconName(self.icon) or "", "text")
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end

local SECTIONS = {
  { title = "highground.teamicons.class.41ff35", icons = function() return Core.TeamIconClasses() end },
  { title = "highground.teamicons.role.c3f104", icons = function() return Core.TEAM_ICON_ROLES end },
  { title = "highground.teamicons.other.6e6a6f", icons = function() return Core.TEAM_ICON_OTHERS end },
}

local function BuildPicker()
  if P then return P end
  P = CreateFrame("Frame", "HighgroundTeamIconPicker", UIParent)
  W.picker = P
  P:SetFrameStrata("DIALOG")
  P:SetClampedToScreen(true)
  P:EnableMouse(true)
  Theme.Backdrop(P)
  P:Hide()
  table.insert(UISpecialFrames, "HighgroundTeamIconPicker")
  local width = COLUMNS * (CELL + PAD) - PAD + Theme.Space("md") * 2
  P.title = Theme.Text(P, "label", "text")
  P.title:SetPoint("TOPLEFT", Theme.Space("md"), -Theme.Space("md"))
  P.title:SetPoint("RIGHT", -Theme.Space("md"), 0)
  P.title:SetJustifyH("LEFT")
  P.buttons = {}
  local y = -Theme.Space("md") - 20
  for _, section in ipairs(SECTIONS) do
    local caption = Kit.Caption(P, ns.Locale:Get(section.title))
    Kit.OnLocale(caption, function(fs) fs:SetText(ns.Text.Upper(ns.Locale:Get(section.title))) end)
    caption:SetPoint("TOPLEFT", Theme.Space("md"), y)
    y = y - 16
    for i, icon in ipairs(section.icons()) do
      local b = IconButton(P)
      b.icon = icon
      Core.PaintTeamIcon(b.badge, icon, 1)
      local col, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
      b:SetPoint("TOPLEFT", Theme.Space("md") + col * (CELL + PAD), y - row * (CELL + PAD))
      P.buttons[#P.buttons + 1] = b
    end
    y = y - math.ceil(#section.icons() / COLUMNS) * (CELL + PAD) - Theme.Space("xs")
  end
  P.none = Kit.Button(P, ns.Locale:Get("highground.teamicons.no_icon.95553b"), (width - Theme.Space("md") * 2 - PAD) / 2)
  ns.Localization.Bind(P.none, "highground.teamicons.no_icon.95553b")
  P.none:SetScript("OnClick", function() Pick(nil) end)
  P.none:SetPoint("TOPLEFT", Theme.Space("md"), y - Theme.Space("xs"))
  P.cancel = Kit.Button(P, ns.Locale:Get("highground.teamicons.cancel.77dfd2"), (width - Theme.Space("md") * 2 - PAD) / 2)
  ns.Localization.Bind(P.cancel, "highground.teamicons.cancel.77dfd2")
  P.cancel:SetScript("OnClick", function() P:Hide() end)
  P.cancel:SetPoint("LEFT", P.none, "RIGHT", PAD, 0)
  P:SetSize(width, -y + Theme.Space("xs") + P.none:GetHeight() + Theme.Space("md"))
  P:SetScript("OnHide", function() P.target = nil end)
  return P
end

-- Open the picker for target { key, name, unit or sample } beside anchor,
-- or at the cursor without one.
function W.OpenPicker(target, anchor)
  local p = BuildPicker()
  p.target = target
  p.title:SetText(target.name or "")
  local current = Marks()[target.key]
  for _, b in ipairs(p.buttons) do b.selected:SetShown(current ~= nil and current.icon == b.icon) end
  p:ClearAllPoints()
  if anchor then
    p:SetPoint("TOPLEFT", anchor, "TOPRIGHT", Theme.Space("sm"), 0)
  else
    local x, y = ns.Util.call(GetCursorPosition)
    local scale = UIParent:GetEffectiveScale()
    if type(x) == "number" and type(y) == "number" and scale > 0 then
      p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    else
      p:SetPoint("CENTER")
    end
  end
  p:Show()
end

function W.PickerShown() return P ~= nil and P:IsShown() end

local WHY = {
  unit = "highground.teamicons.hover_over_or_target_a_player_in.08365c",
}
function W.WhyText(why)
  return Core.TeamIconLockText(why) or ns.Locale:Get(WHY[why] or WHY.unit)
end

-- The player under the mouse, else your target.
function W.Hovered()
  return ns.Util.read(UnitExists, "mouseover") and ns.Util.read(UnitIsPlayer, "mouseover") and "mouseover" or "target"
end

-- The key binding and /hg icon without a name: the picker for the group
-- member under the mouse, else your target.
function W.PickHovered(say)
  return W.PickFor(W.Hovered(), say)
end

function W.PickFor(unit, say)
  say = say or ns.Util.Say
  local lock = Core.TeamIconLock()
  if lock then return say(Core.TeamIconLockText(lock)) end
  local key, member = Core.TeamIconMember(unit)
  if not key then return say(W.WhyText("unit")) end
  -- The group token: the mouse may move on before a click.
  W.OpenPicker({ key = key, unit = member, name = Core.DisplayName(Core.FullUnitName(unit)) })
end

Highground_TeamIcon = function() W.PickHovered() end
ns.Localization.Define(_G, { BINDING_NAME_HIGHGROUND_TEAM_ICON = "highground.teamicons.set_the_team_icon_of_the_group.641459" })

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function Build()
  if W.win then return W.win end
  local w = ns.Localization.BindWidget(Kit.Dialog("HighgroundTeamIcons", { title = ns.Locale:Get("highground.teamicons.team_icons.c632c4"),
    sub = ns.Locale:Get("highground.teamicons.the_group_leader_gives_teammates_icons_so.94af71"),
    width = 400, height = 460, savedKey = "teamIcons",
    onClose = function() W.sample = false; if P then P:Hide() end end }),
    { title = "highground.teamicons.team_icons.c632c4", sub = "highground.teamicons.the_group_leader_gives_teammates_icons_so.94af71" })
  W.win = w
  w.area = Kit.ScrollArea(w.content)
  w.area:SetPoint("TOPLEFT"); w.area:SetPoint("BOTTOMRIGHT", 0, 76)
  w.list = Kit.VirtualList(w.area, { rowHeight = ROW, gap = GAP, inset = 2, max = 40,
    create = function(body)
      local row = Kit.Button(body, "", 200, ROW, { onClick = function(self)
        if self.item and not W.Lock() then
          W.OpenPicker({ key = self.item.key, unit = self.item.unit, name = self.item.name, sample = W.sample }, self)
        end
      end })
      row.badge = Core.MakeTeamIcon(row, BADGE)
      row.badge:SetPoint("LEFT", Theme.Space("md"), 0)
      row.note = Theme.Text(row, "body", "textMuted")
      row.note:SetPoint("RIGHT", -Theme.Space("md"), 0); row.note:SetJustifyH("RIGHT")
      row.label:ClearAllPoints()
      row.label:SetPoint("LEFT", Theme.Space("md") * 2 + BADGE, 0)
      row.label:SetPoint("RIGHT", row.note, "LEFT", -Theme.Space("md"), 0)
      row.label:SetJustifyH("LEFT")
      return row
    end,
    render = function(row, item)
      row.item = item
      local c = item.class and ns.Util.ClassColor(item.class)
      local name = item.name or "?"
      row:SetText(c and c.colorStr and ("|c" .. c.colorStr .. name .. "|r") or name)
      local mark = Marks()[item.key]
      if mark then
        Core.PaintTeamIcon(row.badge, mark.icon, mark.color)
        row.badge:Show()
        row.note:SetText(Core.TeamIconName(mark.icon) or "")
      else
        row.badge:Hide()
        row.note:SetText(ns.Locale:Get("highground.teamicons.no_icon.95553b"))
      end
      if W.Lock() then row:Disable() else row:Enable() end
    end })
  w.empty = Theme.Text(w.content, "body", "textMuted")
  w.empty:SetPoint("TOPLEFT", 0, -8); w.empty:SetPoint("RIGHT"); w.empty:SetJustifyH("LEFT"); w.empty:SetWordWrap(true)
  ns.Localization.Bind(w.empty, "highground.teamicons.no_group_members_yet_join_a_group.52df22")
  w.clear = Kit.ConfirmButton(w.content, { key = "highground.teamicons.clear_all_icons.8c2748" }, {
    width = 200, confirm = { key = "highground.teamicons.click_again_to_clear.074ed4" }, timeout = 4,
    onConfirm = function()
      if W.sample then
        wipe(W.sampleMarks); W.Refresh()
      else
        local ok, why = Core.ClearTeamIcons()
        if not ok then ns.Util.Say(W.WhyText(why)) end
      end
    end })
  w.clear:SetPoint("BOTTOMRIGHT")
  w.hint = Theme.Text(w.content, "body", "textMuted")
  w.hint:SetPoint("BOTTOMLEFT", 0, w.clear:GetHeight() + Theme.Space("md")); w.hint:SetPoint("RIGHT")
  w.hint:SetJustifyH("LEFT"); w.hint:SetWordWrap(true)
  return w
end

function W.Refresh()
  local w = W.win
  if not (w and w:IsShown()) then return end
  local items = Items()
  w.empty:SetShown(#items == 0)
  local lock = W.Lock()
  if W.sample then
    ns.Localization.Bind(w.hint, "highground.teamicons.sample_teammates_icons_chosen_here_are_not.06e2be")
  elseif lock then
    w.hint:SetText(Core.TeamIconLockText(lock))
  else
    ns.Localization.Bind(w.hint, "highground.teamicons.click_a_teammate_to_choose_their_icon.6bb61f")
  end
  w.clear:SetEnabled(not lock and next(Marks()) ~= nil)
  w.list:SetItems(items)
  w.list:Render()
  if lock and P and P:IsShown() and not (P.target and P.target.sample) then P:Hide() end
end
Core.RefreshTeamIcons = W.Refresh

function W.Open(sample)
  local w = Build()
  W.sample = sample and true or false
  if W.sample then W.samples, W.sampleMarks = Samples() end
  Kit.Windows.Show(w)
  W.Refresh()
end

function W.Close()
  if W.win then W.win:Hide() end
end

function W.IsSample() return W.sample == true and W.win ~= nil and W.win:IsShown() end
