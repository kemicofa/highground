local _, ns = ...
local B, T, Kit = ns.Bounty, ns.Theme, ns.Kit
local V = {}
B.ClaimView = V
local STATES = { claimed = { "AWAITING REVIEW", "pending" }, approved = { "APPROVED · PAYMENT DUE", "gold" },
  paid = { "PAID", "success" }, rejected = { "DECLINED", "textMuted" } }

local Text = Kit.Paragraph
local LABELS = { "THIS KILL'S REWARD", "BOUNTY KILL GOAL", "POSTED BY", "KILLING BLOW", "KILL DETECTION",
  "KILL RECORDED", "PREFERRED FINISH", "REVIEWED BY" }

-- A Kit hero with the state badge, then labelled facts and the next step.
local function Build(w)
  local p = CreateFrame("Frame", nil, w.detailBody)
  p:SetPoint("TOPLEFT")
  p.hero = Kit.Hero(p, "gold"); p.hero:SetPoint("TOPLEFT")
  p.strip = p.hero.strip
  p.state = Kit.Badge(p.hero, "", "pending")
  p.name, p.hunter = Text(p.hero, "displayLarge"), Text(p.hero, "body", "textMuted")
  -- facts: reward and goal, then the six report fields (p.fields).
  p.facts, p.fields = {}, {}
  for i, label in ipairs(LABELS) do
    p.facts[i] = Kit.KeyValue(p, { label = label, role = i <= 2 and "readout" or "body", tone = i == 1 and "gold" or nil })
    if i > 2 then p.fields[i - 2] = p.facts[i] end
  end
  p.reward, p.goal = p.facts[1].value, p.facts[2].value
  p.rule = T.Fill(p, "ARTWORK", "border"); p.rule:SetHeight(1)
  p.nextLabel, p.next = Text(p, "caption", "gold"), Text(p, "body", "textMuted")
  p.nextLabel:SetText("NEXT STEP")
  return p
end

-- Wrapped paragraph at (x, y) and inner width; returns its height.
local function Paragraph(text, owner, x, y, width)
  Kit.Place(text, "TOPLEFT", owner, "TOPLEFT", x, -y)
  text:SetWidth(math.max(1, width))
  return math.ceil(text:GetStringHeight())
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
  p.hero:SetTone(state[2])
  local inner, y = width - pad * 2, pad
  p.state:Set((c.previewManage ~= nil and "SAMPLE · " or "") .. state[1], state[2])
  Kit.Place(p.state, "TOPLEFT", p.hero, "TOPLEFT", pad, -y); y = y + p.state:GetHeight() + 9
  p.name:SetText(ns.Core.DisplayName(c.name)); y = y + Paragraph(p.name, p.hero, pad, y, inner) + 6
  p.hunter:SetText("Reported by " .. ns.Core.DisplayName(c.claimant)); y = y + Paragraph(p.hunter, p.hero, pad, y, inner) + pad
  p.hero:SetHeight(y); y = y + 16
  local values = {
    ns.Util.Gold(c.gold), tostring(B.Terms.Count(c)), ns.Core.DisplayName(c.by), B.Kills.CauseText(c.cause),
    B.Kills.EvidenceText(c.evidence, B.Kills.Confirmed(c)), date("%d %b %Y · %H:%M:%S", c.killedAt or c.claimedAt),
    B.Terms.Methods(c) ~= "" and B.Terms.Methods(c) or "Any finish",
    c.paidAt and date("%d %b %Y · %H:%M", c.paidAt) or c.reviewedBy and ns.Core.DisplayName(c.reviewedBy) or "Not reviewed yet",
  }
  p.facts[8]:SetLabel(c.paidAt and "PAYMENT RECORDED" or "REVIEWED BY")
  for i, field in ipairs(p.facts) do
    field:Set(values[i])
    Kit.Place(field, "TOPLEFT", p, "TOPLEFT", pad, -y)
    y = y + field:Layout(inner) + (i == 2 and 18 or 10)
  end
  Kit.Place(p.rule, "TOPLEFT", p, "TOPLEFT", pad, -(y + 6)); p.rule:SetWidth(inner); y = y + 22
  y = y + Paragraph(p.nextLabel, p, pad, y, inner) + 7
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
  p.next:SetText(nextStep .. (c.previewManage ~= nil and " Preview actions only change sample data." or " Highground does not transfer gold."))
  y = y + Paragraph(p.next, p, pad, y, inner) + pad
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
