local _, ns = ...
local B, U = ns.Bounty, ns.Util
local P = B.Public
local function Notifications()
  B.Matches.Scan()
end

U.Events({
  PLAYER_LOGIN = function()
    P.Init()
    B.Scope.Check()
    B.Gold.Record()
    P.quietUntil = GetTime() + 12
    P.Prune()
    P.CheckFunds(true)
    P.TransportTick()
  end,
  PLAYER_MONEY = function() if P.ready then B.Gold.Refresh() end end,
  PLAYER_LOGOUT = function() B.Gold.Record() end,
  PLAYER_ENTERING_WORLD = function()
    if P.ready then B.Scope.Check(); B.Gold.Refresh(); P.nextHello = 0 end
  end,
  CHAT_MSG_CHANNEL = P.OnChannel,
}, "shared bounties", "bounties")

ns.Comms.Listen(P.PREFIX, P.OnAddon, "shared bounties", "bounties")
U.Every(1, function()
  if not P.ready then return end
  P.TransportTick()
  if GetTime() >= (P.nextPrune or 0) then P.nextPrune = GetTime() + 60; P.Prune() end
  Notifications()
  if B.Details then B.Details.Refresh() end
end, "shared bounties", "bounties")

B.Listen("publicChanged", function()
  P.cache = nil
  B.Emit("updated")
end)
