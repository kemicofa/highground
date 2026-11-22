local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public
local A = {}
B.BoardActions = A

function A.PrimaryKey(r)
  if r.suggestion then return r.ignored and "shared.boardactions.allow_again.a84070" or r.existing and "shared.boardactions.view_bounty.be066d" or "shared.boardactions.review_bounty.1d4814" end
  if r.guild and r.guild.state == "pending" and B.IsOfficer(nil, r.guild) then return "shared.boardactions.approve.7b2c7f" end
  local report = not r.preview and B.Ledger.ForBounty(r)
  if report then return report.claimant == B.Me() and "highground.coachbountysamples.view_report.7398c9" or report.state == "approved" and "highground.coachbountysamples.record_payment.86e563" or "highground.coachbountysamples.review_report.29a1c5" end
  if r.offer and P.Mine(r.offer) and not P.CanManage(r.offer) then return "shared.boardactions.view_bounty.be066d" end
  if r.offer and r.offer.contract and P.CanManage(r.offer) then return "highground.coachbountysamples.edit_reward.0854ae" end
  if r.offer and P.CanManage(r.offer) then return "highground.coachbountysamples.edit_reward.0854ae" end
  if r.scope == "public" then return B.Matches.Tracking(r) and "highground.coachbountysamples.stop_tracking.888c9a" or "highground.coachbountysamples.start_tracking.9d94fe" end
  if r.personal then return "highground.coachbountysamples.edit_reward.0854ae" end
  if r.guild and r.guild.by == B.Me() then return "shared.boardactions.share_globally.9b3fc4" end
  return B.Matches.Tracking(r) and "highground.coachbountysamples.stop_tracking.888c9a" or "highground.coachbountysamples.start_tracking.9d94fe"
end

function A.Primary(r) return ns.Locale:Get(A.PrimaryKey(r)) end

function A.Help(r)
  if r.suggestion then return r.ignored and ns.Locale:Get("shared.boardactions.restore_suggestions_for_this_enemy.e57841")
    or ns.Locale:Get("shared.boardactions.open_an_existing_bounty_or_review_a.2846ea") end
  return ({
    ["shared.boardactions.approve.7b2c7f"] = ns.Locale:Get("shared.boardactions.approve_this_submission_now_making_it_visible.6d3233"),
    ["macros.backups.edit.530164"] = ns.Locale:Get("shared.boardactions.edit_your_private_target_reward_and_note.09d6e6"),
    ["highground.coachbountysamples.edit_reward.0854ae"] = ns.Locale:Get("shared.boardactions.review_the_amount_and_expiry_then_publish.4b5ed8"),
    ["shared.boardactions.share_globally.9b3fc4"] = ns.Locale:Get("shared.boardactions.review_this_guild_or_community_reward_in.f07f82"),
    ["shared.messages.report_kill.7ffd8e"] = B.Kills.Hint(),
    ["highground.coachbountysamples.view_report.7398c9"] = ns.Locale:Get("shared.boardactions.this_kill_already_has_a_report_open.facc88"),
    ["highground.coachbountysamples.start_tracking.9d94fe"] = ns.Locale:Get("shared.boardactions.add_this_target_to_my_bounties_and.accdd6"),
    ["highground.coachbountysamples.stop_tracking.888c9a"] = ns.Locale:Get("shared.boardactions.stop_this_target_s_sighting_alerts_and.f72bf4"),
    ["highground.coachbountysamples.review_report.29a1c5"] = ns.Locale:Get("shared.boardactions.review_the_incoming_kill_report_and_approve.7c89fe"),
    ["highground.coachbountysamples.record_payment.86e563"] = ns.Locale:Get("shared.boardactions.open_the_approved_report_after_paying_the.82e541"),
    ["shared.boardactions.view_bounty.be066d"] = ns.Locale:Get("shared.boardactions.see_who_offers_the_reward_when_it.4b9c86"),
  })[A.PrimaryKey(r)]
end

function A.Report(r, missed)
  local previous = not missed and B.Ledger.ForBounty(r)
  if previous then B.Ledger.Open(r.name, previous.killedAt, previous.id); return true, ns.Locale:Get("shared.boardactions.this_kill_already_has_a_report.ecb044") end
  local pot = B.Pot.Find(r.name)
  if not pot then return nil, ns.Locale:Get("shared.boardactions.no_eligible_live_reward_to_report.8f689f") end
  local ok, message = B.Pot.Claim(pot, P.Now(), "manual report")
  B.Say(message)
  if ok then B.Ledger.Open(r.name, P.Now()) end
  return ok ~= nil, message
end

function A.Run(anchor, r)
  if r.suggestion then
    if r.ignored then B.Suggestions.Change(r.name, "allow") else B.Suggestions.View.Review(r.name) end
    return
  end
  local label = A.PrimaryKey(r)
  if label == "shared.boardactions.approve.7b2c7f" then
    local b, err = B.Approve(r.name, r.guild and r.guild.organization); B.Emit("updated"); return b ~= nil, err or ns.Locale:Get("shared.boardactions.bounty_approved.9483c7")
  elseif label == "highground.coachbountysamples.edit_reward.0854ae" and r.personal and not r.offer then B.Form.Open(r.name, "personal", r.personal)
  elseif label == "highground.coachbountysamples.edit_reward.0854ae" and r.offer and r.offer.contract then B.Pot.Open(r.offer)
  elseif label == "highground.coachbountysamples.edit_reward.0854ae" or label == "shared.boardactions.share_globally.9b3fc4" then B.Form.Open(r.name, "public", r.guild)
  elseif label == "shared.boardactions.view_bounty.be066d" then A.Details(r)
  elseif label == "highground.coachbountysamples.start_tracking.9d94fe" then B.Matches.Set(r.name, "tracking"); return true, ns.Locale:Get("shared.boardactions.tracking_this_target_detected_kills_are_reported.2aa66a")
  elseif label == "highground.coachbountysamples.stop_tracking.888c9a" then B.Matches.Set(r.name, "ignored"); return true, ns.Locale:Get("shared.boardactions.stopped_tracking_alerts_for_this_target_are.4642c4")
  elseif label == "highground.coachbountysamples.view_report.7398c9" or label == "highground.coachbountysamples.review_report.29a1c5" or label == "highground.coachbountysamples.record_payment.86e563" then
    local report = B.Ledger.ForBounty(r)
    B.Ledger.Open(r.name, report and report.killedAt, report and report.id); return true
  else return A.Report(r) end
end

-- The line above the cards: the latest action result, else what this board is for.
function A.Hint(owner)
  if owner.message then return owner.message, owner.messageTone or "success" end
  if owner.provider then return ns.Locale:Get("shared.board.sample_bounties_try_the_real_controls_nothing.30d499") end
  return owner.tab == "mine" and ns.Locale:Get("shared.board.tracked_targets_and_your_rewards_each_card.3869f6")
    or owner.tab == "suggestions" and ns.Locale:Get("shared.board.review_the_death_reports_then_choose_whether.a3a9a9")
    or owner.tab == "guild" and ns.Locale:Get("shared.board.hunt_an_approved_target_detected_kills_are.ae01ff")
    or not B.Public.Receiving() and ns.Locale:Get("shared.board.browsing_is_paused_saved_rewards_remain_below.ddcf90")
    or ns.Locale:Get("shared.board.open_a_bounty_to_see_who_pays.ee720e")
end

-- Board feedback keeps its tone: failures and interrupted refreshes are
-- warnings, not successes. Navigating to another board clears it.
function A.Notify(owner, message, tone)
  owner.message, owner.messageTone = message, message and (tone or "success") or nil
  owner.Refresh()
end

-- Card actions report their result on the board, including failures that
-- leave the card unchanged.
function A.Activate(anchor, r)
  local ok, message = A.Run(anchor, r)
  if message then A.Notify(B.Board, message, ok == false and "warning" or "success") end
  return ok, message
end

function A.Details(r)
  if r.suggestion then return B.Suggestions.View.Details(r) end
  return B.Details.Open(r)
end

function A.RefreshStatus(owner)
  local a = owner.refreshAttempt
  if not a then return false end
  local now, message, tone = GetTime()
  if a.tab ~= owner.tab or a.organization ~= owner.organization or a.scope ~= B.Scope.Key() then
    message, tone = ns.Locale:Get("shared.boardactions.refresh_cancelled_for_the_previous_board.d303b0"), "warning"
  elseif not owner.provider and a.tab == "public" and B.Public.transportError and B.Public.transportError ~= a.error then
    message, tone = B.Public.transportError, "warning"
  elseif now >= a.deadline then
    -- Discovery has no all-peers-done packet. Keep the response window open
    -- through active transfers, with a finite upper bound for missing peers.
    -- Community and large guild replies also use the shared transport.
    local pending = not owner.provider and (next(B.Public.incoming) or #B.Public.outbox > 0 or #B.queue > 0)
    if pending and now < a.limit then return true, ns.Locale:Get("shared.boardactions.syncing.221ca6") end
    message = owner.provider and ns.Locale:Get("shared.boardactions.sample_board_refreshed_nothing_sent.fafa81")
      or pending and ns.Locale:Get("shared.boardactions.refresh_timed_out_incoming_updates_will_still.e759e2")
      or ns.Locale:Get("shared.boardactions.refresh_window_finished_incoming_updates_continue_automati.1207b7")
    tone = pending and "warning" or "success"
  end
  if message then owner.refreshAttempt, owner.message, owner.messageTone = nil, message, tone; return false end
  return true, ns.Locale:Get("shared.boardactions.syncing.221ca6")
end

function A.RequestRefresh(owner)
  if owner.refreshAttempt then return end
  local ok, message = true
  if not owner.provider then
    if owner.tab == "public" then ok, message = B.Public.Sync()
    else ok = B.RequestSync(owner.organization); message = B.Messages.Sync(ok) end
    if message then B.Say(message) end
  end
  if not ok then return A.Notify(owner, message, "warning") end
  local now = GetTime()
  owner.refreshAttempt = { tab = owner.tab, organization = owner.organization, scope = B.Scope.Key(),
    deadline = now + (owner.provider and 0.6 or 12), limit = now + 30, error = B.Public.transportError }
  A.Notify(owner, owner.provider and ns.Locale:Get("shared.boardactions.refreshing_sample_rewards_nothing_is_sent.340e4f") or ns.Locale:Get("shared.boardactions.waiting_for_rewards_from_online_participants.fa6145"), "text")
end
