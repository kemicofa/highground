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

t.test("capitals cover accented, Greek and Cyrillic letters and keep escapes", function()
  local U = Text.Upper
  equal(U("Champ de bataille"), "CHAMP DE BATAILLE", "ASCII")
  equal(U("Arène · Œuvre çà"), "ARÈNE · ŒUVRE ÇÀ", "Latin-1 and Œ")
  equal(U("Schlachtfeld für Größe"), "SCHLACHTFELD FÜR GRÖßE", "ß has no single capital and stays")
  equal(U("żółć łódź ı ÿ"), "ŻÓŁĆ ŁÓDŹ I Ÿ", "Latin Extended-A, dotless i and ÿ")
  equal(U("Поле боя ёлка ґ"), "ПОЛЕ БОЯ ЁЛКА Ґ", "Cyrillic, ё and Ukrainian ґ")
  equal(U("Ελλάδα σοφός"), "ΕΛΛΆΔΑ ΣΟΦΌΣ", "Greek with tonos and final sigma")
  equal(U("战场 전장 戰場"), "战场 전장 戰場", "CJK and Hangul unchanged")
  equal(U("|cff00ff00grün|r ok"), "|cff00ff00GRÜN|r OK", "colour codes kept")
  equal(U("a|TInterface\\x:12|tb"), "A|TInterface\\x:12|tB", "texture paths kept")
  equal(U("x|Hitem:1|h[épée]|hy"), "X|Hitem:1|h[épée]|hY", "links kept")
  equal(U("100%|n||é"), "100%|n||É", "line breaks and escaped bars")
  equal(U(""), "", "empty")
  equal(U(nil), nil, "non-strings pass through")
  for lower, upper in pairs(Text.UPPER) do
    equal(Text.Len(lower), 1, "one letter"); equal(Text.Len(upper), 1, "to one letter")
  end
end)

t.finish("Text: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
