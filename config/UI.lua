local _, ns = ...

-- Shared visual language for both clients. Positions remain per-character
-- saved settings; these values control the default panel proportions.
ns.UIConfig = {
  colors = {
    panel = { 0.025, 0.043, 0.067 }, surface = { 0.07, 0.10, 0.145 },
    border = { 0.19, 0.26, 0.34 }, text = { 0.94, 0.97, 1 },
    muted = { 0.58, 0.67, 0.76 }, accent = { 0.25, 0.85, 0.80 },
    warning = { 1, 0.72, 0.28 }, danger = { 1, 0.32, 0.35 },
  },
  main = { width = 320, row = 34, gap = 3, padding = 8, header = 30,
    hero = 72, section = 22, footer = 22, rankWidth = 26 },
  scale = { default = 0.8, min = 0.5, max = 2, step = 0.05 },
  timers = { width = 264, row = 36, gap = 4, padding = 8, header = 30, spacing = 280 },
  flags = { row = 48 },
  -- Compact layout: one docked column, single-line rows.
  compact = {
    main = { width = 250, row = 20, gap = 1, padding = 4, header = 18, hero = 30, section = 4, footer = 4, rankWidth = 18 },
    timers = { row = 18, gap = 1, padding = 4, header = 16 },
    flags = { row = 22 },
    dockGap = 2,
  },
  -- Background opacity of every panel (Background opacity setting).
  opacity = { default = 0.45, min = 0, max = 1, step = 0.05 },
  map = { fontSize = 11 },
}
