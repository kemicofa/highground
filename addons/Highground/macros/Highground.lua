local _, ns = ...
local Macros = ns.Macros

-- Highground's own macros: they click Highground's buttons and commands,
-- so they stay with Highground when the macro tools ship on their own.
Macros.Add(nil, {
  ns.Localization.Define({ name = "HG Kill Target", desc = ns.Locale:Get("highground.highground.highground_target_the_recommended_kill_target.fbf04c"),
    lines = "/click HighgroundTargetButton" }, { desc = "highground.highground.highground_target_the_recommended_kill_target.fbf04c" }),
  ns.Localization.Define({ name = "HG Focus Kill", desc = ns.Locale:Get("highground.highground.highground_focus_the_kill_target_and_keep.fc412f"),
    lines = "/click HighgroundFocusButton" }, { desc = "highground.highground.highground_focus_the_kill_target_and_keep.fc412f" }),
  ns.Localization.Define({ name = "HG Mark Kill", desc = ns.Locale:Get("highground.highground.highground_ping_or_mark_the_kill_target.c1575a"), lines = "/click HighgroundMarkButton" }, { desc = "highground.highground.highground_ping_or_mark_the_kill_target.c1575a" }),
  ns.Localization.Define({ name = "HG Call Kill", desc = ns.Locale:Get("highground.highground.highground_call_the_kill_target_in_chat.f1c2ce"), lines = "/hg call" }, { desc = "highground.highground.highground_call_the_kill_target_in_chat.f1c2ce" }),
})
