-- The macro language data (config/Macros.lua) as the compiler, the
-- explanations, the builder and autocomplete use it: exact text.
local new = dofile("tests/simulation/runtime.lua")
local checks = 0
local function equal(actual, expected, why)
  checks = checks + 1
  assert(actual == expected, why .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
end

-- Commands limited to games with team pings follow the capability.
for _, case in ipairs({ { "cata" }, { "retail" }, { "retail", forever } }) do
  local M = new(case[1], nil, case[2]).ns.Macros
  for _, cmd in ipairs({ "ping", "pingspell", "pingitem" }) do
    equal(M.Compiler.Available("command", cmd), M.Host.Can("pings"), M.Host.Game() .. " /" .. cmd)
  end
end

local ns = new("retail").ns
local M, Config = ns.Macros, ns.Macros.Config
local C, S = M.Compiler, M.Suggest

-- The modules' tables are the config's.
equal(C.COMMAND_GAMES, Config.COMMAND_GAMES, "command games")
equal(C.CONDITIONS, Config.CONDITIONS, "conditions")
equal(S.CLASS_BUFFS, Config.CLASS_BUFFS, "class buffs")
equal(S.BUFF_ICONS, Config.BUFF_ICONS, "buff icons")
equal(M.SLOT_NAMES, Config.SLOTS, "slots")
equal(C.COMMANDS.cast, "cond", "own kind")
equal(C.COMMANDS.played, "plain", "listed commands take text")
equal(C.EMOTES.dance, true, "emotes")
equal(C.Compile("/cast [house] X", "tbc").problems[1].text, "[house] does not exist in The Burning Crusade", "game name")

local function explain(text, game)
  return table.concat(M.Explain(C.Compile(text, game)), "\n")
end
equal(explain("/castsequence reset=4/target/combat/alt A, B ,, C"),
  "Casts A, then B, then C on successive presses, starting over after 4 seconds without pressing it"
  .. " or a new target or leaving combat or pressing it with Alt.", "resets")
equal(explain("/cast [@arena2target,harm,nodead][@party3][@focustarget][@none] X"),
  "Casts X on arena enemy 2's target if it is a living enemy; otherwise on party member 3;"
  .. " otherwise on your focus's target; otherwise on nothing (you pick).", "unit phrases")
equal(explain("/cast [mod:shift/ctrl,nogroup,resting] X"),
  "Casts X if Shift or Ctrl is held and not: you are in a group and you are resting.", "condition words")
equal(explain("/tm [@mouseover] 8\n/use 13"),
  "Puts the Skull marker on the unit under your mouse.\nUses your top trinket.", "markers and slots")
equal(C.Compile("/castsequence reset=foo A").problems[1].text,
  "reset=foo: use seconds, target, combat, shift, ctrl or alt", "unknown reset")
equal(C.Compile("/ping [@target] attack", "cata").problems[1].text, "/ping does not exist in Cataclysm", "ping")
equal(C.Available("command", "ping", "forever"), true, "ping checked for another game: Forever has pings")
equal(C.Available("command", "ping", "classic"), false, "Classic Era has none")

-- Builder: labels and short names from UNITS, trims and splits.
equal(M.TARGET_LABEL.player .. M.TARGET_LABEL.arena5 .. M.TARGET_LABEL.party4, "SelfArena 5Party 4", "labels")
equal(M.TARGET_LABEL.pet, nil, "only the builder's targets")
equal(M.VariantName("Kick", "arena2"), "Kick A2", "variant name")
equal(M.VariantName("Kick", "focustarget"), "Kick FT", "target of focus")
equal(M.VariantName("Kick", "cursor"), "Kick", "cursor: no suffix")
equal(M.UnitOf({ target = "name", unitName = "  Bob Smith  ", of = true }), "Bob Smith-target", "name unit")
equal(table.concat(M.Needs({ verb = "castsequence", spell = " A, B ,, C " }), "|"), "A|B|C", "sequence steps")

-- Autocomplete lists.
local function texts(list)
  local out = {}
  for _, o in ipairs(list) do out[#out + 1] = o.text .. (o.hint and ("=" .. o.hint) or "") end
  return table.concat(out, " ")
end
local _, marks = S.CodeProvider("/tm [@target] ")
equal(texts(marks), "8=skull 7=cross 6=square 5=moon 4=triangle 3=diamond 2=circle 1=star 0=clear", "markers")
local _, resets = S.CodeProvider("/castsequence reset=")
equal(texts(resets), "target=new target combat=leaving combat shift ctrl alt", "resets")
local _, values = S.CodeProvider("/cast [nobutton:")
equal(texts(values), "1=left 2=right 3=middle 4 5", "button values")
local _, dirs = S.CodeProvider("#sh")
equal(texts(dirs), "show=icon of a spell showtooltip=icon and tooltip of a spell", "directives")
local list, set, add = S.Unique()
add("A"); add(""); add(nil); add("A", { text = "A2" }); add("B", { text = "B" })
equal(#list, 2, "unique names")
equal(list[2].text, "B", "item stored")
equal(set.A, true, "set")

print("Macro language: " .. checks .. " checks")
