local _, ns = ...
local Theme = ns.Theme

-- Class colours are game data: keep their hue for icons, strips and bars.
-- Text may need lighter/darker ink, especially yellow and white on linen.
-- Cache per palette and repaint even windows that are currently idle.
local cache = {}
local classTexts = setmetatable({}, { __mode = "k" })

local function Luminance(c)
  local function Linear(v) return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
  return Linear(c[1]) * 0.2126 + Linear(c[2]) * 0.7152 + Linear(c[3]) * 0.0722
end

local function Mix(fg, bg, alpha)
  local c = {}
  for i = 1, 3 do c[i] = fg[i] * alpha + bg[i] * (1 - alpha) end
  return c
end

local function Readable(c, backgrounds)
  local l = Luminance(c)
  for _, bg in ipairs(backgrounds) do
    if (math.max(l, bg) + 0.05) / (math.min(l, bg) + 0.05) < 4.5 then return false end
  end
  return true
end

function Theme.ClassColor(c)
  local r, g, b = c.r or c[1], c.g or c[2], c.b or c[3]
  local key = r .. ":" .. g .. ":" .. b
  if cache[key] then return cache[key] end
  local original, backgrounds = { r, g, b }, {}
  for _, name in ipairs({ "bg", "surface", "surfaceRaised" }) do
    for _, fill in ipairs({ "black", "white" }) do
      local bg = Mix(Theme.Rgb(fill), Theme.Rgb(name), Theme.Alpha("healthFill"))
      local hover = Theme.Rgb("overlayHover")
      backgrounds[#backgrounds + 1] = Luminance(Mix(hover, bg, hover[4]))
    end
  end
  local ink, result = Theme.Rgb("text"), original
  for step = 0, 20 do
    result = Mix(ink, original, step / 20)
    if Readable(result, backgrounds) then break end
  end
  cache[key] = result
  return result
end

function Theme.PaintClass(fs, color)
  Theme.Unpaint(fs)
  fs.wbClass = color
  classTexts[fs] = true
  fs:SetTextColor(unpack(Theme.ClassColor(color)))
end

Theme.OnChange(function()
  wipe(cache)
  for fs in pairs(classTexts) do
    if fs.wbClass then fs:SetTextColor(unpack(Theme.ClassColor(fs.wbClass)))
    else classTexts[fs] = nil end
  end
end)
