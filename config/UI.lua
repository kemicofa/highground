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
    hero = 100, section = 22, footer = 22, rankWidth = 26 },
  timers = { width = 264, row = 36, gap = 4, padding = 8, header = 30, spacing = 280 },
  flags = { row = 48 },
  map = { fontSize = 11 },
}
