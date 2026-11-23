local _, ns = ...
local Core, U = ns.Core, ns.Util

---------------------------------------------------------------------------
-- Battleground profiler (/hg bg profiler start|stop): records what happens
-- in a battleground and what Highground made of it, for scripts/bg_profile.py.
-- Started outside a battleground it waits for the next one. Leaving the
-- battleground stops it and offers a reload: WoW writes
-- HighgroundDB.bgProfiles to disk only on /reload or logout.
-- Rows are "<seconds since start> <kind> <text>". This file owns sessions,
-- chat, match and your own death; core/ProfilerProbes.lua adds polled state
-- and hooks into the timers. Nothing is registered while it is off.
---------------------------------------------------------------------------
local P = { VERSION = 1, KEEP = 3, MAX_ROWS = 4000, MAX_TEXT = 300, MAX_ERRORS = 30, MAX_STAGES = 63, MAX_AGE = 4 * 3600 }
ns.Profiler = P
local session -- the open recording; also HighgroundDB.bgProfiles[1]

local function InBattleground()
  return select(2, IsInInstance()) == "pvp"
end

local function Instance()
  local name, _, _, _, _, _, _, inst = GetInstanceInfo()
  return U.value(name), U.value(inst)
end

-- Row text: no colour, texture or link codes, one line, bounded.
function P.Clean(text)
  text = U.value(text)
  if text == nil then return "?" end
  text = tostring(text):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    :gsub("|H.-|h(.-)|h", "%1"):gsub("[\r\n]+", " ")
  return (text:sub(1, P.MAX_TEXT))
end

function P.Session() return session end
function P.Recording() return session ~= nil end
function P.Armed() return Core.db and Core.db.bgProfilerOn == true end

function P.Add(kind, text)
  local s = session
  if not s then return end
  s.counts[kind] = (s.counts[kind] or 0) + 1
  if #s.rows >= P.MAX_ROWS and kind ~= "end" then
    s.dropped = s.dropped + 1
    return
  end
  s.rows[#s.rows + 1] = string.format("%.1f %s %s", GetTime() - s.t0, kind, P.Clean(text))
end

-- Seconds as text for rows; "-" when unknown.
function P.Num(v, places)
  if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return "-" end
  if places == 0 then return string.format("%d", math.floor(v + 0.5)) end
  return string.format("%.1f", math.abs(v) < 0.05 and 0 or v)
end

-- Saved sessions can be damaged by an edit or another release: keep the
-- newest well-formed ones and their string rows only.
function P.Repair(db)
  if db.bgProfilerOn ~= true then db.bgProfilerOn = nil end
  local list = db.bgProfiles
  if type(list) ~= "table" then db.bgProfiles = nil; return end
  local keep = {}
  for _, s in ipairs(list) do
    if type(s) == "table" and type(s.rows) == "table" and type(s.t0) == "number" and #keep < P.KEEP then
      local rows = {}
      for _, row in ipairs(s.rows) do
        if type(row) == "string" and #rows < P.MAX_ROWS then rows[#rows + 1] = row end
      end
      s.rows = rows
      for _, key in ipairs({ "counts", "stages", "errors", "map" }) do
        if type(s[key]) ~= "table" then s[key] = {} end
      end
      if type(s.dropped) ~= "number" then s.dropped = 0 end
      if type(s.stageKeys) ~= "number" then s.stageKeys = 0 end
      if type(s.started) ~= "number" then s.started = 0 end
      keep[#keep + 1] = s
    end
  end
  db.bgProfiles = #keep > 0 and keep or nil
end

---------------------------------------------------------------------------
-- Your own deaths: the resurrection the timers predicted against the one
-- that happened. GetAreaSpiritHealerTime is the game's own countdown.
---------------------------------------------------------------------------
local death = {}

local function NextWave(g, now)
  local T = ns.Timers
  if not (g and T and T.NextWave) then return nil end
  return (U.call(T.NextWave, g, now))
end

local function GYName(g)
  local T = ns.Timers
  return g and T and T.GYName and U.call(T.GYName, g) or "-"
end

local function Revived(now)
  if not death.since then return end
  P.Add("me", string.format("rez after=%s healerErr=%s gyErr=%s gy=%s", P.Num(now - death.since),
    P.Num(death.healerAt and now - death.healerAt), P.Num(death.gyNext and now - death.gyNext), death.gy or "-"))
  wipe(death)
end

-- Polled each second by the probes, and on death events.
function P.PollMe(now)
  local T = ns.Timers
  if U.read(UnitIsGhost, "player") ~= true then
    if death.since and U.read(UnitIsDeadOrGhost, "player") ~= true then Revived(now) end
    return
  end
  death.since = death.since or now
  local g = T and T.releaseGY
  if g and not death.gyNext then
    death.gyNext, death.gy = NextWave(g, now), GYName(g)
  end
  local left = U.read(GetAreaSpiritHealerTime)
  if type(left) == "number" and left > 0 then
    local at = now + left
    if not death.healerAt or math.abs(at - death.healerAt) > 1.5 then
      death.healerAt = at
      P.Add("me", string.format("healer left=%s gy=%s gyNext=%s", P.Num(left), death.gy or GYName(g),
        P.Num(death.gyNext and death.gyNext - now)))
    end
  end
end

local function OnMe(event)
  local now = GetTime()
  P.Add("me", string.format("%s ghost=%s healer=%s", event, tostring(U.read(UnitIsGhost, "player") == true),
    P.Num(U.read(GetAreaSpiritHealerTime))))
  if event == "PLAYER_UNGHOST" then Revived(now) else P.PollMe(now) end
end

---------------------------------------------------------------------------
-- Chat and match state. A localized line also gets the English form the
-- parsers read; none means the translation tables did not match it.
---------------------------------------------------------------------------
local CHANNEL = {
  CHAT_MSG_BG_SYSTEM_ALLIANCE = "A", CHAT_MSG_BG_SYSTEM_HORDE = "H", CHAT_MSG_BG_SYSTEM_NEUTRAL = "N",
  CHAT_MSG_RAID_BOSS_EMOTE = "boss", CHAT_MSG_MONSTER_YELL = "yell", CHAT_MSG_MONSTER_EMOTE = "emote",
  CHAT_MSG_MONSTER_SAY = "say", CHAT_MSG_SYSTEM = "system",
}

local function OnChat(event, msg, sender)
  msg = U.value(msg)
  local channel = CHANNEL[event]
  if type(msg) ~= "string" then return P.Add("chat", channel .. " ?") end
  local text = channel .. " " .. msg
  sender = U.value(sender)
  if channel == "yell" or channel == "emote" or channel == "say" then text = text .. " <" .. tostring(sender) .. ">" end
  local english = ns.LocalizedChat and U.call(ns.LocalizedChat, msg)
  if type(english) == "string" and english ~= msg then text = text .. " => " .. english end
  P.Add("chat", text)
end

local function Runtime()
  return P.Num(U.read(GetBattlefieldInstanceRunTime), 0)
end

local HANDLERS = {
  PLAYER_DEAD = OnMe, PLAYER_ALIVE = OnMe, PLAYER_UNGHOST = OnMe,
  AREA_SPIRIT_HEALER_IN_RANGE = OnMe, AREA_SPIRIT_HEALER_OUT_OF_RANGE = OnMe,
  PVP_MATCH_ACTIVE = function() P.Add("match", "active runtime=" .. Runtime()) end,
  PVP_MATCH_STATE_CHANGED = function()
    P.Add("match", "state=" .. tostring(C_PvP and U.read(C_PvP.GetActiveMatchState)) .. " runtime=" .. Runtime())
  end,
  PVP_MATCH_COMPLETE = function(_, winner, duration)
    P.Add("match", string.format("complete winner=%s mine=%s duration=%s runtime=%s", tostring(U.value(winner)),
      tostring(U.MyTeam()), P.Num(U.value(duration), 0), Runtime()))
  end,
}
for event in pairs(CHANNEL) do HANDLERS[event] = OnChat end
local frame = U.Events({}, "bg profiler", "battlegrounds")
frame.handlers = HANDLERS

local function Listen(on)
  for event in pairs(HANDLERS) do
    U.call(on and frame.RegisterEvent or frame.UnregisterEvent, frame, event)
  end
  if P.SetProbes then P.SetProbes(on) end
end

---------------------------------------------------------------------------
-- Sessions
---------------------------------------------------------------------------
local function Begin(how)
  local db = Core.db
  local name, inst = Instance()
  local list = ns.Saved.Table(db, "bgProfiles")
  session = { v = P.VERSION, started = time(), date = date("%Y-%m-%d %H:%M:%S"), t0 = GetTime(),
    rows = {}, counts = {}, dropped = 0, stages = {}, stageKeys = 0, errors = {}, map = { name = name, inst = inst },
    game = ns.GAME, client = ns.CLIENT, locale = U.read(GetLocale), build = (U.call(GetBuildInfo)),
    addon = U.value(ns.Api.AddOnMetadata("Highground", "Version")) }
  table.insert(list, 1, session)
  while #list > P.KEEP do table.remove(list) end
  wipe(death)
  P.Add("start", string.format("%s map=%s inst=%s tracked=%s runtime=%s", how, tostring(name), tostring(inst),
    tostring(ns.IsActive and ns.IsActive() or false), Runtime()))
  Listen(true)
end

local function Finish(reason)
  local s = session
  if not s then return 0 end
  P.Add("end", reason)
  s.ended, s.stop, s.duration = time(), reason, GetTime() - s.t0
  session = nil
  Listen(false)
  return #s.rows, s.map.name
end

-- After a /reload or relog: continue the open session of this battleground.
local function Resume()
  local list, inst = Core.db.bgProfiles, select(2, Instance())
  local s = type(list) == "table" and list[1]
  if not (s and not s.ended and s.map.inst == inst and time() - s.started < P.MAX_AGE) then return false end
  if GetTime() < s.t0 then s.t0 = GetTime() - (time() - s.started) end -- the computer restarted
  session = s
  wipe(death)
  P.Add("resume", "runtime=" .. Runtime())
  Listen(true)
  return true
end

-- An open session from a battleground you are no longer in.
local function CloseStale()
  local list = Core.db.bgProfiles
  local s = type(list) == "table" and list[1]
  if s and not s.ended then
    s.ended, s.stop = time(), "lost"
    return #s.rows, s.map.name
  end
end

---------------------------------------------------------------------------
-- Reload offer, after combat when it ends in combat.
---------------------------------------------------------------------------
local TITLE, BODY = "highground.profiler.battleground_recording_ready.47e4eb", "highground.profiler.highground_recorded_count_events_in_map_wow.b42018"
local RELOAD, NOT_NOW = "highground.profiler.reload_now.dfacbf", "highground.community.not_now.e45714"
local pending
local regen = U.Events({}, "bg profiler reload", "battlegrounds")

local function Build()
  if P.win then return P.win end
  local Kit, Theme, L = ns.Kit, ns.Theme, ns.Localization
  local w = L.BindWidget(Kit.Dialog("HighgroundProfilerReload", { title = ns.Locale:Get(TITLE), width = 520, height = 250,
    child = true }), { title = TITLE })
  P.win = w
  w.body = Theme.Text(w.content, "body", "text")
  w.body:SetPoint("TOPLEFT"); w.body:SetPoint("RIGHT"); w.body:SetHeight(90)
  w.body:SetJustifyH("LEFT"); w.body:SetJustifyV("TOP"); w.body:SetWordWrap(true)
  w.status = Theme.Text(w, "body", "warning")
  w.status:SetPoint("BOTTOMLEFT", 24, 64); w.status:SetPoint("RIGHT", -24, 0); w.status:SetJustifyH("LEFT")
  w.later = L.Bind(Kit.Button(w, ns.Locale:Get(NOT_NOW), 140, 32, { onClick = function() w:Hide() end }), NOT_NOW)
  w.later:SetPoint("BOTTOMLEFT", 24, 24)
  w.reload = L.Bind(Kit.Button(w, ns.Locale:Get(RELOAD), 180, 32, { tone = "accent", onClick = function()
    local ok, problem = ns.Modules.Reload()
    if not ok then w.status:SetText(problem or "") end
  end }), RELOAD)
  w.reload:SetPoint("BOTTOMRIGHT", -24, 24)
  return w
end

function P.Offer(count, map)
  if InCombatLockdown() then
    pending = { count = count, map = map }
    regen:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  pending = nil
  local w = Build()
  ns.Localization.Bind(w.body, BODY, { count = count, map = map or "?" })
  w.status:SetText("")
  ns.Kit.Windows.Show(w)
end

regen.handlers.PLAYER_REGEN_ENABLED = function()
  regen:UnregisterEvent("PLAYER_REGEN_ENABLED")
  if pending then P.Offer(pending.count, pending.map) end
end

local function Stopped(count, map, say)
  say = say or U.Say
  say(ns.Locale:Format("highground.profiler.battleground_profiler_stopped_after_count_events_reload.4f2100", { count = count }))
  P.Offer(count, map)
end

local function OnZone()
  if not Core.db then return end
  local inside = InBattleground()
  if session then
    if inside and session.map.inst == select(2, Instance()) then return end
    Core.db.bgProfilerOn = nil
    local count, map = Finish("left")
    return Stopped(count, map)
  end
  if not P.Armed() then return end
  if inside then
    if not Resume() then CloseStale(); Begin("entered") end
    return
  end
  local lost, map = CloseStale()
  if lost then
    Core.db.bgProfilerOn = nil
    Stopped(lost, map)
  end
end

function P.Start(say)
  if not Core.db then return end
  if P.Armed() or session then
    return say(ns.Locale:Get("highground.profiler.the_battleground_profiler_is_already_on_hg.ec2e72"))
  end
  Core.db.bgProfilerOn = true
  if InBattleground() then
    CloseStale()
    Begin("command")
    say(ns.Locale:Get("highground.profiler.battleground_profiler_recording_it_stops_when_you.387a07"))
  else
    say(ns.Locale:Get("highground.profiler.battleground_profiler_on_recording_starts_when_you.d2d057"))
  end
end

function P.Stop(say)
  if not Core.db then return end
  local armed = P.Armed()
  Core.db.bgProfilerOn = nil
  if session then
    local count, map = Finish("stopped")
    return Stopped(count, map, say)
  end
  if armed then return say(ns.Locale:Get("highground.profiler.battleground_profiler_off_nothing_was_recorded.9bc411")) end
  say(ns.Locale:Get("highground.profiler.the_battleground_profiler_is_not_on.345514"))
end

U.Events({
  PLAYER_LOGIN = function()
    if not Core.db then return end
    P.Repair(Core.db)
    OnZone()
  end,
  PLAYER_ENTERING_WORLD = OnZone,
  ZONE_CHANGED_NEW_AREA = OnZone,
}, "bg profiler zone", "battlegrounds")
