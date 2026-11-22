local _, ns = ...
local P, U = ns.Peers, ns.Util
local R = { TTL = 360, requests = 0, scans = 0, nextRequest = 0, nextBackground = 0, nextScan = 0 }
P.Roster = R
local MAX_CHANNELS, REQUEST_GAP, BACKGROUND_GAP, SCAN_GAP = 64, 30, 300, 5
local members, scratch, ticker = {}, {}

local function Wake()
  if R.awake then return end
  R.awake = true
  ticker.Start()
end
local function Sleep()
  R.awake = nil
  if ticker then ticker.Stop() end
end
local function SleepIfIdle()
  if not R.pending and not R.dirty and not R.mappingDirty then Sleep() end
end

local function Integer(value, minimum, maximum)
  return U.plain(value) and type(value) == "number" and value >= minimum
    and value <= maximum and value == math.floor(value)
end

-- These are display indexes, not the /1, /2 channel numbers used to send.
local function Info(index)
  local name, header, _, number, count = U.call(GetChannelDisplayInfo, index)
  if not U.plain(name) or type(name) ~= "string" or #name > 128 or U.value(header) ~= false
    or not Integer(number, 1, 100) then return end
  return name, number, U.value(count)
end

local function Matches(index, channel, number)
  local name, id = Info(index)
  return name and name:lower() == channel:lower() and id == number
end

local function Find(channel, number)
  local count = U.read(GetNumDisplayChannels)
  if not Integer(count, 1, MAX_CHANNELS) then return end
  for index = 1, count do
    if Matches(index, channel, number) then return index end
  end
end

local function NativeVisible()
  return ChannelFrame and ChannelFrame:IsVisible() or CommunitiesFrame and CommunitiesFrame:IsVisible()
end

local function Blocked()
  local combat = U.call(InCombatLockdown)
  local lockdown = U.call(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)
  return U.secret(combat) or U.secret(lockdown) or combat == true or lockdown == true
end

local function Reader()
  return C_ChatInfo and C_ChatInfo.GetChannelRosterInfo or GetChannelRosterInfo
end

local function Finish()
  local attempt = R.pending
  R.pending = nil
  if not attempt or attempt.previous == attempt.index or NativeVisible()
    or U.read(GetSelectedDisplayChannel) ~= attempt.index
    or not Matches(attempt.index, attempt.channel, attempt.number) then return end
  -- Do not overwrite a selection changed by the player or another addon.
  local previous = attempt.previous == 0 and 0 or Find(attempt.previousName, attempt.previousNumber)
  if previous then U.call(SetSelectedDisplayChannel, previous) end
end

function R.Reset()
  Finish()
  R.channel, R.number, R.index, R.snapshot, R.dirty, R.status, R.oversized = nil, nil, nil, nil, nil, nil, nil
  R.mappingDirty = nil
  R.nextBackground, R.nextScan = 0, 0
  wipe(members); wipe(scratch)
  Sleep()
end

local function Sync()
  local channel = P.RealmEnabled() and P.CHANNEL or nil
  local number = channel and P.ChannelID()
  if channel ~= R.channel or number ~= R.number then
    R.Reset()
    R.channel, R.number = channel, number
  end
  return number ~= nil and P.me ~= nil
end

function R.Snapshot()
  local data = R.snapshot
  if data and P.RealmEnabled() and R.channel == P.CHANNEL and R.number == P.ChannelID()
    and GetTime() - data.at < R.TTL then return data end
end

-- Publish only a complete, unique, bounded snapshot containing ourselves.
-- Zero, missing rows, secrets and oversized rosters never evict known peers.
local function Read()
  R.scans, R.nextScan = R.scans + 1, GetTime() + SCAN_GAP
  if not Matches(R.index, R.channel, R.number) then
    R.status, R.snapshot = "changed", nil
    R.nextBackground = 0
    Finish(); R.index = nil
    return
  end
  local _, _, count = Info(R.index)
  R.oversized = Integer(count, P.LIMIT + 2, 1000000) or nil
  if not Integer(count, 1, P.LIMIT + 1) then R.status = R.oversized and "limit" or "incomplete"; return end
  wipe(scratch)
  for row = 1, count do
    local key = P.Key(U.read(Reader(), R.index, row))
    if not key or scratch[key] then R.status = "incomplete"; return end
    scratch[key] = true
  end
  if not scratch[P.me] then R.status = "incomplete"; return end
  members, scratch = scratch, members
  R.snapshot = { members = members, count = count, at = GetTime(),
    cutoff = R.pending and R.pending.started or GetTime() }
  R.status = "ready"
  Finish()
end

function R.Tick()
  if not Sync() then Sleep(); return end
  local now, attempt = GetTime(), R.pending
  if R.mappingDirty then
    R.mappingDirty = nil
    if R.index and not Matches(R.index, R.channel, R.number) then
      R.Reset(); return
    end
  end
  if attempt and (Blocked() or NativeVisible() or U.read(GetSelectedDisplayChannel) ~= attempt.index) then
    R.status, R.dirty = "busy", nil
    Finish()
  elseif R.dirty and now >= R.nextScan then
    R.dirty = nil
    Read()
  end
  if R.pending and now >= R.pending.deadline then
    R.status = R.status == "waiting" and "timeout" or R.status
    Finish()
  end
  SleepIfIdle()
end

function R.Request(explicit)
  if not Sync() or R.pending then return end
  local now = GetTime()
  if now < R.nextRequest or not explicit and now < R.nextBackground then return end
  if Blocked() or NativeVisible() then R.status = "busy"; return end
  if type(Reader()) ~= "function" or type(SetSelectedDisplayChannel) ~= "function"
    or type(GetSelectedDisplayChannel) ~= "function" then
    R.status, R.nextBackground = "unavailable", now + BACKGROUND_GAP
    return
  end
  local index = Find(R.channel, R.number)
  local previous = U.read(GetSelectedDisplayChannel)
  if not index or not Integer(previous, 0, MAX_CHANNELS) then
    R.status, R.nextBackground = "unavailable", now + BACKGROUND_GAP
    return
  end
  local previousName, previousNumber
  if previous > 0 then
    previousName, previousNumber = Info(previous)
    if not previousName then R.status = "unavailable"; return end
  end
  R.index, R.status, R.dirty = index, "waiting", nil
  R.pending = { index = index, channel = R.channel, number = R.number, previous = previous,
    previousName = previousName, previousNumber = previousNumber, started = now, deadline = now + 6 }
  R.requests = R.requests + 1
  R.nextRequest, R.nextBackground = now + REQUEST_GAP, now + BACKGROUND_GAP
  Wake()
  local ok, result = pcall(SetSelectedDisplayChannel, index)
  if not ok or U.secret(result) or result == false then
    R.status, R.dirty = "unavailable", nil
    Finish(); SleepIfIdle()
  end
end

local descriptions = ns.Localization.Define({
  waiting = ns.Locale:Get("highground.peerroster.waiting_for_the_channel_member_list.97e92d"), incomplete = ns.Locale:Get("highground.peerroster.channel_member_list_is_incomplete.72e21d"),
  unavailable = ns.Locale:Get("highground.peerroster.channel_member_list_is_unavailable.5a82a7"), timeout = ns.Locale:Get("highground.peerroster.channel_member_list_did_not_arrive.a0a3e9"),
  busy = ns.Locale:Get("highground.peerroster.channel_member_refresh_is_paused_while_chat.279b2f"),
  changed = ns.Locale:Get("highground.peerroster.channel_membership_changed.98e145"), limit = ns.Locale:Get("highground.peerroster.channel_member_list_exceeds_the_tracking_limit.b61fd8"),
}, { waiting = "highground.peerroster.waiting_for_the_channel_member_list.97e92d", incomplete = "highground.peerroster.channel_member_list_is_incomplete.72e21d", unavailable = "highground.peerroster.channel_member_list_is_unavailable.5a82a7", timeout = "highground.peerroster.channel_member_list_did_not_arrive.a0a3e9", busy = "highground.peerroster.channel_member_refresh_is_paused_while_chat.279b2f", changed = "highground.peerroster.channel_membership_changed.98e145", limit = "highground.peerroster.channel_member_list_exceeds_the_tracking_limit.b61fd8" })
function R.Status()
  if not P.RealmEnabled() then return ns.Locale:Get("highground.peerroster.channel_member_discovery_is_off.566265") end
  if not P.ChannelID() then return ns.Locale:Get("highground.peerroster.channel_member_discovery_is_waiting_for_a.fdf25e") end
  local data = R.Snapshot()
  if R.status == "ready" and data then
    return ns.Locale:Format("highground.peerroster.data_count_channel_members_in_the_last.21eb27", { data_count = data.count })
  end
  return (descriptions[R.status] or ns.Locale:Get("highground.peerroster.channel_member_list_needs_a_refresh.87da28"))
    .. (data and ns.Locale:Get("highground.peerroster.keeping_the_last_complete_list.8bc8da") or ns.Locale:Get("highground.peerroster.using_recent_announcements.bdade4"))
end

function R.Diagnostics()
  local data = R.Snapshot()
  return ns.Locale:Format("highground.peerroster.channel_roster_value2_requests_r_requests_scans.f83470", { value2 = (R.status or "idle"), R_requests = R.requests, R_scans = R.scans, value8 = (data and data.count or "unknown"), value10 = (data and (math.floor(GetTime() - data.at) .. "s") or "unknown") })
end

local function Changed(_, index)
  if U.value(index) ~= R.index or not R.index or not P.RealmEnabled() then return end
  R.dirty = true
  Wake()
end
U.Events({ CHANNEL_ROSTER_UPDATE = Changed, CHANNEL_COUNT_UPDATE = Changed,
  CHANNEL_UI_UPDATE = function()
    if R.index and not R.mappingDirty then R.mappingDirty = true; Wake() end
  end,
}, "addon user roster")
ticker = U.Every(1, R.Tick, "addon user roster")
ticker.Stop()
