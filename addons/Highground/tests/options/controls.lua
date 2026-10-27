-- Cata settings pages: one trinket row, inherited spell overrides, resets.
local o = ...
local client, input, visible, equal = o.client, o.input, o.visible, o.equal
local cata = client("cata")
local pageNames = {}
for _, page in ipairs(cata.ui.pages) do
  assert(not pageNames[page.name], "duplicate options page")
  pageNames[page.name] = true
end
equal(pageNames.Defensives, nil, "separate duplicate defensive page is removed")
equal(pageNames.Cooldowns, true, "cooldowns have one page")
equal(pageNames["Cooldown tracking"], true, "Cata has per-spell tracking controls")
equal(pageNames["Advanced multipliers"], true, "secondary scoring controls are explicitly advanced")
local trinkets = 0
for _, f in ipairs(cata.frames) do
  if f.kind == "FontString" and f.text and f.text:find("trinket", 1, true) then
    if input(f.parent) then trinkets = trinkets + 1 end
  end
end
equal(trinkets, 1, "exactly one editable trinket row")
equal(cata:find("FontString", "Orb carrier"), nil, "Cata hides unsupported orb tuning")
local painRow = false
for _, f in ipairs(cata.frames) do
  if f.kind == "FontString" and f.text == "Pain Suppression" and input(f.parent) then painRow = true end
end
equal(painRow, false, "external spells have no numeric scoring override")
local spell = cata:row("Evasion")
equal(spell:GetText(), "", "spell override initially inherits")
equal(visible(spell), false, "spell overrides are collapsed by default")
local expand = assert(cata:find("Button", "Show spell overrides"))
expand.scripts.OnClick(expand)
equal(visible(spell), true, "optional spell controls expand")
cata:edit("Defensive on cooldown (default per spell)", "9")
equal(spell:GetText(), "", "general tuning does not create a per-spell override")
assert(cata:find("FontString", "inherits 9"), "inherited defaults refresh on the same page")
cata:edit("Evasion", "0")
equal(cata.db.points.kit5277, 0, "zero is a real spell override")
cata:edit("Defensive on cooldown (default per spell)", "11")
equal(spell:GetText(), "0", "explicit override survives changing its general default")
cata:edit("Evasion", "")
equal(cata.db.points.kit5277, nil, "clearing the field restores inheritance")
equal(spell:GetText(), "", "restored inheritance remains clear in the UI")
cata:edit("Evasion", "11")
equal(cata.db.points.kit5277, 11, "entering the current default still creates an explicit override")
cata:edit("Defensive on cooldown (default per spell)", "12")
equal(spell:GetText(), "11", "explicit values stay fixed when the default changes")
for _, child in ipairs(spell.parent.parent.children) do
  if child.kind == "Button" and child.text == "x" then child.scripts.OnClick(child) end
end
equal(cata.db.points.kit5277, nil, "the spell reset button restores inheritance")
equal(spell:GetText(), "", "reset clears the override field")
assert(cata:row("Barkskin"), "Barkskin uses the same override as every other defensive")
return cata
