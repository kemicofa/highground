local test, new, equal = ...

-- Shared helpers (core/Util.lua, ui/kit, config/Client.lua, config/Macros.lua,
-- macros/HostBase.lua) that every addon of the repository builds on.

test("Util text helpers: Trim, Split, Plural, Ago", function()
  local U = new("cata").ns.Util
  equal(U.Trim("  Ice Block \n"), "Ice Block", "trim")
  equal(U.Trim(nil), "", "trim nil")
  local parts = U.Split(" Ice Block, ,Invisibility ,")
  equal(#parts .. ":" .. parts[1] .. "|" .. parts[2], "2:Ice Block|Invisibility", "split drops empty pieces")
  equal(#U.Split("a/b", "/"), 2, "other separator")
  equal(U.Plural(1, "error"), "1 error", "singular")
  equal(U.Plural(2, "error"), "2 errors", "plural")
  equal(U.Plural(3, "WARNING"), "3 WARNINGS", "upper case")
  equal(U.Ago(1) .. " " .. U.Ago(42) .. " " .. U.Ago(130), "now 42s 2m", "ago")
end)

test("Util game data helpers: class names, spells, health", function()
  local sim = new("retail")
  local U = sim.ns.Util
  sim.env.LOCALIZED_CLASS_NAMES_MALE.WARRIOR, sim.env.LOCALIZED_CLASS_NAMES_MALE.MAGE = "Warrior", "Mage"
  equal(U.ClassName("WARRIOR"), "Warrior", "localized")
  equal(U.ClassName("UNKNOWN"), "UNKNOWN", "token when unknown")
  local list = U.SortClasses({ "WARRIOR", "MAGE" })
  equal(list[1], "MAGE", "sorted by name")
  equal(U.SpellName(7), "Spell 7", "spell name by ID")
  equal(U.SpellTexture(7), "Interface\\Icons\\Spell7", "spell icon")
  sim.known.Frostbolt = true
  sim.env.C_Spell.GetSpellInfo = function(name) if name == "Frostbolt" then return { name = name, spellID = 116 } end end
  equal(U.SpellID("Frostbolt"), 116, "spell ID by name")
  equal(U.SpellID("Nope"), nil, "unknown spell")
  sim.env.UnitHealth, sim.env.UnitHealthMax = function() return 25 end, function() return 100 end
  equal(U.HealthFraction("target"), 0.25, "health fraction")
  sim.env.UnitHealthMax = function() return 0 end
  equal(U.HealthFraction("target"), nil, "no maximum")
end)

test("Kit.Tooltip and Kit.ClassIcon", function()
  local sim = new("cata")
  local Kit = sim.ns.Kit
  local b = Kit.Button(sim.env.UIParent, "X", 40, 20)
  Kit.Tooltip(b, { "Title", "Body text", { "Note", "textMuted" } })
  for _, h in ipairs(b.hooks.OnEnter) do h(b) end
  equal(table.concat(sim.env.GameTooltip.lines, "|"), "Title|Body text|Note", "lines in order")
  local c = Kit.Button(sim.env.UIParent, "Y", 40, 20)
  Kit.Tooltip(c, function(self) if not self.empty then return { "Dynamic" } end end)
  c.empty = true
  sim.env.GameTooltip.lines = {}
  for _, h in ipairs(c.hooks.OnEnter) do h(c) end
  equal(#sim.env.GameTooltip.lines, 0, "nothing to show")
  local tex = b:CreateTexture()
  equal(Kit.ClassIcon(tex, "MAGE"), true, "class icon")
  equal(Kit.ClassIcon(tex, nil), false, "no class")
end)

test("game metadata and macro vocabulary", function()
  local ns = new("cata").ns
  equal(ns.Games.tbc.arenaSize, 5, "TBC 5v5")
  equal(ns.Games.forever.arenaSize, nil, "Forever: no arenas")
  equal(ns.Games.classic.contentOf, "forever", "Classic Era uses Forever's spells")
  local U = ns.Macros.Config.UNITS
  equal(U.focus.short .. U.mouseover.short .. U.arena4.short .. U.party3.short, "FMOA4P3", "short labels")
  equal(U.party1.phrase, "party member 1", "phrase")
  equal(ns.Macros.Config.MARKERS[8], "Skull", "markers")
  equal(ns.Macros.Config.SLOTS["13"], "your top trinket", "slots")
end)

test("macro helpers: Host, Verdict, Measurer, LastItem", function()
  local sim = new("cata")
  local M = sim.ns.Macros
  for _, k in ipairs({ "Trim", "Split", "Plural", "ClassName", "SpellName", "SpellTexture", "SpellID", "GameInfo",
    "PREFIX", "Class", "On", "Command", "Release" }) do
    assert(M.Host[k] ~= nil, "Host." .. k)
  end
  equal(M.Host.GameInfo("cata").name, "Cataclysm", "game info")
  local text, token = M.Verdict({ errors = 2, warnings = 1 })
  equal(text .. " " .. token, "2 ERRORS danger", "errors win")
  equal(table.concat({ M.Verdict({ errors = 0, warnings = 0 }) }, " "), "OK success", "clean")
  local box = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  box:SetWidth(70)
  local fits = M.Measurer(box, "codeLarge", box)
  equal(fits("/cast X"), true, "short line fits")
  equal(fits("/cast [@mouseover,help,nodead] Flash Heal"), false, "long line doesn't")
  local seen
  local p = M.Suggest.LastItem(function(word) seen = word; return word, {} end)
  p("Ice Block, Invis")
  equal(seen, " Invis", "the piece after the last comma")
  equal(sim.env.HighgroundDropdown == nil, true, "dropdown made on first use")
end)
