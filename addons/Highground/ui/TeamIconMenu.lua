local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Team icon in group members' right-click menus (Retail and WoW Forever
-- menus): the four roles at once, then Other and Class submenus, No icon,
-- Automatic under a rule, and Open Team icons. Only the group leader sees
-- it, and only where Util.Restricted() can't let it break the menu: never
-- in a match or in combat (see core/TeamIcons.lua for the other locks).
---------------------------------------------------------------------------
local TAGS = { "MENU_UNIT_SELF", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID",
  "MENU_UNIT_PLAYER", "MENU_UNIT_TARGET", "MENU_UNIT_FOCUS" }
local SIZE = 16

-- "|T…|t Name" for a symbol, "|A…|a Name" for a class whose atlas exists.
local function Label(icon)
  local name = Core.TeamIconName(icon) or icon
  local cell = Core.TeamIconCell(icon)
  if cell then
    local x, y = cell % 4 * 64, math.floor(cell / 4) * 64
    return string.format("|T%s:%d:%d:0:0:256:256:%d:%d:%d:%d|t %s", Core.TEAM_ICON_SHEET, SIZE, SIZE, x, x + 64, y, y + 64, name)
  end
  local atlas = "classicon-" .. icon:lower()
  local lookup = ns.Api.Fn("C_Texture", "GetAtlasInfo")
  if ns.Util.call(lookup, atlas) then return string.format("|A:%s:%d:%d|a %s", atlas, SIZE, SIZE, name) end
  return name
end

local function Set(unit, icon)
  return function()
    local ok, why = Core.SetTeamIcon(unit, icon)
    if not ok then ns.Util.Say(ns.TeamIcons.WhyText(why)) end
  end
end

local function Group(parent, key, icons, unit)
  local sub = parent:CreateButton(ns.Locale:Get(key))
  for _, icon in ipairs(icons) do sub:CreateButton(Label(icon), Set(unit, icon)) end
end

-- The Team icon entry for a menu about unit; nothing when you can't use it.
function Core.AddTeamIconMenu(root, unit)
  if not (Core.db and Core.On("teamIcons")) or ns.Util.Restricted() or Core.TeamIconLock() then return end
  local _, member = Core.TeamIconMember(unit)
  if not member then return end
  local rule = Core.TeamIconRule()
  root:CreateDivider()
  local menu = root:CreateButton(ns.Locale:Get("highground.teamicons.team_icon.55f17f"))
  for _, icon in ipairs(Core.TEAM_ICON_ROLES) do menu:CreateButton(Label(icon), Set(member, icon)) end
  Group(menu, "highground.teamicons.other.6e6a6f", Core.TEAM_ICON_OTHERS, member)
  Group(menu, "highground.teamicons.class.41ff35", Core.TeamIconClasses(), member)
  menu:CreateDivider()
  menu:CreateButton(ns.Locale:Get("highground.teamicons.no_icon.95553b"), Set(member, rule and "none" or nil))
  if rule then menu:CreateButton(ns.Locale:Get("highground.teamicons.automatic.ac9041"), Set(member, nil)) end
  menu:CreateButton(ns.Locale:Get("tools.open.teamicons"), function() ns.TeamIcons.Open() end)
end

local installed = false
local function Install()
  if installed or not (Menu and Menu.ModifyMenu) then return end
  installed = true
  for _, tag in ipairs(TAGS) do
    pcall(Menu.ModifyMenu, tag, function(_, root, context)
      local unit = context and context.unit
      if unit then ns.Util.Guard("team icon menu", Core.AddTeamIconMenu, root, unit) end
    end)
  end
end

ns.Util.Events({ PLAYER_LOGIN = Install }, "team icon menu", "battlegrounds")
if IsLoggedIn and IsLoggedIn() and ns.Util.ModuleEnabled("battlegrounds") then Install() end
