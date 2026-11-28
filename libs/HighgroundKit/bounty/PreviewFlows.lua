local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public
local Demo = B.Preview
-- Not a real export prefix: copying a tour post can never create a real offer.
Demo.CODE = "HIGHGROUND-TOUR-SAMPLE-ONLY"

function Demo.Notice(message)
  if not Demo.scene then return end
  Demo.Ensure().messages[Demo.scene.key] = message
  Demo.Refresh()
end

function Demo.Funding(w)
  local wallet, gold = Demo.Wallet(), B.Terms.Gold(w.gold:GetText()) or 0
  local count = math.max(1, tonumber(w.kills and w.kills:GetText()) or 1)
  if w.killBudget then w.killBudget:SetText(ns.Locale:Format("shared.form.value1_per_approved_kill_up_to_value3.2411d3", { value1 = ns.Util.Gold(gold), value3 = ns.Util.Gold(gold * count) })) end
  w.goldSummary:SetText(ns.Locale:Format("shared.previewflows.sample_value2_value4_available_value6.88b5b0", { value2 = (wallet.enabled and ns.Locale:Get("shared.form.account_gold.d091f7") or ns.Locale:Get("shared.form.character_gold.929e3b")), value4 = B.Scope.Label(), value6 = B.Gold.Format(wallet.available) }))
  w.goldWarning:SetText(gold * count * 10000 > wallet.available
    and (ns.Locale:Format("shared.previewflows.not_enough_available_gold_in_this_sample.29eca8", { value2 = (wallet.required
      and ns.Locale:Get("shared.previewflows.add_gold_or_turn_off_require_enough.ce8c13") or ns.Locale:Get("shared.previewflows.you_can_still_create_this_bounty.f3c9a4")) })) or "")
end

function Demo.OpenCreate(mode, note)
  local row, b = Demo.Sample("create")
  local draft = Demo.Ensure().draft or b
  if note then draft = P.Copy(draft); draft.note = note end
  return B.Form.Open(draft.name or row.name, mode or Demo.state.draftMode or "public", draft, true)
end

function Demo.SaveDraft(w)
  local name, gold = P.Name(B.Form.Name(w)), B.Terms.Gold(w.gold:GetText())
  local terms, err = B.Terms.Validate(tonumber(w.kills:GetText()) or 0, B.TermsEditor.Read(w).killMethods)
  if not name then err = ns.Locale:Get("shared.previewflows.enter_a_valid_player_name.6bf0ee")
  elseif not gold or w.formMode == "public" and gold < 1 then err = ns.Locale:Get("shared.previewflows.enter_a_whole_gold_amount_shared_rewards.1c4407")
  elseif w.formMode == "public" and not P.Duration(w.duration:GetText()) then err = ns.Locale:Get("shared.formsteps.choose_an_expiry_from_5_minutes_to.ed2c89") end
  if err then w.error:SetText(err); return end
  local wallet = Demo.Wallet()
  if wallet.required and gold * terms.killsRequired * 10000 > wallet.available then
    ns.Localization.Bind(w.error, "shared.previewflows.not_enough_sample_gold_open_gold_settings.29bb5c"); return
  end
  local editing = Demo.testing and Demo.state.editingSample
  local row, b
  if editing then
    row, b = P.Copy(editing[1]), P.Copy(editing[2])
    row.personal, row.guild, row.shared = b, nil, nil
  else row, b = Demo.Sample("create") end
  b.name, b.gold, b.note = name, gold, B.Clean(w.note:GetText())
  b.killsRequired, b.killMethods = terms.killsRequired, terms.killMethods
  b.expiresAt = P.Now() + (P.Duration(w.duration:GetText()) or 86400)
  row.name, row.gold, row.note = b.name, b.gold, b.note
  row.status = B.Terms.Summary(b)
  if w.formMode == "guild" then
    b.state = "pending"; b.approver = nil
    row.personal, row.guild, row.scope, row.visibility, row.state = nil, b, "guild", "Guild", "pending"
  elseif w.formMode == "public" then
    local offer = P.Copy(b)
    offer.id, offer.contributor, offer.state = "preview-draft", "preview-account", "active"
    offer.createdAt, offer.checkedAt, offer.funds = P.Now(), P.Now(), "available"
    b.state, b.contributions = "public", { offer }
    row.personal, row.shared, row.scope, row.visibility, row.state = nil, b, "public", "Shared", "public"
  end
  Demo.state.draft, Demo.state.draftMode = P.Copy(b), w.formMode
  if editing then editing[1], editing[2] = row, b
  else Demo.state.samples.create = { row, b } end
  Demo.state.editingSample = nil
  if Demo.testing or Demo.scene.key == "create" then Demo.row, Demo.bounty = row, b end
  Demo.Notice(ns.Locale:Format("shared.previewflows.sample_bounty_saved_row_visibility_no_reward.ce436b", { row_visibility = row.visibility }))
  w:Hide()
  if Demo.testing then Demo.TestBoard() end
end

function Demo.AddGold(w)
  local gold = B.Terms.Gold(w.gold:GetText())
  if not gold or gold < 1 then ns.Localization.Bind(w.error, "shared.previewflows.enter_a_positive_whole_gold_amount.79d46d"); w:Layout(); return end
  local b, wallet = Demo.bounty, Demo.Wallet()
  if wallet.required and gold * B.Terms.Count(b) * 10000 > wallet.available then
    ns.Localization.Bind(w.error, "shared.previewflows.not_enough_sample_gold_change_the_requirement.a7a2d6"); w:Layout(); return
  end
  local added = Demo.state.addedContributions or {}
  Demo.state.addedContributions = added
  local contribution = added[b]
  if not contribution then
    if not b.contributions then
      local original = P.Copy(b)
      b.contributions, b.pledgedGold, b.expiresAt = { original }, b.gold, B.Pot.Expires(original)
      b.mega, Demo.row.pot = true, b
    end
    contribution = B.Terms.Copy({ id = "preview-added", contributor = "preview-you", by = B.Me(), name = b.name,
      state = "active", gold = 0, note = b.note, createdAt = P.Now(), expiresAt = b.expiresAt,
      funds = "available", checkedAt = P.Now(), contract = P.Copy(w.contract) }, b)
    added[b] = contribution
    b.contributions[#b.contributions + 1] = contribution
  end
  Demo.state.addedContribution = contribution
  contribution.gold = contribution.gold + gold
  b.gold, b.pledgedGold, Demo.row.gold = b.gold + gold, b.pledgedGold + gold, Demo.row.gold + gold
  Demo.row.owner = ns.Locale:Format("shared.previewflows.value1_contributors_including_your_sample_reward.271b98", { value1 = #b.contributions })
  Demo.row.status = ns.Locale:Format("shared.previewflows.sample_pot_increased_by_value2_per_approved.7e01ad", { value2 = ns.Util.Gold(gold) })
  Demo.Notice(ns.Locale:Format("shared.previewflows.demo_row_status_only_the_preview_changed.707574", { Demo_row_status = Demo.row.status })); w:Hide()
  if Demo.testing then Demo.TestDetails(Demo.row) end
end

function Demo.DecodeSample(text)
  if not text:find(Demo.CODE, 1, true) then return nil, ns.Locale:Get("shared.previewflows.use_the_sample_code_from_share_import.003c05") end
  local _, b = Demo.Sample("exchange")
  return { audience = Demo.Ensure().audience or "global", bounty = b, contributions = b.contributions }
end

function Demo.Interest(value)
  local state = Demo.Ensure()
  state.interest = value
  if Demo.testing then
    state.interests = state.interests or {}
    state.interests[B.Key(Demo.bounty.name)] = value
  end
  Demo.Notice(value == "tracking" and ns.Locale:Get("shared.previewflows.sample_target_is_now_tracked_no_gold.a1a486")
    or ns.Locale:Get("shared.previewflows.sample_target_ignored_replay_to_try_start.4a9dea"))
end

function Demo.Guild(state)
  local b, row = Demo.bounty, Demo.row
  b.state, row.state = state, state
  b.approver = state == "approved" and B.Me() or nil
  row.status = state == "pending" and ns.Locale:Get("shared.previewflows.awaiting_officer_approval.5ee88d") or state == "approved" and ns.Locale:Get("shared.previewflows.approved_by_the_sample_officer.b3e15c") or ns.Locale:Get("shared.previewflows.submission_rejected_sample_only.cea7c5")
  Demo.HideAlerts()
  if state == "approved" then B.Matches.Show(b, true); Demo.Dock(B.Matches.previewWin) end
  Demo.Notice(row.status)
end

-- bare: without "Sample progress:", for a labelled row.
function Demo.Progress(b, bare)
  local state, count = Demo.state or {}, B.Terms.Count(b)
  local relevant = state.coachRole ~= nil or Demo.scene and (Demo.scene.key == "kill" or Demo.scene.key == "claims")
  local done = relevant and (state.approved or 0) or 0
  local pending = relevant and math.max(0, (state.kills or 1) - done) or 0
  if state.coachRole then pending = state.coachPending or 0 end
  local waiting = pending > 0 and ns.Locale:Format("shared.previewflows.pending_pending_review.5d459c", { pending = pending }) or ""
  local complete = done >= count and ns.Locale:Get("shared.previewflows.complete.938ad0") or ""
  if bare then
    return ns.Locale:Format("bounty.progress.value", { done = done, count = count,
      kills = ns.Locale:Get("shared.terms.kills_approved.8c44fb"), pending = waiting, complete = complete })
  end
  return ns.Locale:Format("shared.previewflows.sample_progress_done_count_kills_approved_value6.ea08b4", { done = done, count = count, value6 = waiting, value7 = complete })
end

function Demo.ProofItem()
  local state = Demo.Ensure()
  local captureText = Demo.testing and ({ pending = ns.Locale:Get("shared.previewflows.taking_screenshot.4b1e7c"),
    saved = ns.Locale:Get("shared.previewflows.screenshot_saved_successfully_in_wow_screenshots.b0687a"), failed = ns.Locale:Get("shared.previewflows.screenshot_failed_retry_or_use_the_screenshot.73a99d") })[state.capture]
  local causes = { { event = "SPELL_DAMAGE", spellID = 5308, spellName = "Execute" },
    { event = "ENVIRONMENTAL_DAMAGE", environment = "FALLING" }, false }
  local causeIndex = state.causeIndex or (ns.GAME == "cata" and 1 or 3)
  return { bounty = Demo.bounty, at = P.Now(), preview = true, global = true,
    zone = ns.Locale:Get("shared.preview.tarren_mill.f2b545"), ruleset = B.Scope.Ruleset(), cause = causes[causeIndex] or nil,
    evidence = ns.Caps.combatLog and "observed killing blow" or "honor credit",
    screenshot = state.capture == "saved", captureState = state.capture,
    captureText = captureText or ({ pending = ns.Locale:Get("shared.previewflows.sample_screenshot_awaiting_confirmation_no_file_taken.b9d0ab"),
      saved = ns.Locale:Get("shared.previewflows.sample_screenshot_success_checkmark_no_file_taken.ac9876"),
      failed = ns.Locale:Get("shared.previewflows.sample_screenshot_failed_try_the_sample_retry.44702f") })[state.capture] }
end

function Demo.Capture(state)
  local current = Demo.Ensure()
  current.capture, current.captureRevision = state, (current.captureRevision or 0) + 1
  Demo.Dock(B.Proof.Preview(Demo.bounty, Demo.ProofItem())); Demo.Refresh()
  return current.captureRevision
end

function Demo.RetryCapture()
  local state = Demo.Ensure()
  if state.capture == "pending" then return end
  local revision = Demo.Capture("pending")
  C_Timer.After(0.6, function()
    if Demo.state == state and Demo.scene and Demo.scene.key == "kill" and state.captureRevision == revision
      and state.capture == "pending" then Demo.Capture("saved") end
  end)
end

function Demo.AnotherKill()
  local state = Demo.Ensure()
  if state.kills >= B.Terms.Count(Demo.bounty) then Demo.Notice(ns.Locale:Get("shared.previewflows.the_sample_kill_goal_is_reached_review.7010fd")); return end
  state.kills = state.kills + 1
  local claim = P.Copy(Demo.claims[1])
  claim.id, claim.killedAt, claim.claimedAt = "preview-repeat-" .. state.kills, P.Now() + state.kills, P.Now() + state.kills
  Demo.claims[#Demo.claims + 1] = claim
  Demo.Capture("pending"); Demo.Notice(ns.Locale:Format("shared.previewflows.sample_kill_state_kills_recorded_it_awaits.670130", { state_kills = state.kills }))
end

function Demo.FundingState()
  local state, b = Demo.Ensure(), Demo.bounty
  state.fundingIndex = (state.fundingIndex or 1) % 4 + 1
  local funds = ({ "available", "insufficient", "unknown", "stale" })[state.fundingIndex]
  for _, p in ipairs(b.contributions) do p.funds = funds == "stale" and "available" or funds; p.checkedAt = funds == "stale" and 0 or P.Now() end
  Demo.row.status = ns.Locale:Format("shared.previewflows.funding_example_value2.9b26e9", { value2 = (P.FUND_LABELS[funds] or funds) })
  Demo.HideAlerts(); Demo.Notice(ns.Locale:Format("shared.previewflows.demo_row_status_open_view_bounty_to.3e8467", { Demo_row_status = Demo.row.status }))
end

function Demo.Actions(key)
  local function create() return Demo.OpenCreate() end
  local function claims() return Demo.OpenClaims() end
  local function share() return B.Exchange.PreviewShare(Demo.bounty, Demo.state.audience or "global") end
  local actions = {
    nearby = { { ns.Locale:Get("shared.previewflows.replay_alert.fdf1a7"), Demo.Replay } },
    board = { { ns.Locale:Get("shared.previewflows.try_creating.e8981a"), create }, { ns.Locale:Get("shared.previewflows.sample_claims.c0aa8f"), claims } },
    create = { { ns.Locale:Get("shared.previewflows.open_sample_form.2db53b"), create }, { ns.Locale:Get("shared.form.gold_settings.6b81f3"), function() B.GoldView.Open(true) end }, { ns.Locale:Get("shared.previewflows.share_sample_optional.07366e"), share } },
    gold = { { ns.Locale:Get("shared.form.gold_settings.6b81f3"), function() B.GoldView.Open(true) end }, { ns.Locale:Get("shared.previewflows.try_a_reward.f97922"), create } },
    guild = { { ns.Locale:Get("shared.board.awaiting_approval.d0a0d8"), function() Demo.Guild("pending") end }, { ns.Locale:Get("shared.previewflows.approve_sample.c3ea41"), function() Demo.Guild("approved") end },
      { ns.Locale:Get("shared.previewflows.reject_sample.c52bf5"), function() Demo.Guild("removed") end }, { ns.Locale:Get("shared.previewflows.replay_alert.fdf1a7"), Demo.Replay } },
    shared = { { ns.Locale:Get("shared.previewflows.replay_arrival.6d5195"), Demo.Replay }, { ns.Locale:Get("shared.previewflows.alert_settings.eed020"), function() B.Preferences.Open(true) end },
      { ns.Locale:Get("shared.previewflows.next_funding_state.6374a2"), Demo.FundingState } },
    pot = { { ns.Locale:Get("shared.previewflows.add_sample_gold.1e5d31"), function() B.Pot.Open(Demo.bounty.contributions[1], true) end }, { ns.Locale:Get("shared.previewflows.share_sample_pot.7be8b6"), share } },
    exchange = { { ns.Locale:Get("shared.previewflows.share_sample.16c412"), share }, { ns.Locale:Get("shared.previewflows.import_sample.119fcb"), function() B.Exchange.OpenImport(Demo.CODE, true) end },
      { ns.Locale:Get("shared.details.change_audience.c4df26"), function()
        local nextAudience = { global = "guild", guild = "private", private = "global" }
        Demo.state.audience = nextAudience[Demo.state.audience or "global"]
        Demo.Notice(ns.Locale:Format("shared.previewflows.sample_sharing_audience_demo_state_audience_open.a8841c", { Demo_state_audience = Demo.state.audience }))
      end } },
    kill = { { ns.Locale:Get("shared.previewflows.another_kill.88fccc"), Demo.AnotherKill }, { ns.Locale:Get("shared.previewflows.approve_sample_kill.d94299"), function()
        Demo.state.approved = math.min(Demo.state.kills, (Demo.state.approved or 0) + 1)
        Demo.Capture(Demo.state.capture); Demo.Notice(Demo.Progress(Demo.bounty))
      end }, { ns.Locale:Get("shared.previewflows.screenshot_success.6dafe3"), function() Demo.Capture("saved") end }, { ns.Locale:Get("shared.previewflows.screenshot_failure.a8c0fb"), function() Demo.Capture("failed") end },
      { ns.Locale:Get("shared.previewflows.next_killing_blow.964e51"), function()
        Demo.state.causeIndex = (Demo.state.causeIndex or (ns.GAME == "cata" and 1 or 3)) % 3 + 1
        Demo.Capture(Demo.state.capture)
      end }, { ns.Locale:Get("shared.previewflows.sample_claims.c0aa8f"), claims } },
    claims = { { ns.Locale:Get("shared.previewflows.open_sample_claims.0713b7"), claims }, { ns.Locale:Get("shared.previewflows.replay_kill.94e264"), function() Demo.Select("kill") end } },
    suggestions = { { ns.Locale:Get("shared.previewflows.view_sample_reports.4b707e"), function() B.Suggestions.View.Details(Demo.Reports(), true) end }, { ns.Locale:Get("shared.previewflows.review_sample_draft.75dc27"), function() Demo.OpenCreate("personal") end } },
  }
  return actions[key] or {}
end
