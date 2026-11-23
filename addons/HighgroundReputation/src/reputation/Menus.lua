local _, ns = ...
local W, U = ns.Reputation, ns.Util
local TAGS = { "PLAYER", "ENEMY_PLAYER", "PARTY", "RAID_PLAYER", "FRIEND", "FRIEND_OFFLINE", "GUILD", "CHAT_ROSTER" }

function W.MenuTarget(context)
  if type(context) ~= "table" then return end
  local unit = U.value(context.unit)
  if type(unit) == "string" then return W.Unit(unit) end
  return W.Target(U.value(context.name), U.value(context.server), U.value(context.guid), true)
end

-- One entry opens the report for the selected organization. With several
-- enabled organizations it becomes a submenu: one per organization, then all.
local function ReportEntry(target)
  local list = W.List()
  if #list < 2 then
    local c = W.Get()
    if not W.Joined(c) then c = list[1] end
    local own = c and W.OwnReport(c, target)
    return { text = own and ns.Locale:Get("reputation.menus.edit_your_report.d57ff8") or W.CanModerate(c) and ns.Locale:Get("reputation.menus.add_to_blacklist.214e95") or ns.Locale:Get("reputation.menus.report_player.4fb75f"),
      run = function() W.OpenReport(target, c) end }
  end
  local moderator, children = false, {}
  for _, c in ipairs(list) do moderator = moderator or W.CanModerate(c) end
  for _, choice in ipairs(W.UI.CommunityChoices()) do
    local c = W.Get(choice.key)
    children[#children + 1] = { text = ns.Locale:Format("reputation.menus.organization.502962", { organization = choice.label }), run = function() W.OpenReport(target, c) end }
  end
  children[#children + 1] = { divider = true }
  children[#children + 1] = { text = ns.Locale:Get("reputation.menus.all_guilds_and_communities.f0d48a"), run = function() W.OpenReport(target, W.ALL) end }
  return { text = moderator and ns.Locale:Get("reputation.menus.add_to_blacklist.8f78ba") or ns.Locale:Get("reputation.menus.report_player.7f805b"), children = children }
end

function W.MenuEntries(context)
  local target = W.MenuTarget(context)
  if not target then return {} end
  target = W.Copy(target) -- the player may change targets before clicking
  local entries = { ReportEntry(target) }
  local match = W.Match(target)
  if match then
    entries[#entries + 1] = { text = ns.Locale:Get("reputation.menus.view_blacklist_entry.81924c"), run = function() W.OpenDetails(match.community, match.row) end }
  end
  return entries
end

local function Add(menu, entry)
  if entry.divider then return menu:CreateDivider() end
  local button = menu:CreateButton(entry.text, entry.run)
  for _, child in ipairs(entry.children or {}) do Add(button, child) end
end

function W.InstallMenus()
  if ns.STANDBY or W.menusInstalled then return end
  if Menu and Menu.ModifyMenu then
    for _, tag in ipairs(TAGS) do
      Menu.ModifyMenu("MENU_UNIT_" .. tag, function(_, root, context)
        if not W.ready or U.Restricted() then return end
        local entries = W.MenuEntries(context)
        if #entries == 0 then return end
        root:CreateDivider()
        root:CreateTitle(ns.Locale:Get("reputation.menus.highground_reputation.371b59"))
        for _, entry in ipairs(entries) do Add(root, entry) end
      end)
    end
    W.menusInstalled = true
  elseif UnitPopup_ShowMenu and hooksecurefunc and UIDropDownMenu_CreateInfo and UIDropDownMenu_AddButton then
    hooksecurefunc("UnitPopup_ShowMenu", function(dropdown, which, unit, name)
      if not W.ready or UIDROPDOWNMENU_MENU_LEVEL and UIDROPDOWNMENU_MENU_LEVEL ~= 1 then return end
      local allowed = false
      for _, tag in ipairs(TAGS) do if which == tag then allowed = true end end
      if not allowed then return end
      local target = W.MenuTarget({ unit = unit, name = name or dropdown and dropdown.name,
        server = dropdown and dropdown.server, guid = dropdown and dropdown.guid })
      if not target then return end
      target = W.Copy(target)
      -- One level only; the report form chooses the organization, or all.
      local info = UIDropDownMenu_CreateInfo()
      info.text, info.notCheckable, info.func = ns.Locale:Get("reputation.menus.highground_reputation.9b4583"), true, function() W.OpenReport(target) end
      UIDropDownMenu_AddButton(info, 1)
    end)
    W.menusInstalled = true
  end
end
