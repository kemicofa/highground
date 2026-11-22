local _, ns = ...
local B = ns.Bounty
local P = B.Public

function P.Fill(name, source)
  return B.Form.Open(name, "public", source)
end

function P.OpenDetails(name)
  for _, scope in ipairs({ "public", "mine", "guild" }) do
    local row = B.BoardModel.Find(scope, name)
    if row then return B.Details.Open(row) end
  end
  B.Say(ns.Locale:Format("shared.publicview.no_active_bounty_on_value2_earlier_reports.8c8d5e", { value2 = tostring(name) }))
end

function P.Command(text)
  local action, rest = (text or ""):match("^(%S*)%s*(.-)%s*$")
  if action == "" or action == "board" then B.Board.Open(); B.Board.SetTab("public"); return end
  if action == "sync" then local _, message = P.Sync(); B.Say(message); return end
  if action == "claims" then B.Ledger.Open(); return end
  if action == "receive" or action == "publish" then
    if rest ~= "on" and rest ~= "off" then return B.Say(ns.Locale:Format("shared.publicview.use_action_on_or_off.a0bbb2", { action = action })) end
    ns.Core.SetOption(action == "receive" and "bountyReceive" or "bountyPublish", rest == "on")
    P.TransportTick(); B.Say(P.NetworkStatus()); return
  end
  if action == "threshold" then
    local n = tonumber(rest)
    if not P.Integer(n, 0, 999999999) then return B.Say(ns.Locale:Get("shared.publicview.use_a_whole_gold_threshold_from_0.6f954c")) end
    ns.Core.SetOption("bountyMinGold", n); B.Say(ns.Locale:Format("shared.publicview.shared_bounty_alert_minimum_value2.96ae15", { value2 = ns.Util.Gold(n) })); return
  end
  if action == "add" then
    local gold, duration, who = rest:match("^(%d+[gG]?)%s+(%d+[mhd])%s+(.+)$")
    if not who then return B.Say(ns.Locale:Format("shared.publicview.usage_b_cmd_shared_add_gold_duration.282789", { B_CMD = B.CMD })) end
    local name, note = who:match("^([^;]-)%s*;%s*(.*)$")
    name = (name or who):match("^%s*(.-)%s*$")
    if name:lower() == "target" then name = B.Board.TargetPlayer() end
    local p, err = P.Post(name, gold, duration, note)
    B.Say(p and (ns.Locale:Format("shared.publicview.pledged_value2_on_value4_for_value6.1f75f6", { value2 = ns.Util.Gold(p.gold), value4 = ns.Core.DisplayName(p.name), value6 = P.Remaining(p.expiresAt) })) or err)
    return
  end
  if rest:lower() == "target" then rest = B.Board.TargetPlayer() or "" end
  if action == "claim" then local _, message = P.Claim(rest); B.Say(message); return end
  if action == "withdraw" then local _, message = P.Withdraw(P.Own(rest)); B.Say(message); return end
  B.Say(ns.Locale:Get("shared.publicview.shared_bounties_board_receive_on_off_publish.18b928"))
end
