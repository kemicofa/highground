local _, ns = ...
local Core, Commands = ns.Core, ns.Commands

-- Team icon commands (core/TeamIcons.lua, ui/TeamIcons.lua).
-- /hg icon [NAME] [ICON|none|clear]: give a group member an icon; none
-- hides it even under an automatic rule, clear gives back the automatic
-- icon. Without an icon, open the picker. The member is the one named,
-- else under the mouse, else your target.
function Commands.icon(arg, msg, say)
  local rest = msg:match("^%S+%s+(.-)%s*$") or ""
  local last = rest:match("(%S+)$")
  local icon = Core.TeamIconFromText(last)
  local clear = last ~= nil and last:lower() == "clear"
  local name = (icon or clear) and rest:sub(1, #rest - #last):match("^(.-)%s*$") or rest
  local unit
  if name ~= "" then
    unit = Core.TeamUnitByName(name)
    if not unit then
      say(ns.Locale:Format("highground.display.no_teammate_named_name.0a00e4", { name = name }))
      if name:find("%s") then say(ns.Locale:Format("highground.display.icons_icons.0c96a5", { icons = table.concat(Core.TeamIconChoices(), ", ") })) end
      return
    end
  end
  if not (icon or clear) then
    if unit then return ns.TeamIcons.PickFor(unit, say) end
    return ns.TeamIcons.PickHovered(say)
  end
  unit = unit or ns.TeamIcons.Hovered()
  local ok, why = Core.SetTeamIcon(unit, icon)
  if not ok then return say(ns.TeamIcons.WhyText(why)) end
  local who = Core.DisplayName(Core.FullUnitName(unit))
  if icon and icon ~= "none" then
    say(ns.Locale:Format("highground.display.name_now_has_the_icon_team_icon.f55bd4", { name = who, icon = Core.TeamIconName(icon) }))
  elseif clear and Core.TeamIconRule() then
    say(ns.Locale:Format("highground.display.name_gets_the_automatic_team_icon_now.aa0688", { name = who }))
  else
    say(ns.Locale:Format("highground.display.name_has_no_team_icon_now.17a3a9", { name = who }))
  end
end

local RULES = { off = true, class = true, role = true }

-- /hg icons: the Team icons window; test: its sample; clear: every icon;
-- auto off|class|role: the automatic rule.
function Commands.icons(arg, msg, say)
  if arg == "test" then
    if ns.TeamIcons.IsSample() then
      ns.TeamIcons.Close()
      return say(ns.Locale:Get("highground.display.team_icons_sample_off.50c06c"))
    end
    ns.TeamIcons.Open(true)
    return say(ns.Locale:Get("highground.display.team_icons_sample_on.66a89f"))
  elseif arg == "clear" then
    local ok, why = Core.ClearTeamIcons()
    return say(ok and ns.Locale:Get("highground.display.team_icons_cleared.7f5c5a") or ns.TeamIcons.WhyText(why))
  elseif arg:match("^auto") then
    local rule = arg:match("^auto%s+(%S+)$") or ""
    if not RULES[rule] then return say(ns.Locale:Get("highground.display.use_hg_icons_auto_off_class_or.b77ca6")) end
    local ok, why = Core.SetTeamIconRule(rule ~= "off" and rule or nil)
    if not ok then return say(ns.TeamIcons.WhyText(why)) end
    return say(rule == "off" and ns.Locale:Get("highground.display.automatic_team_icons_off.547723")
      or ns.Locale:Format("highground.display.automatic_team_icons_rule.2fa1da", { rule = Core.TeamIconRuleName(rule) }))
  end
  ns.TeamIcons.Open()
end
