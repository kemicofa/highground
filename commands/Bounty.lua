local _, ns = ...
local Commands, Core = ns.Commands, ns.Core

local USAGE = "/wb bounty [board] | list | add [GOLD] NAME [; note] | submit NAME | approve NAME | reject NAME"
  .. " | remove NAME | claim NAME | sync | test | on | off  (NAME can be \"target\"; Name-Realm for other realms)"

-- The name as typed, keeping case and spaces; "target" reads your target.
local function NameArg(text)
  text = (text or ""):match("^%s*(.-)%s*$")
  if text:lower() == "target" then
    return UnitExists("target") and Core.CanonUnit("target") or nil
  end
  return text ~= "" and text or nil
end

local DONE = {
  submit = function(b)
    return b.state == "approved" and ("posted " .. Core.DisplayName(b.name) .. " to the guild")
      or ("submitted " .. Core.DisplayName(b.name) .. ": an officer must approve it")
  end,
  approve = function(b) return "approved " .. Core.DisplayName(b.name) end,
  reject = function(b) return "rejected " .. Core.DisplayName(b.name) end,
  remove = function(b) return "bounty on " .. Core.DisplayName(b.name) .. " removed" end,
  claim = function(b) return "claim for " .. Core.DisplayName(b.name) .. " sent to " .. Core.DisplayName(b.by or "?") end,
}

-- /wb bounty: bounties (bounty/). Names may contain spaces.
function Commands.bounty(arg, msg, say)
  local Bounty = ns.Bounty
  local raw = (msg or ""):match("^%S+%s*(.-)%s*$") or ""
  local sub, rest = raw:match("^(%S*)%s*(.-)$")
  sub = sub:lower()
  if sub == "" or sub == "board" then
    Bounty.Board.Toggle()
  elseif sub == "on" or sub == "off" then
    Core.db.bounty = sub == "on"
    say("bounty alerts " .. (Core.db.bounty and "on" or "OFF"))
  elseif sub == "add" then
    -- Gold is optional: "add 500 Name" or "add Name" (names never start with a digit).
    local gold, who = rest:match("^(%d+)%s+(.+)$")
    who = who or rest
    local name, note = (who or ""):match("^([^;]-)%s*;%s*(.*)$")
    name = NameArg(name or who)
    if not name then return say("usage: /wb bounty add [GOLD] NAME [; note]") end
    local b, err = Bounty.Add(name, gold, note)
    if not b then return say(err or "bounty not added") end
    say(string.format("%s on %s (personal%s)", Bounty.Amount(b), Core.DisplayName(b.name),
      Bounty.InGuild() and ": /wb bounty submit " .. Core.DisplayName(b.name) .. " to post it to your guild" or ""))
  elseif DONE[sub] then
    local name = NameArg(rest)
    if not name then return say("usage: /wb bounty " .. sub .. " NAME") end
    local fn = ({ submit = Bounty.Submit, approve = Bounty.Approve, reject = Bounty.Remove,
      remove = Bounty.Remove, claim = Bounty.Claim })[sub]
    local b, err = fn(name)
    if not b then return say(err or "failed") end
    say(DONE[sub](b))
    if Bounty.Board.Refresh then Bounty.Board.Refresh() end
  elseif sub == "sync" then
    say(Bounty.RequestSync() and "asking your guild for its bounties" or "not in a guild")
  elseif sub == "test" then
    Bounty.Announce({ name = "Wanted-" .. (Core.myRealm or ""), gold = 500, by = Bounty.Me() or "you",
      state = "approved", note = "test" }, "test")
  elseif sub == "list" then
    local list = Bounty.All()
    say(#list .. " bount" .. (#list == 1 and "y" or "ies") .. (Core.On("bounty") and "" or " (alerts OFF)"))
    for _, b in ipairs(list) do
      say(string.format("  %s  %s  %s by %s%s", Bounty.GoldText(b), Core.DisplayName(b.name), b.state,
        Core.DisplayName(b.by or "?"), b.note and ("  " .. b.note) or ""))
    end
  else
    say(USAGE)
  end
end
