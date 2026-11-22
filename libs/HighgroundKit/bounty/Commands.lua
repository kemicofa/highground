local _, ns = ...
local Commands, Core = ns.Commands, ns.Core
-- Highground Bounties sets /hgb (its Host.lua).
local CMD = ns.BOUNTY_CMD or "/hg bounty"

local USAGE = ns.Locale:Format("shared.commands.cmd_board_list_add_gold_name_note.cf3ad9", { CMD = CMD })

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
  elseif sub == "import" then
    Bounty.Exchange.OpenImport(rest)
  elseif sub == "export" then
    local b = Bounty.Entry(NameArg(rest))
    if not b then return say(ns.Locale:Get("shared.commands.no_bounty_to_export.4b6690")) end
    if b.state == "public" then
      local p = Bounty.Public.Own(b.name) or b.contributions[1]
      Bounty.Exchange.Show(p, "global")
    else Bounty.Exchange.Show(b, Bounty.Pot.Audience(b)) end
  elseif sub == "claims" then
    Bounty.Ledger.Open()
  elseif sub == "gold" then
    Bounty.GoldView.Open()
  elseif sub == "suggestions" then
    Bounty.Board.SetTab("suggestions"); Bounty.Board.Open()
  elseif sub == "on" or sub == "off" then
    say(ns.Locale:Format("shared.commands.bounty_alerts_value2.41d0af", { value2 = (Core.SetFeature("bounty", sub == "on") and "on" or "OFF") }))
  elseif sub == "add" then
    -- Gold is optional: "add 500 Name" or "add Name" (names never start with a digit).
    local gold, who = rest:match("^(%d+[gG]?)%s+(.+)$")
    who = who or rest
    local name, note = (who or ""):match("^([^;]-)%s*;%s*(.*)$")
    name = NameArg(name or who)
    if not name then return say(ns.Locale:Format("shared.commands.usage_cmd_add_gold_name_note.fd63aa", { CMD = CMD })) end
    local b, err = Bounty.Add(name, gold, note)
    if not b then return say(err or ns.Locale:Get("shared.commands.bounty_not_added.b3001e")) end
    say(M.AddedPersonal(b))
  elseif sub == "share" then
    local name = NameArg(rest)
    if not name then return say(ns.Locale:Format("shared.commands.usage_cmd_share_name.6722b3", { CMD = CMD })) end
    -- Blizzard clears the edit box after a slash handler returns. Open
    -- the share draft on the next frame so it survives that cleanup.
    C_Timer.After(0.01, function() ns.Util.Guard("bounty share", Bounty.Share.ToChat, name) end)
  elseif M.done[sub] then
    local name = NameArg(rest)
    if not name then return say(ns.Locale:Format("shared.commands.usage_cmd_sub_name.b6396d", { CMD = CMD, sub = sub })) end
    local _, text = Bounty.Act(sub, name)
    say(text)
  elseif sub == "sync" then
    say(M.Sync(Bounty.RequestSync()))
  elseif sub == "test" then
    Bounty.Preview.Command(rest)
  elseif sub == "guide" then
    Bounty.Preview.GuideCommand(rest)
  elseif sub == "list" then
    local list = Bounty.All()
    say(ns.Locale:Format((#list == 1 and "bounty.count.one" or "bounty.count.other"), { count = #list, status = (Core.On("bounty") and "" or ns.Locale:Get("shared.commands.alerts_off.1cdabd")) }))
    for _, b in ipairs(list) do
      say(ns.Locale:Format("shared.commands.value1_value2_b_state_by_value4_value5.51af01", { value1 = string.format("%s", Bounty.GoldText(b)), value2 = string.format("%s", Core.DisplayName(b.name)), b_state = string.format("%s", b.state), value4 = string.format("%s", Core.DisplayName(b.by or "?")), value5 = string.format("%s", b.note and ("  " .. b.note) or "") }))
    end
  else
    say(USAGE)
  end
end
