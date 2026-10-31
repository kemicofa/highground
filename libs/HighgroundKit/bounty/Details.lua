local _, ns = ...
local B, P, Kit, T = ns.Bounty, ns.Bounty.Public, ns.Kit, ns.Theme
local D = {}
B.Details = D
local SCOPES = { mine = "My bounties", guild = "Guild board", public = "Shared board" }

local function Current()
  if D.preview then return D.preview end
  for _, row in ipairs(B.BoardModel.Rows(D.scope)) do
    if B.Key(row.name) == B.Key(D.name) then return row end
  end
end

local function Entries(b)
  local out = {}
  local function Offer(p)
    local guild = b.guild and b.guild.publicID == p.id and b.guild
    local audience = guild and (guild.state == "pending" and "Shared · guild approval pending" or "Guild + Shared · guild approved") or "Shared"
    out[#out + 1] = { title = (P.Mine(p) and "Your contribution · " or "Posted by ") .. p.by, gold = p.gold,
      detail = "Audience: " .. audience .. "\n" .. P.FUND_LABELS[P.Funds(p)]
        .. " · checked " .. (p.checkedAt > 0 and B.Widgets.Ago(P.Now() - p.checkedAt):lower() or "never")
        .. "\nExpires: " .. date("%Y-%m-%d %H:%M", p.expiresAt) .. " (" .. P.Remaining(p.expiresAt) .. " left)"
        .. "\nNote: " .. (p.note ~= "" and p.note or "None"),
      tint = P.Funds(p) == "available" and "gold" or "textMuted" }
  end
  if b.shared then for _, p in ipairs(b.shared.contributions) do Offer(p) end
  elseif b.offer then Offer(b.offer)
  else
    local source = b.guild or b.personal
    local detail = "Audience: " .. b.visibility
    if b.guild then
      detail = detail .. "\nGuild status: " .. (b.guild.state == "pending" and "Awaiting officer approval" or "Approved")
        .. (b.guild.approver and (" by " .. b.guild.approver) or "")
        .. "\n" .. (b.guild.publicID and "Waiting for contribution details. Use Sync on the board." or "Gold payment is arranged with the poster.")
    else detail = detail .. "\nPrivate target for your own alerts." end
    detail = detail .. "\nNote: " .. (source.note and source.note ~= "" and source.note or "None")
    if source.seenAt then detail = detail .. "\nLast seen: " .. B.Widgets.Ago(time() - source.seenAt):lower() .. " · " .. (source.seenZone or "Unknown location") end
    out[1] = { title = "Posted by " .. (source.by or "?"), gold = source.gold, detail = detail, tint = "gold" }
  end
  return out
end

local function Report(b)
  if b.shared then return P.Claim(b.name) end
  if b.guild then local claimed, err = B.Claim(b.name, true); return claimed ~= nil, err or "Kill reported for review." end
  if b.personal then B.Ledger.Record(b.personal, B.Me()); B.Emit("updated"); return true, "Kill recorded in your private history." end
end

local function Actions(b)
  local actions = {}
  local function Add(label, run, help) actions[#actions + 1] = { label = label, run = run, help = help } end
  local primary = B.BoardActions.Primary(b)
  if primary ~= "View bounty" then
    Add(primary, function() return B.BoardActions.Run(nil, b) end, B.BoardActions.Help(b))
  end
  local canReport = false
  for _, p in ipairs(b.shared and b.shared.contributions or {}) do if not P.Mine(p) then canReport = true end end
  if canReport then Add("Report kill", function() return Report(b) end, "Send a report for every eligible contribution shown here. Each poster reviews their own reward.")
  elseif b.offer and P.CanManage(b.offer) then
    Add("Withdraw", function() local p, err = P.Withdraw(b.offer); return p ~= nil, err end, "Stop future hunts on your contribution. Existing claims still need review.")
  elseif b.personal or b.guild then
    Add("Share in chat", function() B.Share.ToChat(b.name); return true, "Chat draft prepared. Choose where to send it." end,
      "Prepare an import link in your chat box. This does not send it or publish a shared contribution.")
  end
  if b.shared and not b.offer then
    Add("Add a reward", function() B.Form.Open(b.name, "public") end, "Offer your own gold to hunters of this player. Review the amount before publishing.")
  end
  if b.personal and not b.offer and not b.guild then
    Add("Record kill", function() return Report(b) end, "Record this kill in your private bounty history.")
  else Add("View claims", function() B.Ledger.Open(); return true end, "Review kill reports and record manual payments.") end
  return actions
end

local function Card(w, i)
  if w.cards[i] then return w.cards[i] end
  local r = CreateFrame("Frame", nil, w.body)
  local fill = T.Fill(r, "BACKGROUND", "surface"); fill:SetAllPoints(); Kit.Outline(r, "border")
  r.title = T.Text(r, "heading", "text"); r.title:SetPoint("TOPLEFT", 14, -12)
  r.title:SetJustifyH("LEFT"); r.title:SetWordWrap(false)
  r.gold = T.Text(r, "number", "gold"); r.gold:SetPoint("TOPRIGHT", -14, -10)
  r.title:SetPoint("RIGHT", r.gold, "LEFT", -18, 0)
  r.detail = T.Text(r, "body", "text"); r.detail:SetJustifyH("LEFT"); r.detail:SetJustifyV("TOP")
  r.detail:SetWordWrap(true)
  w.cards[i] = r
  return r
end

function D.Layout(w)
  local extra = math.max(0, ns.Core.FontScale() - 1)
  if not w.bountyPage then w:SetSize(740 + extra * 80, 620 + extra * 100) end
  w.scroll:ClearAllPoints(); w.scroll:SetPoint("TOPLEFT", 24, -214 - extra * 30)
  w.scroll:SetPoint("BOTTOMRIGHT", -42, 174)
  w.body:SetWidth(w:GetWidth() - 66)
  w.back:SetWidth(142 + extra * 60)
end

function D.Build()
  if D.win then return D.win end
  local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyOverview", {
    title = "BOUNTY DETAILS", width = 740, height = 620, header = 64, accent = "gold", alpha = 1,
    strata = "FULLSCREEN_DIALOG" })
  D.win = w
  w.intent = T.Text(w, "body", "textMuted"); w.intent:SetPoint("TOPLEFT", 24, -82)
  w.intent:SetPoint("RIGHT", -24, 0); w.intent:SetJustifyH("LEFT")
  w.intent:SetText("Review the reward, who pays, and when it expires.")
  w.target = T.Text(w, "cardTitle", "text"); w.target:SetPoint("TOPLEFT", 24, -122)
  w.target:SetJustifyH("LEFT"); w.target:SetWordWrap(false)
  w.reward = T.Text(w, "number", "gold"); w.reward:SetPoint("TOPRIGHT", -24, -120)
  w.target:SetPoint("RIGHT", w.reward, "LEFT", -20, 0)
  w.context = T.Text(w, "body", "textMuted"); w.context:SetPoint("TOPLEFT", 24, -164)
  w.context:SetPoint("RIGHT", -24, 0); w.context:SetJustifyH("LEFT"); w.context:SetHeight(48)
  w.context:SetJustifyV("TOP")
  w.scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
  w.body = CreateFrame("Frame", nil, w.scroll); w.body:SetSize(674, 300); w.scroll:SetScrollChild(w.body)
  w.scroll:EnableMouseWheel(true)
  w.scroll:SetScript("OnMouseWheel", function(self, delta)
    local limit = math.max(0, w.body:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(limit, self:GetVerticalScroll() - delta * 45)))
  end)
  w.cards = {}
  w.terms = T.Text(w.body, "bodySmall", "textMuted"); w.terms:SetJustifyH("LEFT"); w.terms:SetJustifyV("TOP"); w.terms:SetWordWrap(true)
  w.status = T.Text(w, "body", "textMuted"); w.status:SetPoint("BOTTOMLEFT", 24, 108)
  w.status:SetPoint("RIGHT", -24, 0); w.status:SetHeight(50); w.status:SetJustifyH("LEFT"); w.status:SetJustifyV("BOTTOM")
  w.back = Kit.Button(w, "Back to board", 142, 32, { onClick = function()
    if D.preview then B.Preview.Resume() else w:Hide() end
  end }); w.back:SetPoint("BOTTOMLEFT", 24, 22)
  Kit.Tooltip(w.back, function() return { "Back", D.preview and "Return to the bounty preview. Sample rewards cannot be edited or claimed."
    or "Return to the same board, search and scroll position." } end)
  w.actions = {}
  for i = 1, 4 do
    local button = Kit.Button(w, "", 140, 32, { onClick = function(self)
      local action = self.action
      if not action then return end
      local ok, message = action.run()
      D.Refresh()
      if message then w.status:SetText(message); T.Paint(w.status, ok == false and "warning" or "text") end
    end })
    Kit.Tooltip(button, function(self) return self.action and { self.action.label, self.action.help } end)
    w.actions[i] = button
  end
  w.LayoutPage = D.Layout
  D.Layout(w)
  ns.Core.OnFontScaleChange(function() D.Layout(w); D.Refresh() end)
  return w
end

function D.Refresh()
  local w = D.win
  if not (w and w:IsShown()) then return end
  local b = Current()
  w.target:SetText(D.name)
  w.reward:SetText(b and ns.Util.Gold(b.gold) or "Closed")
  w.context:SetText((D.preview and "PREVIEW · " or "") .. (SCOPES[D.scope] or "Bounty") .. " · " .. (b and b.visibility or "No active bounty")
    .. (b and b.shared and ("\n" .. ns.Util.Gold(b.shared.gold) .. " with funds reported available") or ""))
  local items, y = b and Entries(b) or {}, 0
  local extra = math.max(0, ns.Core.FontScale() - 1)
  for i, entry in ipairs(items) do
    local r = Card(w, i)
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetWidth(w.body:GetWidth())
    r.title:SetText(entry.title); r.gold:SetText(ns.Util.Gold(entry.gold)); T.Paint(r.gold, entry.tint)
    r.detail:ClearAllPoints(); r.detail:SetPoint("TOPLEFT", 14, -42 - extra * 16)
    r.detail:SetWidth(w.body:GetWidth() - 28); r.detail:SetText(entry.detail)
    local textHeight = r.detail:GetStringHeight(); r.detail:SetHeight(textHeight)
    r:SetHeight(56 + extra * 16 + textHeight); r:Show(); y = y + r:GetHeight() + 12
  end
  for i = #items + 1, #w.cards do w.cards[i]:Hide() end
  local terms = not b and "This bounty is no longer active. Earlier kill reports and payment records remain in Claims."
    or b.personal and not b.offer and not b.guild and "Only you see this target. Use Share in chat to prepare an import link, or More on the board to publish it."
    or "After a killing blow, choose Report kill within 15 minutes. Each poster reviews their own reward in Claims & payments and pays through the game. Funding reports do not guarantee payment."
  w.terms:ClearAllPoints(); w.terms:SetPoint("TOPLEFT", 0, -y); w.terms:SetWidth(w.body:GetWidth()); w.terms:SetText(terms)
  local height = w.terms:GetStringHeight(); w.terms:SetHeight(height); w.body:SetHeight(y + height + 12)
  local actions = D.preview and {} or b and Actions(b) or { { label = "Claims", run = function() B.Ledger.Open() end, help = "Review earlier reports and payments." } }
  local previous
  for i = #w.actions, 1, -1 do
    local button, action = w.actions[i], actions[i]
    button.action = action; button:SetShown(action ~= nil)
    if action then
      button:SetText(action.label); button:SetWidth(math.max(100, button.label:GetStringWidth() + 28))
      button:ClearAllPoints()
      if previous then button:SetPoint("RIGHT", previous, "LEFT", -10, 0) else button:SetPoint("BOTTOMRIGHT", -24, 66) end
      previous = button
    end
  end
end

function D.Open(row, preview)
  local w = D.Build()
  D.preview = preview and row or nil
  D.name, D.scope = row.name, row.scope
  w.intent:SetText(preview and "Sample bounty only. Review the reward, who pays, and when it expires."
    or "Review the reward, who pays, and when it expires.")
  w.status:SetText(""); w.scroll:SetVerticalScroll(0)
  w.back:SetText(preview and "Back to preview" or "Back to board")
  if preview then B.Widgets.ShowWindow(w) else B.Widgets.ShowPage(w) end
  D.Refresh()
  return w
end

B.Listen("updated", D.Refresh)
B.Listen("changed", D.Refresh)
