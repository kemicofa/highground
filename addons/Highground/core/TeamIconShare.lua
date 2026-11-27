local _, ns = ...
local Core, Comms = ns.Core, ns.Comms
local Read, Call = ns.Util.read, ns.Util.call

---------------------------------------------------------------------------
-- Team icons go from the group leader to the group (prefix HighgroundG,
-- the party or raid channel of your own group). Only the leader sends, and
-- only outside a match: the game drops addon messages there. Members keep
-- what they received, so icons set before a battleground stay in it.
--   1:REV:I/N:RULE:key,icon,color;...  part I of N of the leader's change
--                                     REV (RULE "", "class" or "role")
--   R                                 a member asks for them (joined, reloaded)
-- Once all parts of a change from the current leader arrived, they replace
-- the member's icons. Older versions ignore the prefix.
---------------------------------------------------------------------------
Core.TEAM_ICON_PREFIX = "HighgroundG"
Core.TEAM_ICON_SEND_DELAY = 0.3 -- seconds: edits in a row go out together
Core.TEAM_ICON_RESEND = 5 -- seconds between sends for requests and newcomers
Core.TEAM_ICON_RETRY = 5 -- seconds between attempts while the game refuses
Core.TEAM_ICON_MAX_PARTS = 20
local BODY = 220 -- bytes of icons per message, below the 255-byte limit

local function After(delay, fn)
  if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else fn() end
end

local function Leader()
  return Read(UnitIsGroupLeader, "player", LE_PARTY_CATEGORY_HOME) == true
end

local function InMatch()
  local _, kind = Call(IsInInstance)
  return kind == "pvp" or kind == "arena"
end

-- Your own group's channel; nil outside a group.
local function Channel()
  if Read(IsInGroup, LE_PARTY_CATEGORY_HOME) ~= true then return end
  return Read(IsInRaid, LE_PARTY_CATEGORY_HOME) == true and "RAID" or "PARTY"
end

local function Key(name)
  local canon = ns.Network.Name(name)
  return canon and canon:lower()
end

-- The hand marks of current members, in message-sized parts.
local parts, list = {}, {}
local function Parts(marks)
  wipe(parts); wipe(list)
  local len = 0
  for key in pairs(Core.TeamIconMembers()) do
    local m = marks[key]
    if type(m) == "table" and Core.ValidTeamIcon(m.icon) then
      local token = key .. "," .. m.icon .. "," .. (tonumber(m.color) or 1)
      if len > 0 and len + #token + 1 > BODY then
        parts[#parts + 1] = table.concat(list, ";")
        wipe(list); len = 0
      end
      list[#list + 1], len = token, len + #token + 1
    end
  end
  parts[#parts + 1] = table.concat(list, ";")
  return parts
end

local scheduled, retrying, sentAt = false, false, -math.huge

local function Retry(fn)
  if retrying then return end
  retrying = true
  After(Core.TEAM_ICON_RETRY, function() retrying = false; fn() end)
end

-- Send the leader's icons now; while the game refuses, try again later.
local function SendNow()
  local channel = Core.db and Leader() and not InMatch() and Channel()
  if not channel then return end
  if Comms.Blocked() then return Retry(SendNow) end
  local rev, rule, marks = Core.TeamIconState()
  local all = Parts(marks)
  for i, body in ipairs(all) do
    local text = string.format("1:%d:%d/%d:%s:%s", rev, i, #all, rule or "", body)
    if not Comms.Send(Core.TEAM_ICON_PREFIX, text, channel) then return Retry(SendNow) end
  end
  sentAt = GetTime()
end

local function Schedule(delay)
  if scheduled then return end
  scheduled = true
  After(delay, function() scheduled = false; SendNow() end)
end

-- After a change by the leader (core/TeamIcons.lua).
function Core.ShareTeamIcons() Schedule(Core.TEAM_ICON_SEND_DELAY) end

-- For a member who asked or joined: the same icons again, at most once
-- per TEAM_ICON_RESEND seconds.
local function Resend()
  if not Leader() or InMatch() then return end
  Schedule(math.max(Core.TEAM_ICON_SEND_DELAY, sentAt + Core.TEAM_ICON_RESEND - GetTime()))
end

local requestedAt = -math.huge
-- A member arriving (joined, logged in, reloaded) asks the leader.
function Core.RequestTeamIcons()
  local channel = Core.db and not Leader() and not InMatch() and Channel()
  if not channel or Comms.Blocked() or GetTime() - requestedAt < Core.TEAM_ICON_RESEND then return end
  requestedAt = GetTime()
  Comms.Send(Core.TEAM_ICON_PREFIX, "R", channel)
end

-- The player key of the sender when they lead your group.
local function FromLeader(sender)
  local want = Key(sender)
  if not want then return end
  for key, unit in pairs(Core.TeamIconMembers()) do
    if Key(key) == want and Read(UnitIsGroupLeader, unit, LE_PARTY_CATEGORY_HOME) == true then return key end
  end
end

local incoming = { parts = {} }
function Core.ReceiveTeamIcons(text, channel, sender)
  if (channel ~= "PARTY" and channel ~= "RAID") or not Core.db or Core.IsMe(sender) then return end
  if text == "R" then return Resend() end
  local rev, i, n, rule, body = text:match("^1:(%d+):(%d+)/(%d+):(%l*):(.*)$")
  rev, i, n = tonumber(rev), tonumber(i), tonumber(n)
  if not (rev and i and n and i >= 1 and i <= n and n <= Core.TEAM_ICON_MAX_PARTS) or Leader() then return end
  local from = FromLeader(sender)
  if not from then return end
  if incoming.from ~= from or incoming.rev ~= rev or incoming.n ~= n then
    wipe(incoming.parts)
    incoming.from, incoming.rev, incoming.n = from, rev, n
  end
  incoming.parts[i] = body
  for k = 1, n do
    if not incoming.parts[k] then return end
  end
  local marks, now = {}, time()
  for k = 1, n do
    for token in incoming.parts[k]:gmatch("[^;]+") do
      local key, icon, color = token:match("^([^,]+),([^,]+),(%d+)$")
      key = key and ns.Network.Name(key)
      if key and Core.ValidTeamIcon(icon) then marks[key] = { icon = icon, color = tonumber(color), t = now } end
    end
  end
  wipe(incoming.parts)
  incoming.rev = nil
  Core.ReplaceTeamIcons(from, rule ~= "" and rule or nil, marks)
end

Comms.Listen(Core.TEAM_ICON_PREFIX, function(text, channel, sender)
  Core.ReceiveTeamIcons(text, ns.Util.value(channel), sender)
end, "team icons", "battlegrounds")

-- A bigger group holds members who haven't heard the icons yet.
local members = 0
ns.Util.Events({
  GROUP_ROSTER_UPDATE = function()
    local n = Read(GetNumGroupMembers, LE_PARTY_CATEGORY_HOME) or 0
    if n > members then Resend() end
    members = n
  end,
  GROUP_JOINED = function() After(2, Core.RequestTeamIcons) end,
  PLAYER_ENTERING_WORLD = function() After(3, Core.RequestTeamIcons) end,
}, "team icon sharing", "battlegrounds")
