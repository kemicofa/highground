local new = dofile("../../tools/wowsim/runtime.lua")
local F = {}

function F.new(name, options)
  options = options or {}
  return (options.runtime or new)(options.client or "retail", options.settings or {}, function(s, e)
    s.addon = options.addon or "HighgroundReputation"
    s.otherAddons = options.others
    local base = s.addon == "HighgroundReputation" and "" or ("../" .. s.addon .. "/")
    s.manifest = base .. s.addon .. (options.client == "cata" and "_Cata" or "") .. ".toc"
    if base ~= "" then
      local loader = s.load
      s.load = function(self, path) return loader(self, path:sub(1, 3) == "../" and path or base .. path) end
    end
    s.units.player.name, s.units.player.guid, s.units.player.realm = name, "Player-1-" .. name:gsub("%s", ""), "Realm"
    e.HighgroundReputationNetworkDB = options.database
    e.GetBuildInfo = function() return "test", "1", "", options.build or (options.client == "cata" and 40402 or 120100) end
    e.GetCurrentRegion = function() return options.region or 1 end
    e.GetServerTime = function() return 1700000000 + math.floor(s.now) end
    e.GetNormalizedRealmName = function() return "Realm" end
    e.UnitNameUnmodified = e.UnitName
    e.JoinPermanentChannel = function(channel) s.channel = channel end
    e.LeaveChannelByName = function() s.channel = nil end
    e.GetChannelName = function(channel) return s.channel == channel and 1 or 0 end
    e.C_ChatInfo.InChatMessagingLockdown = function() return s.chatLocked or false end
    e.C_ChatInfo.AreOutgoingAddonChatMessagesRestricted = function() return s.addonLocked or false end
    e.C_ChatInfo.SendAddonMessage = function(prefix, message, channel, target)
      s.sent[#s.sent + 1] = { prefix = prefix, message = message, channel = channel, target = target }
      return s.sendResult or 0
    end
    e.SendChatMessage = function(message, channel, _, target)
      s.chat[#s.chat + 1] = { message = message, channel = channel, target = target }
    end
    s.menus = {}
    if not options.legacy then
      e.Menu = { ModifyMenu = function(tag, callback) s.menus[tag] = callback end }
    else
      e.Menu = nil
      e.UnitPopup_ShowMenu = function() end
      e.UIDropDownMenu_CreateInfo = function() return {} end
      e.UIDropDownMenu_AddButton = function(info) s.legacyMenu = info end
    end
    s.tipCallbacks = {}
    e.Enum = e.Enum or {}
    e.Enum.TooltipDataType = { Unit = 1 }
    e.TooltipDataProcessor = { AddTooltipPostCall = function(_, callback) s.tipCallbacks[#s.tipCallbacks + 1] = callback end }
    s.native = options.native or F.native(name)
    s.ruleset = options.ruleset or "PvE"
    e.Enum.GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
    e.C_GameRules = { IsGameRuleActive = function(rule)
      return rule == 1 and s.ruleset == "Hardcore" or rule == 2 and s.ruleset:find("RP", 1, true) ~= nil
        or rule == 3 and s.ruleset:find("PvP", 1, true) ~= nil
    end }
    e.Enum.ClubType = { BattleNet = 0, Character = 1, Guild = 2 }
    e.Enum.ClubRoleIdentifier = { Owner = 1, Leader = 2, Moderator = 3, Member = 4 }
    e.Enum.ClubMemberPresence = { Unknown = 0, Online = 1, OnlineMobile = 2, Offline = 3, Away = 4, Busy = 5 }
    e.C_Club = {
      IsEnabled = function() return not s.clubsDisabled end,
      GetSubscribedClubs = function()
        if s.clubsLoading then return nil end
        local clubs = {}
        for id, club in pairs(s.native) do
          if club.members[name .. "-Realm"] then clubs[#clubs + 1] = { clubId = id, name = club.name, clubType = club.type or 1 } end
        end
        return clubs
      end,
      GetMemberInfoForSelf = function(id) return s.native[id] and s.native[id].members[name .. "-Realm"] end,
      AreMembersReady = function() return not s.rosterLoading end,
      GetClubMembers = function(id)
        local members = {}; for _, info in pairs(s.native[id].members) do members[#members + 1] = info.memberId end; return members
      end,
      GetMemberInfo = function(id, who)
        for _, info in pairs(s.native[id].members) do if info.memberId == who then return info end end
      end,
    }
    if options.client == "cata" and not options.native then e.C_Club = nil end
    e.JoinPermanentChannel = function() error("Reputation must use native rosters, not a discovery channel") end
    if options.guild then
      s.guild, s.rank = options.guild, 0
      e.GetGuildInfo = function() return s.guild, "Guild Master", s.rank end
      e.GetNumGuildMembers = function() return #s.guildRoster end
      e.GetGuildRosterInfo = function(i) local r = s.guildRoster[i]; return r[1], "Rank", r[2], nil, nil, nil, nil, nil, true end
      s.guildRoster = { { name .. "-Realm", 0 }, { "Guildmember-Realm", 5 } }
    end
    if options.configure then options.configure(s, e) end
  end)
end

function F.W(s) return s.ns.Reputation end
function F.click(s, button)
  assert(button:IsEnabled(), "button is enabled")
  button.scripts.OnClick(button, "LeftButton")
  s:assertHealthy()
end
function F.target(s, name, guid) return assert(F.W(s).Target(name or "Enemy-Realm", nil, guid)) end
function F.native(name)
  local members, id = {}, 0
  for who, role in pairs({ [name .. "-Realm"] = 1, ["Member-Realm"] = 4, ["Moderator-Realm"] = 3 }) do
    id = id + 1
    members[who] = { name = who, role = role, memberId = id, presence = 1 }
  end
  return { [42] = { name = "Test community", members = members } }
end
function F.community(s)
  local org = s.env.C_Club and "club:42" or assert(s.ns.Organizations.Guild()).id
  return assert(F.W(s).Enable(org))
end

function F.deliver(sims, options)
  options = options or {}
  local packets = {}
  for _, source in ipairs(sims) do
    for i = (source.delivered or 0) + 1, #source.sent do packets[#packets + 1] = { source = source, packet = source.sent[i] } end
    source.delivered = #source.sent
  end
  if options.reverse then
    local reversed = {}
    for i = #packets, 1, -1 do reversed[#reversed + 1] = packets[i] end
    packets = reversed
  end
  for _, value in ipairs(packets) do
    local source, packet = value.source, value.packet
    options.seen = (options.seen or 0) + 1
    if not options.dropEvery or options.seen % options.dropEvery ~= 0 then
      for _, destination in ipairs(sims) do
        if source ~= destination and (packet.channel ~= "WHISPER" or packet.target == F.W(destination).Me()) then
          destination:event("CHAT_MSG_ADDON", packet.prefix, packet.message, packet.channel, F.W(source).Me(), "", 0, 1, "HighgroundReputation")
          if options.duplicate then destination:event("CHAT_MSG_ADDON", packet.prefix, packet.message, packet.channel, F.W(source).Me(), "", 0, 1, "HighgroundReputation") end
        end
      end
    end
  end
end

function F.pump(sims, seconds, options)
  options = options or {}
  for _ = 1, math.ceil(seconds / 0.2) do
    for _, sim in ipairs(sims) do sim:advance(0.2) end
    F.deliver(sims, options)
  end
end

function F.join(owner, member, c)
  local joined = assert(F.W(member).Enable(c.id))
  F.pump({ owner, member }, 60)
  assert(joined.synced, "native moderator snapshot verified")
  return joined
end

function F.chat(name, guid, message)
  return { message or "hello", name, "Common", "", "", "", 0, 0, "", 0, 101, guid or "", 0 }
end

return F
