local _, ns = ...
local B, P, Kit, T = ns.Bounty, ns.Bounty.Public, ns.Kit, ns.Theme
local D = {}
B.Details = D
local SCOPES = { mine = "My bounties", guild = "Guild & communities", public = "Shared board" }

local function Current()
  if D.preview then return D.preview end
  for _, row in ipairs(B.BoardModel.Rows(D.scope, nil, false, D.organization)) do
    if B.Key(row.name) == B.Key(D.name) then return row end
  end
end

local function Entries(b)
  local out = {}
  local function Entry(source, audience, detail)
    local last = not D.preview and B.Kills.Latest(source.name)
    if last then detail = detail .. "\nLast kill: " .. B.Kills.CauseText(last.cause)
      .. " · " .. date("%Y-%m-%d %H:%M:%S", last.killedAt) end
    out[#out + 1] = {
      source = source,
      bounty = { name = b.name, class = b.class or source.class, gold = source.gold, note = source.note, killsRequired = B.Terms.Count(source), killMethods = source.killMethods },
      audience = audience, owner = "Posted by " .. ns.Core.DisplayName(source.by or "?", true),
      detail = detail .. (B.Terms.Methods(source) ~= "" and ("\nPreferred finish: " .. B.Terms.Methods(source)) or ""),
      progress = D.preview and B.Preview.Progress(source) or B.Terms.Progress(source),
      location = B.Sightings.Location(source),
    }
  end
  local function Offer(p)
    local guild = b.guild and b.guild.publicID == p.id and b.guild
    local audience = guild and (guild.state == "pending" and "Shared · organization approval pending" or (B.Organizations.Label(guild) .. " + Shared · approved"))
      or ({ private = "Private", guild = "Guild", community = B.Organizations.Label(p), global = "Shared" })[B.Pot.Audience(p)]
    Entry(p, audience, P.FUND_LABELS[P.Funds(p)]
      .. "\nExpires " .. date("%d %b · %H:%M", p.expiresAt) .. " · " .. P.Remaining(p.expiresAt) .. " left"
      .. (p.contract and ("\nReward reviewed by " .. ns.Core.DisplayName(p.contract.by)) or ""))
  end
  if b.pot and (#b.pot.contributions > 1 or b.personal and b.pot.contributions[1] ~= b.personal) then
    for _, p in ipairs(b.pot.contributions) do
      if p.id then Offer(p)
      else Entry(p, B.Pot.Audience(p) == "private" and "Private" or B.Organizations.Label(p), "Completion decided by " .. ns.Core.DisplayName(p.by)
        .. ".\nExpires " .. date("%Y-%m-%d %H:%M", B.Pot.Expires(p))) end
    end
  elseif b.shared then for _, p in ipairs(b.shared.contributions) do Offer(p) end
  elseif b.offer then Offer(b.offer)
  else
    local source = b.guild or b.personal
    local detail = "Private target for your own alerts."
    if b.guild then
      detail = (b.guild.state == "pending" and "Awaiting moderator approval" or "Organization approved")
        .. (b.guild.approver and (" by " .. ns.Core.DisplayName(b.guild.approver, true)) or "")
        .. "\n" .. (b.guild.publicID and "Waiting for contribution details. Use Refresh on the board." or "Gold payment is arranged with the poster.")
    end
    Entry(source, b.visibility, detail)
  end
  return out
end

local function Report(b)
  return B.BoardActions.Report(b)
end

local function Actions(b)
  local actions, seen = {}, {}
  local function Add(label, run, help)
    if not seen[label] then actions[#actions + 1] = { label = label, run = run, help = help }; seen[label] = true end
  end
  local primary = B.BoardActions.Primary(b)
  if primary ~= "View bounty" then
    Add(primary, function() return B.BoardActions.Run(nil, b) end, B.BoardActions.Help(b))
  end
  local canReport = false
  for _, p in ipairs(b.pot and b.pot.contributions or b.shared and b.shared.contributions or {}) do
    if p.by ~= B.Me() and (not p.id or not P.Mine(p)) then canReport = true end
  end
  local hasReport = primary == "View report" or primary == "Review report" or primary == "Record payment"
  if canReport and primary ~= "Report kill" and not hasReport then Add("Report kill", function() return Report(b) end, B.Kills.Hint())
  elseif b.offer and P.CanManage(b.offer) then
    Add("Withdraw", function() local p, err = P.Withdraw(b.offer); return p ~= nil, err end, "Stop future hunts on your contribution. Existing claims still need review.")
  elseif b.personal or b.guild then
    Add("Share in chat", function() B.Share.ToChat(b.name); return true, "Chat draft prepared. Choose where to send it." end,
      "Prepare an import link in your chat box. This does not send it or publish a shared contribution.")
  end
  if hasReport then
    Add("Report a missed kill", function() return B.BoardActions.Report(b, true) end, "Only use this for a different kill that was not detected automatically.")
  elseif b.personal and b.personal.by == B.Me() and not b.offer and not b.guild then
    Add("Record kill", function() return Report(b) end, "Record this kill in your private bounty history.")
  else Add("View claims", function() B.Ledger.Open(b.name); return true end, "Review kill reports and record manual payments.") end
  for _, item in ipairs(B.BoardActions.Items(b)) do
    if item.text ~= "Add gold to pot" and not (primary == "Edit" and item.text == "Edit private bounty")
      and not (primary == "Edit reward" and item.text == "Edit my shared contribution") then Add(item.text, item.run) end
  end
  return actions
end

local function Card(w, i)
  if w.cards[i] then return w.cards[i] end
  local r = B.Wanted.Build(w.body)
  r.addGold = Kit.Button(r, "Add gold", 180, 28, { onClick = function()
    if not r.source then return end
    if D.preview then
      if D.previewActions and D.previewActions.addGold then D.previewActions.addGold(r.source) end
    else B.Pot.Open(r.source) end
  end })
  w.cards[i] = r
  return r
end

function D.Layout(w)
  local extra = math.max(0, ns.Core.FontScale() - 1)
  if not w.bountyPage then w:SetSize(math.min(780 + extra * 100, UIParent:GetWidth() - 48), math.min(740, UIParent:GetHeight() - 48)) end
  w.area:ClearAllPoints(); w.area:SetPoint("TOPLEFT", 24, -116 - extra * 18)
  local feedback = w.status:GetText() ~= "" and (40 + extra * 20) or 0
  local hasActions = not D.preview or D.previewActions and D.previewActions.actions
  w.area:SetPoint("BOTTOMRIGHT", -26, (hasActions and 84 or 66) + feedback)
  w.body:SetWidth(w:GetWidth() - 66)
  w.back:SetWidth(142 + extra * 60)
  w.status:SetHeight(feedback); w.status:SetShown(feedback > 0)
  if w:IsShown() and not w.refreshing then D.Refresh() end
end

function D.Build()
  if D.win then return D.win end
  local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyOverview", {
    title = "WANTED POSTER", width = 780, height = 740, header = 64, accent = "gold", alpha = 1, child = true,
    strata = "FULLSCREEN_DIALOG" })
  D.win = w
  w.reward = T.Text(w, "body", "gold"); w.reward:SetPoint("TOPRIGHT", -24, -84)
  w.context = T.Text(w, "body", "textMuted"); w.context:SetPoint("TOPLEFT", 24, -84)
  w.context:SetPoint("RIGHT", w.reward, "LEFT", -20, 0); w.context:SetJustifyH("LEFT")
  w.context:SetJustifyV("TOP")
  w.area = Kit.ScrollArea(w, { wheelStep = 45 })
  w.scroll, w.body = w.area.view, w.area.body
  w.cards = {}
  w.terms = T.Text(w.body, "bodySmall", "textMuted"); w.terms:SetJustifyH("LEFT"); w.terms:SetJustifyV("TOP"); w.terms:SetWordWrap(true)
  w.status = T.Text(w, "body", "textMuted"); w.status:SetPoint("BOTTOMLEFT", 24, 66)
  w.status:SetPoint("RIGHT", -24, 0); w.status:SetJustifyH("LEFT"); w.status:SetJustifyV("BOTTOM")
  w.back = Kit.Button(w, "Back to board", 142, 32, { onClick = function()
    if D.preview then B.Preview.Resume() else w:Hide() end
  end }); w.back:SetPoint("BOTTOMLEFT", 24, 22)
  Kit.Tooltip(w.back, function() return { "Back", D.preview and "Return to the bounty preview. Sample actions only change this preview."
    or "Return to the same board, search and scroll position." } end)
  w.actions = {}
  w.more = Kit.Button(w, "More", 90, 32, { onClick = function(self)
    local items = {}
    for i = 2, #(w.availableActions or {}) do
      local action = w.availableActions[i]
      items[#items + 1] = { text = action.label, run = action.run }
    end
    Kit.Dropdown.Open(self, items, function(item)
      local ok, message = item.run()
      if message then w.status:SetText(message); T.Paint(w.status, ok == false and "warning" or "text") end
      D.Refresh()
    end)
  end })
  w.more:SetPoint("LEFT", w.back, "RIGHT", 12, 0)
  for i = 1, 4 do
    local button = Kit.Button(w, "", 140, 32, { tone = i == 1 and "gold" or nil, onClick = function(self)
      local action = self.action
      if not action then return end
      local ok, message = action.run()
      if message then w.status:SetText(message); T.Paint(w.status, ok == false and "warning" or "text") end
      D.Refresh()
    end })
    Kit.Tooltip(button, function(self) return self.action and { self.action.label, self.action.help } end)
    w.actions[i] = button
  end
  w.LayoutPage = D.Layout
  D.Layout(w)
  ns.Core.OnFontScaleChange(function() D.Layout(w) end)
  return w
end

function D.Refresh()
  local w = D.win
  if not (w and w:IsShown()) or w.refreshing then return end
  w.refreshing = true
  local b = Current()
  local items, y = b and Entries(b) or {}, 0
  w.reward:SetText(#items > 1 and ("Total pledged: " .. ns.Util.Gold(b.gold)) or "")
  w.reward:SetShown(#items > 1)
  w.context:ClearAllPoints(); w.context:SetPoint("TOPLEFT", 24, -84)
  if #items > 1 then w.context:SetPoint("RIGHT", w.reward, "LEFT", -20, 0)
  else w.context:SetPoint("RIGHT", -24, 0) end
  w.context:SetText((D.preview and "PREVIEW · " or "") .. (SCOPES[D.scope] or "Bounty")
    .. (not b and " · No active bounty" or #items > 1 and (" · " .. #items .. " rewards") or ""))
  D.Layout(w)
  local scale, available, gap = math.max(1, ns.Core.FontScale()), w.body:GetWidth(), 18
  local columns = math.max(1, math.min(#items, 2, math.floor((available + gap) / (430 * scale + gap))))
  local width = (available - (columns - 1) * gap) / columns
  local start = (available - columns * width - (columns - 1) * gap) / 2
  local rowHeight = 0
  for i, entry in ipairs(items) do
    local r = Card(w, i)
    r.source = entry.source
    r.addGold:SetShown(entry.source ~= nil and entry.source.state ~= "pending"
      and (D.preview and D.previewActions and D.previewActions.addGold ~= nil or not D.preview and B.Pot.Live(entry.source)))
    local column = (i - 1) % columns
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", start + column * (width + gap), -y)
    B.Wanted.Fill(r, entry.bounty, { width = width, compact = true, status = entry.audience:upper(),
      owner = entry.owner, location = entry.location, detail = entry.detail, progress = entry.progress,
      preview = D.preview ~= nil, portraitLabel = D.preview and b.previewPortraitLabel, tracking = B.Matches.Label(b) })
    r:Show(); rowHeight = math.max(rowHeight, r:GetHeight())
    if column == columns - 1 or i == #items then
      for index = i - column, i do w.cards[index]:SetHeight(rowHeight) end
      y, rowHeight = y + rowHeight + gap, 0
    end
  end
  for i = #items + 1, #w.cards do w.cards[i]:Hide() end
  local terms = not b and "This bounty is no longer active. Earlier kill reports and payment records remain in Claims."
    or b.personal and not b.offer and not b.guild and "Only you see this target. Use Share in chat to prepare an import link, or More on the board to publish it."
    or B.Kills.Hint() .. " Reward approval and payment follow in Claims & payments."
  w.terms:ClearAllPoints(); w.terms:SetPoint("TOPLEFT", 0, -y); w.terms:SetWidth(w.body:GetWidth()); w.terms:SetText(terms)
  w.terms:SetHeight(0)
  local height = math.ceil(w.terms:GetStringHeight()) + 2; w.terms:SetHeight(height); w.body:SetHeight(y + height + 12)
  local actions
  if D.preview then actions = D.previewActions and D.previewActions.actions and D.previewActions.actions(b) or {}
  else actions = b and Actions(b) or { { label = "Claims", run = function() B.Ledger.Open() end, help = "Review earlier reports and payments." } } end
  w.availableActions = actions
  w.more:SetShown(#actions > 1)
  w.more:SetSize(w.more.label:GetStringWidth() + 30, 32 * scale)
  w.back:SetHeight(32 * scale)
  for i = 1, #w.actions do
    local button, action = w.actions[i], actions[i]
    button.action = action; button:SetShown(action ~= nil and i == 1)
    if action then
      button:SetText(action.label); button:SetWidth(math.max(100, button.label:GetStringWidth() + 28))
      button:ClearAllPoints(); button:SetPoint("BOTTOMRIGHT", -24, 22); button:SetHeight(32 * scale)
    end
  end
  w.area:Refresh()
  w.refreshing = nil
end

function D.Open(row, preview, actions)
  if preview then B.Poster.StopPreview() end
  local w = D.Build()
  D.preview = preview and row or nil
  D.previewActions = preview and actions or nil
  D.name, D.scope = row.name, row.scope
  D.organization = row.organization or row.guild and (row.guild.organization or "guild") or row.offer and row.offer.organization
  w.status:SetText(""); w.area:Scroll(0)
  w.back:SetText(preview and "Back to preview" or "Back to board")
  B.Widgets.ShowWindow(w)
  D.Refresh()
  return w
end

B.Listen("updated", D.Refresh)
B.Listen("changed", D.Refresh)
