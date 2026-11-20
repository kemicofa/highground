local _, ns = ...
local Core, Theme, Kit, Motion = ns.Core, ns.Theme, ns.Kit, ns.Motion

-- Default controls share a tiny alpha atlas. Custom radii keep the band
-- fallback; neither path needs masks or client-specific atlas APIs.
local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local function Corner(parent, layer, color, alpha, corner, offset, size, spread)
  local left, top = corner:find("LEFT"), corner:find("TOP")
  local t = parent:CreateTexture(nil, layer)
  t:SetTexture(Core.CONTROL_CORNERS)
  local u, v = offset / 32, (offset + size) / 32
  t:SetTexCoord(left and u or v, left and v or u, top and 0 or size / 16, top and size / 16 or 0)
  t:SetSize(size, size)
  spread = spread or 0
  t:SetPoint(corner, left and -spread or spread, top and spread or -spread)
  t.wbCorner = true
  return Theme.Tint(t, color, alpha)
end

local function CurveInset(radius, y)
  return radius - math.sqrt(math.max(0, radius * radius - (radius - y) ^ 2))
end

function Kit.PaintFill(fill, color, alpha)
  Theme.Paint(fill, color, alpha)
  for _, part in ipairs(fill.parts or {}) do Theme.Paint(part, color, alpha, part.wbMode) end
end

-- Optional layer and vertical gradient share the same outline as the face.
function Kit.RoundedFill(parent, color, alpha, layer, gradient)
  local radius = parent.cornerRadius
  layer = layer or "BACKGROUND"
  local fill = Theme.Fill(parent, layer, color, alpha)
  fill:SetPoint("TOPLEFT", 0, -radius); fill:SetPoint("BOTTOMRIGHT", 0, radius)
  fill.parts = {}
  if radius == 5 and Core.CONTROL_CORNERS then
    for _, side in ipairs({ "TOP", "BOTTOM" }) do
      local band = Theme.Fill(parent, layer, color, alpha)
      band:SetPoint(side .. "LEFT", radius, 0); band:SetPoint(side .. "RIGHT", -radius, 0)
      band:SetHeight(radius)
      fill.parts[#fill.parts + 1] = band
    end
    for _, corner in ipairs(CORNERS) do
      fill.parts[#fill.parts + 1] = Corner(parent, layer, color, alpha, corner, 0, radius)
    end
  else for y = 0, radius - 1 do
    local inset = CurveInset(radius, y + 0.5)
    for _, side in ipairs({ "TOP", "BOTTOM" }) do
      local band = Theme.Fill(parent, layer, color, alpha)
      local offset = side == "TOP" and -y or y
      band:SetPoint(side .. "LEFT", inset, offset); band:SetPoint(side .. "RIGHT", -inset, offset)
      band:SetHeight(1)
      fill.parts[#fill.parts + 1] = band
    end
  end end
  if gradient then
    local function Shade(region, from, to)
      region.wbGradient = region.wbGradient or {}
      region.wbGradient[1], region.wbGradient[2], region.wbGradient[3] = "VERTICAL", from, to
      Theme.Paint(region, color, alpha, region.wbCorner and "gradientTexture" or "gradient")
    end
    local function Refresh()
      local height = math.max(radius * 2, parent:GetHeight())
      Shade(fill, radius / height, 1 - radius / height)
      for i, part in ipairs(fill.parts) do
        if radius == 5 and Core.CONTROL_CORNERS then
          local top = i == 1 or i == 3 or i == 4
          Shade(part, top and 1 - radius / height or 0, top and 1 or radius / height)
        else
          local y = math.floor((i - 1) / 2)
          if i % 2 == 1 then Shade(part, 1 - (y + 1) / height, 1 - y / height)
          else Shade(part, y / height, (y + 1) / height) end
        end
      end
    end
    parent:HookScript("OnSizeChanged", Refresh)
    Refresh()
  end
  return fill
end

function Kit.RoundedOutline(parent, color)
  local line = Theme.Size("line")
  local radius = math.max(0, parent.cornerRadius - line)
  local layer = Kit.BorderLayer(parent, line)
  local edges = Kit.Outline(layer, color)
  for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    edges[i]:ClearAllPoints()
    if i <= 2 then
      edges[i]:SetPoint(side .. "LEFT", radius, 0); edges[i]:SetPoint(side .. "RIGHT", -radius, 0)
    else
      edges[i]:SetPoint("TOP" .. side, 0, -radius); edges[i]:SetPoint("BOTTOM" .. side, 0, radius)
    end
  end
  if radius == 4 and line == 1 and Core.CONTROL_CORNERS then
    for _, corner in ipairs(CORNERS) do
      edges[#edges + 1] = Corner(layer, "OVERLAY", color, nil, corner, 8, radius)
    end
  else for y = 0, radius - 1 do
    local outer = CurveInset(radius, y + 0.5)
    local inner = y + 0.5 < line and radius or line + CurveInset(radius - line, y + 0.5 - line)
    for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
      local part = Theme.Fill(layer, "OVERLAY", color)
      local left, top = corner:find("LEFT"), corner:find("TOP")
      part:SetPoint(corner, left and outer or -outer, top and -y or y)
      part:SetSize(math.max(0.01, inner - outer), 1)
      edges[#edges + 1] = part
    end
  end end
  return edges
end

-- Join the four straight glow strips around each rounded corner. Each
-- band fades outward from the curved boundary without spilling over text.
local function GlowCorners(frame, radius, spread)
  if radius <= 0 then return end
  if radius == 5 and spread == 4 and Core.CONTROL_CORNERS then
    for _, corner in ipairs(CORNERS) do
      frame.parts[#frame.parts + 1] = Corner(frame, "BACKGROUND", frame.color, frame.alphaToken,
        corner, 16, radius + spread, spread)
    end
    return
  end
  local outerRadius = radius + spread
  local rows = math.ceil(outerRadius)
  local height = outerRadius / rows
  for row = 0, rows - 1 do
    local y = row * height
    local distance = outerRadius - y - height / 2
    local outer = math.sqrt(math.max(0, outerRadius ^ 2 - distance ^ 2))
    local inner = math.sqrt(math.max(0, radius ^ 2 - distance ^ 2))
    local strength = math.min(1, (outerRadius - distance) / spread)
    for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
      local left, top = corner:find("LEFT"), corner:find("TOP")
      local part = Theme.Gradient(frame, "BACKGROUND", frame.color, frame.alphaToken,
        "HORIZONTAL", left and 0 or strength, left and strength or 0)
      local x = radius - outer
      part:SetPoint(corner, left and x or -x, top and spread - y or y - spread)
      part:SetSize(outer - inner, height)
      frame.parts[#frame.parts + 1] = part
    end
  end
end

-- Light falls outside a solid reading surface. No effect owns input, moves
-- a hit area or touches a protected attribute. Corner masks are shared.
function Kit.Glow(parent, color, spread, alpha)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  f:EnableMouse(false)
  f.parts, f.color, f.alphaToken = {}, color or "accent", alpha or "glow"
  spread = spread or 6
  local radius = parent.cornerRadius or 0
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local vertical = side == "TOP" or side == "BOTTOM"
    local reverse = side == "TOP" or side == "RIGHT"
    local t = Theme.Gradient(f, "BACKGROUND", f.color, f.alphaToken,
      vertical and "VERTICAL" or "HORIZONTAL", reverse and 1 or 0, reverse and 0 or 1)
    if side == "TOP" then
      t:SetPoint("BOTTOMLEFT", f, "TOPLEFT", radius, 0); t:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -radius, 0)
    elseif side == "BOTTOM" then
      t:SetPoint("TOPLEFT", f, "BOTTOMLEFT", radius, 0); t:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -radius, 0)
    elseif side == "LEFT" then
      t:SetPoint("TOPRIGHT", f, "TOPLEFT", 0, -radius); t:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 0, radius)
    else
      t:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, -radius); t:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", 0, radius)
    end
    if vertical then t:SetHeight(spread) else t:SetWidth(spread) end
    f.parts[#f.parts + 1] = t
  end
  GlowCorners(f, radius, spread)
  function f:SetColor(token)
    if token == self.color then return end
    self.color = token
    for _, t in ipairs(self.parts) do Theme.Paint(t, token, self.alphaToken, t.wbMode) end
  end
  function f:RefreshPulse()
    if self.pulsing and self.active and self:IsVisible() and Theme.Alpha(self.alphaToken) > 0 then
      if not self.pulse then self.pulse = Core.Bounce(self, 0.55, 1, Theme.Motion("pulse")) end
      if not self.pulse:IsPlaying() then self.pulse:Play() end
    else
      if self.pulse then self.pulse:Stop() end
    end
  end
  function f:SetActive(on, pulsing, immediate)
    on, pulsing = not not on, on and not not pulsing or false
    if self.active == on and self.pulsing == pulsing and not immediate then return end
    self.active, self.pulsing = on, pulsing
    if self.pulse then self.pulse:Stop() end
    Motion.Show(self, on, immediate and 0 or "hover")
    if pulsing then Motion.Stop(self, 1) end
    self:RefreshPulse()
  end
  f:Hide()
  f:HookScript("OnHide", function(self)
    Motion.Stop(self)
    if self.pulse then self.pulse:Stop() end
  end)
  f:HookScript("OnShow", function(self) self:RefreshPulse() end)
  parent:HookScript("OnHide", function()
    Motion.Stop(f, f.active and 1 or 0)
    if not f.active then f:Hide() end
    if f.pulse then f.pulse:Stop() end
  end)
  parent:HookScript("OnShow", function() f:RefreshPulse() end)
  Theme.OnChange(function() f:RefreshPulse() end)
  return f
end

-- A single travelling glint on the top edge. It runs only on an entrance,
-- a new selection or a new tactical signal, never on recurring refreshes.
function Kit.Sweep(parent, color)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  f:EnableMouse(false)
  f.light = Theme.Gradient(f, "OVERLAY", color or "metalHighlight", "edgeLight", "HORIZONTAL", 0, 1)
  f.light:SetSize(48, 2)
  local function draw(self, value)
    local inset = math.max(3, (parent.cornerRadius or 0) + 1)
    local width = math.max(0, parent:GetWidth() - inset * 2)
    local length = math.min(48, width)
    self.progress = value
    self.light:SetWidth(length)
    self.light:ClearAllPoints()
    self.light:SetPoint("TOPLEFT", inset + (width - length) * value, -1)
    self.light:SetAlpha(value >= 1 and 0 or math.sin(value * math.pi))
    -- Gradient repainting must never reveal a stopped glint. Its initial
    -- width may also predate the owner's first layout.
    self.light:SetShown(value > 0 and value < 1 and length > 0)
  end
  function f:Play()
    if Core.ReducedMotion() or not self:IsVisible() then self:Stop(); return end
    draw(self, 0)
    Motion.Value(self, 0, 1, "sweep", draw)
  end
  function f:Stop() Motion.Stop(self); draw(self, 1) end
  f:HookScript("OnHide", function(self) self:Stop() end)
  parent:HookScript("OnHide", function() f:Stop() end)
  parent:HookScript("OnSizeChanged", function() draw(f, f.progress or 1) end)
  f:Stop()
  return f
end

-- Every control gets relief; only primary and selected controls radiate.
-- Brightening the perimeter leaves the label's contrast unchanged.
function Kit.ButtonFinish(button)
  button.sheen = Kit.RoundedFill(button, "metalHighlight", "sheen", "BORDER", true)
  button.glow = Kit.Glow(button, "accent", 4)
  button.sweep = Kit.Sweep(button)
  function button:RefreshFinish(immediate)
    local primary = self.tone == "accent" or self.tone == "gold" or self.tone == "danger"
    local selected = self.tone == "selected"
    local enabled = not self.wbDisabled and self.enabled ~= false
    local token = primary and self.tone or selected and "accent" or "focus"
    self.glow:SetColor(token)
    self.glow:SetActive(enabled and (primary or selected or self.wbHovered), false, immediate)
    self.edge:SetColor(primary and self.tone or selected and "accent" or enabled and self.wbHovered and "focus" or "controlBorder")
    if selected and not self.wbWasSelected then self.sweep:Play() end
    self.wbWasSelected = selected
    if not enabled or immediate then self.sweep:Stop() end
  end
  button:HookScript("OnEnter", function(self) if not self.wbDisabled then self.sweep:Play() end end)
  button:HookScript("OnShow", function(self) self:RefreshFinish(true) end)
  button:RefreshFinish(true)
end

-- Framed cards have a clear surface and edge. Featured cards add a halo,
-- a highlighted rim and an entrance glint without enlarging the layout.
function Kit.CardFinish(card, featured)
  card.edge = Kit.Outline(card, featured and "borderAccent" or "border")
  card.bevel = Kit.Bevel(card)
  card.sheen = Theme.Gradient(card, "BORDER", "metalHighlight", "sheen")
  card.sheen:SetPoint("TOPLEFT", 1, -1); card.sheen:SetPoint("TOPRIGHT", -1, -1)
  card.sheen:SetHeight(24)
  if featured then
    card.glow = Kit.Glow(card, "accent", 8)
    card.glow:SetActive(true, true, true)
    card.sweep = Kit.Sweep(card)
    card:HookScript("OnShow", function() card.sweep:Play() end)
  end
end
