local _, ns = ...

-- Text encodings for strings shared through chat, forums and Discord.
local Codec = {}
ns.Codec = Codec

-- Base64 (RFC 4648, standard alphabet, "=" padding). Byte codes collect in
-- one reused buffer and become strings in chunks, not one table per group.
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ENCODE, DECODE, PAD = {}, {}, ("="):byte()
for i = 1, 64 do ENCODE[i - 1] = B64:byte(i); DECODE[B64:byte(i)] = i - 1 end
local CHUNK, codes = 240, {}

local function Flush(out, count)
  out[#out + 1] = string.char(unpack(codes, 1, count))
  return 0
end

function Codec.Encode64(text)
  local out, count = {}, 0
  for i = 1, #text, 3 do
    local a, b, c = text:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    codes[count + 1] = ENCODE[math.floor(n / 262144) % 64]
    codes[count + 2] = ENCODE[math.floor(n / 4096) % 64]
    codes[count + 3] = b and ENCODE[math.floor(n / 64) % 64] or PAD
    codes[count + 4] = c and ENCODE[n % 64] or PAD
    count = count + 4
    if count >= CHUNK then count = Flush(out, count) end
  end
  if count > 0 then Flush(out, count) end
  return table.concat(out)
end

-- Text, or nil when this isn't valid base64. Whitespace is ignored.
function Codec.Decode64(text)
  text = (text or ""):gsub("%s+", "")
  if text == "" or #text % 4 ~= 0 or text:find("[^%w%+/=]") or text:find("=[^=]") then return nil end
  -- At most two padding characters (Profiles.Decode64 accepted "====").
  if text:find("===$") then return nil end
  local out, count = {}, 0
  for i = 1, #text, 4 do
    local a, b, c, d = text:byte(i, i + 3)
    local n = ((DECODE[a] or 0) * 64 + (DECODE[b] or 0)) * 4096 + (DECODE[c] or 0) * 64 + (DECODE[d] or 0)
    codes[count + 1] = math.floor(n / 65536) % 256
    count = count + 1
    if c ~= PAD then codes[count + 1] = math.floor(n / 256) % 256; count = count + 1 end
    if d ~= PAD then codes[count + 1] = n % 256; count = count + 1 end
    if count >= CHUNK then count = Flush(out, count) end
  end
  if count > 0 then Flush(out, count) end
  return table.concat(out)
end

-- Length-prefixed data, never Lua code. Bounded decoding is also used for
-- full setup profiles; imports cannot execute functions or create cycles.
local function KeyOrder(a, b)
  local ta, tb = type(a), type(b)
  if ta == tb then return a < b end
  return ta < tb
end

-- Pack is not re-entrant: one output buffer and one key list per nesting
-- level are reused. A table's keys stay in use only while its own children,
-- one level deeper, are encoded.
local out, size, keyLists = {}, 0, {}
local function Encode(v, depth)
  assert(depth <= 8, "data nesting limit")
  local kind = type(v)
  if kind == "boolean" then size = size + 1; out[size] = v and "b1" or "b0"; return end
  if kind == "string" or kind == "number" then
    assert(kind ~= "number" or (v == v and math.abs(v) ~= math.huge), "invalid number")
    local s = tostring(v)
    out[size + 1], out[size + 2], size = (kind == "string" and "s" or "n") .. #s .. ":", s, size + 2
    return
  end
  assert(kind == "table", "unsupported value")
  local keys, count = keyLists[depth] or {}, 0
  keyLists[depth] = keys
  for key in pairs(v) do
    assert(type(key) == "string" or type(key) == "number", "invalid key")
    count = count + 1; keys[count] = key
  end
  for i = #keys, count + 1, -1 do keys[i] = nil end
  table.sort(keys, KeyOrder)
  size = size + 1; out[size] = "t" .. count .. ":"
  for i = 1, count do
    local key = keys[i]
    Encode(key, depth + 1); Encode(v[key], depth + 1)
  end
end

-- Drop references to the encoded data; key lists are truncated on reuse.
local function Reset()
  for i = size, 1, -1 do out[i] = nil end
  size = 0
end

function Codec.Pack(value)
  Reset()
  local ok, err = pcall(Encode, value, 0)
  local text = ok and table.concat(out, "", 1, size)
  Reset()
  if not ok then error(err, 0) end
  return text
end

function Codec.Unpack(text)
  if type(text) ~= "string" or #text > 131072 then return nil, "data too large" end
  local pos, values = 1, 0
  local function decode(depth)
    values = values + 1
    assert(depth <= 8 and values <= 10000, "data limit")
    local kind = text:sub(pos, pos); pos = pos + 1
    if kind == "b" then
      local value = text:sub(pos, pos); pos = pos + 1
      assert(value == "1" or value == "0", "invalid boolean")
      return value == "1"
    end
    assert(kind == "s" or kind == "n" or kind == "t", "invalid type")
    local colon = assert(text:find(":", pos, true), "missing length")
    local digits = text:sub(pos, colon - 1)
    assert(digits:match("^%d+$") and #digits <= 6, "invalid length")
    local length = tonumber(digits); pos = colon + 1
    if kind == "t" then
      assert(length <= 2000, "too many entries")
      local out = {}
      for _ = 1, length do
        local key = decode(depth + 1)
        assert(type(key) == "string" or type(key) == "number", "invalid key")
        assert(out[key] == nil, "duplicate key")
        out[key] = decode(depth + 1)
      end
      return out
    end
    assert(pos + length - 1 <= #text, "truncated data")
    local result = text:sub(pos, pos + length - 1); pos = pos + length
    if kind == "s" then return result end
    local n = tonumber(result)
    assert(n and n == n and math.abs(n) ~= math.huge, "invalid number")
    return n
  end
  local ok, result = pcall(decode, 0)
  if not ok or pos ~= #text + 1 then return nil, "invalid data" end
  return result
end
