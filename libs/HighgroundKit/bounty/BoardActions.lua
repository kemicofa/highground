local _, ns = ...
local B, P, Kit = ns.Bounty, ns.Bounty.Public, ns.Kit
local A = {}
B.BoardActions = A

local function Remove(r, scope)
  local b, err = B.Remove(r.name, scope)
  if not b then B.Say(err) else B.Emit("updated") end
end

function A.Items(r)
  local items = {}
  local function Add(text, run) items[#items + 1] = { text = text, run = run } end
  if r.suggestion then
    if r.ignored then Add("Allow suggestions again", function() B.Suggestions.Change(r.name, "allow") end)
    else
      Add("Dismiss for 24 hours", function() B.Suggestions.Change(r.name, "dismiss") end)
      Add("Ignore this enemy", function() B.Suggestions.Change(r.name, "ignore") end)
    end
    return items
  end
  if r.guild and r.guild.state == "pending" and B.IsOfficer() then
    Add("Approve guild submission", function() B.Approve(r.name); B.Emit("updated") end)
    Add("Reject guild submission", function() Remove(r, "guild") end)
  end
  if r.offer and P.CanManage(r.offer) then
    Add("Edit my shared contribution", function() B.Form.Open(r.name, "public") end)
    if not r.guild then Add("Share same reward with guild", function() B.Form.Open(r.name, "guild") end) end
    Add("Withdraw my contribution", function() local _, message = P.Withdraw(r.offer); B.Say(message) end)
  elseif r.personal or r.guild and r.guild.by == B.Me() then
    Add("Publish on shared board", function() B.Form.Open(r.name, "public", r.guild or r.personal) end)
    if r.personal then
      Add("Edit private bounty", function() B.Form.Open(r.name, "personal", r.personal) end)
      if not r.guild then Add("Submit to guild", function() B.Form.Open(r.name, "guild", r.personal) end) end
    end
  end
  if r.personal then Add("Remove private bounty", function() Remove(r, "personal") end) end
  if r.guild and r.guild.state ~= "pending" and (r.guild.by == B.Me() or B.IsOfficer()) then
    Add("Remove guild listing", function() Remove(r, "guild") end)
  elseif r.guild and r.guild.state == "pending" and not B.IsOfficer() and r.guild.by == B.Me() then
    Add("Withdraw guild submission", function() Remove(r, "guild") end)
  end
  return items
end

function A.Menu(anchor, r)
  local items = A.Items(r)
  if #items > 0 then
    Kit.Dropdown.Open(anchor, items, function(item) item.run() end, { width = 350 * math.max(1, ns.Core.FontScale()) })
  end
end

function A.Primary(r)
  if r.suggestion then return r.ignored and "Allow again" or r.existing and "View bounty" or "Review bounty" end
  if r.guild and r.guild.state == "pending" and B.IsOfficer() then return "Approve" end
  if r.offer and P.Mine(r.offer) and not P.CanManage(r.offer) then return "View bounty" end
  if r.offer and P.CanManage(r.offer) then return "Edit reward" end
  if r.scope == "public" then return "Contribute" end
  if r.personal then return "Edit" end
  if r.guild and r.guild.by == B.Me() then return "Share globally" end
  return "Report kill"
end

function A.Help(r)
  if r.suggestion then return r.ignored and "Restore suggestions for this enemy."
    or "Open an existing bounty or review a draft. Choose the audience and optional reward before saving." end
  return ({
    Approve = "Approve this guild submission now, making it visible to guild members. Rejection is available under More.",
    Edit = "Edit your private target, reward and note. Save keeps it private.",
    ["Edit reward"] = "Edit your contribution directly. Review the amount, note and duration, then publish your changes.",
    Contribute = "Add your own reward to this exact target. One account contributes once; edits update the same pledge.",
    ["Share globally"] = "Review this guild reward in the Shared form, then publish it to participating players on your realm and faction.",
    ["Report kill"] = "Send a kill report for the poster to review. This does not prove the kill or transfer gold.",
    ["View bounty"] = "View this account's contribution. Only its posting character can edit or withdraw it.",
  })[A.Primary(r)]
end

function A.Run(anchor, r)
  if r.suggestion then
    if r.ignored then B.Suggestions.Change(r.name, "allow") else B.Suggestions.View.Review(r.name) end
    return
  end
  local label = A.Primary(r)
  if label == "Approve" then
    local b, err = B.Approve(r.name); B.Emit("updated"); return b ~= nil, err or "Guild bounty approved."
  elseif label == "Edit" then B.Form.Open(r.name, "personal", r.personal)
  elseif label == "Contribute" or label == "Edit reward" or label == "Share globally" then B.Form.Open(r.name, "public", r.guild)
  elseif label == "View bounty" then A.Details(r)
  else
    local claimed, message = B.Claim(r.name, true)
    B.Say(message or "Kill reported for review.")
    return claimed ~= nil, message or "Kill reported for review."
  end
end

function A.Details(r)
  if r.suggestion then return B.Suggestions.View.Details(r) end
  return B.Details.Open(r)
end
