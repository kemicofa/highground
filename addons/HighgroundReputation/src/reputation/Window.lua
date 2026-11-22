local _, ns = ...
local W, K, T, O = ns.Reputation, ns.Kit, ns.Theme, ns.Organizations
local UI = W.UI
local TABS = { ns.Localization.Define({ key = "overview", label = ns.Locale:Get("reputation.window.overview.0efc2e") }, { label = "reputation.window.overview.0efc2e" }), ns.Localization.Define({ key = "blacklist", label = ns.Locale:Get("reputation.window.blacklist.7b2dd0") }, { label = "reputation.window.blacklist.7b2dd0" }),
  ns.Localization.Define({ key = "proposals", label = ns.Locale:Get("reputation.window.proposals.ef44f4") }, { label = "reputation.window.proposals.ef44f4" }), ns.Localization.Define({ key = "members", label = ns.Locale:Get("reputation.window.members.1cb449") }, { label = "reputation.window.members.1cb449" }), ns.Localization.Define({ key = "history", label = ns.Locale:Get("reputation.window.history.90ccd6") }, { label = "reputation.window.history.90ccd6" }) }
local PAGE = 7
local HELP = ns.Localization.Define({
  blacklist = ns.Locale:Get("reputation.window.approved_decisions_these_entries_affect_your_chat.e2b355"),
  members = ns.Locale:Get("reputation.window.your_native_roster_membership_and_roles_are.d41b12"),
  history = ns.Locale:Get("reputation.window.previous_decisions_including_dismissed_proposals_and_revok.a31834"),
}, { blacklist = "reputation.window.approved_decisions_these_entries_affect_your_chat.e2b355", members = "reputation.window.your_native_roster_membership_and_roles_are.d41b12", history = "reputation.window.previous_decisions_including_dismissed_proposals_and_revok.a31834" })
local function Current(source)
  local W = source or W
  return W.Get()
end

local function Rows(c, source)
  local W = source or W
  local UI, O = W.UI, W.organizations or O
  local rows, state = {}, "ready"
  local organizations, readiness = O.List()
  if UI.mode == "organizations" then
    state = readiness
    for _, org in ipairs(organizations) do
      local value = org
      local state = W.Availability(value.id)
      rows[#rows + 1] = { name = value.name, hint = (value.kind == "guild" and ns.Locale:Get("reputation.window.guild.54241a") or ns.Locale:Get("reputation.window.wow_community.06d629"))
        .. " · " .. state.label, tone = state.tone, detail = state.message, action = ns.Locale:Get("shared.actionrow.open.cf9b77"), run = function()
          UI.SetMode("overview", value.id)
        end }
    end
  elseif not W.Joined(c) then state = readiness == "loading" and "loading" or ns.Locale:Get("reputation.window.unavailable.1d5ee3")
  elseif UI.mode == "members" then
    local members
    members, state = O.Members(c.id)
    for _, member in ipairs(members) do
      rows[#rows + 1] = { name = ns.Core.DisplayName(member.name), hint = (member.role or ns.Locale:Get("reputation.window.role_unavailable.48f5d9"))
        .. (member.online and ns.Locale:Get("reputation.window.online.e29e74") or ns.Locale:Get("reputation.window.offline.a79382")), action = ns.Locale:Get("reputation.window.view_in_wow.26263e"), run = function() W.OpenNative(c) end }
    end
  elseif c and UI.mode ~= "settings" then
    for _, row in ipairs(W.Rows(c, UI.mode)) do
      local value = row
      local hint = row.active and W.CategoryText(row.active.categories) or row.state
      if UI.mode == "proposals" then
        local report = not W.CanModerate(c) and W.OwnReport(c, row.target)
        hint = report and W.DeliveryText(c, report) or ns.Locale:Format("reputation.window.row_count_value2_row_pending_awaiting_review.5adbf5", { row_count = row.count, value2 = (row.count == 1 and ns.Locale:Get("reputation.window.reporter.816779") or ns.Locale:Get("reputation.window.reporters.901fa0")), row_pending = row.pending })
      end
      rows[#rows + 1] = { name = ns.Core.DisplayName(row.target.name), hint = hint, action = ns.Locale:Get("reputation.window.details.4dade5"),
        run = function() W.OpenDetails(c, value) end }
    end
  end
  local query, filtered = (UI.window.search:GetText() or ""):lower(), {}
  for _, row in ipairs(rows) do
    if query == "" or (row.name .. " " .. row.hint):lower():find(query, 1, true) then filtered[#filtered + 1] = row end
  end
  return filtered, state
end

function UI.Refresh(source)
  local W = source or W
  local UI = W.UI
  local f = UI.window
  if not f or not W.ready then return end
  local width = math.max(1, f.workspaceBody:GetWidth())
  if f.layoutWidth ~= width then
    f.layoutWidth = width
    f.workspaceTabs:SetWidth(width); f.pageTabs:SetWidth(width)
    f.workspaceTabs:Layout(); f.pageTabs:Layout()
    f.community:SetWidth(math.max(160, width - 176))
    f.search:SetWidth(math.max(220, width - 230))
    f.summary:SetWidth(width)
    for _, row in ipairs(f.rows) do row.title:SetWidth(width - 140); row.hint:SetWidth(width - 140) end
  end
  local c, O = Current(W), W.organizations or O
  local directory, settings, overview = UI.mode == "organizations", UI.mode == "settings", UI.mode == "overview"
  local scoped, listing = not directory and not settings, not settings and not overview
  local org = W.db.selected and O.Get(W.db.selected)
  local availability = scoped and org and W.Availability(org.id)
  local moderator = W.CanModerate(c)
  local role = org and O.Role(org.id)
  local roleName = role == "owner" and (org.kind == "guild" and ns.Locale:Get("reputation.window.guild_master.cf51be") or ns.Locale:Get("reputation.window.owner.89ff31"))
    or role == "moderator" and (org.kind == "guild" and ns.Locale:Get("highground.coachrecords.officer.f58330") or ns.Locale:Get("reputation.window.moderator.ad3b15"))
    or role == "leader" and ns.Locale:Get("reputation.window.leader.e26c93") or role == "member" and ns.Locale:Get("highground.coachrecords.member.6853c9") or ns.Locale:Get("reputation.window.unavailable.1d5ee3")
  f.community:SetChoices(UI.CommunityChoices(nil, true))
  f.community:SetValue(org and org.id, true)
  f.community:SetShown(scoped); f.browse:SetShown(scoped)
  f.heading:SetShown(directory or settings)
  f.heading:SetText(settings and ns.Locale:Get("reputation.window.personal_preferences.e41ab4") or ns.Locale:Get("reputation.window.your_guild_communities.7b052a"))
  f.heading:SetWidth(width)
  f.summary:SetText(directory and ns.Locale:Get("reputation.window.choose_an_organization_to_see_its_status.cd893c")
    or settings and ns.Locale:Get("reputation.window.these_preferences_apply_to_every_organization_you.5f299b")
    or UI.mode == "proposals" and (moderator and ns.Locale:Get("reputation.window.reports_awaiting_your_review_open_details_to.3e4537")
      or ns.Locale:Get("reputation.window.your_reports_and_delivery_status_a_proposal.cc1469"))
    or HELP[UI.mode]
    or org and (ns.Locale:Format("reputation.window.value1_your_role_rolename.3e2a9d", { value1 = (org.kind == "guild" and ns.Locale:Get("reputation.window.guild.54241a") or ns.Locale:Get("reputation.window.wow_community.06d629")), roleName = roleName }))
    or ns.Locale:Get("reputation.window.waiting_for_the_game_to_confirm_this.863d9b"))
  K.StatusText(f.status, directory and ns.Locale:Get("reputation.window.opening_an_organization_does_not_enable_or.7a1e7a")
    or settings and ns.Locale:Get("reputation.window.manage_participation_separately_in_each_organization_s.5035ac")
    or W.Joined(c) and W.Status(c) or availability and availability.message or W.Status(c), availability and availability.tone)
  f.add:SetShown(scoped and listing); f.add:SetEnabled(W.Joined(c))
  f.add:SetText(moderator and ns.Locale:Get("reputation.window.blacklist_player.fb83d8") or ns.Locale:Get("reputation.menus.report_player.4fb75f"))
  f.manage:SetShown(directory)
  f.workspaceTabs:SetSelected(settings and "settings" or "organizations")
  f.pageTabs:SetShown(scoped)
  for _, tab in ipairs(TABS) do
    f.pageTabs:SetItemEnabled(tab.key, tab.key == "overview" or W.Joined(c))
  end
  f.pageTabs:SetSelected(scoped and UI.mode or nil)
  f.overview:SetShown(overview)
  if overview then UI.RefreshOverview(W, org, c) end
  f.settings:SetShown(settings)
  f.search:SetShown(listing); f.search.caption:SetShown(listing)
  f.search.caption:SetText(directory and ns.Locale:Get("reputation.window.find_an_organization.b93d86") or UI.mode == "members" and ns.Locale:Get("reputation.window.find_a_member.036dc8") or ns.Locale:Get("reputation.window.search_players_or_categories.baec91"))
  local listTop = directory and 144 or 154 + f.pageTabs:GetHeight()
  if f.listTop ~= listTop then
    f.listTop = listTop
    f.search:ClearAllPoints(); f.search:SetPoint("TOPLEFT", 0, -listTop + 44)
    f.add:ClearAllPoints(); f.add:SetPoint("TOPRIGHT", 0, -listTop + 48)
    for i, widget in ipairs(f.rows) do
      widget:ClearAllPoints(); widget:SetPoint("TOPLEFT", 0, -listTop - (i - 1) * 50); widget:SetPoint("RIGHT", 0, 0)
    end
    f.empty:ClearAllPoints(); f.empty:SetPoint("TOPLEFT", 18, -listTop - 26)
  end
  local rows, nativeState = {}, "ready"
  if listing then rows, nativeState = Rows(c, W) end
  f.viewState = K.ResolveState({ count = #rows, filtered = (f.search:GetText() or "") ~= "",
    loading = nativeState == "loading" and ns.Locale:Get("reputation.window.waiting_for_the_game_to_supply_organizations.99e753"),
    unavailable = nativeState == "unavailable" and (not c and ns.Locale:Get("reputation.window.open_a_guild_or_community_from_organizations.d92b51")
      or ns.Locale:Get("reputation.window.the_game_cannot_supply_this_roster_open.40b735")),
    empty = UI.mode == "organizations" and ns.Locale:Get("reputation.window.join_a_guild_or_community_through_wow.2ade31")
      or UI.mode == "members" and ns.Locale:Get("reputation.window.no_members_to_show_open_guild_communities.f0cb4d")
      or UI.mode == "proposals" and ns.Locale:Get("reputation.window.no_proposals_yet_report_a_player_now.12344d")
      or ns.Locale:Get("reputation.window.no_entries_yet_use_report_player_to.962777") })
  if f.viewState.blocked then rows = {} end
  if nativeState == "loading" then f.summary:SetText(f.viewState.message) end
  local footer = math.max(76, f.status:GetStringHeight() + 60)
  local pageSize = math.max(2, math.min(PAGE, math.floor((f.workspaceBody:GetHeight() - listTop - footer) / 50)))
  UI.pageSize = pageSize
  local pages = math.max(1, math.ceil(#rows / pageSize))
  UI.pages, UI.page = pages, math.max(1, math.min(pages, UI.page))
  for i, widget in ipairs(f.rows) do
    local row = i <= pageSize and rows[(UI.page - 1) * pageSize + i] or nil
    widget:SetShown(row ~= nil and listing)
    widget.action:SetScript("OnClick", row and row.run or nil)
    widget.action:SetEnabled(row ~= nil)
    widget.detail = row and row.detail or nil
    if row then
      ns.Localization.BindField(widget.title, row, "name"); K.StatusText(widget.hint, row.hint, row.tone)
      widget.action:SetText(row.action)
    end
  end
  f.empty:SetShown(#rows == 0 and listing)
  K.StatusText(f.empty, f.viewState.message, f.viewState.tone)
  f.page:SetText(listing and (ns.Locale:Format("reputation.window.page_ui_page_of_pages.37760a", { UI_page = UI.page, pages = pages })) or "")
  f.page:SetShown(listing and pages > 1)
  f.previous:SetShown(listing and pages > 1); f.next:SetShown(listing and pages > 1)
  f.previous:SetEnabled(listing and UI.page > 1); f.next:SetEnabled(listing and UI.page < pages)
  if not settings then return end
  for key, toggle in pairs(f.toggles) do toggle:SetChecked(W.db.settings[key] ~= false, true) end
  f.replyInterval:SetValue(W.ReplyInterval(), true)
  local replyText = type(W.db.settings.replyText) == "string" and W.db.settings.replyText or W.DEFAULT_REPLY
  if f.replyText:GetText() ~= replyText then
    f.replyText.refreshing = true; f.replyText:SetText(replyText); f.replyText.refreshing = nil
  end
  local width = math.max(400, f.settings:GetWidth() - 16)
  f.settingsBody:SetWidth(width); f.replyText:SetWidth(width)
  for _, toggle in pairs(f.toggles) do toggle:SetWidth(width) end
  f.replyInterval:SetWidth(width - 170)
  f.replyHelp:SetWidth(width); f.settingsHelp:SetWidth(width)
  local helpY = 278 + f.replyHelp:GetStringHeight() + 24
  f.settingsHelp:ClearAllPoints(); f.settingsHelp:SetPoint("TOPLEFT", 0, -helpY)
  f.settingsBody:SetHeight(helpY + f.settingsHelp:GetStringHeight() + 24)
end

function W.Build(source)
  local W = source or W
  local UI = W.UI
  if UI.window then return UI.window end
  local f = UI.Dialog("Window", ns.Locale:Get("reputation.window.highground_reputation.b2db53"), 820, 740)
  UI.window = f
  f.workspaceTabs = K.TabGroup(f.content, { items = {
    { key = "organizations", label = ns.Locale:Get("reputation.window.organizations.076052") }, { key = "settings", label = ns.Locale:Get("reputation.window.preferences.9dfd34") },
  }, onSelect = function(_, key)
    if key == "organizations" then return UI.ReturnToOrganizations(W) end
    return UI.SelectTab(key)
  end })
  f.workspaceTabs:SetPoint("TOPLEFT")
  local body = CreateFrame("Frame", nil, f.content)
  f.workspaceBody = body
  body:SetPoint("TOPLEFT", f.workspaceTabs, "BOTTOMLEFT", 0, -20)
  body:SetPoint("BOTTOMRIGHT")
  f.heading = UI.Label(body, "", 0, 0, 500, "text")
  T.SetRole(f.heading, "title")
  f.browse = K.Button(body, ns.Locale:Get("reputation.window.all_organizations.b72720"), 166, 30, { onClick = function() UI.SetMode("organizations") end })
  f.browse:SetPoint("TOPLEFT", 0, 0)
  f.community = K.Select(body, { width = 380, menu = true, choices = {}, onChange = function(_, id)
    UI.SetMode("overview", id)
  end })
  f.community:SetPoint("LEFT", f.browse, "RIGHT", 10, 0)
  f.manage = K.Button(body, ns.Locale:Get("reputation.window.guild_communities.b58440"), 210, 30, { onClick = function() W.OpenNative() end })
  f.manage:SetPoint("TOPRIGHT", 0, -96)
  f.add = K.Button(body, ns.Locale:Get("reputation.menus.report_player.4fb75f"), 190, 30, { tone = "accent", onClick = function() W.OpenReport(nil, Current(W)) end })
  f.add:SetPoint("TOPRIGHT", 0, -136)
  f.summary = UI.Label(body, "", 0, -40, 620); f.summary:SetWordWrap(false)
  f.pageTabs = K.TabGroup(body, { items = TABS, onSelect = function(_, key) return UI.SelectTab(key) end })
  f.pageTabs:SetPoint("TOPLEFT", 0, -76)
  f.tabs = {}
  for _, tab in ipairs(TABS) do f.tabs[tab.key] = f.pageTabs.buttons[tab.key] end
  f.tabs.settings = f.workspaceTabs.buttons.settings
  UI.BuildOverview(f, W)
  f.search = K.Input(body, 380, ns.Locale:Get("reputation.window.search_players_categories_or_organizations.395096"))
  f.search:SetPoint("TOPLEFT", 0, -140)
  f.search:SetScript("OnTextChanged", function() UI.page = 1; UI.Refresh() end)
  f.rows = {}
  for i = 1, PAGE do
    local row = CreateFrame("Frame", nil, body)
    row:SetPoint("TOPLEFT", 0, -184 - (i - 1) * 50); row:SetPoint("RIGHT", 0, 0); row:SetHeight(46)
    row.bg = T.Fill(row, "BACKGROUND", "surface"); row.bg:SetAllPoints()
    row.title = UI.Label(row, "", 10, -5, 550, "text"); row.title:SetWordWrap(false)
    row.hint = UI.Label(row, "", 10, -26, 550); row.hint:SetWordWrap(false)
    row.action = K.Button(row, ns.Locale:Get("reputation.window.details.4dade5"), 110, 30); row.action:SetPoint("RIGHT", -8, 0)
    row:EnableMouse(true)
    K.Tooltip(row, function() return row.detail and { row.title:GetText(), row.detail } end)
    f.rows[i] = row
  end
  f.empty = UI.Label(body, "", 18, -210, 650)
  f.settings = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
  f.settings:SetPoint("TOPLEFT", 0, -84); f.settings:SetPoint("BOTTOMRIGHT", -26, 80)
  f.settingsBody = CreateFrame("Frame", nil, f.settings)
  f.settingsBody:SetSize(660, 600); f.settings:SetScrollChild(f.settingsBody)
  f.toggles = {}
  for i, option in ipairs({ { "filter", ns.Locale:Get("reputation.window.hide_chat_from_blacklisted_players.549198") },
    { "reply", ns.Locale:Get("reputation.window.reply_to_whispers_from_blacklisted_players.bc4674") },
    { "tooltip", ns.Locale:Get("reputation.window.show_community_reasons_on_player_tooltips.879b94") } }) do
    local key = option[1]
    local toggle = K.Toggle(f.settingsBody, option[2], { width = 650, onChange = function(_, checked)
      W.db.settings[key] = checked; W.Changed()
    end })
    toggle:SetPoint("TOPLEFT", 0, -(i - 1) * 48); f.toggles[key] = toggle
  end
  f.replyInterval = K.Select(f.settingsBody, { width = 380, label = ns.Locale:Get("reputation.window.automatic_reply_frequency.1db7de"), menu = true,
    choices = W.REPLY_INTERVALS, onChange = function(_, value) W.db.settings.replyInterval = value; W.Changed() end })
  f.replyInterval:SetPoint("TOPLEFT", 0, -174)
  f.replyText = K.Input(f.settingsBody, 650, ns.Locale:Get("reputation.window.automatic_reply_message_200_characters.6bf328"))
  f.replyText:SetPoint("TOPLEFT", 0, -238); f.replyText:SetMaxLetters(200)
  f.replyText:SetScript("OnTextChanged", function(self)
    if not self.refreshing then W.db.settings.replyText = self:GetText() end
  end)
  f.replyText:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  f.resetReply = K.Button(f.settingsBody, ns.Locale:Get("reputation.window.reset_message.91b174"), 150, 30, { onClick = function()
    W.db.settings.replyText = nil; W.Changed()
  end })
  f.resetReply:SetPoint("LEFT", f.replyInterval, "RIGHT", 20, 0)
  f.replyHelp = UI.Label(f.settingsBody, ns.Locale:Get("reputation.window.use_organization_for_the_guild_or_community.507da7"), 0, -278, 650)
  f.settingsHelp = UI.Label(f.settingsBody, ns.Locale:Get("reputation.window.these_are_personal_display_and_chat_preferences.ba8ca7"), 0, -374, 650)
  f.status = UI.Label(body, "", 0, -548, 720)
  f.status:SetWordWrap(true)
  f.status:ClearAllPoints(); f.status:SetPoint("BOTTOMLEFT", 0, 48); f.status:SetPoint("RIGHT", 0, 0)
  f.previous = K.Button(f, ns.Locale:Get("reputation.window.previous.50f942"), 100, 28, { onClick = function() UI.GoPage(-1) end })
  f.previous:SetPoint("BOTTOMLEFT", 18, 18)
  f.next = K.Button(f, ns.Locale:Get("highground.coach.next.bc9819"), 80, 28, { onClick = function() UI.GoPage(1) end })
  f.next:SetPoint("LEFT", f.previous, "RIGHT", 8, 0)
  f.page = UI.Label(f, "", 224, -696, 130); f.page:ClearAllPoints(); f.page:SetPoint("BOTTOMLEFT", 224, 22)
  f:SetScript("OnShow", function() UI.Refresh() end)
  f:SetScript("OnSizeChanged", function() UI.Refresh() end)
  ns.Core.OnFontScaleChange(function() if f:IsVisible() then UI.Refresh() end end)
  local router = UI.GetRouter()
  K.AttachNavigation(f, router)
  if not router:Current() and not router._busy then UI.SetMode(UI.mode) end
  UI.Refresh()
  return f
end

function W.Open(embedded, source)
  if ns.Modules and not ns.Modules.Require("reputation") then return end
  local W = source or W
  local UI = W.UI
  if not W.ready then return W.Say(W.loadError or ns.Locale:Get("reputation.forms.reputation_is_loading.ebdd24")) end
  local f = W.Build()
  UI.GetRouter():Refresh()
  if embedded then return f end
  if ns.Hub then ns.Hub.Release(f) end
  K.Windows.Show(f); UI.Refresh(); return f
end
function W.Command(text)
  if not W.ready then return W.Say(W.loadError or ns.Locale:Get("reputation.forms.reputation_is_loading.ebdd24")) end
  local command, rest = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
  command = command:lower()
  if command == "communities" or command == "organizations" then W.OpenOrganizations()
  elseif command == "manage" then W.OpenNative(Current())
  elseif command == "report" then
    local target, err
    if rest == "" or rest == "target" then target, err = W.Unit("target") else target, err = W.Target(rest) end
    if target then W.OpenReport(target) else W.Say(err) end
  elseif command == "sync" then
    for _, org in ipairs(O.List()) do W.Discover(org.id, true) end
    for _, c in ipairs(W.List()) do W.RequestSync(c, true); W.SendReports(c) end
    W.Say(ns.Locale:Get("reputation.window.requesting_updates_from_online_community_moderators_and.f75db8"))
  elseif command == "status" then W.Say(W.Status(Current()))
  elseif command == "on" or command == "off" then W.db.settings.filter = command == "on"; W.Changed(); W.Say(ns.Locale:Format("reputation.window.chat_filtering_command.201fe1", { command = command }))
  elseif command == "help" then W.Say(ns.Locale:Get("reputation.window.hgrep_or_hg_reputation_communities_manage_report.08ecaf"))
  elseif command == "" then if ns.Hub then ns.Hub.Open("reputation") else W.Open() end
  else W.Say(ns.Locale:Get("reputation.window.unknown_reputation_command_use_hgrep_help_or.8201d5")) end
end
W.Listen(function() if UI.window and UI.window:IsShown() then UI.Refresh() end end)
