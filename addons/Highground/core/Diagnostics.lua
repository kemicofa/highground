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
      text = ns.Locale:Format("highground.diagnostics.error_value2.731725", { value2 = tostring(res[2]) })
    else
      local parts = {}
      for i = 2, math.max(#res, 2) do
        local v = res[i]
        if v == nil then
          parts[#parts + 1] = "nil"
        elseif Core.issecret(v) then
          parts[#parts + 1] = ns.Locale:Get("shared.copy.secret.3c3b27")
        elseif type(v) == "table" then
          local okLen, n = pcall(function() return #v end)
          parts[#parts + 1] = okLen and Core.plain(n) and ("table#" .. n) or ns.Locale:Get("highground.diagnostics.table_secret_len.2b8979")
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
  show(ns.Locale:Get("highground.diagnostics.addon_active_enemies_allyfaction.8511f9"), function()
    local n = 0
    for _ in pairs(Core.enemies) do n = n + 1 end
    return Core.active, n, tostring(Core.allyFaction)
  end)
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    show("InChatMessagingLockdown", C_ChatInfo.InChatMessagingLockdown)
  end
  show("NumBattlefieldScores", GetNumBattlefieldScores)
  show(ns.Locale:Get("highground.diagnostics.rows_per_team_faction_count.6f7513"), function()
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
    say(ns.Locale:Get("highground.diagnostics.no_target_target_an_enemy_player_and.38123f"))
  else
    show("UnitName", UnitName, u)
    show("UnitClass", UnitClass, u)
    show("UnitIsPlayer", UnitIsPlayer, u)
    show("UnitCanAttack", UnitCanAttack, "player", u)
    show(ns.Locale:Get("highground.diagnostics.canonunit_in_roster.12afb7"), function()
      local k = Core.CanonUnit(u)
      return k, k and Core.enemies[k] ~= nil
    end)
    show("UnitIsDeadOrGhost", UnitIsDeadOrGhost, u)
    show("UnitHealthPercent", UnitHealthPercent, u, true)
    show(ns.Locale:Get("highground.diagnostics.big_defensive_auras.8141dc"), C_UnitAuras.GetUnitAuras, u, "HELPFUL|BIG_DEFENSIVE")
    show(ns.Locale:Get("highground.diagnostics.external_defensive_auras.d8be86"), C_UnitAuras.GetUnitAuras, u, "HELPFUL|EXTERNAL_DEFENSIVE")
    show(ns.Locale:Get("highground.diagnostics.crowd_control_auras.2c5213"), C_UnitAuras.GetUnitAuras, u, "HARMFUL|CROWD_CONTROL")
    show(ns.Locale:Get("highground.diagnostics.important_non_def_auras.acc18a"), C_UnitAuras.GetUnitAuras, u, "HELPFUL|IMPORTANT|!BIG_DEFENSIVE|!EXTERNAL_DEFENSIVE")
    show("GetRaidTargetIndex", GetRaidTargetIndex, u)
    show(ns.Locale:Get("highground.diagnostics.unitpowermax_mana.6d9b00"), UnitPowerMax, u, 0)
    show("UnitHealthMax", UnitHealthMax, u)
    show("UnitPowerType", UnitPowerType, u)
    show(ns.Locale:Get("highground.diagnostics.target_s_target_is_you.c61417"), UnitIsUnit, u .. "target", "player")
    show(ns.Locale:Get("highground.diagnostics.raid1target_name.db2421"), UnitName, "raid1target")
    show(ns.Locale:Get("highground.diagnostics.nearest_band_yards_secret_answer.8743d7"), Core.NearestBand, u)
  end
  show(ns.Locale:Get("highground.diagnostics.rows_bound_row1_macro.155a1a"), function()
    return HighgroundRow1 and HighgroundRow1:GetAttribute("macrotext1")
  end)
  Core.db.lastProbe = { t = date("%Y-%m-%d %H:%M:%S"), lines = out }
  say(ns.Locale:Get("highground.diagnostics.saved_to_savedvariables_written_on_reload_or.f5faa5"))
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
  for _, row in pairs(Core.db.errors or {}) do errors = errors + (row.count or 0) end
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
    r.samples[#r.samples + 1] = { seconds = r.elapsed, heapKB = r.heapEnd, fps = fps }
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
  r.buffersEnd, r.addonEndKB = Buffers(), AddonMemory()
  if say then
    say(ns.Locale:Format("highground.diagnostics.performance_capture_finished_r_elapsed_s_value2.456c6f", { r_elapsed = string.format("%.0f", r.elapsed), value2 = string.format("%.1f", (r.heapEnd - r.heapStart) / 1024), value3 = string.format("%s", r.fpsMin and ns.Locale:Format("highground.diagnostics.lowest_sampled_fps_r_fpsmin.51817c", { r_fpsMin = string.format("%.0f", r.fpsMin) }) or "") }))
    say(ns.Locale:Get("highground.diagnostics.use_hg_perf_for_the_largest_callbacks.afdd74"))
  end
  return true
end

function Core.StartPerformance(say)
  if capture then say(ns.Locale:Get("highground.diagnostics.performance_capture_is_already_running_it_stops.daedc6")); return end
  if not Core.db or type(collectgarbage) ~= "function" or not C_Timer or not C_Timer.NewTicker then
    say(ns.Locale:Get("highground.diagnostics.this_client_does_not_expose_the_apis.501690")); return
  end
  local ok, memory = pcall(collectgarbage, "count")
  if not ok or type(memory) ~= "number" then say(ns.Locale:Get("highground.diagnostics.lua_memory_measurement_is_unavailable_on_this.38253f")); return end
  local r = { version = 1, started = date("%Y-%m-%d %H:%M:%S"), running = true,
    stages = {}, samples = {}, work = {}, fpsSamples = 0, fpsTotal = 0, keys = 0,
    buffersStart = Buffers(), addonStartKB = AddonMemory() }
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
  say(ns.Locale:Get("highground.diagnostics.capturing_highground_for_60_seconds_keep_playing.a07a5b"))
end

function Core.PerformanceReport(say)
  local r = Core.db and Core.db.lastPerformance
  if not r then say(ns.Locale:Get("highground.diagnostics.use_hg_perf_start_to_capture_60.cb1229")); return end
  say(ns.Locale:Format("highground.diagnostics.performance_value1_value2_s_lua_heap_value3.1ce209", { value1 = string.format("%s", capture and "running" or r.running and "interrupted" or "complete"), value2 = string.format("%.0f", r.elapsed or 0), value3 = string.format("%+.1f", ((r.heapEnd or r.heapStart) - r.heapStart) / 1024) }))
  if r.fpsSamples > 0 then say(ns.Locale:Format("highground.diagnostics.sampled_fps_average_value1_lowest_r_fpsmin.902e04", { value1 = string.format("%.0f", r.fpsTotal / r.fpsSamples), r_fpsMin = string.format("%.0f", r.fpsMin) })) end
  if r.addonStartKB and r.addonEndKB then
    say(ns.Locale:Format("highground.diagnostics.highground_memory_value1_value2_mib.6486e9", { value1 = string.format("%.1f", r.addonStartKB / 1024), value2 = string.format("%.1f", r.addonEndKB / 1024) }))
  end
  local rows = {}
  for name, value in pairs(r.stages) do rows[#rows + 1] = { name = name, value = value } end
  table.sort(rows, function(a, b) return a.value.kb > b.value.kb end)
  for i = 1, math.min(6, #rows) do
    local row, value = rows[i], rows[i].value
    say(ns.Locale:Format("highground.diagnostics.row_name_value_kb_kib_value_ms.d097f9", { row_name = string.format("%s", row.name), value_kb = string.format("%.1f", value.kb), value_ms = string.format("%.1f", value.ms), value_calls = string.format("%d", value.calls), value_maxMS = string.format("%.1f", value.maxMS) }))
  end
  say(ns.Locale:Get("highground.diagnostics.callback_allocations_are_lower_bounds_if_gc.8a0f50"))
end
