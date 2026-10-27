-- Macros.Merge (three-way line merge) and Macros.FromForm (builder form to
-- builder options): pure functions of the macro builder.
local test, new, equal = ...

test("merge: only one side changed takes that side", function()
  local Merge = new("cata").ns.Macros.Merge
  local base = "#showtooltip\n/cast Kick"
  equal(Merge(base, base, base), base, "nothing changed")
  equal(Merge(base, base, "#showtooltip\n/cast [@focus] Kick"), "#showtooltip\n/cast [@focus] Kick",
    "builder change taken")
  equal(Merge(base, "#showtooltip\n/cast Kick\n/say kicked", base), "#showtooltip\n/cast Kick\n/say kicked",
    "hand edit kept")
  equal(Merge(base, "/cast Kick", base), "/cast Kick", "line deleted by hand stays deleted")
  equal(Merge("/stopcasting\n/cast Kick", "/stopcasting\n/cast Kick\n/say hi", "/cast Kick"), "/cast Kick\n/say hi",
    "line the builder drops goes, hand line stays")
end)

test("merge: empty base and empty sides", function()
  local Merge = new("cata").ns.Macros.Merge
  equal(Merge("", "/say hi", "#showtooltip\n/cast Kick"), "#showtooltip\n/cast Kick\n/say hi",
    "edited macro: builder lines first, typed ones after")
  equal(Merge("", "", "/cast Kick"), "/cast Kick", "empty box takes the builder's text")
  equal(Merge("/cast Kick", "/cast Kick", ""), "", "builder clears its own lines")
  equal(Merge("/cast Kick", "", "/cast Kick"), "", "everything deleted by hand stays deleted")
end)

test("merge: both sides changed the same lines", function()
  local Merge = new("cata").ns.Macros.Merge
  equal(Merge("/cast Kick", "/cast Kick!", "/cast [@focus] Kick"), "/cast [@focus] Kick\n/cast Kick!",
    "builder wins, hand line kept after it")
  equal(Merge("/cast Kick", "/cast [@focus] Kick", "/cast [@focus] Kick"), "/cast [@focus] Kick",
    "same change on both sides once")
  equal(Merge("a\nb\nc", "a\nB\nc", "a\nb2\nc"), "a\nb2\nB\nc", "conflict settled inside its stretch")
  equal(Merge("a\nb", "a\nb\n", "a\nb"), "a\nb", "trailing newline ignored")
end)

test("form: resets for sequences, uses and cancels for the rest", function()
  local FromForm = new("cata").ns.Macros.FromForm
  local reset, uses, cancel = FromForm({ verb = "castsequence", resetSeconds = "8.7", reset_combat = true,
    reset_target = true, trinket1 = true, item = "Healthstone", aura = " Ice Block,, Divine Shield " })
  equal(reset, "8/target/combat", "whole seconds, then reset words in order")
  equal(#uses, 0, "no /use in a sequence")
  equal(table.concat(cancel, "|"), "Ice Block|Divine Shield", "auras split and trimmed")
  reset, uses, cancel = FromForm({ verb = "cast", resetSeconds = "8", trinket1 = true, trinket2 = true,
    item = "Healthstone, 10 ,", reset_shift = true })
  equal(reset, nil, "no reset outside a sequence")
  equal(table.concat(uses, "|"), "13|14|Healthstone|10", "trinkets, then items")
  equal(cancel, nil, "no auras")
  reset = FromForm({ verb = "castsequence", resetSeconds = "0.5" })
  equal(reset, "", "under a second: no time limit")
end)

test("Copy & Edit keeps a sequence's resets", function()
  local sim = new("cata")
  sim:command("macros")
  local M = sim.ns.Macros
  local entry = { name = "Seq", spell = "Frostbolt, Fire Blast", verb = "castsequence", reset = "4/target/shift" }
  M.Window.CopyEdit(entry)
  local p = M.BuildPanel.frame
  equal(p.code:GetPlainText(), "#showtooltip\n/castsequence reset=4/target/shift Frostbolt, Fire Blast", "same macro in the builder")
  equal(p.resetSeconds.text, "4", "seconds in their field")
end)
