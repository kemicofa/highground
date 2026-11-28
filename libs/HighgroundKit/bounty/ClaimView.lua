local _, ns = ...
local B, T, Kit = ns.Bounty, ns.Theme, ns.Kit
local V = {}
B.ClaimView = V
local STATES = { claimed = ns.Localization.Define({ ns.Locale:Get("shared.claimview.awaiting_review.5d3376"), "pending" }, { [1] = "shared.claimview.awaiting_review.5d3376" }), approved = ns.Localization.Define({ ns.Locale:Get("shared.claimview.approved_payment_due.9709f7"), "gold" }, { [1] = "shared.claimview.approved_payment_due.9709f7" }),
  paid = ns.Localization.Define({ ns.Locale:Get("shared.claimview.paid.f3534d"), "success" }, { [1] = "shared.claimview.paid.f3534d" }), rejected = ns.Localization.Define({ ns.Locale:Get("shared.claimview.declined.e2bd52"), "textMuted" }, { [1] = "shared.claimview.declined.e2bd52" }) }

local Text = Kit.Paragraph
-- Fact labels are bound to their messages, so they follow language changes.
local LABELS = { "shared.claimview.this_kill_s_reward.d36351", "shared.claimview.bounty_kill_goal.612407",
  "shared.claimview.posted_by.bf4654", "shared.claimview.killing_blow.e0295f", "shared.claimview.kill_detection.9567f3",
  "shared.claimview.kill_recorded.89fa61", "shared.claimview.preferred_finish.4c9904", "shared.claimview.reviewed_by.056b5c" }

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
    p.facts[i] = Kit.KeyValue(p, { role = i <= 2 and "readout" or "body", tone = i == 1 and "gold" or nil })
    ns.Localization.Bind(p.facts[i].label, label)
    if i > 2 then p.fields[i - 2] = p.facts[i] end
  end
  p.reward, p.goal = p.facts[1].value, p.facts[2].value
  p.rule = T.Fill(p, "ARTWORK", "border"); p.rule:SetHeight(1)
  p.nextLabel, p.next = Text(p, "caption", "gold"), Text(p, "body", "textMuted")
  ns.Localization.Bind(p.nextLabel, "shared.claimview.next_step.34831e")
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
  local state = tracking and { ns.Locale:Get("shared.claimview.kill_recorded.89fa61"), "success" } or STATES[c.state] or STATES.claimed
  p:SetWidth(width); p.hero:SetWidth(width)
  p.hero:SetTone(state[2])
  local inner, y = width - pad * 2, pad
  p.state:Set((c.previewManage ~= nil and ns.Locale:Get("shared.goldtooltip.sample.8dd386") or "") .. state[1], state[2])
  Kit.Place(p.state, "TOPLEFT", p.hero, "TOPLEFT", pad, -y); y = y + p.state:GetHeight() + 9
  p.name:SetText(ns.Core.DisplayName(c.name)); y = y + Paragraph(p.name, p.hero, pad, y, inner) + 6
  p.hunter:SetText(ns.Locale:Format("shared.claimview.reported_by_value2.5aff53", { value2 = ns.Core.DisplayName(c.claimant) }))
  y = y + Paragraph(p.hunter, p.hero, pad, y, inner) + pad
  p.hero:SetHeight(y); y = y + 16
  local values = {
    ns.Util.Gold(c.gold), tostring(B.Terms.Count(c)), ns.Core.DisplayName(c.by), B.Kills.CauseText(c.cause),
    B.Kills.EvidenceText(c.evidence, B.Kills.Confirmed(c)), ns.Util.Exact(c.killedAt or c.claimedAt),
    B.Terms.Methods(c) ~= "" and B.Terms.Methods(c) or ns.Locale:Get("shared.claimview.any_finish.36e00e"),
    c.paidAt and ns.Util.When(c.paidAt) or c.reviewedBy and ns.Core.DisplayName(c.reviewedBy)
      or ns.Locale:Get("shared.claimview.not_reviewed_yet.4e21ff"),
  }
  ns.Localization.Bind(p.facts[8].label, c.paidAt and "shared.claimview.payment_recorded.35a84c" or "shared.claimview.reviewed_by.056b5c")
  for i, field in ipairs(p.facts) do
    field:Set(values[i])
    Kit.Place(field, "TOPLEFT", p, "TOPLEFT", pad, -y)
    y = y + field:Layout(inner) + (i == 2 and 18 or 10)
  end
  Kit.Place(p.rule, "TOPLEFT", p, "TOPLEFT", pad, -(y + 6)); p.rule:SetWidth(inner); y = y + 22
  y = y + Paragraph(p.nextLabel, p, pad, y, inner) + 7
  local manage = c.previewManage == true or c.previewManage == nil and B.Ledger.CanManage(c)
  local nextStep = tracking and ns.Locale:Get("shared.claimview.saved_to_your_private_history_no_reward.f0c601")
    or c.state == "paid" and ns.Locale:Get("shared.claimview.payment_has_been_recorded_this_report_is.681e49")
    or c.state == "rejected" and ns.Locale:Get("shared.claimview.the_poster_declined_this_report_no_payment.3163d9")
    or c.state == "approved" and (manage and ns.Locale:Get("shared.claimview.pay_the_hunter_through_the_game_then.e1df17")
      or ns.Locale:Get("shared.claimview.your_report_is_approved_arrange_payment_with.d5c8e4"))
    or (manage and ns.Locale:Get("shared.claimview.review_the_evidence_and_bounty_terms_then.1f5f68")
      or c.public and not c.received and (B.Public.Now() > c.killedAt + B.Public.CLAIM_WINDOW
        and ns.Locale:Get("shared.claimview.delivery_was_not_confirmed_before_the_reporting.feaf38")
        or ns.Locale:Get("shared.claimview.your_report_is_saved_highground_retries_delivery.1e51a3"))
      or ns.Locale:Get("shared.claimview.your_report_is_saved_wait_for_the.d687f9"))
  local offer = c.previewManage == nil and c.public and B.Public.Data().offers[c.pledge]
  if offer and offer.contract then
    nextStep = ns.Locale:Format("shared.claimview.completion_is_decided_by_value2_value4.4c2859", { value2 = ns.Core.DisplayName(offer.contract.by), value4 = (c.state == "approved" and ns.Locale:Get("shared.claimview.their_acceptance_obliges_you_to_pay_this.127d23")
        or c.state == "claimed" and ns.Locale:Get("shared.claimview.your_contribution_follows_their_decision_you_cannot.5ff02f") or nextStep) })
  end
  p.next:SetText(nextStep .. (c.previewManage ~= nil and ns.Locale:Get("shared.claimview.preview_actions_only_change_sample_data.3b44f5")
    or ns.Locale:Get("shared.claimview.highground_does_not_transfer_gold.8f2904")))
  y = y + Paragraph(p.next, p, pad, y, inner) + pad
  p:SetHeight(y)
  return y
end

function V.Row(row, entry)
  local c = entry.claim
  local state = B.Ledger.Tracking(c) and { ns.Locale:Get("shared.claimview.kill_recorded.89fa61"), "success" } or STATES[c.state] or STATES.claimed
  T.SetRole(row.label, "rowName")
  row.summary:SetText(ns.Util.Gold(c.gold) .. " · " .. state[1]:lower())
  T.Paint(row.summary, state[2])
end
