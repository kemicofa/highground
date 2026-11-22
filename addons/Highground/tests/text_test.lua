-- ns.Text (libs/core/Text.lua): UTF-8 lengths, substrings and byte cuts.
-- Run from addons/Highground: luajit tests/text_test.lua
local t = dofile("../../tools/harness.lua")("text")
local ns = {}
assert(loadfile("libs/core/Text.lua"))("Highground", ns)
local Text, equal = ns.Text, t.equal

t.test("lengths and characters count letters, not bytes", function()
  equal(Text.Len(""), 0, "empty")
  equal(Text.Len("Kick"), 4, "ASCII")
  equal(Text.Len("Élodie"), 6, "two-byte letter")
  equal(Text.Len("Анна Смит"), 9, "Cyrillic and a space")
  equal(Text.Len("技能"), 2, "three-byte characters")
  equal(Text.Len("😀!"), 2, "four-byte character")
  local chars = {}
  for ch in Text.Chars("aé技") do chars[#chars + 1] = ch end
  equal(table.concat(chars, "|"), "a|é|技", "whole characters")
end)

t.test("substrings follow string.sub's rules by character", function()
  equal(Text.Sub("Ледяная глыба", 1, 7), "Ледяная", "first word")
  equal(Text.Sub("Ледяная глыба", 9), "глыба", "to the end")
  equal(Text.Sub("Ледяная глыба", -5), "глыба", "negative start")
  equal(Text.Sub("Ледяная глыба", 2, -7), "едяная", "negative end")
  equal(Text.Sub("abc", 0, 99), "abc", "clamped")
  equal(Text.Sub("abc", 3, 2), "", "empty range")
  equal(Text.Sub("", 1, 3), "", "empty string")
end)

t.test("byte cuts never split a character", function()
  equal(Text.ClipBytes("Kick", 16), "Kick", "short text stays")
  equal(Text.ClipBytes("Hammer of Justice", 13), "Hammer of Jus", "ASCII cuts at the limit")
  equal(Text.ClipBytes("Coup de bouclÓÓ", 15), "Coup de bouclÓ", "never half of a two-byte letter")
  equal(Text.ClipBytes("Удар щитом", 5), "Уд", "Cyrillic keeps whole letters")
  equal(Text.ClipBytes("技能名称", 7), "技能", "three-byte characters")
  equal(Text.ClipBytes("😀😀", 5), "😀", "four-byte characters")
  equal(Text.ClipBytes("é", 1), "", "nothing fits")
  equal(Text.ClipBytes("abc", 0), "", "zero bytes")
  equal(Text.ClipBytes("abc", -1), "", "negative limit")
  local s = "Grâce de l'Éveil 技"
  for limit = 0, #s + 1 do
    local cut = Text.ClipBytes(s, limit)
    assert(#cut <= limit, "fits " .. limit)
    equal(s:sub(1, #cut), cut, "a prefix at " .. limit)
    local after = s:byte(#cut + 1)
    assert(not after or after < 128 or after >= 192, "ends between characters at " .. limit)
    assert(#cut == #s or limit - #cut < 3, "drops at most the split character at " .. limit)
  end
end)

t.finish("Text: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
