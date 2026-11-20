local _, ns = ...
local Core, Bounty = ns.Core, ns.Bounty

---------------------------------------------------------------------------
-- Bounty actions and their chat lines, shared by the board
-- (bounty/Board.lua) and /hg bounty (bounty/Commands.lua).
---------------------------------------------------------------------------
local M = {}
Bounty.Messages = M

local function Name(b) return Core.DisplayName(b.name) end

-- "1,234g", or "no reward" (gold is optional).
function M.Gold(b)
  if b.state == "public" then return ns.Util.Gold(b.gold) end
  return b.gold > 0 and (ns.Util.Gold(b.gold) .. (Bounty.Terms.Count(b) > 1 and " per kill" or "")) or "no reward"
end

-- "500g" or "a bounty", for "placed ... on Name".
function M.Amount(b)
  return b.gold > 0 and M.Gold(b) or "a bounty"
end

Bounty.GoldText, Bounty.Amount = M.Gold, M.Amount

M.done = {
  submit = function(b)
    return b.state == "approved" and ("posted " .. Name(b) .. " to " .. Bounty.Organizations.Label(b))
      or ("submitted " .. Name(b) .. ": an officer or community moderator must approve it")
  end,
  approve = function(b) return "approved " .. Name(b) end,
  reject = function(b) return "rejected " .. Name(b) end,
  remove = function(b) return "bounty on " .. Name(b) .. " removed" end,
  claim = function(b) return "claim for " .. Name(b) .. " sent to " .. Core.DisplayName(b.by or "?") end,
}

function M.Sync(sent)
  return sent and "requesting bounties from your organization" or "Join a guild or community first."
end

-- Board form: "500g on Name[, posted to the guild]".
function M.Added(b, submitted, err)
  local text = M.Amount(b) .. " on " .. Name(b)
  if submitted then
    return text .. (submitted.state == "approved" and ", posted to the guild" or ", submitted for officer approval")
  end
  return err and (text .. " kept personal: " .. err) or text
end

-- /hg bounty add: points to the submit command when in a guild.
function M.AddedPersonal(b)
  return string.format("%s on %s (personal%s)", M.Amount(b), Name(b),
    Bounty.InGuild() and ": " .. Bounty.CMD .. " submit " .. Name(b) .. " to post it to your guild" or "")
end

local RUN = { submit = "Submit", approve = "Approve", reject = "Remove", remove = "Remove", claim = "Claim" }

-- Run an action (a key of M.done) on a name. Returns the entry and its
-- chat line, or nil and the reason.
function Bounty.Act(action, name)
  local b, err = Bounty[RUN[action]](name)
  if not b then return nil, err or "failed" end
  Bounty.Emit("updated")
  return b, M.done[action](b)
end
