local _, ns = ...
if ns.STANDBY then return end
local P, U = ns.Protocols, ns.Util
local CHAT = "Highground capabilities "
local routes, routeCount, window, budget = {}, 0, 0, 0

function P.ClearRoutes()
  wipe(routes)
  routeCount, window, budget = 0, 0, 0
end

local function Matches(base, id, name)
  local channel = ns.Scope.Channel(base)
  local joined = channel and U.read(GetChannelName, channel)
  return type(joined) == "number" and joined > 0 and ns.Chat.MatchesChannel(channel, joined, id, name)
end

local function Channel(id, name)
  local peers, public = ns.Peers, ns.Bounty and ns.Bounty.Public
  return peers and peers.RealmEnabled() and Matches("HighgroundUsers", id, name)
    or public and public.Connected() and Matches("HighgroundBounties", id, name) or false
end

-- Called synchronously after accepted feature traffic. No queue, new channel,
-- request/reply exchange, or delay can outlive the original audience consent.
-- Announce at most once per route in 5-6 minutes and four times per 10 seconds.
function P.Sent(prefix, channel, target, chatFallback)
  if ns.STANDBY or not ns.Network.CanSend() then return end
  local feature
  for id in pairs(P.active) do if P.registry[id].prefix == prefix then feature = true; break end end
  if not feature then return end
  P.CheckScope()
  if channel == "WHISPER" then target = ns.Network.Name(target); if not target then return end
  elseif channel == "CHANNEL" then
    local id = tonumber(target)
    if not id or not Channel(id) then return end
    if chatFallback and (prefix ~= "HighgroundU" or ns.Caps.addonChannel) then return end
    if not chatFallback and not ns.Caps.addonChannel then return end
  elseif channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" and channel ~= "GUILD" then return end
  local now, key = GetTime(), channel .. ":" .. (target or "")
  for route, due in pairs(routes) do
    if now >= due then routes[route], routeCount = nil, routeCount - 1 end
  end
  if routes[key] or routeCount >= 128 then return end
  if now - window >= 10 then window, budget = now, 0 end
  if budget >= 4 then return end
  local text = P.Encode(prefix, chatFallback and 255 - #CHAT or 255)
  if not text then return end
  budget, routeCount = budget + 1, routeCount + 1
  routes[key] = now + 60 -- Rejected capability sends back off independently.
  local accepted
  if chatFallback then
    if not ns.Api.Fn("C_ChatInfo", "SendChatMessage") then return end
    accepted = ns.Api.SendChatMessage(CHAT .. text, "CHANNEL", nil, tonumber(target))
  else accepted = ns.Comms.Send(P.PREFIX, text, channel, target) end
  if accepted then routes[key] = now + 300 + math.random() * 60 end
end

local function Receive(text, channel, sender, _, _, id, name)
  if channel == "CHANNEL" then
    if not Channel(U.value(id), U.value(name)) then return end
  elseif channel ~= "WHISPER" and channel ~= "PARTY" and channel ~= "RAID"
    and channel ~= "INSTANCE_CHAT" and channel ~= "GUILD" then return end
  P.Observe(text, sender)
end
ns.Comms.Listen(P.PREFIX, Receive, "protocol capabilities")

if not ns.Caps.addonChannel then
  U.Events({ CHAT_MSG_CHANNEL = function(_, text, sender, _, _, _, _, _, id, name)
    if not U.plain(text) or type(text) ~= "string" or text:sub(1, #CHAT) ~= CHAT then return end
    Receive(text:sub(#CHAT + 1), "CHANNEL", sender, nil, nil, id, name)
  end }, "protocol capabilities")
  if ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", function(_, _, text, _, _, _, _, _, _, id, name)
      return U.plain(text) and type(text) == "string" and text:sub(1, #CHAT) == CHAT
        and Channel(U.value(id), U.value(name)) and P.Decode(text:sub(#CHAT + 1)) ~= nil or false
    end)
  end
end
U.Every(60, P.Prune, "protocol capabilities")
