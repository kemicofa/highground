-- Highground Macros on its own: loads from its TOCs (Highground's simulator,
-- through the shared/ link), opens, saves, ranks. Run from this folder.
local new = dofile("shared/tests/simulation/runtime.lua")
local count = 0
local function test(name, run)
  count = count + 1
  local ok, err = xpcall(run, debug.traceback)
  if not ok then io.stderr:write("FAIL macros addon: " .. name .. "\n" .. err .. "\n"); os.exit(1) end
  print("PASS macros addon: " .. name)
end
local function equal(actual, expected, why)
  assert(actual == expected, why .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function standalone(client, build, saved)
  return new(client, saved, function(s)
    s.addon, s.savedVariable = "HighgroundMacros", "HighgroundMacrosDB"
    -- Classic Era and The Burning Crusade use the classic (Cata-like) API
    -- and the main TOC; Cataclysm its own.
    s.manifest = (build or 0) >= 40000 and build < 50000 and "HighgroundMacros_Cata.toc" or "HighgroundMacros.toc"
    if build then s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", build end end
  end)
end

for _, case in ipairs({ { "cata", 40402, "cata" }, { "retail", 120100, "retail" }, { "retail", 16001, "forever" },
  { "cata", 11509, "classic" }, { "cata", 20506, "tbc" } }) do
  test(case[3] .. ": loads, opens with /hgm and copies a macro", function()
    local saved = {}
    local sim = standalone(case[1], case[2], saved)
    local ns = sim.ns
    equal(ns.GAME, case[3], "game detected")
    equal(ns.Core.db, saved, "HighgroundMacrosDB is the settings table")
    local ranked = { forever = true, classic = true, tbc = true }
    equal(ns.Macros.Ranks.Supported(), ranked[case[3]] == true, "spell ranks")
    sim.env.SlashCmdList.HIGHGROUNDMACROS("pve")
    local w = sim.env.HighgroundMacrosMacroFrame
    assert(w and w:IsShown(), "/hgm opens the window")
    equal(saved.macroMode, "pve", "mode saved")
    w.tabs.general.scripts.OnClick(w.tabs.general)
    local card
    for _, r in ipairs(w.rows) do if r:IsShown() and r.entry.name == "Focus Mouseover" then card = r end end
    assert(card, "shared preset listed")
    card.general.scripts.OnClick(card.general)
    equal(sim.macros[1] and sim.macros[1].name, "Focus Mouseover", "copied into the General tab")
    for _, e in ipairs(ns.Macros.catalog) do
      assert(not e.name:match("^HG "), "no Highground-only macros: " .. e.name)
    end
    sim.env.SlashCmdList.HIGHGROUNDMACROS("theme ember")
    equal(saved.theme, "ember", "/hgm theme")
    sim.env.SlashCmdList.HIGHGROUNDMACROS("help")
    assert(sim.env.Highground == nil and sim.ns.Commands == nil, "no Highground globals or commands")
  end)
end
test("Classic Era and The Burning Crusade: vanilla presets, their own additions, arenas in TBC", function()
  local function find(sim, class, name)
    for _, e in ipairs(sim.ns.Macros.catalog) do
      if e.class == class and e.name == name and (e.mode or "pvp") == "pvp" then return e end
    end
  end
  local era, tbc = standalone("cata", 11509, {}), standalone("cata", 20506, {})
  local M, T = era.ns.Macros, tbc.ns.Macros
  equal(M.Build(find(era, "SHAMAN", "Interrupt")), "#showtooltip\n/stopcasting\n/cast [@focus,harm,nodead][] Earth Shock",
    "vanilla spell names on Classic Era")
  equal(M.InGame(find(era, "HUNTER", "Misdirection")), false, "no Misdirection before TBC")
  equal(T.InGame(find(tbc, "HUNTER", "Misdirection")), true, "Misdirection in TBC")
  equal(M.InGame(find(era, "DEATHKNIGHT", "Mind Freeze")), false, "no Death Knights")
  equal(M.Window.Variants(find(era, "ROGUE", "Kick")), nil, "no arenas on Classic Era")
  assert(T.Window.Variants(find(tbc, "ROGUE", "Kick")), "arena variants in TBC")
  equal(select(4, M.Limits()), 18, "18 character macros")
  local r = M.Compiler.Compile("/ping [@target] attack", "classic")
  equal(r.errors, 1, "no /ping on Classic Era")
end)
print("Macros addon: " .. count .. " scenarios")
