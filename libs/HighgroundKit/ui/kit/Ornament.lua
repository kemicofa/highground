local _, ns = ...
local Core, Kit, Theme = ns.Core, ns.Kit, ns.Theme

-- Cut-metal corners, a double rim and light spilling beyond the silhouette.
-- Full windows get long brackets; combat windows keep a tighter profile.
-- Decorations never own input or change protected geometry during repaint.
function Kit.Inlay(parent, compact)
  local f = CreateFrame("Frame", nil, parent)
  f:SetAllPoints()
  f:EnableMouse(false)
  f.edges = {}
  local function stroke(anchor, x, y, width, height, token, angle)
    local t = Theme.Fill(f, "OVERLAY", token)
    t:SetSize(width, height)
    t:SetPoint(anchor, f, anchor, x, y)
    if angle then t:SetRotation(angle) end
    f.edges[#f.edges + 1] = t
    return t
  end
  f.shadow = Kit.Glow(parent, "black", compact and 7 or 18, "elevation")
  f.shadow:SetActive(true, false, true)
  f.glow = Kit.Glow(f, "accent", compact and 3 or 8)
  f.glow:SetActive(true, false, true)
  local reach = compact and 10 or 26
  for _, corner in ipairs({ { "TOPLEFT", 1, -1 }, { "TOPRIGHT", -1, -1 },
    { "BOTTOMLEFT", 1, 1 }, { "BOTTOMRIGHT", -1, 1 } }) do
    local anchor, x, y = corner[1], corner[2], corner[3]
    stroke(anchor, x * 2, y * 2, reach, 2, "metalHighlight")
    stroke(anchor, x * 2, y * 2, 2, reach, "metalEdge")
    if not compact then
      stroke(anchor, x * 6, y * 6, reach - 12, 1, "metalEdge")
      stroke(anchor, x * 6, y * 6, 1, reach - 12, "metalShadow")
      local facet = stroke(anchor, x * 3, y * 3, 7, 7, "metalEdge", math.pi / 4)
      facet:SetAlpha(0.65)
    end
  end
  if not compact then
    f.rim = Kit.Outline(f, "metalEdge", 2)
    for _, edge in ipairs(f.rim) do edge:SetAlpha(0.35) end
    local peak = stroke("TOP", 0, -1, 6, 6, "metalHighlight", math.pi / 4)
    peak:SetAlpha(0.8)
    for _, x in ipairs({ -13, 13 }) do
      stroke("TOP", x, -1, 3, 3, "metalEdge", math.pi / 4)
    end
    stroke("BOTTOM", 0, 2, 3, 3, "metalEdge", math.pi / 4)
  end
  function f:Refresh()
    local opts = parent.wbBackdrop or {}
    local frameless = opts.frameless ~= false and Core.Frameless and Core.Frameless()
    local hidden = frameless or (Core.BorderSize and Core.BorderSize() == 0)
    local opacity = compact and Core.PanelBgAlpha and Core.PanelBgAlpha(parent) or 1
    self:SetAlpha(hidden and 0 or Theme.Alpha("ornament") * opacity)
    self.shadow:SetAlpha(hidden and 0 or opacity)
  end
  parent.wbInlay = f
  f:Refresh()
  return f
end

-- The supplied crest is reserved for spacious branded surfaces. Other
-- palettes use a simple summit in the same space, keeping layout stable.
function Kit.Crest(parent, size)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(size, size)
  f:EnableMouse(false)
  f.image = f:CreateTexture(nil, "ARTWORK")
  f.image:SetAllPoints()
  f.image:SetTexture(Core.CREST)
  f.summit = CreateFrame("Frame", nil, f)
  f.summit:SetAllPoints()
  f.summit:EnableMouse(false)
  for _, side in ipairs({ -1, 1 }) do
    local line = Theme.Fill(f.summit, "ARTWORK", "accent")
    line:SetSize(size * 0.38, 2)
    line:SetPoint("CENTER", side * size * 0.13, 0)
    line:SetRotation(-side * math.pi / 4)
  end
  local diamond = Theme.Fill(f.summit, "ARTWORK", "titleText")
  diamond:SetSize(size * 0.12, size * 0.12)
  diamond:SetPoint("CENTER", 0, size * 0.2)
  diamond:SetRotation(math.pi / 4)
  local function refresh()
    f.image:SetAlpha(Theme.Alpha("crest"))
    f.summit:SetAlpha(1 - Theme.Alpha("crest"))
  end
  Theme.OnChange(refresh)
  refresh()
  return f
end
