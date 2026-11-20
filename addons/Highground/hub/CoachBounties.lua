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
local function Clickable(button)
  return button and button.IsEnabled and button.GetScript and button:GetScript("OnClick")
    and button:IsVisible() and button:IsEnabled() and button or nil
end
local function SaveHint()
  local w = V(B.Form.previewWin)
  if not w then return "Replay to reopen your draft." end
  if w.formMode ~= "public" then return "Back returns to the audience choice. This walkthrough uses Shared." end
  return w.error:GetText() ~= "" and w.error:GetText() or "Save this sample reward. Nothing is published."
end

local function PostSteps()
  local saved, reviewed, paid
  return {
    { id = "create", title = "Create a reward for other hunters",
      text = "Start on My bounties. Create bounty opens the real form with sample data.",
      hint = "Click Create bounty, or Next to activate it.", requireAction = true,
      enter = function() S.Board("mine") end, target = function() return V(S.win) and S.win.create end,
      advance = function() return V(B.Form.previewWin) and "target" end },
    { id = "target", title = "1 of 3 · Target",
      text = "This path follows one shared reward through a hunter's claim and your review. Edit the sample target, and use Shared so other players can hunt it.",
      hint = "Choose Next: reward when ready. Nothing is posted yet.", capture = S.Remember, requireAction = true,
      enter = function() S.Form("name") end,
      target = function() return Field("action") end,
      advance = function() return V(B.Form.previewWin) and B.Form.previewWin.step == 2 and "reward" end },
    { id = "reward", title = "2 of 3 · Reward",
      text = "Set the gold per kill. One kill and any finish are the defaults. A note and custom conditions are optional.",
      hint = "Choose Review bounty to check the full commitment.", capture = S.Remember, requireAction = true,
      enter = function() S.Form("gold") end, target = function() return GoldReturn() or Field("action") end,
      advance = function() return V(B.Form.previewWin) and B.Form.previewWin.step == 3 and "save" end },
    { id = "save", title = "3 of 3 · Review and create",
      text = "Save the shared bounty. Its target, reward and conditions stay together for the rest of this walkthrough.",
      hint = SaveHint, missing = SaveHint, requireAction = true, capture = S.Remember,
      enter = function() S.Form("review"); saved = D.state.coachSaveVersion or 0 end,
      target = function() return GoldReturn() or Field("action") end,
      advance = function()
        if (D.state.coachSaveVersion or 0) > saved then return D.state.draftMode == "public" and "posted" or "target" end
      end },
    { id = "posted", title = "Share your bounty",
      text = function() return Target() .. " is ready. Share bounty copies a link for other hunters. Shared rewards also appear in game, so sending a link is optional." end,
      hint = "Try Share bounty, or Next to practice reviewing a hunter's claim.",
      enter = function() S.Posted(); OpenDetails() end,
      target = function() return V(B.Exchange.previewShareWin) and B.Exchange.previewShareWin.done or S.DetailButton("Share bounty") end,
      action = function() return V(B.Exchange.previewShareWin) and B.Exchange.previewShareWin.done end },
    { id = "review", title = "Review the hunter's evidence",
      text = "Check the evidence and bounty terms. Honor credit may include assists; a saved screenshot only confirms image capture. Approve records the reward owed; Reject declines the report.",
      hint = "Try Approve, or Next to activate it. No gold moves.", requireAction = true,
      enter = function() Review(); reviewed = S.Claim().state end, target = function() return ClaimTarget(1) end,
      complete = function() return S.Claim().state ~= "claimed" end,
      next = function() return S.Claim().state == "rejected" and "finish" or "payment" end,
      advance = function() local state = S.Claim().state; if state ~= reviewed then return state == "approved" and "payment" or "finish" end end },
    { id = "payment", title = "Pay in the game, then record it",
      text = "After paying the hunter through the game, choose Mark paid. This records payment; Highground never transfers gold. Record payment on the board returns to this report.",
      hint = "Try Mark paid, or Next to activate it.", requireAction = true,
      enter = function()
        Review(); local claim = S.Claim()
        if claim.state == "claimed" then claim.state, claim.reviewedBy = "approved", B.Me(); D.claimsWin:Refresh() end
        paid = claim.state
      end, target = function() return ClaimTarget(2) end,
      complete = function() return S.Claim().state == "paid" or S.Claim().state == "rejected" end,
      advance = function() return S.Claim().state ~= paid and "finish" end },
    { id = "finish", title = function() return S.Claim() and S.Claim().state == "rejected" and "Keep the review record" or "Keep the payment record" end,
      text = "This report keeps the bounty's target, reward, evidence and decision together. Further kills on a larger goal need their own review and payment.",
      hint = "Done returns to the two bounty paths. Real bounties and balances are unchanged.",
      enter = function()
        local existing = S.Claim(); Review()
        if not existing then local claim = S.Claim(); claim.state, claim.paidAt = "paid", B.Public.Now(); D.claimsWin:Refresh() end
      end, target = function() return V(D.claimsWin) and D.claimsWin.claimProfile.state end },
  }
end

local function HuntSteps()
  local tracking
  return {
    { id = "browse", title = "Find a reward on the Shared board",
      text = "Shared board lists rewards offered by other players. You can browse here at any time; new bounty popups are another way to discover them.",
      hint = "Click Shared board, or Next to activate it.", requireAction = true,
      enter = function() S.Board("mine") end, target = function() return V(S.win) and S.win.tabs.public end,
      advance = function() return V(S.win) and B.Board.preview.tab == "public" and "reward" end },
    { id = "reward", title = "Inspect a reward before tracking it",
      text = function() return "This wanted card offers a reward for " .. Target() .. ". Open it to read the full conditions." end,
      hint = "Click View bounty, or Next.", requireAction = true,
      enter = function() S.Board("public"); S.win.search:SetText("") end,
      target = function() return S.CardButton("public") end, advance = function() return Details() and "terms" end },
    { id = "terms", title = "Check what earns the reward",
      text = "Check the target, reward and expiry. Read any custom conditions below them; long posters scroll. Return to the card to start tracking. No contribution is needed.",
      hint = "Click Back to preview, or Next.", requireAction = true,
      enter = OpenDetails, target = function() return Details() and B.Details.win.back end,
      advance = function() return not Details() and V(S.win) and "tracking" end },
    { id = "tracking", title = "Start tracking this target",
      text = "Choose Start tracking. The card changes to TRACKING and appears in My bounties. Stop tracking turns its alerts off; it does not remove your rewards or reports. Tracking pledges no gold.",
      hint = function() return D.state.interest == "tracking" and "Already tracking this target. Next continues to its sample sighting."
        or "Click Start tracking. Next activates the highlighted control." end, requireAction = true,
      enter = function() S.Board("public"); S.win.search:SetText(""); tracking = D.state.coachInterestVersion or 0 end,
      target = function() return D.state.interest == "tracking" and S.win.tabs.mine or S.PrimaryButton() end,
      action = function() return D.state.interest ~= "tracking" and Clickable(S.PrimaryButton()) or nil end,
      complete = function() return D.state.interest == "tracking" end,
      advance = function()
        if (D.state.coachInterestVersion or 0) > tracking then return D.state.interest == "ignored" and "status" or "sighting" end
      end },
    { id = "sighting", title = "Sample event: your target is nearby",
      text = function() return "A sighting detects " .. Target() .. ", the same target you chose to track. Close this alert to continue to a sample kill, or inspect its poster again." end,
      hint = "Close the wanted alert, or Next to activate its close button.", requireAction = true,
      enter = function()
        Hunt(); S.Select("nearby"); D.Replay()
        S.ReturnOn(B.Poster.previewWin.close, B.Poster.previewWin)
      end,
      target = function() return Details() and B.Details.win.back or V(B.Poster.previewWin) and B.Poster.previewWin.close end,
      advance = function() return not V(B.Poster.previewWin) and not Details() and V(S.win) and "kill" end },
    { id = "kill", title = "Sample event: the target is killed",
      text = "The addon creates the report automatically. A readable killing blow is confirmed; honor credit may include assists. The screenshot checkmark only means the image was saved. Open the report to follow review.",
      hint = "Click View sample report. Copying proof is optional; no real screenshot or report is sent.", requireAction = true,
      enter = function() Hunt(); S.Proof("saved") end,
      target = function() local copy, w = V(B.Exchange.previewProofWin), S.Poster(B.Proof); return copy and copy.done or w and w.details end,
      advance = function() return (V(D.claimsWin) or not V(B.Proof.previewWin) and not V(B.Exchange.previewProofWin) and V(S.win) and S.Claim()) and "status" end },
    { id = "status", title = function() return D.state.interest == "ignored" and "Bounty ignored" or "Follow your own claim" end,
      text = function() return D.state.interest == "ignored" and "This target was not added to your tracked bounties. Start the hunting path again whenever you want to try a claim."
        or "Your report is saved. Its next step explains delivery, review or payment. The poster reviews the reward and pays through the game. Use Claim reward or Report a missed kill only when detection missed a death." end,
      hint = "Done returns to the two bounty paths. No real report, screenshot or message was sent.",
      enter = function()
        if D.state.interest == "ignored" then S.Board("mine")
        else Hunt(true); S.MakeClaim(false); if not V(D.claimsWin) then S.Claims() end end
      end,
      target = function() return V(D.claimsWin) and D.claimsWin.claimProfile.state or V(S.win) and S.win.tabs.mine end },
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
