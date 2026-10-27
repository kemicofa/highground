local _, ns = ...

-- Text encodings for strings shared through chat, forums and Discord.
local Codec = {}
ns.Codec = Codec

-- Base64 (RFC 4648, standard alphabet, "=" padding).
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64INDEX = {}
for i = 1, 64 do B64INDEX[B64:sub(i, i)] = i - 1 end

function Codec.Encode64(text)
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

-- Text, or nil when this isn't valid base64. Whitespace is ignored.
function Codec.Decode64(text)
  text = (text or ""):gsub("%s+", "")
  if text == "" or #text % 4 ~= 0 or text:find("[^%w%+/=]") or text:find("=[^=]") then return nil end
  -- At most two padding characters (Profiles.Decode64 accepted "====").
  if text:find("===$") then return nil end
  local out = {}
  for i = 1, #text, 4 do
    local n, pad = 0, 0
    for j = i, i + 3 do
      local ch = text:sub(j, j)
      if ch == "=" then pad = pad + 1 end
      n = n * 64 + (B64INDEX[ch] or 0)
    end
    local bytes = string.char(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
    out[#out + 1] = bytes:sub(1, 3 - pad)
  end
  return table.concat(out)
end
