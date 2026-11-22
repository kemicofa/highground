local _, ns = ...
local B, T, Kit = ns.Bounty, ns.Theme, ns.Kit
local V = {}
B.ClaimView = V
local STATES = { claimed = { "AWAITING REVIEW", "pending" }, approved = { "APPROVED · PAYMENT DUE", "gold" },
  paid = { "PAID", "success" }, rejected = { "DECLINED", "textMuted" } }

local Text = Kit.Paragraph

local function Place(f, value, x, y, width)
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", x, -y); f:SetWidth(math.max(1, width)); f:SetText(value)
  return f:GetStringHeight()
end

local function Build(w)
  local p = CreateFrame("Frame", nil, w.detailBody)
  p:SetPoint("TOPLEFT")
  p.hero = B.Widgets.Hero(p); p.hero:SetPoint("TOPLEFT")
  p.strip = p.hero.strip
  p.state, p.name, p.hunter = Text(p.hero, "caption"), Text(p.hero, "displayLarge"), Text(p.hero, "body", "textMuted")
  p.stats = CreateFrame("Frame", nil, p); T.Fill(p.stats, "BACKGROUND", "well"):SetAllPoints()
  p.reward, p.rewardLabel = Text(p.stats, "readout", "gold"), Text(p.stats, "caption", "textMuted")
  p.goal, p.goalLabel = Text(p.stats, "readout"), Text(p.stats, "caption", "textMuted")
  p.fields = {}
  for i = 1, 6 do p.fields[i] = { label = Text(p, "caption", "textMuted"), value = Text(p, "body") } end
  p.rule = T.Fill(p, "ARTWORK", "border"); p.rule:SetHeight(1)
  p.nextLabel, p.next = Text(p, "caption", "gold"), Text(p, "body", "textMuted")
  return p
end

function V.Render(entry, w, width)
  w.claimProfile = w.claimProfile or Build(w)
  local p = w.claimProfile
  p:SetShown(entry ~= nil)
  if not entry then return end
  local c, pad = entry.claim, 16
  local tracking = B.Ledger.Tracking(c)
  local state = tracking and { "KILL RECORDED", "success" } or STATES[c.state] or STATES.claimed
  p:SetWidth(width); p.hero:SetWidth(width)
  T.Paint(p.state, state[2]); T.Paint(p.strip, state[2])
  local inner, y = width - pad * 2, pad
  y = y + Place(p.state, (c.previewManage ~= nil and "SAMPLE · " or "") .. state[1], pad, y, inner) + 9
  y = y + Place(p.name, ns.Core.DisplayName(c.name), pad, y, inner) + 6
  y = y + Place(p.hunter, "Reported by " .. ns.Core.DisplayName(c.claimant), pad, y, inner) + pad
  p.hero:SetHeight(y)
  p.stats:ClearAllPoints(); p.stats:SetPoint("TOPLEFT", 0, -y); p.stats:SetWidth(width)
  local cell = width / 2
  local height = math.max(Place(p.reward, ns.Util.Gold(c.gold), pad, 14, cell - pad * 2),
    Place(p.goal, tostring(B.Terms.Count(c)), cell + pad, 14, cell - pad * 2)) + 20
  height = height + math.max(Place(p.rewardLabel, "THIS KILL'S REWARD", pad, height, cell - pad * 2),
    Place(p.goalLabel, "BOUNTY KILL GOAL", cell + pad, height, cell - pad * 2)) + 14
  p.stats:SetHeight(height); y = y + height + 20
  local values = {
    { "POSTED BY", ns.Core.DisplayName(c.by) },
    { "KILLING BLOW", B.Kills.CauseText(c.cause) },
    { "KILL DETECTION", B.Kills.EvidenceText(c.evidence, B.Kills.Confirmed(c)) },
    { "KILL RECORDED", date("%d %b %Y · %H:%M:%S", c.killedAt or c.claimedAt) },
    { "PREFERRED FINISH", B.Terms.Methods(c) ~= "" and B.Terms.Methods(c) or "Any finish" },
    { c.paidAt and "PAYMENT RECORDED" or "REVIEWED BY", c.paidAt and date("%d %b %Y · %H:%M", c.paidAt)
      or c.reviewedBy and ns.Core.DisplayName(c.reviewedBy) or "Not reviewed yet" },
  }
  local columns = width >= 400 * ns.Core.FontScale() and 2 or 1
  local fieldWidth, rowHeight = (inner - (columns - 1) * 20) / columns, 0
  for i, field in ipairs(p.fields) do
    local column = (i - 1) % columns
    local x = pad + column * (fieldWidth + 20)
    local height = Place(field.label, values[i][1], x, y, fieldWidth) + 5
    height = height + Place(field.value, values[i][2], x, y + height, fieldWidth) + 17
    rowHeight = math.max(rowHeight, height)
    if column == columns - 1 then y, rowHeight = y + rowHeight, 0 end
  end
  p.rule:ClearAllPoints(); p.rule:SetPoint("TOPLEFT", pad, -y); p.rule:SetWidth(inner); y = y + 16
  y = y + Place(p.nextLabel, "NEXT STEP", pad, y, inner) + 7
  local manage = c.previewManage == true or c.previewManage == nil and B.Ledger.CanManage(c)
  local nextStep = tracking and "Saved to your private history. No reward review or payment is needed."
    or c.state == "paid" and "Payment has been recorded. This report is complete."
    or c.state == "rejected" and "The poster declined this report. No payment is due."
    or c.state == "approved" and (manage and "Pay the hunter through the game, then choose Mark paid."
      or "Your report is approved. Arrange payment with the poster; they record it here after paying.")
    or (manage and "Review the evidence and bounty terms, then approve or decline the reward."
      or c.public and not c.received and (B.Public.Now() > c.killedAt + B.Public.CLAIM_WINDOW
        and "Delivery was not confirmed before the reporting window closed. Contact the poster and share your proof."
        or "Your report is saved. Highground retries delivery while the claim window is open. The poster has not acknowledged it yet.")
      or "Your report is saved. Wait for the poster's reward review; there is no need to report this kill again.")
  local offer = c.previewManage == nil and c.public and B.Public.Data().offers[c.pledge]
  if offer and offer.contract then
    nextStep = "Completion is decided by " .. ns.Core.DisplayName(offer.contract.by) .. ". "
      .. (c.state == "approved" and "Their acceptance obliges you to pay this hunter. Pay through the game, then mark paid."
        or c.state == "claimed" and "Your contribution follows their decision; you cannot approve or decline it separately." or nextStep)
  end
  y = y + Place(p.next, nextStep .. (c.previewManage ~= nil and " Preview actions only change sample data." or " Highground does not transfer gold."), pad, y, inner) + pad
  p:SetHeight(y)
  return y
end

function V.Row(row, entry)
  local c = entry.claim
  local state = B.Ledger.Tracking(c) and { "KILL RECORDED", "success" } or STATES[c.state] or STATES.claimed
  T.SetRole(row.label, "rowName")
  row.summary:SetText(ns.Util.Gold(c.gold) .. " · " .. state[1]:lower())
  T.Paint(row.summary, state[2])
end
