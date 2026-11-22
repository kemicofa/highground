local _, ns = ...

-- Whether another player is plausibly online, for directed addon messages.
-- A whisper to an offline player prints "No player named ... is currently
-- playing", so features should retry only toward players seen recently.
-- Sources: Seen() (an addon message, channel hello or other observation
-- within WINDOW seconds), an online friend-list entry, native guild or
-- community presence, and feature sources added with AddSource(). Nothing is
-- saved; at most MAX names are remembered.
local Presence = { WINDOW = 600, MAX = 256 }
ns.Presence = Presence
local seen, sessions, count, listeners, sources = {}, {}, 0, {}, {}

local function Name(who)
  if type(who) ~= "string" or ns.Util.secret(who) or #who > 96 or who:find("[%c|,:;]") then return end
  return ns.Core.Canon(who:match("^%s*(.-)%s*$"))
end

-- Record activity from who (canonical or raw name). source is a short label
-- for listeners. Starts a new session after WINDOW seconds of silence.
function Presence.Seen(who, source)
  local name = Name(who)
  if not name or name == ns.Core.CanonUnit("player") then return end
  local now = GetTime()
  if not seen[name] then
    if count >= Presence.MAX then
      for other, at in pairs(seen) do
        if now - at > Presence.WINDOW then seen[other], sessions[other], count = nil, nil, count - 1 end
      end
      if count >= Presence.MAX then return end
    end
    count = count + 1
  end
  local returning = not seen[name] or now - seen[name] > Presence.WINDOW
  seen[name] = now
  if returning then
    sessions[name] = now
    for _, fn in ipairs(listeners) do ns.Util.Guard("presence", fn, name, source) end
  end
end

-- When who's current session started (GetTime), or 0 without one. Retry
-- budgets reset when this changes.
function Presence.Session(who)
  local name = Name(who)
  return name and sessions[name] or 0
end

function Presence.Recent(who)
  local name = Name(who)
  local at = name and seen[name]
  return at ~= nil and GetTime() - at <= Presence.WINDOW
end

-- A friend-list entry, which may omit the local realm.
local function Friend(name)
  local get = C_FriendList and C_FriendList.GetFriendInfo
  if type(get) ~= "function" then return false end
  local info = ns.Util.read(get, name)
  if type(info) ~= "table" then info = ns.Util.read(get, name:match("^[^-]+")) end
  return type(info) == "table" and ns.Util.value(info.connected) == true
end

-- Native presence in any shared guild or community, read live.
local function Roster(name)
  local O = ns.Organizations
  if not O then return false end
  for _, org in ipairs(O.List()) do
    local member = O.Member(org.id, name)
    if member and member.online then return true end
  end
  return false
end

function Presence.Online(who)
  local name = Name(who)
  if not name then return false end
  if Presence.Recent(name) or Friend(name) or Roster(name) then return true end
  for _, source in ipairs(sources) do if source(name) then return true end end
  return false
end

-- fn(name, source) runs when a player starts a new session (first seen, or
-- seen again after WINDOW seconds of silence).
function Presence.Listen(fn) listeners[#listeners + 1] = fn end

-- fn(name) returns true when a feature knows the player is online.
function Presence.AddSource(fn) sources[#sources + 1] = fn end

function Presence.Clear()
  wipe(seen); wipe(sessions); count = 0
end
