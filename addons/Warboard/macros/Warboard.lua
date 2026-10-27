local _, ns = ...
local Macros = ns.Macros

-- Warboard's own macros: they click Warboard's buttons and commands, so they
-- stay with Warboard when the macro tools ship on their own.
Macros.Add(nil, {
  { name = "WB Kill Target", desc = "Warboard: target the recommended kill target",
    lines = "/click WarboardTargetButton" },
  { name = "WB Focus Kill", desc = "Warboard: focus the kill target and keep your target",
    lines = "/click WarboardFocusButton" },
  { name = "WB Mark Kill", desc = "Warboard: ping or mark the kill target", lines = "/click WarboardMarkButton" },
  { name = "WB Call Kill", desc = "Warboard: call the kill target in chat", lines = "/wb call" },
})
