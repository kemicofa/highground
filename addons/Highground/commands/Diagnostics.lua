local _, ns = ...
local Core, Commands = ns.Core, ns.Commands
local Hex = ns.Theme.TipHex -- chat

function Commands.why(arg, msg, say)
  local cfg = (Core.me.range or ns.RangeBands[Core.me.class])
  local reach = cfg and (cfg.reachYards or cfg.attackYards) or 40
  say(ns.Locale:Format("highground.diagnostics.kill_target_eligible_live_priority_within_reach.f504df", { reach = string.format("%d", reach), value2 = string.format("%s", Core.me.class or "?") }))
  say(ns.Locale:Format("highground.diagnostics.kill_target_value2.ec3f2e", { value2 = (Core.killNow and Core.killNow.display or ns.Locale:Get("highground.diagnostics.none_eligible.5fdca4")) }))
  local list = {}
  for _, e in ipairs(Core.order) do
    list[#list + 1] = e
  end
  table.sort(list, function(a, b)
    return (a.live or 0) > (b.live or 0)
  end)
  for i = 1, math.min(#list, 10) do
    local e = list[i]
    local parts = {}
    for _, w in ipairs(Core.WEIGHTS) do
      local v = e.comp and e.comp[w.key]
      if v and math.abs(v) >= 0.5 then
        parts[#parts + 1] = string.format("%s%+.0f", w.key, v)
      end
    end
    local where = Core.TargetBlocked(e) or e.yards and string.format("%dyd", e.yards)
      or e.plateUnit and ">range" or "unseen"
    say(ns.Locale:Format("highground.diagnostics.value1_i_value3_live_value4_where_value6.aee270", { value1 = string.format("%s", e == Core.killNow and Hex("kill") or ""), i = string.format("%d", i), value3 = string.format("%s", e.display:match("^[^-]+")), value4 = string.format("%.0f", e.live or 0), where = string.format("%s", where), value6 = string.format("%s", table.concat(parts, " ")), value7 = string.format("%s", e == Core.killNow and "|r" or "") }))
  end
  local a = Core.db.liveStats and Core.db.liveStats.auras
  say(ns.Locale:Format("highground.diagnostics.aura_reads_plain_value1_secret_value2_error.7c85cf", { value1 = string.format("%d", a and a.plain or 0), value2 = string.format("%d", a and a.secret or 0), value3 = string.format("%d", a and a.error or 0), value4 = string.format("%s", Core.db.auraErr and (" (" .. Core.db.auraErr .. ")") or "") }))
end

function Commands.kit(arg, msg, say)
  local key = UnitExists("target") and Core.CanonUnit("target")
  local e = (key and Core.enemies[key]) or Core.killNow
  if not e then
    say(ns.Locale:Get("highground.diagnostics.target_an_enemy_or_have_a_kill.8c0f86"))
  elseif not ns.Kits then
    say(ns.Locale:Get("highground.diagnostics.cooldown_tracking_needs_the_combat_log_cata.02c257"))
  else
    say(e.display .. " (" .. (e.specID and Core.specInfo[e.specID] and Core.specInfo[e.specID].name or "?") .. " " .. e.class .. ")")
    for _, entry in ipairs(Core.KitFor(e)) do
      local left = Core.CdLeft(e, entry)
      local active = e.activeCooldowns and e.activeCooldowns[entry[1]]
      local status = active and ns.Locale:Get("highground.tooltip.active.c72633") or left and (ns.Locale:Format("highground.diagnostics.down_value2.00c9a0", { value2 = Core.Clock(left) }))
        or (e.cds and e.cds[entry[1]] and ns.Locale:Get("highground.diagnostics.estimated_ready.0faf49") or ns.Locale:Get("highground.diagnostics.not_observed.858b88"))
      say(ns.Locale:Format("highground.diagnostics.value1_status.09882b", { value1 = string.format("%-20s", entry[4]), status = string.format("%s", status) }))
    end
  end
end

function Commands.err(arg, msg, say)
  if Core.db.apiMissing and #Core.db.apiMissing > 0 then
    say(ns.Locale:Format("highground.diagnostics.missing_on_this_client_value2.ded54b", { value2 = table.concat(Core.db.apiMissing, ", ") }))
  end
  local n = 0
  for key, rec in pairs(Core.db.errors or {}) do
    n = n + 1
    say(ns.Locale:Format("highground.diagnostics.value1_key_r_x_rec_count_since.e8bb92", { value1 = string.format("%s", Hex("danger")), key = string.format("%s", key), rec_count = string.format("%d", rec.count), rec_first = string.format("%s", rec.first) }))
  end
  say(n == 0 and ns.Locale:Get("highground.diagnostics.no_errors_recorded.5d8bc4") or ns.Locale:Get("highground.diagnostics.full_traces_saved_reload_so_they_can.c86cf3"))
  for group, g in pairs(Core.db.liveStats or {}) do
    if type(g) == "table" then
      local parts = {}
      for k, v in pairs(g) do
        parts[#parts + 1] = k .. "=" .. v
      end
      say(group .. ": " .. table.concat(parts, " "))
    end
  end
  if Core.db.liveStats and Core.db.liveStats.maxVisible then
    say(ns.Locale:Format("highground.diagnostics.most_enemies_visible_at_once_core_db.2f1511", { Core_db_liveStats_maxVisible = Core.db.liveStats.maxVisible }))
  end
  if Core.db.healthErr then
    say(ns.Locale:Format("highground.diagnostics.health_error_core_db_healtherr.ed44ab", { Core_db_healthErr = Core.db.healthErr }))
  end
  say(ns.Locale:Format("highground.diagnostics.roster_value2_value3.57dd22", { value2 = (Core.rosterStatus or "ok"), value3 = ns.Locale:Format("highground.diagnostics.active_value1_enemies_value2_allyfaction_value3.3171ed", { value1 = string.format("%s", tostring(Core.active)), value2 = string.format("%d", (function() local c = 0 for _ in pairs(Core.enemies) do c = c + 1 end return c end)()), value3 = string.format("%s", tostring(Core.allyFaction)) }) }))
end

function Commands.clearerr(arg, msg, say)
  ns.Util.ClearErrors()
  say(ns.Locale:Get("highground.diagnostics.errors_cleared.9d8a45"))
end

function Commands.perf(arg, msg, say)
  if arg == "start" then Core.StartPerformance(say)
  elseif arg == "stop" then
    if not Core.StopPerformance(say) then say(ns.Locale:Get("highground.diagnostics.no_performance_capture_is_running.5d30f1")) end
  elseif arg == "" then Core.PerformanceReport(say)
  else say(ns.Locale:Get("highground.diagnostics.hg_perf_start_capture_60_seconds_hg.37afa5")) end
end

function Commands.probe(arg, msg, say)
  Core.Probe(say)
end

function Commands.map(arg, msg, say)
  Core.mapKey = nil
  Core.DetectMap()
  local ui = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local name, _, _, _, _, _, _, inst = GetInstanceInfo()
  say(ns.Locale:Format("highground.diagnostics.value1_uimap_value2_instance_value3.dd728c", { value1 = string.format("%s", tostring(name)), value2 = string.format("%s", tostring(ui)), value3 = string.format("%s", tostring(inst)) }))
  if Core.currentBG then
    local tilts = {}
    for k, v in pairs(Core.currentProfile or {}) do
      if k ~= "label" then tilts[#tilts + 1] = k .. " x" .. v end
    end
    say(ns.Locale:Format("highground.diagnostics.profile_core_currentbg_name_core_currentprofile_label.d93061", { Core_currentBG_name = string.format("%s", Core.currentBG.name), Core_currentProfile_label = string.format("%s", Core.currentProfile.label), value3 = string.format("%s", Core.isBlitz and " +Blitz" or ""), value4 = string.format("%s", table.concat(tilts, ", ")) }))
  else
    say(ns.Locale:Get("highground.diagnostics.no_battleground_profile_for_this_map_default.2d9cb0"))
  end
end

-- /hg help: the command catalog (config/Commands.lua) for this client.
function Commands.help(arg, msg, say)
  Core.UpdateMe()
  local si = Core.me.specID and Core.specInfo[Core.me.specID]
  say(ns.Locale:Format("highground.diagnostics.you_value1_value2_core_me_dmg_value4.63dfaa", { value1 = string.format("%s", si and si.name or "?"), value2 = string.format("%s", Core.me.class or "?"), Core_me_dmg = string.format("%s", Core.me.dmg), value4 = string.format("%s", Core.me.melee and "melee" or "ranged") }))
  local group
  for _, row in ipairs(ns.CommandCatalog.commands) do
    if not row[2] then
      group = row[1]
    elseif ns.OptionAvailable(row) then
      if group then say(Hex("accent") .. group .. "|r"); group = nil end
      say(Hex("gold") .. row[1] .. "|r  " .. Hex("textMuted") .. row[2] .. "|r")
      for _, alias in ipairs(row.aliases or {}) do say(ns.Locale:Format("highground.diagnostics.also_hg_alias.9c8450", { alias = alias })) end
    end
  end
  say(ns.Locale:Get("highground.diagnostics.keybind_target_kill_order_1_under_key.818d43"))
  say(ns.Locale:Get("highground.diagnostics.commands_and_ui_controls_help_and_commands.25474a"))
end
