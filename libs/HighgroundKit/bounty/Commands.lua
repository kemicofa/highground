local _, ns = ...
local Commands, Core = ns.Commands, ns.Core
-- Highground Bounties sets /hgb (its Host.lua).
local CMD = ns.BOUNTY_CMD or "/hg bounty"

local USAGE = CMD .. " [board] | list | add [GOLD] NAME [; note] | submit NAME | approve NAME | reject NAME"
  .. " | claims | remove NAME | claim NAME | share NAME | sync | test | on | off  (NAME can be \"target\"; Name-Realm for other realms)"

-- The name as typed, keeping case and spaces; "target" reads your target.
local function NameArg(text)
  text = ns.Util.Trim(text)
  if text:lower() == "target" then
    return UnitExists("target") and Core.CanonUnit("target") or nil
  end
  return text ~= "" and text or nil
end

-- /hg bounty: bounties (bounty/). Names may contain spaces. Actions and
-- their messages are shared with the board (bounty/Messages.lua).
function Commands.bounty(arg, msg, say)
  local Bounty = ns.Bounty
  local M = Bounty.Messages
  local raw = (msg or ""):match("^%S+%s*(.-)%s*$") or ""
  local sub, rest = raw:match("^(%S*)%s*(.-)$")
  sub = sub:lower()
  if sub == "" or sub == "board" then
    Bounty.Board.Toggle()
  elseif sub == "shared" then
    Bounty.Public.Command(rest)
  elseif sub == "claims" then
    Bounty.Ledger.Open()
  elseif sub == "on" or sub == "off" then
    say("bounty alerts " .. (Core.SetFeature("bounty", sub == "on") and "on" or "OFF"))
  elseif sub == "add" then
    -- Gold is optional: "add 500 Name" or "add Name" (names never start with a digit).
    local gold, who = rest:match("^(%d+)%s+(.+)$")
    who = who or rest
    local name, note = (who or ""):match("^([^;]-)%s*;%s*(.*)$")
    name = NameArg(name or who)
    if not name then return say("usage: " .. CMD .. " add [GOLD] NAME [; note]") end
    local b, err = Bounty.Add(name, gold, note)
    if not b then return say(err or "bounty not added") end
    say(M.AddedPersonal(b))
  elseif sub == "share" then
    local name = NameArg(rest)
    if not name then return say("usage: " .. CMD .. " share NAME") end
    -- Blizzard clears the edit box after a slash handler returns. Open
    -- the share draft on the next frame so it survives that cleanup.
    C_Timer.After(0.01, function() ns.Util.Guard("bounty share", Bounty.Share.ToChat, name) end)
  elseif M.done[sub] then
    local name = NameArg(rest)
    if not name then return say("usage: " .. CMD .. " " .. sub .. " NAME") end
    local _, text = Bounty.Act(sub, name)
    say(text)
  elseif sub == "sync" then
    say(M.Sync(Bounty.RequestSync()))
  elseif sub == "test" then
    Bounty.Preview.Command(rest)
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
