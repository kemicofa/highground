local _, ns = ...

-- Shared visual language for both clients. Positions remain per-character
-- saved settings; these values control the default panel proportions.
-- Colours come from the active theme (config/Theme.lua); these legacy names
-- are the same tables as the tokens, so they follow a theme switch.
local C = ns.ThemeTokens.color
ns.UIConfig = {
  colors = {
    panel = C.bg, surface = C.surface, border = C.border, text = C.text,
    muted = C.textMuted, accent = C.accent, warning = C.warning, danger = C.danger,
  },
  main = { width = 320, row = 34, gap = 3, padding = 8, header = 30,
    hero = 72, section = 22, footer = 22, rankWidth = 26 },
  scale = { default = 0.8, min = 0.5, max = 2, step = 0.05 },
  timers = { width = 264, row = 36, gap = 4, padding = 8, header = 30, spacing = 280 },
  flags = { row = 68 },
  -- Compact layout: one docked column; carriers retain a separate health strip.
  compact = {
    main = { width = 250, row = 20, gap = 1, padding = 4, header = 18, hero = 30, section = 4, footer = 4, rankWidth = 18 },
    timers = { row = 18, gap = 1, padding = 4, header = 16 },
    flags = { row = 48 },
    dockGap = 2,
  },
  -- Background opacity of every panel (Background opacity setting).
  opacity = { default = 1, min = 0, max = 1, step = 0.05, idle = 0.65 },
  map = { fontSize = 11 },
  -- Appearance settings (HighgroundDB.style). Layout values are kept per
  -- layout (normal / compact); every other choice applies to both.
  appearance = {
    panels = {
      -- "battlegrounds" multiplies every other battleground panel's scale.
      ns.Localization.Define({ key = "battlegrounds", module = "battlegrounds", label = ns.Locale:Get("profiles.panel.battlegrounds") }, { label = "profiles.panel.battlegrounds" }),
      ns.Localization.Define({ key = "main", module = "battlegrounds", label = ns.Locale:Get("shared.ui.main_panel.097f43") }, { label = "shared.ui.main_panel.097f43" }),
      ns.Localization.Define({ key = "timers", module = "battlegrounds", label = ns.Locale:Get("profiles.panel.timers") }, { label = "profiles.panel.timers" }),
      ns.Localization.Define({ key = "bases", module = "battlegrounds", label = ns.Locale:Get("profiles.panel.objectives") }, { label = "profiles.panel.objectives" }),
      ns.Localization.Define({ key = "forecast", module = "battlegrounds", label = ns.Locale:Get("profiles.panel.forecast") }, { label = "profiles.panel.forecast" }),
      ns.Localization.Define({ key = "flags", module = "battlegrounds", label = ns.Locale:Get("highground.profilesummary.flag_carriers.287119") }, { label = "highground.profilesummary.flag_carriers.287119" }),
      ns.Localization.Define({ key = "quickCalls", module = "battlegrounds", label = ns.Locale:Get("profiles.panel.callouts") }, { label = "profiles.panel.callouts" }),
      ns.Localization.Define({ key = "arena", module = "arena", label = ns.Locale:Get("profiles.panel.arena") }, { label = "profiles.panel.arena" }),
      ns.Localization.Define({ key = "nearby", module = "nearby", label = ns.Locale:Get("highground.profilesummary.nearby_enemies.85f5df") }, { label = "highground.profilesummary.nearby_enemies.85f5df" }),
    },
    panelScale = { min = 0.5, max = 2, step = 0.05 },
    metrics = {
      ns.Localization.Define({ module = "battlegrounds", key = "width", label = ns.Locale:Get("shared.ui.main_panel_width.d3aaab"), min = 200, max = 480, step = 10 }, { label = "shared.ui.main_panel_width.d3aaab" }),
      ns.Localization.Define({ module = "battlegrounds", key = "row", label = ns.Locale:Get("shared.ui.enemy_row_height.80c620"), normal = { 28, 64 }, compact = { 16, 40 }, step = 1 }, { label = "shared.ui.enemy_row_height.80c620" }),
      ns.Localization.Define({ module = "battlegrounds", key = "gap", label = ns.Locale:Get("shared.ui.row_spacing.502469"), min = 0, max = 12, step = 1 }, { label = "shared.ui.row_spacing.502469" }),
      ns.Localization.Define({ module = "battlegrounds", key = "padding", label = ns.Locale:Get("shared.ui.panel_padding.3dc00b"), min = 0, max = 16, step = 1 }, { label = "shared.ui.panel_padding.3dc00b" }),
      ns.Localization.Define({ module = "battlegrounds", key = "health", style = "line", label = ns.Locale:Get("shared.ui.thin_line_height.dadca8"), min = 1, max = 12, step = 1 }, { label = "shared.ui.thin_line_height.dadca8" }),
      ns.Localization.Define({ module = "battlegrounds", key = "healthBar", style = "bar", label = ns.Locale:Get("shared.ui.bar_thickness.18928a"), normal = { 6, 28 }, compact = { 3, 14 }, step = 1 }, { label = "shared.ui.bar_thickness.18928a" }),
      ns.Localization.Define({ module = "battlegrounds", key = "timerWidth", label = ns.Locale:Get("shared.ui.timer_panel_width.9ba638"), min = 200, max = 420, step = 10, normalOnly = true }, { label = "shared.ui.timer_panel_width.9ba638" }),
      ns.Localization.Define({ module = "battlegrounds", key = "timerRow", label = ns.Locale:Get("shared.ui.timer_row_height.53a02f"), normal = { 24, 48 }, compact = { 14, 28 }, step = 1 }, { label = "shared.ui.timer_row_height.53a02f" }),
      ns.Localization.Define({ module = "battlegrounds", key = "timerGap", label = ns.Locale:Get("shared.ui.timer_row_spacing.821ba3"), min = 0, max = 12, step = 1 }, { label = "shared.ui.timer_row_spacing.821ba3" }),
      ns.Localization.Define({ module = "arena", key = "arenaWidth", label = ns.Locale:Get("shared.ui.panel_width.c9f204"), min = 200, max = 480, step = 10 }, { label = "shared.ui.panel_width.c9f204" }),
      ns.Localization.Define({ module = "arena", key = "arenaGap", label = ns.Locale:Get("shared.ui.row_spacing.502469"), min = 0, max = 12, step = 1 }, { label = "shared.ui.row_spacing.502469" }),
      ns.Localization.Define({ module = "arena", key = "arenaPadding", label = ns.Locale:Get("shared.ui.panel_padding.3dc00b"), min = 0, max = 16, step = 1 }, { label = "shared.ui.panel_padding.3dc00b" }),
      ns.Localization.Define({ module = "arena", key = "arenaHeader", label = ns.Locale:Get("shared.ui.header_height.ada802"), min = 14, max = 40, step = 1 }, { label = "shared.ui.header_height.ada802" }),
      ns.Localization.Define({ module = "nearby", key = "nearbyWidth", label = ns.Locale:Get("shared.ui.panel_width.c9f204"), min = 200, max = 480, step = 10 }, { label = "shared.ui.panel_width.c9f204" }),
      ns.Localization.Define({ module = "nearby", key = "nearbyGap", label = ns.Locale:Get("shared.ui.row_spacing.502469"), min = 0, max = 12, step = 1 }, { label = "shared.ui.row_spacing.502469" }),
      ns.Localization.Define({ module = "nearby", key = "nearbyPadding", label = ns.Locale:Get("shared.ui.panel_padding.3dc00b"), min = 0, max = 16, step = 1 }, { label = "shared.ui.panel_padding.3dc00b" }),
      ns.Localization.Define({ module = "nearby", key = "nearbyHeader", label = ns.Locale:Get("shared.ui.header_height.ada802"), min = 14, max = 40, step = 1 }, { label = "shared.ui.header_height.ada802" }),
    },
    elements = {
      ns.Localization.Define({ key = "rank", label = ns.Locale:Get("shared.ui.priority_rank.689cfb"), desc = ns.Locale:Get("shared.ui.1_is_highest_ranks_update_even_when.0dc10e") }, { label = "shared.ui.priority_rank.689cfb", desc = "shared.ui.1_is_highest_ranks_update_even_when.0dc10e" }),
      ns.Localization.Define({ key = "icon", label = ns.Locale:Get("shared.ui.spec_icon.01b283"), desc = ns.Locale:Get("shared.ui.class_icon_until_the_spec_is_known.63e7fe") }, { label = "shared.ui.spec_icon.01b283", desc = "shared.ui.class_icon_until_the_spec_is_known.63e7fe" }),
      ns.Localization.Define({ key = "spec", label = ns.Locale:Get("shared.ui.spec_text.1b31ca"), desc = ns.Locale:Get("shared.ui.capture_timers_flag_carriers_and_the_spec.f5a475") }, { label = "shared.ui.spec_text.1b31ca", desc = "shared.ui.capture_timers_flag_carriers_and_the_spec.f5a475" }),
      ns.Localization.Define({ key = "health", label = ns.Locale:Get("shared.ui.health_bar.ed43a3") }, { label = "shared.ui.health_bar.ed43a3" }),
      ns.Localization.Define({ key = "healthText", label = ns.Locale:Get("shared.ui.health.e2324e"), desc = ns.Locale:Get("shared.ui.health_percentage_on_the_bar_or_beside.7cc27d") }, { label = "shared.ui.health.e2324e", desc = "shared.ui.health_percentage_on_the_bar_or_beside.7cc27d" }),
      ns.Localization.Define({ key = "mana", label = ns.Locale:Get("shared.ui.mana_bar.a532dd"), desc = ns.Locale:Get("shared.ui.mana_users_once_seen.62442b"), cata = true }, { label = "shared.ui.mana_bar.a532dd", desc = "shared.ui.mana_users_once_seen.62442b" }),
      ns.Localization.Define({ key = "trinket", label = ns.Locale:Get("shared.ui.pvp_trinket.7581a2"), cata = true }, { label = "shared.ui.pvp_trinket.7581a2" }),
      ns.Localization.Define({ key = "status", label = ns.Locale:Get("shared.ui.status_chip.8f98ef"), desc = ns.Locale:Get("shared.ui.immune_def_cc_burst.dc84fa") }, { label = "shared.ui.status_chip.8f98ef", desc = "shared.ui.immune_def_cc_burst.dc84fa" }),
      ns.Localization.Define({ key = "distance", label = ns.Locale:Get("shared.ui.distance.423208") }, { label = "shared.ui.distance.423208" }),
      ns.Localization.Define({ key = "gap", label = ns.Locale:Get("shared.ui.priority_tag.e41138"), desc = ns.Locale:Get("shared.ui.now_attack_target_top_priority_leader_dead.4027e4") }, { label = "shared.ui.priority_tag.e41138", desc = "shared.ui.now_attack_target_top_priority_leader_dead.4027e4" }),
      ns.Localization.Define({ key = "allies", label = ns.Locale:Get("shared.ui.teammates_on_them.3d6073"), desc = ns.Locale:Get("shared.ui.normal_layout.a62e20") }, { label = "shared.ui.teammates_on_them.3d6073", desc = "shared.ui.normal_layout.a62e20" }),
    },
    fonts = {
      ns.Localization.Define({ key = "barlow", label = ns.Locale:Get("highground.profilesummary.theme_default.a99097") }, { label = "highground.profilesummary.theme_default.a99097" }),
      ns.Localization.Define({ key = "friz", label = ns.Locale:Get("shared.ui.game_default.778789"), file = "Fonts\\FRIZQT__.TTF" }, { label = "shared.ui.game_default.778789" }),
      ns.Localization.Define({ key = "arial", label = ns.Locale:Get("shared.ui.arial_narrow.299aae"), file = "Fonts\\ARIALN.TTF" }, { label = "shared.ui.arial_narrow.299aae" }),
      ns.Localization.Define({ key = "skurri", label = ns.Locale:Get("shared.ui.skurri.36fa9f"), file = "Fonts\\skurri.ttf" }, { label = "shared.ui.skurri.36fa9f" }),
    },
    fontScale = { min = 0.7, max = 1.5, step = 0.05 },
    bars = {
      ns.Localization.Define({ key = "flat", label = ns.Locale:Get("shared.ui.flat.79c9e1"), file = "Interface\\Buttons\\WHITE8x8" }, { label = "shared.ui.flat.79c9e1" }),
      ns.Localization.Define({ key = "blizzard", label = ns.Locale:Get("shared.ui.blizzard.f6221a"), file = "Interface\\TargetingFrame\\UI-StatusBar" }, { label = "shared.ui.blizzard.f6221a" }),
      ns.Localization.Define({ key = "raid", label = ns.Locale:Get("shared.ui.raid_frames.b610fc"), file = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" }, { label = "shared.ui.raid_frames.b610fc" }),
    },
    -- Bar (default): a thick bar on a track under the name, percentage at
    -- its end. Fill: health fills the whole enemy row, mana is a bar along
    -- its bottom. Line: thin health and mana lines along the bottom.
    healthStyles = {
      ns.Localization.Define({ key = "bar", label = ns.Locale:Get("shared.ui.bar_under_the_name.edff3e") }, { label = "shared.ui.bar_under_the_name.edff3e" }),
      ns.Localization.Define({ key = "fill", label = ns.Locale:Get("shared.ui.fill_the_row.a7132a") }, { label = "shared.ui.fill_the_row.a7132a" }),
      ns.Localization.Define({ key = "line", label = ns.Locale:Get("shared.ui.thin_line.92f627") }, { label = "shared.ui.thin_line.92f627" }),
    },
    barColors = {
      ns.Localization.Define({ key = "class", label = ns.Locale:Get("shared.ui.class_colors.6cfb0e") }, { label = "shared.ui.class_colors.6cfb0e" }),
      ns.Localization.Define({ key = "faction", label = ns.Locale:Get("shared.ui.faction_colors.8df4ef") }, { label = "shared.ui.faction_colors.8df4ef" }),
      ns.Localization.Define({ key = "health", label = ns.Locale:Get("shared.ui.green_to_red.b946ee") }, { label = "shared.ui.green_to_red.b946ee" }),
      ns.Localization.Define({ key = "custom", label = ns.Locale:Get("shared.ui.custom_color.34cfc6") }, { label = "shared.ui.custom_color.34cfc6" }),
    },
    border = { default = 1, min = 0, max = 4, step = 1 },
    borderColors = {
      ns.Localization.Define({ key = "default", label = ns.Locale:Get("highground.profilesummary.theme_default.a99097") }, { label = "highground.profilesummary.theme_default.a99097" }),
      ns.Localization.Define({ key = "accent", label = ns.Locale:Get("shared.ui.accent.233064") }, { label = "shared.ui.accent.233064" }),
      ns.Localization.Define({ key = "black", label = ns.Locale:Get("shared.ui.black.b406fb"), color = C.black }, { label = "shared.ui.black.b406fb" }),
      ns.Localization.Define({ key = "white", label = ns.Locale:Get("shared.ui.white.37619f"), color = C.white }, { label = "shared.ui.white.37619f" }),
    },
  },
}

-- Enemy-panel overrides inherit shared styling until explicitly selected.
local A = ns.UIConfig.appearance
local function Choice(key, label) return ns.Localization.Define({ key = key, label = ns.Locale:Get(label) }, { label = label }) end
A.enemyBars = { Choice("shared", "enemy.appearance.shared") }
for _, choice in ipairs(A.bars) do A.enemyBars[#A.enemyBars + 1] = choice end
A.enemyColors = { Choice("shared", "enemy.appearance.shared"), Choice("theme", "highground.profilesummary.theme_default.a99097") }
for _, choice in ipairs(A.barColors) do A.enemyColors[#A.enemyColors + 1] = choice end
A.enemyPresets = { Choice("readable", "enemy.appearance.readable"), Choice("compact", "enemy.appearance.compact"),
  Choice("default", "highground.appearance.default.808d7d") }
A.enemyNumbers = {
  ns.Localization.Define({ key = "enemyBackground", label = ns.Locale:Get("enemy.appearance.background"), min = 0, max = 1, default = 0 }, { label = "enemy.appearance.background" }),
  ns.Localization.Define({ key = "enemyOpacity", label = ns.Locale:Get("enemy.appearance.opacity"), min = 0.3, max = 1, default = 1 }, { label = "enemy.appearance.opacity" }),
  ns.Localization.Define({ key = "enemyNames", label = ns.Locale:Get("enemy.appearance.names"), min = 0.4, max = 1, default = 0.6 }, { label = "enemy.appearance.names" }),
}
