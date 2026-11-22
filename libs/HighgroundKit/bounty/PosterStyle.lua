local addon, ns = ...
local B, Core, T, Kit = ns.Bounty, ns.Core, ns.Theme, ns.Kit
local Style = {}
B.PosterStyle = Style
local MEDIA = "Interface\\AddOns\\" .. addon .. "\\libs\\bounty\\media\\"
Core.FACES.wantedDisplay, Core.FACES.wantedName, Core.FACES.wantedCaption =
  MEDIA .. "WantedDisplay.ttf", MEDIA .. "WantedName.ttf", MEDIA .. "WantedCaption.ttf"

-- Separate from the interface palette: paper and ink travel together.
-- Numeric choice IDs also round-trip through the existing tuning profiles.
function Style.Current() return Core.O("bountyPosterTheme") == 2 and 2 or 1 end
local C = ns.ThemeColor
local PAPER = {
  posterPaper = C("dbd0b1"), posterInset = C("cbbc98"), posterInk = C("352a22"),
  posterMuted = C("574632"), posterEdge = C("79694d"), posterStamp = C("352a22"), posterWell = C("494436"),
  portraitTint = C("e4c996"),
}
function Style.Color(token) return Style.Current() == 1 and PAPER[token] or T.Rgb(token) end
local INK = { title = "posterInk", name = "posterInk", reward = "posterStamp", status = "posterStamp",
  trackingLabel = "posterInk", class = "posterMuted", rewardLabel = "posterMuted", killProgress = "posterStamp",
  note = "posterInk", owner = "posterMuted", location = "posterMuted", detail = "posterMuted", likeness = "posterMuted",
  captureStatus = "posterMuted", rule = "posterEdge", strip = "posterEdge", progress = "posterStamp" }

local function Decorations(w)
  local paper = { w:CreateTexture(nil, "BACKGROUND", nil, 1) }
  paper[1]:SetTexture(MEDIA .. "WantedPaper.tga"); paper[1]:SetAllPoints()
  w.scrolls = {}
  for i = 1, 2 do
    local scroll = w:CreateTexture(nil, "ARTWORK")
    scroll:SetTexture(MEDIA .. "WantedScroll.tga")
    scroll:SetTexCoord(i == 1 and 0 or 1, i == 1 and 1 or 0, 0, 1)
    T.Tint(scroll, PAPER.posterInk)
    paper[#paper + 1], w.scrolls[i] = scroll, scroll
  end
  function paper:SetShown(on) for _, region in ipairs(self) do region:SetShown(on) end end
  w.paperWear = paper
  w.verdict = B.Wanted.Text(w, "heading")
  w.imprint = B.Wanted.Text(w, "heading"); w.imprint:SetText("HIGHGROUND")
end

-- Wide paper portraits crop square headshots instead of stretching faces.
-- Race atlases and class icons retain their native proportions in the well.
function Style.Portrait(w)
  local width, height = w.portraitWell:GetWidth(), w.portraitWell:GetHeight()
  if width <= 0 or height <= 0 then return end
  local sepia = Style.Current() == 1
  if w.portrait.wantedSepia ~= sepia then
    w.portrait:SetDesaturated(sepia); w.portrait.wantedSepia = sepia
  end
  T.Tint(w.portrait, sepia and PAPER.portraitTint or "white")
  w.portrait:ClearAllPoints()
  if Style.Current() == 1 and w.portraitKind == "race" then
    w.portrait:SetPoint("CENTER", w.portraitWell, "CENTER")
    w.portrait:SetSize(math.min(width, height), math.min(width, height))
  else
    w.portrait:SetAllPoints(w.portraitWell)
    if w.portraitKind == "native" or w.portraitKind == "model" then
      local crop = math.max(0, (1 - height / width) / 2)
      w.portrait:SetTexCoord(0, 1, crop, 1 - crop)
    end
  end
  w.fallback:ClearAllPoints(); w.fallback:SetPoint("CENTER", w.portraitWell, "CENTER")
  local size = math.max(1, math.min(width, height) - 28)
  w.fallback:SetSize(size, size)
end

-- Dedicated print faces survive a global UI-font selection. Fit with native
-- measurements, including long realm names, instead of guessing glyph widths.
local function Print(fs, face, size, width)
  fs.wbFixedFace = true
  fs:SetWordWrap(false); fs:SetWidth(0)
  Core.SetFace(fs, face, size / Core.FontScale())
  local measured = fs:GetStringWidth()
  if measured > width then Core.SetFace(fs, face, size * width / measured / Core.FontScale()) end
end

function Style.Type(w, width, tight)
  local inner = width - (w.fullPoster and not w.contribution and 48 or 36)
  local art = math.min(inner, 360 * math.max(1, Core.FontScale()))
  Print(w.title, "wantedDisplay", art * (tight and 0.17 or 0.24), inner)
  Print(w.name, "wantedName", art * (tight and 0.11 or 0.16), inner - 16)
  Print(w.verdict, "wantedCaption", art * 0.073, inner - 12)
  Print(w.reward, "wantedCaption", art * 0.065, inner - 20)
  Print(w.imprint, "wantedName", art * 0.075, inner * 0.34)
end

function Style.Apply(w, width)
  local onePiece = Style.Current() == 1
  w.posterTheme = onePiece and 1 or 2
  if not w.paperWear then Decorations(w) end
  local function Color(token) return onePiece and PAPER[token] or token end
  T.Paint(w.paper, Color("posterPaper")); T.Paint(w.portraitPaper, Color("posterWell"))
  w.paperEdge:SetColor(Color("posterEdge")); w.portraitEdge:SetColor(Color(onePiece and "posterInk" or "posterEdge"))
  w.paperEdge:SetShown(not onePiece)
  w.paperInset:SetShown(not onePiece)
  for _, pin in ipairs(w.paperPins) do pin:SetShown(not onePiece) end
  w.paperWear:SetShown(onePiece)
  if w.contribution then for _, scroll in ipairs(w.scrolls) do scroll:Hide() end end
  if w.strip then w.strip:SetShown(not onePiece) end
  for key, token in pairs(INK) do if w[key] then T.Paint(w[key], Color(token)) end end
  w.verdict:SetText(onePiece and w.title:GetText() == "WANTED" and "DEAD OR ALIVE" or "")
  w.verdict:Hide(); w.imprint:Hide()
  T.Paint(w.verdict, Color("posterInk")); T.Paint(w.imprint, Color("posterInk"))
  for _, key in ipairs({ "details", "secondaryAction", "retry", "addGold", "primary", "close" }) do
    local button = w[key]
    if button and button.RefreshFinish then
      if not button.posterFinish then
        button.posterFinish = { fill = button.tone or button.bg.wbToken or "surface", ink = button.label.wbToken }
        local finish = button.RefreshFinish
        function button:RefreshFinish(immediate)
          finish(self, immediate)
          if Style.Current() == 1 then self.edge:SetColor(PAPER.posterEdge); self.glow:SetColor(PAPER.posterEdge) end
        end
      end
      if onePiece then Kit.Paint(button, PAPER.posterInk, PAPER.posterPaper)
      else Kit.Paint(button, button.posterFinish.fill, button.posterFinish.ink) end
    elseif button and button.label then
      T.Paint(button.label, Color("posterInk"))
      if button.bg then T.Paint(button.bg, Color("posterInset")) end
      if button.edge then button.edge:SetColor(Color("posterMuted")) end
    end
  end
  if not onePiece then
    if w.close then w.close:ClearAllPoints(); w.close:SetPoint("TOPRIGHT", -8, -8); w.close:SetSize(24, 24) end
    for _, fs in ipairs({ w.title, w.name, w.reward, w.verdict, w.imprint }) do fs.wbFixedFace = nil; fs:SetWordWrap(true) end
    T.SetRole(w.title, w.thumbnail and "title" or w.fullPoster and "display" or "posterTitle")
    T.SetRole(w.name, w.thumbnail and "cardTitle" or "posterName")
    T.SetRole(w.reward, w.thumbnail and "displayLarge" or "posterReward")
    return false
  end
  if w.contribution then Style.Type(w, width or w:GetWidth()) end
  return true
end

-- One printed composition for board cards, full details and gameplay popups.
-- Popup compression preserves actions on short screens and at large text sizes.
function Style.Layout(w, width, slots)
  local scale = math.max(1, Core.FontScale())
  local full = w.fullPoster and not w.contribution
  local pad = full and 24 or 18
  local inner = width - pad * 2
  local art = math.min(inner, (full and 360 or 280) * scale)
  w:SetWidth(width)
  local function Arrange(tight, withoutPortrait)
    Style.Type(w, width, tight)
    local y, measured = 8, {}
    local function Place(key, gap, align, inset, span)
      local fs = w[key]
      fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", pad + (inset or 0), -y); fs:SetWidth(span or inner - (inset or 0) * 2)
      fs:SetJustifyH(align or "CENTER"); fs:SetHeight(0)
      local height = fs:GetText() ~= "" and math.ceil(fs:GetStringHeight()) + 2 or 0
      measured[key] = height; fs:SetHeight(math.max(1, height)); fs:SetShown(height > 0)
      local slot = slots and slots[key] or height
      if slot > 0 then y = y + slot + (tight and 2 or gap or 2) end
    end
    for _, key in ipairs({ "class", "likeness", "note", "owner", "detail", "killProgress", "trackingLabel", "rule", "imprint" }) do w[key]:Hide() end
    Place("title", 2)
    w.portraitWell:ClearAllPoints(); w.portraitWell:SetShown(not withoutPortrait)
    if not withoutPortrait then
      local portrait = tight and math.min(art, 100) or art
      w.portraitWell:SetPoint("TOPLEFT", (width - portrait) / 2, -y)
      w.portraitWell:SetSize(portrait, portrait * 0.72)
      y = y + w.portraitWell:GetHeight() + 4
    end
    local scrollTop = y
    Place("verdict", 0); Place("name", 0, nil, 8); Place("reward", 4)
    local label = w.rewardLabel:GetText()
    if label == "REWARD" or label == "WANTED PLAYER" then w.rewardLabel:Hide()
    else Place("rewardLabel", 2) end
    for i, scroll in ipairs(w.scrolls) do
      scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", i == 1 and 6 or width - 18, -scrollTop)
      scroll:SetSize(12, math.max(36, y - scrollTop)); scroll:SetShown(not tight)
    end
    local footerTop, footerWidth = y, inner * 0.64
    Place("status", 0, "LEFT", 0, footerWidth)
    if not tight or full then Place("trackingLabel", 0, "LEFT", 0, footerWidth) end
    Place("location", 0, "LEFT", 0, footerWidth)
    local footerEnd = y
    y = footerTop
    Place("imprint", 0, "RIGHT", inner * 0.66, inner * 0.34)
    y = math.max(y, footerEnd) + 6
    if full then
      Place("class", 8)
      w.rule:ClearAllPoints(); w.rule:SetPoint("TOPLEFT", pad, -y); w.rule:SetWidth(inner); w.rule:Show()
      y = y + 14
      for _, key in ipairs({ "killProgress", "note", "owner", "detail" }) do Place(key, 8, "LEFT") end
    end
    if w.captureStatus then
      Place("captureStatus", 6, nil, 20)
      w.check:ClearAllPoints(); w.check:SetPoint("RIGHT", w.captureStatus, "LEFT", -4, 0)
    end
    if w.thumbnail then
      local actionHeight = math.max(32 * scale, w.details.label:GetStringHeight() + 12)
      measured.action = w.primary:IsShown() and math.max(28 * scale, w.primary.label:GetStringHeight() + 10) + 8 or 0
      local action = slots and slots.action or measured.action
      Kit.Place(w.details, "BOTTOMLEFT", w, "BOTTOMLEFT", pad, 18, inner, actionHeight)
      Kit.Place(w.primary, "BOTTOMLEFT", w, "BOTTOMLEFT", pad, 18 + actionHeight + 8, inner, math.max(28 * scale, measured.action - 8))
      w.slots = measured
      return y + action + actionHeight + 24
    end
    for _, key in ipairs({ "details", "addGold", "secondaryAction", "retry" }) do
      local button = w[key]
      if button and button:IsShown() then
        local height = math.max(28 * scale, button.label and button.label:GetStringHeight() + 10 or 0)
        local span = inner
        if key == "details" and w.close then
          span = inner - height - 6
          Kit.Place(w.close, "TOPLEFT", w, "TOPLEFT", pad + span + 6, -y, height, height)
        end
        Kit.Place(button, "TOPLEFT", w, "TOPLEFT", pad, -y, span, height)
        y = y + height + (tight and 3 or 6)
      end
    end
    return y + 14
  end
  local height = Arrange(false)
  if w.popup and height > UIParent:GetHeight() - 48 then height = Arrange(true) end
  if w.popup and height > UIParent:GetHeight() - 48 then height = Arrange(true, true) end
  w:SetHeight(math.max(height, w.minPosterHeight or 0))
  Style.Portrait(w)
end
