-- Optional layout measurements for UI regressions and local previews.
-- Resolves native frame anchors; font metrics are approximate (no game
-- renderer). Install in the simulator's configure callback, before load.
return function(sim)
  local env = sim.env
  local methods = getmetatable(env.UIParent).__index
  local function wrap(name, flag)
    local original = methods[name]
    methods[name] = function(f, ...) f[flag] = true; return original(f, ...) end
  end
  wrap("SetWidth", "widthSet"); wrap("SetHeight", "heightSet")
  local size = methods.SetSize
  methods.SetSize = function(f, w, h) f.widthSet, f.heightSet = true, true; return size(f, w, h) end
  local clear = methods.ClearAllPoints
  methods.ClearAllPoints = function(f) f.allPoints = nil; clear(f) end
  for _, pair in ipairs({ { "SetJustifyH", "justifyH" }, { "SetJustifyV", "justifyV" },
    { "SetWordWrap", "wordWrap" }, { "SetMultiLine", "multiLine" } }) do
    methods[pair[1]] = function(f, value) f[pair[2]] = value end
  end
  local texture = methods.CreateTexture
  methods.CreateTexture = function(f, name, layer, _, sub)
    local t = texture(f, name); t.layer, t.subLayer = layer, sub; return t
  end
  local function plain(f)
    return (f.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("||", "|")
  end
  local function charWidth(f)
    local face = f.font and f.font[1] or ""
    return (f.font and f.font[2] or 12) * (face:find("FRIZQT") and 0.8 or face:find("Mono") and 0.61 or 0.49)
  end
  local function textWidth(f)
    local longest = 0
    for line in (plain(f) .. "\n"):gmatch("(.-)\n") do longest = math.max(longest, #line) end
    return longest * charWidth(f)
  end
  local function textHeight(f, width)
    local n = 0
    for line in (plain(f) .. "\n"):gmatch("(.-)\n") do
      n = n + ((f.wordWrap or f.multiLine) and math.max(1, math.ceil(#line * charWidth(f) / math.max(1, width))) or 1)
    end
    return n * (f.font and f.font[2] or 12) * 1.2
  end
  local fractions = { TOPLEFT = { 0, 0 }, TOP = { 0.5, 0 }, TOPRIGHT = { 1, 0 },
    LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 1 }, BOTTOM = { 0.5, 1 }, BOTTOMRIGHT = { 1, 1 } }
  local resolving = {}
  local function bounds(f)
    if not f or type(f) ~= "table" then return { 0, 0, 0, 0 } end
    if resolving[f] then return { 0, 0, f.width or 0, f.height or 0 } end
    resolving[f] = true
    if f.allPoints then
      local r = bounds(f.allPoints); resolving[f] = nil; return r
    end
    local w, h = f.widthSet and f.width or 0, f.heightSet and f.height or 0
    if f.kind == "FontString" then
      if not f.widthSet then w = textWidth(f) end
      if not f.heightSet then h = textHeight(f, w) end
    end
    local points, last = {}, {}
    for _, a in ipairs(f.points) do last[a[1]] = a end
    for _, a in ipairs(f.points) do
      if last[a[1]] == a then
      local point, relative, rp, dx, dy = unpack(a)
      if type(relative) == "number" or relative == nil then
        dx, dy, relative, rp = relative or 0, rp or 0, f.parent, point
      elseif type(rp) == "number" or rp == nil then
        dx, dy, rp = rp or 0, dx or 0, point
      end
      if type(relative) == "string" then relative = env[relative] end
      local r = bounds(relative)
      local frac, rfrac = fractions[point], fractions[rp]
      points[#points + 1] = { frac[1], frac[2], r[1] + r[3] * rfrac[1] + (dx or 0), r[2] + r[4] * rfrac[2] - (dy or 0) }
      end
    end
    for i, a in ipairs(points) do
      for j = i + 1, #points do
        local b = points[j]
        if math.abs(a[1] - b[1]) == 1 then w = math.abs(a[3] - b[3]) end
        if math.abs(a[2] - b[2]) == 1 then h = math.abs(a[4] - b[4]) end
      end
    end
    if f.kind == "FontString" and not f.heightSet then h = textHeight(f, w) end
    if f.multiLine then h = math.max(h, textHeight(f, w)) end
    local parent = #points == 0 and bounds(f.parent) or nil
    local x, y = parent and parent[1] or 0, parent and parent[2] or 0
    if points[1] then x, y = points[1][3] - w * points[1][1], points[1][4] - h * points[1][2] end
    if f.parent and f.parent.scrollChild == f then y = y - (f.parent.verticalScroll or 0) end
    resolving[f] = nil
    return { x, y, w, h }
  end
  sim.bounds = bounds
  methods.GetWidth = function(f) return bounds(f)[3] end
  methods.GetHeight = function(f) return bounds(f)[4] end
  methods.GetStringWidth = textWidth
  methods.GetStringHeight = function(f) return textHeight(f, f:GetWidth()) end
  env.UIParent:SetSize(1280, 820)
end
