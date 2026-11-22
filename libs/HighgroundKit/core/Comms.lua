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
