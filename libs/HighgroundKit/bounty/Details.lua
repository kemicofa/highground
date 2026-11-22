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
  local actions, manage = {}, {}
  local function Add(label, run, help, secondary)
    local list = secondary and manage or actions
    list[#list + 1] = { label = label, run = run, help = help, secondary = secondary }
  end
  local report = B.Ledger.ForBounty(b)
  local own = B.Pot.Own(b.name)
  local source = own or b.offer or b.guild or b.personal
    or b.shared and b.shared.contributions[1]
  local canReport = false
  for _, reward in ipairs(b.pot and b.pot.contributions or {}) do
    if reward.by ~= B.Me() and (not reward.id or not P.Mine(reward)) and reward.state ~= "pending" then canReport = true end
  end
  if report then
    Add(B.BoardActions.Primary(b), function() return B.BoardActions.Run(nil, b) end, B.BoardActions.Help(b))
  elseif b.guild and b.guild.state == "pending" and B.IsOfficer(nil, b.guild) then
    Add("Approve bounty", function() return B.BoardActions.Run(nil, b) end, "Approve this submission for your organization.")
  elseif canReport then
    Add("Claim reward", function() return Report(b) end, "Report a kill if automatic detection missed it. The poster reviews your claim before paying.")
  end
  if source then
    Add("Share bounty", function() B.Exchange.Show(source, B.Pot.Audience(source)); return true end,
      "Copy a bounty link to send to other players, or share it in game.")
  end
  if own and (not own.id or P.CanManage(own)) then
    Add("Edit reward", function()
      if own.contract or own.state ~= "personal" and not own.id then B.Pot.Open(own)
      else B.Form.Open(b.name, own.id and "public" or "personal", own) end
      return true
    end, "Change your reward. Published completion terms stay fixed.")
  end
  if not own then
    local tracking = B.Matches.Tracking(b)
    Add(tracking and "Stop tracking" or "Start tracking", function()
      B.Matches.Set(b.name, tracking and "ignored" or "tracking"); return true
    end, "Sighting alerts cost no gold. Detected kills are reported automatically.")
  end
  if not report and not canReport then
    Add("Claims & payments", function() B.Ledger.Open(b.name); return true end, "Review hunters' claims and record payments after paying them in game.")
  end
  if report and canReport then
    Add("Report a missed kill", function() return B.BoardActions.Report(b, true) end, "Only for a different kill that was not detected.", true)
  end
  if own then
    local tracking = B.Matches.Tracking(b)
    Add(tracking and "Stop tracking" or "Start tracking", function()
      B.Matches.Set(b.name, tracking and "ignored" or "tracking"); return true
    end, "Turn sighting alerts on or off without removing the reward.", true)
    if not own.contract and (not own.id or P.CanManage(own)) then
      Add("Change audience", function() B.Form.Open(b.name, "public", own); return true end,
        "Review publication on the shared board or submission to a guild or community.", true)
    end
  end
  if b.offer and P.CanManage(b.offer) then
    Add("Withdraw reward", function() local p, err = P.Withdraw(b.offer); return p ~= nil, err end,
      "Stop future hunts. Existing claims and payments are kept.", true)
  elseif b.guild and (b.guild.by == B.Me() or B.IsOfficer(nil, b.guild)) then
    Add(b.guild.state == "pending" and "Reject / withdraw" or "Remove bounty", function()
      local removed, err = B.Remove(b.name, "guild", b.guild.organization); B.Emit("updated"); return removed ~= nil, err
    end, "Remove this organization listing. Existing claims are kept.", true)
  elseif b.personal then
    Add("Remove bounty", function() local removed, err = B.Remove(b.name, "personal"); B.Emit("updated"); return removed ~= nil, err end,
      "Remove this private target. Existing claims are kept.", true)
  end
  for _, action in ipairs(manage) do actions[#actions + 1] = action end
  return actions
end

local function Card(w, i)
  if w.cards[i] then return w.cards[i] end
  local r = B.Wanted.Build(w.body)
  r.fullPoster = true
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
  if w:IsShown() and not w.refreshing then return D.Refresh() end
  local extra = math.max(0, ns.Core.FontScale() - 1)
  local scale = 1 + extra
  if not w.bountyPage then w:SetSize(math.min(540 + extra * 180, UIParent:GetWidth() - 48), math.min(740, UIParent:GetHeight() - 48)) end
  local available = w:GetWidth() - 48
  w.back:SetSize(w.back.label:GetStringWidth() + 28, 32 * scale)
  local footer = 22 + w.back:GetHeight() + 14
  local managementHeight = Kit.LayoutGrid(w.manageActions or {}, { width = available,
    height = 30 * scale, padding = 28 * scale, gap = 10, anchor = "BOTTOMLEFT" })
  Kit.Place(w.management, "BOTTOMLEFT", w, "BOTTOMLEFT", 24, footer, available, math.max(1, managementHeight))
  w.manageLabel:SetShown(managementHeight > 0)
  if managementHeight > 0 then
    footer = footer + managementHeight + 8
    Kit.Place(w.manageLabel, "BOTTOMLEFT", w, "BOTTOMLEFT", 24, footer, available, 0)
    w.manageLabel:SetHeight(math.ceil(w.manageLabel:GetStringHeight()) + 2)
    footer = footer + w.manageLabel:GetHeight() + 14
  end
  local feedback = w.status:GetText() ~= "" and (40 + extra * 20) or 0
  Kit.Place(w.status, "BOTTOMLEFT", w, "BOTTOMLEFT", 24, footer, available, feedback)
  w.status:SetShown(feedback > 0)
  footer = footer + feedback
  local top = 116 + extra * 18
  local actionHeight = Kit.LayoutGrid(w.mainActions or {}, { width = available,
    height = 32 * scale, padding = 30 * scale, gap = 10 })
  Kit.Place(w.actionArea, "TOPLEFT", w, "TOPLEFT", 24, -top, available, math.max(1, actionHeight))
  top = top + (actionHeight > 0 and actionHeight + 16 or 0)
  Kit.Place(w.area, "TOPLEFT", w, "TOPLEFT", 24, -top, w:GetWidth() - 50, math.max(1, w:GetHeight() - top - footer))
  w.body:SetWidth(w:GetWidth() - 66)
end

function D.Build()
  if D.win then return D.win end
  local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyOverview", {
    title = "BOUNTY DETAILS", width = 540, height = 740, header = 64, accent = "gold", alpha = 1, child = true,
    strata = "FULLSCREEN_DIALOG" })
  D.win = w
  w.reward = T.Text(w, "body", "gold"); w.reward:SetPoint("TOPRIGHT", -24, -84)
  w.context = T.Text(w, "body", "textMuted"); w.context:SetPoint("TOPLEFT", 24, -84)
  w.context:SetPoint("RIGHT", w.reward, "LEFT", -20, 0); w.context:SetJustifyH("LEFT")
  w.context:SetJustifyV("TOP")
  w.area = Kit.ScrollArea(w, { wheelStep = 45 })
  w.scroll, w.body = w.area.view, w.area.body
  w.target = B.Wanted.Build(w.body)
  w.target.fullPoster = true
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
  w.actionArea = CreateFrame("Frame", nil, w)
  w.management = CreateFrame("Frame", nil, w)
  w.manageLabel = Kit.Paragraph(w, "heading", "textMuted")
  w.manageLabel:SetText("Manage bounty")
  w.nextStep = Kit.Paragraph(w.body, "body", "text")
  for i = 1, 10 do
    local button = Kit.Button(w.actionArea, "", 140, 32, { tone = i == 1 and "gold" or nil, onClick = function(self)
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
  local offset = w.area.offset
  local b = Current()
  local items, y = b and Entries(b) or {}, 0
  w.reward:SetText(#items > 1 and ("Total pledged: " .. ns.Util.Gold(b.gold)) or "")
  w.reward:SetShown(#items > 1)
  w.context:ClearAllPoints(); w.context:SetPoint("TOPLEFT", 24, -84)
  if #items > 1 then w.context:SetPoint("RIGHT", w.reward, "LEFT", -20, 0)
  else w.context:SetPoint("RIGHT", -24, 0) end
  w.context:SetText((D.preview and "PREVIEW · " or "") .. (SCOPES[D.scope] or "Bounty")
    .. (not b and " · No active bounty" or #items > 1 and (" · " .. #items .. " rewards") or ""))
  local actions
  if D.preview then actions = D.previewActions and D.previewActions.actions and D.previewActions.actions(b) or {}
  else actions = b and Actions(b) or { { label = "Claims & payments", run = function() B.Ledger.Open() end } } end
  w.availableActions = actions
  local main, management = {}, {}
  for i, button in ipairs(w.actions) do
    local action = actions[i]
    button.action = action; button:SetShown(action ~= nil)
    if action then
      button:SetText(action.label)
      button:SetParent(action.secondary and w.management or w.actionArea)
      local list = action.secondary and management or main
      list[#list + 1] = button
    end
  end
  w.mainActions, w.manageActions = main, management
  D.Layout(w)
  local available, gap = w.body:GetWidth(), 12
  local width = available
  local owner = b and (D.preview and B.Preview.state.coachRole == "post" or not D.preview and B.Pot.Own(b.name))
  local report = b and not D.preview and B.Ledger.ForBounty(b) or nil
  w.nextStep:SetText(not b and "This bounty is closed. Your reports and payments are still available."
    or report and (report.claimant == B.Me() and "Your claim is saved. View report shows its review and payment status."
      or report.state == "approved" and "Claim approved. Pay the hunter in game, then record the payment."
      or report.state == "paid" and "Payment recorded. The report keeps the evidence and payment history."
      or "A hunter reported a kill. Review report to check the evidence and decide the reward.")
    or owner and "Your reward. Share it with hunters, then review their claims in Claims & payments."
    or "Defeat this target. Detected kills create a claim automatically. Use Claim reward if detection missed your kill.")
  w.nextStep:ClearAllPoints(); w.nextStep:SetPoint("TOPLEFT"); w.nextStep:SetWidth(available)
  w.nextStep:SetHeight(0); w.nextStep:SetHeight(w.nextStep:GetStringHeight() + 2)
  w.nextStep:SetShown(#actions > 0 and (report ~= nil or not b))
  y = w.nextStep:IsShown() and w.nextStep:GetHeight() + 14 or 0
  w.target:SetShown(#items > 1)
  if #items > 1 then
    w.target:ClearAllPoints(); w.target:SetPoint("TOPLEFT", 0, -y)
    B.Wanted.Fill(w.target, { name = b.name, class = b.class, gold = b.gold }, {
      width = width, compact = true, status = "TARGET", tracking = B.Matches.Label(b), progress = "", detail = "",
      preview = D.preview ~= nil, portraitLabel = D.preview and b.previewPortraitLabel })
    y = y + w.target:GetHeight() + gap
  end
  for i, entry in ipairs(items) do
    local r = Card(w, i)
    r.source, r.contribution = entry.source, #items > 1
    r.minPosterHeight = #items == 1 and math.min(440, w.scroll:GetHeight() - y - gap) or 0
    r.addGold:SetShown(entry.source ~= nil and entry.source.state ~= "pending"
      and (D.preview and D.previewActions and D.previewActions.addGold ~= nil and entry.source.by ~= B.Me()
        or not D.preview and not B.Pot.Own(b.name) and entry.source.by ~= B.Me()
          and (not entry.source.id or not P.Mine(entry.source)) and B.Pot.Live(entry.source)))
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y)
    B.Wanted.Fill(r, entry.bounty, { width = width, compact = true, status = entry.audience:upper(),
      owner = entry.owner, location = entry.location, detail = entry.detail, progress = entry.progress,
      preview = D.preview ~= nil, portraitLabel = D.preview and b.previewPortraitLabel, tracking = "" })
    r:Show(); y = y + r:GetHeight() + gap
  end
  for i = #items + 1, #w.cards do w.cards[i]:Hide() end
  local terms = not b and "This bounty is no longer active. Earlier kill reports and payment records remain in Claims."
    or b.personal and not b.offer and not b.guild and "Only you see this target. Share bounty prepares a link; Change audience lets you publish it."
    or B.Kills.Hint() .. " Reward approval and payment follow in Claims & payments."
  w.terms:ClearAllPoints(); w.terms:SetPoint("TOPLEFT", 0, -y); w.terms:SetWidth(w.body:GetWidth()); w.terms:SetText(terms)
  w.terms:SetHeight(0)
  local height = not b and math.ceil(w.terms:GetStringHeight()) + 2 or 0
  w.terms:SetHeight(math.max(1, height)); w.terms:SetShown(height > 0)
  -- Commit the full content height once. Native resize callbacks may refresh
  -- the scroll range while laying out; they must not discard the reader's offset.
  w.body:SetHeight(y + height + 12)
  w.area:Refresh()
  w.area:Scroll(offset)
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
  w.back:SetText(preview and not B.Preview.testing and "Back to preview" or "Back to board")
  B.Widgets.ShowWindow(w)
  D.Refresh()
  return w
end

B.Listen("updated", D.Refresh)
B.Listen("changed", D.Refresh)
