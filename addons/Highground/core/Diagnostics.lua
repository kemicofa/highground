local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Slash
---------------------------------------------------------------------------
-- /hg probe: report which APIs return readable vs secret values right now,
-- on your target. Results are also saved to HighgroundDB.lastProbe.
function Core.Probe(say)
  local out = {}
  local function show(label, f, ...)
    local res = { pcall(f, ...) }
    local text
    if not res[1] then
      text = "ERROR " .. tostring(res[2])
    else
      local parts = {}
      for i = 2, math.max(#res, 2) do
        local v = res[i]
        if v == nil then
          parts[#parts + 1] = "nil"
        elseif Core.issecret(v) then
          parts[#parts + 1] = "SECRET"
        elseif type(v) == "table" then
          local okLen, n = pcall(function() return #v end)
          parts[#parts + 1] = okLen and Core.plain(n) and ("table#" .. n) or "table(SECRET len)"
        else
          parts[#parts + 1] = tostring(v)
        end
      end
      text = table.concat(parts, ", ")
    end
    out[#out + 1] = label .. " = " .. text
    say(label .. " = " .. ns.Theme.TipHex("gold") .. text .. "|r")
  end
  local _, instanceType = IsInInstance()
  show("instance", function() return instanceType end)
  show("IsRatedBattleground", C_PvP.IsRatedBattleground)
  show("IsSoloRBG", C_PvP.IsSoloRBG)
  show("GetActiveMatchState", C_PvP.GetActiveMatchState)
  show("addon active / enemies / allyFaction", function()
    local n = 0
    for _ in pairs(Core.enemies) do n = n + 1 end
    return Core.active, n, tostring(Core.allyFaction)
  end)
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    show("InChatMessagingLockdown", C_ChatInfo.InChatMessagingLockdown)
  end
  show("NumBattlefieldScores", GetNumBattlefieldScores)
  show("rows per team (faction:count)", function()
    local counts = {}
    for i = 1, GetNumBattlefieldScores() or 0 do
      local info = Core.ScoreInfo(i)
      local f = info and info.faction
      if Core.plain(f) then
        counts[f] = (counts[f] or 0) + 1
      end
    end
    local parts = {}
    for f, c in pairs(counts) do
      parts[#parts + 1] = f .. ":" .. c
    end
    return table.concat(parts, " ")
  end)
  if (GetNumBattlefieldScores() or 0) > 0 then
    show("score[1].name/class/spec/faction", function()
      local i = Core.ScoreInfo(1)
      if i then return i.name, i.classToken, i.talentSpec, i.faction end
    end)
  end
  local u = "target"
  if not UnitExists(u) then
    say("no target: target an enemy player and run /hg probe again for unit checks")
  else
    show("UnitName", UnitName, u)
    show("UnitClass", UnitClass, u)
    show("UnitIsPlayer", UnitIsPlayer, u)
    show("UnitCanAttack", UnitCanAttack, "player", u)
    show("CanonUnit / in roster", function()
      local k = Core.CanonUnit(u)
      return k, k and Core.enemies[k] ~= nil
    end)
    show("UnitIsDeadOrGhost", UnitIsDeadOrGhost, u)
    show("UnitHealthPercent", UnitHealthPercent, u, true)
    show("BIG_DEFENSIVE auras", C_UnitAuras.GetUnitAuras, u, "HELPFUL|BIG_DEFENSIVE")
    show("EXTERNAL_DEFENSIVE auras", C_UnitAuras.GetUnitAuras, u, "HELPFUL|EXTERNAL_DEFENSIVE")
    show("CROWD_CONTROL auras", C_UnitAuras.GetUnitAuras, u, "HARMFUL|CROWD_CONTROL")
    show("IMPORTANT (non-def) auras", C_UnitAuras.GetUnitAuras, u, "HELPFUL|IMPORTANT|!BIG_DEFENSIVE|!EXTERNAL_DEFENSIVE")
    show("GetRaidTargetIndex", GetRaidTargetIndex, u)
    show("UnitPowerMax mana", UnitPowerMax, u, 0)
    show("UnitHealthMax", UnitHealthMax, u)
    show("UnitPowerType", UnitPowerType, u)
    show("target's target is you", UnitIsUnit, u .. "target", "player")
    show("raid1target name", UnitName, "raid1target")
    show("nearest band (yards) / secret answer", Core.NearestBand, u)
  end
  show("rows bound (row1 macro)", function()
    return HighgroundRow1 and HighgroundRow1:GetAttribute("macrotext1")
  end)
  Core.db.lastProbe = { t = date("%Y-%m-%d %H:%M:%S"), lines = out }
  say("saved to SavedVariables (written on /reload or logout)")
end

-- Opt-in, finite capture for problems that cannot be reproduced in the
-- simulator. Nothing is wrapped or scheduled until /hg perf start is used.
local capture
local U = ns.Util
local function Count(values)
  local n = 0
  for _ in pairs(type(values) == "table" and values or {}) do n = n + 1 end
  return n
end

local function Buffers()
  local W, B, N = ns.Reputation or {}, ns.Bounty or {}, ns.Nearby or {}
  local P = B.Public or {}
  local errors = 0
  for _, row in pairs(type(Core.db.errors) == "table" and Core.db.errors or {}) do
    errors = errors + (type(row) == "table" and tonumber(row.count) or 0)
  end
  return { enemies = Count(Core.enemies), nearby = Count(N.seen), errors = errors,
    errorKeys = Count(Core.db.errors), reputationQueue = Count(W.outbox), reputationPeers = Count(W.peers),
    reputationProbes = Count(W.probes), reputationIncoming = Count(W.incoming),
    bountyQueue = Count(P.outbox), bountyPeers = Count(P.peers), bountyIncoming = Count(P.incoming) }
end

local function AddonMemory()
  U.call(UpdateAddOnMemoryUsage or C_AddOns and C_AddOns.UpdateAddOnMemoryUsage)
  local value = U.read(GetAddOnMemoryUsage or C_AddOns and C_AddOns.GetAddOnMemoryUsage, ns.ADDON or "Highground")
  return type(value) == "number" and value or nil
end

local function UIState()
  local W, H, J = ns.Reputation and ns.Reputation.UI or {}, ns.Hub or {}, ns.EnemyJournal or {}
  local function State(frame)
    return not frame and "unbuilt" or frame:IsVisible() and "visible" or frame:IsShown() and "parent-hidden" or "hidden"
  end
  return { hub = State(H.win), hubPage = H.current, reputation = State(W.window),
    report = State(W.report), reason = State(W.reason), details = State(W.details), journal = State(J.win) }
end

local function Sample(s)
  local r = s.report
  local fps = U.read(GetFramerate)
  if type(fps) == "number" then
    r.fpsSamples, r.fpsTotal = r.fpsSamples + 1, r.fpsTotal + fps
    r.fpsMin = math.min(r.fpsMin or fps, fps)
  end
  r.elapsed = math.max(0, GetTime() - s.started)
  r.heapEnd = s.heap("count")
  if #r.samples < 8 and r.elapsed >= s.nextSample then
    r.samples[#r.samples + 1] = { seconds = r.elapsed, heapKB = r.heapEnd, fps = fps, ui = UIState() }
    s.nextSample = s.nextSample + 10
  end
end

function Core.StopPerformance(say)
  local s = capture
  if not s then return false end
  capture = nil
  if s.timer then s.timer:Cancel() end
  for _, hook in ipairs(s.hooks) do
    if hook.owner[hook.key] == hook.wrapper then hook.owner[hook.key] = hook.original end
  end
  Sample(s)
  local r = s.report
  r.running, r.finished = false, date("%Y-%m-%d %H:%M:%S")
  r.buffersEnd, r.addonEndKB, r.uiEnd = Buffers(), AddonMemory(), UIState()
  if say then
    say(string.format("Performance capture finished: %.0fs, %.1f MiB Lua heap change%s.", r.elapsed,
      (r.heapEnd - r.heapStart) / 1024, r.fpsMin and string.format(", lowest sampled FPS %.0f", r.fpsMin) or ""))
    say("Use /hg perf for the largest callbacks. /reload writes this report to SavedVariables for analysis.")
  end
  return true
end

function Core.StartPerformance(say)
  if capture then say("Performance capture is already running; it stops after 60 seconds."); return end
  if not Core.db or type(collectgarbage) ~= "function" or not C_Timer or not C_Timer.NewTicker then
    say("This client does not expose the APIs needed for a performance capture."); return
  end
  local ok, memory = pcall(collectgarbage, "count")
  if not ok or type(memory) ~= "number" then say("Lua memory measurement is unavailable on this client."); return end
  local r = { version = 2, started = date("%Y-%m-%d %H:%M:%S"), running = true,
    stages = {}, details = {}, routes = {}, routeKeys = 0, samples = {}, work = {}, fpsSamples = 0, fpsTotal = 0, keys = 0,
    buffersStart = Buffers(), addonStartKB = AddonMemory(), uiStart = UIState() }
  local s = { report = r, hooks = {}, heap = collectgarbage, nextSample = 0, inside = false,
    clock = debugprofilestop or function() return GetTime() * 1000 end }
  local function Install(owner, key, wrapper)
    s.hooks[#s.hooks + 1] = { owner = owner, key = key, original = owner[key], wrapper = wrapper }
    owner[key] = wrapper
  end
  local function Finish(row, memoryBefore, timeBefore, ...)
    local kb, ms = math.max(0, s.heap("count") - memoryBefore), math.max(0, s.clock() - timeBefore)
    row.calls, row.kb, row.ms = row.calls + 1, row.kb + kb, row.ms + ms
    row.maxKB, row.maxMS = math.max(row.maxKB, kb), math.max(row.maxMS, ms)
    s.inside = false
    return ...
  end
  for _, key in ipairs({ "Guard", "RunGuarded" }) do
    local original = U[key]
    Install(U, key, function(stage, fn, ...)
      if capture == s and stage == "router:enter" then
        local to = ...
        local name = type(to) == "table" and to.name
        if type(name) == "string" then
          local windows = ns.Kit and ns.Kit.Windows
          local frame = windows and windows.frames[name]
          if frame then name = "window:" .. (frame:GetName() or name) end
          name = name:sub(1, 80)
          if not r.routes[name] then
            if r.routeKeys >= 15 then name = "other"
            else r.routeKeys = r.routeKeys + 1 end
          end
          r.routes[name] = (r.routes[name] or 0) + 1
        end
      end
      if capture ~= s or s.inside then return original(stage, fn, ...) end
      local label = type(stage) == "string" and stage or "unknown"
      if #label > 80 then label = label:sub(1, 80) end
      if not r.stages[label] and r.keys >= 63 then label = "other" end
      local row = r.stages[label]
      if not row then
        row = { calls = 0, kb = 0, ms = 0, maxKB = 0, maxMS = 0 }
        r.stages[label], r.keys = row, r.keys + 1
      end
      s.inside = true
      return Finish(row, s.heap("count"), s.clock(), original(stage, fn, ...))
    end)
  end
  -- Inclusive suboperations explain the aggregate sync row. They may nest,
  -- so never add these rows to each other or to the outer stage totals.
  local W = ns.Reputation
  local function DetailFinish(row, memory, started, ...)
    row.calls = row.calls + 1
    row.kb = row.kb + math.max(0, s.heap("count") - memory)
    row.ms = row.ms + math.max(0, s.clock() - started)
    return ...
  end
  for _, entry in ipairs({ { W, "Reconcile", "reputation scope/access" },
    { W, "Discover", "reputation discovery" }, { W, "RequestSync", "reputation update requests" },
    { W, "GuildDiscoveryTick", "reputation guild announcements" },
    { W, "PumpSnapshots", "reputation snapshots" }, { W, "Flush", "reputation transport" },
    { W and W.UI, "Refresh", "reputation UI" }, { W and W.UI, "RefreshDialogs", "reputation dialogs" } }) do
    local owner, key, label = unpack(entry)
    if owner and type(owner[key]) == "function" then
      local original, row = owner[key], { calls = 0, kb = 0, ms = 0 }
      r.details[label] = row
      Install(owner, key, function(...)
        if capture ~= s then return original(...) end
        return DetailFinish(row, s.heap("count"), s.clock(), original(...))
      end)
    end
  end
  -- Count addon work without intercepting or replacing native game APIs.
  for _, entry in ipairs({ { ns.Organizations, "Members", "rosterBuilds" },
    { ns.Organizations, "Member", "memberLookups" }, { ns.Organizations, "List", "organizationLists" },
    { ns.Guild, "ReadRoster", "guildRosterReads" } }) do
    local owner, key, name = unpack(entry)
    if owner and type(owner[key]) == "function" then
      local original = owner[key]
      r.work[name] = 0
      Install(owner, key, function(...)
        if capture == s then r.work[name] = r.work[name] + 1 end
        return original(...)
      end)
    end
  end
  Core.db.lastPerformance, capture = r, s
  s.started, r.heapStart = GetTime(), s.heap("count")
  Sample(s)
  s.timer = C_Timer.NewTicker(1, function()
    if capture ~= s then return end
    if GetTime() - s.started >= 60 then Core.StopPerformance(say) else Sample(s) end
  end)
  say("Capturing Highground for 60 seconds. Keep playing normally; leave the main window closed for this check.")
end

function Core.PerformanceReport(say)
  local r = Core.db and Core.db.lastPerformance
  if not r then say("Use /hg perf start to capture 60 seconds of callback time, allocations and FPS."); return end
  say(string.format("Performance: %s, %.0fs; Lua heap %+.1f MiB.", capture and "running" or r.running and "interrupted" or "complete",
    r.elapsed or 0, ((r.heapEnd or r.heapStart) - r.heapStart) / 1024))
  if r.fpsSamples > 0 then say(string.format("Sampled FPS: average %.0f, lowest %.0f.", r.fpsTotal / r.fpsSamples, r.fpsMin)) end
  if r.addonStartKB and r.addonEndKB then
    say(string.format("Highground memory: %.1f -> %.1f MiB.", r.addonStartKB / 1024, r.addonEndKB / 1024))
  end
  local rows = {}
  for name, value in pairs(r.stages) do rows[#rows + 1] = { name = name, value = value } end
  table.sort(rows, function(a, b) return a.value.kb > b.value.kb end)
  for i = 1, math.min(6, #rows) do
    local row, value = rows[i], rows[i].value
    say(string.format("%s: %.1f KiB, %.1f ms, %d calls (slowest %.1f ms).", row.name, value.kb, value.ms, value.calls, value.maxMS))
  end
  say("Callback allocations are lower bounds if GC ran; the Lua heap includes Blizzard and other addons. No GC settings were changed.")
end
