local _, ns = ...
local C = ns.CommandCatalog
-- Retained standalone hosts have their own slash entry points.
if not C then return end
C.Register("macros", "Macros", {
  C.Tool("macros", "Open the macro browser and builder.", "macros", "Open macros"),
  C.Action("macros pvp", "Browse PvP macros for your class.", "Browse PvP macros"),
  C.Action("macros pve", "Browse PvE macros for your class.", "Browse PvE macros"),
  C.Action("macros build", "Build a macro with labeled controls.", "Build a macro"),
  C.Action("macros mine", "Browse your existing macros.", "Open your macros"),
  C.Action("macros export", "Export your macros as a shareable code.", "Export macros"),
  C.Action("macros import", "Review and import a macro code.", "Import macros"),
  C.Action("macros history", "Review backups and undo Highground macro edits.", "Open macro backups"),
  C.Action("macros presets", "Browse presets for spells with ranks on WoW Forever.", "Browse ranked spell presets", { caps = "spellRanks" }),
  C.Action("macros ranks", "Review action buttons and macros for highest-rank upgrades.", "Review spell rank upgrades", { caps = "spellRanks" }),
}, {
  { kind = "open", cmd = "macros", label = "Macros", desc = "Ready-made PvP and PvE macros for your class, and a macro builder" },
})
