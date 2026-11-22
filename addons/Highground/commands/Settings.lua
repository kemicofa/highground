local _, ns = ...
local Core, Options, Commands = ns.Core, ns.Options, ns.Commands
local Hex = ns.Theme.TipHex -- chat

-- /hg export [NAME]: a saved profile, or your current settings.
function Commands.export(arg, msg, say)
  Options.Profiles.ShowExport((msg or ""):match("^%S+%s+(.+)$") or false)
end

function Commands.import(arg, msg, say)
  if arg ~= "" then
    -- /hg import WB1;... (lowercased by the slash parser: re-read raw)
    local raw = (msg or ""):match("^%S+%s+(.+)$")
    local _, res = Options.Profiles.ImportText(raw)
    say(res)
  else
    Options.Profiles.ShowImport()
  end
end

function Commands.profile(arg, msg, say)
  local sub = arg:match("^(%S*)")
  local rawName = (msg or ""):match("^%S+%s+%S+%s+(.+)$") -- keep the name's case
  if sub == "save" and rawName then
    rawName = Options.Profiles.CleanName(rawName)
    if not rawName then return say(ns.Locale:Get("highground.settings.enter_a_profile_name.2b23a6")) end
    local P = Options.Profiles
    P.EnsureDefault()
    local ok, err = P.SaveProfile(rawName)
    if not ok then return say(err) end
    Core.db.activeProfile = rawName
    Core.db.importedProfileName = nil
    say(ns.Locale:Format("highground.settings.saved_profile_rawname.78e96f", { rawName = rawName }))
    if ns.Hub then ns.Hub.Open("profiles") else Options.Open() end
    local panel = Options.panel
    panel.SelectProfile(rawName)
  elseif sub == "load" and rawName then
    local ok, err = Options.Profiles.LoadProfile(rawName)
    say(ok and (ns.Locale:Format("highground.settings.loaded_profile_rawname_value3.70852a", { rawName = rawName, value3 = (Options.Profiles.pending and ns.Locale:Get("highground.settings.applies_after_combat.fcdc04") or "") })) or err or (ns.Locale:Format("highground.settings.no_profile_named_rawname.754bf3", { rawName = rawName })))
  elseif sub == "delete" and rawName and Core.db.profiles and Core.db.profiles[rawName] then
    local ok, problem = Options.Profiles.DeleteProfile(rawName)
    say(ok and (ns.Locale:Format("highground.settings.deleted_profile_rawname.3d3a8f", { rawName = rawName })) or problem or ns.Locale:Get("highground.settings.choose_a_saved_profile.5c404b"))
    Options.panel.RefreshProfiles()
  elseif sub == "share" then
    local _, message = Options.Profiles.Chat.ToChat(rawName)
    say(message)
  else
    local names = {}
    for n in Options.Profiles.SortedPairs(Core.db.profiles or {}) do
      names[#names + 1] = n
    end
    say(#names > 0 and (ns.Locale:Format("highground.settings.profiles_value2.8d2cc0", { value2 = table.concat(names, ", ") })) or ns.Locale:Get("highground.settings.no_saved_profiles.69bd31"))
    say("/hg profile save|load|delete|share NAME, /hg export, /hg import")
  end
end

-- /hg config: the Highground window (/hg config blizzard: the Options panel).
function Commands.config(arg, msg, say)
  if arg == "blizzard" or not ns.Hub then return Options.Open() end
  ns.Hub.Open(arg ~= "" and arg or nil)
end

function Commands.points(arg, msg, say)
  local key, val = arg:match("^(%S+)%s*(%S*)$")
  local real
  for k in pairs(Core.POINT_DEFAULT) do
    if key and k:lower() == key:lower() then
      real = k
    end
  end
  if not key then
    local n = 0
    for k, v in pairs(Core.db.points or {}) do
      n = n + 1
      say(ns.Locale:Format("highground.settings.k_value2_default_value3.000f55", { k = string.format("%s", k), value2 = string.format("%s", Options.Format(v)), value3 = string.format("%s", Options.Format(Core.POINT_DEFAULT[k] or 0)) }))
    end
    say(n == 0 and ns.Locale:Get("highground.settings.all_points_at_default_hg_config_to.c0390a") or "/hg points KEY reset")
  elseif not real then
    say(ns.Locale:Get("highground.settings.unknown_key_see_options_addons_highground.3f9b67"))
  elseif val == "reset" or val == "" then
    local ok, err = Core.SetTuning("point", real, Core.POINT_DEFAULT[real])
    if not ok then say(err); return end
    say(ns.Locale:Format("highground.settings.real_reset_to_value3.553ad8", { real = real, value3 = Options.Format(Core.POINT_DEFAULT[real]) }))
    Options.PointsChanged()
  elseif tonumber(val) then
    local ok, err = Core.SetTuning("point", real, tonumber(val))
    if not ok then say(err); return end
    say(real .. " = " .. val)
    Options.PointsChanged()
  end
end

function Commands.weights(arg, msg, say)
  for _, w in ipairs(Core.WEIGHTS) do
    say(ns.Locale:Format("highground.settings.w_key_x_value2_value3_w_desc.d9a463", { w_key = string.format("%-9s", w.key), value2 = string.format("%.1f", Core.W(w.key)), value3 = string.format("%s", Hex("textMuted")), w_desc = string.format("%s", w.desc) }))
  end
  say("/hg weight NAME X  (0-5)  |  /hg weight reset")
end

function Commands.weight(arg, msg, say)
  if arg == "" then return Commands.weights(arg, msg, say) end
  local name, val = arg:match("^(%S+)%s*(.-)$")
  if name == "reset" then
    Core.db.weights = {}
    say(ns.Locale:Get("highground.settings.all_coefficients_reset_to_1_0.4c31eb"))
  else
    local known
    for _, w in ipairs(Core.WEIGHTS) do
      if w.key == name then
        known = w
      end
    end
    local x = tonumber(val)
    if known and x then
      local ok, err = Core.SetTuning("weight", name, x)
      if not ok then say(err); return end
      say(ns.Locale:Format("highground.settings.name_coefficient_x_value2.df1f4a", { name = string.format("%s", name), value2 = string.format("%.1f", (Core.db.weights or {})[name] or 1) }))
    else
      say(ns.Locale:Get("highground.settings.unknown_weight_or_value_hg_weights_to.0d68e6"))
    end
  end
  Options.PointsChanged()
end

function Commands.live(arg, msg, say)
  Core.SetTuning("option", "liveSort", not Core.O("liveSort"))
  say(ns.Locale:Format("highground.settings.live_re_ordering_value2.b523e7", { value2 = (Core.O("liveSort") and ns.Locale:Get("highground.settings.on_defensives_cc_burst_range_move_rows.60ae03") or ns.Locale:Get("highground.settings.off_stable_order_live_state_shown_as.eef75f")) }))
  Options.PointsChanged()
end

function Commands.all(arg, msg, say)
  local on = Core.SetFeature("allBGs", not Core.db.allBGs)
  say(ns.Locale:Format("highground.settings.all_battlegrounds_value2.92ec6c", { value2 = (on and "on" or ns.Locale:Get("highground.settings.off_rated_only.3ae026")) }))
end

function Commands.rows(arg, msg, say)
  if not tonumber(arg) then return Commands.help(arg, msg, say) end
  if not Core.SetRows(arg) then return say(ns.Locale:Format("highground.settings.choose_a_whole_number_of_enemies_from.8566b5", { Core_MAX_ROWS = Core.MAX_ROWS })) end
  say(ns.Locale:Format("highground.settings.enemies_shown_core_db_rows_value3.efd93e", { Core_db_rows = Core.db.rows, value3 = (InCombatLockdown() and ns.Locale:Get("highground.settings.updates_after_combat.f25c8c") or "") }))
end

function Commands.scale(arg, msg, say)
  if not tonumber(arg) then return Commands.help(arg, msg, say) end
  local applied = ns.SetUIScale(tonumber(arg))
  say(ns.Locale:Format("highground.settings.ui_scale_value1_value2.faf6df", { value1 = string.format("%d", math.floor(Core.db.scale * 100 + 0.5)), value2 = string.format("%s", applied and "" or ns.Locale:Get("highground.settings.applies_after_combat.fcdc04")) }))
end

function Commands.compact(arg, msg, say)
  local on = arg == "on" or (arg ~= "off" and not Core.IsCompact())
  Core.SetFeature("compact", on)
  local applied = Core.compact == on -- in combat the layout waits
  say(ns.Locale:Format("highground.settings.compact_layout_value2_value3.7cdd01", { value2 = (on and "on" or "off"), value3 = (applied and "" or ns.Locale:Get("highground.settings.applies_after_combat.fcdc04")) }))
end

function Commands.opacity(arg, msg, say)
  if not tonumber(arg) then return Commands.help(arg, msg, say) end
  ns.SetBgAlpha(tonumber(arg) / 100)
  say(ns.Locale:Format("highground.settings.background_opacity_value1.68cc4a", { value1 = string.format("%d", math.floor(Core.BgAlpha() * 100 + 0.5)) }))
end

function Commands.exec(arg, msg, say)
  if not tonumber(arg) then return Commands.help(arg, msg, say) end
  local ok, err = Core.SetTuning("option", "executePct", tonumber(arg) / 100)
  if not ok then say(err); return end
  Options.PointsChanged()
  say(ns.Locale:Format("highground.settings.execute_highlight_below_value1.7bf2ca", { value1 = string.format("%d", Core.db.executePct * 100) }))
end

Commands.options = Commands.config

-- /hg nearby [on | off | test | clear | forget]: the open-world enemy list
-- (world/Nearby.lua) and its saved history (world/History.lua).
function Commands.nearby(arg, msg, say)
  if arg == "on" or arg == "off" then
    Core.SetFeature("nearby", arg == "on")
  elseif arg == "test" and ns.NearbyPreview then
    local on = ns.NearbyPreview()
    if on == nil then say(ns.Locale:Get("highground.display.leave_combat_first.8497e3")); return end
    say(ns.Locale:Format("highground.settings.nearby_enemies_preview_value2.57bba2", { value2 = (on and ns.Locale:Get("highground.settings.on_drag_it_into_place_hg_nearby.5134ee") or "off") }))
    return
  elseif arg == "clear" and ns.NearbyClear then
    ns.NearbyClear()
    say(ns.Locale:Get("highground.settings.nearby_enemies_cleared.49b891"))
    return
  elseif arg == "forget" and ns.NearbyHistory then
    ns.NearbyHistory.Clear()
    say(ns.Locale:Get("highground.settings.enemy_history_forgotten.8eb942"))
    return
  end
  local n = 0
  for _ in pairs(ns.Nearby and ns.Nearby.seen or {}) do n = n + 1 end
  say(ns.Locale:Format("highground.settings.nearby_enemies_value2_n_remembered_hg_nearby.874130", { value2 = (Core.On("nearby") and "on" or "OFF"), n = n }))
end

-- /hg theme [NAME]: list the themes, or switch to one (saved).
function Commands.theme(arg, msg, say)
  local Theme = ns.Theme
  if arg ~= "" then
    local found -- the command arrives lowercased: match names in any case
    for _, name in ipairs(Theme.Names()) do
      if name:lower() == arg then found = name end
    end
    if not (found and Theme.Use(found)) then
      say(ns.Locale:Format("highground.settings.no_theme_named_arg_hg_theme_lists.4ed863", { arg = arg }), "error")
      return
    end
    Options.RefreshAllRows()
    say(ns.Locale:Format("highground.settings.theme_value2.85ee12", { value2 = Theme.Label(found) }))
    return
  end
  local names = {}
  for _, name in ipairs(Theme.Names()) do
    names[#names + 1] = name .. (name == Theme.Current() and ns.Locale:Get("highground.settings.on.199d33") or "")
  end
  say(ns.Locale:Format("highground.settings.themes_value2_hg_theme_name.990f59", { value2 = table.concat(names, ", ") }))
end

function Commands.setup() ns.Setup.Open() end
function Commands.alerts() ns.Alerts.Open() end
function Commands.history() ns.MatchHistory.Open() end
function Commands.journal() ns.EnemyJournal.Open() end
function Commands.users(arg)
  if arg == "why" then return ns.Hub.CopyUsersDiagnostics() end
  ns.Hub.Show("users")
end
