local _, ns = ...
local Core, B, T, Kit = ns.Core, ns.Bounty, ns.Theme, ns.Kit
local Board = { tab = "mine", offset = 0, CARDS = 7, W = 760 }
B.Board = Board
local PREFIX = ns.FRAME_PREFIX or "Highground"
local TABS = {
  { key = "mine", label = "My bounties", help = "Players you track privately and rewards you posted. Only me means only you receive the sightings." },
  { key = "guild", label = "Guild board", help = "Bounties from your guild. An officer must approve a submission before members can hunt it." },
  { key = "public", label = "Shared board", help = "Rewards offered by players on your realm and faction who use a compatible addon. Browsing is optional." },
  { key = "suggestions", label = "Suggestions", help = "Repeated attackers reported by you or your guild. Review the reports before creating a bounty." },
}
local STEPS = {
  { "1. Choose a player", "Create a bounty with a player name, or use your current target. A reward is optional for a private target." },
  { "2. Choose who sees it", "Only me keeps it private. Guild asks an officer to approve it. Shared offers your reward to players on your realm and faction." },
  { "3. Hunt, then report", "Sightings trigger an alert. For a reward, open the bounty and choose Report kill. The poster reviews it in Claims & payments and pays through the game." },
}

local function Text(parent, role, tint)
  local text = T.Text(parent, role, tint or "text")
  text:SetJustifyH("LEFT"); text:SetJustifyV("TOP"); text:SetWordWrap(true)
  return text
end

function Board.Create() B.Form.Open(nil, Board.win.createMode or "personal") end

function Board.Tools(anchor)
  local items = {
    { text = "Bounty suggestions", run = function() Board.SetTab("suggestions") end },
    { text = "Shared alert settings", run = function() B.Preferences.Open() end },
    { text = "Bounty settings", run = Board.OpenSettings },
  }
  Kit.Dropdown.Open(anchor, items, function(item) item.run() end, { width = 250 * math.max(1, Core.FontScale()) })
end

function Board.Layout(w)
  if w.layingOut then return end
  w.layingOut = true
  local scale = math.max(1, Core.FontScale())
  local head = 64 + (scale - 1) * 24
  w.head:SetHeight(head); w.bar:SetHeight(head)
  w.rule:ClearAllPoints(); w.rule:SetPoint("TOPLEFT", 1, -head); w.rule:SetPoint("TOPRIGHT", -1, -head)
  w.create:SetSize(194 * scale, 30 + (scale - 1) * 10)
  local available, needed, tabs = w:GetWidth() - 44, 0, {}
  for _, def in ipairs(TABS) do
    local tab = w.tabs[def.key]
    local show = def.key ~= "suggestions" or Board.tab == "suggestions"
    tab:SetShown(show)
    if show then tabs[#tabs + 1] = tab; needed = math.max(needed, tab.label:GetStringWidth() + 34 * scale) end
  end
  local columns = math.max(1, math.min(#tabs, math.floor((available + 8) / (needed + 8))))
  local rows, tabHeight = math.ceil(#tabs / columns), 32 + (scale - 1) * 12
  for i, tab in ipairs(tabs) do
    local width = (available - (columns - 1) * 8) / columns
    tab:ClearAllPoints(); tab:SetPoint("TOPLEFT", 22 + ((i - 1) % columns) * (width + 8), -head - 10 - math.floor((i - 1) / columns) * (tabHeight + 8))
    tab:SetSize(width, tabHeight)
  end
  w.toolbar = head + 22 + rows * (tabHeight + 8)
  w.sync:ClearAllPoints(); w.sync:SetPoint("TOPRIGHT", -22, -w.toolbar); w.sync:SetSize(90 * scale, 28)
  w.review:ClearAllPoints(); w.review:SetPoint("RIGHT", w.sync, "LEFT", -12, 0); w.review:SetWidth(190 * scale)
  w.search:ClearAllPoints(); w.search:SetPoint("TOPLEFT", 22, -w.toolbar)
  w.search:SetPoint("RIGHT", (Board.tab == "guild" or Board.tab == "suggestions") and w.review or w.sync, "LEFT", -14, 0)
  w.viewHint:ClearAllPoints(); w.viewHint:SetPoint("TOPLEFT", 22, -w.toolbar - 42)
  w.viewHint:SetPoint("RIGHT", -22, 0); w.viewHint:SetHeight(48 + (scale - 1) * 20)
  w.listTop = w.toolbar + 100 + (scale - 1) * 20
  for i, row in ipairs(w.rows) do
    B.BoardRow.Layout(row); w.cardStep = row:GetHeight() + 6
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 22, -w.listTop - (i - 1) * w.cardStep); row:SetPoint("RIGHT", -22, 0)
  end
  w.guide:ClearAllPoints(); w.guide:SetPoint("TOPLEFT", 30, -w.toolbar - 4); w.guide:SetPoint("BOTTOMRIGHT", -22, 138)
  w.guide.body:SetWidth(available - 24)
  w.alerts:SetSize(106 * scale, 30); w.claims:SetSize(168 * scale, 30); w.help:SetSize(132 * scale, 30)
  w.browse:SetSize(230 * scale, 32); w.explore:SetSize(170 * scale, 32); w.emptyAction:SetSize(212 * scale, 32)
  if w.page then
    if w.page.close then w.page.close:SetShown(w:IsMovable()) end
    if w.page.LayoutPage then w.page:LayoutPage() end
  end
  w.layingOut = nil
end

function Board.Build()
  if Board.win then return Board.win end
  local w = Kit.Dialog(PREFIX .. "BountyFrame", { title = "BOUNTIES", width = Board.W, height = 690,
    header = 64, savedKey = "bounty", point = { "CENTER", "CENTER", 0, 20 }, accent = "gold" })
  Board.win = w
  w.browser = CreateFrame("Frame", nil, w); w.browser:SetAllPoints(w)
  w.create = Kit.Button(w.browser, "Create bounty", 194, 30, { tone = "gold", onClick = Board.Create })
  Kit.Tooltip(w.create, { "Create a bounty", "Choose a player and who can see it. Start with Only me for private alerts; add a reward when you want others to help." })
  w.tabs = {}
  for _, def in ipairs(TABS) do
    local tab = Kit.Tab(w.browser, def.label, function() Board.SetTab(def.key) end)
    Kit.Tooltip(tab, { def.label, def.help }); w.tabs[def.key] = tab
  end
  w.search = Kit.Input(w.browser, 240, "")
  w.search.hint = T.Text(w.search, "label", "textMuted")
  w.search.hint:SetPoint("LEFT", 8, 0); w.search.hint:SetText("Search player or poster")
  w.search:SetScript("OnTextChanged", function(self)
    self.hint:SetShown(self:GetText() == ""); Board.offset = 0; Board.Refresh()
  end)
  Kit.Tooltip(w.search, { "Search this board", "Find a player, realm, poster or audience. Clear the field to see the whole board." })
  w.review = Kit.Toggle(w.browser, "Awaiting approval", { width = 220, onChange = function(_, on)
    if Board.tab == "suggestions" then Board.showIgnored = on else Board.pendingOnly = on end
    Board.offset = 0; Board.Refresh()
  end })
  Kit.Tooltip(w.review, function()
    if Board.tab == "suggestions" then return { "Show ignored enemies", "Include ignored enemies. Choose Allow again to restore their suggestions." } end
    return { "Guild review queue", "Show submissions awaiting officer approval. Members see their own submissions; officers can review all of them." }
  end)
  w.viewHint = Text(w.browser, "body", "textMuted")
  w.rows = {}; for i = 1, Board.CARDS do w.rows[i] = B.BoardRow.Build(w.browser) end
  w.guide = Kit.ScrollArea(w.browser)
  w.guide.title = Text(w.guide.body, "cardTitle")
  w.empty = Text(w.guide.body, "body", "textMuted")
  w.guide.steps = {}
  for i = 1, #STEPS do w.guide.steps[i] = { title = Text(w.guide.body, "heading", "gold"), body = Text(w.guide.body, "body") } end
  w.guide.terms = Text(w.guide.body, "bodySmall", "textMuted")
  w.browse = Kit.Button(w.browser, "Browse shared bounties", 230, 32, { tone = "gold", onClick = function()
    Core.SetOption("bountyReceive", true); B.Public.TransportTick(); Board.Refresh()
  end })
  w.browse:SetPoint("BOTTOMLEFT", 30, 84)
  Kit.Tooltip(w.browse, { "Join the shared board", "Receive rewards from participating players on this realm and faction. Browsing does not publish your own bounties." })
  w.explore = Kit.Button(w.browser, "Browse rewards", 170, 32, { onClick = function() Board.SetTab("public") end })
  w.explore:SetPoint("LEFT", w.create, "RIGHT", 12, 0)
  Kit.Tooltip(w.explore, { "Hunt for a reward", "Open the shared board to find rewards offered by other players. You choose whether to receive them." })
  w.emptyAction = Kit.Button(w.browser, "", 212, 32, { onClick = function(self) if self.run then self.run() end end })
  w.emptyAction:SetPoint("BOTTOMLEFT", 30, 84)
  Kit.Tooltip(w.emptyAction, function(self) return { self:GetText(), w.empty:GetText() } end)
  w.alerts = Kit.Button(w.browser, "More tools", 106, 30, { onClick = Board.Tools })
  w.alerts:SetPoint("BOTTOMLEFT", 22, 18)
  Kit.Tooltip(w.alerts, { "More bounty tools", "Open attacker suggestions, shared alert preferences or bounty settings." })
  w.claims = Kit.Button(w.browser, "Claims & payments", 168, 30, { onClick = function() B.Ledger.Open() end })
  w.claims:SetPoint("LEFT", w.alerts, "RIGHT", 10, 0)
  Kit.Tooltip(w.claims, { "Claims and payments", "After reporting a kill, follow its review here. If you posted the reward, approve the report, pay through the game, then mark it paid." })
  w.help = Kit.Button(w.browser, "How it works", 132, 30, { onClick = function()
    Board.help = not Board.help; w.guide:Scroll(0); Board.Refresh()
  end })
  w.help:SetPoint("BOTTOMRIGHT", -22, 18)
  Kit.Tooltip(w.help, { "How bounties work", "Read the steps from choosing a target to paying a hunter. Your current board and search are kept." })
  w.sync = Kit.Button(w.browser, "Refresh", 90, 28, { onClick = function()
    if Board.tab == "public" then local _, message = B.Public.Sync(); B.Say(message)
    else B.Say(B.Messages.Sync(B.RequestSync())) end
  end })
  Kit.Tooltip(w.sync, { "Refresh this board", "Request current rewards from online participants. Shared rewards need browsing enabled; guild rewards need guild membership." })
  w.next = Kit.Button(w.browser, ">", 34, 26, { onClick = function() Board.offset = Board.offset + (w.visible or 1); Board.Refresh() end })
  w.next:SetPoint("BOTTOMRIGHT", -22, 64)
  w.prev = Kit.Button(w.browser, "<", 34, 26, { onClick = function() Board.offset = Board.offset - (w.visible or 1); Board.Refresh() end })
  w.prev:SetPoint("RIGHT", w.next, "LEFT", -6, 0)
  Kit.Tooltip(w.prev, { "Previous page", "Show previous bounties. The mouse wheel also scrolls the list." })
  Kit.Tooltip(w.next, { "Next page", "Show more bounties, including rewards below your alert minimum." })
  w.range = T.Text(w.browser, "bodySmall", "textMuted"); w.range:SetPoint("RIGHT", w.prev, "LEFT", -12, 0)
  w.browser:EnableMouseWheel(true); w.browser:SetScript("OnMouseWheel", function(_, delta) Board.offset = Board.offset - delta; Board.Refresh() end)
  Core.OnFontScaleChange(function() Board.Layout(w); Board.Refresh() end)
  T.OnChange(function() Board.Layout(w); Board.Refresh() end)
  w:SetScript("OnShow", function() Board.Refresh() end)
  w:HookScript("OnHide", function() if w.page then w.page:Hide() end end)
  w:SetScript("OnSizeChanged", function() Board.Layout(w); Board.Refresh() end)
  Board.Layout(w)
  return w
end

local function Guide(w, count, total)
  local query = w.search:GetText() ~= ""
  local intro = Board.help or Board.tab == "mine" and total == 0 and not query
  local browse = Board.tab == "public" and not B.Public.Receiving() and not Board.help
  local title, body = "No bounties here yet", "Create a bounty to choose a player and offer a reward."
  if intro then
    title = Board.help and "From a target to a reward" or "Start with a player you want to find"
    body = "Bounties help you spot a player again or offer gold for their defeat. Start privately, or invite other players to hunt."
  elseif query then title, body = "No matching bounties", "No matching bounties. Clear the search to see this board."
  elseif Board.tab == "guild" then
    title = not B.InGuild() and "Guild bounties need a guild" or Board.pendingOnly and "All caught up" or "Give your guild a target"
    body = not B.InGuild() and "Join a guild to see its bounties. You can still track a player privately in My bounties."
      or Board.pendingOnly and "No bounties are waiting for approval."
      or "Submit a player and an optional reward. An officer approves the bounty before guild members can see it."
  elseif Board.tab == "public" then
    title = browse and "Hunt for rewards from other players" or "Waiting for shared bounties"
    body = browse and "Browse rewards from players on your realm and faction who use Highground. This only receives their bounties; your private targets stay private."
      or "No shared rewards have arrived yet. Other players must be online with a compatible addon to send their offers. Try Refresh, or post the first reward."
  elseif Board.tab == "suggestions" then
    title = B.Suggestions.Enabled() and "No recurring attackers yet" or "Suggestions are optional"
    body = "Suggestions use repeated open-world death reports to help you choose a target. Enable them and choose thresholds in Bounty settings. Sharing your deaths is a separate option."
  end
  w.guide:SetShown(count == 0 or Board.help)
  local y, width = 0, w.guide.body:GetWidth()
  local function Place(text, value, gap)
    text:ClearAllPoints(); text:SetPoint("TOPLEFT", 0, -y); text:SetWidth(width); text:SetText(value)
    local height = text:GetStringHeight(); text:SetHeight(height); y = y + height + gap
  end
  Place(w.guide.title, title, 14); Place(w.empty, body, 24)
  for i, step in ipairs(w.guide.steps) do
    step.title:SetShown(intro); step.body:SetShown(intro)
    if intro then Place(step.title, STEPS[i][1], 6); Place(step.body, STEPS[i][2], 18) end
  end
  w.guide.terms:SetShown(intro or Board.tab == "public")
  if intro or Board.tab == "public" then Place(w.guide.terms, "Highground tracks reports and payments. Players send the gold themselves.", 8) end
  w.guide.body:SetHeight(y); w.guide:Refresh()
  w.explore:SetShown(intro); w.browse:SetShown(browse)
  w.emptyAction:SetShown(count == 0 and not intro and (query or Board.tab == "suggestions" or Board.pendingOnly))
  w.emptyAction:SetText(query and "Clear search" or Board.pendingOnly and "Show all guild bounties" or "Suggestion settings")
  w.emptyAction.run = query and function() w.search:SetText("") end
    or Board.pendingOnly and function() Board.SetTab("guild") end or Board.OpenSettings
  local createBelow = intro or count == 0 and not query and Board.tab == "guild" and not Board.pendingOnly
  w.create:ClearAllPoints(); w.create:SetPoint(createBelow and "BOTTOMLEFT" or "TOPRIGHT", createBelow and 30 or -52, createBelow and 84 or -16)
  w.create:SetText(intro and total == 0 and not Board.help and "Create first bounty" or createBelow and Board.tab == "guild"
    and (B.InGuild() and "Create guild bounty" or "Create private bounty") or "Create bounty")
  w.createMode = not Board.help and Board.tab == "public" and "public" or not Board.help and Board.tab == "guild" and B.InGuild() and "guild" or "personal"
  w.title:ClearAllPoints(); w.title:SetPoint("TOPLEFT", 22, -16)
  if createBelow then w.title:SetPoint("RIGHT", -52, 0) else w.title:SetPoint("RIGHT", w.create, "LEFT", -18, 0) end
  w.title:SetJustifyH("LEFT"); w.title:SetWordWrap(false)
end

function Board.Refresh()
  local w = Board.win
  if not (w and w:IsShown()) or w.refreshing or w.layingOut then return end
  w.refreshing = true
  local total = 0
  for _, def in ipairs(TABS) do
    local count = #B.BoardModel.Rows(def.key)
    w.tabs[def.key]:Select(Board.tab == def.key)
    w.tabs[def.key].count:SetText(tostring(count)); w.tabs[def.key].count:SetShown(count > 0)
    if def.key == Board.tab then total = count end
  end
  Board.Layout(w)
  local suggestions = Board.tab == "suggestions"
  local list = B.BoardModel.Rows(Board.tab, w.search:GetText(), suggestions and Board.showIgnored or Board.tab == "guild" and Board.pendingOnly)
  local footer = Board.tab == "public" and not B.Public.Receiving() and 138 or 108
  w.visible = math.max(1, math.min(Board.CARDS, math.floor((w:GetHeight() - w.listTop - footer) / w.cardStep)))
  Board.offset = math.max(0, math.min(Board.offset, #list - w.visible))
  for i, row in ipairs(w.rows) do
    local b = not Board.help and i <= w.visible and list[Board.offset + i]
    if b then B.BoardRow.Fill(row, b) else row.entry = nil; row:Hide() end
  end
  Guide(w, #list, total)
  local filtering = not Board.help and (total > 0 or w.search:GetText() ~= "" or Board.pendingOnly or suggestions)
  w.search:SetShown(filtering); w.review:SetShown(filtering and (Board.tab == "guild" or suggestions))
  w.review.label:SetText(suggestions and "Show ignored" or "Awaiting approval")
  w.review:SetChecked(suggestions and Board.showIgnored == true or not suggestions and Board.pendingOnly == true, true)
  if filtering and #list == 0 and not Board.help then w.guide:SetPoint("TOPLEFT", 30, -w.listTop) end
  w.help:SetText(Board.help and "Back to board" or "How it works")
  local hint = Board.message or (Board.tab == "mine" and "Targets you track and rewards you offer. Only me means private alerts; Guild and Shared invite other hunters."
    or suggestions and "Review the death reports, then choose whether to create a bounty. Nothing is posted automatically."
    or Board.tab == "guild" and "Hunt an approved target, then open its bounty to report your kill. Follow the result in Claims & payments."
    or not B.Public.Receiving() and "Browsing is paused. Saved rewards remain below. Choose Browse shared bounties to receive new offers."
    or "Open a bounty to see who pays and report a kill. Lower rewards stay listed below your alert minimum.")
  w.viewHint:SetText(hint); T.Paint(w.viewHint, Board.message and "success" or "textMuted")
  w.viewHint:SetShown(#list > 0 and not Board.help)
  w.sync:SetShown(not Board.help and not suggestions and (Board.tab == "public" and B.Public.Receiving() or Board.tab ~= "public" and B.InGuild()))
  w.sync:SetEnabled(true)
  local pages = #list > w.visible and not Board.help
  w.range:SetText(string.format("%d–%d of %d", Board.offset + 1, math.min(#list, Board.offset + w.visible), #list))
  w.range:SetShown(pages); w.prev:SetShown(pages); w.next:SetShown(pages)
  w.prev:SetEnabled(Board.offset > 0); w.next:SetEnabled(Board.offset + w.visible < #list)
  w.refreshing = nil
end

function Board.SetTab(key)
  if Board.win and Board.win.page then Board.win.page:Hide() end
  Board.pendingOnly = key == "pending"
  Board.tab, Board.offset = key == "all" and "mine" or key == "pending" and "guild" or key, 0
  Board.help, Board.message = nil, nil
  if Board.win then Board.win.search:SetText(""); Board.win.guide:Scroll(0) end
  Board.Refresh()
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
  local w = Board.Build()
  if not w:IsVisible() then Board.message = nil end
  w:Show(); Board.Refresh()
  if name then B.Form.Open(name) end
end

function Board.Toggle()
  local w = Board.Build()
  if ns.Hub then ns.Hub.Release(w) end
  if w:IsShown() then w:Hide() else Board.Open() end
end

function Board.OpenSettings()
  if ns.Options and ns.Options.OpenPage then ns.Options.OpenPage("bounty")
  elseif ns.StandaloneSettings then ns.StandaloneSettings.Open() end
end

B.Listen("updated", Board.Refresh)
B.Listen("changed", Board.Refresh)
_G["BINDING_NAME_" .. PREFIX:upper() .. "_BOUNTY"] = "Toggle the bounty board"
_G[PREFIX .. "_BountyBoard"] = function()
  if ns.STANDBY then return ns.Util.Say((ns.STANDBY_LABEL or "Highground") .. " is loaded: use " .. (ns.STANDBY_COMMAND or "/hg bounty")) end
  Board.Toggle()
end
