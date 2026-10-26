local _, ns = ...
local Core, Bounty = ns.Core, ns.Bounty
Bounty.Board = {}
local Board, W = Bounty.Board, Bounty.Widgets
local C = Core.THEME.colors

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

local function Say(text) Bounty.Say(text) end
local function Number(n) return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n) end

local function Act(fn, name, done)
  local b, err = fn(name)
  Say(b and done(b) or err or "failed")
  Board.Refresh()
end

local FILTER = {
  all = function() return true end,
  mine = function(b, me) return b.state == "personal" or b.by == me end,
  guild = function(b) return b.state == "approved" end,
  pending = function(b) return b.state == "pending" end,
}

-- { label, run, fill color } per card, by state and your role.
local function Actions(b)
  local officer, mine, name = Bounty.IsOfficer(), b.by == Bounty.Me(), b.name
  local short = Core.DisplayName(name)
  local function removed() return "removed " .. short end
  if b.state == "personal" then
    local list = {}
    if Bounty.InGuild() then
      list[#list + 1] = { "Submit", function()
        Act(Bounty.Submit, name, function(e)
          return e.state == "approved" and ("posted " .. short .. " to the guild")
            or ("submitted " .. short .. ": an officer must approve it")
        end)
      end }
    end
    list[#list + 1] = { "Remove", function() Act(Bounty.Remove, name, removed) end }
    return list
  elseif b.state == "pending" and officer then
    return {
      { "Approve", function() Act(Bounty.Approve, name, function() return "approved " .. short end) end, W.GOLD },
      { "Reject", function() Act(Bounty.Remove, name, function() return "rejected " .. short end) end },
    }
  elseif officer or mine then
    return { { b.state == "pending" and "Withdraw" or "Remove", function() Act(Bounty.Remove, name, removed) end } }
  end
  return {}
end

function W.CardTooltip(r)
  local b = r.entry
  if not b then return end
  GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
  GameTooltip:AddLine(Core.DisplayName(b.name), W.GOLD[1], W.GOLD[2], W.GOLD[3])
  GameTooltip:AddLine(b.gold > 0 and (Bounty.GoldText(b) .. " reward") or "No reward", 1, 1, 1)
  if b.note then GameTooltip:AddLine(b.note, 0.9, 0.9, 0.9, true) end
  GameTooltip:AddLine(b.state == "personal" and "Personal: alerts only you"
    or ("Placed by " .. Core.DisplayName(b.by or "?")), 0.7, 0.7, 0.75)
  if b.approver then GameTooltip:AddLine("Approved by " .. Core.DisplayName(b.approver), 0.7, 0.7, 0.75) end
  if b.seenAt then
    GameTooltip:AddLine("Last seen " .. W.Ago(time() - b.seenAt):lower() .. (b.seenZone and (" in " .. b.seenZone) or "")
      .. (b.seenBy and (" by " .. Core.DisplayName(b.seenBy)) or ""), 0.45, 0.85, 0.8)
  end
  GameTooltip:Show()
end

local function BuildHeader(w)
  local band = Core.Fill(w, "BORDER", W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.06)
  band:SetPoint("TOPLEFT", 1, -1)
  band:SetPoint("TOPRIGHT", -1, -1)
  band:SetHeight(HEAD)
  local bar = Core.Fill(w, "ARTWORK", W.GOLD[1], W.GOLD[2], W.GOLD[3], 1)
  bar:SetPoint("TOPLEFT", 1, -1)
  bar:SetSize(4, HEAD)
  w.icon = w:CreateTexture(nil, "ARTWORK")
  w.icon:SetSize(36, 36)
  w.icon:SetPoint("TOPLEFT", 16, -14)
  w.icon:SetTexture(Bounty.ICON)
  w.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  w.title = Core.Text(w, "bold", 24)
  w.title:SetPoint("TOPLEFT", 62, -12)
  w.title:SetText("BOUNTY BOARD")
  w.title:SetTextColor(unpack(C.text))
  w.guild = Core.Text(w, "mono", 9)
  w.guild:SetPoint("TOPLEFT", w.title, "BOTTOMLEFT", 1, -3)
  w.guild:SetTextColor(unpack(C.muted))
  w.purse = Core.Text(w, "bold", 26)
  w.purse:SetPoint("TOPRIGHT", -44, -10)
  w.purse:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
  w.purseLabel = Core.Text(w, "mono", 8)
  w.purseLabel:SetPoint("TOPRIGHT", w.purse, "BOTTOMRIGHT", 0, -1)
  w.purseLabel:SetTextColor(unpack(C.muted))
  w.purseLabel:SetText("GUILD PURSE")
  w.close = W.Button(w, "X", 24, 24, C.panel, function() w:Hide() end)
  w.close:SetPoint("TOPRIGHT", -10, -10)
end

local function BuildTabs(w)
  w.tabs = {}
  for i, def in ipairs(TABS_DEF) do
    local t = W.Tab(w, def.label, function() Board.SetTab(def.key) end)
    t:SetPoint("TOPLEFT", 14 + (i - 1) * 92, -HEAD - 6)
    w.tabs[def.key] = t
  end
  w.search = W.Input(w, 150, "")
  w.search:SetPoint("TOPRIGHT", -14, -HEAD - 8)
  w.search.hint = Core.Text(w.search, "mono", 9)
  w.search.hint:SetPoint("LEFT", 8, 0)
  w.search.hint:SetText("SEARCH")
  w.search.hint:SetTextColor(unpack(C.muted))
  w.search:SetScript("OnTextChanged", function(self)
    self.hint:SetShown(self:GetText() == "")
    Board.offset = 0
    Board.Refresh()
  end)
end

local function BuildCompose(w)
  local well = Core.Fill(w, "BORDER", C.surface[1], C.surface[2], C.surface[3], 0.6)
  well:SetPoint("BOTTOMLEFT", 1, FOOT)
  well:SetPoint("BOTTOMRIGHT", -1, FOOT)
  well:SetHeight(COMPOSE)
  w.compose = Core.Text(w, "bold", 13)
  w.compose:SetPoint("BOTTOMLEFT", 14, FOOT + COMPOSE - 18)
  w.compose:SetText("NEW BOUNTY")
  w.compose:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
  w.name = W.Input(w, 140, "NAME (NAME-REALM ELSEWHERE)")
  w.name:SetPoint("BOTTOMLEFT", 14, FOOT + 10)
  w.target = W.Button(w, "Target", 56, 24, C.panel, function() Board.FillTarget() end)
  w.target:SetPoint("LEFT", w.name, "RIGHT", 4, 0)
  w.gold = W.Input(w, 70, "GOLD (OPTIONAL)")
  w.gold:SetPoint("LEFT", w.target, "RIGHT", 10, 0)
  w.note = W.Input(w, 120, "NOTE")
  w.note:SetPoint("LEFT", w.gold, "RIGHT", 10, 0)
  w.add = W.Button(w, "Add", 52, 24, C.panel, function() Board.AddFromForm(false) end)
  w.add:SetPoint("LEFT", w.note, "RIGHT", 10, 0)
  w.submit = W.Button(w, "Add + submit", 92, 24, C.panel, function() Board.AddFromForm(true) end)
  w.submit:SetPoint("LEFT", w.add, "RIGHT", 4, 0)
  W.Paint(w.submit, W.GOLD, C.panel)
  for _, e in ipairs({ w.name, w.gold, w.note }) do
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Board.AddFromForm(false) end)
  end
end

function Board.Build()
  if Board.win then return Board.win end
  local w = CreateFrame("Frame", "WarboardBountyFrame", UIParent, "BackdropTemplate")
  Board.win = w
  w:SetSize(Board.W, LIST_TOP + Board.CARDS * (Board.CARD_H + 4) + 18 + COMPOSE + FOOT)
  w:SetFrameStrata("DIALOG")
  w:SetBackdrop({ bgFile = Core.WHITE, edgeFile = Core.WHITE, edgeSize = 1 })
  w:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 0.97)
  w:SetBackdropBorderColor(W.GOLD[1] * 0.55, W.GOLD[2] * 0.55, W.GOLD[3] * 0.55, 1)
  w:SetMovable(true)
  w:SetClampedToScreen(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", w.StartMoving)
  w:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    if Core.db then Core.db.bountyPoint = { p, rp, x, y } end
  end)
  local pt = Core.db and Core.db.bountyPoint
  w:SetPoint(pt and pt[1] or "CENTER", UIParent, pt and pt[2] or "CENTER", pt and pt[3] or 0, pt and pt[4] or 60)
  if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "WarboardBountyFrame") end
  BuildHeader(w)
  BuildTabs(w)

  w.rows = {}
  for i = 1, Board.CARDS do
    local r = W.Card(w, Board.CARD_H)
    r:SetPoint("TOPLEFT", 12, -LIST_TOP - (i - 1) * (Board.CARD_H + 4))
    r:SetPoint("RIGHT", w, "RIGHT", -12, 0)
    w.rows[i] = r
  end
  pcall(w.EnableMouseWheel, w, true)
  w:SetScript("OnMouseWheel", function(_, delta)
    Board.offset = math.max(0, Board.offset - delta)
    Board.Refresh()
  end)
  w.empty = Core.Text(w, "semi", 15)
  w.empty:SetPoint("TOP", 0, -LIST_TOP - 70)
  w.empty:SetTextColor(unpack(C.muted))
  w.range = Core.Text(w, "mono", 8)
  w.range:SetPoint("BOTTOMRIGHT", -14, FOOT + COMPOSE + 4)
  w.range:SetTextColor(unpack(C.muted))
  BuildCompose(w)

  w.settings = W.Button(w, "Settings", 72, 20, C.surface, function() Board.OpenSettings() end)
  w.settings:SetPoint("BOTTOMLEFT", 12, 5)
  w.sync = W.Button(w, "Sync guild", 84, 20, C.surface, function()
    Say(Bounty.RequestSync() and "asking your guild for its bounties" or "not in a guild")
  end)
  w.sync:SetPoint("LEFT", w.settings, "RIGHT", 4, 0)
  w.help = Core.Text(w, "mono", 8)
  w.help:SetPoint("BOTTOMRIGHT", -14, 11)
  w.help:SetTextColor(unpack(C.muted))
  w:SetScript("OnShow", function() Board.Refresh() end)
  w:Hide()
  return w
end

local function FillCard(r, b, now)
  r.entry = b
  local state = W.STATE[b.state] or W.STATE.personal
  r.strip:SetColorTexture(state[2], state[3], state[4], 1)
  local short, realm = b.name:match("^([^-]+)-(.+)$")
  r.name:SetText(short or b.name)
  r.realm:SetText(realm and realm ~= Core.myRealm and realm or "")
  local cc = ns.Util.ClassColor(b.class)
  if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) else r.name:SetTextColor(unpack(C.text)) end
  if not (b.class and pcall(r.icon.SetAtlas, r.icon, "classicon-" .. b.class:lower())) then
    r.icon:SetTexture(Bounty.ICON)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  local by = b.state == "personal" and "YOURS" or ("BY " .. Core.DisplayName(b.by or "?"):upper())
  r.sub:SetText(by .. (b.approver and ("  ·  OK " .. Core.DisplayName(b.approver):upper()) or "")
    .. (b.note and ("  ·  " .. b.note) or ""))
  r.gold:SetText(b.gold > 0 and Number(b.gold) or "WANTED")
  r.coin:SetShown(b.gold > 0)
  r.tag:SetText(state[1])
  r.tag:SetTextColor(state[2], state[3], state[4])
  r.chipBg:SetColorTexture(state[2], state[3], state[4], 0.16)
  if b.seenAt then
    local ago = now - b.seenAt
    r.seen:SetText("SEEN " .. W.Ago(ago) .. (b.seenZone and b.seenZone ~= "" and ("  " .. b.seenZone:upper()) or ""))
    r.seen:SetTextColor(unpack(ago < 600 and C.danger or C.muted))
  else
    r.seen:SetText("NOT SEEN YET")
    r.seen:SetTextColor(unpack(C.muted))
  end
  local actions = Actions(b)
  for j, btn in ipairs(r.buttons) do
    local a = actions[#actions - #r.buttons + j] -- right-aligned
    btn.run = a and a[2]
    btn:SetText(a and a[1] or "")
    if a then W.Paint(btn, a[3] or C.panel, a[3] and C.panel or C.text) end
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
    t.count:SetTextColor(unpack(key == "pending" and n > 0 and C.warning or C.muted))
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
  w.guild:SetText(type(gname) == "string" and gname ~= ""
    and (gname:upper() .. "  ·  " .. (Bounty.IsOfficer() and "OFFICER" or "MEMBER"))
    or "NO GUILD  ·  PERSONAL BOUNTIES ONLY")
  w.purse:SetText(Number(purse) .. "g")
  w.help:SetText(Core.On("bounty") and "PERSONAL BOUNTIES ALERT ONLY YOU" or "ALERTS OFF  ·  GENERAL PAGE")
end

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
  local text = Bounty.Amount(b) .. " on " .. Core.DisplayName(b.name)
  if submit then
    local s, serr = Bounty.Submit(b.name)
    text = s and (text .. (s.state == "approved" and ", posted to the guild" or ", submitted for officer approval"))
      or (text .. " kept personal: " .. serr)
  end
  Say(text)
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
