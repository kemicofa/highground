local _, ns = ...
local Core, Kit, Theme = ns.Core, ns.Kit, ns.Theme

---------------------------------------------------------------------------
-- Team icons window (/hg icons): the automatic rule, then one row per
-- group member with their icon. The group leader clicks a row to choose
-- an icon in the picker (ui/TeamIconPicker.lua); everyone else sees the
-- icons and why they can't change them. The picker also opens at the
-- cursor from the Set team icon key and /hg icon. /hg icons test shows
-- sample teammates whose icons and rule stay in the window.
---------------------------------------------------------------------------
local W = { items = {}, units = {}, list = {}, sampleResolved = {} }
ns.TeamIcons = W
local ROW, GAP, BADGE = 30, 4, 22
local Picker = ns.TeamIconPicker

-- Sample teammates: two with the same icon show the second outline colour.
local function Samples()
  local marks = {}
  local list = {
    { key = "sample:Brann", name = "Brann", class = "WARRIOR", role = "tank", icon = "flag" },
    { key = "sample:Lunara", name = "Lunara", class = "PRIEST", role = "healer", icon = "healer" },
    { key = "sample:Thornik", name = "Thornik", class = "SHAMAN", role = "healer", icon = "healer" },
    { key = "sample:Sylra", name = "Sylra", class = "DRUID", role = "caster", icon = "DRUID" },
    { key = "sample:Kael", name = "Kael", class = "MAGE", role = "caster", icon = "squadA" },
    { key = "sample:Vex", name = "Vex", class = "ROGUE", role = "melee" },
  }
  for _, item in ipairs(list) do
    if item.icon then Core.MarkTeamIcon(marks, item.key, item.icon) end
  end
  return list, marks
end

-- The rule, hand marks and icons on show: the sample's or your group's.
local function Rule()
  if W.sample then return W.sampleRule end
  return Core.TeamIconRule()
end
local function HandMarks()
  if W.sample then return W.sampleMarks end
  return Core.TeamIconMarks()
end
function W.Icons()
  if not W.sample then return Core.TeamIconsResolved() end
  local rule = W.sampleRule
  wipe(W.list)
  for i, item in ipairs(W.samples) do
    W.list[i] = { key = item.key, auto = rule == "class" and item.class or rule == "role" and item.role or nil }
  end
  return Core.ResolveTeamIcons(W.sampleResolved, W.sampleMarks, W.list)
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

local WHY = {
  unit = "highground.teamicons.hover_over_or_target_a_player_in.08365c",
}
function W.WhyText(why)
  return Core.TeamIconLockText(why) or ns.Locale:Get(WHY[why] or WHY.unit)
end

-- Open the picker for a row's teammate (or a sample) beside anchor, or at
-- the cursor. A choice is saved and sent like /hg icon.
function W.OpenPicker(target, anchor)
  local current = W.Icons()[target.key]
  Picker.Open(target.name, current and not current.auto and current.icon or nil, Rule() ~= nil, function(icon)
    if target.sample then
      Core.MarkTeamIcon(W.sampleMarks, target.key, icon)
      W.Refresh()
    else
      local ok, why = Core.SetTeamIcon(target.unit, icon)
      if not ok then ns.Util.Say(W.WhyText(why)) end
    end
  end, anchor)
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

-- Change the automatic rule from the window: "off", "class" or "role".
local function SetRule(key)
  local rule = key ~= "off" and key or nil
  if W.sample then
    W.sampleRule = rule
    return W.Refresh()
  end
  local ok, why = Core.SetTeamIconRule(rule)
  if not ok then ns.Util.Say(W.WhyText(why)); W.Refresh() end
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local RULES = {
  { key = "off", label = { key = "highground.teamicons.off.e3de5a" } },
  { key = "class", label = { key = "highground.teamicons.class.41ff35" },
    tooltip = { key = "highground.teamicons.every_teammate_without_an_icon_from_the.cd98bd" } },
  { key = "role", label = { key = "highground.teamicons.role.c3f104" },
    tooltip = { key = "highground.teamicons.every_teammate_without_an_icon_from_the.eb2c47" } },
}

local function Build()
  if W.win then return W.win end
  local w = ns.Localization.BindWidget(Kit.Dialog("HighgroundTeamIcons", { title = ns.Locale:Get("highground.teamicons.team_icons.c632c4"),
    sub = ns.Locale:Get("highground.teamicons.the_group_leader_gives_teammates_icons_so.94af71"),
    width = 400, height = 500, savedKey = "teamIcons",
    onClose = function() W.sample = false; Picker.Hide() end }),
    { title = "highground.teamicons.team_icons.c632c4", sub = "highground.teamicons.the_group_leader_gives_teammates_icons_so.94af71" })
  W.win = w
  w.ruleLabel = Theme.Text(w.content, "label", "textMuted")
  w.ruleLabel:SetPoint("TOPLEFT"); w.ruleLabel:SetJustifyH("LEFT")
  ns.Localization.Bind(w.ruleLabel, "highground.teamicons.automatic_icons.8850b6")
  w.rule = Kit.Segmented(w.content, { choices = RULES, value = "off", onChange = function(_, key) SetRule(key) end })
  w.rule:SetPoint("TOPLEFT", w.ruleLabel, "BOTTOMLEFT", 0, -Theme.Space("xs"))
  w.rule:Layout(360)
  w.area = Kit.ScrollArea(w.content)
  w.area:SetPoint("TOPLEFT", w.rule, "BOTTOMLEFT", 0, -Theme.Space("md")); w.area:SetPoint("BOTTOMRIGHT", 0, 76)
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
      local icon = W.Icons()[item.key]
      if icon then
        Core.PaintTeamIcon(row.badge, icon.icon, icon.color)
        row.badge:Show()
        local label = Core.TeamIconName(icon.icon) or ""
        row.note:SetText(icon.auto and ns.Locale:Format("highground.teamicons.icon_automatic.107c7d", { icon = label }) or label)
      else
        row.badge:Hide()
        row.note:SetText(ns.Locale:Get("highground.teamicons.no_icon.95553b"))
      end
      if W.Lock() then row:Disable() else row:Enable() end
    end })
  w.empty = Theme.Text(w.content, "body", "textMuted")
  w.empty:SetPoint("TOPLEFT", w.area, "TOPLEFT", 0, -8); w.empty:SetPoint("RIGHT"); w.empty:SetJustifyH("LEFT"); w.empty:SetWordWrap(true)
  ns.Localization.Bind(w.empty, "highground.teamicons.no_group_members_yet_join_a_group.52df22")
  w.clear = Kit.ConfirmButton(w.content, { key = "highground.teamicons.clear_all_icons.8c2748" }, {
    width = 200, confirm = { key = "highground.teamicons.click_again_to_clear.074ed4" }, timeout = 4,
    onConfirm = function()
      if W.sample then
        wipe(W.sampleMarks); W.sampleRule = nil; W.Refresh()
      else
        local ok, why = Core.ClearTeamIcons()
        if not ok then ns.Util.Say(W.WhyText(why)) end
      end
    end })
  w.clear:SetPoint("BOTTOMRIGHT")
  w.panel = Kit.Button(w.content, ns.Locale:Get("highground.teamicons.quick_panel.bec970"), 140, nil, { onClick = function() ns.TeamIconPanel.Toggle() end })
  ns.Localization.Bind(w.panel, "highground.teamicons.quick_panel.bec970")
  w.panel:SetPoint("BOTTOMLEFT")
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
    ns.Localization.Bind(w.hint, "highground.teamicons.click_a_teammate_to_choose_their_icon.aec23b")
  end
  w.rule:SetValue(Rule() or "off", true)
  for _, choice in ipairs(RULES) do w.rule:SetEnabled(choice.key, not lock) end
  w.clear:SetEnabled(not lock and (next(HandMarks()) ~= nil or Rule() ~= nil))
  w.list:SetItems(items)
  w.list:Render()
  if lock and not W.sample then Picker.Hide() end
end
Core.RefreshTeamIcons = W.Refresh

function W.Open(sample)
  local w = Build()
  W.sample = sample and true or false
  if W.sample then W.samples, W.sampleMarks = Samples(); W.sampleRule = nil end
  Kit.Windows.Show(w)
  W.Refresh()
end

function W.Close()
  if W.win then W.win:Hide() end
end

function W.IsSample() return W.sample == true and W.win ~= nil and W.win:IsShown() end
function W.PickerShown() return Picker.Shown() end
