local support = ...
local check = support.check

-- Pin colours come from theme tokens and follow a theme switch.
local s, ns = support.client()
local env = setmetatable({}, { __index = _G })
env.CreateFromMixins = function(...)
  local out = {}
  for i = 1, select("#", ...) do for k, v in pairs(select(i, ...) or {}) do out[k] = v end end
  return out
end
env.MapCanvasPinMixin, env.MapCanvasDataProviderMixin = {}, {}
env.CreateFrame = function()
  local f = {}
  function f:SetScript() end
  function f:RegisterEvent() end
  return f
end
ns.UIConfig = ns.UIConfig or { map = { fontSize = 11 } }
setfenv(assert(loadfile("map/Pins.lua")), env)("Highground", ns)

local function region(kind)
  local r = { kind = kind }
  function r:GetObjectType() return self.kind end
  function r:SetVertexColor(red, g, b, a) self.vertex = { red, g, b, a } end
  function r:SetTextColor(red, g, b, a) self.color = { red, g, b, a } end
  for _, m in ipairs({ "SetFont", "SetShadowColor", "SetShadowOffset", "SetText", "Show", "Hide", "SetShown",
    "SetSize", "SetAtlas", "SetTexture", "SetTexCoord", "SetDesaturated" }) do r[m] = function() end end
  return r
end
local pin = setmetatable({ Ring = region("Texture"), Mark = region("Texture"), Icon = region("Texture"),
  Label = region("FontString") }, { __index = env.HighgroundPinMixin })
for _, m in ipairs({ "SetScalingLimits", "UseFrameLevelType", "SetSize", "SetAlpha", "SetPosition" }) do
  pin[m] = function() end
end
pin:OnLoad()

s.db.intel = true
ns.Intel.Record(support.key, 0.4, 0.4, 3, "Me", s.now, nil, "coords")
s.now = s.now + 10 -- not fresh: label shows the age in labelColor
local item = s.items()[1]
check(item and item.labelColor == "mapLabel", "intel pin labels use a theme token")
pin:OnAcquired(item)
local muted = ns.Theme.Rgb("mapLabel")
check(pin.Label.color[1] == muted[1] and pin.Mark.vertex[1] == ns.Theme.Rgb("mapMark")[1], "pin painted from tokens")

assert(ns.Theme.Register("pintest", { color = { mapLabel = { 0.1, 0.2, 0.3 }, mapMark = { 0.4, 0.5, 0.6 } } }))
assert(ns.Theme.Use("pintest"))
check(pin.Label.color[1] == 0.1 and pin.Label.color[3] == 0.3, "theme switch repaints the pin label")
check(pin.Mark.vertex[1] == 0.4 and pin.Mark.vertex[4] == 0.9, "theme switch repaints the kill mark, alpha kept")
-- A pooled pin reused with a computed colour stops following the theme.
local ring = { 0.2, 0.3, 0.4 }
pin:OnAcquired({ x = 0.5, y = 0.5, ring = "textDim" })
check(pin.Ring.vertex[1] == ns.Theme.Rgb("textDim")[1], "token ring painted")
pin:OnAcquired({ x = 0.5, y = 0.5, ring = ring })
assert(ns.Theme.Use("highground"))
check(pin.Ring.vertex[1] == 0.2 and pin.Ring.vertex[3] == 0.4, "computed ring is not repainted")
check(pin.Label.color[1] == 1, "an item without labelColor gets the white token")
