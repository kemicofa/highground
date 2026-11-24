local _, ns = ...
local Core, Options, Commands = ns.Core, ns.Options, ns.Commands
local Hex = ns.Theme.TipHex -- chat

-- One usage line from a command's catalog entry: its syntax, then what it
-- does. Pipes are doubled so chat shows them instead of reading escapes.
local function Usage(id)
  local C = ns.CommandCatalog
  local row = C.byId[id]
  return (row[1]:gsub("|", "||")) .. "  " .. C.Description(row)
end

-- The Highground window pages that list scoring values, in sidebar order.
local function ScoringPages()
  local names = {}
  for _, def in ipairs(Core.POINTS) do
    local page = def.group and Options.pointPages[def.page]
    if page then names[#names + 1] = page.name end
  end
  return table.concat(names, ", ")
end

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
    say(ok and ns.Locale:Format(Options.Profiles.pending and "highground.settings.loaded_profile_rawname_applies_after_combat.eeb6f7"
      or "highground.settings.loaded_profile_rawname.bc00e8", { rawName = rawName }) or err or (ns.Locale:Format("highground.settings.no_profile_named_rawname.754bf3", { rawName = rawName })))
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
    say("/hg profile save||load||delete||share NAME, /hg export, /hg import")
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
    if key and k:lower() == key:lower() and Core.PointAvailable(k) then
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
    say(ns.Locale:Format("highground.settings.unknown_scoring_value_in_hg_config_see.b49c0d", { addon = ns.Modules.byKey.battlegrounds.name, pages = ScoringPages() }))
  elseif val == "" then
    -- Show the value; only an explicit "reset" resets it.
    local v = (Core.db.points or {})[real] or Core.POINT_DEFAULT[real]
    say(ns.Locale:Format("highground.settings.k_value2_default_value3.000f55", { k = real, value2 = Options.Format(v),
      value3 = Options.Format(Core.POINT_DEFAULT[real]) }))
    say(Usage("points-value"))
  elseif val == "reset" then
    local ok, err = Core.SetTuning("point", real, Core.POINT_DEFAULT[real])
    if not ok then say(err); return end
    say(ns.Locale:Format("highground.settings.real_reset_to_value3.553ad8", { real = real, value3 = Options.Format(Core.POINT_DEFAULT[real]) }))
    Options.PointsChanged()
  elseif tonumber(val) then
    local ok, err = Core.SetTuning("point", real, tonumber(val))
    if not ok then say(err); return end
    say(real .. " = " .. val)
    Options.PointsChanged()
  else
    say(Usage("points-value"))
  end
end

function Commands.weights(arg, msg, say)
  for _, w in ipairs(Core.WEIGHTS) do
    if ns.OptionAvailable(w) then say(ns.Locale:Format("highground.settings.w_key_x_value2_value3_w_desc.d9a463", { w_key = string.format("%-9s", w.key), value2 = string.format("%.1f", Core.W(w.key)), value3 = string.format("%s", Hex("textMuted")), w_desc = string.format("%s", w.desc) })) end
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
      if w.key == name and ns.OptionAvailable(w) then
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
  if not tonumber(arg) then return say(Usage("rows")) end
  if not Core.SetRows(arg) then return say(ns.Locale:Format("highground.settings.choose_a_whole_number_of_enemies_from.8566b5", { Core_MAX_ROWS = Core.MAX_ROWS })) end
  say(ns.Locale:Format("highground.settings.enemies_shown_core_db_rows_value3.efd93e", { Core_db_rows = Core.db.rows, value3 = (InCombatLockdown() and ns.Locale:Get("highground.settings.updates_after_combat.f25c8c") or "") }))
end

function Commands.scale(arg, msg, say)
  if not tonumber(arg) then return say(Usage("scale")) end
  local applied = ns.SetUIScale(tonumber(arg))
  say(ns.Locale:Format(applied and "highground.settings.ui_scale_scale.c5adb8" or "highground.settings.ui_scale_scale_applies_after_combat.e090f1",
    { scale = string.format("%d", math.floor(Core.db.scale * 100 + 0.5)) }))
end

function Commands.compact(arg, msg, say)
  local on = arg == "on" or (arg ~= "off" and not Core.IsCompact())
  Core.SetFeature("compact", on)
  local applied = Core.compact == on -- in combat the layout waits
  say(ns.Locale:Get(on and (applied and "highground.settings.compact_layout_on.c07ef3" or "highground.settings.compact_layout_on_applies_after_combat.bc8a1e")
    or (applied and "highground.settings.compact_layout_off.c27b9b" or "highground.settings.compact_layout_off_applies_after_combat.1b684a")))
end

-- /hg nameplates [range YARDS | all on|off | friends on|off]: the game's
-- nameplate settings that markers need (ns.Nameplates in ui/HealerMarks.lua).
function Commands.nameplates(arg, msg, say)
  local N = ns.Nameplates
  local sub, value = arg:match("^(%S*)%s*(%S*)")
  if sub == "range" then
    local yards = tonumber(value)
    if not yards then return say(Usage("nameplates range")) end
    local kept, err = N.Set("range", yards)
    if not kept then return say(err, "error") end
    local R = N.RANGE
    if yards < R.min or yards > R.max then
      say(ns.Locale:Format("highground.addonpages.min_to_max_yards_the_game_may.2934d3", { min = R.min, max = R.max }))
    elseif kept < math.floor(yards + 0.5) then
      say(ns.Locale:Format("highground.settings.the_game_limits_nameplate_range_to_range.0a158f", { range = string.format("%d", kept) }))
    end
  elseif sub == "all" or sub == "friends" then
    if value ~= "on" and value ~= "off" then return say(Usage("nameplates " .. sub)) end
    local kept, err = N.Set(sub, value == "on")
    if kept == nil then return say(err, "error") end
  end
  local function State(key)
    local on = N.Get(key)
    if on == nil then return "?" end
    return ns.Locale:Get(on and "shared.copy.on.db3d40" or "shared.copy.off.ad5048")
  end
  local yards = N.Get("range")
  say(ns.Locale:Format("highground.settings.nameplates_range_range_yards_always_show_all.36b388",
    { range = yards and string.format("%d", yards) or "?", all = State("all"), friends = State("friends") }))
end

function Commands.opacity(arg, msg, say)
  if not tonumber(arg) then return say(Usage("opacity")) end
  ns.SetBgAlpha(tonumber(arg) / 100)
  say(ns.Locale:Format("highground.settings.background_opacity_value1.68cc4a", { value1 = string.format("%d", math.floor(Core.BgAlpha() * 100 + 0.5)) }))
end

function Commands.exec(arg, msg, say)
  if not tonumber(arg) then return say(Usage("exec")) end
  local ok, err = Core.SetTuning("option", "executePct", tonumber(arg) / 100)
  if not ok then say(err); return end
  Options.PointsChanged()
  say(ns.Locale:Format("highground.settings.execute_highlight_below_value1.7bf2ca", { value1 = string.format("%d", math.floor(Core.db.executePct * 100 + 0.5)) }))
end

Commands.options = Commands.config

-- /hg nearby [on | off | map on|off | share on|off | share guild on|off | fights on|off |
-- tracking on|off | track NAME | untrack NAME | tracked | watch on|off |
-- mark TYPE|clear | marks on|off | marks world on|off | calls on|off | feed on|off |
-- test | clear | forget]: the open-world enemy list (world/Nearby.lua), its
-- map pins and shared sightings (world/Map.lua, world/Share.lua), tracked
-- enemies (world/Tracking.lua), map marks and calls (world/Marks.lua,
-- world/Calls.lua) and its saved history (world/History.lua).
local NEARBY_SWITCHES = {
  ["on"] = "nearby", ["off"] = "nearby",
  ["map on"] = "nearbyMap", ["map off"] = "nearbyMap",
  ["share on"] = "nearbyShare", ["share off"] = "nearbyShare",
  ["share guild on"] = "nearbyShareGuild", ["share guild off"] = "nearbyShareGuild",
  ["tracking on"] = "nearbyTrack", ["tracking off"] = "nearbyTrack",
  ["marks on"] = "nearbyMarks", ["marks off"] = "nearbyMarks",
  ["calls on"] = "nearbyCalls", ["calls off"] = "nearbyCalls",
  ["feed on"] = "nearbyFeed", ["feed off"] = "nearbyFeed",
  ["fights on"] = "worldFights", ["fights off"] = "worldFights",
}

-- /hg nearby mark enemies|ganker|help: at your position; mark clear: yours.
local function Mark(kind, say)
  local Marks = ns.WorldMarks
  if not Marks then return say(ns.Locale:Get("tracking.unavailable")) end
  if kind == "clear" then return say(ns.Locale:Format("marks.cleared", { count = Marks.Clear() })) end
  local m, why = Marks.Here(kind)
  say(m and ns.Locale:Format("marks.placed", { mark = Marks.Label(kind) }) or why)
end
local function Track(verb, typed, say)
  local T = ns.Tracking
  if not T then return say(ns.Locale:Get("tracking.unavailable")) end
  local name = typed and typed:lower() == "target" and Core.FullUnitName("target") or T.Resolve(typed)
  if not name then return say(ns.Locale:Get("tracking.usage")) end
  local ok, why = T.Set(name, verb == "track")
  say(ok and ns.Locale:Format(verb == "track" and "tracking.action.on" or "tracking.action.off",
    { name = Core.DisplayName(name) }) or why)
end

local function Tracked(say)
  local T = ns.Tracking
  if not T then return say(ns.Locale:Get("tracking.unavailable")) end
  say(T.Status())
  for _, item in ipairs(T.List()) do
    local r = item.record.report
    say("  " .. Core.DisplayName(item.key) .. (type(r) == "table" and (" — " .. T.Where(r) .. " · "
      .. ns.Util.Ago(math.max(0, time() - (r.at or time())))) or ""))
  end
end

function Commands.nearby(arg, msg, say)
  local verb = arg:match("^(%S+)")
  if verb == "track" or verb == "untrack" then
    return Track(verb, msg:match("^%S+%s+%S+%s+(.-)%s*$"), say)
  elseif arg == "tracked" then
    return Tracked(say)
  elseif arg == "watch on" or arg == "watch off" then
    Core.SetTuning("option", "nearbyTrackWorld", arg == "watch on")
  elseif arg == "marks world on" or arg == "marks world off" then
    Core.SetTuning("option", "nearbyMarksWorld", arg == "marks world on")
  elseif verb == "mark" then
    return Mark(arg:match("^mark%s+(%S+)") or "", say)
  elseif NEARBY_SWITCHES[arg] then
    Core.SetFeature(NEARBY_SWITCHES[arg], arg:match("on$") ~= nil)
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
  if ns.WorldShare then say(ns.WorldShare.Status()) end
  if ns.Tracking then say(ns.Tracking.Status()) end
  if ns.WorldMarks then say(ns.WorldMarks.Status()) end
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
    names[#names + 1] = name == Theme.Current() and ns.Locale:Format("highground.settings.name_on.dda78d", { name = name }) or name
  end
  say(ns.Locale:Format("highground.settings.themes_value2_hg_theme_name.990f59", { value2 = table.concat(names, ", ") }))
end

function Commands.setup() ns.Setup.Open() end
-- /hg alerts sound ALERT SOUND chooses and plays an alert's sound; anything
-- less lists the alerts or that alert's sounds. Lock-on keeps /hg sniper sound.
local function AlertSound(arg, say)
  local A = ns.Alerts
  local category, key = arg:match("^(%S*)%s*(%S*)")
  local def
  for _, d in ipairs(A.categories) do if d.key == category and A.Choosable(d.key) then def = d end end
  if not def then
    local keys = {}
    for _, d in ipairs(A.categories) do if A.Choosable(d.key) then keys[#keys + 1] = d.key end end
    return say(ns.Locale:Format("alerts.sound.usage", { alerts = table.concat(keys, ", ") }))
  end
  if ns.Modules and not ns.Modules.Active(def.module) then return say(ns.Locale:Get("alerts.sample.disabled")) end
  if key ~= "" and A.SetSound(def.key, key) then
    A.Play(def.key)
    return say(ns.Locale:Format("alerts.sound.set", { alert = def.label, sound = A.SoundLabel(key) }))
  end
  local list = {}
  for _, choice in ipairs(A.SoundChoices(def.key)) do list[#list + 1] = choice.key .. " = " .. choice.label end
  say(ns.Locale:Format("alerts.sound.list", { alert = def.label, sounds = table.concat(list, ", ") }))
end

-- /hg alerts preset NAME sets every alert's switches, like the Alerts
-- window's preset choice; anything else lists the presets.
local function AlertPreset(arg, say)
  local A, key = ns.Alerts, arg:lower():match("^(%S*)")
  if A.SetMode(key) then
    if A.win and A.win:IsShown() then A.win:Refresh() end
    return say(ns.Locale:Format("alerts.preset.set", { preset = A.PresetLabel(key) }))
  end
  local list = {}
  for _, choice in ipairs(A.PresetChoices()) do list[#list + 1] = choice.key .. " = " .. choice.label end
  say(ns.Locale:Format("alerts.preset.usage", { presets = table.concat(list, ", ") }))
end

function Commands.alerts(arg, msg, say)
  local sub, rest = (arg or ""):match("^(%S*)%s*(.-)$")
  if sub == "sound" then return AlertSound(rest, say) end
  if sub == "preset" then return AlertPreset(rest, say) end
  ns.Alerts.Open()
end
function Commands.history() ns.MatchHistory.Open() end
function Commands.journal() ns.EnemyJournal.Open() end
-- /hg activity: zones with recent enemies, marks and kills (world/Activity.lua).
function Commands.activity(_, _, say)
  if not ns.WorldActivity then return say(ns.Locale:Get("tracking.unavailable")) end
  ns.WorldActivity.Open()
end
function Commands.users(arg)
  if arg == "why" then return ns.Hub.CopyUsersDiagnostics() end
  ns.Hub.Show("users")
end
