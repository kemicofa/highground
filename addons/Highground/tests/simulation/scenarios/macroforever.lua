local test, new, equal = ...

-- WoW Forever's own class kit: new spells and talents, renamed spells and
-- removed ones, kept apart from Classic Era and The Burning Crusade.

test("WoW Forever presets: its new spells, renames and removals", function()
  local sim = new("retail", nil, function(s)
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  end)
  local M = sim.ns.Macros
  local function entry(class, name, mode)
    for _, e in ipairs(M.catalog) do
      if e.class == class and e.name == name and M.InMode(e, mode or "pvp") then return e end
    end
    error("missing preset " .. class .. " " .. name)
  end
  for _, c in ipairs({ { "WARRIOR", "Victory Rush" }, { "PALADIN", "Holy Strike" }, { "PALADIN", "Oath of Light" },
    { "HUNTER", "Summon Hawk" }, { "ROGUE", "Shank" }, { "PRIEST", "Penance" }, { "SHAMAN", "Totemic Call" },
    { "MAGE", "Ice Lance" }, { "WARLOCK", "Bane of Havoc" }, { "DRUID", "Wild Growth" } }) do
    local e = entry(c[1], c[2])
    equal(M.InGame(e, "forever"), true, c[2] .. " on Forever")
    equal(M.InGame(e, "classic"), false, c[2] .. " not on Classic Era")
  end
  equal(M.InGame(entry("HUNTER", "Wyvern Sting"), "forever"), false, "Forever removed Wyvern Sting")
  equal(M.InGame(entry("HUNTER", "Wyvern Sting"), "classic"), true, "Classic Era keeps it")
  equal(M.InGame(entry("HUNTER", "Wyvern Sting"), "tbc"), true, "TBC keeps it")
  local agony = entry("WARLOCK", "Agony", "pve")
  assert(M.Build(agony, "forever"):find("Bane of Agony", 1, true), "Forever: Bane of Agony")
  assert(M.Build(agony, "classic"):find("Curse of Agony", 1, true), "Classic Era: Curse of Agony")
  assert(M.Build(entry("PRIEST", "SW:Death"), "tbc"), "TBC has Shadow Word: Death too")
  equal(M.Build(entry("PRIEST", "SW:Death"), "classic"), nil, "Classic Era does not")
  equal(M.Build(entry("WARLOCK", "Wrack")), "#showtooltip\n/stopmacro [channeling]\n/cast Wrack", "channel kept")
  equal(M.Build(entry("HUNTER", "Lacerate")), "#showtooltip\n/startattack\n/petattack\n/cast Lacerate", "pet joins")
end)
