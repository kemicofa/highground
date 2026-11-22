local _, ns = ...
local Core, B, T, Kit = ns.Core, ns.Bounty, ns.Theme, ns.Kit
local Board = { tab = "mine", offset = 0, CARDS = 6, W = 760, previews = {} }
B.Board = Board
local PREFIX = ns.FRAME_PREFIX or "Highground"
local TABS = {
  { key = "mine", label = "My bounties", help = "Players you track privately and rewards you posted. Only me means only you receive the sightings." },
  { key = "guild", label = "Guild & communities", help = "Choose a guild or WoW community. Its officers or moderators approve bounties before members can hunt." },
  { key = "public", label = "Shared board", help = "Rewards offered by players on your realm and faction who use a compatible addon. Browsing is optional." },
  { key = "suggestions", label = "Suggestions", help = "Repeated attackers reported by you or your guild. Review the reports before creating a bounty." },
}
local STEPS = {
  { "Post a bounty", "Create bounty takes 3 steps: Target, Reward, Review. Nothing is posted until you confirm." },
  { "Share it", "Open View bounty, then Share bounty to copy a link. Shared rewards also appear in game; guild rewards need moderator approval." },
  { "Claim a reward", "Detected kills are reported automatically. View report opens Claims & payments. Use Claim reward on the bounty if detection missed a kill. The poster approves the reward and pays through the game." },
}

local Text = Kit.Paragraph

function Board.Create() B.Form.Open(nil, Board.win.createMode or "personal", nil, nil, Board.organization) end

function Board.Tools(anchor)
  local items = {
    { text = "Shared alert settings", run = function() B.Preferences.Open() end },
    { text = "Account gold & funding", run = function() B.GoldView.Open() end },
    { text = "Bounty settings", run = Board.OpenSettings },
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
  local w = Kit.Dialog(PREFIX .. "BountyFrame" .. (provider and (provider.name or "Preview") or ""), { title = "BOUNTIES", width = Board.W, height = 690,
    header = 64, headerPadding = 22, savedKey = not provider and "bounty" or nil, point = { "CENTER", "CENTER", 0, 20 }, accent = "gold" })
  Board.win, w.board = w, Board
  w.browser = CreateFrame("Frame", nil, w); w.browser:SetAllPoints(w)
  w.create = Kit.Button(w.browser, "Create bounty", 194, 30, { tone = "gold", onClick = Board.Create })
  Kit.Tooltip(w.create, { "Create a bounty", "Choose a player and who can see it. Start with Only me for private alerts; add a reward when you want others to help." })
  w.tabs = {}
  for _, def in ipairs(TABS) do
    local tab = Kit.Tab(w.browser, def.label, function() Board.SetTab(def.key) end)
    Kit.Tooltip(tab, { def.label, def.help }); w.tabs[def.key] = tab
  end
  w.organization = Kit.Select(w.browser, { width = 500, menu = true, choices = {}, onChange = function(_, id)
    if provider then return end
    B.Navigation.UpdateBoard(Board, { organization = id, offset = 0, scroll = 0 })
  end })
  Kit.Tooltip(w.organization, { "Organization board", "Choose the guild or community whose bounties you want to view. Each has its own board and moderators." })
  w.search = Kit.Input(w.browser, 240, "", { placeholder = "Search player or poster",
    onChange = function() Board.offset = 0; Board.Refresh() end })
  Kit.Tooltip(w.search, { "Search this board", "Find a player, realm, poster or audience. Clear the field to see the whole board." })
  w.review = Kit.Toggle(w.browser, "Awaiting approval", { width = 220, onChange = function(_, on)
    B.Navigation.UpdateBoard(Board, { [Board.tab == "suggestions" and "showIgnored" or "pendingOnly"] = on, offset = 0, scroll = 0 })
  end })
  Kit.Tooltip(w.review, function()
    if Board.tab == "suggestions" then return { "Show ignored enemies", "Include ignored enemies. Choose Allow again to restore their suggestions." } end
    return { "Organization review queue", "Show submissions awaiting approval. Members see their own submissions; guild officers and community moderators can review all of them." }
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
  w.import = Kit.Button(w.browser, "Import bounty", 142, 30, { onClick = function()
    if provider then provider.import() else B.Exchange.OpenImport() end
  end })
  Kit.Tooltip(w.import, { "Import a bounty", "Paste the bounty link you received, review the reward, then confirm." })
  w.guide = Kit.ScrollArea(w.browser)
  w.guide.title = Text(w.guide.body, "cardTitle")
  w.empty = Text(w.guide.body, "body", "textMuted")
  w.guide.steps = {}
  for i = 1, #STEPS do w.guide.steps[i] = { title = Text(w.guide.body, "heading", "gold"), body = Text(w.guide.body, "body") } end
  w.guide.terms = Text(w.guide.body, "bodySmall", "textMuted")
  w.browse = Kit.Button(w.browser, "Browse shared bounties", 230, 32, { tone = "gold", onClick = function()
    if provider then Board.SetTab("public"); return end
    Core.SetOption("bountyReceive", true); B.Public.TransportTick(); B.BoardActions.RequestRefresh(Board)
  end })
  w.browse:SetPoint("BOTTOMLEFT", 30, 98)
  Kit.Tooltip(w.browse, { "Join the shared board", "Receive rewards from participating players on this realm and faction. Browsing does not publish your own bounties." })
  w.emptyAction = Kit.Button(w.browser, "", 212, 32, { onClick = function(self) if self.run then self.run() end end })
  w.emptyAction:SetPoint("BOTTOMLEFT", 30, 98)
  Kit.Tooltip(w.emptyAction, function(self) return { self:GetText(), w.empty:GetText() } end)
  w.alerts = Kit.Button(w.browser, "Settings", 106, 30, { onClick = Board.Tools })
  w.alerts:SetPoint("BOTTOMLEFT", 22, 18)
  Kit.Tooltip(w.alerts, { "Bounty settings", "Shared alerts, account gold and bounty preferences." })
  w.claims = Kit.Button(w.browser, "Claims & payments", 168, 30, { onClick = function()
    if provider then provider.claims() else B.Ledger.Open() end
  end })
  w.claims:SetPoint("LEFT", w.alerts, "RIGHT", 10, 0)
  Kit.Tooltip(w.claims, { "Claims and payments", "After reporting a kill, follow its review here. If you posted the reward, approve the report, pay through the game, then mark it paid." })
  w.help = Kit.Button(w.browser, "Help", 132, 30, { onClick = function()
    B.Navigation.UpdateBoard(Board, { help = not Board.help })
  end })
  w.help:SetPoint("BOTTOMRIGHT", -22, 18)
  Kit.Tooltip(w.help, { "How bounties work", "Read the steps from choosing a target to paying a hunter. Your current board and search are kept." })
  w.sync = Kit.Button(w.browser, "Refresh", 90, 28, { onClick = function()
    B.BoardActions.RequestRefresh(Board)
  end })
  Kit.BusyButton(w.sync, function() return B.BoardActions.RefreshStatus(Board) end, Board.Refresh)
  Kit.BusyButton(w.browse, function() return B.BoardActions.RefreshStatus(Board) end, Board.Refresh)
  Kit.Tooltip(w.sync, { "Refresh this board", "Request current rewards from online participants. The loader stays visible while waiting; Refresh is disabled until the response window ends. Shared rewards need browsing enabled; organization rewards need membership." })
  w.next = Kit.Button(w.browser, ">", 34, 26, { onClick = function() B.Navigation.Page(Board, 1) end })
  w.next:SetPoint("BOTTOMRIGHT", -22, 64)
  w.prev = Kit.Button(w.browser, "<", 34, 26, { onClick = function() B.Navigation.Page(Board, -1) end })
  w.prev:SetPoint("RIGHT", w.next, "LEFT", -6, 0)
  Kit.Tooltip(w.prev, { "Previous page", "Show previous bounties. The mouse wheel also scrolls the list." })
  Kit.Tooltip(w.next, { "Next page", "Show more bounties, including rewards below your alert minimum." })
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

local function Guide(w, count, total)
  local Board = w.board or Board
  local query = w.search:GetText() ~= ""
  local intro = Board.help or Board.tab == "mine" and total == 0 and not query
  local browse = not Board.provider and Board.tab == "public" and not B.Public.Receiving() and not Board.help
  local title, body = "No bounties here yet", "Create a bounty to choose a player and offer a reward."
  if intro then
    title = Board.help and "From a target to a reward" or "Who are you hunting?"
    body = "Create a bounty in 3 steps: target, reward, review.\nOr browse rewards to hunt for other players."
  elseif query then title, body = "No matching bounties", "No matching bounties. Clear the search to see this board."
  elseif Board.tab == "guild" then
    title = not Board.provider and not B.Organizations.Member(Board.organization) and "Choose a guild or community" or Board.pendingOnly and "All caught up" or "Give your organization a target"
    body = not Board.provider and not B.Organizations.Member(Board.organization) and "Join a guild or WoW community to see its bounties. You can still track a player privately in My bounties."
      or Board.pendingOnly and "No bounties are waiting for approval."
      or "Submit a player and an optional reward. An officer or community moderator approves the bounty before members can see it."
  elseif Board.tab == "public" then
    title = browse and "Hunt for rewards from other players" or "Waiting for shared bounties"
    body = browse and "Browse rewards from players on your realm and faction who use Highground. This only receives their bounties; your private targets stay private."
      or "No shared rewards have arrived yet. Other players must be online with a compatible addon to send their offers. Try Refresh, or post the first reward."
  elseif Board.tab == "suggestions" then
    title = (Board.provider or B.Suggestions.Enabled()) and "No recurring attackers yet" or "Need a target for a bounty?"
    body = "Suggestions find repeated attackers in your death reports. Review one to create a bounty.\n\nOptional: enable suggestions in settings. You can post and hunt bounties without them."
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
  if intro or Board.tab == "public" then Place(w.guide.terms, "Highground tracks reports and payments. Players send the gold themselves.", 8) end
  w.guide.body:SetHeight(y); w.guide:Refresh()
  w.browse:SetShown(browse)
  w.emptyAction:SetShown(count == 0 and not intro and (query or Board.tab == "suggestions" or Board.pendingOnly))
  w.emptyAction:SetText(query and "Clear search" or Board.pendingOnly and "Show all submissions" or "Suggestion settings")
  w.emptyAction.run = query and function() w.search:SetText("") end
    or Board.pendingOnly and function() Board.SetTab("guild") end or Board.OpenSettings
  local createBelow = intro or count == 0 and not query and Board.tab == "guild" and not Board.pendingOnly
  w.header:SetActions(not createBelow and { w.create } or nil)
  if createBelow then w.create:ClearAllPoints(); w.create:SetPoint("BOTTOMLEFT", 30, w.footerTop + 24) end
  w.create:SetText(intro and total == 0 and not Board.help and "Create first bounty" or createBelow and Board.tab == "guild"
    and ((Board.provider or B.Organizations.Member(Board.organization)) and "Create group bounty" or "Create private bounty") or "Create bounty")
  w.createMode = not Board.help and Board.tab == "public" and "public" or not Board.help and Board.tab == "guild" and (Board.provider or B.Organizations.Member(Board.organization)) and "guild" or "personal"
end

function Board.Refresh(owner)
  local Board = type(owner) == "table" and owner.provider and owner or Board
  local w = Board.win
  if not (w and w:IsShown()) or w.refreshing or w.layingOut then return end
  -- Window transitions prepare hosted pages before showing their parent.
  if not w:IsVisible() and not Kit.Windows.switching then return end
  w.refreshing = true
  w.refreshedAt = GetTime()
  Board.organization = Board.provider and "guild" or B.Organizations.Selected()
  w.organization:SetChoices(Board.provider and { { key = "guild", label = "Sample guild" } } or B.Organizations.Choices())
  w.organization:SetValue(Board.organization, true)
  w.organization:SetShown(Board.tab == "guild" and not Board.help)
  local total, Rows = 0, Board.provider and Board.provider.rows or B.BoardModel.Rows
  for _, def in ipairs(TABS) do
    local count = #Rows(def.key)
    w.tabs[def.key]:Select(Board.tab == def.key)
    w.tabs[def.key].count:SetText(tostring(count)); w.tabs[def.key].count:SetShown(count > 0)
    if def.key == Board.tab then total = count end
  end
  Board.Layout(w)
  local suggestions = Board.tab == "suggestions"
  local list = Rows(Board.tab, w.search:GetText(), suggestions and Board.showIgnored or Board.tab == "guild" and Board.pendingOnly)
  w.visible = Board.CARDS
  w.pages = #list > w.visible and not Board.help
  Board.offset = math.max(0, math.min(Board.offset, math.floor(math.max(0, #list - 1) / w.visible) * w.visible))
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
  local page = Board.tab .. ":" .. Board.offset .. ":" .. w.search:GetText()
  if w.listPage ~= page then w.list:Scroll(0); w.listPage = page end
  w.list:Refresh()
  Guide(w, #list, total)
  local filtering = not Board.help and (total > 0 or w.search:GetText() ~= "" or Board.pendingOnly or suggestions)
  w.search:SetShown(filtering); w.review:SetShown(filtering and (Board.tab == "guild" or suggestions))
  w.review.label:SetText(suggestions and "Show ignored" or "Awaiting approval")
  w.review:SetChecked(suggestions and Board.showIgnored == true or not suggestions and Board.pendingOnly == true, true)
  w.help:SetText(Board.help and "Back to board" or "Help")
  w.sync:RefreshBusy(); w.browse:RefreshBusy()
  local hint = Board.message or Board.provider and "Sample bounties · try the real controls. Nothing is saved or sent." or (Board.tab == "mine" and "Tracked targets and your rewards. Each card shows its tracking state."
    or suggestions and "Review the death reports, then choose whether to create a bounty. Nothing is posted automatically."
    or Board.tab == "guild" and "Hunt an approved target. Detected kills are reported automatically; follow the review in Claims & payments."
    or not B.Public.Receiving() and "Browsing is paused. Saved rewards remain below. Choose Browse shared bounties to receive new offers."
    or "Open a bounty to see who pays, track the target or view its kill reports. Lower rewards stay listed below your alert minimum.")
  w.viewHint:SetText(hint); T.Paint(w.viewHint, Board.message and "success" or "textMuted")
  Board.Layout(w)
  w.viewHint:SetShown((#list > 0 or Board.message ~= nil) and not Board.help)
  w.sync:SetShown(not Board.help and not suggestions and (Board.provider or Board.tab == "public" and B.Public.Receiving() or Board.tab ~= "public" and B.Organizations.Member(Board.organization)))
  w.sync:SetEnabled(true)
  local pages = #list > w.visible and not Board.help
  w.range:SetText(string.format("%d–%d of %d", Board.offset + 1, math.min(#list, Board.offset + w.visible), #list))
  w.range:SetShown(pages); w.prev:SetShown(pages); w.next:SetShown(pages)
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
  if not U.read(UnitExists, "target") then return nil, "Select a player first, then click Use target." end
  if not U.read(UnitIsPlayer, "target") then return nil, "That target is not a player. Select a player first." end
  if U.read(UnitIsUnit, "target", "player") then return nil, "Select another player for the bounty." end
  local name = Core.CanonUnit("target")
  if not name then return nil, "That player's name is unavailable. Try again or enter the name manually." end
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
_G["BINDING_NAME_" .. PREFIX:upper() .. "_BOUNTY"] = "Toggle the bounty board"
_G[PREFIX .. "_BountyBoard"] = function()
  if ns.STANDBY then return ns.Util.Say((ns.STANDBY_LABEL or "Highground") .. " is loaded: use " .. (ns.STANDBY_COMMAND or "/hg bounty")) end
  Board.Toggle()
end
