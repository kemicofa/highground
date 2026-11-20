local _, ns = ...
local B, P, Kit = ns.Bounty, ns.Bounty.Public, ns.Kit
local A = {}
B.BoardActions = A

local function Remove(r, scope)
  local b, err = B.Remove(r.name, scope, r.guild and r.guild.organization)
  if not b then B.Say(err) else B.Emit("updated") end
end

function A.Items(r, source)
  local items = {}
  local function Add(text, run) items[#items + 1] = { text = text, run = run } end
  if source and r.suggestion then return items end
  if r.suggestion then
    if r.ignored then Add("Allow suggestions again", function() B.Suggestions.Change(r.name, "allow") end)
    else
      Add("Dismiss for 24 hours", function() B.Suggestions.Change(r.name, "dismiss") end)
      Add("Ignore this enemy", function() B.Suggestions.Change(r.name, "ignore") end)
    end
    return items
  end
  if r.personal or r.shared or r.guild or r.offer then
    local state
    if source then state = source.state(r.name) else state = B.Matches.State(r.name) end
    local function Set(value)
      if source then return source.set(r.name, value) end
      return B.Matches.Set(r.name, value)
    end
    local tracking = source and state == "tracking" or not source and B.Matches.Tracking(r)
    if tracking then Add("Stop tracking", function() Set("ignored") end)
    else Add("Start tracking", function() Set("tracking") end) end
    if not tracking and state ~= "ignored" then Add("Ignore bounty alerts", function() Set("ignored") end) end
  end
  -- Explicit sample sources can only change their own tracking state.
  if source then return items end
  if B.Ledger.ForBounty(r) then
    Add("Report a missed kill", function() A.Report(r, true) end)
  end
  if r.guild and r.guild.state == "pending" and B.IsOfficer(nil, r.guild) then
    Add("Approve submission", function() B.Approve(r.name, r.guild and r.guild.organization); B.Emit("updated") end)
    Add("Reject submission", function() Remove(r, "guild") end)
  end
  if r.offer and P.CanManage(r.offer) then
    Add("Edit my shared contribution", function() B.Form.Open(r.name, "public") end)
    if not r.guild then Add("Share with guild or community", function() B.Form.Open(r.name, "guild") end) end
    Add("Withdraw my contribution", function() local _, message = P.Withdraw(r.offer); B.Say(message) end)
  elseif r.personal or r.guild and r.guild.by == B.Me() then
    Add("Publish on shared board", function() B.Form.Open(r.name, "public", r.guild or r.personal) end)
    if r.personal then
      Add("Edit private bounty", function() B.Form.Open(r.name, "personal", r.personal) end)
      if not r.guild then Add("Submit to guild or community", function() B.Form.Open(r.name, "guild", r.personal) end) end
    end
  end
  if r.personal then Add("Export private bounty", function() B.Exchange.Show(r.personal, "private") end) end
  if r.guild then Add("Export organization bounty", function() B.Exchange.Show(r.guild, B.Pot.Audience(r.guild)) end) end
  if r.offer then Add("Share updated bounty", function() B.Exchange.Show(r.offer, B.Pot.Audience(r.offer)) end) end
  if r.personal then Add("Remove private bounty", function() Remove(r, "personal") end) end
  if r.guild and r.guild.state ~= "pending" and (r.guild.by == B.Me() or B.IsOfficer(nil, r.guild)) then
    Add("Remove organization listing", function() Remove(r, "guild") end)
  elseif r.guild and r.guild.state == "pending" and not B.IsOfficer(nil, r.guild) and r.guild.by == B.Me() then
    Add("Withdraw submission", function() Remove(r, "guild") end)
  end
  if B.Pot.Default(r.name) then Add("Add gold to pot", function() B.Pot.Open(B.Pot.Default(r.name)) end) end
  return items
end

function A.Menu(anchor, r, source)
  local items = A.Items(r, source)
  if #items > 0 then
    Kit.Dropdown.Open(anchor, items, function(item) item.run() end, {
      width = 350 * math.max(1, ns.Core.FontScale()), keepOpenFor = source and source.keepOpenFor,
    })
  end
end

function A.Primary(r)
  if r.suggestion then return r.ignored and "Allow again" or r.existing and "View bounty" or "Review bounty" end
  if r.guild and r.guild.state == "pending" and B.IsOfficer(nil, r.guild) then return "Approve" end
  local report = not r.preview and B.Ledger.ForBounty(r)
  if report then return report.claimant == B.Me() and "View report" or report.state == "approved" and "Record payment" or "Review report" end
  if r.offer and P.Mine(r.offer) and not P.CanManage(r.offer) then return "View bounty" end
  if r.offer and r.offer.contract and P.CanManage(r.offer) then return "Add gold" end
  if r.offer and P.CanManage(r.offer) then return "Edit reward" end
  if r.scope == "public" then return B.Matches.Tracking(r) and "Stop tracking" or "Start tracking" end
  if r.personal then return "Edit" end
  if r.guild and r.guild.by == B.Me() then return "Share globally" end
  return B.Matches.Tracking(r) and "Stop tracking" or "Start tracking"
end

function A.Help(r)
  if r.suggestion then return r.ignored and "Restore suggestions for this enemy."
    or "Open an existing bounty or review a draft. Choose the audience and optional reward before saving." end
  return ({
    Approve = "Approve this submission now, making it visible to members of its guild or community. Rejection is available under More.",
    Edit = "Edit your private target, reward and note. Save keeps it private.",
    ["Add gold"] = "Increase your contribution under the original poster's completion terms and claim decision.",
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
  elseif label == "Add gold" then B.Pot.Open(r.offer)
  elseif label == "Edit" then B.Form.Open(r.name, "personal", r.personal)
  elseif label == "Edit reward" or label == "Share globally" then B.Form.Open(r.name, "public", r.guild)
  elseif label == "View bounty" then A.Details(r)
  elseif label == "Start tracking" then B.Matches.Set(r.name, "tracking"); return true, "Tracking this target. Detected kills are reported automatically."
  elseif label == "Stop tracking" then B.Matches.Set(r.name, "ignored"); return true, "Stopped tracking. Alerts for this target are off."
  elseif label == "View report" or label == "Review report" or label == "Record payment" then
    local report = B.Ledger.ForBounty(r)
    B.Ledger.Open(r.name, report and report.killedAt, report and report.id); return true
  else return A.Report(r) end
end

function A.Details(r)
  if r.suggestion then return B.Suggestions.View.Details(r) end
  return B.Details.Open(r)
end
