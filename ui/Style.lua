local _, ns = ...
local Core = ns.Core

-- Tactical HUD: a clear target card, two-line enemy rows and shared panel
-- styling. Keep secure click targets stable while their visuals update.
---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\Warboard\\media\\"
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"
local FONTS = {
  bold = MEDIA .. "BarlowCondensed-Bold.ttf",
  semi = MEDIA .. "BarlowCondensed-SemiBold.ttf",
  medium = MEDIA .. "BarlowCondensed-Medium.ttf",
  mono = MEDIA .. "JetBrainsMono-Bold.ttf",
}
Core.WHITE = "Interface\\Buttons\\WHITE8x8"
Core.CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
Core.ICON_LOCK = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"
Core.TRINKET_ICON = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01"
Core.THEME = ns.UIConfig
Core.ACCENT, Core.INK, Core.MUTED = Core.THEME.colors.accent, Core.THEME.colors.panel, Core.THEME.colors.muted

-- Readable status chips; highest priority wins.
Core.PIP = {
  immune = { "IMMUNE", 1, 0.4, 0.35 },
  def = { "DEF", 1, 0.78, 0.3 },
  cc = { "CC", 0.45, 0.72, 1 },
  control = { "CC", 0.45, 0.72, 1 },
  stun = { "STUN/SIL", 1, 0.64, 0.25 }, -- Cata's combined stun/silence observation
  carrier = { "FLAG", 0.78, 0.56, 1 },
  spent = { "SPENT", 0.4, 0.9, 0.6 },
  burst = { "BURST", 1, 0.32, 0.35 },
}

Core.ROW_H, Core.GAP, Core.PAD, Core.WIDTH = Core.THEME.main.row, Core.THEME.main.gap, Core.THEME.main.padding, Core.THEME.main.width
Core.HEAD_H, Core.HERO_H, Core.FOOT_H = Core.THEME.main.header, Core.THEME.main.hero, Core.THEME.main.footer
Core.LIST_TOP = Core.HEAD_H + Core.HERO_H + Core.PAD + Core.THEME.main.section
Core.TILE_W = Core.THEME.main.rankWidth
Core.METER_SEGS = 6

-- Bundled fonts are new files: the client only sees them after a full
-- restart (not /reload). Until then SetFont fails -> Arial Narrow.
-- Every face set here is remembered, so the Font and Text size settings
-- (ui/Appearance.lua) can restyle all text at once.
Core.fonts = setmetatable({}, { __mode = "k" })
function Core.SetFace(fs, face, size, flags)
  fs.wbFace, fs.wbSize, fs.wbFlags = face, size, flags
  Core.fonts[fs] = true
  local choice = Core.StyleChoice and Core.StyleChoice("font")
  local file = choice and choice.file or FONTS[face] or FONT_FALLBACK
  size = size * (Core.FontScale and Core.FontScale() or 1)
  local okCall, ok = pcall(fs.SetFont, fs, file, size, flags or "")
  if not (okCall and ok) then
    fs:SetFont(FONT_FALLBACK, size, flags or "")
  end
end

-- Status bars drawn with the Bar texture setting.
Core.bars = {}
function Core.BarFile()
  return Core.StyleChoice and Core.StyleChoice("bar").file or Core.WHITE
end
function Core.StatusBar(bar)
  Core.bars[#Core.bars + 1] = bar
  bar:SetStatusBarTexture(Core.BarFile())
  return bar
end

function Core.Text(parent, face, size, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  Core.SetFace(fs, face, size, flags)
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.85)
  fs:SetWordWrap(false)
  return fs
end

function Core.Border(parent, r, g, b, a, size)
  size = size or 1
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetPoint("TOPLEFT", -size, size)
  f:SetPoint("BOTTOMRIGHT", size, -size)
  f:SetBackdrop({ edgeFile = Core.WHITE, edgeSize = size })
  f:SetBackdropBorderColor(r, g, b, a or 1)
  return f
end

function Core.Fill(parent, layer, r, g, b, a, sub)
  local t = parent:CreateTexture(nil, layer, nil, sub)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

-- Panel backgrounds follow the Background opacity setting (ui/Compact.lua):
-- registered surfaces take its alpha, backdrops its fill alpha.
Core.surfaces, Core.backdrops = {}, {}
function Core.Surface(parent, layer)
  local t = Core.Fill(parent, layer, unpack(Core.THEME.colors.surface))
  t.wbSurface = true
  Core.surfaces[#Core.surfaces + 1] = t
  t:SetAlpha(Core.BgAlpha and Core.BgAlpha() or 1)
  return t
end

-- Panel fill and border, following Background opacity, Border and the
-- Frameless setting (no fill, border or header: just the rows).
function Core.PaintBackdrop(f)
  local a = Core.BgAlpha and Core.BgAlpha() or 0.9
  local edge = Core.BorderSize and Core.BorderSize() or 1
  if Core.Frameless and Core.Frameless() then
    f:SetBackdrop(nil)
    return
  end
  f:SetBackdrop({ bgFile = Core.WHITE, edgeFile = edge > 0 and Core.WHITE or nil, edgeSize = edge })
  f:SetBackdropColor(Core.INK[1], Core.INK[2], Core.INK[3], a)
  if edge > 0 then
    if Core.BorderColor then
      f:SetBackdropBorderColor(Core.BorderColor(a))
    else
      local b = Core.THEME.colors.border
      f:SetBackdropBorderColor(b[1], b[2], b[3], math.min(1, a + 0.25))
    end
  end
end

function Core.Backdrop(f)
  Core.backdrops[#Core.backdrops + 1] = f
  Core.PaintBackdrop(f)
end

-- Header pieces hidden by the Frameless setting.
Core.chrome = {}
function Core.Chrome(...)
  for i = 1, select("#", ...) do
    local region = select(i, ...)
    Core.chrome[#Core.chrome + 1] = region
    if Core.Frameless and Core.Frameless() then region:SetAlpha(0) end
  end
end

function Core.Bounce(target, from, to, dur)
  local g = target:CreateAnimationGroup()
  g:SetLooping("BOUNCE")
  local a = g:CreateAnimation("Alpha")
  a:SetFromAlpha(from)
  a:SetToAlpha(to)
  a:SetDuration(dur)
  a:SetSmoothing("IN_OUT")
  return g
end
