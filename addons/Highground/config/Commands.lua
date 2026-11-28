local _, ns = ...
-- Addons publish their own catalogs. This registry supplies every reference,
-- UI action and dispatch owner; it does no polling or gameplay work.
local C = { groups = {}, commands = {}, previews = {}, byCommand = {}, byId = {}, owners = {} }
ns.CommandCatalog = C

function C.Action(command, description, label, options)
  local row = options or {}
  row.command = command
  row.descriptionKey, row.labelKey = row.descriptionKey or description, row.labelKey or label
  row[1] = "/hg" .. (command ~= "" and " " .. command or "") .. (row.usage and " " .. row.usage or "")
  ns.Localization.Define(row, { [2] = row.descriptionKey or description })
  row.ui = ns.Localization.Define({ command = command }, { label = row.labelKey or label })
  return row
end
function C.Description(row) return row.descriptionKey and ns.Locale:Get(row.descriptionKey) or row[2] end
function C.Label(row) return row.labelKey and ns.Locale:Get(row.labelKey) or row.ui.label end
function C.Link(command, description, page, label, options)
  local row = C.Action(command, description, label, options)
  row.ui.command, row.ui.page = nil, page
  return row
end
-- options.toolArg is passed to the tool's opener (a journal filter).
function C.Tool(command, description, tool, label, options)
  local row = C.Action(command, description, label, options)
  row.ui.command, row.ui.tool, row.ui.toolArg = nil, tool, row.toolArg
  return row
end
function C.Register(owner, label, rows, previews)
  local group = ns.Localization.Define({ owner = owner, commands = rows, previews = previews or {} }, { label = label })
  C.groups[#C.groups + 1] = group
  C.commands[#C.commands + 1] = ns.Localization.Define({}, { [1] = label })
  for _, row in ipairs(rows) do
    row.id = row.id or row.command
    assert(not C.byId[row.id], "Duplicate command ID: " .. row.id)
    C.byId[row.id] = row
    row.owner = owner
    C.byCommand[row.command] = C.byCommand[row.command] or row
    C.commands[#C.commands + 1] = row
    if owner ~= "shared" then
      C.owners[row.command] = owner
      local head = row.command:match("^%S+")
      if not C.byCommand[head] or C.byCommand[head].owner ~= "shared" then C.owners[head] = owner end
    end
    for _, alias in ipairs(row.aliases or {}) do
      assert(not C.byCommand[alias], "Duplicate alias: " .. alias)
      C.byCommand[alias] = row
      if owner ~= "shared" then C.owners[alias] = owner end
    end
  end
  for _, preview in ipairs(group.previews) do
    preview.module = owner
    C.previews[#C.previews + 1] = preview
  end
  if ns.Modules and ns.Modules.byKey[owner] then ns.Modules.byKey[owner].commands = rows end
end

local A, L = C.Action, C.Link
C.Register("shared", "Highground", {
  A("", "commands.configuration.toggle", "highground.commands.open_close_highground.2b34cd"),
  A("help", "highground.commands.list_available_commands_and_your_detected_specialization.e61f2e", "highground.commands.print_command_help.1cacbc"),
  A("test", "highground.commands.toggle_available_previews_across_enabled_addons_keeping.877f4c", "highground.commands.toggle_all_addon_previews.27a82f", { aliases = { "test all" } }),
  A("test stop", "highground.commands.stop_all_addon_previews_including_samples_started.eb3aae", "highground.commands.stop_all_previews.317d8b"),
  L("config", "commands.configuration.open", "home", "highground.commands.browse_highground.def826", { usage = "[PAGE|blizzard]", aliases = { "options" } }),
  A("config blizzard", "highground.commands.open_the_native_blizzard_addon_settings_panel.883cf3", "highground.commands.open_blizzard_settings.2c91f1"),
  L("setup", "highground.commands.choose_playstyle_presets_and_place_panels.7f827e", "setup", "highground.commands.open_playstyle_presets.c74b26"),
  L("guide", "highground.commands.browse_addons_or_start_and_resume_a.950156", "addons", "highground.commands.open_addons_and_guides.d3ec2d", { usage = "[FEATURE]", aliases = { "checklist" } }),
  L("alerts", "highground.commands.choose_alert_presets_and_text_sound_preferences.236bfa", "alerts", "highground.commands.open_alert_controls.6f3752"),
  A("alerts sound", "alerts.sound.command", "alerts.sound.command_label", { usage = "ALERT [SOUND]", fields = {
    ns.Localization.Define({ label = ns.Locale:Get("alerts.sound.field_alert"), choices = function()
      local choices = {}
      for _, def in ipairs(ns.Alerts.categories) do
        if ns.Alerts.Choosable(def.key) then choices[#choices + 1] = { key = def.key, label = def.label } end
      end
      return choices
    end }, { label = "alerts.sound.field_alert" }),
    ns.Localization.Define({ label = ns.Locale:Get("alerts.sound.field_sound"), choices = function()
      local choices = {}
      for _, sound in ipairs(ns.Alerts.sounds) do
        if sound.player() then choices[#choices + 1] = { key = sound.key, label = ns.Alerts.SoundLabel(sound.key) } end
      end
      return choices
    end }, { label = "alerts.sound.field_sound" }) } }),
  A("alerts preset", "alerts.preset.command", "alerts.preset.command_label", { usage = "NAME", fields = {
    ns.Localization.Define({ label = ns.Locale:Get("alerts.preset.field"), choices = function() return ns.Alerts.PresetChoices() end }, { label = "alerts.preset.field" }) } }),
  L("users", "highground.commands.inspect_channel_members_addon_versions_and_discovery.591f3b", "users", "highground.commands.open_addon_users.1c5288"),
  A("users why", "highground.commands.copy_discovery_diagnostics_channel_membership_and_retry.b61693", "highground.commands.copy_discovery_diagnostics.ddf2f8"),
  A("guide users", "highground.commands.explore_channel_discovery_with_isolated_sample_members.cad9c5", "highground.commands.start_addon_users_guide.9bc078"),
  A("lock", "highground.commands.lock_all_hud_panels_in_place.09f95e", "highground.commands.lock_panels.6d05de"),
  A("unlock", "highground.commands.show_panel_headers_for_dragging_outside_combat.765de8", "highground.commands.unlock_panels.fc32e8"),
  L("scale", "highground.commands.set_the_master_hud_scale.22cf24", "general", "highground.commands.adjust_master_scale.5eded8", { usage = "N" }),
  L("opacity", "highground.commands.set_the_background_opacity_of_hud_panels.410456", "appearance", "highground.commands.adjust_background_opacity.e90a2c", { usage = "PCT" }),
  L("sound", "highground.commands.toggle_the_master_highground_sound_preference.28df20", "general", "highground.commands.master_sound_control.3d795e"),
  L("theme", "highground.commands.list_themes_or_select_a_theme_by.cefae5", "appearance", "highground.commands.choose_a_theme.3fdb3a", { usage = "[NAME]" }),
  L("profile", "profiles.commands.manage", "profiles", "profiles.page.title", { usage = "[ADDON]" }),
  L("profile copy", "profiles.commands.copy", "profiles", "profiles.commands.copy_label", { usage = "ADDON NAME" }),
  L("profile delete", "profiles.commands.delete", "profiles", "profiles.commands.delete_label", { usage = "NAME" }),
  L("profile share", "profiles.commands.share", "profiles", "profiles.share.chat", { usage = "[ADDON]" }),
  L("export", "profiles.commands.export", "profiles", "profiles.page.export", { usage = "[ADDON]" }),
  L("import", "profiles.commands.import", "profiles", "profiles.page.import", { usage = "[CODE]" }),
  A("err", "highground.commands.print_recorded_errors_and_diagnostic_counters_in.7e7664", "highground.commands.show_errors_in_chat.49dd1c"),
  A("clearerr", "highground.commands.clear_recorded_errors.dc03e0", "highground.commands.clear_recorded_errors.12b928", ns.Localization.Define({ confirm = ns.Locale:Get("highground.commands.clear_all_recorded_errors.92b34e") }, { confirm = "highground.commands.clear_all_recorded_errors.92b34e" })),
  A("perf", "highground.commands.print_the_latest_performance_capture_in_chat.11de69", "highground.commands.show_performance_report.27a0b2"),
  A("perf start", "highground.commands.capture_callback_allocations_time_and_fps_for.cf2081", "highground.commands.start_performance_capture.7d39ef"),
  A("perf stop", "highground.commands.finish_the_current_performance_capture_early.c1aa46", "highground.commands.stop_performance_capture.b6dd77"),
  A("probe", "highground.commands.print_the_information_highground_can_read_from.4908eb", "highground.commands.inspect_target_in_chat.130eb8"),
})

-- Resolve the most specific documented route, falling back to its parent.
-- This also covers invalid arguments without letting them bypass module guards.
function C.Owner(message)
  local path = (message or ""):lower():match("^%s*(.-)%s*$"):gsub("%s+", " ")
  while path ~= "" do
    if C.owners[path] or C.byCommand[path] then return C.owners[path] end
    path = path:match("^(.*) %S+$") or ""
  end
end
-- The catalog row a typed command runs (longest matching command).
function C.Row(message)
  local path = (message or ""):lower():match("^%s*(.-)%s*$"):gsub("%s+", " ")
  while path ~= "" do
    if C.byCommand[path] then return C.byCommand[path] end
    path = path:match("^(.*) %S+$") or ""
  end
end
function C.Choices(field)
  local source = type(field.choices) == "function" and field.choices() or field.choices
  if not source then return end
  local choices = {}
  for i, value in ipairs(source) do
    choices[i] = type(value) == "table" and value or { key = value, label = value }
  end
  return choices
end
function C.Format(row, values)
  local parts = { row.command }
  for i, field in ipairs(row.fields or {}) do
    local value = tostring(values and values[i] or ""):match("^%s*(.-)%s*$")
    if value == "" and not field.optional then return nil, ns.Locale:Format("highground.commands.enter_field_label.f736e0", { field_label = field.label }) end
    if value:find("[\r\n]") then return nil, ns.Locale:Format("highground.commands.field_label_must_be_one_line.eee60f", { field_label = field.label }) end
    local choices = C.Choices(field)
    if choices then
      local found
      for _, choice in ipairs(choices) do if choice.key == value then found = true end end
      if not found then return nil, ns.Locale:Format("highground.commands.choose_field_label.106807", { field_label = field.label }) end
    elseif field.kind == "number" or field.kind == "number-or-reset" and value ~= "reset" then
      local n = tonumber(value)
      if not n or n ~= n or n == math.huge or n == -math.huge or field.min and n < field.min or field.max and n > field.max
        or field.integer and n ~= math.floor(n) then return nil, ns.Locale:Format("highground.commands.enter_a_valid_field_label.8121fc", { field_label = field.label }) end
    end
    if value ~= "" then parts[#parts + 1] = value end
  end
  return table.concat(parts, " ")
end
