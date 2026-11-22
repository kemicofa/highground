local _, ns = ...

---------------------------------------------------------------------------
-- Addon messages: the group channel, protected sends and one shared
-- CHAT_MSG_ADDON frame that hands each message to its prefix's listener.
-- Prefixes in use (wire formats live with their modules):
--   HighgroundC  capture probes   core/CapShare.lua
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

-- An addon whisper to an offline player prints "No player named ... is
-- currently playing." Hide that notice only for names an addon message was
-- whispered to in the last few seconds; the player's own whispers keep it.
Comms.NOTICE_SECONDS = 5
local whispered, whisperedCount, notice = {}, 0, nil
local function Mark(key, now)
  if not whispered[key] then whisperedCount = whisperedCount + 1 end
  whispered[key] = now
end
local installed
local function Whispered(recipient)
  if not installed then
    -- Installed with the first addon whisper; standby hosts never send.
    local add = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
    if type(add) ~= "function" or type(GetTime) ~= "function" then return end
    installed = true
    add("CHAT_MSG_SYSTEM", Comms.HideNotice)
  end
  local now = GetTime()
  if whisperedCount >= 64 then
    for key, at in pairs(whispered) do
      if now - at > Comms.NOTICE_SECONDS then whispered[key], whisperedCount = nil, whisperedCount - 1 end
    end
  end
  -- The notice may name the full address or just the character.
  Mark(recipient:lower(), now)
  Mark((recipient:match("^[^-]+") or recipient):lower(), now)
end
function Comms.HideNotice(_, _, text)
  if type(text) ~= "string" or Util.secret(text) or type(ERR_CHAT_PLAYER_NOT_FOUND_S) ~= "string" then return false end
  if not notice then
    local escaped = ERR_CHAT_PLAYER_NOT_FOUND_S:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    notice = "^" .. (escaped:gsub("%%%%s", "(.+)")) .. "$"
  end
  local name = text:match(notice)
  local at = name and whispered[name:lower()]
  return at ~= nil and GetTime() - at <= Comms.NOTICE_SECONDS
end

-- Send text under prefix on channel (target for WHISPER). Return whether
-- the game accepted it; queueing and retries belong to the caller. Clients
-- return nothing, a boolean, an enum (0 = success), or a second result.
function Comms.Send(prefix, text, channel, target)
  if ns.STANDBY or not (channel and Comms.CanSend()) then return false end
  -- Forever accepts First Surname, not our internal Name-Ruleset identity.
  -- Keep the canonical target for protocol callbacks and peer throttling.
  local recipient = target
  if channel == "WHISPER" and ns.Caps and ns.Caps.rulesetRealms and type(target) == "string" then
    recipient = target:match("^[^-]+")
  end
  if channel == "WHISPER" and type(recipient) == "string" then Whispered(recipient) end
  local ok, result, second = pcall(C_ChatInfo.SendAddonMessage, prefix, text, channel, recipient)
  if second ~= nil then result = second end
  local accepted = ok and (result == nil or result == true or result == 0)
  if accepted and ns.Protocols and ns.Protocols.Sent then
    Util.Guard("protocol announcement", ns.Protocols.Sent, prefix, channel, target)
  end
  return accepted
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

Comms.frame = Util.Events({
  PLAYER_LOGIN = function()
    loggedIn = true
    for prefix in pairs(listeners) do Register(prefix) end
  end,
  -- Every addon's messages arrive here: filter by prefix before guarding.
  CHAT_MSG_ADDON = function(_, prefix, text, channel, sender, ...)
    local l = listeners[prefix]
    if l and type(text) == "string" then Util.Guard(l.stage, l.fn, text, channel, sender, ...) end
  end,
}, "comms")
