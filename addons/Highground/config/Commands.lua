local _, ns = ...
-- Addons publish their own catalogs. This registry supplies every reference,
-- UI action and dispatch owner; it does no polling or gameplay work.
local C = { groups = {}, commands = {}, previews = {}, byCommand = {}, byId = {}, owners = {} }
ns.CommandCatalog = C

function C.Action(command, description, label, options)
  local row = options or {}
  row.command, row[2] = command, description
  row[1] = "/hg" .. (command ~= "" and " " .. command or "") .. (row.usage and " " .. row.usage or "")
  row.ui = { label = label, command = command }
  return row
end
function C.Link(command, description, page, label, options)
  local row = C.Action(command, description, label, options)
  row.ui = { label = label, page = page }
  return row
end
function C.Register(owner, label, rows, previews)
  local group = { owner = owner, label = label, commands = rows, previews = previews or {} }
  C.groups[#C.groups + 1] = group
  C.commands[#C.commands + 1] = { label }
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
  A("", "Open or close the Highground window.", "Open / close Highground"),
  A("help", "List available commands and your detected specialization in chat.", "Print command help"),
  A("test", "Toggle available previews across enabled addons, keeping existing samples when starting the set.", "Toggle all addon previews", { aliases = { "test all" } }),
  A("test stop", "Stop all addon previews, including samples started individually.", "Stop all previews"),
  L("config", "Open a Highground page; config blizzard opens Blizzard settings.", "home", "Browse Highground", { usage = "[PAGE|blizzard]", aliases = { "options" } }),
  A("config blizzard", "Open the native Blizzard addon settings panel.", "Open Blizzard settings"),
  L("setup", "Choose playstyle presets and place panels.", "setup", "Open playstyle presets"),
  L("guide", "Browse Addons or start and resume a specific walkthrough.", "addons", "Open Addons and guides", { usage = "[FEATURE]", aliases = { "checklist" } }),
  L("alerts", "Choose alert presets and text/sound preferences.", "alerts", "Open alert controls"),
  L("users", "Inspect channel members, addon versions and discovery status.", "users", "Open addon users"),
  A("users why", "Copy discovery diagnostics, channel membership and retry state.", "Copy discovery diagnostics"),
  A("guide users", "Explore channel discovery with isolated sample members.", "Start addon users guide"),
  A("lock", "Lock all HUD panels in place.", "Lock panels"),
  A("unlock", "Show panel headers for dragging outside combat.", "Unlock panels"),
  L("scale", "Set the master HUD scale.", "general", "Adjust master scale", { usage = "N" }),
  L("opacity", "Set the background opacity of HUD panels, in percent.", "appearance", "Adjust background opacity", { usage = "PCT" }),
  L("sound", "Toggle the master Highground sound preference.", "general", "Master sound control"),
  L("theme", "List themes or select a theme by name.", "appearance", "Choose a theme", { usage = "[NAME]" }),
  L("profile", "List profiles; save or update with a complete review, load a saved copy, or delete a profile except Default.", "profiles", "Manage saved profiles", { usage = "[save|load|delete|share NAME]" }),
  A("profile share", "Prepare a chat link for your current setup or a named profile.", "Share a setup", { usage = "[NAME]", fields = { { label = "Profile name (blank = current setup)", optional = true } } }),
  A("export", "Choose current settings or a saved copy to export or share in chat.", "Export settings", { usage = "[NAME]", fields = { { label = "Profile name (blank = current setup)", optional = true } } }),
  L("import", "Review or import a settings code, preserving its case.", "profiles", "Import a profile", { usage = "[CODE]" }),
  A("err", "Print recorded errors and diagnostic counters in chat.", "Show errors in chat"),
  A("clearerr", "Clear recorded errors.", "Clear recorded errors", { confirm = "Clear all recorded errors?" }),
  A("perf", "Print the latest performance capture in chat.", "Show performance report"),
  A("perf start", "Capture callback allocations, time and FPS for 60 seconds.", "Start performance capture"),
  A("perf stop", "Finish the current performance capture early.", "Stop performance capture"),
  A("probe", "Print the information Highground can read from your target.", "Inspect target in chat"),
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
    if value == "" and not field.optional then return nil, "Enter " .. field.label .. "." end
    if value:find("[\r\n]") then return nil, field.label .. " must be one line." end
    local choices = C.Choices(field)
    if choices then
      local found
      for _, choice in ipairs(choices) do if choice.key == value then found = true end end
      if not found then return nil, "Choose " .. field.label .. "." end
    elseif field.kind == "number" or field.kind == "number-or-reset" and value ~= "reset" then
      local n = tonumber(value)
      if not n or n ~= n or n == math.huge or n == -math.huge or field.min and n < field.min or field.max and n > field.max
        or field.integer and n ~= math.floor(n) then return nil, "Enter a valid " .. field.label .. "." end
    end
    if value ~= "" then parts[#parts + 1] = value end
  end
  return table.concat(parts, " ")
end
