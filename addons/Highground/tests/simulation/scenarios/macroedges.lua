local test, new, equal = ...

-- Macro edge cases: WoW's byte limits with localized text, form choices
-- that no longer apply, and explicit editor save states.

local function toggle(p, key)
  for _, b in ipairs(p.toggles) do if b.value == key then b.scripts.OnClick(b); return b end end
  error("missing toggle " .. key)
end

test("names clip to WoW's byte limit without splitting a character", function()
  local M = new("cata").ns.Macros
  equal(M.Clip("Kick", 16), "Kick", "short names stay")
  equal(M.Clip("Hammer of Justice", 13), "Hammer of Jus", "ASCII cuts at the limit")
  -- "Ó" and "т" take two bytes: the cut steps back to a whole character.
  equal(M.Clip("Coup de bouclÓÓ", 15), "Coup de bouclÓ", "never half of a two-byte letter")
  equal(M.Clip("Удар щитом", 5), "Уд", "Cyrillic keeps whole letters")
  equal(M.Clip("技能名称", 7), "技能", "three-byte characters too")
  local name = M.VariantName("Ледяная глыба", "arena3")
  assert(#name <= 16 and name:sub(-3) == " A3", "variant suffix kept within 16 bytes: " .. name)
  equal(name, "Ледяна A3", "suffix after whole letters")
end)

test("a sequence ignores single-cast choices left on the form", function()
  local M = new("cata").ns.Macros
  equal(M.Build({ verb = "castsequence", spell = "Corruption, Immolate", reset = "8/target", force = true, toggle = true }),
    "#showtooltip\n/castsequence reset=8/target Corruption, Immolate", "reset kept, no ! or /cancelaura of the list")
  equal(M.Build({ verb = "castrandom", spell = "Corruption, Immolate", force = true }),
    "#showtooltip\n/castrandom Corruption, Immolate", "no ! on random")
  equal(M.Build({ verb = "use", spell = "Healthstone", force = true, toggle = true }),
    "#showtooltip\n/use Healthstone", "no ! or toggle on items")
  equal(M.Build({ verb = "castsequence", spell = "Rend, Heroic Strike", reset = "combat", stance = { 1, "Battle Stance" } }),
    "#showtooltip\n/castsequence [nostance:1] Battle Stance; reset=combat Rend, Heroic Strike",
    "stance dance with the sequence's own command and a plain #showtooltip")
  equal(M.Build({ spell = "Overpower", force = true, stance = { 1, "Battle Stance" } }),
    "#showtooltip Overpower\n/cast [nostance:1] Battle Stance; !Overpower", "single casts keep their tooltip")
end)

test("switching the builder to Sequence keeps resets and drops single-cast toggles", function()
  local sim = new("cata")
  sim:command("macros build")
  local p = sim.ns.Macros.BuildPanel.frame
  p.spell:SetText("Corruption")
  toggle(p, "force"); toggle(p, "toggle")
  equal(p.code:GetPlainText(), "#showtooltip\n/cancelaura Corruption\n/cast !Corruption", "single cast uses both")
  p.verbs[3].scripts.OnClick(p.verbs[3])
  p.spell:SetText("Corruption, Immolate")
  p.resetSeconds:SetText("5")
  equal(p.code:GetPlainText(), "#showtooltip\n/castsequence reset=5 Corruption, Immolate", "what the form shows is what is built")
end)

-- WoW Forever with ranked spells: SPELLS[id] = { name, rank, helpful, range }.
local SPELLS = {
  [11] = { "Greater Blessing of Kings", 1, true, true }, [12] = { "Greater Blessing of Might", 2, true, true },
  [13] = { "Greater Blessing of Wisdom", 1, true, true }, [14] = { "Blessing of Sanctuary", 3, true, true },
  [15] = { "Blessing of Salvation", 1, true, true }, [16] = { "Seal of Righteousness", 4, false, false },
  [17] = { "Flash of Light", 2, true, true },
}
local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  local byName = {}
  for id, info in pairs(SPELLS) do byName[info[1]] = id end
  local spell = s.env.C_Spell
  spell.GetSpellInfo = function(name) local id = byName[name]; return id and { name = name, spellID = id } or nil end
  spell.GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end
  spell.GetSpellSubtext = function(id) return SPELLS[id] and ("Rank " .. SPELLS[id][2]) or "" end
  spell.IsSpellHelpful = function(name) return SPELLS[byName[name] or 0] and SPELLS[byName[name]][3] end
  spell.SpellHasRange = function(name) return SPELLS[byName[name] or 0] and SPELLS[byName[name]][4] end
  s.spellbook = {}
  for _, info in pairs(SPELLS) do s.spellbook[#s.spellbook + 1] = info[1] end
end

test("ranked presets get unique names that survive target suffixes", function()
  local sim = new("retail", nil, forever)
  local M = sim.ns.Macros
  local names, saved = {}, {}
  for _, e in ipairs(M.Ranks.Presets()) do
    names[e.spell] = e.name
    for _, target in ipairs({ "target", "focus", "mouseover", "party1", "party4", "player" }) do
      local variant = M.WithTarget(e, target).name
      assert(#variant <= 16, "fits WoW's limit: " .. variant)
      assert(not saved[variant] or saved[variant] == e.spell, variant .. " names two spells")
      saved[variant] = e.spell
    end
  end
  equal(names["Greater Blessing of Kings"], "Greater Kings", "clashing names keep their last word")
  equal(names["Greater Blessing of Might"], "Greater Might", "same rule for the whole group")
  equal(names["Greater Blessing of Wisdom"], "Greate Wisdom", "a long last word shortens the rest")
  equal(names["Blessing of Sanctuary"], "Ble Sanctuary", "clash after the variant suffix")
  equal(names["Flash of Light"], "Flash of Light", "unique names unchanged")
  equal(names["Seal of Righteousness"], "Seal of Righteou", "self-only spells use all 16 bytes")
end)

test("localized bodies change only spell names, never conditions or spacing", function()
  local sim = new("cata", nil, function(_, env) env.GetLocale = function() return "frFR" end end)
  local M = sim.ns.Macros
  local names = { [1766] = "Coup de pied", [1784] = "Camouflage", [17116] = "Rapidité de la nature (druide)",
    [16188] = "Rapidité de la nature", [80964] = "Coup de crâne", [106839] = "Coup de crâne (Retail)" }
  M.Host.SpellName = function(id) return names[id] end
  equal(M.LocalBody("#showtooltip\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Kick", "cata"),
    "#showtooltip\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Coup de pied", "condition groups untouched")
  equal(M.LocalBody("/castsequence [mod:shift] reset=3/target Kick, !Stealth;  Kick", "cata"),
    "/castsequence [mod:shift] reset=3/target Coup de pied, !Camouflage;  Coup de pied", "resets, ! and spacing kept")
  equal(M.LocalBody("/cast [known:Kick] Ice Lance\n/use 13", "cata"), "/cast [known:Kick] Ice Lance\n/use 13",
    "unknown names, condition values and items stay")
  equal(M.LocalSpell("Nature's Swiftness", "cata", "DRUID"), "Rapidité de la nature (druide)", "class's own spell")
  equal(M.LocalSpell("Nature's Swiftness", "cata", "SHAMAN"), "Rapidité de la nature", "default spell")
  equal(M.LocalSpell("Skull Bash", "cata"), "Coup de crâne", "per-game identifier")
  equal(M.LocalSpell("Skull Bash", "retail"), "Coup de crâne (Retail)", "Retail's identifier")
end)

test("wrapped preset code and default names keep whole letters", function()
  local sim = new("cata")
  local M = sim.ns.Macros
  local rows = M.Uncolor(M.Highlight("/cast Ледяная глыба", function(line) return #line <= 9 end))
  for row in (rows .. "\n"):gmatch("(.-)\n") do
    assert(#row <= 9, "row fits: " .. row)
    assert(not row:find("^[\128-\191]") and not row:find("[\192-\255]$"), "no split letter in " .. row)
  end
  equal(rows:gsub("\n", ""), "/cast Ледяная глыба", "nothing lost between rows")
  sim:command("macros build")
  local P = M.BuildPanel
  P.frame.spell:SetText("Ледяная глыба")
  equal(P.Name(), "Ледяная", "default name: whole letters, no trailing space")
end)

test("spell suggestions offer your class's presets, not every class's", function()
  local sim = new("retail") -- a mage
  sim.spellbook = { "Frostbolt" }
  local S = sim.ns.Macros.Suggest
  local _, pummel = S.SpellProvider("Pummel")
  equal(#pummel, 0, "another class's preset spell is not suggested")
  local _, steal = S.SpellProvider("Spellst")
  equal(steal[1] and steal[1].text, "Spellsteal", "your class's preset spell is")
  equal(steal[1].hint, "not learned", "and marked as not learned")
  local _, book = S.SpellProvider("Frost")
  equal(book[1].text, "Frostbolt", "your spellbook first")
end)

test("spell rank checks reread buttons and macros only after they change", function()
  local bar, reads = {}, 0
  local sim = new("retail", nil, function(s)
    forever(s)
    s.env.GetActionInfo = function(slot) reads = reads + 1; if bar[slot] then return "spell", bar[slot] end end
    s.env.PlaceAction = function(slot) bar[slot] = s.cursor end
    s.env.ClearCursor = function() s.cursor = nil end
    s.env.GetCursorInfo = function() return nil end
    s.env.C_Spell.PickupSpell = function(id) s.cursor = id end
  end)
  sim:event("SPELLS_CHANGED")
  local first = reads
  assert(first >= 120, "the first check reads every button")
  for _ = 1, 5 do sim:event("SPELLS_CHANGED") end
  equal(reads, first, "unchanged buttons and macros are not read again")
  bar[1] = 17 -- Flash of Light, rank 2
  sim:event("ACTIONBAR_SLOT_CHANGED", 1)
  sim:event("SPELLS_CHANGED")
  assert(reads > first, "a changed button is read")
  equal(sim.ns.Macros.Ranks.top["Flash of Light"].rank, 2, "and its spell is tracked")

  local retail = new("retail")
  local frames = 0
  for _, f in ipairs(retail.frames) do
    local h = f.handlers
    if h and h.ACTIONBAR_SLOT_CHANGED and h.UPDATE_MACROS and h.SPELLS_CHANGED then frames = frames + 1 end
  end
  equal(frames, 0, "games without ranks register no rank events")
end)

test("scrolling, typing and combat reuse macro lists instead of rebuilding them", function()
  local sim = new("cata")
  for i = 1, 40 do sim.macros[i] = { name = "M" .. i, body = "/cast Kick", perCharacter = i > 30 } end
  local M = sim.ns.Macros
  local counts = { build = 0, layout = 0, info = 0 }
  local build, layout, info = M.Build, M.Window.Layout, sim.env.GetMacroInfo
  M.Build = function(...) counts.build = counts.build + 1; return build(...) end
  M.Window.Layout = function(...) counts.layout = counts.layout + 1; return layout(...) end
  sim.env.GetMacroInfo = function(...) counts.info = counts.info + 1; return info(...) end
  local function reset() for k in pairs(counts) do counts[k] = 0 end end
  sim:command("macros")
  M.Window.SetTab("all")
  local first = M.Window.List()
  reset()
  for _ = 1, 10 do M.Window.Scroll(-1) end
  equal(counts.build, 0, "scrolling the catalog builds no preset again")
  equal(counts.layout, 0, "scrolling keeps the window's geometry")
  assert(M.Window.List() == first, "the same list is reused")
  sim:event("SPELLS_CHANGED")
  assert(M.Window.List() ~= first, "new spells rebuild it")

  M.Window.SetTab("build")
  local p = M.BuildPanel.frame
  reset()
  for _, text in ipairs({ "/c", "/ca", "/cas", "/cast", "/cast K" }) do p.code:SetText(text) end
  p.name:SetText("New name")
  equal(counts.info, 0, "a name no macro has needs no macro reads")
  p.name:SetText("M35")
  equal(p.save:GetText(), "Update macro", "an existing name is still found")
  M.Window.win:Hide()
  reset()
  for _ = 1, 5 do sim:setCombat(true); sim:setCombat(false) end
  equal(counts.info, 0, "combat with the window closed reads no macros")
end)
