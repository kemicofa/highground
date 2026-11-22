local _, ns = ...

---------------------------------------------------------------------------
-- UTF-8 text (ns.Text). WoW strings are UTF-8 bytes, while # and
-- string.sub count bytes: a byte cut can split a letter of a localized or
-- accented name. A character is a lead byte and its continuation bytes;
-- stray continuation bytes at the start are skipped. No WoW API calls.
---------------------------------------------------------------------------
local Text = {}
ns.Text = Text

-- Pattern of one character, for gmatch.
Text.CHAR = "[^\128-\191][\128-\191]*"

-- Iterator over the characters of s.
function Text.Chars(s) return s:gmatch(Text.CHAR) end

-- Number of characters in s.
function Text.Len(s)
  local _, n = s:gsub(Text.CHAR, "")
  return n
end

-- s cut to at most maxBytes bytes without splitting a character, for limits
-- the game counts in bytes (macro names and bodies, chat lines).
function Text.ClipBytes(s, maxBytes)
  if #s <= maxBytes then return s end
  local cut = math.max(0, maxBytes)
  while cut > 0 do
    local b = s:byte(cut + 1)
    if b < 128 or b >= 192 then break end -- the next byte starts a character
    cut = cut - 1
  end
  return s:sub(1, cut)
end

-- Characters i to j of s, with string.sub's rules: j defaults to the end and
-- negative positions count from the end.
function Text.Sub(s, i, j)
  local starts = {}
  for at in s:gmatch("()" .. Text.CHAR) do starts[#starts + 1] = at end
  local n = #starts
  i, j = i or 1, j or -1
  if i < 0 then i = n + i + 1 end
  if j < 0 then j = n + j + 1 end
  if i < 1 then i = 1 end
  if j > n then j = n end
  if i > j then return "" end
  return s:sub(starts[i], (starts[j + 1] or #s + 1) - 1)
end

-- UTF-8 encoding of a code point below U+10000.
local function Encode(cp)
  if cp < 0x80 then return string.char(cp) end
  if cp < 0x800 then return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40) end
  return string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end

-- Lowercase letter -> uppercase letter for Latin-1, Latin Extended-A,
-- Greek and Cyrillic. Letters with no single uppercase form (ß, ŉ, ΐ) and
-- every other script (CJK, Hangul) stay as they are.
local UPPER = {}
local function Map(lower, upper) UPPER[Encode(lower)] = Encode(upper) end
local function Pairs(first, last, upperFirst) -- alternating upper/lower pairs
  for cp = first, last do
    if (cp - first) % 2 == (upperFirst and 1 or 0) then Map(cp, upperFirst and cp - 1 or cp + 1) end
  end
end
for cp = 0xE0, 0xFE do if cp ~= 0xF7 then Map(cp, cp - 0x20) end end -- à..þ except ÷
Map(0xFF, 0x178) -- ÿ
Pairs(0x100, 0x12F, true); Map(0x131, 0x49); Pairs(0x132, 0x137, true) -- ı -> I
Pairs(0x139, 0x148, true); Pairs(0x14A, 0x177, true); Pairs(0x179, 0x17E, true)
for cp = 0x3B1, 0x3CB do if cp ~= 0x3C2 then Map(cp, cp - 0x20) end end
Map(0x3C2, 0x3A3) -- final sigma
Map(0x3AC, 0x386); Map(0x3AD, 0x388); Map(0x3AE, 0x389); Map(0x3AF, 0x38A)
Map(0x3CC, 0x38C); Map(0x3CD, 0x38E); Map(0x3CE, 0x38F)
for cp = 0x430, 0x44F do Map(cp, cp - 0x20) end -- а..я
for cp = 0x450, 0x45F do Map(cp, cp - 0x50) end -- ѐ..џ
Pairs(0x460, 0x481, true); Pairs(0x48A, 0x4BF, true); Pairs(0x4C1, 0x4CE, true); Map(0x4CF, 0x4C0)
Pairs(0x4D0, 0x52F, true)
Text.UPPER = UPPER

local function UpperPlain(s) return (s:upper():gsub("[\192-\247][\128-\191]+", UPPER)) end

-- Where the escape sequence starting at s[i] == "|" ends: colors, textures,
-- atlases and links stay byte for byte.
local function EscapeEnd(s, i)
  local c = s:sub(i + 1, i + 1)
  if c == "c" and s:find("^%x%x%x%x%x%x%x%x", i + 2) then return i + 9 end
  local close = ({ T = "|t", A = "|a", H = "|h", K = "|k" })[c]
  if close then
    local _, e = s:find(close, i + 2, true)
    if c == "H" and e then _, e = s:find("|h", e + 1, true) end -- |H…|htext|h
    return e or #s
  end
  if c ~= "" then return i + 1 end -- |r, |n, ||
  return i
end

-- s in capitals for display: ASCII and accented, Greek and Cyrillic letters;
-- WoW's string.upper changes ASCII only. Escape sequences are kept.
function Text.Upper(s)
  if type(s) ~= "string" then return s end
  if not s:find("|", 1, true) then return UpperPlain(s) end
  local out, at = {}, 1
  while at <= #s do
    local i = s:find("|", at, true)
    if not i then out[#out + 1] = UpperPlain(s:sub(at)); break end
    out[#out + 1] = UpperPlain(s:sub(at, i - 1))
    local e = EscapeEnd(s, i)
    out[#out + 1] = s:sub(i, e)
    at = e + 1
  end
  return table.concat(out)
end

-- s with its first character in capitals (Text.Upper), for sentences that
-- may start with an accented or Cyrillic letter.
function Text.UpperFirst(s)
  if type(s) ~= "string" then return s end
  local first, rest = s:match("^(" .. Text.CHAR .. ")(.*)$")
  if not first then return s end
  return Text.Upper(first) .. rest
end
