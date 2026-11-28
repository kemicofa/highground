local _, ns = ...
local Core = ns.Core
local Read, Call = ns.Util.read, ns.Util.call

---------------------------------------------------------------------------
-- Team icons: the group leader gives teammates an icon so they are easy to
-- find, above all in a battleground among strangers. An icon is a class
-- icon or one of Highground's symbols; none of them means anything to
-- Highground. Teammates with the same icon get their own outline colour.
-- Only the leader of your own group changes icons, and never in a match:
-- the game blocks addon messages there, so teammates wouldn't see it.
-- The leader's client sends them to the group (core/TeamIconShare.lua);
-- everyone keeps them per region until they leave the group, so they last
-- through a /reload and into a battleground. An automatic rule can give
-- everyone else an icon (core/TeamIconRules.lua).
-- Drawn by ui/TeamIconMarks.lua; the window and picker: ui/TeamIcons.lua.
---------------------------------------------------------------------------
Core.TEAM_ICON_SHEET = "Interface\\AddOns\\Highground\\assets\\teamicons\\TeamIcons.tga"
Core.TEAM_ICON_RING = "Interface\\AddOns\\Highground\\assets\\teamicons\\TeamIconRing.tga"
Core.TEAM_ICON_MAX_AGE = 86400 -- seconds; older icons are dropped at login

-- Highground's symbols in sheet order (tools/team_icons.py), 4 per row.
local SYMBOLS = { "tank", "healer", "melee", "caster", "flag", "escort", "defense", "offense",
  "caller", "peel", "scout", "focus", "squadA", "squadB", "squadC", "squadD" }
local CELL = {}
for i, id in ipairs(SYMBOLS) do CELL[id] = i - 1 end
Core.TEAM_ICON_ROLES = { "tank", "healer", "melee", "caster" }
Core.TEAM_ICON_OTHERS = { "flag", "escort", "defense", "offense", "caller", "peel", "scout", "focus",
  "squadA", "squadB", "squadC", "squadD" }

local NAMES = {
  tank = "highground.teamicons.tank.0ba4d1",
  healer = "highground.teamicons.healer.6cad85",
  melee = "highground.teamicons.melee.e00694",
  caster = "highground.teamicons.caster.9c060f",
  flag = "highground.teamicons.flag_carrier.9e4a71",
  escort = "highground.teamicons.escort.02e79d",
  defense = "highground.teamicons.defense.3c284a",
  offense = "highground.teamicons.offense.c1015f",
  caller = "highground.teamicons.caller.3fda6d",
  peel = "highground.teamicons.peel.bd47b4",
  scout = "highground.teamicons.scout.56be36",
  focus = "highground.teamicons.focus.fe7f55",
  squadA = "highground.teamicons.squad_a.e4142f",
  squadB = "highground.teamicons.squad_b.22e773",
  squadC = "highground.teamicons.squad_c.1e1a24",
  squadD = "highground.teamicons.squad_d.f78de1",
}

-- Outline colour tokens, in the order teammates with the same icon get them.
Core.TEAM_ICON_COLORS = { "teamIcon1", "teamIcon2", "teamIcon3", "teamIcon4",
  "teamIcon5", "teamIcon6", "teamIcon7", "teamIcon8" }

function Core.TeamIconColor(index)
  local colors = Core.TEAM_ICON_COLORS
  return colors[((index or 1) - 1) % #colors + 1]
end

-- Class tokens this game has, in class order; built on first use.
local classes, classSet
function Core.TeamIconClasses()
  if not classes then
    classes, classSet = {}, {}
    for _, id in ipairs(ns.ClassIDs or {}) do
      local _, file = Call(GetClassInfo, id)
      if Core.plain(file) and type(file) == "string" and not classSet[file] then
        classes[#classes + 1], classSet[file] = file, true
      end
    end
  end
  return classes
end

-- The sheet cell (0-15) of a symbol; nil for a class icon.
function Core.TeamIconCell(icon) return CELL[icon] end

-- "none" is a hand mark meaning no icon, even with an automatic rule.
function Core.ValidTeamIcon(icon)
  if CELL[icon] or icon == "none" then return true end
  Core.TeamIconClasses()
  return type(icon) == "string" and classSet[icon] == true
end

function Core.TeamIconName(icon)
  if icon == "none" then return ns.Locale:Get("highground.teamicons.no_icon.95553b") end
  if NAMES[icon] then return ns.Locale:Get(NAMES[icon]) end
  if Core.ValidTeamIcon(icon) then return ns.Util.ClassName(icon) end
end

-- The icon a command names: a symbol or class in English ("tank",
-- "squadA", "warrior"), any case; nil when there is none.
function Core.TeamIconFromText(text)
  if type(text) ~= "string" or text == "" then return end
  local want = text:lower()
  if want == "none" then return "none" end
  for _, id in ipairs(SYMBOLS) do
    if id:lower() == want then return id end
  end
  for _, class in ipairs(Core.TeamIconClasses()) do
    if class:lower() == want then return class end
  end
end

-- Every icon's command name: classes, roles, then the others.
function Core.TeamIconChoices()
  local codes = {}
  for _, class in ipairs(Core.TeamIconClasses()) do codes[#codes + 1] = class:lower() end
  for _, id in ipairs(SYMBOLS) do codes[#codes + 1] = id:lower() end
  return codes
end

---------------------------------------------------------------------------
-- Saved icons
--   teamIcons = { marks = { [key] = { icon, color, t } }, rule = "class"|"role"|nil,
--     rev = n, from = leader key, t = time(), offered = true once the quick panel appeared }
-- marks are the leader's hand marks; rule gives everyone else an icon.
-- rev counts the leader's changes; from is whoever set them last.
---------------------------------------------------------------------------
local EMPTY = {}
Core.TEAM_ICON_RULES = { class = true, role = true }

local function Store()
  local s = ns.Scope.Saved("teamIcons", "social")
  if type(s.marks) ~= "table" then s.marks = {} end
  return s
end

-- Player key -> { icon, color, t }: the hand marks. Read-only for callers.
function Core.TeamIconMarks()
  if not Core.db then return EMPTY end
  return Store().marks
end

-- The automatic rule: "class", "role" or nil.
function Core.TeamIconRule()
  local rule = Core.db and Store().rule
  if Core.TEAM_ICON_RULES[rule] then return rule end
end

local RULE_NAMES = { class = "highground.teamicons.class.41ff35", role = "highground.teamicons.role.c3f104" }
function Core.TeamIconRuleName(rule)
  return RULE_NAMES[rule] and ns.Locale:Get(RULE_NAMES[rule])
end

-- What the leader sends: change count, rule and hand marks.
function Core.TeamIconState()
  local s = Store()
  return tonumber(s.rev) or 0, Core.TeamIconRule(), s.marks
end

local function Changed()
  if Core.InvalidateTeamIcons then Core.InvalidateTeamIcons() end
  if Core.UpdateTeamIconMarks then Core.UpdateTeamIconMarks() end
  if Core.RefreshTeamIcons then Core.RefreshTeamIcons() end
end
Core.TeamIconsChanged = Changed

-- A change by you, the leader: counted, then sent to the group.
local function Edited()
  local s = Store()
  s.rev, s.from, s.t = (tonumber(s.rev) or 0) + 1, Core.TeamKey("player"), time()
  Changed()
  if Core.ShareTeamIcons then Core.ShareTeamIcons() end
end

-- The group leader's icons arrived: they replace yours.
function Core.ReplaceTeamIcons(from, rule, marks)
  local s = Store()
  s.marks, s.rule, s.from, s.t = marks, Core.TEAM_ICON_RULES[rule] and rule or nil, from, time()
  Changed()
end

-- The lowest outline colour no other teammate with this icon has; past
-- the last colour they repeat.
local function FreeColor(marks, icon, key)
  local used, count = {}, 0
  for k, m in pairs(marks) do
    if k ~= key and m.icon == icon then used[m.color or 1], count = true, count + 1 end
  end
  for i = 1, #Core.TEAM_ICON_COLORS do
    if not used[i] then return i end
  end
  return count % #Core.TEAM_ICON_COLORS + 1
end

-- Put an icon (nil clears it) on key in any marks table: the saved one or
-- a sample. A teammate keeps their colour while their icon stays the same.
function Core.MarkTeamIcon(marks, key, icon)
  local old = marks[key]
  if icon == nil then marks[key] = nil; return end
  local color = old and old.icon == icon and old.color or FreeColor(marks, icon, key)
  marks[key] = { icon = icon, color = color, t = time() }
end

---------------------------------------------------------------------------
-- Who may change icons
---------------------------------------------------------------------------
local LOCKS = {
  match = "highground.teamicons.team_icons_can_t_change_during_a.e8eec6",
  blocked = "highground.teamicons.the_game_is_blocking_addon_messages_right.c6757e",
  group = "highground.teamicons.join_a_group_to_give_teammates_icons.6bc226",
  leader = "highground.teamicons.only_your_group_leader_can_change_team.eb8d68",
}

-- Why you can't change icons now, else nil: "match" (a battleground or
-- arena), "blocked" (the game blocks addon messages), "group" (not in a
-- group) or "leader" (someone else leads). Raid assistants can't either.
function Core.TeamIconLock()
  local _, kind = Call(IsInInstance)
  if kind == "pvp" or kind == "arena" then return "match" end
  if ns.Comms.Blocked() then return "blocked" end
  if Read(IsInGroup, LE_PARTY_CATEGORY_HOME) ~= true then return "group" end
  if Read(UnitIsGroupLeader, "player", LE_PARTY_CATEGORY_HOME) ~= true then return "leader" end
end

function Core.TeamIconLockText(lock)
  return LOCKS[lock] and ns.Locale:Get(LOCKS[lock])
end

-- Your group's members: player key -> unit token, you included.
local members, units = {}, {}
function Core.TeamIconMembers()
  wipe(members)
  for _, unit in ipairs(Core.TeamUnits(units)) do
    local key = Core.TeamKey(unit)
    if key then members[key] = unit end
  end
  return members
end

-- The group member a unit token names: their player key and group token;
-- nil when the unit is no player in your group.
function Core.TeamIconMember(unit)
  if not unit or Read(UnitIsPlayer, unit) ~= true then return end
  local key = Core.CanonUnit(unit)
  local member = key and Core.TeamIconMembers()[key]
  if member then return key, member end
end

-- Give a teammate an icon, "none" (no icon, even with a rule), or clear
-- their hand mark (icon nil). Returns true, else nil and why: a lock
-- (Core.TeamIconLock), "unit" (no player in your group) or "icon".
function Core.SetTeamIcon(unit, icon)
  if icon ~= nil and not Core.ValidTeamIcon(icon) then return nil, "icon" end
  local lock = Core.TeamIconLock()
  if lock then return nil, lock end
  local key = Core.TeamIconMember(unit)
  if not key then return nil, "unit" end
  Core.MarkTeamIcon(Store().marks, key, icon)
  Edited()
  return true
end

-- Choose the automatic rule: "class", "role" or nil (off).
function Core.SetTeamIconRule(rule)
  if rule ~= nil and not Core.TEAM_ICON_RULES[rule] then return nil, "rule" end
  local lock = Core.TeamIconLock()
  if lock then return nil, lock end
  Store().rule = rule
  Edited()
  return true
end

-- Clear every icon: hand marks and the automatic rule.
function Core.ClearTeamIcons()
  local lock = Core.TeamIconLock()
  if lock then return nil, lock end
  local s = Store()
  wipe(s.marks)
  s.rule = nil
  Edited()
  return true
end

-- Whether the quick panel (ui/TeamIconPanel.lua) appeared for this group.
function Core.TeamIconOffered() return Core.db ~= nil and Store().offered == true end
function Core.SetTeamIconOffered() Store().offered = true end

local function Forget()
  local s = Store()
  local had = next(s.marks) ~= nil or s.rule ~= nil
  wipe(s.marks)
  s.rule, s.from, s.t, s.offered = nil, nil, nil, nil
  if had then Changed() end
end

-- Leaving your own group drops its icons. Leaving a battleground's group
-- does not.
local function Left(category)
  if not Core.db or category ~= nil and LE_PARTY_CATEGORY_HOME and category ~= LE_PARTY_CATEGORY_HOME then return end
  if Read(IsInGroup, LE_PARTY_CATEGORY_HOME) == true then return end
  Forget()
end

-- At login: icons from more than a day ago belong to another session.
local function Prune()
  if not Core.db then return end
  local s, now = Store(), time()
  if now - (tonumber(s.t) or 0) > Core.TEAM_ICON_MAX_AGE then return Forget() end
  for key, m in pairs(s.marks) do
    if type(m) ~= "table" or not Core.ValidTeamIcon(m.icon) then s.marks[key] = nil end
  end
end

ns.Util.Events({
  PLAYER_ENTERING_WORLD = function(_, login) if login then Prune() end; Changed() end,
  GROUP_LEFT = function(_, category) Left(category) end,
  GROUP_ROSTER_UPDATE = Changed,
  -- A group member's name became readable; nameplates' names don't matter.
  UNIT_NAME_UPDATE = function(_, unit)
    if type(unit) == "string" and (unit:find("^raid%d") or unit:find("^party%d")) then Changed() end
  end,
  PLAYER_ROLES_ASSIGNED = Changed,
  PARTY_LEADER_CHANGED = function() if Core.RefreshTeamIcons then Core.RefreshTeamIcons() end end,
}, "team icons", "battlegrounds")
