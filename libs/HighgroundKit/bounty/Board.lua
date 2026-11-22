local _, ns = ...
local Core, B, T, Kit = ns.Core, ns.Bounty, ns.Theme, ns.Kit
local Board = { tab = "mine", offset = 0, CARDS = 6, W = 760, previews = {} }
B.Board = Board
local PREFIX = ns.FRAME_PREFIX or "Highground"
local TABS = {
  ns.Localization.Define({ key = "mine", label = ns.Locale:Get("shared.board.my_bounties.8513d0"), help = ns.Locale:Get("shared.board.players_you_track_privately_and_rewards_you.45b441") }, { label = "shared.board.my_bounties.8513d0", help = "shared.board.players_you_track_privately_and_rewards_you.45b441" }),
  ns.Localization.Define({ key = "guild", label = ns.Locale:Get("shared.board.guild_communities.a49fce"), help = ns.Locale:Get("shared.board.choose_a_guild_or_wow_community_its.b8c403") }, { label = "shared.board.guild_communities.a49fce", help = "shared.board.choose_a_guild_or_wow_community_its.b8c403" }),
  ns.Localization.Define({ key = "public", label = ns.Locale:Get("shared.board.shared_board.4b49e6"), help = ns.Locale:Get("shared.board.rewards_offered_by_players_on_your_realm.63f508") }, { label = "shared.board.shared_board.4b49e6", help = "shared.board.rewards_offered_by_players_on_your_realm.63f508" }),
  ns.Localization.Define({ key = "suggestions", label = ns.Locale:Get("shared.board.suggestions.861edb"), help = ns.Locale:Get("shared.board.repeated_attackers_reported_by_you_or_your.fe24f4") }, { label = "shared.board.suggestions.861edb", help = "shared.board.repeated_attackers_reported_by_you_or_your.fe24f4" }),
}
local STEPS = {
  ns.Localization.Define({ ns.Locale:Get("highground.toursteps.post_a_bounty.f67d15"), ns.Locale:Get("shared.board.create_bounty_takes_3_steps_target_reward.954dcc") }, { [1] = "highground.toursteps.post_a_bounty.f67d15", [2] = "shared.board.create_bounty_takes_3_steps_target_reward.954dcc" }),
  ns.Localization.Define({ ns.Locale:Get("shared.board.share_it.5c41f8"), ns.Locale:Get("shared.board.open_view_bounty_then_share_bounty_to.beacfb") }, { [1] = "shared.board.share_it.5c41f8", [2] = "shared.board.open_view_bounty_then_share_bounty_to.beacfb" }),
  ns.Localization.Define({ ns.Locale:Get("shared.board.claim_a_reward.842d3e"), ns.Locale:Get("shared.board.detected_kills_are_reported_automatically_view_report.f9c6dc") }, { [1] = "shared.board.claim_a_reward.842d3e", [2] = "shared.board.detected_kills_are_reported_automatically_view_report.f9c6dc" }),
}

local Text = Kit.Paragraph

function Board.Create() B.Form.Open(nil, Board.win.createMode or "personal", nil, nil, Board.organization) end

function Board.Tools(anchor)
  local items = {
    { text = ns.Locale:Get("highground.coachbountysamples.shared_alert_settings.cefbc7"), run = function() B.Preferences.Open() end },
    { text = ns.Locale:Get("highground.coachbountysamples.account_gold_funding.731d2e"), run = function() B.GoldView.Open() end },
    { text = ns.Locale:Get("shared.board.bounty_settings.3a7148"), run = Board.OpenSettings },
  }
  Kit.Dropdown.Open(anchor, items, function(item) item.run() end, { width = 250 * math.max(1, Core.FontScale()) })
end

function Board.Layout(w)
  local Board = w.board or Board
  if w.layingOut then return end
  w.layingOut = true
  local scale = math.max(1, Core.FontScale())
  local head = 64 + (scale - 1) * 24
  w.head:SetHeight(head)
  w.rule:ClearAllPoints(); w.rule:SetPoint("TOPLEFT", 1, -head); w.rule:SetPoint("TOPRIGHT", -1, -head)
  w.create:SetSize(194 * scale, 30 + (scale - 1) * 10)
  local available, tabs = w:GetWidth() - 44, {}
  for _, def in ipairs(TABS) do
    local tab = w.tabs[def.key]
    tab:Show()
    tabs[#tabs + 1] = tab
  end
  local tabsHeight = Kit.LayoutGrid(tabs, { width = available, height = 32 + (scale - 1) * 12,
    x = 22, y = -head - 10, padding = 34 * scale })
  w.toolbar = head + 30 + tabsHeight
  w.organization:ClearAllPoints(); w.organization:SetPoint("TOPLEFT", 22, -w.toolbar)
  w.organization:SetWidth(available)
  if Board.tab == "guild" and not Board.help then w.toolbar = w.toolbar + 44 end
  w.sync:ClearAllPoints(); w.sync:SetPoint("TOPRIGHT", -22, -w.toolbar); w.sync:SetSize(90 * scale, 28)
  w.review:ClearAllPoints(); w.review:SetPoint("RIGHT", w.sync, "LEFT", -12, 0); w.review:SetWidth(190 * scale)
  w.search:ClearAllPoints(); w.search:SetPoint("TOPLEFT", 22, -w.toolbar)
  w.search:SetPoint("RIGHT", (Board.tab == "guild" or Board.tab == "suggestions") and w.review or w.sync, "LEFT", -14, 0)
  w.viewHint:ClearAllPoints(); w.viewHint:SetPoint("TOPLEFT", 22, -w.toolbar - 42)
  w.viewHint:SetPoint("RIGHT", -22, 0); w.viewHint:SetHeight(0)
  w.viewHint:SetHeight(math.ceil(w.viewHint:GetStringHeight()) + 2)
  w.listTop = w.toolbar + 54 + w.viewHint:GetHeight()
  local footer = { w.claims, w.import, w.alerts, w.help }
  local needed = 30
  for _, button in ipairs(footer) do needed = needed + button.label:GetStringWidth() + 28 end
  if needed <= available then
    local x = 22
    for _, button in ipairs(footer) do
      local width = button.label:GetStringWidth() + 28 + (available - needed) / #footer
      button:ClearAllPoints(); button:SetPoint("BOTTOMLEFT", x, 18); button:SetSize(width, 30 * scale)
      x = x + width + 10
    end
    w.footerTop = 18 + 30 * scale
  else w.footerTop = 18 + Kit.LayoutGrid(footer, { width = available, columns = 2, height = 30 * scale,
    x = 22, y = 18, anchor = "BOTTOMLEFT", gap = 10, padding = 28 }) end
  w.next:ClearAllPoints(); w.next:SetPoint("BOTTOMRIGHT", -22, w.footerTop + 14)
  w.list:ClearAllPoints(); w.list:SetPoint("TOPLEFT", 22, -w.listTop)
  w.list:SetPoint("BOTTOMRIGHT", -22, w.footerTop + (w.pages and 52 or 14))
  w.list.body:SetWidth(available - 20)
  local guideTop = not Board.help and w.search:IsShown() and w.listTop or w.toolbar + 4
  w.guide:ClearAllPoints(); w.guide:SetPoint("TOPLEFT", 30, -guideTop); w.guide:SetPoint("BOTTOMRIGHT", -22, w.footerTop + 74)
  w.guide.body:SetWidth(available - 24)
  w.browse:SetSize(230 * scale, 32); w.emptyAction:SetSize(212 * scale, 32)
  w.browse:ClearAllPoints(); w.browse:SetPoint("BOTTOMLEFT", 30, w.footerTop + 24)
  w.emptyAction:ClearAllPoints(); w.emptyAction:SetPoint("BOTTOMLEFT", 30, w.footerTop + 24)
  if w.page then
    if w.page.close then w.page.close:SetShown(w:IsMovable()) end
    if w.page.LayoutPage then w.page:LayoutPage() end
  end
  w.layingOut = nil
end

local function Sample(provider)
  local owner = { tab = "mine", offset = 0, CARDS = Board.CARDS, W = Board.W, provider = provider }
  owner.Layout, owner.Create, owner.Tools = Board.Layout, provider.create, provider.tools
  owner.OpenSettings = provider.tools
  owner.Refresh = function() Board.Refresh(owner) end
  owner.router = ns.Router.New()
  B.Navigation.RegisterBoards(owner, owner.router)
  owner.SetTab = function(key) return B.Navigation.SetTab(key, owner) end
  Board.preview, provider.board = owner, owner
  Board.previews[provider.name or "Preview"] = owner
  return owner
end

-- A provider supplies sample rows and every action. The preview owns its
-- frames, filters and router; live stores and the live board remain separate.
function Board.Build(provider)
  local Board = provider and (Board.previews[provider.name or "Preview"] or Sample(provider)) or Board
  if provider then B.Board.preview, provider.board = Board, Board end
  if Board.win then return Board.win end
  local w = ns.Localization.BindWidget(Kit.Dialog(PREFIX .. "BountyFrame" .. (provider and (provider.name or "Preview") or ""), { title = ns.Locale:Get("shared.board.bounties.d82af6"), width = Board.W, height = 690,
    header = 64, headerPadding = 22, savedKey = not provider and "bounty" or nil, point = { "CENTER", "CENTER", 0, 20 }, accent = "gold" }), { title = "shared.board.bounties.d82af6" })
  Board.win, w.board = w, Board
  w.browser = CreateFrame("Frame", nil, w); w.browser:SetAllPoints(w)
  w.create = ns.Localization.Bind(Kit.Button(w.browser, ns.Locale:Get("shared.board.create_bounty.77492e"), 194, 30, { tone = "gold", onClick = Board.Create }), "shared.board.create_bounty.77492e")
  Kit.Tooltip(w.create, function() return { ns.Locale:Get("bounties.commands.create_a_bounty.de852e"), ns.Locale:Get("shared.board.choose_a_player_and_who_can_see.476aa7") } end)
  w.tabs = {}
  for _, def in ipairs(TABS) do
    local tab = Kit.Tab(w.browser, def.label, function() Board.SetTab(def.key) end)
    Kit.Tooltip(tab, { def.label, def.help }); w.tabs[def.key] = tab
  end
  w.organization = Kit.Select(w.browser, { width = 500, menu = true, choices = {}, onChange = function(_, id)
    if provider then return end
    B.Navigation.UpdateBoard(Board, { organization = id, offset = 0, scroll = 0 })
  end })
  Kit.Tooltip(w.organization, function() return { ns.Locale:Get("shared.board.organization_board.e058cb"), ns.Locale:Get("shared.board.choose_the_guild_or_community_whose_bounties.49be93") } end)
  w.search = ns.Localization.BindWidget(Kit.Input(w.browser, 240, "", { placeholder = ns.Locale:Get("shared.board.search_player_or_poster.8179b0"),
    onChange = function() if not Board.restoring then Board.offset = 0; Board.Refresh() end end }), { hint = "shared.board.search_player_or_poster.8179b0" })
  Kit.Tooltip(w.search, function() return { ns.Locale:Get("shared.board.search_this_board.8679a9"), ns.Locale:Get("shared.board.find_a_player_realm_poster_or_audience.9f7f4e") } end)
  w.review = ns.Localization.BindWidget(Kit.Toggle(w.browser, ns.Locale:Get("shared.board.awaiting_approval.d0a0d8"), { width = 220, onChange = function(_, on)
    B.Navigation.UpdateBoard(Board, { [Board.tab == "suggestions" and "showIgnored" or "pendingOnly"] = on, offset = 0, scroll = 0 })
  end }), { label = "shared.board.awaiting_approval.d0a0d8" })
  Kit.Tooltip(w.review, function()
    if Board.tab == "suggestions" then return { ns.Locale:Get("shared.board.show_ignored_enemies.2460a1"), ns.Locale:Get("shared.board.include_ignored_enemies_choose_allow_again_to.e27439") } end
    return { ns.Locale:Get("shared.board.organization_review_queue.6c740a"), ns.Locale:Get("shared.board.show_submissions_awaiting_approval_members_see_their.c1c80f") }
  end)
  w.viewHint = Text(w.browser, "body", "textMuted")
  w.list = Kit.ScrollArea(w.browser)
  w.rows = {}; for i = 1, Board.CARDS do
    local row = B.BoardRow.Build(w.list.body); w.rows[i] = row
    if provider then
      row:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" and row.entry then provider.details(row.entry) end end)
      row.details:SetScript("OnClick", function() if row.entry then provider.details(row.entry) end end)
      row.previewPrimary = provider.primary
      row.primary:SetScript("OnClick", function() if provider.runPrimary then provider.runPrimary(row.entry) end end)
    end
  end
  w.import = ns.Localization.Bind(Kit.Button(w.browser, ns.Locale:Get("highground.coachbountysamples.import_bounty.00e6b6"), 142, 30, { onClick = function()
    if provider then provider.import() else B.Exchange.OpenImport() end
  end }), "highground.coachbountysamples.import_bounty.00e6b6")
  Kit.Tooltip(w.import, function() return { ns.Locale:Get("bounties.commands.import_a_bounty.c82590"), ns.Locale:Get("shared.board.paste_the_bounty_link_you_received_review.a0c940") } end)
  w.guide = Kit.ScrollArea(w.browser)
  w.guide.title = Text(w.guide.body, "cardTitle")
  w.empty = Text(w.guide.body, "body", "textMuted")
  w.guide.steps = {}
  for i = 1, #STEPS do w.guide.steps[i] = { title = Text(w.guide.body, "heading", "gold"), body = Text(w.guide.body, "body") } end
  w.guide.terms = Text(w.guide.body, "bodySmall", "textMuted")
  w.browse = ns.Localization.Bind(Kit.Button(w.browser, ns.Locale:Get("shared.board.browse_shared_bounties.a74539"), 230, 32, { tone = "gold", onClick = function()
    if provider then Board.SetTab("public"); return end
    Core.SetOption("bountyReceive", true); B.Public.TransportTick(); B.BoardActions.RequestRefresh(Board)
  end }), "shared.board.browse_shared_bounties.a74539")
  w.browse:SetPoint("BOTTOMLEFT", 30, 98)
  Kit.Tooltip(w.browse, function() return { ns.Locale:Get("shared.board.join_the_shared_board.fd8f75"), ns.Locale:Get("shared.board.receive_rewards_from_participating_players_on_this.261882") } end)
  w.emptyAction = Kit.Button(w.browser, "", 212, 32, { onClick = function(self) if self.run then self.run() end end })
  w.emptyAction:SetPoint("BOTTOMLEFT", 30, 98)
  Kit.Tooltip(w.emptyAction, function(self) return { self:GetText(), w.empty:GetText() } end)
  w.alerts = ns.Localization.Bind(Kit.Button(w.browser, ns.Locale:Get("highground.hub.settings.c7f73b"), 106, 30, { onClick = Board.Tools }), "highground.hub.settings.c7f73b")
  w.alerts:SetPoint("BOTTOMLEFT", 22, 18)
  Kit.Tooltip(w.alerts, function() return { ns.Locale:Get("shared.board.bounty_settings.3a7148"), ns.Locale:Get("shared.board.shared_alerts_account_gold_and_bounty_preferences.a6b474") } end)
  w.claims = ns.Localization.Bind(Kit.Button(w.browser, ns.Locale:Get("shared.board.claims_payments.f83748"), 168, 30, { onClick = function()
    if provider then provider.claims() else B.Ledger.Open() end
  end }), "shared.board.claims_payments.f83748")
  w.claims:SetPoint("LEFT", w.alerts, "RIGHT", 10, 0)
  Kit.Tooltip(w.claims, function() return { ns.Locale:Get("shared.board.claims_and_payments.eece00"), ns.Locale:Get("shared.board.after_reporting_a_kill_follow_its_review.9274e9") } end)
  w.help = ns.Localization.Bind(Kit.Button(w.browser, ns.Locale:Get("battlegrounds.quickcalls.help.c47ae1"), 132, 30, { onClick = function()
    B.Navigation.UpdateBoard(Board, { help = not Board.help })
  end }), "battlegrounds.quickcalls.help.c47ae1")
  w.help:SetPoint("BOTTOMRIGHT", -22, 18)
  Kit.Tooltip(w.help, function() return { ns.Locale:Get("shared.board.how_bounties_work.2a9f5e"), ns.Locale:Get("shared.board.read_the_steps_from_choosing_a_target.2287dc") } end)
  w.sync = ns.Localization.Bind(Kit.Button(w.browser, ns.Locale:Get("shared.board.refresh.56e3ba"), 90, 28, { onClick = function()
    B.BoardActions.RequestRefresh(Board)
  end }), "shared.board.refresh.56e3ba")
  Kit.BusyButton(w.sync, function() return B.BoardActions.RefreshStatus(Board) end, Board.Refresh)
  Kit.BusyButton(w.browse, function() return B.BoardActions.RefreshStatus(Board) end, Board.Refresh)
  Kit.Tooltip(w.sync, function() return { ns.Locale:Get("shared.board.refresh_this_board.a65740"), ns.Locale:Get("shared.board.request_current_rewards_from_online_participants_the.9b1369") } end)
  w.next = Kit.Button(w.browser, ">", 34, 26, { onClick = function() B.Navigation.Page(Board, 1) end })
  w.next:SetPoint("BOTTOMRIGHT", -22, 64)
  w.prev = Kit.Button(w.browser, "<", 34, 26, { onClick = function() B.Navigation.Page(Board, -1) end })
  w.prev:SetPoint("RIGHT", w.next, "LEFT", -6, 0)
  Kit.Tooltip(w.prev, function() return { ns.Locale:Get("shared.board.previous_page.81f547"), ns.Locale:Get("shared.board.show_previous_bounties_the_mouse_wheel_also.8b6270") } end)
  Kit.Tooltip(w.next, function() return { ns.Locale:Get("macros.scripts.next_page.4bfc19"), ns.Locale:Get("shared.board.show_more_bounties_including_rewards_below_your.964d7e") } end)
  w.range = T.Text(w.browser, "bodySmall", "textMuted"); w.range:SetPoint("RIGHT", w.prev, "LEFT", -12, 0)
  w.browser:EnableMouseWheel(true); w.browser:SetScript("OnMouseWheel", function(_, delta) w.list:Scroll(w.list.offset - delta * 60) end)
  Core.OnFontScaleChange(function() Board.Layout(w); Board.Refresh() end)
  T.OnChange(function() Board.Layout(w); Board.Refresh() end)
  w:SetScript("OnShow", function() if not provider then B.Navigation.Resume() end; Board.Refresh() end)
  w:HookScript("OnHide", function()
    if provider then Board.refreshAttempt = nil end
    if not w:IsShown() and w.page then
      w.page:Hide()
      if not provider and not Kit.Windows.switching and not B.Navigation.GetRouter()._busy then B.Navigation.BackToBoard() end
    end
  end)
  w:SetScript("OnSizeChanged", function() Board.Layout(w); Board.Refresh() end)
  Board.Layout(w)
  if provider then Kit.AttachNavigation(w, Board.router); Board.SetTab("mine") else B.Navigation.Attach(w) end
  return w
end

local function Guide(w, count, total, member)
  local Board = w.board or Board
  local query = w.search:GetText() ~= ""
  local intro = Board.help or Board.tab == "mine" and total == 0 and not query
  local browse = not Board.provider and Board.tab == "public" and not B.Public.Receiving() and not Board.help
  local title, body = ns.Locale:Get("shared.board.no_bounties_here_yet.5ffb10"), ns.Locale:Get("shared.board.create_a_bounty_to_choose_a_player.fae0d5")
  if intro then
    title = Board.help and ns.Locale:Get("shared.board.from_a_target_to_a_reward.8ead76") or ns.Locale:Get("shared.board.who_are_you_hunting.e091a5")
    body = ns.Locale:Get("shared.board.create_a_bounty_in_3_steps_target.324a2a")
  elseif query then title, body = ns.Locale:Get("shared.board.no_matching_bounties.ca7058"), ns.Locale:Get("shared.board.no_matching_bounties_clear_the_search_to.e0276f")
  elseif Board.tab == "guild" then
    title = not member and ns.Locale:Get("shared.board.choose_a_guild_or_community.b7b49c") or Board.pendingOnly and ns.Locale:Get("shared.board.all_caught_up.47cbaf") or ns.Locale:Get("shared.board.give_your_organization_a_target.dd651a")
    body = not member and ns.Locale:Get("shared.board.join_a_guild_or_wow_community_to.b4a8ad")
      or Board.pendingOnly and ns.Locale:Get("shared.board.no_bounties_are_waiting_for_approval.eda44e")
      or ns.Locale:Get("shared.board.submit_a_player_and_an_optional_reward.2a04fa")
  elseif Board.tab == "public" then
    title = browse and ns.Locale:Get("shared.board.hunt_for_rewards_from_other_players.35f91d") or ns.Locale:Get("shared.board.waiting_for_shared_bounties.5ada50")
    body = browse and ns.Locale:Get("shared.board.browse_rewards_from_players_on_your_realm.21de02")
      or ns.Locale:Get("shared.board.no_shared_rewards_have_arrived_yet_other.410409")
  elseif Board.tab == "suggestions" then
    title = (Board.provider or B.Suggestions.Enabled()) and ns.Locale:Get("shared.board.no_recurring_attackers_yet.bfcf29") or ns.Locale:Get("shared.board.need_a_target_for_a_bounty.79c298")
    body = ns.Locale:Get("shared.board.suggestions_find_repeated_attackers_in_your_death.b07bef")
  end
  w.guide:SetShown(count == 0 or Board.help)
  local y, width = 0, w.guide.body:GetWidth()
  local function Place(text, value, gap)
    text:ClearAllPoints(); text:SetPoint("TOPLEFT", 0, -y); text:SetWidth(width); text:SetText(value)
    text:SetHeight(0)
    local height = math.ceil(text:GetStringHeight()) + 2; text:SetHeight(height); y = y + height + gap
  end
  Place(w.guide.title, title, 14); Place(w.empty, body, 24)
  for i, step in ipairs(w.guide.steps) do
    step.title:SetShown(Board.help == true); step.body:SetShown(Board.help == true)
    if Board.help then Place(step.title, STEPS[i][1], 6); Place(step.body, STEPS[i][2], 18) end
  end
  w.guide.terms:SetShown(intro or Board.tab == "public")
  if intro or Board.tab == "public" then Place(w.guide.terms, ns.Locale:Get("shared.board.highground_tracks_reports_and_payments_players_send.1ebf74"), 8) end
  w.guide.body:SetHeight(y); w.guide:Refresh()
  w.browse:SetShown(browse)
  w.emptyAction:SetShown(count == 0 and not intro and (query or Board.tab == "suggestions" or Board.pendingOnly))
  w.emptyAction:SetText(query and ns.Locale:Get("shared.board.clear_search.67300d") or Board.pendingOnly and ns.Locale:Get("shared.board.show_all_submissions.e8b6da") or ns.Locale:Get("shared.board.suggestion_settings.c4a248"))
  w.emptyAction.run = query and function() w.search:SetText("") end
    or Board.pendingOnly and function() Board.SetTab("guild") end or Board.OpenSettings
  local createBelow = intro or count == 0 and not query and Board.tab == "guild" and not Board.pendingOnly
  w.header:SetActions(not createBelow and { w.create } or nil)
  if createBelow then w.create:ClearAllPoints(); w.create:SetPoint("BOTTOMLEFT", 30, w.footerTop + 24) end
  w.create:SetText(intro and total == 0 and not Board.help and ns.Locale:Get("shared.board.create_first_bounty.a61a53") or createBelow and Board.tab == "guild"
    and (member and ns.Locale:Get("shared.board.create_group_bounty.b8d6dc") or ns.Locale:Get("shared.board.create_private_bounty.84e83b")) or ns.Locale:Get("shared.board.create_bounty.77492e"))
  w.createMode = not Board.help and Board.tab == "public" and "public" or not Board.help and Board.tab == "guild" and member and "guild" or "personal"
end

local function Hint(Board, suggestions)
  if Board.message then return Board.message, Board.messageTone or "success" end
  if Board.provider then return ns.Locale:Get("shared.board.sample_bounties_try_the_real_controls_nothing.30d499") end
  return Board.tab == "mine" and ns.Locale:Get("shared.board.tracked_targets_and_your_rewards_each_card.3869f6")
    or suggestions and ns.Locale:Get("shared.board.review_the_death_reports_then_choose_whether.a3a9a9")
    or Board.tab == "guild" and ns.Locale:Get("shared.board.hunt_an_approved_target_detected_kills_are.ae01ff")
    or not B.Public.Receiving() and ns.Locale:Get("shared.board.browsing_is_paused_saved_rewards_remain_below.ddcf90")
    or ns.Locale:Get("shared.board.open_a_bounty_to_see_who_pays.ee720e")
end

-- One full model build per refresh: other tabs only need their counts.
function Board.Refresh(owner)
  local Board = type(owner) == "table" and owner.provider and owner or Board
  local w = Board.win
  if not (w and w:IsShown()) or w.refreshing or w.layingOut then return end
  -- Window transitions prepare hosted pages before showing their parent.
  if not w:IsVisible() and not Kit.Windows.switching then return end
  -- A mounted form, claim list or settings page covers the browser.
  -- Closing it refreshes the board.
  if w.page and w.page:IsShown() then return end
  w.refreshing = true
  w.refreshedAt = GetTime()
  local provider = Board.provider
  Board.organization = provider and "guild" or B.Organizations.Selected()
  w.organization:SetChoices(provider and { { key = "guild", label = ns.Locale:Get("shared.board.sample_guild.ddad55") } } or B.Organizations.Choices())
  w.organization:SetValue(Board.organization, true)
  w.organization:SetShown(Board.tab == "guild" and not Board.help)
  local suggestions, query = Board.tab == "suggestions", w.search:GetText()
  local member = provider ~= nil or B.Organizations.Member(Board.organization)
  local filter = suggestions and Board.showIgnored or Board.tab == "guild" and Board.pendingOnly
  local list = (provider and provider.rows or B.BoardModel.Rows)(Board.tab, query, filter)
  local total = 0
  for _, def in ipairs(TABS) do
    local count = def.key == Board.tab and query == "" and not filter and #list
      or provider and #provider.rows(def.key) or B.BoardModel.Count(def.key)
    w.tabs[def.key]:Select(Board.tab == def.key)
    w.tabs[def.key].count:SetText(tostring(count)); w.tabs[def.key].count:SetShown(count > 0)
    if def.key == Board.tab then total = count end
  end
  w.visible = Board.CARDS
  w.pages = #list > w.visible and not Board.help
  Board.offset = math.max(0, math.min(Board.offset, math.floor(math.max(0, #list - 1) / w.visible) * w.visible))
  local filtering = not Board.help and (total > 0 or query ~= "" or Board.pendingOnly or suggestions)
  w.search:SetShown(filtering); w.review:SetShown(filtering and (Board.tab == "guild" or suggestions))
  w.review.label:SetText(suggestions and ns.Locale:Get("shared.board.show_ignored.722c8d") or ns.Locale:Get("shared.board.awaiting_approval.d0a0d8"))
  w.review:SetChecked(suggestions and Board.showIgnored == true or not suggestions and Board.pendingOnly == true, true)
  w.help:SetText(Board.help and ns.Locale:Get("shared.board.back_to_board.c4cc8d") or ns.Locale:Get("battlegrounds.quickcalls.help.c47ae1"))
  -- A finished refresh attempt leaves its result message for the hint.
  w.sync:RefreshBusy(); w.browse:RefreshBusy()
  Kit.StatusText(w.viewHint, Hint(Board, suggestions))
  -- Lay out once, after every label and visibility that affects geometry.
  Board.Layout(w)
  local available, gap = w.list.body:GetWidth(), 16
  local minWidth = 216 + math.max(0, Core.FontScale() - 1) * 120
  local columns = math.max(1, math.min(3, math.floor((available + gap) / (minWidth + gap))))
  local width, y = (available - (columns - 1) * gap) / columns, 0
  for i, row in ipairs(w.rows) do
    local b = not Board.help and i <= w.visible and list[Board.offset + i]
    if b then
      local column = (i - 1) % columns
      row:ClearAllPoints(); row:SetPoint("TOPLEFT", column * (width + gap), -y); row:SetWidth(width)
      B.BoardRow.Fill(row, b)
      if column == columns - 1 or i == math.min(w.visible, #list - Board.offset) then
        local height = B.BoardRow.Align(w.rows, i - column, i, width)
        y = y + height + gap
      end
    else row.entry = nil; row:Hide() end
  end
  w.list.body:SetHeight(math.max(1, y)); w.list:SetShown(#list > 0 and not Board.help)
  local page = Board.tab .. ":" .. Board.offset .. ":" .. query
  if w.listPage ~= page then w.list:Scroll(0); w.listPage = page end
  w.list:Refresh()
  Guide(w, #list, total, member)
  w.viewHint:SetShown((#list > 0 or Board.message ~= nil) and not Board.help)
  w.sync:SetShown(not Board.help and not suggestions and (provider or Board.tab == "public" and B.Public.Receiving() or Board.tab ~= "public" and member))
  w.sync:SetEnabled(true)
  w.range:SetText(ns.Locale:Format("shared.board.value1_value2_of_value3.e1ddb3", { value1 = string.format("%d", Board.offset + 1), value2 = string.format("%d", math.min(#list, Board.offset + w.visible)), value3 = string.format("%d", #list) }))
  w.range:SetShown(w.pages); w.prev:SetShown(w.pages); w.next:SetShown(w.pages)
  w.prev:SetEnabled(Board.offset > 0); w.next:SetEnabled(Board.offset + w.visible < #list)
  w.refreshing = nil
end

-- Changes refresh immediately through the event listeners below. Only age
-- labels and expiry need polling, and only while the live board is visible.
function Board.Tick()
  local w = Board.win
  if w and w:IsVisible() and GetTime() - (w.refreshedAt or 0) >= 5 then Board.Refresh() end
end

function Board.SetTab(key)
  return B.Navigation.SetTab(key)
end

function Board.TargetPlayer()
  local U = ns.Util
  if not U.read(UnitExists, "target") then return nil, ns.Locale:Get("shared.board.select_a_player_first_then_click_use.f16ed5") end
  if not U.read(UnitIsPlayer, "target") then return nil, ns.Locale:Get("shared.board.that_target_is_not_a_player_select.8c8ae8") end
  if U.read(UnitIsUnit, "target", "player") then return nil, ns.Locale:Get("shared.board.select_another_player_for_the_bounty.b2e870") end
  local name = Core.CanonUnit("target")
  if not name then return nil, ns.Locale:Get("shared.board.that_player_s_name_is_unavailable_try.e49bfe") end
  return name
end

function Board.Open(name)
  if ns.Modules and not ns.Modules.Require("bounties") then return end
  local w = Board.Build()
  if not w:IsVisible() then Board.message = nil end
  Kit.Windows.Show(w); Board.Refresh()
  if name then B.Form.Open(name) end
end

function Board.Toggle()
  if ns.Modules and not ns.Modules.Require("bounties") then return end
  local w = Board.Build()
  if ns.Hub then ns.Hub.Release(w) end
  if w:IsShown() then w:Hide() else Board.Open() end
end

function Board.OpenSettings()
  if ns.Hub then ns.Hub.Open("bounty")
  elseif ns.Options and ns.Options.OpenPage then ns.Options.OpenPage("bounty")
  elseif ns.StandaloneSettings then ns.StandaloneSettings.Open() end
end

B.Listen("updated", Board.Refresh)
B.Listen("changed", Board.Refresh)
_G["BINDING_NAME_" .. PREFIX:upper() .. "_BOUNTY"] = ns.Locale:Get("shared.board.toggle_the_bounty_board.8371a8")
_G[PREFIX .. "_BountyBoard"] = function()
  if ns.STANDBY then return ns.Util.Say(ns.Locale:Format("shared.board.value1_is_loaded_use_value3.77c783", { value1 = (ns.STANDBY_LABEL or "Highground"), value3 = (ns.STANDBY_COMMAND or "/hg bounty") })) end
  Board.Toggle()
end
