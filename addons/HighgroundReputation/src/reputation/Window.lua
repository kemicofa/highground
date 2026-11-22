local _, ns = ...
local W, K, T, O = ns.Reputation, ns.Kit, ns.Theme, ns.Organizations
local UI = W.UI
local TABS = { { "organizations", "Organizations" }, { "blacklist", "Blacklist" }, { "proposals", "Proposals" },
  { "members", "Members" }, { "history", "History" }, { "settings", "Settings" } }
local PAGE = 7
local function Current(source)
  local W = source or W
  local c = W.Get(); return W.Joined(c) and c or W.List()[1]
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
      local entry, state = W.Get(value.id), W.Availability(value.id)
      local canEnable = O.CanModerate(value.id) and not (entry and entry.activated)
      rows[#rows + 1] = { name = value.name, hint = (value.kind == "guild" and "Guild" or "WoW community")
        .. " · " .. state.label, tone = state.tone, detail = state.message, action = canEnable and "Enable" or "Open", run = function()
          local c, err
          if canEnable then c, err = W.Enable(value.id) else c, err = W.Follow(value.id) end
          if not c then return W.Say(err) end
          W.Discover(c.id, true)
          UI.SetMode(c.activated and "blacklist" or "proposals", c.id)
        end }
    end
  elseif not c then state = readiness == "loading" and "loading" or "unavailable"
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
        hint = report and W.DeliveryText(c, report) or row.count .. " reporting identities · " .. row.pending .. " awaiting review"
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

function UI.Refresh(source)
  local W = source or W
  local UI = W.UI
  local f = UI.window
  if not f or not W.ready then return end
  local c = Current(W)
  f.community:SetChoices(UI.CommunityChoices())
  f.community:SetValue(c and c.id or nil, true)
  if c then W.db.selected = c.id end
  f.summary:SetText(c and (W.Name(c) .. " · " .. (W.Role(c) or "Role unavailable") .. " · " .. W.MemberCount(c) .. " members")
    or "Choose a guild or community. Only officers and community moderators can enable Reputation.")
  K.StatusText(f.status, W.Status(c), c and W.Availability(c.id).tone)
  f.disable:SetEnabled(c ~= nil); f.sync:SetEnabled(c ~= nil)
  f.add:SetEnabled(#(W.organizations or O).List() > 0)
  for mode, button in pairs(f.tabs) do K.Paint(button, mode == UI.mode and "selected" or "surface") end
  local settings = UI.mode == "settings"
  f.settings:SetShown(settings)
  f.search:SetShown(not settings); f.search.caption:SetShown(not settings)
  local rows, nativeState = {}, "ready"
  if not settings then rows, nativeState = Rows(c, W) end
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
  local pageSize = math.max(2, math.min(PAGE, math.floor((f.content:GetHeight() - 184 - footer) / 50)))
  UI.pageSize = pageSize
  local pages = math.max(1, math.ceil(#rows / pageSize))
  UI.pages, UI.page = pages, math.max(1, math.min(pages, UI.page))
  for i, widget in ipairs(f.rows) do
    local row = i <= pageSize and rows[(UI.page - 1) * pageSize + i] or nil
    widget:SetShown(row ~= nil and not settings)
    widget.action:SetScript("OnClick", row and row.run or nil)
    widget.action:SetEnabled(row ~= nil)
    widget.detail = row and row.detail or nil
    if row then
      widget.title:SetText(row.name); K.StatusText(widget.hint, row.hint, row.tone)
      widget.action:SetText(row.action)
    end
  end
  f.empty:SetShown(#rows == 0 and not settings)
  K.StatusText(f.empty, f.viewState.message, f.viewState.tone)
  f.page:SetText(settings and "" or (UI.page .. " / " .. pages))
  f.previous:SetEnabled(not settings and UI.page > 1); f.next:SetEnabled(not settings and UI.page < pages)
  for key, toggle in pairs(f.toggles) do toggle:SetChecked(W.db.settings[key] ~= false, true) end
  f.replyInterval:SetValue(W.ReplyInterval(), true)
  local replyText = type(W.db.settings.replyText) == "string" and W.db.settings.replyText or W.DEFAULT_REPLY
  if f.replyText:GetText() ~= replyText then
    f.replyText.refreshing = true; f.replyText:SetText(replyText); f.replyText.refreshing = nil
  end
  local width = math.max(400, f.settings:GetWidth() - 16)
  f.settingsBody:SetWidth(width); f.replyText:SetWidth(width)
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
  local f = UI.Dialog("Window", "HIGHGROUND REPUTATION", 820, 740)
  UI.window = f
  f.community = K.Select(f.content, { width = 290, menu = true, choices = {}, onChange = function(_, id)
    UI.SetMode(UI.mode, id)
  end })
  f.community:SetPoint("TOPLEFT", 0, 0)
  f.manage = K.Button(f.content, "Guild & Communities", 218, 30, { onClick = function() W.OpenNative(Current(W)) end })
  f.manage:SetPoint("LEFT", f.community, "RIGHT", 10, 0)
  f.add = K.Button(f.content, "Report player...", 160, 30, { tone = "accent", onClick = function() W.OpenReport(nil, Current(W)) end })
  f.add:SetPoint("LEFT", f.manage, "RIGHT", 10, 0)
  f.summary = UI.Label(f.content, "", 0, -40, 620); f.summary:SetWordWrap(false)
  f.sync = K.Button(f.content, "Sync", 80, 26, { onClick = function()
    local c = Current(W); if c then W.Discover(c.id, true); W.RequestSync(c, true); W.SendReports(c); UI.Refresh() end
  end })
  f.sync:SetPoint("TOPRIGHT", 0, -36)
  f.tabs = {}
  for i, tab in ipairs(TABS) do
    local mode = tab[1]
    local button = K.Button(f.content, tab[2], 112, 30, { onClick = function() UI.SetMode(mode) end })
    button:SetPoint("TOPLEFT", (i - 1) * 120, -76); f.tabs[mode] = button
  end
  f.search = K.Input(f.content, 380, "Search players, categories or organizations")
  f.search:SetPoint("TOPLEFT", 0, -140)
  f.search:SetScript("OnTextChanged", function() UI.page = 1; UI.Refresh() end)
  f.rows = {}
  for i = 1, PAGE do
    local row = CreateFrame("Frame", nil, f.content)
    row:SetPoint("TOPLEFT", 0, -184 - (i - 1) * 50); row:SetPoint("RIGHT", 0, 0); row:SetHeight(46)
    row.bg = T.Fill(row, "BACKGROUND", "surface"); row.bg:SetAllPoints()
    row.title = UI.Label(row, "", 10, -5, 550, "text"); row.title:SetWordWrap(false)
    row.hint = UI.Label(row, "", 10, -26, 550); row.hint:SetWordWrap(false)
    row.action = K.Button(row, "Details...", 110, 30); row.action:SetPoint("RIGHT", -8, 0)
    row:EnableMouse(true)
    K.Tooltip(row, function() return row.detail and { row.title:GetText(), row.detail } end)
    f.rows[i] = row
  end
  f.empty = UI.Label(f.content, "", 18, -210, 650)
  f.settings = CreateFrame("ScrollFrame", nil, f.content, "UIPanelScrollFrameTemplate")
  f.settings:SetPoint("TOPLEFT", 0, -136); f.settings:SetPoint("BOTTOMRIGHT", -26, 80)
  f.settingsBody = CreateFrame("Frame", nil, f.settings)
  f.settingsBody:SetSize(660, 600); f.settings:SetScrollChild(f.settingsBody)
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
  f.settingsHelp = UI.Label(f.settingsBody, "Officers and community owners, leaders or moderators enable Reputation. Members discover it automatically. Manage membership and roles in Guild & Communities.\n\nProposals wait here until a moderator has the addon enabled. Keep the reporting character online to send them automatically. Only moderators receive report notes.\n\nPause an organization on this account to stop its sharing and filtering. Other members keep their own settings.", 0, -374, 650)
  f.status = UI.Label(f.content, "", 0, -548, 720)
  f.status:SetWordWrap(true)
  f.status:ClearAllPoints(); f.status:SetPoint("BOTTOMLEFT", 0, 48); f.status:SetPoint("RIGHT", 0, 0)
  f.previous = K.Button(f, "Previous", 100, 28, { onClick = function() UI.GoPage(-1) end })
  f.previous:SetPoint("BOTTOMLEFT", 18, 18)
  f.next = K.Button(f, "Next", 80, 28, { onClick = function() UI.GoPage(1) end })
  f.next:SetPoint("LEFT", f.previous, "RIGHT", 8, 0)
  f.page = UI.Label(f, "", 224, -696, 130); f.page:ClearAllPoints(); f.page:SetPoint("BOTTOMLEFT", 224, 22)
  f.disable = K.Button(f, "Pause on this account", 235, 28, { onClick = function()
    W.Disable(Current(W)); UI.SetMode("organizations")
  end })
  f.disable:SetPoint("BOTTOMRIGHT", -18, 18)
  f:SetScript("OnShow", function() UI.Refresh() end)
  f:SetScript("OnSizeChanged", function()
    local width = math.max(500, f.content:GetWidth())
    f.community:SetWidth(math.max(160, width - 408))
    for i, tab in ipairs(TABS) do
      local button = f.tabs[tab[1]]
      button:SetWidth((width - 40) / 6)
      button:ClearAllPoints(); button:SetPoint("TOPLEFT", (i - 1) * ((width - 40) / 6 + 8), -76)
    end
    f.summary:SetWidth(width - 96)
    for _, row in ipairs(f.rows) do row.title:SetWidth(width - 140); row.hint:SetWidth(width - 140) end
    UI.Refresh()
  end)
  local router = UI.GetRouter()
  K.AttachNavigation(f, router)
  if not router:Current() and not router._busy then UI.SetMode(UI.mode) end
  UI.Refresh()
  return f
end

function UI.GetRouter(source)
  local W = source or W
  local UI = W.UI
  if UI.router then return UI.router end
  local router = ns.Router.New()
  UI.router = router
  for _, tab in ipairs(TABS) do
    router:Register(tab[1], {
      beforeEnter = function(to)
        if to.name ~= "organizations" and (#W.List() == 0 or to.params.organization and not W.Joined(W.Get(to.params.organization))) then
          return "organizations"
        end
      end,
      capture = function() return { query = UI.window.search:GetText(), page = UI.page } end,
      enter = function(to)
        local f, state = W.Build(), to.state or {}
        UI.mode = to.name
        if to.params.organization then W.db.selected = to.params.organization end
        f.search:SetText(state.query or ""); UI.page = state.page or 1
        UI.Refresh()
      end,
    })
  end
  return router
end

function UI.SetMode(mode, organization, source)
  local W = source or W
  local UI, c = W.UI, Current(W)
  return UI.GetRouter():Navigate({ name = mode, params = { organization = organization or c and c.id } })
end

function UI.GoPage(delta, source)
  local UI = (source or W).UI
  local page = math.max(1, math.min(UI.pages, UI.page + delta))
  if page == UI.page then return true end
  local target = UI.GetRouter():Current()
  target.state = { query = UI.window.search:GetText(), page = page }
  return UI.GetRouter():Navigate(target, { restoreState = true })
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
  elseif command == "" then if ns.Hub then ns.Hub.Open("reputation") else W.Open() end
  else W.Say("Unknown Reputation command. Use /hgrep help or /hg reputation help.") end
end
W.Listen(function() if UI.window and UI.window:IsShown() then UI.Refresh() end end)
