local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
local A, L = C.Action, C.Link
local function Guide(key, aliases)
  local prefix = "commands.guide." .. key
  return A("guide " .. key, nil, nil, { descriptionKey = prefix .. ".description", labelKey = prefix .. ".action", aliases = aliases })
end
C.Register("battlegrounds", "Battlegrounds", {
  Guide("battlegrounds", { "checklist battlegrounds" }),
  Guide("enemies", { "guide targeting", "checklist enemies", "checklist targeting" }),
  Guide("objectives", { "checklist objectives" }),
  L("priority", "Show or change target recommendations.", "battlegrounds-settings", "Target recommendation switch", { usage = "[on|off]" }),
  A("call", "Prepare a kill-target chat message; press Enter to send.", "Prepare target call"),
  A("call", "Choose the chat channel used for target calls.", "Choose call channel", { id = "call-channel", usage = "s|i|raid|party|y",
    fields = { { label = "Channel", choices = { { key = "s", label = "Say" }, { key = "i", label = "Instance" },
      { key = "raid", label = "Raid" }, { key = "party", label = "Party" }, { key = "y", label = "Yell" } } } } }),
  A("mark", "Print the current mark mode and the secure button macro.", "Show mark instructions"),
  A("mark icon", "Choose the raid icon used by the mark key.", "Choose raid icon", { usage = "1-8", fields = {
    { label = "Raid icon", choices = { { key = "1", label = "Star" }, { key = "2", label = "Circle" }, { key = "3", label = "Diamond" },
      { key = "4", label = "Triangle" }, { key = "5", label = "Moon" }, { key = "6", label = "Square" }, { key = "7", label = "Cross" }, { key = "8", label = "Skull" } } } } }),
  A("mark ping", "Choose the ping used by the mark key.", "Choose ping type", { usage = "TYPE", caps = "pings",
    fields = { { label = "Ping", choices = { "attack", "warning", "assist", "onmyway" } } } }),
  A("why", "Print why the kill target was chosen.", "Explain target choice"),
  L("live", "Toggle live-priority row sorting.", "behavior", "Live sorting controls"),
  L("all", "Toggle participation in unrated battlegrounds.", "battlegrounds-settings", "Battleground scope controls"),
  A("kit", "Print tracked cooldowns for your target or kill target.", "Show target cooldowns", { cata = true }),
  L("exec", "Set the execute health threshold.", "behavior", "Execute threshold", { usage = "PCT", cata = true }),
  C.Tool("history", "Review saved PvP results and observed objective timelines.", "history", "Open match history"),
  L("bg test", "Start or stop battleground enemy rows, timers, objectives and flag carrier samples.", "battlegrounds-previews", "Battleground panel preview controls"),
  A("bg test stop", "Stop the battleground panel previews.", "Stop battleground previews"),
  A("intel", "Show enemy map and sharing status.", "Show map sharing status"),
  L("intel on", "Enable or disable enemy map positions.", "battlegrounds-settings", "Map position switch", { aliases = { "intel off" } }),
  L("intel share", "Enable or disable sharing map positions with teammates.", "battlegrounds-settings", "Map sharing switch", { usage = "on|off" }),
  L("intel test", "Start or stop a sample world-map pin.", "battlegrounds-previews", "Map preview controls"),
  A("timers", "Show battleground timer status.", "Show timer status"),
  L("timers on", "Enable or disable battleground timers.", "battlegrounds-settings", "Battleground timer switch", { aliases = { "timers off" } }),
  A("timers reset", "Restore battleground panel positions and spacing.", "Reset battleground positions", { confirm = "Reset battleground timer and objective panel positions?" }),
  A("reset", "Restore the main enemy panel position.", "Reset enemy panel position", { confirm = "Reset the main enemy panel position?" }),
  L("rows", "Set the number of enemies shown.", "battlegrounds-appearance", "Choose enemy row count", { usage = "N" }),
  L("compact", "Toggle the slim one-line enemy layout.", "battlegrounds-settings", "Compact layout switch", { usage = "[on|off]" }),
  L("sniper", "Toggle the target marker.", "battlegrounds-settings", "Target marker switch"),
  A("sniper why", "Explain why the target marker is hidden.", "Diagnose target marker"),
  L("sniper color", "Choose a ring, skull or aim color; default restores the component color.", "battlegrounds-appearance", "Target marker colors", { usage = "ring|skull|aim HEX|default" }),
  A("sniper color", "Choose a named ring preset and restore its automatic kill-window colors.", "Choose marker color preset", { id = "sniper-preset", usage = "NAME", fields = {
    { label = "Ring preset", choices = function()
      local choices = {}; for key in pairs(ns.Core.SNIPER_COLORS) do choices[#choices + 1] = key end
      table.sort(choices); return choices
    end } } }),
  L("sniper size", "Set target marker scale.", "battlegrounds-appearance", "Target marker size", { usage = "X" }),
  L("sniper x", "Set the horizontal marker offset.", "battlegrounds-appearance", "Target marker horizontal offset", { usage = "N" }),
  L("sniper y", "Set the vertical marker offset.", "battlegrounds-appearance", "Target marker vertical offset", { usage = "N" }),
  L("sniper padding", "Set the nameplate edge gap.", "battlegrounds-appearance", "Target marker edge gap", { usage = "N" }),
  A("sniper sound", "Choose and preview a lock-on sound; zero disables it.", "Choose target marker sound", { usage = "N", fields = {
    { label = "Lock-on sound", choices = function()
      local choices = { { key = "0", label = "Off" } }
      for i, sound in ipairs(ns.Core.SNIPER_SOUNDS) do choices[#choices + 1] = { key = tostring(i), label = sound.name } end
      return choices
    end } } }),
  L("sniper place", "Choose marker placement; head placement follows the nameplate approximately.", "battlegrounds-appearance", "Target marker placement", { usage = "body|head|left|right|above" }),
  L("sniper style", "Choose the layered marker or original crosshair.", "battlegrounds-appearance", "Target marker style", { usage = "layered|legacy" }),
  L("sniper skull", "Show or hide the marker skull.", "battlegrounds-settings", "Target marker skull", { usage = "[on|off]" }),
  L("sniper animate", "Toggle marker animation; Reduced motion keeps it steady.", "battlegrounds-settings", "Target marker animation", { usage = "[on|off]" }),
  L("sniper test", "Start or stop a marker preview on a visible nameplate.", "battlegrounds-previews", "Target marker preview controls"),
  L("go", "Preview the kill-window look and sound with a sample active.", "battlegrounds-previews", "Kill-window preview controls"),
  A("burst", "Print recent observed burst buffs.", "Show burst diagnostics", { cata = true }),
  L("burst test", "Start or stop a burst marker sample.", "battlegrounds-previews", "Burst preview controls", { cata = true }),
  A("pressure", "Print teammate pressure status and observed targeting counts.", "Show pressure status", { cata = true, aliases = { "pressure status" } }),
  L("pressure on", "Enable or disable teammate pressure shields.", "battlegrounds-settings", "Pressure shield switch", { cata = true, aliases = { "pressure off" } }),
  A("pressure count", "Set the maximum number of teammates with pressure shields.", "Choose pressure shield count", { cata = true, usage = "N",
    fields = { { label = "Teammates", kind = "number", min = 1, max = 3, integer = true, default = "3" } } }),
  L("pressure test", "Start or stop the pressure-shield sample.", "battlegrounds-previews", "Pressure preview controls", { cata = true }),
  A("points", "Print overridden scoring values in chat.", "Show scoring overrides"),
  A("points", "Set or reset any scoring value.", "Edit a scoring value", { id = "points-value", usage = "NAME VALUE|reset", fields = {
    { label = "Scoring value", choices = function()
      local choices = {}
      for key in pairs(ns.Core.POINT_DEFAULT) do choices[#choices + 1] = key end
      table.sort(choices); return choices
    end }, { label = "Value or reset", kind = "number-or-reset", default = "reset" } } }),
  L("weights", "Inspect all score multipliers.", "multipliers", "Inspect score multipliers"),
  L("weight", "Set a score multiplier.", "multipliers", "Edit score multipliers", { usage = "[NAME X]" }),
  A("weight reset", "Reset every score multiplier to 1.0.", "Reset all score multipliers", { confirm = "Reset every score multiplier to 1.0?" }),
  A("map", "Print the current map and battleground weighting profile.", "Inspect current map"),
  A("cap why", "Explain capture detection for your current target.", "Explain capture detection"),
  A("cap probe", "Start or stop recording capture diagnostics.", "Toggle capture recording", { cata = true }),
  A("cap clear", "Clear capture diagnostics while preserving learned capture spells.", "Clear capture diagnostics", { confirm = "Clear recorded capture diagnostics? Learned capture spells are kept." }),
}, {
  { cmd = "bg test", label = "Battleground panels", desc = "Enemy list, kill-target card, timers, objectives and flag carriers with sample data" },
  { cmd = "sniper test", label = "Target marker", desc = "Crosshair on any target with a visible nameplate" },
  { kind = "action", cmd = "go", label = "Kill window", desc = "GO look and sound (with Battleground panels or Target marker on)" },
  { cmd = "intel test", label = "Map pin", desc = "Sample enemy pin on the world map" },
  { cmd = "burst test", label = "Burst marker", desc = "Marker beside your target's nameplate", cata = true },
  { cmd = "pressure test", label = "Pressure shields", desc = "Shield badge on a targeted teammate or yourself", cata = true },
})
