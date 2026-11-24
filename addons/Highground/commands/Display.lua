local _, ns = ...
local Core, Commands = ns.Core, ns.Commands
local Hex = ns.Theme.TipHex -- chat
-- Command syntax shown as text: chat reads "|r" in "s|i|raid" as an escape.
local function Syntax(text) return (text:gsub("|", "||")) end

function Commands.intel(arg, msg, say)
  if not ns.MapWhere then
    say(ns.Locale:Format("highground.display.value1_intel_map_not_loaded_r_restart.f6819b", { value1 = Hex("error") }))
    return
  end
  if arg == "test" and ns.IntelTest then
    say(ns.IntelTest() and ns.Locale:Get("highground.display.test_pin_on_open_the_map_an.9f533b") or ns.Locale:Get("highground.display.test_pin_off.e1e632"))
  elseif arg == "off" or arg == "on" then
    Core.SetFeature("intel", arg == "on")
  elseif arg == "share off" or arg == "share on" then
    Core.SetFeature("intelShare", arg == "share on")
  end
  say(ns.Locale:Format("highground.display.intel_map_value1_sharing_with_teammates_value2.4a53da", { value1 = string.format("%s", Core.On("intel") and ns.Locale:Get("shared.copy.on.db3d40") or ns.Locale:Get("shared.copy.off.ad5048")), value2 = string.format("%s", Core.On("intelShare") and ns.Locale:Get("shared.copy.on.db3d40") or ns.Locale:Get("shared.copy.off.ad5048")) }))
  if ns.IntelStatus then
    say(ns.IntelStatus())
  end
end

function Commands.timers(arg, msg, say)
  if arg == "off" or arg == "on" then
    Core.SetFeature("timers", arg == "on")
  elseif arg == "reset" and ns.TimersWindowReset then
    ns.TimersWindowReset()
    say(ns.Locale:Get("highground.display.res_timers_and_bases_windows_moved_back.73c2d4"))
  end
  say(ns.Locale:Format("highground.display.timers_value2_value3.698da2", { value2 = (Core.On("timers") and ns.Locale:Get("shared.copy.on.db3d40") or ns.Locale:Get("shared.copy.off.ad5048")), value3 = (ns.TimersStatus and (" | " .. ns.TimersStatus()) or ns.Locale:Get("highground.display.timer_modules_not_loaded_restart_the_client.2270ae")) }))
end

function Commands.priority(arg, msg, say)
  if arg == "off" or arg == "on" then
    Core.SetFeature("killorder", arg == "on")
  end
  say(ns.Locale:Format("highground.display.target_recommendations_value2_value3_hg_priority_on.59f573", { value2 = (Core.PriorityOn() and ns.Locale:Get("shared.copy.on.db3d40") or ns.Locale:Get("shared.copy.off.ad5048")), value3 = (Core.PriorityOn() and "" or ns.Locale:Get("highground.display.scope_follows_your_target.4e7ba6")) }))
end

function Commands.arena(arg, msg, say)
  if arg == "off" or arg == "on" then
    Core.SetFeature("arena", arg == "on")
    if ns.Arena then ns.Arena.Update() end
  elseif arg == "test" and ns.ArenaPreview then
    local on = ns.ArenaPreview()
    if on == nil then say(ns.Locale:Get("highground.display.leave_combat_first.8497e3")); return end
    say(on and ns.Locale:Get("highground.display.preview_on_drag_to_move_hg_arena.7301b3") or ns.Locale:Get("highground.display.preview_off.90af6a"))
    return
  end
  say(ns.Locale:Format("highground.display.arena_duels_value2_hg_arena_on_off.ebae9d", { value2 = (Core.On("arena") and "on" or "off") }))
end

function Commands.call(arg, msg, say)
  if Core.CALL_CHANNELS[arg] then
    Core.db.callChannel = arg
    say(ns.Locale:Format("highground.display.calls_go_to_value2_press_enter_to.c765b4", { value2 = Core.CALL_CHANNELS[arg] }))
  elseif arg == "" then
    Core.CallTarget()
  else
    say("/hg call  = call now  |  /hg call s||i||raid||party||y  = channel")
  end
end

function Commands.mark(arg, msg, say)
  local sub, val = arg:match("^(%S*)%s*(.-)$")
  local names = { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" }
  local pings = { attack = true, warning = true, assist = true, onmyway = true }
  if sub == "icon" and not ns.Caps.enemyMarks then
    say(Syntax(ns.Locale:Get("highground.display.raid_icons_can_t_go_on_enemy.118b4d")))
  elseif sub == "icon" and tonumber(val) and tonumber(val) >= 1 and tonumber(val) <= 8 then
    Core.db.markIcon, Core.db.markMode = tonumber(val), "icon"
    Core.markBound = nil
    Core.UpdateTargetButton()
    say(ns.Locale:Format("highground.display.mark_button_raid_icon_value2.19af2f", { value2 = names[Core.db.markIcon] }))
  elseif sub == "ping" then
    if not ns.Caps.pings then return say(ns.Locale:Get("highground.display.pings_are_not_available_on_this_client.23aaf3")) end
    if pings[val] then
      Core.db.pingType = val
    end
    Core.db.markMode = "ping"
    Core.markBound = nil
    Core.UpdateTargetButton()
    say(Syntax(ns.Locale:Format("highground.display.mark_button_core_db_pingtype_ping_hg.0496dc", { Core_db_pingType = Core.db.pingType })))
  else
    say(ns.Locale:Get("highground.display.macro_click_highgroundmarkbutton_pings_marks_the_kill.055234"))
    -- Clients without pings only offer raid icons; WoW Forever only pings.
    say(Syntax(ns.Locale:Format(not ns.Caps.pings and "highground.display.now_value2_hg_mark_icon_1_8.cc4c9a"
      or ns.Caps.enemyMarks and "highground.display.now_value2_hg_mark_ping_attack_warning.b0390f"
      or "highground.display.now_value2_hg_mark_ping_attack_warning.8a54cc", { value2 = (Core.db.markMode == "icon" and (ns.Locale:Format("highground.display.raid_icon_value2.bfd95a", { value2 = names[Core.db.markIcon or 8] })) or ns.Locale:Format("shared.copy.type_ping.ffba7c", { type = Core.db.pingType })) })))
    say(ns.Locale:Get("highground.display.mark_call_click_highgroundmarkbutton_then_hg_call.ba8ce8"))
    say(ns.Locale:Get(ns.Caps.enemyMarks and "highground.display.re_points_out_of_combat_only_raid.8d1fb2"
      or "highground.display.re_points_out_of_combat_only.b4d99d"))
    local mt = Core.markBtn:GetAttribute("macrotext")
    say(ns.Locale:Format("highground.display.button_currently_does_value2.49efe2", { value2 = ((mt and mt ~= "") and mt:gsub("\n", " | ")
      or ns.Locale:Format("highground.display.value1_nothing_r_no_kill_target_yet.4c3400", { value1 = Hex("danger") })) }))
  end
end

-- /hg burst: the last enemy burst buffs and what their marker showed.
function Commands.burst(arg, msg, say)
  if arg == "test" then
    Core.SetBurstTest(not Core.burstTest)
    return say(Core.burstTest and ns.Locale:Get("highground.display.burst_marker_test_on_target_anyone_with.8cb7eb")
      or ns.Locale:Get("highground.display.burst_marker_test_off.2ea98a"))
  end
  local list = type(Core.db.burstDiag) == "table" and Core.db.burstDiag or {}
  say(ns.Locale:Format("highground.display.burst_markers_value2_enemy_burst_buffs_seen.c84a72", { value2 = (Core.On("burstMarks") and "on" or "off"), value4 = #list }))
  for i = 1, math.min(6, #list) do
    local d = type(list[i]) == "table" and list[i] or {}
    say(ns.Locale:Format("highground.display.d_t_value2_value3_value4_value5.de2e47", { d_t = string.format("%s", tostring(d.t)), value2 = string.format("%s", tostring(d.who):match("^[^-]+")), value3 = string.format("%s", tostring(d.name)), value4 = string.format("%s", tostring(d.mode)), value5 = string.format("%s", d.answer and ns.Locale:Format("shared.copy.marker_answer.842892", { answer = ns.Text.Upper(tostring(d.answer)) }) or not d.nameplate and ns.Locale:Get("highground.display.no_nameplate_too_far_or_plates_off.7dd2bd")
        or not d.read and ns.Locale:Get("highground.display.buff_not_read.cc23f3") or ns.Locale:Format("highground.display.no_marker_dispel_value2.c609fc", { value2 = tostring(d.dispel) })) }))
  end
end

function Commands.pressure(arg, msg, say)
  if ns.PressureCommand then
    ns.PressureCommand(arg, say)
  else
    say(ns.Locale:Get("highground.display.enemy_focus_markers_have_not_loaded_restart.1c68eb"))
  end
end

-- /hg healer [NAME]: mark or unmark a teammate as a healer, by name or the
-- one under the mouse, else your target (core/HealerTags.lua).
function Commands.healer(arg, msg, say)
  local name = msg:match("^%S+%s+(.-)%s*$")
  if name and name ~= "" then
    local unit = Core.TeamUnitByName(name)
    if not unit then return say(ns.Locale:Format("highground.display.no_teammate_named_name.0a00e4", { name = name })) end
    return Core.ToggleTeamHealer(unit, say)
  end
  Core.ToggleHoveredHealer(say)
end

-- /hg healers: the Team healers window; /hg healers test: its sample.
function Commands.healers(arg, msg, say)
  if arg == "test" then
    if ns.TeamHealers.IsSample() then
      ns.TeamHealers.Close()
      return say(ns.Locale:Get("highground.display.team_healers_sample_off.128308"))
    end
    ns.TeamHealers.Open(true)
    return say(ns.Locale:Get("highground.display.team_healers_sample_on.5c71d6"))
  end
  ns.TeamHealers.Open()
end

-- /hg cap probe: record every possible sign of a capture (see
-- core/CapProbe.lua). /hg cap clear: forget the capture diagnostics.
local function CapProbe(say)
  if not ns.Caps.combatLog then say(ns.Locale:Get("highground.display.the_capture_probe_needs_the_combat_log.7d87e1")) return end
  Core.SetCapProbe(not Core.db.capProbeOn)
  if Core.db.capProbeOn then
    say(ns.Locale:Get("highground.display.capture_probe_on_cap_bases_or_stand.916c26"))
  else
    say(ns.Locale:Format("highground.display.capture_probe_off_value2_assaults_recorded.099e13", { value2 = #(Core.db.capProbe or {}) }))
  end
end

-- /hg cap why: target a capper mid-cast to see each capture-detection step.
function Commands.cap(arg, msg, say)
  if arg == "probe" then return CapProbe(say) end
  if arg == "clear" then
    Core.db.capLog, Core.db.capDiag, Core.db.capProbe = nil, nil, nil
    return say(ns.Locale:Get("highground.display.capture_diagnostics_cleared_learned_capture_spell_kept.437826"))
  end
  if arg ~= "why" then return Commands.help(arg, msg, say) end
  local learned = {}
  for spell, l in pairs(Core.db.capSpells or {}) do
    if Core.IsCaptureCast(spell, nil) then learned[#learned + 1] = ns.Locale:Format("highground.display.value1_value2_s.63dbc1", { value1 = string.format("%s", tostring(l.name)), value2 = string.format("%s", tostring(l.secs)) }) end
  end
  say(ns.Locale:Format("highground.display.capture_spells_learned_value2.ce4834", { value2 = (#learned > 0 and table.concat(learned, ", ") or ns.Locale:Get("highground.display.none_yet_cap_a_base_yourself.4ec723")) }))
  local log = Core.db.capLog or {}
  say(ns.Locale:Format("highground.display.combat_log_capture_events_seen_value2.911a2c", { value2 = #log }))
  for i = 1, math.min(3, #log) do
    local l = log[i]
    say(ns.Locale:Format("highground.display.l_t_value2_l_sub_value4.8ec54c", { l_t = string.format("%s", l.t), value2 = string.format("%s", tostring(l.who)), l_sub = string.format("%s", l.sub), value4 = string.format("%s", tostring(l.name or l.spell)) }))
  end
  if not UnitExists("target") then say(ns.Locale:Get("highground.display.for_a_live_check_target_the_player.186f0d")) return end
  local okC, name, _, _, start, finish, _, _, _, spell = pcall(UnitCastingInfo, "target")
  if not (okC and name) then okC, name, _, _, start, finish, _, _, spell = pcall(UnitChannelInfo, "target") end
  say(ns.Locale:Format("highground.display.target_cast_value1_spell_value2_value3.06b4b3", { value1 = string.format("%s", tostring(name)), value2 = string.format("%s", tostring(spell)), value3 = string.format("%s", start and finish and string.format("%.1fs", (finish - start) / 1000) or ns.Locale:Get("highground.display.no_timing.b2b86d")) }))
  say(ns.Locale:Format("highground.display.counts_as_a_capture_value2.397fc3", { value2 = tostring(name ~= nil and Core.IsCaptureCast(spell, name) or false) }))
  local e = Core.enemies[Core.CanonUnit("target") or ""]
  if not e then say(ns.Locale:Get("highground.display.not_in_the_enemy_roster_a_teammate.350840")) return end
  local cap = Core.Capping(e)
  say(ns.Locale:Format("highground.display.tracked_capture_value2.8d9d76", { value2 = (cap and ns.Locale:Format("highground.display.value1_s_left.2179fb", { value1 = string.format("%.1f", cap.finish - GetTime()) }) or "none") }))
  say(ns.Locale:Format("highground.display.nameplate_value2_nameplate_bars_value4.6a339f", { value2 = tostring(e.plateUnit or ns.Locale:Get("highground.display.none_enemy_nameplates_off_or_out_of.5c63e2")), value4 = (Core.db.capPlates ~= false and "on" or "off") }))
end

function Commands.sniper(arg, msg, say)
  local sub, val = arg:match("^(%S*)%s*(.-)$")
  if sub == "test" then
    Core.sniperTest.on = not Core.sniperTest.on
    Core.sniperTest.go = false
    if Core.sniperTest.on then
      Core.sniperDriver:Start()
      say(ns.Locale:Get("highground.display.sniper_test_on_target_anything_with_a.d5dfd7"))
    else
      Core.sniperDriver:Stop()
      Core.UpdateSniper(nil)
      say(ns.Locale:Get("highground.display.sniper_test_off.457b2f"))
    end
  elseif sub == "color" then
    local layer, color = val:match("^(%S+)%s+(.+)$")
    if layer and Core.SetSniperLayerColor(layer, color) then
      say(ns.Locale:Format("highground.display.sniper_layer_colour_value4.3906d3", { layer = layer, value4 = (color == "default" and "default" or "#" .. Core.SniperHex(Core.SniperLayerColor(layer))) }))
    elseif Core.SNIPER_COLORS[val] then
      Core.db.sniperColor = val
      Core.SetSniperLayerColor("ring", "")
      Core.RefreshScopes()
      local page = ns.Options.byKey["battlegrounds-appearance"]
      if page.RefreshSniperColors then page.RefreshSniperColors() end
      say(ns.Locale:Format("highground.display.sniper_color_val.ce7c65", { val = val }))
    else
      local names = {}
      for k in pairs(Core.SNIPER_COLORS) do names[#names + 1] = k end
      table.sort(names)
      say("/hg sniper color ring||skull||aim HEX||default; or color NAME (" .. table.concat(names, ", ") .. ")")
    end
  elseif sub == "skull" or sub == "animate" then
    if val ~= "" and val ~= "on" and val ~= "off" then
      say("/hg sniper " .. sub .. " on||off")
      return
    end
    local key = sub == "skull" and "sniperSkull" or "sniperAnimate"
    local on = val == "on" or (val == "" and not Core.On(key))
    Core.SetFeature(key, on)
    say(ns.Locale:Format("highground.display.sniper_value2_value4_value5.751167", { value2 = (sub == "skull" and "skull" or "animation"), value4 = (on and "on" or "off"), value5 = (sub == "animate" and on and Core.ReducedMotion() and ns.Locale:Get("highground.display.reduced_motion_keeps_it_steady.885a25") or "") }))
  elseif sub == "style" then
    if Core.SetSniperStyle(val) then say(ns.Locale:Format("highground.display.sniper_style_val.79eadb", { val = val }))
    else say("/hg sniper style layered||legacy") end
  elseif sub == "place" then
    if Core.SetSniperPlacement(val) then
      say(ns.Locale:Format("highground.display.sniper_placement_value2_hg_sniper_x_n.2d8714", { value2 = Core.SniperPlacement().label }))
    else say("/hg sniper place body||head||left||right||above") end
  elseif (sub == "x" or sub == "y" or sub == "padding") and tonumber(val) then
    local key = sub == "padding" and "sniperPadding" or (sub == "x" and "sniperX" or "sniperY")
    Core.SetSniperNumber(key, tonumber(val))
    say(ns.Locale:Format("highground.display.sniper_sub_value4_px_value6.a89a86", { sub = sub, value4 = Core.db[key], value6 = (sub == "padding" and ns.Locale:Get("highground.display.left_right_and_above_placements.12acf7") or ns.Locale:Get("highground.display.positive_right_up.373565")) }))
  elseif sub == "size" and tonumber(val) then
    Core.SetSniperNumber("sniperScale", tonumber(val))
    say(ns.Locale:Format("highground.display.sniper_size_x_core_db_sniperscale.cd3631", { Core_db_sniperScale = Core.db.sniperScale }))
  elseif sub == "sound" then
    -- 0 turns off the lock-on Sound switch; a sound number picks it and
    -- turns the switch back on.
    local n = tonumber(val)
    if n == 0 then
      ns.Alerts.SetChannel("lockon", "sound", false)
      say(ns.Locale:Format("highground.display.lock_on_sound_value2.598f52", { value2 = ns.Locale:Get("highground.profileassignments.off.e3de5a") }))
    elseif n and ns.Alerts.SetSound("lockon", n) then
      ns.Alerts.SetChannel("lockon", "sound", true)
      ns.Alerts.Play("lockon")
      say(ns.Locale:Format("highground.display.lock_on_sound_value2.598f52", { value2 = Core.SNIPER_SOUNDS[n].name }))
    else
      local list = {}
      for i, snd in ipairs(Core.SNIPER_SOUNDS) do
        list[#list + 1] = i .. "=" .. snd.name
      end
      say(ns.Locale:Format("highground.display.hg_sniper_sound_n_value2_0_off.cae351", { value2 = table.concat(list, ", ") }))
    end
  elseif sub == "why" then
    -- Each step the scope needs, stopping at the first that fails.
    local function check(ok, pass, fail)
      say((ok and ns.Locale:Format("highground.display.value1_ok_r.c45783", { value1 = Hex("success") }) or ns.Locale:Format("highground.display.value1_no_r.ff781c", { value1 = Hex("error") })) .. (ok and pass or fail))
      return ok
    end
    if not check(Core.On("sniper"), ns.Locale:Get("highground.display.scope_switched_on.048251"), ns.Locale:Get("highground.display.scope_switched_off_hg_sniper_turns_it.0058f1")) then return end
    if not check(UnitExists("target"), ns.Locale:Get("highground.display.you_have_a_target.11fd8f"), ns.Locale:Get("highground.display.no_target.b46e11")) then return end
    if not check(C_NamePlate and C_NamePlate.GetNamePlateForUnit, ns.Locale:Get("highground.display.nameplate_api_present.b9bde7"),
      ns.Locale:Get("highground.display.this_client_has_no_nameplate_api.2c4a1f")) then return end
    local okP, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if not check(okP and plate, ns.Locale:Get("highground.display.target_has_a_nameplate.46e6c8"),
      ns.Locale:Get("highground.display.the_game_reports_no_nameplate_for_your.6ca709")) then return end
    if not check(not (plate.IsForbidden and plate:IsForbidden()), ns.Locale:Get("highground.display.nameplate_is_usable.1b2e05"), ns.Locale:Get("highground.display.nameplate_is_forbidden_to_addons_here.29f9d8")) then return end
    local unit = Core.TargetPlateUnit()
    check(unit ~= nil, ns.Locale:Format("highground.display.nameplate_unit_token_value2.536812", { value2 = tostring(unit) }),
      ns.Locale:Get("highground.display.no_nameplate_unit_token_plate_nameplateunittoken_missing.dd7e8b"))
    check(Core.sniper.anchor ~= nil, ns.Locale:Format("highground.display.scope_has_a_nameplate_anchor_value2.57c736", { value2 = Core.SniperPlacement().label }),
      ns.Locale:Get("highground.display.scope_has_no_nameplate_anchor_try_hg.09667f"))
    check(Core.sniper:IsShown(), ns.Locale:Get("highground.display.scope_is_showing.e07edd"), ns.Locale:Get("highground.display.scope_is_hidden_try_hg_sniper_test.e498d1"))
    if Core.active and not Core.sniperTest.on then
      say(ns.Locale:Format("highground.display.in_a_match_the_scope_marks_the.aaeb4b", { value2 = (Core.killNow and Core.killNow.display or ns.Locale:Get("highground.display.none_in_reach.550fd5")) }))
    end
  elseif sub == "" then
    local on = Core.SetFeature("sniper", not Core.On("sniper"))
    say(ns.Locale:Format("highground.display.sniper_scope_over_the_value2_value4_hg.de3545", { value2 = (Core.PriorityOn() and ns.Locale:Get("highground.display.kill_target.0d01b7") or ns.Locale:Get("highground.display.your_target.487d8f")), value4 = (on and "on" or "off") }))
  else
    say("/hg sniper [test||why||style layered||legacy||place body||head||left||right||above||padding N||x N||y N||color NAME||size X||sound N||skull on||off||animate on||off]")
  end
end

function Commands.sound(arg, msg, say)
  local on = Core.SetFeature("sound", not Core.On("sound"))
  say(ns.Locale:Format("highground.display.highground_sounds_value2.9814c6", { value2 = (on and "on" or "off") }))
end

function Commands.go(arg, msg, say)
  if Core.sniperTest.on then
    Core.sniperTest.go = not Core.sniperTest.go
    if Core.sniperTest.go and Core.On("sound") then
      Core.PlayGoSound()
    end
    say(ns.Locale:Format("highground.display.sniper_test_kill_window_look_value2.d9b790", { value2 = (Core.sniperTest.go and "on" or "off") }))
    return
  end
  local top = Core.order[1]
  if top then
    top.burnedAt = GetTime()
    top.range = top.range or "attack"
    top.def, top.cc, top.dead = false, false, false
    if Core.testMode then
      Core.Tick()
    end
    say(ns.Locale:Format("highground.display.kill_window_preview_on_top_display_value3.f8bccc", { top_display = top.display, value3 = (Core.testMode and "" or ns.Locale:Get("highground.display.live_data_may_override.952d01")) }))
  else
    say(ns.Locale:Get("highground.display.no_enemies_listed_try_hg_bg_test.d158ab"))
  end
end

function Commands.lock(arg, msg, say)
  Core.SetPanelsLocked(true)
  say("locked")
end

function Commands.unlock(arg, msg, say)
  Core.SetPanelsLocked(false)
  say(InCombatLockdown() and ns.Locale:Get("highground.display.unlocked_drag_panel_headers_after_combat.de173e") or ns.Locale:Get("highground.display.unlocked_drag_panel_headers_to_move.57df3c"))
end

function Commands.reset(arg, msg, say)
  -- The main panel holds secure buttons: it cannot move in combat.
  if InCombatLockdown() then return say(ns.Locale:Get("highground.display.leave_combat_first.8497e3")) end
  Core.pos.point = nil
  Core.PlaceDockHead(Core.frame)
end
