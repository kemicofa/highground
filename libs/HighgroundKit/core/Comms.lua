local _, ns = ...

---------------------------------------------------------------------------
-- Addon messages: the group channel, protected sends and one shared
-- CHAT_MSG_ADDON frame that hands each message to its prefix's listener.
-- Prefixes in use (wire formats live with their modules):
--   HighgroundC  capture probes   core/CapShare.lua
--   HighgroundS  spec tags        core/SpecTags.lua
--   HighgroundT  timers           timers/Sharing.lua
--   HighgroundI  map intel        map/Sharing.lua
--   HighgroundB  guild bounties   bounty/Sync.lua
--   HighgroundBP bounty transport bounty/PublicWire.lua
--   HighgroundD  death reports    bounty/SuggestionSync.lua
--   HighgroundRep reputation     reputation/State.lua and Wire.lua (feature)
--   HighgroundP  setup profiles   options/ProfileSharing.lua (Highground)
--   HighgroundN  capabilities     core/Protocols.lua and ProtocolTransport.lua
-- Each prefix registers with the client once, on PLAYER_LOGIN (or at
-- once when already logged in). Queues and throttling live in core/Network
-- or the feature-specific transport.
---------------------------------------------------------------------------
local Util = ns.Util
local Comms = {}
ns.Comms = Comms

-- The group's chat channel: instance group first, then raid, then party.
-- nil when not in a group.
function Comms.GroupChannel()
  if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    return "INSTANCE_CHAT"
  elseif IsInRaid and IsInRaid() then
    return "RAID"
  elseif IsInGroup and IsInGroup() then
    return "PARTY"
  end
end

-- True when the client can send addon messages.
function Comms.CanSend()
  return C_ChatInfo ~= nil and C_ChatInfo.SendAddonMessage ~= nil
end

-- Why the game would refuse an addon message now, or nil. Chat lockdown
-- blocks every send. Forever reports outgoing messages restricted even when
-- they send, so that flag counts only on other games.
function Comms.Blocked()
  if not C_ChatInfo then return end
  if not (ns.Caps and ns.Caps.addonRestrictionAdvisory)
    and Util.read(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) then return "outgoing_restricted" end
  if Util.read(C_ChatInfo.InChatMessagingLockdown) then return "chat_lockdown" end
end

-- Status suffix counting messages the game refused, or "" for none.
function Comms.RefusedNote(count)
  if not count or count <= 0 then return "" end
  return ns.Locale:Format("battlegrounds.sharing.refused", { count = string.format("%d", count) })
end

-- An addon whisper to an offline player prints "No player named ... is
-- currently playing." Hide that notice only when the latest whisper to that
-- name, within the last few seconds, was an addon message; the notice for
-- the player's own whisper stays.
Comms.NOTICE_SECONDS = 5
local addon, manual, count, notice, installed = {}, {}, 0, nil, false
local function Mark(store, recipient)
  local now = GetTime()
  if count >= 64 then
    count = 0
    for _, t in ipairs({ addon, manual }) do
      for key, at in pairs(t) do
        if now - at > Comms.NOTICE_SECONDS then t[key] = nil else count = count + 1 end
      end
    end
  end
  -- The notice may name the full address or just the character.
  for i = 1, 2 do
    local key = (i == 1 and recipient or recipient:match("^[^-]+") or recipient):lower()
    if not store[key] then count = count + 1 end
    store[key] = now
  end
end
local function Manual(_, chatType, _, target)
  if chatType == "WHISPER" and type(target) == "string" and not Util.secret(target) then Mark(manual, target) end
end
local function Install()
  -- Installed with the first addon whisper; standby hosts never send.
  local add = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
  if type(add) ~= "function" or type(GetTime) ~= "function" then return false end
  installed = true
  add("CHAT_MSG_SYSTEM", Comms.HideNotice)
  if type(hooksecurefunc) == "function" then
    if type(SendChatMessage) == "function" then hooksecurefunc("SendChatMessage", Manual) end
    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then hooksecurefunc(C_ChatInfo, "SendChatMessage", Manual) end
  end
  return true
end
function Comms.HideNotice(_, _, text)
  if type(text) ~= "string" or Util.secret(text) or type(ERR_CHAT_PLAYER_NOT_FOUND_S) ~= "string" then return false end
  if not notice then
    local escaped = ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    notice = "^" .. (escaped:gsub("%%%%s", "(.+)")) .. "$"
  end
  local name = text:match(notice)
  local key = name and name:lower()
  local at = key and addon[key]
  return at ~= nil and GetTime() - at <= Comms.NOTICE_SECONDS and not (manual[key] and manual[key] > at)
end

-- Send text under prefix on channel (target for WHISPER). Return whether
-- the game accepted it, and its native result; queueing and retries belong to the caller. Clients
-- return nothing, a boolean, an enum (0 = success), or a second result.
function Comms.Send(prefix, text, channel, target)
  if ns.STANDBY or not (channel and Comms.CanSend()) then return false end
  -- Forever accepts First Surname, not our internal Name-Ruleset identity.
  -- Keep the canonical target for protocol callbacks and peer throttling.
  local recipient = target
  if channel == "WHISPER" and ns.Caps and ns.Caps.rulesetRealms and type(target) == "string" then
    recipient = target:match("^[^-]+")
  end
  if channel == "WHISPER" and type(recipient) == "string" and (installed or Install()) then Mark(addon, recipient) end
  local ok, result, second = pcall(C_ChatInfo.SendAddonMessage, prefix, text, channel, recipient)
  if second ~= nil then result = second end
  local accepted = ok and (result == nil or result == true or result == 0)
  if accepted and ns.Protocols and ns.Protocols.Sent then
    Util.Guard("protocol announcement", ns.Protocols.Sent, prefix, channel, target)
  end
  -- The native result tells callers to wait (throttled) or give up.
  return accepted, ok and result or nil
end

local listeners = {} -- [prefix] = { fn, stage }
local registered = {} -- [prefix] = true once the client knows it
local loggedIn = false

local function Register(prefix)
  if registered[prefix] or not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) then return end
  registered[prefix] = pcall(C_ChatInfo.RegisterAddonMessagePrefix, prefix) or nil
end

-- Call fn(text, channel, sender) for each string message under prefix,
-- guarded under stage (default the prefix). One listener per prefix.
-- On standby (ns.STANDBY) Highground listens instead.
function Comms.Listen(prefix, fn, stage, module)
  if not Util.ModuleEnabled(module) then return end
  assert(not listeners[prefix], "Comms.Listen: " .. tostring(prefix) .. " already has a listener")
  listeners[prefix] = { fn = fn, stage = stage or prefix }
  if ns.Protocols then ns.Protocols.Activate(prefix) end
  if loggedIn or (IsLoggedIn and IsLoggedIn()) then Register(prefix) end
end

-- Every addon's messages arrive here, often many per second in groups:
-- filter by prefix before any guard; only our listeners run guarded.
local frame = CreateFrame("Frame")
frame.handlers = {
  PLAYER_LOGIN = function()
    loggedIn = true
    for prefix in pairs(listeners) do Register(prefix) end
  end,
  CHAT_MSG_ADDON = function(_, prefix, text, channel, sender, ...)
    local l = listeners[prefix]
    if l and type(text) == "string" then Util.Guard(l.stage, l.fn, text, channel, sender, ...) end
  end,
}
if not ns.STANDBY then
  for event in pairs(frame.handlers) do pcall(frame.RegisterEvent, frame, event) end
end
frame:SetScript("OnEvent", function(self, event, ...)
  if event == "CHAT_MSG_ADDON" then return self.handlers.CHAT_MSG_ADDON(event, ...) end
  Util.Guard("comms", self.handlers[event], event, ...)
end)
Comms.frame = frame
