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
  if w.killBudget then w.killBudget:SetText(ns.Util.Gold(gold) .. " per approved kill\nUp to " .. ns.Util.Gold(gold * count) .. " total") end
  w.goldSummary:SetText("SAMPLE · " .. (wallet.enabled and "Account gold" or "Character gold") .. " · " .. B.Scope.Label()
    .. "\nAvailable: " .. B.Gold.Format(wallet.available))
  w.goldWarning:SetText(gold * count * 10000 > wallet.available
    and ("Not enough available gold in this sample wallet. " .. (wallet.required
      and "Add gold or turn off Require enough gold." or "You can still create this bounty.")) or "")
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
  if not name then err = "Enter a valid player name."
  elseif not gold or w.formMode == "public" and gold < 1 then err = "Enter a whole gold amount; shared rewards need at least 1g."
  elseif w.formMode == "public" and not P.Duration(w.duration:GetText()) then err = "Choose an expiry from 5 minutes to 30 days." end
  if err then w.error:SetText(err); return end
  local wallet = Demo.Wallet()
  if wallet.required and gold * terms.killsRequired * 10000 > wallet.available then
    w.error:SetText("Not enough sample gold. Open Gold & settings to turn off Require enough gold."); return
  end
  local row, b = Demo.Sample("create")
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
  Demo.state.samples.create = { row, b }
  if Demo.scene.key == "create" then Demo.row, Demo.bounty = row, b end
  Demo.Notice("Sample bounty saved · " .. row.visibility .. ". No reward published, settings changed or gold committed.")
  w:Hide()
end

function Demo.AddGold(w)
  local gold = B.Terms.Gold(w.gold:GetText())
  if not gold or gold < 1 then w.error:SetText("Enter a positive whole gold amount."); w:Layout(); return end
  local b, wallet = Demo.bounty, Demo.Wallet()
  if wallet.required and gold * B.Terms.Count(b) * 10000 > wallet.available then
    w.error:SetText("Not enough sample gold. Change the requirement in Account gold."); w:Layout(); return
  end
  local contribution = Demo.state.addedContribution
  if not contribution then
    contribution = B.Terms.Copy({ id = "preview-added", contributor = "preview-you", by = B.Me(), name = b.name,
      state = "active", gold = 0, note = b.note, createdAt = P.Now(), expiresAt = b.expiresAt,
      funds = "available", checkedAt = P.Now(), contract = B.Pot.Contract(b.contributions[1]) }, b)
    Demo.state.addedContribution = contribution
    b.contributions[#b.contributions + 1] = contribution
  end
  contribution.gold = contribution.gold + gold
  b.gold, b.pledgedGold, Demo.row.gold = b.gold + gold, b.pledgedGold + gold, Demo.row.gold + gold
  Demo.row.owner = #b.contributions .. " contributors · including your sample reward"
  Demo.row.status = "Sample pot increased by " .. ns.Util.Gold(gold) .. " per approved kill"
  Demo.Notice(Demo.row.status .. ". Only the preview changed."); w:Hide()
end

function Demo.DecodeSample(text)
  if not text:find(Demo.CODE, 1, true) then return nil, "Use the sample code from Share & import. Real codes are not imported by this tour." end
  local _, b = Demo.Sample("exchange")
  return { audience = Demo.Ensure().audience or "global", bounty = b, contributions = b.contributions }
end

function Demo.Interest(value)
  Demo.Ensure().interest = value
  Demo.Notice(value == "tracking" and "Sample target is now tracked. No gold pledged; your real tracking list is unchanged."
    or "Sample target ignored. Replay to try Start tracking; your real alert preferences are unchanged.")
end

function Demo.Guild(state)
  local b, row = Demo.bounty, Demo.row
  b.state, row.state = state, state
  b.approver = state == "approved" and B.Me() or nil
  row.status = state == "pending" and "Awaiting officer approval" or state == "approved" and "Approved by the sample officer" or "Submission rejected · sample only"
  Demo.HideAlerts()
  if state == "approved" then B.Matches.Show(b, true); Demo.Dock(B.Matches.previewWin) end
  Demo.Notice(row.status)
end

function Demo.Progress(b)
  local state, count = Demo.state or {}, B.Terms.Count(b)
  local relevant = state.coachRole ~= nil or Demo.scene and (Demo.scene.key == "kill" or Demo.scene.key == "claims")
  local done = relevant and (state.approved or 0) or 0
  local pending = relevant and math.max(0, (state.kills or 1) - done) or 0
  if state.coachRole then pending = state.coachPending or 0 end
  return "Sample progress: " .. done .. "/" .. count .. " kills approved"
    .. (pending > 0 and (" · " .. pending .. " pending review") or "") .. (done >= count and " · Complete" or "")
end

function Demo.ProofItem()
  local state = Demo.Ensure()
  local causes = { { event = "SPELL_DAMAGE", spellID = 5308, spellName = "Execute" },
    { event = "ENVIRONMENTAL_DAMAGE", environment = "FALLING" }, false }
  local causeIndex = state.causeIndex or (ns.GAME == "cata" and 1 or 3)
  return { bounty = Demo.bounty, at = P.Now(), preview = true, global = true,
    zone = "Tarren Mill", ruleset = B.Scope.Ruleset(), cause = causes[causeIndex] or nil,
    evidence = ns.Caps.combatLog and "observed killing blow" or "honor credit",
    screenshot = state.capture == "saved", captureState = state.capture,
    captureText = ({ pending = "SAMPLE · Screenshot awaiting confirmation. No file taken.",
      saved = "SAMPLE · Screenshot success checkmark. No file taken.",
      failed = "SAMPLE · Screenshot failed. Try the sample retry button." })[state.capture] }
end

function Demo.Capture(state)
  Demo.Ensure().capture = state
  Demo.Dock(B.Proof.Preview(Demo.bounty, Demo.ProofItem())); Demo.Refresh()
end

function Demo.AnotherKill()
  local state = Demo.Ensure()
  if state.kills >= B.Terms.Count(Demo.bounty) then Demo.Notice("The sample kill goal is reached. Review the pending claims before recording payment."); return end
  state.kills = state.kills + 1
  local claim = P.Copy(Demo.claims[1])
  claim.id, claim.killedAt, claim.claimedAt = "preview-repeat-" .. state.kills, P.Now() + state.kills, P.Now() + state.kills
  Demo.claims[#Demo.claims + 1] = claim
  Demo.Capture("pending"); Demo.Notice("Sample kill " .. state.kills .. " recorded. It awaits approval; the reward is not automatically paid.")
end

function Demo.FundingState()
  local state, b = Demo.Ensure(), Demo.bounty
  state.fundingIndex = (state.fundingIndex or 1) % 4 + 1
  local funds = ({ "available", "insufficient", "unknown", "stale" })[state.fundingIndex]
  for _, p in ipairs(b.contributions) do p.funds = funds == "stale" and "available" or funds; p.checkedAt = funds == "stale" and 0 or P.Now() end
  Demo.row.status = "Funding example: " .. (P.FUND_LABELS[funds] or funds)
  Demo.HideAlerts(); Demo.Notice(Demo.row.status .. ". Open View bounty to inspect each contribution.")
end

function Demo.Actions(key)
  local function create() return Demo.OpenCreate() end
  local function claims() return Demo.OpenClaims() end
  local function share() return B.Exchange.PreviewShare(Demo.bounty, Demo.state.audience or "global") end
  local actions = {
    nearby = { { "Replay alert", Demo.Replay } },
    board = { { "Try creating", create }, { "Sample claims", claims } },
    create = { { "Open sample form", create }, { "Gold & settings", function() B.GoldView.Open(true) end }, { "Share sample (optional)", share } },
    gold = { { "Gold & settings", function() B.GoldView.Open(true) end }, { "Try a reward", create } },
    guild = { { "Awaiting approval", function() Demo.Guild("pending") end }, { "Approve sample", function() Demo.Guild("approved") end },
      { "Reject sample", function() Demo.Guild("removed") end }, { "Replay alert", Demo.Replay } },
    shared = { { "Replay arrival", Demo.Replay }, { "Alert settings", function() B.Preferences.Open(true) end },
      { "Next funding state", Demo.FundingState } },
    pot = { { "Add sample gold", function() B.Pot.Open(Demo.bounty.contributions[1], true) end }, { "Share sample pot", share } },
    exchange = { { "Share sample", share }, { "Import sample", function() B.Exchange.OpenImport(Demo.CODE, true) end },
      { "Change audience", function()
        local nextAudience = { global = "guild", guild = "private", private = "global" }
        Demo.state.audience = nextAudience[Demo.state.audience or "global"]
        Demo.Notice("Sample sharing audience: " .. Demo.state.audience .. ". Open Share sample to see its destination.")
      end } },
    kill = { { "Another kill", Demo.AnotherKill }, { "Approve sample kill", function()
        Demo.state.approved = math.min(Demo.state.kills, (Demo.state.approved or 0) + 1)
        Demo.Capture(Demo.state.capture); Demo.Notice(Demo.Progress(Demo.bounty))
      end }, { "Screenshot success", function() Demo.Capture("saved") end }, { "Screenshot failure", function() Demo.Capture("failed") end },
      { "Next killing blow", function()
        Demo.state.causeIndex = (Demo.state.causeIndex or (ns.GAME == "cata" and 1 or 3)) % 3 + 1
        Demo.Capture(Demo.state.capture)
      end }, { "Sample claims", claims } },
    claims = { { "Open sample claims", claims }, { "Replay kill", function() Demo.Select("kill") end } },
    suggestions = { { "View sample reports", function() B.Suggestions.View.Details(Demo.Reports(), true) end }, { "Review sample draft", function() Demo.OpenCreate("personal") end } },
  }
  return actions[key] or {}
end
