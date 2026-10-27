local _, ns = ...

-- The command catalog: every /wb command and the preview buttons, shown on
-- the Test and commands page and used by /wb help and the docs. Rows:
-- { command, what it does } or { "Group title" }; cata = true limits a row
-- to Cataclysm (see ns.OptionAvailable).
ns.CommandCatalog = {}

ns.CommandCatalog.previews = {
  { cmd = "test", label = "Main panel", desc = "Enemy list and kill-target card with sample enemies" },
  { cmd = "sniper test", label = "Target marker", desc = "Crosshair on any target with a visible nameplate" },
  { cmd = "go", label = "Kill window", desc = "GO look and sound (with Main panel or Target marker on)" },
  { cmd = "arena test", label = "Arena panel", desc = "Arena enemy team with trinkets" },
  { cmd = "nearby test", label = "Nearby enemies", desc = "Open-world enemy list" },
  { cmd = "intel test", label = "Map pin", desc = "Sample enemy pin on the world map" },
  { cmd = "burst test", label = "Burst marker", desc = "Marker beside your target's nameplate", cata = true },
  { cmd = "pressure test", label = "Pressure shields", desc = "Shield badge on a targeted teammate or yourself", cata = true },
  { cmd = "bounty test", label = "Bounty alert", desc = "Bounty sound and center-screen message" },
  { cmd = "bounty", label = "Bounty board", desc = "Open or close the bounty board" },
  { cmd = "macros", label = "PvP macros", desc = "Ready-made macros for your class, and a macro builder" },
}

-- { command, what it does }; group rows have only a title.
ns.CommandCatalog.commands = {
  { "General" },
  { "/wb", "Open or close the Warboard window" },
  { "/wb help", "Every command in chat, with your detected spec" },
  { "/wb config [PAGE]  |  config blizzard", "Warboard window on a page; the Blizzard settings panel" },
  { "/wb options", "Same as /wb config" },
  { "/wb lock  |  unlock", "Keep panels in place, or drag them by their headers" },
  { "/wb reset  |  timers reset", "Move the main panel back; restore battleground panel spacing" },
  { "/wb scale 0.8  |  opacity 45  |  rows 8", "Panel scale, background opacity, enemy rows shown" },
  { "/wb compact [on|off]", "Slim one-line layout" },
  { "/wb sound", "Mute or unmute every Warboard sound" },
  { "/wb theme [NAME]", "List the themes, or switch to one (also on the Appearance page)" },
  { "Targets" },
  { "/wb priority on|off", "Target recommendations" },
  { "/wb call [s|i|raid|party|y]", "Call the kill target in chat, or pick the channel" },
  { "/wb mark icon 1-8  |  mark ping TYPE", "What the mark key does: a raid icon or a ping" },
  { "/wb why", "Why the kill target was chosen" },
  { "/wb live", "Reorder rows by live priority" },
  { "/wb all", "Also turn on in unrated battlegrounds" },
  { "/wb kit", "Tracked cooldowns of your target", cata = true },
  { "/wb exec PCT", "Execute health threshold", cata = true },
  { "Panels and previews" },
  { "/wb test", "Main panel preview" },
  { "/wb arena on|off|test", "Arena enemy panel" },
  { "/wb nearby on|off|test|clear", "Open-world nearby enemies" },
  { "/wb intel on|off|test  |  intel share on|off", "Enemy map positions and sharing" },
  { "/wb timers on|off", "Battleground timers and capture tracking" },
  { "/wb sniper  |  sniper why", "Target marker on or off; why it is not showing" },
  { "/wb sniper color NAME|size X|y N|sound N", "Target marker colour, size, height and lock-on sound" },
  { "/wb sniper test  |  go", "Target marker and kill-window previews" },
  { "/wb burst [test]", "Burst marker preview and recent burst buffs", cata = true },
  { "/wb pressure on|off|test|count N", "Teammate pressure shields", cata = true },
  { "Bounties" },
  { "/wb bounty", "Open the bounty board" },
  { "/wb bounty add [GOLD] NAME [; note]", "Personal bounty; NAME can be \"target\"" },
  { "/wb bounty submit|remove|claim NAME", "Send to your guild, take down, or report a kill" },
  { "/wb bounty approve|reject NAME", "Officers: review submissions" },
  { "/wb bounty list|sync|test|on|off", "Print, ask the guild, preview, switch alerts" },
  { "Macros" },
  { "/wb macros  |  macros build|mine", "PvP macros for your class and game; build your own; your macros" },
  { "/wb macros export  |  macros import", "Share your macros as a base64 string" },
  { "Tuning and profiles" },
  { "/wb profile save|load|delete NAME", "Named settings profiles" },
  { "/wb export [NAME]  |  import", "Share settings or a saved profile as a base64 string" },
  { "/wb points [NAME VALUE]", "Show or set a scoring value" },
  { "/wb weights  |  weight NAME X", "Score multipliers" },
  { "Troubleshooting" },
  { "/wb err  |  clearerr", "Show or clear recorded errors" },
  { "/wb probe  |  map", "What the addon reads from your target and this map" },
  { "/wb cap why|probe|clear", "Capture tracking diagnostics" },
}
