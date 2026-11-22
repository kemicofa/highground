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
  return b.gold > 0 and (ns.Util.Gold(b.gold) .. (Bounty.Terms.Count(b) > 1 and ns.Locale:Get("shared.messages.per_kill.2c08b4") or "")) or ns.Locale:Get("shared.messages.no_reward.9bd4f2")
end

-- "500g" or "a bounty", for "placed ... on Name".
function M.Amount(b)
  return b.gold > 0 and M.Gold(b) or ns.Locale:Get("shared.messages.a_bounty.b0eed9")
end

Bounty.GoldText, Bounty.Amount = M.Gold, M.Amount

M.done = {
  submit = function(b)
    return b.state == "approved" and (ns.Locale:Format("shared.messages.posted_value2_to_value4.525352", { value2 = Name(b), value4 = Bounty.Organizations.Label(b) }))
      or (ns.Locale:Format("shared.messages.submitted_value2_an_officer_or_community_moderator.305a2a", { value2 = Name(b) }))
  end,
  approve = function(b) return ns.Locale:Format("shared.messages.approved_value2.e2e064", { value2 = Name(b) }) end,
  reject = function(b) return ns.Locale:Format("shared.messages.rejected_value2.4d09ec", { value2 = Name(b) }) end,
  remove = function(b) return ns.Locale:Format("shared.messages.bounty_on_value2_removed.0eb14e", { value2 = Name(b) }) end,
  claim = function(b) return ns.Locale:Format("shared.messages.claim_for_value2_sent_to_value4.92bfa8", { value2 = Name(b), value4 = Core.DisplayName(b.by or "?") }) end,
}

function M.Sync(sent)
  return sent and ns.Locale:Get("shared.messages.requesting_bounties_from_your_organization.bc09b4") or ns.Locale:Get("shared.messages.join_a_guild_or_community_first.b91566")
end

-- /hg bounty add: points to the submit command when in a guild.
function M.AddedPersonal(b)
  return ns.Locale:Format("shared.messages.value1_on_value2_personal_value3.056c62", { value1 = string.format("%s", M.Amount(b)), value2 = string.format("%s", Name(b)), value3 = string.format("%s", Bounty.InGuild() and ns.Locale:Format("shared.messages.bounty_cmd_submit_value4_to_post_it.2a49fa", { Bounty_CMD = Bounty.CMD, value4 = Name(b) }) or "") })
end

local RUN = ns.Localization.Define({ submit = ns.Locale:Get("shared.messages.submit.2dacf6"), approve = ns.Locale:Get("shared.boardactions.approve.7b2c7f"), reject = ns.Locale:Get("shared.messages.remove.e96390"), remove = ns.Locale:Get("shared.messages.remove.e96390"), claim = ns.Locale:Get("shared.messages.claim.dc4e08") }, { submit = "shared.messages.submit.2dacf6", approve = "shared.boardactions.approve.7b2c7f", reject = "shared.messages.remove.e96390", remove = "shared.messages.remove.e96390", claim = "shared.messages.claim.dc4e08" })

-- Run an action (a key of M.done) on a name. Returns the entry and its
-- chat line, or nil and the reason.
function Bounty.Act(action, name)
  local b, err = Bounty[RUN[action]](name)
  if not b then return nil, err or "failed" end
  Bounty.Emit("updated")
  return b, M.done[action](b)
end
