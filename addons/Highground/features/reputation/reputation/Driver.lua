local addon, ns = ...
local W, U = ns.Reputation, ns.Util
local function Start()
  if not W.Init() then return end
  W.Reconcile()
  W.InstallFilters(); W.InstallMenus(); W.InstallTooltip()
end
ns.Comms.Listen(W.PREFIX, W.ReceiveWire, "reputation sync", "reputation")
U.Events({
  ADDON_LOADED = function(_, name)
    if name == addon then Start() elseif W.ready then W.InstallMenus(); W.InstallTooltip() end
  end,
  PLAYER_LOGIN = function() Start(); W.nextSync = GetTime() + 5 + math.random() * 5 end,
  PLAYER_ENTERING_WORLD = function() W.nextSync = GetTime() + 5 + math.random() * 5 end,
  CHAT_MSG_WHISPER = W.OnWhisper,
}, "reputation", "reputation")
U.Every(0.2, W.Tick, "reputation sync", "reputation")
if ns.Commands then
  ns.Commands.reputation = function(_, msg) W.Command((msg or ""):match("^%S+%s*(.-)$") or "") end
end
