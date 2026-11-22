local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public
local A = {}
B.BoardActions = A

function A.Primary(r)
  if r.suggestion then return r.ignored and "Allow again" or r.existing and "View bounty" or "Review bounty" end
  if r.guild and r.guild.state == "pending" and B.IsOfficer(nil, r.guild) then return "Approve" end
  local report = not r.preview and B.Ledger.ForBounty(r)
  if report then return report.claimant == B.Me() and "View report" or report.state == "approved" and "Record payment" or "Review report" end
  if r.offer and P.Mine(r.offer) and not P.CanManage(r.offer) then return "View bounty" end
  if r.offer and r.offer.contract and P.CanManage(r.offer) then return "Edit reward" end
  if r.offer and P.CanManage(r.offer) then return "Edit reward" end
  if r.scope == "public" then return B.Matches.Tracking(r) and "Stop tracking" or "Start tracking" end
  if r.personal then return "Edit reward" end
  if r.guild and r.guild.by == B.Me() then return "Share globally" end
  return B.Matches.Tracking(r) and "Stop tracking" or "Start tracking"
end

function A.Help(r)
  if r.suggestion then return r.ignored and "Restore suggestions for this enemy."
    or "Open an existing bounty or review a draft. Choose the audience and optional reward before saving." end
  return ({
    Approve = "Approve this submission now, making it visible to members of its guild or community. Open the bounty to reject it.",
    Edit = "Edit your private target, reward and note. Save keeps it private.",
    ["Edit reward"] = "Review the amount and expiry, then publish your changes. Published notes and kill terms stay fixed.",
    ["Share globally"] = "Review this guild or community reward in the Shared form, then publish it to participating players on your realm and faction.",
    ["Report kill"] = B.Kills.Hint(),
    ["View report"] = "This kill already has a report. Open its evidence, review and payment status.",
    ["Start tracking"] = "Add this target to My bounties and get sighting alerts. Detected kills are reported automatically; tracking costs no gold.",
    ["Stop tracking"] = "Stop this target's sighting alerts and remove it from your tracked targets. Your rewards and reports are kept.",
    ["Review report"] = "Review the incoming kill report and approve the reward if its terms are met.",
    ["Record payment"] = "Open the approved report. After paying the hunter through the game, choose Mark paid.",
    ["View bounty"] = "See who offers the reward, when it expires, and how to report a kill or add your own reward.",
  })[A.Primary(r)]
end

function A.Report(r, missed)
  local previous = not missed and B.Ledger.ForBounty(r)
  if previous then B.Ledger.Open(r.name, previous.killedAt, previous.id); return true, "This kill already has a report." end
  local pot = B.Pot.Find(r.name)
  if not pot then return nil, "No eligible live reward to report." end
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
  local label = A.Primary(r)
  if label == "Approve" then
    local b, err = B.Approve(r.name, r.guild and r.guild.organization); B.Emit("updated"); return b ~= nil, err or "Bounty approved."
  elseif label == "Edit reward" and r.personal and not r.offer then B.Form.Open(r.name, "personal", r.personal)
  elseif label == "Edit reward" and r.offer and r.offer.contract then B.Pot.Open(r.offer)
  elseif label == "Edit reward" or label == "Share globally" then B.Form.Open(r.name, "public", r.guild)
  elseif label == "View bounty" then A.Details(r)
  elseif label == "Start tracking" then B.Matches.Set(r.name, "tracking"); return true, "Tracking this target. Detected kills are reported automatically."
  elseif label == "Stop tracking" then B.Matches.Set(r.name, "ignored"); return true, "Stopped tracking. Alerts for this target are off."
  elseif label == "View report" or label == "Review report" or label == "Record payment" then
    local report = B.Ledger.ForBounty(r)
    B.Ledger.Open(r.name, report and report.killedAt, report and report.id); return true
  else return A.Report(r) end
end

-- The line above the cards: the latest action result, else what this board is for.
function A.Hint(owner)
  if owner.message then return owner.message, owner.messageTone or "success" end
  if owner.provider then return "Sample bounties · try the real controls. Nothing is saved or sent." end
  return owner.tab == "mine" and "Tracked targets and your rewards. Each card shows its tracking state."
    or owner.tab == "suggestions" and "Review the death reports, then choose whether to create a bounty. Nothing is posted automatically."
    or owner.tab == "guild" and "Hunt an approved target. Detected kills are reported automatically; follow the review in Claims & payments."
    or not B.Public.Receiving() and "Browsing is paused. Saved rewards remain below. Choose Browse shared bounties to receive new offers."
    or "Open a bounty to see who pays, track the target or view its kill reports. Lower rewards stay listed below your alert minimum."
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
    message, tone = "Refresh cancelled for the previous board.", "warning"
  elseif not owner.provider and a.tab == "public" and B.Public.transportError and B.Public.transportError ~= a.error then
    message, tone = B.Public.transportError, "warning"
  elseif now >= a.deadline then
    -- Discovery has no all-peers-done packet. Keep the response window open
    -- through active transfers, with a finite upper bound for missing peers.
    -- Community and large guild replies also use the shared transport.
    local pending = not owner.provider and (next(B.Public.incoming) or #B.Public.outbox > 0 or #B.queue > 0)
    if pending and now < a.limit then return true, "Syncing…" end
    message = owner.provider and "Sample board refreshed. Nothing sent."
      or pending and "Refresh timed out. Incoming updates will still appear automatically."
      or "Refresh window finished. Incoming updates continue automatically."
    tone = pending and "warning" or "success"
  end
  if message then owner.refreshAttempt, owner.message, owner.messageTone = nil, message, tone; return false end
  return true, "Syncing…"
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
  A.Notify(owner, owner.provider and "Refreshing sample rewards… Nothing is sent." or "Waiting for rewards from online participants…", "text")
end
