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
Core.THEME = ns.UIConfig
Core.ACCENT, Core.INK, Core.MUTED = Core.THEME.colors.accent, Core.THEME.colors.panel, Core.THEME.colors.muted

-- Readable status chips; highest priority wins.
Core.PIP = {
  immune = { "IMMUNE", 1, 0.4, 0.35 },
  def = { "DEF", 1, 0.78, 0.3 },
  cc = { "CC", 0.45, 0.72, 1 },
  control = { "CC", 0.45, 0.72, 1 },
  stun = { "STUN/SIL", 1, 0.64, 0.25 }, -- Cata's combined stun/silence observation
  notrinket = { "NO TRNK", 0.25, 0.85, 0.8 },
  carrier = { "FLAG", 0.78, 0.56, 1 },
  spent = { "SPENT", 0.4, 0.9, 0.6 },
  burst = { "BURST", 1, 0.32, 0.35 },
}

Core.ROW_H, Core.GAP, Core.PAD, Core.WIDTH = Core.THEME.main.row, Core.THEME.main.gap, Core.THEME.main.padding, Core.THEME.main.width
Core.HEAD_H, Core.HERO_H = Core.THEME.main.header, Core.THEME.main.hero
Core.LIST_TOP = Core.HEAD_H + Core.HERO_H + Core.PAD + Core.THEME.main.section
Core.TILE_W = Core.THEME.main.rankWidth
Core.METER_SEGS = 6

-- Bundled fonts are new files: the client only sees them after a full
-- restart (not /reload). Until then SetFont fails -> Arial Narrow.
function Core.Text(parent, face, size, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  local okCall, ok = pcall(fs.SetFont, fs, FONTS[face] or FONT_FALLBACK, size, flags or "")
  if not (okCall and ok) then
    fs:SetFont(FONT_FALLBACK, size, flags or "")
  end
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
