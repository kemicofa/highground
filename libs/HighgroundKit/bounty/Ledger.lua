local _, ns = ...
local B, Kit, U = ns.Bounty, ns.Kit, ns.Util
local L = {}
B.Ledger = L

-- A claim is a player's report, never proof of a kill or gold transfer.
-- Keep the offer snapshot so removing/expiring a bounty keeps its history.
function L.All()
  ns.Core.db.bountyClaims = ns.Core.db.bountyClaims or {}
  return ns.Core.db.bountyClaims
end

local function ID(b, from) return table.concat({ b.name, b.by, b.at, from, b.state == "personal" and "personal" or B.GuildKey() or "" }, ";") end
function L.Record(b, from)
  if b.publicID then
    local p = B.LinkedOffer(b)
    return p and B.Public.GuildClaim(p, from) or nil
  end
  local id = ID(b, from)
  for _, c in ipairs(L.All()) do if c.id == id then return c end end
  local c = { id = id, name = b.name, gold = b.gold, by = b.by, offerAt = b.at,
    claimant = from, claimedAt = time(), at = time(), state = "claimed", personal = b.state == "personal",
    guild = b.state ~= "personal" and B.GuildKey() or nil }
  table.insert(L.All(), 1, c)
  while #L.All() > 200 do table.remove(L.All()) end
  if L.win then L.win:Refresh() end
  return c
end

function L.CanManage(c, who)
  who = who or B.Me()
  if c.public then
    local p = B.Public.Data().offers[c.pledge]
    return p ~= nil and B.Public.CanManage(p) and who == B.Me()
  end
  return c.by == who or (not c.personal and c.guild ~= nil and c.guild == B.GuildKey() and B.IsOfficer(who))
end

function L.Change(c, state)
  if c.public then return B.Public.ChangeClaim(c, state) end
  if not L.CanManage(c) then return false, "Only the poster or a guild officer can settle this claim." end
  if c.state == "paid" or c.state == "rejected" then return false, "This claim is already settled." end
  if not ({ approved = true, paid = true, rejected = true })[state] then return false, "Unknown claim state." end
  if state == "paid" and c.state ~= "approved" then return false, "Approve the claim before marking it paid." end
  c.state, c.at, c.reviewedBy = state, math.max(time(), c.at + 1), B.Me()
  if state == "paid" then c.paidAt = time() end
  if not c.personal and c.guild == B.GuildKey() then
    B.Send(table.concat({ "1:L", B.Clean(c.name), c.offerAt, B.Clean(c.claimant), state, c.at }, ","))
  end
  return true, state == "paid" and "Marked paid manually. No gold was transferred." or ("Claim " .. state .. ".")
end

function L.Receive(rest, from)
  local name, offerAt, claimant, state, at = rest:match("^,([^,]+),(%d+),([^,]+),(%a+),(%d+)$")
  offerAt, at = tonumber(offerAt), tonumber(at)
  if not at or at > time() + 86400 or not ({ approved = true, paid = true, rejected = true })[state] then return end
  for _, c in ipairs(L.All()) do
    if c.name == name and c.offerAt == offerAt and c.claimant == claimant and not c.personal and c.guild == B.GuildKey()
      and at > c.at and L.CanManage(c, from) and c.state ~= "paid" and c.state ~= "rejected" then
      c.state, c.at, c.reviewedBy = state, at, from
      if state == "paid" then c.paidAt = at end
    end
  end
  if L.win then L.win:Refresh() end
end

function L.Entry(c)
  return { key = c.id, claim = c, title = c.name, summary = c.state .. "  ·  " .. c.gold .. "g",
      detail = c.name .. "\nReward: " .. c.gold .. "g\nPosted by: " .. c.by .. "\nClaimed by: " .. c.claimant
        .. "\nStatus: " .. c.state .. "\nClaim date: " .. date("%Y-%m-%d %H:%M", c.claimedAt)
        .. (c.public and ("\nShared contribution: " .. c.pledge .. "\nEvidence: " .. c.evidence
          .. "\nKill date: " .. date("%Y-%m-%d %H:%M", c.killedAt)
          .. "\nEach contribution is reviewed and paid separately. First approved claim earns it.") or "")
        .. (c.reviewedBy and ("\nReviewed by: " .. c.reviewedBy) or "")
        .. (c.paidAt and ("\nMarked paid: " .. date("%Y-%m-%d %H:%M", c.paidAt)) or "")
        .. "\n\nClaims are reports. Approval and payment are recorded manually. Pay players through the game." }
end

local function Entries()
  local out, claims = {}, {}
  for _, c in ipairs(L.All()) do claims[#claims + 1] = c end
  if B.Public then for _, c in pairs(B.Public.Data().claims) do claims[#claims + 1] = c end end
  table.sort(claims, function(a, b) return a.claimedAt > b.claimedAt end)
  for _, c in ipairs(claims) do out[#out + 1] = L.Entry(c) end
  return out
end

function L.Open()
  if not L.win then
    local actions = {}
    for _, choice in ipairs({ { "Approve", "approved" }, { "Mark paid", "paid" }, { "Reject", "rejected" } }) do
      actions[#actions + 1] = { label = choice[1], enabled = function(e)
        return L.CanManage(e.claim) and (choice[2] == "paid" and e.claim.state == "approved"
          or choice[2] ~= "paid" and e.claim.state == "claimed")
      end, run = function(e) return L.Change(e.claim, choice[2]) end }
    end
    L.win = Kit.Browser((ns.FRAME_PREFIX or "Highground") .. "BountyLedger", { title = "BOUNTY CLAIMS",
      strata = "FULLSCREEN_DIALOG", alpha = 1,
      hint = "Personal, guild and shared claims. Search target, claimant, poster or status. Payments are recorded manually.",
      data = Entries, empty = "No claims yet. Report a kill with the bounty claim command.", actions = actions })
    B.Widgets.BrowserHelp(L.win, {
      "Accept this kill report and record that the reward is owed. Only an authorized reviewer can approve it; no gold is transferred.",
      "After paying the hunter through the game, record the approved claim as paid. This button does not send gold.",
      "Decline a pending kill report after review. An approved payment obligation cannot be rejected.",
    })
  end
  L.win:Open(); B.Widgets.ShowWindow(L.win); return L.win
end

B.Listen("claimed", L.Record)
B.Listen("updated", function() if L.win and L.win:IsShown() then L.win:Refresh() end end)
