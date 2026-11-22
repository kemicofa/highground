local _, ns = ...
local W, U = ns.Reputation, ns.Util
local TAGS = { "PLAYER", "ENEMY_PLAYER", "PARTY", "RAID_PLAYER", "FRIEND", "FRIEND_OFFLINE", "GUILD", "CHAT_ROSTER" }

function W.MenuTarget(context)
  if type(context) ~= "table" then return end
  local unit = U.value(context.unit)
  if type(unit) == "string" then return W.Unit(unit) end
  return W.Target(U.value(context.name), U.value(context.server), U.value(context.guid), true)
end

function W.MenuEntries(context)
  local target = W.MenuTarget(context)
  if not target then return {} end
  target = W.Copy(target) -- the player may change targets before clicking
  local c = W.Get()
  if not W.Joined(c) then c = W.List()[1] end
  local own = c and W.OwnReport(c, target)
  local entries = { { text = own and ns.Locale:Get("reputation.menus.edit_your_report.d57ff8") or W.CanModerate(c) and ns.Locale:Get("reputation.menus.add_to_blacklist.214e95") or ns.Locale:Get("reputation.menus.report_player.4fb75f"),
    run = function() W.OpenReport(target, c) end } }
  local match = W.Match(target)
  if match then
    entries[#entries + 1] = { text = ns.Locale:Get("reputation.menus.view_blacklist_entry.81924c"), run = function() W.OpenDetails(match.community, match.row) end }
  end
  return entries
end

function W.InstallMenus()
  if ns.STANDBY or W.menusInstalled then return end
  if Menu and Menu.ModifyMenu then
    for _, tag in ipairs(TAGS) do
      Menu.ModifyMenu("MENU_UNIT_" .. tag, function(_, root, context)
        if not W.ready then return end
        local entries = W.MenuEntries(context)
        if #entries == 0 then return end
        root:CreateDivider()
        local menu = root:CreateButton(ns.Locale:Get("reputation.menus.highground_reputation.371b59"))
        for _, entry in ipairs(entries) do menu:CreateButton(entry.text, entry.run) end
      end)
    end
    W.menusInstalled = true
  elseif UnitPopup_ShowMenu and hooksecurefunc and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
    hooksecurefunc("UnitPopup_ShowMenu", function(dropdown, which, unit, name)
      if not W.ready or UIDROPDOWNMENU_MENU_LEVEL and UIDROPDOWNMENU_MENU_LEVEL ~= 1 then return end
      local allowed = false
      for _, tag in ipairs(TAGS) do if which == tag then allowed = true end end
      if not allowed then return end
      local entries = W.MenuEntries({ unit = unit, name = name or dropdown and dropdown.name,
        server = dropdown and dropdown.server, guid = dropdown and dropdown.guid })
      if #entries == 0 then return end
      local info = UIDropDownMenu_CreateInfo()
      info.text, info.notCheckable, info.func = ns.Locale:Get("reputation.menus.highground_reputation.9b4583"), true, entries[1].run
      UIDropDownMenu_AddButton(info, 1)
    end)
    W.menusInstalled = true
  end
end
