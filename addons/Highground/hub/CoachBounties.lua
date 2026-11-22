local _, ns = ...
local C, B = ns.Onboarding.Coach, ns.Bounty
local D, S = B.Preview, C.BountySample
local V = S.Visible
local function Details() return B.Details.preview and V(B.Details.win) end
local function Field(key) local w = V(B.Form.previewWin); return w and w[key] end
local function GoldReturn() local w = V(B.GoldView.previewWin); return w and w.done end
local function Target() return ns.Core.DisplayName(D.state.coachBounty.name) end
local function OpenDetails()
  if not Details() then S.Board("mine"); S.Details(D.state.coachRow) end
end
local function Hunt(killed)
  D.state.interest = "tracking"
  if killed and not D.state.coachKill then
    D.state.kills, D.state.capture = 1, "saved"
    D.state.coachKill = D.ProofItem()
  end
end
local function Review()
  S.Incoming()
  if not V(D.claimsWin) then S.Claims() end
end
local function ClaimTarget(index)
  local w = V(D.claimsWin)
  return w and (w.actions[index]:IsEnabled() and w.actions[index] or w.claimProfile.state)
end
local Clickable = C.Clickable
local function SaveHint()
  local w = V(B.Form.previewWin)
  if not w then return ns.Locale:Get("highground.coachbounties.replay_to_reopen_your_draft.fc6f69") end
  if w.formMode ~= "public" then return ns.Locale:Get("highground.coachbounties.back_returns_to_the_audience_choice_this.331865") end
  return w.error:GetText() ~= "" and w.error:GetText() or ns.Locale:Get("highground.coachbounties.save_this_sample_reward_nothing_is_published.860b3b")
end

local function PostSteps()
  local saved, reviewed, paid
  return {
    { id = "create", title = ns.Locale:Get("highground.coachbounties.create_a_reward_for_other_hunters.c036fa"),
      text = ns.Locale:Get("highground.coachbounties.start_on_my_bounties_create_bounty_opens.553999"),
      hint = ns.Locale:Get("highground.coachbounties.click_create_bounty_or_next_to_activate.39f99c"), requireAction = true,
      enter = function() S.Board("mine") end, target = function() return V(S.win) and S.win.create end,
      advance = function() return V(B.Form.previewWin) and "target" end },
    { id = "target", title = ns.Locale:Get("highground.coachbounties.1_of_3_target.b285f5"),
      text = ns.Locale:Get("highground.coachbounties.this_path_follows_one_shared_reward_through.0f6fb3"),
      hint = ns.Locale:Get("highground.coachbounties.choose_next_reward_when_ready_nothing_is.3f6873"), capture = S.Remember, requireAction = true,
      enter = function() S.Form("name") end,
      target = function() return Field("action") end,
      advance = function() return V(B.Form.previewWin) and B.Form.previewWin.step == 2 and "reward" end },
    { id = "reward", title = ns.Locale:Get("highground.coachbounties.2_of_3_reward.69e70e"),
      text = ns.Locale:Get("highground.coachbounties.set_the_gold_per_kill_one_kill.19457b"),
      hint = ns.Locale:Get("highground.coachbounties.choose_review_bounty_to_check_the_full.b05001"), capture = S.Remember, requireAction = true,
      enter = function() S.Form("gold") end, target = function() return GoldReturn() or Field("action") end,
      advance = function() return V(B.Form.previewWin) and B.Form.previewWin.step == 3 and "save" end },
    { id = "save", title = ns.Locale:Get("highground.coachbounties.3_of_3_review_and_create.a294c5"),
      text = ns.Locale:Get("highground.coachbounties.save_the_shared_bounty_its_target_reward.03ecb2"),
      hint = SaveHint, missing = SaveHint, requireAction = true, capture = S.Remember,
      enter = function() S.Form("review"); saved = D.state.coachSaveVersion or 0 end,
      target = function() return GoldReturn() or Field("action") end,
      advance = function()
        if (D.state.coachSaveVersion or 0) > saved then return D.state.draftMode == "public" and "posted" or "target" end
      end },
    { id = "posted", title = ns.Locale:Get("highground.coachbounties.share_your_bounty.48b966"),
      text = function() return ns.Locale:Format("highground.coachbounties.value1_is_ready_share_bounty_copies_a.0dc471", { value1 = Target() }) end,
      hint = ns.Locale:Get("highground.coachbounties.try_share_bounty_or_next_to_practice.a5db6b"),
      enter = function() S.Posted(); OpenDetails() end,
      target = function() return V(B.Exchange.previewShareWin) and B.Exchange.previewShareWin.done or S.DetailButton(ns.Locale:Get("highground.coachbounties.share_bounty.94e67c")) end,
      action = function() return V(B.Exchange.previewShareWin) and B.Exchange.previewShareWin.done end },
    { id = "review", title = ns.Locale:Get("highground.coachbounties.review_the_hunter_s_evidence.9122ff"),
      text = ns.Locale:Get("highground.coachbounties.check_the_evidence_and_bounty_terms_honor.133997"),
      hint = ns.Locale:Get("highground.coachbounties.try_approve_or_next_to_activate_it.6ec9dd"), requireAction = true,
      enter = function() Review(); reviewed = S.Claim().state end, target = function() return ClaimTarget(1) end,
      complete = function() return S.Claim().state ~= "claimed" end,
      next = function() return S.Claim().state == "rejected" and "finish" or "payment" end,
      advance = function() local state = S.Claim().state; if state ~= reviewed then return state == "approved" and "payment" or "finish" end end },
    { id = "payment", title = ns.Locale:Get("highground.coachbounties.pay_in_the_game_then_record_it.846e10"),
      text = ns.Locale:Get("highground.coachbounties.after_paying_the_hunter_through_the_game.c29898"),
      hint = ns.Locale:Get("highground.coachbounties.try_mark_paid_or_next_to_activate.2dd990"), requireAction = true,
      enter = function()
        Review(); local claim = S.Claim()
        if claim.state == "claimed" then claim.state, claim.reviewedBy = "approved", B.Me(); D.claimsWin:Refresh() end
        paid = claim.state
      end, target = function() return ClaimTarget(2) end,
      complete = function() return S.Claim().state == "paid" or S.Claim().state == "rejected" end,
      advance = function() return S.Claim().state ~= paid and "finish" end },
    { id = "finish", title = function() return S.Claim() and S.Claim().state == "rejected" and ns.Locale:Get("highground.coachbounties.keep_the_review_record.a3d78e") or ns.Locale:Get("highground.coachbounties.keep_the_payment_record.dbcd2c") end,
      text = ns.Locale:Get("highground.coachbounties.this_report_keeps_the_bounty_s_target.8e6fa6"),
      hint = ns.Locale:Get("highground.coachbounties.done_returns_to_the_two_bounty_paths.522a07"),
      enter = function()
        local existing = S.Claim(); Review()
        if not existing then local claim = S.Claim(); claim.state, claim.paidAt = "paid", B.Public.Now(); D.claimsWin:Refresh() end
      end, target = function() return V(D.claimsWin) and D.claimsWin.claimProfile.state end },
  }
end

local function HuntSteps()
  local tracking
  return {
    { id = "browse", title = ns.Locale:Get("highground.coachbounties.find_a_reward_on_the_shared_board.eb6540"),
      text = ns.Locale:Get("highground.coachbounties.shared_board_lists_rewards_offered_by_other.16ad7b"),
      hint = ns.Locale:Get("highground.coachbounties.click_shared_board_or_next_to_activate.c968ce"), requireAction = true,
      enter = function() S.Board("mine") end, target = function() return V(S.win) and S.Tab("public") end,
      advance = function() return V(S.win) and B.Board.preview.tab == "public" and "reward" end },
    { id = "reward", title = ns.Locale:Get("highground.coachbounties.inspect_a_reward_before_tracking_it.d290ec"),
      text = function() return ns.Locale:Format("highground.coachbounties.this_wanted_card_offers_a_reward_for.b6fd13", { value2 = Target() }) end,
      hint = ns.Locale:Get("highground.coachbounties.click_view_bounty_or_next.dc340a"), requireAction = true,
      enter = function() S.Board("public"); S.win.search:SetText("") end,
      target = function() return S.CardButton("public") end, advance = function() return Details() and "terms" end },
    { id = "terms", title = ns.Locale:Get("highground.coachbounties.check_what_earns_the_reward.391d20"),
      text = ns.Locale:Get("highground.coachbounties.check_the_target_reward_and_expiry_read.94c5fa"),
      hint = ns.Locale:Get("highground.coachbounties.click_back_to_preview_or_next.d9e682"), requireAction = true,
      enter = OpenDetails, target = function() return Details() and B.Details.win.back end,
      advance = function() return not Details() and V(S.win) and "tracking" end },
    { id = "tracking", title = ns.Locale:Get("highground.coachbounties.start_tracking_this_target.50a0d0"),
      text = ns.Locale:Get("highground.coachbounties.choose_start_tracking_the_card_changes_to.b9aa0d"),
      hint = function() return D.state.interest == "tracking" and ns.Locale:Get("highground.coachbounties.already_tracking_this_target_next_continues_to.eb8954")
        or ns.Locale:Get("highground.coachbounties.click_start_tracking_next_activates_the_highlighted.5f13d4") end, requireAction = true,
      enter = function() S.Board("public"); S.win.search:SetText(""); tracking = D.state.coachInterestVersion or 0 end,
      target = function() return D.state.interest == "tracking" and S.Tab("mine") or S.PrimaryButton() end,
      action = function() return D.state.interest ~= "tracking" and Clickable(S.PrimaryButton()) or nil end,
      complete = function() return D.state.interest == "tracking" end,
      advance = function()
        if (D.state.coachInterestVersion or 0) > tracking then return D.state.interest == "ignored" and "status" or "sighting" end
      end },
    { id = "sighting", sound = "bounty", title = ns.Locale:Get("highground.coachbounties.sample_event_your_target_is_nearby.f5e819"),
      text = function() return ns.Locale:Format("highground.coachbounties.a_sighting_detects_value2_the_same_target.a41058", { value2 = Target() }) end,
      hint = ns.Locale:Get("highground.coachbounties.close_the_wanted_alert_or_next_to.724954"), requireAction = true,
      enter = function()
        Hunt(); S.Select("nearby"); D.Replay()
        S.ReturnOn(B.Poster.previewWin.close, B.Poster.previewWin)
      end,
      target = function() return Details() and B.Details.win.back or V(B.Poster.previewWin) and B.Poster.previewWin.close end,
      advance = function() return not V(B.Poster.previewWin) and not Details() and V(S.win) and "kill" end },
    { id = "kill", title = ns.Locale:Get("highground.coachbounties.sample_event_the_target_is_killed.ca18c1"),
      text = ns.Locale:Get("highground.coachbounties.the_addon_creates_the_report_automatically_a.1fa40f"),
      hint = ns.Locale:Get("highground.coachbounties.click_view_sample_report_copying_proof_is.ecb999"), requireAction = true,
      enter = function() Hunt(); S.Proof("saved") end,
      target = function() local copy, w = V(B.Exchange.previewProofWin), S.Poster(B.Proof); return copy and copy.done or w and w.details end,
      advance = function() return (V(D.claimsWin) or not V(B.Proof.previewWin) and not V(B.Exchange.previewProofWin) and V(S.win) and S.Claim()) and "status" end },
    { id = "status", title = function() return D.state.interest == "ignored" and ns.Locale:Get("highground.coachbounties.bounty_ignored.3d5adf") or ns.Locale:Get("highground.coachbounties.follow_your_own_claim.e2d148") end,
      text = function() return D.state.interest == "ignored" and ns.Locale:Get("highground.coachbounties.this_target_was_not_added_to_your.871630")
        or ns.Locale:Get("highground.coachbounties.your_report_is_saved_its_next_step.c8431b") end,
      hint = ns.Locale:Get("highground.coachbounties.done_returns_to_the_two_bounty_paths.aa70f3"),
      enter = function()
        if D.state.interest == "ignored" then S.Board("mine")
        else Hunt(true); S.MakeClaim(false); if not V(D.claimsWin) then S.Claims() end end
      end,
      target = function() return V(D.claimsWin) and D.claimsWin.claimProfile.state or V(S.win) and S.Tab("mine") end },
  }
end

function C.BountySteps(role)
  role = role == "hunt" and "hunt" or "post"
  local progress, key = ns.Onboarding.State().samples, "bounty_" .. role
  local retired = role == "post" and { share = "posted", terms = "reward", poster = "posted", incoming = "review" }
    or { proof = "kill", report_open = "kill", report = "kill", submitted = "status" }
  if type(progress) == "table" and retired[progress[key]] then progress[key] = retired[progress[key]] end
  local steps = role == "hunt" and HuntSteps() or PostSteps()
  for _, step in ipairs(steps) do
    local enter, target = step.enter, step.target
    step.enter = function(...) S.Ensure(role); if enter then return enter(...) end end
    step.context = S.Context
    if step.requireAction and not step.action then step.action = function() return Clickable(target()) end end
  end
  return steps
end
