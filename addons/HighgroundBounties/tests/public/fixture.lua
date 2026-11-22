local new = dofile("../../tools/wowsim/runtime.lua")
local F = {}

function F.new(name, options)
  options = options or {}
  local saved = options.saved or { bountyReceive = true, bountyPublish = true }
  return (options.runtime or new)(options.client or "retail", saved, function(s, e)
    s.addon = options.addon or "HighgroundBounties"
    local base, loader = "../" .. s.addon .. "/", s.load
    s.manifest = base .. s.addon .. (options.client == "cata" and "_Cata" or "") .. ".toc"
    s.load = function(self, path) return loader(self, path:sub(1, 3) == "../" and path or base .. path) end
    s.units.player.name, s.units.player.guid = name, "Player-1-" .. name
    s.guild, s.rank, s.roster = options.guild, options.rank or 5, options.roster or {}
    s.money, s.epoch = (options.gold or 10000) * 10000, options.epoch or 100000
    e.HighgroundBountyNetworkDB = options.network
    e.GetMoney = function() return s.money end
    e.GetServerTime = function() return math.floor(s.epoch + s.now) end
    e.time = e.GetServerTime -- Both APIs report epoch seconds, not uptime.
    e.GetBuildInfo = function() return "test", "1", "", options.client == "cata" and 40402 or options.build or 120100 end
    e.GetNormalizedRealmName = function() return options.realm or "Realm" end
    s.units.player.realm = options.realm or "Realm"
    s.joins, s.leaves, s.swaps, s.channels = 0, 0, 0, options.channels or {}
    local function Number(channel)
      for n, c in pairs(s.channels) do if c == channel then return n end end
    end
    e.JoinPermanentChannel = function(channel)
      local n = 1
      while s.channels[n] do n = n + 1 end
      s.channels[n], s.channel, s.joins = channel, channel, s.joins + 1
    end
    e.LeaveChannelByName = function(channel)
      local n = Number(channel)
      if n then s.channels[n] = nil end
      s.channel, s.leaves = nil, s.leaves + 1
    end
    e.GetChannelName = function(channel) return Number(channel) or 0 end
    e.GetChannelList = function()
      local list = {}
      for n = 1, table.maxn(s.channels) do
        if s.channels[n] then list[#list + 1], list[#list + 2], list[#list + 3] = n, s.channels[n], false end
      end
      return unpack(list)
    end
    e.C_ChatInfo.SwapChatChannelsByChannelIndex = function(a, b)
      s.swaps = s.swaps + 1
      if not s.ignoreSwaps then s.channels[a], s.channels[b] = s.channels[b], s.channels[a] end
    end
    e.SendChatMessage = function(text, channel, _, target)
      s.chat[#s.chat + 1] = { text = text, channel = channel, target = target }
    end
    local wireErrors = {}
    s.checks[#s.checks + 1] = function() return wireErrors end
    e.C_ChatInfo.SendAddonMessage = function(prefix, text, channel, target)
      if type(prefix) ~= "string" or #prefix > 16 or type(text) ~= "string" or #text > 255 or text:find("%z") then
        wireErrors[#wireErrors + 1] = "invalid addon prefix or payload"
        return false
      end
      s.sent[#s.sent + 1] = { prefix = prefix, message = text, channel = channel, target = target,
        accepted = s.sendResult == nil or s.sendResult == 0 or s.sendResult == true }
      if s.sendResult ~= nil then return s.sendResult end
      return 0
    end
  end)
end

function F.P(sim) return sim.ns.Bounty.Public end
function F.post(sim, name, gold, duration)
  return assert(F.P(sim).Post(name or "Enemy-Realm", gold or 500, duration or "2h"))
end

function F.flush(sim)
  local p, packets, start = F.P(sim), {}, #sim.sent
  for _ = 1, 500 do if #p.outbox == 0 then break end; p.Flush() end
  assert(#p.outbox == 0, "queue drained")
  sim:assertHealthy()
  for i = start + 1, #sim.sent do packets[#packets + 1] = sim.sent[i] end
  return packets
end

function F.deliver(from, to, packets)
  local recipient = to.ns.GAME == "forever" and to.units.player.name or to.ns.Bounty.Me()
  for _, packet in ipairs(packets or F.flush(from)) do
    if packet.accepted ~= false and (packet.channel ~= "WHISPER" or packet.target == recipient)
      and (packet.channel ~= "GUILD" or from.guild and from.guild == to.guild) then
      to:event("CHAT_MSG_ADDON", packet.prefix, packet.message, packet.channel, from.ns.Bounty.Me(), "", 0, 1, F.P(to).CHANNEL)
    end
  end
end

function F.count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
function F.claim(sim) for _, c in pairs(F.P(sim).Data().claims) do return c end end
function F.said(sim, text)
  local n = 0
  for _, m in ipairs(sim.messages) do if m:find(text, 1, true) then n = n + 1 end end
  return n
end
return F
