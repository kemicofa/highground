local _, ns = ...
local B, U = ns.Bounty, ns.Util
local P = B.Public
local alerts = {}

local function Notifications()
  if not P.Receiving() or not B.Enabled() then return end
  local now, present = GetTime(), {}
  for _, b in ipairs(P.All()) do
    local key = B.Key(b.name)
    present[key] = true
    local a = alerts[key] or { above = false, last = -math.huge }
    local above = b.gold > 0 and b.gold >= (ns.Core.O("bountyMinGold") or 0)
    if above and not a.above and now >= (P.quietUntil or 0) and now - a.last >= 120 then
      a.last = now
      if not (ns.NearbyHistory and ns.NearbyHistory.Muted(b.name)) then
        B.AnnounceShared(b)
      end
    end
    a.above = above; alerts[key] = a
  end
  for key, a in pairs(alerts) do
    if not present[key] then a.above = false; if now - a.last > 3600 then alerts[key] = nil end end
  end
end

U.Events({
  PLAYER_LOGIN = function()
    P.Init()
    P.quietUntil = GetTime() + 12
    P.Prune()
    P.CheckFunds(true)
    P.TransportTick()
  end,
  PLAYER_MONEY = function() if P.ready then P.CheckFunds(false) end end,
  PLAYER_ENTERING_WORLD = function() if P.ready then P.nextHello = 0 end end,
  CHAT_MSG_CHANNEL = P.OnChannel,
}, "shared bounties")

ns.Comms.Listen(P.PREFIX, P.OnAddon, "shared bounties")
U.Every(1, function()
  if not P.ready then return end
  P.TransportTick()
  if GetTime() >= (P.nextPrune or 0) then P.nextPrune = GetTime() + 60; P.Prune() end
  Notifications()
  if B.Details then B.Details.Refresh() end
end, "shared bounties")

B.Listen("publicChanged", function()
  P.cache = nil
  B.Emit("updated")
end)
