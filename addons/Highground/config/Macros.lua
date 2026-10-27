local _, ns = ...
ns.Macros = ns.Macros or {}

---------------------------------------------------------------------------
-- Macro vocabulary shared by the builder, the explanations, autocomplete
-- and the window (macros/*.lua): one entry per word players see.
--   UNITS[token] = { label (button), short (variant button and name suffix),
--     phrase (in sentences), tip (tooltip title), about (tooltip text) }
-- A unit's target ("focustarget", "Bob-target") is built from these.
---------------------------------------------------------------------------
local Config = {}
ns.Macros.Config = Config

Config.UNITS = {
  target = { label = "Target", phrase = "your target", tip = "Target", about = "Your current target" },
  focus = { label = "Focus", short = "F", phrase = "your focus", tip = "Focus", about = "Your focus target" },
  mouseover = { label = "Mouseover", short = "MO", phrase = "the unit under your mouse", tip = "Mouseover",
    about = "The unit under your mouse, on a nameplate, frame or in the world" },
  cursor = { label = "Cursor", phrase = "the ground at your cursor", tip = "Cursor",
    about = "The ground at your cursor, no targeting circle" },
  player = { label = "Self", short = "Me", phrase = "yourself", tip = "Me", about = "Yourself" },
  pet = { label = "Pet", phrase = "your pet" },
  none = { label = "None", phrase = "nothing (you pick)" },
}
for i = 1, 5 do
  Config.UNITS["arena" .. i] = { label = "Arena " .. i, short = "A" .. i, phrase = "arena enemy " .. i,
    tip = "Arena " .. i, about = "Arena enemy " .. i
      .. (i == 1 and " (the first enemy on the arena frames)" or i > 3 and " (5v5 only)" or "") }
end
for i = 1, 4 do
  Config.UNITS["party" .. i] = { label = "Party " .. i, short = "P" .. i, phrase = "party member " .. i,
    tip = "Party " .. i, about = "Party member " .. i .. (i == 1 and " (the first under you on the party frames)" or "") }
end

-- Raid markers by number (/tm 1-8; 0 clears).
Config.MARKERS = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
-- Modifier keys ([mod:shift], reset=shift).
Config.MODS = { shift = "Shift", ctrl = "Ctrl", alt = "Alt" }
-- /castsequence reset= words: button label and phrase in explanations.
Config.RESETS = {
  { key = "target", button = "New target", phrase = "a new target" },
  { key = "combat", button = "Combat ends", phrase = "leaving combat" },
  { key = "shift", button = "Shift", phrase = "pressing it with Shift" },
  { key = "ctrl", button = "Ctrl", phrase = "pressing it with Ctrl" },
  { key = "alt", button = "Alt", phrase = "pressing it with Alt" },
}
-- Equipment slots by number (/use 13), as said in explanations.
Config.SLOTS = { ["1"] = "your head item", ["2"] = "your neck item", ["3"] = "your shoulder item",
  ["5"] = "your chest item", ["6"] = "your belt", ["7"] = "your legs item", ["8"] = "your boots",
  ["9"] = "your wrist item", ["10"] = "your gloves", ["11"] = "your first ring", ["12"] = "your second ring",
  ["13"] = "your top trinket", ["14"] = "your bottom trinket", ["15"] = "your cloak",
  ["16"] = "your main-hand item", ["17"] = "your off-hand item" }
