local _, ns = ...
local Core, B, T, Kit = ns.Core, ns.Bounty, ns.Theme, ns.Kit
local Board = { tab = "mine", offset = 0, CARDS = 7, W = 760 }
B.Board = Board
local PREFIX = ns.FRAME_PREFIX or "Highground"
local TABS = {
  { key = "mine", label = "My bounties", help = "Your private targets and rewards you posted. Each target appears once, with its audience labelled." },
  { key = "guild", label = "Guild board", help = "Guild listings and submissions you can review. A linked shared contribution is the same reward, payable once." },
  { key = "public", label = "Shared board", help = "Rewards from participating players on your realm and faction. Smaller rewards stay visible below those matching your alert minimum." },
}
local EMPTY = { mine = "You have no active bounties. Use Create bounty to add one.",
  guild = "No guild bounties in this view.", public = "No shared rewards received yet. Posters must be online to sync." }

function Board.Layout(w)
  local scale = math.max(1, Core.FontScale())
  local head = 64 + (scale - 1) * 24
  w.head:SetHeight(head); w.bar:SetHeight(head)
  w.rule:ClearAllPoints(); w.rule:SetPoint("TOPLEFT", 1, -head); w.rule:SetPoint("TOPRIGHT", -1, -head)
  w.create:SetSize(190 * scale, 30 + (scale - 1) * 10)
  for i, def in ipairs(TABS) do
    local tab = w.tabs[def.key]
    local width = 190 + (scale - 1) * 24
    tab:ClearAllPoints(); tab:SetPoint("TOPLEFT", 22 + (i - 1) * (width + 8), -head - 8)
    tab:SetSize(width, 30 + (scale - 1) * 12)
  end
  local toolbar = head + 52 + (scale - 1) * 12
  w.review:ClearAllPoints(); w.review:SetPoint("TOPRIGHT", -22, -toolbar); w.review:SetWidth(190 * scale)
  w.search:ClearAllPoints(); w.search:SetPoint("TOPLEFT", 22, -toolbar); w.search:SetPoint("RIGHT", w.review, "LEFT", -18, 0)
  w.viewHint:ClearAllPoints(); w.viewHint:SetPoint("TOPLEFT", 22, -toolbar - 40)
  w.viewHint:SetPoint("RIGHT", -22, 0); w.viewHint:SetHeight(44 + (scale - 1) * 10)
  w.browse:ClearAllPoints(); w.browse:SetPoint("TOPRIGHT", -22, -toolbar - 38); w.browse:SetSize(220 * scale, 30 + (scale - 1) * 12)
  w.listTop = toolbar + 94 + (scale - 1) * 10
  for i, row in ipairs(w.rows) do
    B.BoardRow.Layout(row)
    w.cardStep = row:GetHeight() + 6
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", 22, -w.listTop - (i - 1) * w.cardStep)
    row:SetPoint("RIGHT", -22, 0)
  end
  w.empty:ClearAllPoints(); w.empty:SetPoint("TOPLEFT", 36, -w.listTop - 38); w.empty:SetPoint("RIGHT", -36, 0)
  w.alerts:SetWidth(128 * scale); w.claims:SetWidth(88 * scale); w.sync:SetWidth(76 * scale)
end

function Board.Build()
  if Board.win then return Board.win end
  local w = Kit.Dialog(PREFIX .. "BountyFrame", { title = "BOUNTIES", width = Board.W, height = 690,
    header = 64, savedKey = "bounty", point = { "CENTER", "CENTER", 0, 20 }, accent = "gold" })
  Board.win = w
  w.create = Kit.Button(w, "Create bounty", 190, 30, { tone = "gold", onClick = function()
    B.Form.Open(nil, Board.tab == "public" and "public" or Board.tab == "guild" and "guild" or "personal")
  end })
  w.create:SetPoint("TOPRIGHT", -52, -16)
  w.title:SetPoint("RIGHT", w.create, "LEFT", -18, 0); w.title:SetJustifyH("LEFT"); w.title:SetWordWrap(false)
  Kit.Tooltip(w.create, { "Create a bounty", "Choose Only me, Guild or Shared, then enter the target and reward. Shared publishing can be enabled directly on the final action." })
  w.tabs = {}
  for _, def in ipairs(TABS) do
    local tab = Kit.Tab(w, def.label, function() Board.SetTab(def.key) end)
    Kit.Tooltip(tab, { def.label, def.help }); w.tabs[def.key] = tab
  end
  w.search = Kit.Input(w, 240, "")
  w.search.hint = T.Text(w.search, "label", "textMuted")
  w.search.hint:SetPoint("LEFT", 8, 0); w.search.hint:SetText("Search player or poster")
  w.search:SetScript("OnTextChanged", function(self)
    self.hint:SetShown(self:GetText() == ""); Board.offset = 0; Board.Refresh()
  end)
  Kit.Tooltip(w.search, { "Search this board", "Find a player, realm, poster or audience in the selected view. Clear the field to see the whole list." })
  w.review = Kit.Toggle(w, "Awaiting approval", { width = 220, onChange = function(_, on)
    Board.pendingOnly, Board.offset = on, 0; Board.Refresh()
  end })
  Kit.Tooltip(w.review, { "Guild review queue", "Show only submissions awaiting an officer's approval. Members see their own submissions; officers can review all of them." })
  w.viewHint = T.Text(w, "body", "textMuted"); w.viewHint:SetJustifyH("LEFT"); w.viewHint:SetJustifyV("TOP")
  w.browse = Kit.Button(w, "Browse shared bounties", 220, 30, { tone = "gold", onClick = function()
    Core.SetOption("bountyReceive", true); B.Public.TransportTick(); Board.Refresh()
  end })
  Kit.Tooltip(w.browse, { "Join the shared board", "Opt into receiving other players' contributions on this realm and faction. This does not publish your private or guild bounties." })
  w.rows = {}; for i = 1, Board.CARDS do w.rows[i] = B.BoardRow.Build(w) end
  w.empty = T.Text(w, "body", "textMuted"); w.empty:SetJustifyH("CENTER")
  w.alerts = Kit.Button(w, "Alert settings", 128, 30, { onClick = function() B.Preferences.Open() end })
  w.alerts:SetPoint("BOTTOMLEFT", 22, 18)
  Kit.Tooltip(w.alerts, { "Shared alerts and browsing", "Set your notification minimum, browse shared rewards, or pause advertising your contributions. Lower rewards remain visible." })
  w.claims = Kit.Button(w, "Claims", 88, 30, { onClick = function() B.Ledger.Open() end })
  w.claims:SetPoint("LEFT", w.alerts, "RIGHT", 10, 0)
  Kit.Tooltip(w.claims, { "Claims and payments", "Review kill reports, approve a winner, and record manual payments. A contribution shared with a guild has one claim history." })
  w.sync = Kit.Button(w, "Sync", 76, 30, { onClick = function()
    if Board.tab == "public" then local _, message = B.Public.Sync(); B.Say(message)
    else B.Say(B.Messages.Sync(B.RequestSync())) end
  end })
  w.sync:SetPoint("LEFT", w.claims, "RIGHT", 10, 0)
  Kit.Tooltip(w.sync, { "Refresh bounties", "Request current contributions from online shared participants, or the guild list when viewing Guild or My bounties." })
  w.next = Kit.Button(w, ">", 34, 30, { onClick = function() Board.offset = Board.offset + (w.visible or 1); Board.Refresh() end })
  w.next:SetPoint("BOTTOMRIGHT", -22, 18)
  w.prev = Kit.Button(w, "<", 34, 30, { onClick = function() Board.offset = Board.offset - (w.visible or 1); Board.Refresh() end })
  w.prev:SetPoint("RIGHT", w.next, "LEFT", -6, 0)
  Kit.Tooltip(w.prev, { "Previous page", "Show the previous bounties. The mouse wheel also scrolls the list." })
  Kit.Tooltip(w.next, { "Next page", "Show more bounties, including rewards below your notification minimum." })
  w.range = T.Text(w, "bodySmall", "textMuted"); w.range:SetPoint("BOTTOMRIGHT", -22, 58)
  w:EnableMouseWheel(true); w:SetScript("OnMouseWheel", function(_, delta) Board.offset = Board.offset - delta; Board.Refresh() end)
  Board.Layout(w)
  Core.OnFontScaleChange(function() Board.Layout(w); Board.Refresh() end)
  w:SetScript("OnShow", function() Board.Refresh() end)
  w:SetScript("OnSizeChanged", function() if not w.layingOut then w.layingOut = true; Board.Layout(w); w.layingOut = nil; Board.Refresh() end end)
  return w
end

function Board.Refresh()
  local w = Board.win
  if not (w and w:IsShown()) then return end
  for _, def in ipairs(TABS) do
    w.tabs[def.key]:Select(Board.tab == def.key)
    w.tabs[def.key].count:SetText(tostring(#B.BoardModel.Rows(def.key)))
  end
  local list = B.BoardModel.Rows(Board.tab, w.search:GetText(), Board.tab == "guild" and Board.pendingOnly)
  w.visible = math.max(1, math.min(Board.CARDS, math.floor((w:GetHeight() - w.listTop - 84) / w.cardStep)))
  Board.offset = math.max(0, math.min(Board.offset, #list - w.visible))
  for i, row in ipairs(w.rows) do
    local b = i <= w.visible and list[Board.offset + i]
    if b then B.BoardRow.Fill(row, b) else row.entry = nil; row:Hide() end
  end
  w.review:SetShown(Board.tab == "guild"); w.review:SetChecked(Board.pendingOnly == true, true)
  local browse = Board.tab == "public" and not B.Public.Receiving()
  w.browse:SetShown(browse)
  w.viewHint:ClearAllPoints(); w.viewHint:SetPoint("TOPLEFT", w.search, "BOTTOMLEFT", 0, -14)
  if browse then w.viewHint:SetPoint("RIGHT", w.browse, "LEFT", -12, 0) else w.viewHint:SetPoint("RIGHT", -22, 0) end
  local hint = Board.tab == "mine" and "Your rewards, one row per target. The audience tells you who can see each bounty."
    or Board.tab == "guild" and (B.InGuild() and "Guild listings. Guild + Shared means one reward, payable once." or "Join a guild to browse or submit guild bounties.")
    or browse and "Shared browsing is off. Join to see other players' rewards."
    or ("Notify from " .. ns.Util.Gold(Core.O("bountyMinGold") or 0) .. ". Lower rewards stay below matching bounties.")
  w.viewHint:SetText(hint)
  w.empty:SetText(#list == 0 and (w.search:GetText() ~= "" and "No matching bounties." or EMPTY[Board.tab]) or "")
  w.range:SetText(#list == 0 and "0 bounties" or string.format("%d–%d / %d", Board.offset + 1, math.min(#list, Board.offset + w.visible), #list))
  w.prev:SetEnabled(Board.offset > 0); w.next:SetEnabled(Board.offset + w.visible < #list)
end

function Board.SetTab(key)
  Board.pendingOnly = key == "pending"
  Board.tab, Board.offset = key == "all" and "mine" or key == "pending" and "guild" or key, 0
  if Board.win then Board.win.search:SetText("") end
  Board.Refresh()
end

function Board.TargetPlayer()
  local U = ns.Util
  if not U.read(UnitExists, "target") then return nil, "Select a player first, then click Use target." end
  if not U.read(UnitIsPlayer, "target") then return nil, "That target is not a player. Select a player first." end
  if U.read(UnitIsUnit, "target", "player") then return nil, "Select another player for the bounty." end
  -- Copying a name must not depend on faction, PvP flags or attackability.
  local name = Core.CanonUnit("target")
  if not name then return nil, "That player's name is unavailable. Try again or enter the name manually." end
  return name
end

function Board.Open(name)
  local w = Board.Build(); w:Show(); Board.Refresh()
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
