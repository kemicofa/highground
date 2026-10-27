local _, ns = ...
local Macros = ns.Macros

-- Highground's own macros: they click Highground's buttons and commands, so they
-- stay with Highground when the macro tools ship on their own.
Macros.Add(nil, {
  { name = "HG Kill Target", desc = "Highground: target the recommended kill target",
    lines = "/click WarboardTargetButton" },
  { name = "HG Focus Kill", desc = "Highground: focus the kill target and keep your target",
    lines = "/click WarboardFocusButton" },
  { name = "HG Mark Kill", desc = "Highground: ping or mark the kill target", lines = "/click WarboardMarkButton" },
  { name = "HG Call Kill", desc = "Highground: call the kill target in chat", lines = "/wb call" },
})
