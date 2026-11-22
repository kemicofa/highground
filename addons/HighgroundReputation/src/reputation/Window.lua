local _, ns = ...
local W, K, T, O = ns.Reputation, ns.Kit, ns.Theme, ns.Organizations
local UI = W.UI
local TABS = { { key = "overview", label = "Overview" }, { key = "blacklist", label = "Blacklist" },
  { key = "proposals", label = "Proposals" }, { key = "members", label = "Members" }, { key = "history", label = "History" } }
local PAGE = 7
local HELP = {
  blacklist = "Approved decisions. These entries affect your chat and player tooltips.",
  members = "Your native roster. Membership and roles are managed in WoW.",
  history = "Previous decisions, including dismissed proposals and revoked blacklist entries.",
}
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
      rows[#rows + 1] = { name = value.name, hint = (value.kind == "guild" and "Guild" or "WoW community")
        .. " · " .. state.label, tone = state.tone, detail = state.message, action = "Open", run = function()
          UI.SetMode("overview", value.id)
        end }
    end
  elseif not W.Joined(c) then state = readiness == "loading" and "loading" or "unavailable"
  elseif UI.mode == "members" then
    local members
    members, state = O.Members(c.id)
    for _, member in ipairs(members) do
      rows[#rows + 1] = { name = ns.Core.DisplayName(member.name), hint = (member.role or "Role unavailable")
        .. (member.online and " · Online" or " · Offline"), action = "View in WoW", run = function() W.OpenNative(c) end }
    end
  elseif c and UI.mode ~= "settings" then
    for _, row in ipairs(W.Rows(c, UI.mode)) do
      local value = row
      local hint = row.active and W.CategoryText(row.active.categories) or row.state
      if UI.mode == "proposals" then
        local report = not W.CanModerate(c) and W.OwnReport(c, row.target)
        hint = report and W.DeliveryText(c, report) or row.count .. (row.count == 1 and " reporter · " or " reporters · ") .. row.pending .. " awaiting review"
      end
      rows[#rows + 1] = { name = ns.Core.DisplayName(row.target.name), hint = hint, action = "Details...",
        run = function() W.OpenDetails(c, value) end }
    end
  end
  local query, filtered = (UI.window.search:GetText() or ""):lower(), {}
  for _, row in ipairs(rows) do
    if query == "" or (row.name .. " " .. row.hint):lower():find(query, 1, true) then filtered[#filtered + 1] = row end
  end
  return filtered, state
end

-- Shared by the dedicated window, isolated guide samples and Highground's
-- configuration page. Building preferences never opens or navigates reports.
local function BuildSettings(f, source)
  local W = source or W
  local UI = W.UI
  f.toggles = {}
  for i, option in ipairs({ { "filter", "Hide chat from blacklisted players" },
    { "reply", "Reply to whispers from blacklisted players" },
    { "tooltip", "Show community reasons on player tooltips" } }) do
    local key = option[1]
    local toggle = K.Toggle(f.settingsBody, option[2], { width = 650, onChange = function(_, checked)
      W.db.settings[key] = checked; W.Changed()
    end })
    toggle:SetPoint("TOPLEFT", 0, -(i - 1) * 48); f.toggles[key] = toggle
  end
  f.replyInterval = K.Select(f.settingsBody, { width = 380, label = "Automatic reply frequency", menu = true,
    choices = W.REPLY_INTERVALS, onChange = function(_, value) W.db.settings.replyInterval = value; W.Changed() end })
  f.replyInterval:SetPoint("TOPLEFT", 0, -174)
  f.replyText = K.Input(f.settingsBody, 650, "Automatic reply message (200 characters)")
  f.replyText:SetPoint("TOPLEFT", 0, -238); f.replyText:SetMaxLetters(200)
  f.replyText:SetScript("OnTextChanged", function(self)
    if not self.refreshing then W.db.settings.replyText = self:GetText() end
  end)
  f.replyText:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  f.resetReply = K.Button(f.settingsBody, "Reset message", 150, 30, { onClick = function()
    W.db.settings.replyText = nil; W.Changed()
  end })
  f.resetReply:SetPoint("LEFT", f.replyInterval, "RIGHT", 20, 0)
  f.replyHelp = UI.Label(f.settingsBody, "Use {organization} for the guild or community and {categories} for the blacklist reasons.\nA [Highground Reputation] prefix is added automatically to prevent reply loops. Leaving the message blank uses the default.", 0, -278, 650)
  f.settingsHelp = UI.Label(f.settingsBody, "These are personal display and chat preferences. To enable or disable an organization, open the Reputation window, choose Organizations, open the organization and use Overview.\n\nOnly approved blacklist decisions affect chat and tooltips. A proposal alone never blacklists anyone.", 0, -374, 650)
  f.replyHelp:SetWordWrap(true); f.settingsHelp:SetWordWrap(true)
end
UI.BuildSettings = BuildSettings

local function RefreshSettings(f, width, source)
  local W = source or W
  for key, toggle in pairs(f.toggles) do toggle:SetChecked(W.db.settings[key] ~= false, true) end
  f.replyInterval:SetValue(W.ReplyInterval(), true)
  local replyText = type(W.db.settings.replyText) == "string" and W.db.settings.replyText or W.DEFAULT_REPLY
  if f.replyText:GetText() ~= replyText then
    f.replyText.refreshing = true; f.replyText:SetText(replyText); f.replyText.refreshing = nil
  end
  for _, toggle in pairs(f.toggles) do toggle:SetWidth(width) end
  f.settingsBody:SetWidth(width); f.replyText:SetWidth(width)
  f.replyInterval:SetWidth(width - 170)
  f.replyHelp:SetWidth(width); f.settingsHelp:SetWidth(width)
  f.replyHelp:SetHeight(f.replyHelp:GetStringHeight()); f.settingsHelp:SetHeight(f.settingsHelp:GetStringHeight())
  local helpY = 278 + f.replyHelp:GetStringHeight() + 24
  f.settingsHelp:ClearAllPoints(); f.settingsHelp:SetPoint("TOPLEFT", 0, -helpY)
  f.settingsBody:SetHeight(helpY + f.settingsHelp:GetStringHeight() + 24)
end
UI.RefreshSettings = RefreshSettings

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
  local roleName = role == "owner" and (org.kind == "guild" and "Guild master" or "Owner")
    or role == "moderator" and (org.kind == "guild" and "Officer" or "Moderator")
    or role == "leader" and "Leader" or role == "member" and "Member" or "unavailable"
  f.community:SetChoices(UI.CommunityChoices(nil, true))
  f.community:SetValue(org and org.id, true)
  f.community:SetShown(scoped); f.browse:SetShown(scoped)
  f.heading:SetShown(directory or settings)
  f.heading:SetText(settings and "Personal preferences" or "Your guild & communities")
  f.heading:SetWidth(width)
  f.summary:SetText(directory and "Choose an organization to see its status, reports and participation controls."
    or settings and "These preferences apply to every organization you use on this account."
    or UI.mode == "proposals" and (moderator and "Reports awaiting your review. Open Details to approve or dismiss."
      or "Your reports and delivery status. A proposal alone never blacklists anyone.")
    or HELP[UI.mode]
    or org and ((org.kind == "guild" and "Guild" or "WoW community") .. " · Your role: " .. roleName)
    or "Waiting for the game to confirm this organization.")
  K.StatusText(f.status, directory and "Opening an organization does not enable or resume Reputation."
    or settings and "Manage participation separately in each organization's Overview."
    or W.Joined(c) and W.Status(c) or availability and availability.message or W.Status(c), availability and availability.tone)
  f.add:SetShown(scoped and listing); f.add:SetEnabled(W.Joined(c))
  f.add:SetText(moderator and "Blacklist player..." or "Report player...")
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
  f.search.caption:SetText(directory and "Find an organization" or UI.mode == "members" and "Find a member" or "Search players or categories")
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
    loading = nativeState == "loading" and "Waiting for the game to supply organizations or members…",
    unavailable = nativeState == "unavailable" and (not c and "Open a guild or community from Organizations."
      or "The game cannot supply this roster. Open Guild & Communities to check it."),
    empty = UI.mode == "organizations" and "Join a guild or community through WoW to use Reputation."
      or UI.mode == "members" and "No members to show. Open Guild & Communities to check the roster."
      or UI.mode == "proposals" and "No proposals yet. Report a player now; proposals wait here until a moderator can receive them."
      or "No entries yet. Use Report player to submit a proposal or moderation decision." })
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
      widget.title:SetText(row.name); K.StatusText(widget.hint, row.hint, row.tone)
      widget.action:SetText(row.action)
    end
  end
  f.empty:SetShown(#rows == 0 and listing)
  K.StatusText(f.empty, f.viewState.message, f.viewState.tone)
  f.page:SetText(listing and ("Page " .. UI.page .. " of " .. pages) or "")
  f.page:SetShown(listing and pages > 1)
  f.previous:SetShown(listing and pages > 1); f.next:SetShown(listing and pages > 1)
  f.previous:SetEnabled(listing and UI.page > 1); f.next:SetEnabled(listing and UI.page < pages)
  if not settings then return end
  RefreshSettings(f, math.max(400, f.settings:GetWidth() - 16), W)
end

function W.Build(source)
  local W = source or W
  local UI = W.UI
  if UI.window then return UI.window end
  local f = UI.Dialog("Window", "HIGHGROUND REPUTATION", 820, 740)
  UI.window = f
  f.workspaceTabs = K.TabGroup(f.content, { items = {
    { key = "organizations", label = "Organizations" }, { key = "settings", label = "Preferences" },
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
  f.browse = K.Button(body, "All organizations", 166, 30, { onClick = function() UI.SetMode("organizations") end })
  f.browse:SetPoint("TOPLEFT", 0, 0)
  f.community = K.Select(body, { width = 380, menu = true, choices = {}, onChange = function(_, id)
    UI.SetMode("overview", id)
  end })
  f.community:SetPoint("LEFT", f.browse, "RIGHT", 10, 0)
  f.manage = K.Button(body, "Guild & Communities", 210, 30, { onClick = function() W.OpenNative() end })
  f.manage:SetPoint("TOPRIGHT", 0, -96)
  f.add = K.Button(body, "Report player...", 190, 30, { tone = "accent", onClick = function() W.OpenReport(nil, Current(W)) end })
  f.add:SetPoint("TOPRIGHT", 0, -136)
  f.summary = UI.Label(body, "", 0, -40, 620); f.summary:SetWordWrap(false)
  f.pageTabs = K.TabGroup(body, { items = TABS, onSelect = function(_, key) return UI.SelectTab(key) end })
  f.pageTabs:SetPoint("TOPLEFT", 0, -76)
  f.tabs = {}
  for _, tab in ipairs(TABS) do f.tabs[tab.key] = f.pageTabs.buttons[tab.key] end
  f.tabs.settings = f.workspaceTabs.buttons.settings
  UI.BuildOverview(f, W)
  f.search = K.Input(body, 380, "Search players, categories or organizations")
  f.search:SetPoint("TOPLEFT", 0, -140)
  f.search:SetScript("OnTextChanged", function() UI.page = 1; UI.Refresh() end)
  f.rows = {}
  for i = 1, PAGE do
    local row = CreateFrame("Frame", nil, body)
    row:SetPoint("TOPLEFT", 0, -184 - (i - 1) * 50); row:SetPoint("RIGHT", 0, 0); row:SetHeight(46)
    row.bg = T.Fill(row, "BACKGROUND", "surface"); row.bg:SetAllPoints()
    row.title = UI.Label(row, "", 10, -5, 550, "text"); row.title:SetWordWrap(false)
    row.hint = UI.Label(row, "", 10, -26, 550); row.hint:SetWordWrap(false)
    row.action = K.Button(row, "Details...", 110, 30); row.action:SetPoint("RIGHT", -8, 0)
    row:EnableMouse(true)
    K.Tooltip(row, function() return row.detail and { row.title:GetText(), row.detail } end)
    f.rows[i] = row
  end
  f.empty = UI.Label(body, "", 18, -210, 650)
  f.settings = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
  f.settings:SetPoint("TOPLEFT", 0, -84); f.settings:SetPoint("BOTTOMRIGHT", -26, 80)
  f.settingsBody = CreateFrame("Frame", nil, f.settings)
  f.settingsBody:SetSize(660, 600); f.settings:SetScrollChild(f.settingsBody)
  BuildSettings(f, W)
  f.status = UI.Label(body, "", 0, -548, 720)
  f.status:SetWordWrap(true)
  f.status:ClearAllPoints(); f.status:SetPoint("BOTTOMLEFT", 0, 48); f.status:SetPoint("RIGHT", 0, 0)
  f.previous = K.Button(f, "Previous", 100, 28, { onClick = function() UI.GoPage(-1) end })
  f.previous:SetPoint("BOTTOMLEFT", 18, 18)
  f.next = K.Button(f, "Next", 80, 28, { onClick = function() UI.GoPage(1) end })
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
  if not W.ready then return W.Say(W.loadError or "Reputation is loading.") end
  local f = W.Build()
  UI.GetRouter():Refresh()
  if embedded then return f end
  if ns.Hub then ns.Hub.Release(f) end
  K.Windows.Show(f); UI.Refresh(); return f
end
function W.Command(text)
  if not W.ready then return W.Say(W.loadError or "Reputation is loading.") end
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
    W.Say("Requesting updates from online community moderators and guild officers.")
  elseif command == "status" then W.Say(W.Status(Current()))
  elseif command == "on" or command == "off" then W.db.settings.filter = command == "on"; W.Changed(); W.Say("Chat filtering " .. command .. ".")
  elseif command == "help" then W.Say("/hgrep or /hg reputation: communities | manage | report [target/full name] | sync | status | on | off")
  elseif command == "" then W.Open()
  else W.Say("Unknown Reputation command. Use /hgrep help or /hg reputation help.") end
end
W.Listen(function() if UI.window and UI.window:IsVisible() then UI.Refresh() end end)
