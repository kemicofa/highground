local _, ns = ...
local B = ns.Bounty
local P = B.Public

function P.Tooltip(b)
  local lines = { { b.name, "gold" },
    { ns.Util.Gold(b.gold) .. " with recent available-funds reports / " .. ns.Util.Gold(b.pledgedGold) .. " pledged", "text", true },
    { "Each contribution expires separately. Payment is manual; funds are not reserved by the game.", "textMuted", true } }
  for _, p in ipairs(b.contributions) do
    lines[#lines + 1] = { ns.Util.Gold(p.gold) .. " from " .. p.by .. " · " .. P.Remaining(p.expiresAt)
      .. " · " .. P.FUND_LABELS[P.Funds(p)], "text", true }
  end
  return lines
end

function P.Fill(name, source)
  return B.Form.Open(name, "public", source)
end

function P.OpenDetails(name)
  for _, scope in ipairs({ "public", "mine", "guild" }) do
    for _, row in ipairs(B.BoardModel.Rows(scope)) do
      if B.Key(row.name) == B.Key(name) then return B.Details.Open(row) end
    end
  end
  B.Say("No active bounty on " .. tostring(name) .. ". Earlier reports are in Claims.")
end

function P.Command(text)
  local action, rest = (text or ""):match("^(%S*)%s*(.-)%s*$")
  if action == "" or action == "board" then B.Board.Open(); B.Board.SetTab("public"); return end
  if action == "sync" then local _, message = P.Sync(); B.Say(message); return end
  if action == "claims" then B.Ledger.Open(); return end
  if action == "receive" or action == "publish" then
    if rest ~= "on" and rest ~= "off" then return B.Say("Use " .. action .. " on or off.") end
    ns.Core.SetOption(action == "receive" and "bountyReceive" or "bountyPublish", rest == "on")
    P.TransportTick(); B.Say(P.NetworkStatus()); return
  end
  if action == "threshold" then
    local n = tonumber(rest)
    if not P.Integer(n, 0, 999999999) then return B.Say("Use a whole gold threshold from 0 to 999999999.") end
    ns.Core.SetOption("bountyMinGold", n); B.Say("Shared bounty alert minimum: " .. ns.Util.Gold(n)); return
  end
  if action == "add" then
    local gold, duration, who = rest:match("^(%d+)%s+(%d+[mhd])%s+(.+)$")
    if not who then return B.Say("Usage: " .. B.CMD .. " shared add GOLD DURATION NAME [; note] (example: 500 2h target)") end
    local name, note = who:match("^([^;]-)%s*;%s*(.*)$")
    name = (name or who):match("^%s*(.-)%s*$")
    if name:lower() == "target" then name = B.Board.TargetPlayer() end
    local p, err = P.Post(name, gold, duration, note)
    B.Say(p and ("Pledged " .. ns.Util.Gold(p.gold) .. " on " .. p.name .. " for " .. P.Remaining(p.expiresAt)) or err)
    return
  end
  if rest:lower() == "target" then rest = B.Board.TargetPlayer() or "" end
  if action == "claim" then local _, message = P.Claim(rest); B.Say(message); return end
  if action == "withdraw" then local _, message = P.Withdraw(P.Own(rest)); B.Say(message); return end
  B.Say("Shared bounties: board | receive on/off | publish on/off | threshold GOLD | add GOLD 2h NAME | claim NAME | withdraw NAME | claims | sync")
end
