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
