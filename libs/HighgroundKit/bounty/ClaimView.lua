local _, ns = ...
local B, T, Kit = ns.Bounty, ns.Theme, ns.Kit
local V = {}
B.ClaimView = V
local STATES = { claimed = ns.Localization.Define({ ns.Locale:Get("shared.claimview.awaiting_review.5d3376"), "pending" }, { [1] = "shared.claimview.awaiting_review.5d3376" }), approved = ns.Localization.Define({ ns.Locale:Get("shared.claimview.approved_payment_due.9709f7"), "gold" }, { [1] = "shared.claimview.approved_payment_due.9709f7" }),
  paid = ns.Localization.Define({ ns.Locale:Get("shared.claimview.paid.f3534d"), "success" }, { [1] = "shared.claimview.paid.f3534d" }), rejected = ns.Localization.Define({ ns.Locale:Get("shared.claimview.declined.e2bd52"), "textMuted" }, { [1] = "shared.claimview.declined.e2bd52" }) }

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
  local state = tracking and { ns.Locale:Get("shared.claimview.kill_recorded.89fa61"), "success" } or STATES[c.state] or STATES.claimed
  p:SetWidth(width); p.hero:SetWidth(width)
  T.Paint(p.state, state[2]); T.Paint(p.strip, state[2])
  local inner, y = width - pad * 2, pad
  y = y + Place(p.state, (c.previewManage ~= nil and ns.Locale:Get("shared.goldtooltip.sample.8dd386") or "") .. state[1], pad, y, inner) + 9
  y = y + Place(p.name, ns.Core.DisplayName(c.name), pad, y, inner) + 6
  y = y + Place(p.hunter, ns.Locale:Format("shared.claimview.reported_by_value2.5aff53", { value2 = ns.Core.DisplayName(c.claimant) }), pad, y, inner) + pad
  p.hero:SetHeight(y)
  p.stats:ClearAllPoints(); p.stats:SetPoint("TOPLEFT", 0, -y); p.stats:SetWidth(width)
  local cell = width / 2
  local height = math.max(Place(p.reward, ns.Util.Gold(c.gold), pad, 14, cell - pad * 2),
    Place(p.goal, tostring(B.Terms.Count(c)), cell + pad, 14, cell - pad * 2)) + 20
  height = height + math.max(Place(p.rewardLabel, ns.Locale:Get("shared.claimview.this_kill_s_reward.d36351"), pad, height, cell - pad * 2),
    Place(p.goalLabel, ns.Locale:Get("shared.claimview.bounty_kill_goal.612407"), cell + pad, height, cell - pad * 2)) + 14
  p.stats:SetHeight(height); y = y + height + 20
  local values = {
    { ns.Locale:Get("shared.claimview.posted_by.bf4654"), ns.Core.DisplayName(c.by) },
    { ns.Locale:Get("shared.claimview.killing_blow.e0295f"), B.Kills.CauseText(c.cause) },
    { ns.Locale:Get("shared.claimview.kill_detection.9567f3"), B.Kills.EvidenceText(c.evidence, B.Kills.Confirmed(c)) },
    { ns.Locale:Get("shared.claimview.kill_recorded.89fa61"), date("%d %b %Y · %H:%M:%S", c.killedAt or c.claimedAt) },
    { ns.Locale:Get("shared.claimview.preferred_finish.4c9904"), B.Terms.Methods(c) ~= "" and B.Terms.Methods(c) or ns.Locale:Get("shared.claimview.any_finish.36e00e") },
    { c.paidAt and ns.Locale:Get("shared.claimview.payment_recorded.35a84c") or ns.Locale:Get("shared.claimview.reviewed_by.056b5c"), c.paidAt and date("%d %b %Y · %H:%M", c.paidAt)
      or c.reviewedBy and ns.Core.DisplayName(c.reviewedBy) or ns.Locale:Get("shared.claimview.not_reviewed_yet.4e21ff") },
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
  y = y + Place(p.nextLabel, ns.Locale:Get("shared.claimview.next_step.34831e"), pad, y, inner) + 7
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
  y = y + Place(p.next, nextStep .. (c.previewManage ~= nil and ns.Locale:Get("shared.claimview.preview_actions_only_change_sample_data.3b44f5") or ns.Locale:Get("shared.claimview.highground_does_not_transfer_gold.8f2904")), pad, y, inner) + pad
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
