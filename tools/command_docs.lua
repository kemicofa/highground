-- Run from addons/Highground. The manifest defines the catalog inventory.
local mode = ...
local ns = {}
for line in io.lines("Highground_Cata.toc") do
  if line:match("^libs/locale/") or line == "config/Commands.lua" or line:match("^features/[^/]+/config/Commands.lua$") then
    assert(loadfile(line))("Highground", ns)
  end
end
local lines = {
  "# Commands", "", "[Documentation](README.md) · [Highground overview](../README.md)", "",
  "Generated from the addon-owned command catalogs by `luajit ../../tools/command_docs.lua`. Each addon's **Commands** page shows its entries and UI controls; **Help and commands** combines them. `/hg help` prints the same catalog. `/highground` works like `/hg`.", "",
  "Words in capitals are values; `a|b` means a choice. UI links open the relevant settings or editor. Action buttons run the same handlers as chat commands, with labeled fields when needed. Disabled addons keep their reference visible in the combined list, but actions are unavailable until enabled and reloaded.", "",
  "`/hg config PAGE` accepts page keys or sidebar labels, including `nearby-commands`, `bounties-commands` and `tools`. Unknown commands print help. Standalone addons are deprecated; these are the supported Highground commands. Shared-bounty examples are in the [user guide](user-guide.md#shared-bounties).", "",
}
local function Add(line) lines[#lines + 1] = line end
local function Escape(text) return (text:gsub("|", "\\|")) end
local function Availability(row)
  return row.cata and " (Cata)" or row.caps == "spellRanks" and " (WoW Forever)" or row.caps and (" (requires " .. row.caps .. ")") or ""
end
for _, group in ipairs(ns.CommandCatalog.groups) do
  Add("## " .. group.label); Add("")
  Add("| Command | What it does | UI equivalent |"); Add("| --- | --- | --- |")
  for _, row in ipairs(group.commands) do
    local syntax = "`" .. Escape(row[1]) .. "`"
    for _, alias in ipairs(row.aliases or {}) do syntax = syntax .. " · `/hg " .. Escape(alias) .. "`" end
    Add("| " .. syntax .. " | " .. Escape(ns.CommandCatalog.Description(row)) .. Availability(row) .. " | " .. row.ui.label
      .. (row.ui.page and (" → `" .. row.ui.page .. "`") or row.ui.tool and " (separate window)" or "") .. " |")
  end
  Add("")
end
Add("## Previews"); Add("")
Add("Use each addon's **Previews and guide** page to start and stop samples. Open it from the addon's sidebar section, or choose **Visit** in **Addons**, then **Previews and guide**. Bounties also offers each sample scene there. Preview records stay separate from real records; panel positions can intentionally be saved."); Add("")
Add("`/hg bg test` toggles the battleground enemy list, target card, timers, objectives and flag carrier samples using your settings; `/hg bg test stop` ends them. `/hg test` and `/hg test all` start the catalogued previews across enabled addons, keeping existing samples on. Repeat either command to stop the set, or use `/hg test stop` to stop all samples. **Help and commands** provides **Toggle all addon previews** and **Stop all previews**. Start outside combat, matches, duels and active guides or panel placement. Managed samples stop on combat, incoming duel requests, PvP instances and guide/placement handoffs. Bounties starts its wanted-poster scene unless another bounty sample is already running. Macros and Reputation use their guides and real tools instead of test toggles."); Add("")
Add("| Preview | Command | What it shows |"); Add("| --- | --- | --- |")
for _, row in ipairs(ns.CommandCatalog.previews) do
  Add("| " .. row.label .. " | `/hg " .. row.cmd .. "` | " .. row.desc .. Availability(row) .. " |")
end
Add(""); Add("## Key bindings"); Add("")
Add("Under **Key Bindings → AddOns → Highground**, bind targeting, focus, ping/mark, preparing a target call, opening Highground or toggling the bounty board. Secure target/mark actions remain on their existing buttons and key bindings.")
Add("")
local document = table.concat(lines, "\n")
if mode == "return" then return document, ns.CommandCatalog end
io.write(document)
