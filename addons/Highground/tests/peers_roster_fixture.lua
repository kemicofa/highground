local new = dofile("../../tools/wowsim/battleground/runtime.lua")
return function(client, saved, configure)
  return new(client == "cata" and "cata" or "retail", saved or {}, function(s, e)
    if client == "forever" then
      e.GetBuildInfo = function() return "1.60.1", "71037", "Nov 2026", 16001 end
      e.Enum.GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
      e.C_GameRules = { IsGameRuleActive = function(rule) return rule == 1 and s.hardcore or false end }
    end
    s.channelNumber, s.channelIndex, s.selected = 8, 4, 2
    s.rows, s.rosterReads, s.displayReads, s.selections = { "Me-Realm", "Friend-Realm", "Silent-Realm" }, 0, 0, {}
    e.GetChannelName = function(name) return s.joined == name and s.channelNumber or 0 end
    e.JoinTemporaryChannel = function(name) s.joined = name end
    e.LeaveChannelByName = function(name) if s.joined == name then s.joined = nil end end
    e.GetNumDisplayChannels = function() return 5 end
    e.GetChannelDisplayInfo = function(index)
      s.displayReads = s.displayReads + 1
      if index == 2 then return "General", false, false, 1, 50, true end
      if index == s.channelIndex and s.joined then
        return s.displayName or s.joined, false, false, s.channelNumber, s.reportedCount or #s.rows, true
      end
      if index == 5 then return "Trade", false, false, 3, 60, true end
      return "Channels", true, false, 0, 0, true
    end
    e.GetSelectedDisplayChannel = function() return s.selected end
    e.SetSelectedDisplayChannel = function(index)
      s.selections[#s.selections + 1] = index
      if s.selectError then error("selection unavailable") end
      s.selected = index
      if s.autoReply and index == s.channelIndex then s:event("CHANNEL_ROSTER_UPDATE", index) end
    end
    local function Read(index, row)
      assert(index == s.channelIndex, "display index must differ from the send channel number")
      s.rosterReads = s.rosterReads + 1
      if s.readError then error("roster unavailable") end
      return s.rows[row]
    end
    if client == "cata" then e.GetChannelRosterInfo = Read else e.C_ChatInfo.GetChannelRosterInfo = Read end
    function s:tick(seconds)
      self.now = self.now + (seconds or 1)
      self.ns.Peers.Tick(); self.ns.Peers.Roster.Tick(); self:assertHealthy()
    end
    function s:reply(rows, count)
      if rows then self.rows = rows end
      self.reportedCount = count
      self:event("CHANNEL_ROSTER_UPDATE", self.channelIndex)
      self.now = self.now + 5
      self.ns.Peers.Roster.Tick(); self:assertHealthy()
    end
    function s:announce(name, channel)
      self:event("CHAT_MSG_ADDON", self.ns.Peers.PREFIX, "1|" .. self.ns.Scope.Social() .. "|" .. self.ns.Peers.Version(),
        channel or "CHANNEL", name, "", 0, self.channelNumber, self.joined)
    end
    if configure then configure(s, e) end
  end)
end
