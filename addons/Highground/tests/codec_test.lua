local t = dofile("../../tools/harness.lua")("codec")
local ns = {}
setfenv(assert(loadfile("libs/core/Codec.lua")), setmetatable({}, { __index = _G }))("Highground", ns)
local Codec = ns.Codec

-- The previous implementations: peers hash and compare Pack output, so the
-- bytes must never change.
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function Encode64(text)
  local out = {}
  for i = 1, #text, 3 do
    local a, b, c = text:byte(i, i + 2)
    local n = a * 65536 + (b or 0) * 256 + (c or 0)
    local chars = { math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64 }
    for j = 1, 4 do chars[j] = B64:sub(chars[j] + 1, chars[j] + 1) end
    if not b then chars[3] = "=" end
    if not c then chars[4] = "=" end
    out[#out + 1] = table.concat(chars)
  end
  return table.concat(out)
end
local function Pack(value)
  local function encode(v, depth)
    local kind = type(v)
    if kind == "boolean" then return v and "b1" or "b0" end
    if kind == "string" or kind == "number" then
      local s = tostring(v)
      return (kind == "string" and "s" or "n") .. #s .. ":" .. s
    end
    local keys, out = {}, {}
    for key in pairs(v) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return type(a) == type(b) and a < b or type(a) < type(b) end)
    out[1] = "t" .. #keys .. ":"
    for _, key in ipairs(keys) do out[#out + 1] = encode(key, depth + 1); out[#out + 1] = encode(v[key], depth + 1) end
    return table.concat(out)
  end
  return encode(value, 0)
end

math.randomseed(225)
local function Bytes(n)
  local out = {}
  for i = 1, n do out[i] = string.char(math.random(0, 255)) end
  return table.concat(out)
end
local function Value(depth)
  local roll = math.random(depth >= 7 and 4 or 6)
  if roll == 1 then return math.random() < 0.5 end
  if roll == 2 then return math.random(-100000, 100000) / (math.random(1, 3) == 1 and 7 or 1) end
  if roll <= 4 then return Bytes(math.random(0, 40)) end
  local out = {}
  for i = 1, math.random(0, 6) do out[i] = Value(depth + 1) end
  for _ = 1, math.random(0, 6) do out[Bytes(math.random(1, 8))] = Value(depth + 1) end
  if math.random() < 0.3 then out[math.random(-5, 5) + 0.5] = Value(depth + 1) end
  return out
end

t.test("base64 matches the previous encoder and round-trips every length", function()
  for n = 0, 600 do
    local text = Bytes(n)
    local coded = Codec.Encode64(text)
    t.equal(coded, Encode64(text), "same encoding for " .. n .. " bytes")
    if n > 0 then t.equal(Codec.Decode64(coded), text, "round trip for " .. n .. " bytes") end
  end
end)

t.test("pack matches the previous encoder and unpacks to equal data", function()
  for i = 1, 300 do
    local value = Value(0)
    local packed = Codec.Pack(value)
    t.equal(packed, Pack(value), "same bytes for sample " .. i)
    local unpacked, problem = Codec.Unpack(packed)
    t.equal(problem, nil, "unpacks sample " .. i)
    t.equal(Codec.Pack(unpacked), packed, "round trip for sample " .. i)
  end
end)

t.test("failed packs leave no state behind", function()
  local deep = {}
  local cursor = deep
  for _ = 1, 9 do cursor.next = {}; cursor = cursor.next end
  for _, bad in ipairs({ deep, { x = 0 / 0 }, { x = math.huge }, { f = print }, { [true] = 1 } }) do
    t.equal(pcall(Codec.Pack, bad), false, "invalid data rejected")
    t.equal(Codec.Pack({ a = 1, b = { "x" } }), "t2:s1:an1:1s1:bt1:n1:1s1:x", "next pack starts clean")
  end
end)

t.test("encoding reuses its buffers", function()
  local record = { id = "abcdef0123", name = "First Last-PvP", at = 1800000000, tags = { "a", "b" },
    meta = { by = "Mod-Realm", flags = { x = true, y = false } } }
  local list = {}
  for i = 1, 50 do list[i] = record end
  local text = string.rep("profile data ", 400)
  Codec.Pack(list); Codec.Encode64(text)
  if jit then jit.off() end
  collectgarbage("collect"); collectgarbage("stop")
  local before = collectgarbage("count")
  for _ = 1, 20 do Codec.Pack(list) end
  local packed = collectgarbage("count") - before
  before = collectgarbage("count")
  for _ = 1, 20 do Codec.Decode64(Codec.Encode64(text)) end
  local base64 = collectgarbage("count") - before
  collectgarbage("restart")
  if jit then jit.on() end
  -- Output strings and chunk lists remain; per-value tables do not.
  assert(packed < 160, "Pack allocated " .. packed .. " KiB")
  assert(base64 < 240, "base64 allocated " .. base64 .. " KiB")
end)

t.finish("Codec: " .. t.tests .. " tests, " .. t.checks .. " checks")
