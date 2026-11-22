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
