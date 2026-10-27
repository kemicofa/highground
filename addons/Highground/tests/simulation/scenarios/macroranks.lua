local test, new, equal = ...

local function macro(sim, name)
  for _, m in ipairs(sim.macros) do if m.name == name then return m end end
end

test("macro tools use Highground only through macros/Host.lua", function()
  local pipe = assert(io.popen("ls macros/*.lua"))
  local checked = 0
  for path in pipe:lines() do
    if path ~= "macros/Host.lua" and path ~= "macros/Highground.lua" then
      local file = assert(io.open(path))
      local text = file:read("*a")
      file:close()
      local n = 0
      for line in (text .. "\n"):gmatch("(.-)\n") do
        n = n + 1
        local code = line:gsub("%-%-.*$", "")
        for name in code:gmatch("%f[%w_]ns%.(%a+)") do
          assert(name == "Macros", path .. ":" .. n .. " uses ns." .. name .. ": go through macros/Host.lua")
        end
        assert(not code:find("%f[%w_]Core%."), path .. ":" .. n .. " uses Core: go through macros/Host.lua")
      end
      checked = checked + 1
    end
  end
  pipe:close()
  assert(checked >= 15, "macro files found")
end)

test("macros window switches between PvP and PvE presets", function()
  local sim = new("retail")
  sim.units.player.classID = 5 -- priest
  sim:command("macros")
  local Win = sim.ns.Macros.Window
  equal(Win.Mode(), "pvp", "PvP by default")
  local function names()
    local set = {}
    for _, e in ipairs(Win.List()) do set[e.name] = e end
    return set
  end
  Win.SetTab("class")
  assert(names()["Psychic Scream"] and not names()["SW:Pain"], "PvP presets")
  local w = sim.env.HighgroundMacroFrame
  w.modes.pve.scripts.OnClick(w.modes.pve)
  equal(Win.Mode(), "pve", "PvE selected")
  equal(sim.env.HighgroundDB.macroMode, "pve", "mode saved")
  local pve = names()
  assert(pve["SW:Pain"] and pve["Flash Heal"] and not pve["Psychic Scream"], "PvE presets")
  equal(sim.ns.Macros.Build(Win.Resolve(pve["SW:Pain"])),
    "#showtooltip\n/cast [@mouseover,harm,nodead][] Shadow Word: Pain", "mouseover dot")
  Win.variant[pve["SW:Pain"]] = "focus"
  local o = Win.Resolve(pve["SW:Pain"])
  equal(o.name, "SW:Pain F", "focus variant name")
  equal(sim.ns.Macros.Build(o), "#showtooltip\n/cast [@focus,harm,nodead][] Shadow Word: Pain", "focus variant")
  Win.SetTab("general")
  local general = names()
  assert(general["Mark Skull MO"] and general["Trinket 1"] and not general["Target Arena 1"],
    "general: PvE and shared presets, no arena macros")
  sim:command("macros pvp")
  equal(Win.Mode(), "pvp", "/hg macros pvp")
  for _, e in ipairs(sim.ns.Macros.catalog) do
    for _, game in ipairs({ "cata", "retail", "forever" }) do
      if sim.ns.Macros.InGame(e, game) then
        local body = sim.ns.Macros.Build(e, game)
        local r = sim.ns.Macros.Compiler.Compile(body, game)
        assert(r.errors == 0, e.name .. " (" .. game .. ") compiles: " .. ((r.problems[1] or {}).text or ""))
        assert(#e.name <= 16, e.name .. " fits 16 characters")
      end
    end
  end
end)

-- Forever with ranked Frostbolt: spells[id] = { name, rank }, known[id].
local SPELLS = { [101] = { "Frostbolt", 1 }, [102] = { "Frostbolt", 2 }, [103] = { "Frostbolt", 3 },
  [104] = { "Frostbolt", 4 }, [201] = { "Blink" }, [301] = { "Flash Heal", 1 }, [302] = { "Flash Heal", 2 },
  [401] = { "Desperate Prayer", 1 }, [402] = { "Desperate Prayer", 2 } }
local function ranked(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  s.spellIDs, s.bar, s.cursor = { [101] = true, [102] = true, [201] = true, [301] = true, [302] = true, [401] = true, [402] = true }, {}, nil
  local spell = s.env.C_Spell
  local byName = spell.GetSpellInfo
  spell.GetSpellInfo = function(name)
    local top
    for id in pairs(s.spellIDs) do
      if SPELLS[id][1] == name and (not top or id > top) then top = id end
    end
    if top then return { name = name, spellID = top } end
    return byName(name)
  end
  spell.GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end
  spell.GetSpellSubtext = function(id) local r = SPELLS[id] and SPELLS[id][2]; return r and ("Rank " .. r) or "" end
  spell.PickupSpell = function(id) s.cursor = id end
  spell.IsSpellHelpful = function(name) return name == "Flash Heal" or name == "Desperate Prayer" end
  spell.SpellHasRange = function(name) return name ~= "Desperate Prayer" end
  s.env.GetActionInfo = function(slot) if s.bar[slot] then return "spell", s.bar[slot] end end
  s.env.PlaceAction = function(slot) assert(not s.combat, "PlaceAction in combat"); s.bar[slot], s.cursor = s.cursor, s.bar[slot] end
  s.env.ClearCursor = function() s.cursor = nil end
  s.env.GetCursorInfo = function() return s.cursor and "spell" or nil end
end

test("WoW Forever: new spell ranks move buttons and macros up, downranks stay", function()
  local sim = new("retail", nil, ranked)
  local Ranks = sim.ns.Macros.Ranks
  equal(Ranks.Supported(), true, "Forever has spell ranks")
  sim.bar[1], sim.bar[2], sim.bar[3] = 102, 101, 201
  sim.macros[1] = { name = "FB", body = "#showtooltip Frostbolt(Rank 2)\n/cast [@focus,harm][] Frostbolt(Rank 2)" }
  sim.macros[2] = { name = "FB1", body = "/cast Frostbolt(Rank 1)" }
  sim.macros[3] = { name = "FB Top", body = "/cast Frostbolt" }
  sim:event("SPELLS_CHANGED") -- remembers rank 2 as the highest

  sim.spellIDs[103] = true
  sim:event("SPELLS_CHANGED")
  equal(sim.bar[1], 103, "button on the replaced rank moves up")
  equal(sim.bar[2], 101, "downranked button stays")
  equal(sim.bar[3], 201, "spells without ranks stay")
  equal(sim.cursor, nil, "cursor left empty")
  equal(macro(sim, "FB").body, "#showtooltip Frostbolt(Rank 3)\n/cast [@focus,harm][] Frostbolt(Rank 3)", "macro moves up")
  equal(macro(sim, "FB1").body, "/cast Frostbolt(Rank 1)", "downranked macro stays")
  equal(macro(sim, "FB Top").body, "/cast Frostbolt", "no rank: already the highest")

  sim:setCombat(true)
  sim.spellIDs[104] = true
  sim:event("SPELLS_CHANGED")
  equal(sim.bar[1], 103, "nothing moves in combat")
  sim:setCombat(false)
  equal(sim.bar[1], 104, "moves after combat")
  equal(macro(sim, "FB").body, "#showtooltip Frostbolt(Rank 4)\n/cast [@focus,harm][] Frostbolt(Rank 4)", "macro after combat")

  local r = sim.ns.Macros.Analyze("/cast Frostbolt(Rank 1)")
  assert(r.problems[1] and r.problems[1].text:find("you know rank 4", 1, true), "pinned low rank flagged")
  equal(sim.ns.Macros.Build({ spell = "Frostbolt", target = "focus", kind = "harm", rank = 1 }),
    "#showtooltip\n/cast [@focus,harm,nodead] Frostbolt(Rank 1)", "builder pins a rank")

  sim:command("macros ranks")
  equal(sim.bar[2], 104, "/hg macros ranks moves downranks up too")
  equal(macro(sim, "FB1").body, "/cast Frostbolt(Rank 4)", "and downranked macros")
end)

test("highest spell rank switch: off leaves buttons alone, Also in macros off leaves macros", function()
  local sim = new("retail", nil, ranked)
  sim.bar[1] = 102
  sim.macros[1] = { name = "FB", body = "/cast Frostbolt(Rank 2)" }
  sim:event("SPELLS_CHANGED")
  sim.ns.Core.SetFeature("highestRankMacros", false)
  sim.spellIDs[103] = true
  sim:event("SPELLS_CHANGED")
  equal(sim.bar[1], 103, "buttons move")
  equal(macro(sim, "FB").body, "/cast Frostbolt(Rank 2)", "macros stay")
  sim.ns.Core.SetFeature("highestRank", false)
  sim.spellIDs[104] = true
  sim:event("SPELLS_CHANGED")
  equal(sim.bar[1], 103, "switched off: nothing moves")
end)

test("spell ranks: Retail and Cata have none", function()
  for _, client in ipairs({ "retail", "cata" }) do
    local sim = new(client)
    equal(sim.ns.Macros.Ranks.Supported(), false, client .. " has no ranks")
    sim:command("macros ranks")
    local r = sim.ns.Macros.Analyze("/cast Frostbolt(Rank 1)")
    local found
    for _, p in ipairs(r.problems) do if p.text:find("no spell ranks", 1, true) then found = true end end
    assert(found, client .. ": pinned rank flagged")
  end
end)

test("WoW Forever: RANKS presets for every ranked spell you know", function()
  local sim = new("retail", nil, ranked)
  sim.spellbook = { "Frostbolt", "Blink", "Flash Heal", "Desperate Prayer" }
  sim:event("SPELLS_CHANGED")
  sim:command("macros presets")
  local Win = sim.ns.Macros.Window
  equal(Win.Mode(), "ranks", "/hg macros presets opens the RANKS mode")
  local w = sim.env.HighgroundMacroFrame
  assert(w.modes.ranks:IsShown(), "RANKS button shown where spells have ranks")
  local list = Win.List()
  equal(#list, 3, "ranked spells only: Blink has no ranks")
  equal(list[1].spell, "Desperate Prayer", "sorted by name")
  equal(sim.ns.Macros.Build(Win.Resolve(list[1])), "#showtooltip\n/cast Desperate Prayer", "self-only: a plain /cast")
  equal(Win.Variants(list[1]), nil, "self-only: no target variants")
  equal(sim.ns.Macros.Build(Win.Resolve(list[2])),
    "#showtooltip\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Flash Heal", "heal: mouseover chain")
  equal(sim.ns.Macros.Build(Win.Resolve(list[3])), "#showtooltip\n/cast Frostbolt", "damage: bare name, highest rank")
  assert(list[3].desc:find("rank 2", 1, true), "shows the current rank")
  local card
  for _, r in ipairs(w.rows) do if r:IsShown() and r.entry.spell == "Frostbolt" then card = r end end
  assert(card.body.text:find(sim.ns.Theme.Hex("accent") .. "/cast|r", 1, true), "preset text is syntax-coloured")
  card.general.scripts.OnClick(card.general)
  equal(macro(sim, "Frostbolt").body, "#showtooltip\n/cast Frostbolt", "copied")
  sim.spellIDs[103] = true
  sim:event("SPELLS_CHANGED")
  assert(Win.List()[3].desc:find("rank 3", 1, true), "refreshed after learning a rank")
  equal(macro(sim, "Frostbolt").body, "#showtooltip\n/cast Frostbolt", "bare name needs no change")

  local cata = new("cata")
  cata:command("macros")
  assert(not cata.env.HighgroundMacroFrame.modes.ranks:IsShown(), "no RANKS button without ranks")
  cata.ns.Macros.Window.SetMode("ranks")
  equal(cata.ns.Macros.Window.Mode(), "pvp", "RANKS mode falls back to PvP")
end)
