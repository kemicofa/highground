local test, new, equal = ...

-- Macros window labels and rules read from shared config: variant button
-- labels, target tooltips, game labels, arena games and catalog rules.
local function entry(sim, class, name)
  for _, e in ipairs(sim.ns.Macros.catalog) do
    if e.class == class and e.name == name and (e.mode or "pvp") == "pvp" then return e end
  end
end
local function labels(list)
  local out = {}
  for _, v in ipairs(list or {}) do out[#out + 1] = v[2] end
  return table.concat(out, " ")
end
local function forever(s) -- WoW Forever: the retail manifest on 16001
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
end
local function client(game)
  if game == "forever" then return new("retail", nil, forever) end
  return new(game)
end
local function hover(sim, b)
  sim.env.GameTooltip.lines = {}
  for _, h in ipairs(b.hooks.OnEnter or {}) do h(b) end
  return table.concat(sim.env.GameTooltip.lines, " | ")
end

test("variant buttons: same labels, arena ones by bracket size", function()
  local cata = new("cata")
  local Win = cata.ns.Macros.Window
  local kick = entry(cata, "ROGUE", "Kick")
  equal(labels(Win.Variants(kick)), "F A1 A2 A3", "arena")
  equal(labels(Win.MoreVariants(kick)), "A4 A5", "5v5 behind +")
  equal(labels(Win.Variants({ enemy = true })), "F MO T", "enemy")
  equal(labels(Win.Variants({ party = true })), "MO P1 P2 ME", "party")
  equal(labels(Win.MoreVariants({ party = true })), "P3 P4", "party behind +")
  equal(labels(Win.Variants({ assist = true })), "FT MOT P1T P2T", "assist")
  equal(labels(Win.MoreVariants({ assist = true })), "P3T P4T", "assist behind +")

  local retail = new("retail")
  local RWin = retail.ns.Macros.Window
  equal(labels(RWin.Variants(entry(retail, "ROGUE", "Kick"))), "F A1 A2 A3", "retail arena")
  equal(RWin.MoreVariants(entry(retail, "ROGUE", "Kick")), nil, "3v3: nothing behind +")

  local fv = client("forever")
  equal(fv.ns.Macros.Window.Variants({ arena = true }), nil, "no arenas on Forever")
end)

test("arena games and sizes come from ns.Games", function()
  local sim = new("cata")
  local M, Games = sim.ns.Macros, sim.ns.Games
  for game, info in pairs(Games) do
    equal(M.ARENA_SIZE[game], info.arenaSize, game .. " arena size")
    equal(M.ARENA_GAMES[game], info.arenaSize and true or nil, game .. " has arenas")
  end
  for class, games in pairs(M.CLASS_GAMES) do
    for game in pairs(games) do assert(Games[game], class .. ": unknown game " .. game) end
  end
  equal(M.InMode({ mode = "both" }, "pve"), true, "both modes")
  equal(M.InMode({}, "pve"), false, "pvp by default")
end)

test("target tooltips keep their text", function()
  local sim = new("cata")
  local tips = sim.ns.Macros.Window.TARGET_TIPS
  local want = {
    target = { "Target", "Your current target" },
    player = { "Me", "Yourself" },
    arena1 = { "Arena 1", "Arena enemy 1 (the first enemy on the arena frames)" },
    arena5 = { "Arena 5", "Arena enemy 5 (5v5 only)" },
    party1 = { "Party 1", "Party member 1 (the first under you on the party frames)" },
    mouseovertarget = { "Mouseover's target",
      "Whoever the unit under your mouse is targeting. Your own target does not change." },
    party4target = { "Party 4's target", "Whoever party member 4 is targeting. Your own target does not change." },
  }
  for unit, t in pairs(want) do
    equal(tips[unit][1], t[1], unit .. " title")
    equal(tips[unit][2], t[2], unit .. " text")
  end
  equal(tips.pet, nil, "no button, no tooltip")
end)

test("cards: class names, verdicts, tooltips and the game label", function()
  local sim = new("cata")
  local names = {}
  for _, c in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE",
    "WARLOCK", "DRUID" }) do names[c] = "Local " .. c:lower() end
  sim.env.LOCALIZED_CLASS_NAMES_MALE = names
  sim:command("macros")
  local Win = sim.ns.Macros.Window
  Win.SetTab("all")
  local w = sim.env.HighgroundMacroFrame
  assert(w.sub.text:find("CATACLYSM", 1, true), "game label in the subtitle")
  local card
  for _, r in ipairs(w.rows) do if r:IsShown() and r.entry and r.entry.class then card = r break end end
  assert(card, "a class card")
  assert(card.desc.text:find("Local " .. card.entry.class:lower(), 1, true), "localized class appears in All classes")
  assert(hover(sim, card.more):find("Customize", 1, true), "secondary actions explain themselves")

  sim.macros[#sim.macros + 1] = { name = "Bad", body = "/cast [@focus" }
  sim.macros[#sim.macros + 1] = { name = "Fine", body = "/cleartarget" }
  Win.SetTab("mine")
  local status = {}
  for _, r in ipairs(w.rows) do if r:IsShown() then status[r.entry.name] = r.status.text end end
  equal(status.Fine, "All characters", "sound macro")
  assert(status.Bad and status.Bad:find("Needs editing", 1, true), "broken macro: " .. tostring(status.Bad))
end)

test("hub subtitle names the game", function()
  for game, label in pairs({ retail = "RETAIL", cata = "CATACLYSM", forever = "WOW FOREVER" }) do
    local sim = client(game)
    sim:command("")
    assert(sim.env.HighgroundHub.sub.text:find(label, 1, true), game .. ": " .. tostring(sim.env.HighgroundHub.sub.text))
  end
end)
