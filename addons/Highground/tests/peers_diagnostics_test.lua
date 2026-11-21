local t = dofile("../../tools/harness.lua")("discovery diagnostics")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")

local function fixture(configure)
  return new("retail", nil, function(s, env)
    env.GetBuildInfo = function() return "1.60.1", "71037", "Nov 2026", 16001 end
    s.joins, s.sends, s.restricted, s.lockdown = 0, 0, true, false
    env.GetChannelName = function(name) return name == "HighgroundUsers" and (s.channelID or 0) or 0 end
    env.JoinTemporaryChannel = function()
      s.joins = s.joins + 1
      if s.joinError then error("private error detail") end
      if s.joinRejected then return false end
      if not s.joinBlocked then s.channelID = 8 end
    end
    env.C_ChatInfo.AreOutgoingAddonChatMessagesRestricted = function() return s.restricted end
    env.C_ChatInfo.InChatMessagingLockdown = function() return s.lockdown end
    env.C_ChatInfo.SendAddonMessage = function(prefix)
      if prefix == "HighgroundU" then s.sends = s.sends + 1 end
      return not s.rejectSend
    end
    function s:step(seconds) self.now = self.now + seconds; self.ns.Peers.Tick(); self:assertHealthy() end
    if configure then configure(s, env) end
  end)
end

local function contains(text, expected) assert(text:find(expected, 1, true), "Missing " .. expected .. " in:\n" .. text) end

t.test("Forever reports the actual restriction and both independent flags", function()
  local s = fixture()
  local P = s.ns.Peers
  t.equal(s.ns.GAME, "forever", "uses Forever capabilities")
  s.restricted, s.lockdown = true, true
  contains(P.Status(), "chat messaging lockdown is active")
  local report = P.Diagnostics()
  contains(report, "game: forever")
  contains(report, "build: 71037; interface: 16001")
  contains(report, "AreOutgoingAddonChatMessagesRestricted: true")
  contains(report, "InChatMessagingLockdown: true")
  contains(report, "blocking check: chat_lockdown")
  contains(report, "Outgoing restriction handling: advisory on this client")
  contains(report, "Join attempts: 0; last: never")
  s.restricted = false
  contains(P.Status(), "chat messaging lockdown is active")
  contains(P.Diagnostics(), "AreOutgoingAddonChatMessagesRestricted: false")
  s.env.C_ChatInfo = nil
  contains(P.Status(), "no addon-message sending API")
  contains(P.Diagnostics(), "blocking check: missing_api")
  contains(P.Diagnostics(), "InChatMessagingLockdown: unavailable")
  P.SetPreference("peerDiscovery", false)
  t.equal(P.Status(), "Detection is off.", "disabled preference takes precedence")
  t.equal(s.joins + s.sends, 0, "reading diagnostics never joins or sends")
end)

t.test("Forever joins and announces with the reported idle realm-policy flags", function()
  local s = fixture()
  local P = s.ns.Peers
  contains(P.Diagnostics(), "AreOutgoingAddonChatMessagesRestricted: true")
  contains(P.Diagnostics(), "InChatMessagingLockdown: false")
  contains(P.Diagnostics(), "InCombatLockdown: false; instance type: none")
  contains(P.Diagnostics(), "Can send: true; blocking check: none")
  s:step(30); s:step(30)
  t.equal(s.joins, 1, "realm-policy flag cannot suppress joining on Forever")
  t.equal(s.sends, 1, "normal announcement reaches the sending API")
  contains(P.Diagnostics(), "GetChannelName(HighgroundUsers): 8")
  contains(P.Diagnostics(), "route: CHANNEL; accepted by API: true")
  contains(P.Status(), "Detection active")
  s.lockdown = true
  s:step(600)
  t.equal(s.sends, 1, "active chat lockdown still prevents sending")
  contains(P.Status(), "chat messaging lockdown is active")
  s.lockdown = false
  s:step(15)
  t.equal(s.sends, 2, "pending announcement resumes when chat lockdown ends")
end)

t.test("a paused check cannot postpone the first real join by five minutes", function()
  local s = fixture(function(sim) sim.lockdown = true end)
  local P = s.ns.Peers
  s:step(30); s:step(330); s:step(330)
  t.equal(s.joins, 0, "no actual join while restricted")
  contains(P.ConnectionStatus(), "automatic joining is paused")
  contains(P.Diagnostics(), "Join attempts: 0")
  s.lockdown = false
  s:step(15)
  t.equal(s.joins, 1, "first tick after restrictions clear can join")
  contains(P.ConnectionStatus(), "joined channel 8")
  s:step(15)
  t.equal(s.joins, 1, "already connected does not rejoin")
end)

t.test("unconfirmed joins retain slow retry timing and channel notices", function()
  local s = fixture(function(sim) sim.joinBlocked = true end)
  local P = s.ns.Peers
  s:step(30)
  contains(P.ConnectionStatus(), "not joined; next join attempt in about")
  contains(P.Diagnostics(), "API result: no return value")
  for _ = 1, 19 do s:step(15) end
  t.equal(s.joins, 1, "a real failed join still waits at least five minutes")
  s:event("CHAT_MSG_CHANNEL_NOTICE", "WRONG_PASSWORD", "", "", "", "", "", 0, 0, P.CHANNEL)
  s:event("CHAT_MSG_CHANNEL_NOTICE", "BANNED", "", "", "", "", "", 0, 0, "General")
  s:event("CHAT_MSG_CHANNEL_NOTICE", { secret = true }, "", "", "", "", "", 0, 0, P.CHANNEL)
  contains(P.Diagnostics(), "Last channel notice: WRONG_PASSWORD")
  s:step(75)
  t.equal(s.joins, 2, "real failed attempts retry slowly")
  s.channelID, s.rejectSend = 8, true
  s:step(15); s:step(30)
  contains(P.Diagnostics(), "Announcement attempts: 1")
  contains(P.Diagnostics(), "route: CHANNEL; accepted by API: false")
end)

t.test("API errors, missing checks and unreadable values stay distinct from false", function()
  local s = fixture(function(sim, env)
    sim.joinError = true
    env.C_ChatInfo.AreOutgoingAddonChatMessagesRestricted = function() error("private error detail") end
    env.C_ChatInfo.InChatMessagingLockdown = function()
      return setmetatable({ secret = true }, { __tostring = function() error("must not stringify secret") end })
    end
    env.C_ChatInfo.IsAddonMessagePrefixRegistered = function() return nil end
  end)
  s:step(30)
  local report = s.ns.Peers.Diagnostics()
  contains(report, "AreOutgoingAddonChatMessagesRestricted: API error")
  contains(report, "InChatMessagingLockdown: unreadable")
  contains(report, "Prefix registered: unknown")
  contains(report, "Active channels: unavailable")
  contains(report, "API result: API error")
  assert(not report:find("private error detail", 1, true), "no arbitrary error contents in report")
  local rejected = fixture(function(sim) sim.joinRejected = true end)
  rejected:step(30)
  contains(rejected.ns.Peers.Diagnostics(), "API result: false")
end)

t.test("copy command and page show a fresh report without network side effects", function()
  local s = fixture(function(sim) dofile("../../tools/wowsim/geometry.lua")(sim); sim.lockdown = true end)
  s:command("users")
  local page = s.ns.Hub.users
  contains(page.status:GetText(), "chat messaging lockdown is active")
  contains(page.connection:GetText(), "automatic joining is paused")
  page.diagnostics:Click()
  local dialog = s.ns.Hub.usersDiagnostics
  assert(dialog:IsShown(), "copy report opens from the page")
  contains(dialog:GetText(), "blocking check: chat_lockdown")
  dialog:Hide()
  s.lockdown = false
  s:command("users why")
  t.equal(s.ns.Hub.usersDiagnostics, dialog, "copy window reused")
  contains(dialog:GetText(), "blocking check: none")
  t.equal(s.joins + s.sends, 0, "copying and refreshing never probe the network")
  dialog:Hide(); s:command("users")
  for _, scale in ipairs({ 1, 1.25, 1.5 }) do
    s.ns.Core.SetFontScale(scale)
    local line, button = s.bounds(page.connection), s.bounds(page.diagnostics)
    assert(line[2] + line[4] <= button[2], "connection text does not overlap copy button")
  end
  s:assertHealthy()
end)

t.finish("Discovery diagnostics: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
