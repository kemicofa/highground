local _, ns = ...
local Core, Kit, Theme = ns.Core, ns.Kit, ns.Theme

---------------------------------------------------------------------------
-- Team healers window (/hg healers): one row per teammate whose class can
-- heal. A click marks or unmarks them by hand (core/HealerTags.lua); the
-- note says how Highground knows. /hg healers test shows sample teammates
-- whose marks stay in the window.
---------------------------------------------------------------------------
local W = { items = {}, units = {} }
ns.TeamHealers = W
local ROW, GAP = 30, 4

-- Sample teammates: one per kind of note.
local function Samples()
  local function spec(class, tree) return Core.classSpecs[class] and Core.classSpecs[class][tree] end
  return {
    { key = "sample:Lunara", name = "Lunara", class = "PRIEST", healer = true, by = "inspect", spec = spec("PRIEST", 2) },
    { key = "sample:Brann", name = "Brann", class = "PALADIN", healer = true, by = "hand" },
    { key = "sample:Thornik", name = "Thornik", class = "SHAMAN", healer = false, by = "inspect", spec = spec("SHAMAN", 2) },
    { key = "sample:Sylra", name = "Sylra", class = "DRUID", healer = false },
  }
end

local function Note(item)
  if item.by == "role" then return ns.Locale:Get("highground.teamhealers.group_role.76d76e") end
  if item.by == "self" then return ns.Locale:Get("highground.teamhealers.your_talents.1fc82b") end
  if item.by == "hand" then return ns.Locale:Get("highground.teamhealers.your_mark.7d21c5") end
  local info = item.spec and Core.specInfo[item.spec]
  if item.by == "inspect" and info then return ns.Locale:Format("highground.teamhealers.inspected_spec.4296a4", { spec = info.name }) end
  return ns.Locale:Get("highground.teamhealers.not_known_yet.72369a")
end

local function Items()
  wipe(W.items)
  if W.sample then
    for _, item in ipairs(W.samples) do W.items[#W.items + 1] = item end
    return W.items
  end
  for _, unit in ipairs(Core.TeamUnits(W.units)) do
    local _, class = ns.Util.call(UnitClass, unit)
    if Core.plain(class) and Core.HealerClass(class) then
      local key = Core.TeamKey(unit)
      local healer, by = Core.TeamHealer(unit, key)
      local tag = Core.HealerTag(key)
      W.items[#W.items + 1] = { unit = unit, name = Core.DisplayName(Core.FullUnitName(unit)), class = class,
        healer = healer, by = by, spec = tag and tag.spec }
    end
  end
  return W.items
end

local function Toggle(item)
  if W.sample then
    item.healer, item.by = not item.healer, "hand"
    W.Refresh()
  elseif item.unit then
    Core.SetTeamHealer(item.unit, not item.healer)
  end
end

local function Build()
  if W.win then return W.win end
  local w = ns.Localization.BindWidget(Kit.Dialog("HighgroundTeamHealers", { title = ns.Locale:Get("highground.teamhealers.team_healers.68a1c6"),
    sub = ns.Locale:Get("highground.teamhealers.click_a_teammate_to_mark_or_unmark.7d532d"), width = 380, height = 420, savedKey = "teamHealers",
    onClose = function() W.sample = false end }),
    { title = "highground.teamhealers.team_healers.68a1c6", sub = "highground.teamhealers.click_a_teammate_to_mark_or_unmark.7d532d" })
  W.win = w
  w.area = Kit.ScrollArea(w.content)
  w.area:SetPoint("TOPLEFT"); w.area:SetPoint("BOTTOMRIGHT", 0, 52)
  w.list = Kit.VirtualList(w.area, { rowHeight = ROW, gap = GAP, inset = 2, max = 24,
    create = function(body)
      local row = Kit.Choice(body, "", 200, "check", function(self) if self.item then Toggle(self.item) end end)
      row.note = Theme.Text(row, "body", "textMuted")
      row.note:SetPoint("RIGHT", -Theme.Space("md"), 0); row.note:SetJustifyH("RIGHT")
      row.label:SetPoint("RIGHT", row.note, "LEFT", -Theme.Space("md"), 0)
      return row
    end,
    render = function(row, item)
      row.item = item
      local c = ns.Util.ClassColor(item.class)
      row:SetText(c and c.colorStr and ("|c" .. c.colorStr .. item.name .. "|r") or item.name)
      row.note:SetText(Note(item))
      row:SetSelected(item.healer)
      if item.by == "role" then row:Disable() else row:Enable() end
    end })
  w.empty = Theme.Text(w.content, "body", "textMuted")
  w.empty:SetPoint("TOPLEFT", 0, -8); w.empty:SetPoint("RIGHT"); w.empty:SetJustifyH("LEFT"); w.empty:SetWordWrap(true)
  ns.Localization.Bind(w.empty, "highground.teamhealers.no_teammates_who_can_heal_join_a.642ada")
  w.hint = Theme.Text(w.content, "body", "textMuted")
  w.hint:SetPoint("BOTTOMLEFT"); w.hint:SetPoint("RIGHT"); w.hint:SetJustifyH("LEFT"); w.hint:SetWordWrap(true)
  return w
end

function W.Refresh()
  local w = W.win
  if not (w and w:IsShown()) then return end
  local items = Items()
  w.empty:SetShown(#items == 0)
  ns.Localization.Bind(w.hint, W.sample and "highground.teamhealers.sample_teammates_marks_made_here_are_not.b2932a"
    or "highground.teamhealers.hover_over_a_teammate_and_press_your.c97e8a")
  w.list:SetItems(items)
  w.list:Render()
end
Core.RefreshTeamHealers = W.Refresh

function W.Open(sample)
  local w = Build()
  W.sample = sample and true or false
  if W.sample then W.samples = Samples() end
  Kit.Windows.Show(w)
  W.Refresh()
end

function W.Close()
  if W.win then W.win:Hide() end
end

function W.IsSample() return W.sample == true and W.win ~= nil and W.win:IsShown() end
