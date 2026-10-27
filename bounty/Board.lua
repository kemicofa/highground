local _, ns = ...
local Core, Bounty = ns.Core, ns.Bounty
Bounty.Board = {}
local Board, W, Theme, Kit = Bounty.Board, Bounty.Widgets, ns.Theme, ns.Kit

---------------------------------------------------------------------------
-- Bounty board: every bounty you can see as wanted cards, filtered by tab
-- (all, yours, approved guild bounties, submissions awaiting an officer)
-- and by name. A compose bar adds a bounty, typed or from your target.
-- Opens with /wb bounty, its key binding, an enemy's right-click menu
-- (Retail and Forever) or the Guild bounties settings page.
---------------------------------------------------------------------------
Board.CARDS = 7
Board.CARD_H = 50
Board.W = 600
Board.tab = "all"
Board.offset = 0
local HEAD, TABS, COMPOSE, FOOT = 64, 34, 70, 30
local LIST_TOP = HEAD + TABS + 6

local TABS_DEF = {
  { key = "all", label = "ALL" },
  { key = "mine", label = "MINE" },
  { key = "guild", label = "GUILD" },
  { key = "pending", label = "PENDING" },
}

local EMPTY = { all = "No bounties yet. Add one below.", mine = "You have no bounties.",
  guild = "No approved guild bounties.", pending = "Nothing awaiting approval." }

local Say, M = Bounty.Say, Bounty.Messages
local function Number(n) return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n) end

-- Bounty.Act emits "updated" on success, which refreshes the board.
local function Act(action, name)
  local _, text = Bounty.Act(action, name)
  Say(text)
end

local FILTER = {
  all = function() return true end,
  mine = function(b, me) return b.state == "personal" or b.by == me end,
  guild = function(b) return b.state == "approved" end,
  pending = function(b) return b.state == "pending" end,
}

-- { label, action (bounty/Messages.lua), button tone } per card, by state
-- and your role.
local function Actions(b)
  local officer, mine = Bounty.IsOfficer(), b.by == Bounty.Me()
  if b.state == "personal" then
    local list = {}
    if Bounty.InGuild() then list[#list + 1] = { "Submit", "submit" } end
    list[#list + 1] = { "Remove", "remove" }
    return list
  elseif b.state == "pending" and officer then
    return { { "Approve", "approve", "gold" }, { "Reject", "reject" } }
  elseif officer or mine then
    return { { b.state == "pending" and "Withdraw" or "Remove", "remove" } }
  end
  return {}
end

local function Line(text, color, wrap)
  Theme.TipLine(GameTooltip, text, color, wrap)
end

function Board.Tooltip(r)
  local b = r.entry
  if not b then return end
  GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
  Line(Core.DisplayName(b.name), "gold")
  Line(b.gold > 0 and (Bounty.GoldText(b) .. " reward") or "No reward", "white")
  if b.note then Line(b.note, "text", true) end
  Line(b.state == "personal" and "Personal: alerts only you" or ("Placed by " .. Core.DisplayName(b.by or "?")), "textMuted")
  if b.approver then Line("Approved by " .. Core.DisplayName(b.approver), "textMuted") end
  if b.seenAt then
    Line("Last seen " .. W.Ago(time() - b.seenAt):lower() .. (b.seenZone and (" in " .. b.seenZone) or "")
      .. (b.seenBy and (" by " .. Core.DisplayName(b.seenBy)) or ""), "accent")
  end
  GameTooltip:Show()
end

-- Header on the gold Kit.Dialog chrome: icon, title, guild line (the sub
-- line), purse.
local function BuildHeader(w)
  w.icon = w:CreateTexture(nil, "ARTWORK")
  w.icon:SetSize(36, 36)
  w.icon:SetPoint("TOPLEFT", 16, -14)
  w.icon:SetTexture(Bounty.ICON)
  w.icon:SetTexCoord(unpack(Bounty.ICON_CROP))
  w.title:ClearAllPoints()
  w.title:SetPoint("TOPLEFT", 62, -12)
  w.guild = w.sub
  w.purse = Theme.Text(w, "displayLarge", "gold")
  w.purse:SetPoint("TOPRIGHT", -44, -10)
  w.purseLabel = Theme.Text(w, "caption", "textMuted")
  w.purseLabel:SetPoint("TOPRIGHT", w.purse, "BOTTOMRIGHT", 0, -1)
  w.purseLabel:SetText("GUILD PURSE")
  Kit.Paint(w.close, "panel")
end

local function BuildTabs(w)
  w.tabs = {}
  for i, def in ipairs(TABS_DEF) do
    local t = Kit.Tab(w, def.label, function() Board.SetTab(def.key) end)
    t:SetPoint("TOPLEFT", 14 + (i - 1) * 92, -HEAD - 6)
    w.tabs[def.key] = t
  end
  w.search = Kit.Input(w, 150, "")
  w.search:SetPoint("TOPRIGHT", -14, -HEAD - 8)
  w.search.hint = Theme.Text(w.search, "label", "textMuted")
  w.search.hint:SetPoint("LEFT", 8, 0)
  w.search.hint:SetText("SEARCH")
  w.search:SetScript("OnTextChanged", function(self)
    self.hint:SetShown(self:GetText() == "")
    Board.offset = 0
    Board.Refresh()
  end)
end

local function BuildCompose(w)
  local well = Theme.Fill(w, "BORDER", "surface", "bar")
  well:SetPoint("BOTTOMLEFT", 1, FOOT)
  well:SetPoint("BOTTOMRIGHT", -1, FOOT)
  well:SetHeight(COMPOSE)
  w.compose = Theme.Text(w, "heading", "gold")
  w.compose:SetPoint("BOTTOMLEFT", 14, FOOT + COMPOSE - 18)
  w.compose:SetText("NEW BOUNTY")
  local function Button(label, width, tone, onClick)
    return Kit.Button(w, label, width, 24, { tone = tone, onClick = onClick })
  end
  w.name = Kit.Input(w, 140, "NAME (NAME-REALM ELSEWHERE)")
  w.name:SetPoint("BOTTOMLEFT", 14, FOOT + 10)
  w.target = Button("Target", 56, "panel", function() Board.FillTarget() end)
  w.target:SetPoint("LEFT", w.name, "RIGHT", 4, 0)
  w.gold = Kit.Input(w, 70, "GOLD (OPTIONAL)")
  w.gold:SetPoint("LEFT", w.target, "RIGHT", 10, 0)
  w.note = Kit.Input(w, 120, "NOTE")
  w.note:SetPoint("LEFT", w.gold, "RIGHT", 10, 0)
  w.add = Button("Add", 52, "panel", function() Board.AddFromForm(false) end)
  w.add:SetPoint("LEFT", w.note, "RIGHT", 10, 0)
  w.submit = Button("Add + submit", 92, "gold", function() Board.AddFromForm(true) end)
  w.submit:SetPoint("LEFT", w.add, "RIGHT", 4, 0)
  for _, e in ipairs({ w.name, w.gold, w.note }) do
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Board.AddFromForm(false) end)
  end
end

local function BuildFooter(w)
  w.empty = Theme.Text(w, "rowName", "textMuted")
  w.empty:SetPoint("TOP", 0, -LIST_TOP - 70)
  w.range = Theme.Text(w, "caption", "textMuted")
  w.range:SetPoint("BOTTOMRIGHT", -14, FOOT + COMPOSE + 4)
  w.settings = Kit.Button(w, "Settings", 72, 20, { onClick = function() Board.OpenSettings() end })
  w.settings:SetPoint("BOTTOMLEFT", 12, 5)
  w.sync = Kit.Button(w, "Sync guild", 84, 20, { onClick = function() Say(M.Sync(Bounty.RequestSync())) end })
  w.sync:SetPoint("LEFT", w.settings, "RIGHT", 4, 0)
  w.help = Theme.Text(w, "caption", "textMuted")
  w.help:SetPoint("BOTTOMRIGHT", -14, 11)
end

-- The window; the Warboard hub borrows it (hub/Hub.lua hides w.close).
function Board.Build()
  if Board.win then return Board.win end
  local w = Kit.Dialog("WarboardBountyFrame", { title = "BOUNTY BOARD", width = Board.W,
    height = LIST_TOP + Board.CARDS * (Board.CARD_H + 4) + 18 + COMPOSE + FOOT,
    savedKey = "bounty", point = { "CENTER", "CENTER", 0, 60 }, header = HEAD, accent = "gold", borderAlpha = 0.55 })
  Board.win = w
  BuildHeader(w)
  BuildTabs(w)
  w.rows = {}
  for i = 1, Board.CARDS do
    local r = W.Card(w, Board.CARD_H, Board.Tooltip)
    r:SetPoint("TOPLEFT", 12, -LIST_TOP - (i - 1) * (Board.CARD_H + 4))
    r:SetPoint("RIGHT", w, "RIGHT", -12, 0)
    w.rows[i] = r
  end
  pcall(w.EnableMouseWheel, w, true)
  w:SetScript("OnMouseWheel", function(_, delta)
    Board.offset = math.max(0, Board.offset - delta)
    Board.Refresh()
  end)
  BuildFooter(w)
  BuildCompose(w)
  w:SetScript("OnShow", function() Board.Refresh() end)
  return w
end

local function FillCard(r, b, now)
  r.entry = b
  local state = W.STATE[b.state] or W.STATE.personal
  r:SetStrip(state.token)
  local short, realm = b.name:match("^([^-]+)-(.+)$")
  r.name:SetText(short or b.name)
  r.realm:SetText(realm and realm ~= Core.myRealm and realm or "")
  local cc = ns.Util.ClassColor(b.class)
  if cc then
    Theme.Unpaint(r.name)
    r.name:SetTextColor(cc.r, cc.g, cc.b)
  else
    Theme.Paint(r.name, "text")
  end
  if not (b.class and pcall(r.icon.SetAtlas, r.icon, "classicon-" .. b.class:lower())) then
    r.icon:SetTexture(Bounty.ICON)
    r.icon:SetTexCoord(unpack(Bounty.ICON_CROP))
  end
  local by = b.state == "personal" and "YOURS" or ("BY " .. Core.DisplayName(b.by or "?"):upper())
  r.sub:SetText(by .. (b.approver and ("  ·  OK " .. Core.DisplayName(b.approver):upper()) or "")
    .. (b.note and ("  ·  " .. b.note) or ""))
  r.gold:SetText(b.gold > 0 and Number(b.gold) or "WANTED")
  r.coin:SetShown(b.gold > 0)
  r.tag:SetText(state[1])
  Theme.Paint(r.tag, state.token)
  Theme.Paint(r.chipBg, state.token, "chip")
  if b.seenAt then
    local ago = now - b.seenAt
    r.seen:SetText("SEEN " .. W.Ago(ago) .. (b.seenZone and b.seenZone ~= "" and ("  " .. b.seenZone:upper()) or ""))
    Theme.Paint(r.seen, ago < 600 and "danger" or "textMuted")
  else
    r.seen:SetText("NOT SEEN YET")
    Theme.Paint(r.seen, "textMuted")
  end
  local actions = Actions(b)
  for j, btn in ipairs(r.buttons) do
    local a = actions[#actions - #r.buttons + j] -- right-aligned
    local action, name = a and a[2], b.name
    btn.run = a and function() Act(action, name) end
    btn:SetText(a and a[1] or "")
    if a then Kit.Paint(btn, a[3] or "panel") end
    btn:SetShown(a ~= nil)
  end
  r:Show()
end

function Board.Refresh()
  local w = Board.win
  if not (w and w:IsShown()) then return end
  local me = Bounty.Me()
  local query = w.search:GetText():lower()
  local counts, purse, list = {}, 0, {}
  for _, b in ipairs(Bounty.All()) do
    if b.state == "approved" then purse = purse + b.gold end
    for key, f in pairs(FILTER) do
      if f(b, me) then counts[key] = (counts[key] or 0) + 1 end
    end
    if FILTER[Board.tab](b, me) and (query == "" or b.name:lower():find(query, 1, true)) then
      list[#list + 1] = b
    end
  end
  for key, t in pairs(w.tabs) do
    t:Select(key == Board.tab)
    local n = counts[key] or 0
    t.count:SetText(n > 0 and tostring(n) or "")
    Theme.Paint(t.count, key == "pending" and n > 0 and "warning" or "textMuted")
  end
  Board.offset = math.max(0, math.min(Board.offset, #list - Board.CARDS))
  local now = time()
  for i, r in ipairs(w.rows) do
    local b = list[i + Board.offset]
    if b then FillCard(r, b, now) else r.entry = nil; r:Hide() end
  end
  w.empty:SetText(#list == 0 and (query ~= "" and "No match." or EMPTY[Board.tab]) or "")
  w.range:SetText(#list > Board.CARDS and string.format("%d-%d OF %d  ·  SCROLL", Board.offset + 1,
    math.min(#list, Board.offset + Board.CARDS), #list) or "")
  local gname = ns.Util.value(ns.Util.call(GetGuildInfo, "player"))
  w:SetSub(type(gname) == "string" and gname ~= ""
    and (gname:upper() .. "  ·  " .. (Bounty.IsOfficer() and "OFFICER" or "MEMBER"))
    or "NO GUILD  ·  PERSONAL BOUNTIES ONLY")
  w.purse:SetText(ns.Util.Gold(purse))
  w.help:SetText(Core.On("bounty") and "PERSONAL BOUNTIES ALERT ONLY YOU" or "ALERTS OFF  ·  GENERAL PAGE")
end

Bounty.Listen("updated", function() Board.Refresh() end)
Bounty.Listen("changed", function() Board.Refresh() end)

function Board.SetTab(key)
  Board.tab, Board.offset = key, 0
  Board.Refresh()
end

-- Your target when it is a hostile player, for the name field.
function Board.EnemyTarget()
  if not (UnitExists("target") and Bounty.IsOtherPlayer("target")) then return nil end
  local Call, Plain = ns.Util.call, ns.Util.value
  local hostile = Plain(Call(UnitCanAttack, "player", "target")) or Plain(Call(UnitIsEnemy, "player", "target"))
  return hostile and Core.CanonUnit("target") or nil
end

function Board.FillTarget()
  local key = UnitExists("target") and Core.CanonUnit("target")
  if not key then return Say("target an enemy player first") end
  Board.win.name:SetText(Core.DisplayName(key))
end

function Board.AddFromForm(submit)
  local w = Board.win
  local b, err = Bounty.Add(w.name:GetText(), w.gold:GetText(), w.note:GetText())
  if not b then return Say(err) end
  local s, serr
  if submit then s, serr = Bounty.Submit(b.name) end
  Say(M.Added(b, s, submit and serr))
  w.name:SetText("")
  w.gold:SetText("")
  w.note:SetText("")
  Board.Refresh()
end

function Board.Open(name)
  local w = Board.Build()
  w:Show()
  name = name or Board.EnemyTarget()
  if name then w.name:SetText(Core.DisplayName(name)) end
  Board.Refresh()
end

function Board.Toggle()
  local w = Board.Build()
  if ns.Hub then ns.Hub.Release(w) end
  if w:IsShown() then w:Hide() else Board.Open() end
end

function Board.OpenSettings()
  if ns.Options and ns.Options.OpenPage then ns.Options.OpenPage("bounty") end
end

-- Key binding (Bindings.xml).
BINDING_NAME_WARBOARD_BOUNTY = "Toggle the bounty board"
Warboard_BountyBoard = function() Board.Toggle() end
