local _, ns = ...
local B, Core, Kit, T, U = ns.Bounty, ns.Core, ns.Kit, ns.Theme, ns.Util
local Wanted, views = {}, setmetatable({}, { __mode = "k" })
B.Wanted = Wanted
local R = B.Portraits
Wanted.Matches = R.Matches
local function Likeness(w)
  return w.portraitLabel or (w.portraitKind == "native" and "LAST SEEN"
    or w.portraitKind == "race" and "RACE PORTRAIT" or "MODEL LIKENESS")
end

function Wanted.Portrait(w, unit)
  local b = w.posterBounty
  if not b then return end
  local kind = R.Apply(w, b.name, unit, w.posterPreview)
  if not kind then return end
  w.hasPortrait, w.portraitUnit, w.portraitKind = true, unit, kind
  w.portrait:SetShown(kind ~= "modelFrame"); w.fallback:Hide()
  if w.portraitModel then w.portraitModel:SetShown(kind == "modelFrame") end
  w.likeness:SetText(Likeness(w))
end

function Wanted.ClearPortrait(w)
  R.Release(w)
  w.hasPortrait, w.portraitUnit, w.posterClass, w.portraitKind = nil, nil, nil, nil
  w.modelDisplayID = nil
  w.portrait:Hide(); w.portrait:SetTexture(nil)
end

function Wanted.Observe(b, unit)
  for w in pairs(views) do
    if w:IsVisible() and w.posterBounty and B.Key(w.posterBounty.name) == B.Key(b.name) then
      if b.class then
        w.posterClass = b.class
        w.class:SetText(U.ClassName(b.class))
        if not w.hasPortrait then Kit.ClassIcon(w.fallback, b.class) end
      end
      if w.portraitKind ~= "native" then Wanted.Portrait(w, unit) end
    end
  end
end

local function Text(w, role, color)
  local fs = Kit.Paragraph(w, role, color or "posterInk")
  fs:SetJustifyH("CENTER"); fs:SetShadowOffset(0, 0)
  return fs
end
Wanted.Text = Text

function Wanted.PopupWidth()
  return math.min(360 + math.max(0, Core.FontScale() - 1) * 120, UIParent:GetWidth() - 48)
end

-- The same paper, typography and portrait treatment in alerts and details.
-- This frame has no expiry, click handler or publishing action of its own.
function Wanted.Build(parent, name)
  local w = CreateFrame("Frame", name, parent)
  views[w] = true
  w:EnableMouse(false)
  T.Fill(w, "BACKGROUND", "posterPaper"):SetAllPoints()
  Kit.Outline(w, "posterEdge", 2)
  local inset = CreateFrame("Frame", nil, w)
  inset:SetPoint("TOPLEFT", 7, -7); inset:SetPoint("BOTTOMRIGHT", -7, 7)
  inset:EnableMouse(false); Kit.Outline(inset, "posterEdge")
  for _, anchor in ipairs({ "TOP", "BOTTOM" }) do
    local pin = T.Fill(w, "ARTWORK", "posterEdge")
    pin:SetSize(5, 5); pin:SetPoint(anchor, 0, anchor == "TOP" and -5 or 5); pin:SetRotation(math.pi / 4)
  end
  local body = w
  if parent == UIParent then
    w.viewport = CreateFrame("ScrollFrame", nil, w); w.viewport:SetAllPoints()
    w.content = CreateFrame("Frame", nil, w.viewport); w.content:SetSize(1, 1)
    w.viewport:SetScrollChild(w.content); w.viewport:EnableMouseWheel(true)
    w.viewport:SetScript("OnMouseWheel", function(self, delta)
      self:SetVerticalScroll(math.max(0, math.min(w.content:GetHeight() - self:GetHeight(), self:GetVerticalScroll() - delta * 48)))
    end)
    w.footer = CreateFrame("Frame", nil, w)
    w.footer:SetFrameLevel(w.viewport:GetFrameLevel() + 2)
    local rule = T.Fill(w.footer, "ARTWORK", "posterEdge")
    rule:SetPoint("TOPLEFT", 24, 0); rule:SetPoint("TOPRIGHT", -24, 0); rule:SetHeight(1)
    w.scrollHint = Text(w, "caption", "posterMuted"); w.scrollHint:SetPoint("BOTTOM", 0, 8)
    w.scrollHint:SetText("Scroll for more"); w.scrollHint:Hide()
    body = w.content
  end
  w.status = Text(body, "caption", "posterStamp")
  w.trackingLabel = Text(body, "heading", "posterInk")
  w.title = Text(body, "posterTitle"); w.title:SetText("WANTED")
  w.portraitWell = CreateFrame("Frame", nil, body)
  T.Fill(w.portraitWell, "BACKGROUND", "posterWell"):SetAllPoints()
  Kit.Outline(w.portraitWell, "posterEdge", 2)
  w.portrait = w.portraitWell:CreateTexture(nil, "ARTWORK"); w.portrait:SetAllPoints()
  w.fallback = w.portraitWell:CreateTexture(nil, "ARTWORK")
  w.fallback:SetPoint("TOPLEFT", 14, -14); w.fallback:SetPoint("BOTTOMRIGHT", -14, 14)
  w.likeness = Text(body, "caption", "posterMuted")
  w.name, w.class = Text(body, "posterName"), Text(body, "body", "posterMuted")
  w.rule = T.Fill(body, "ARTWORK", "posterEdge"); w.rule:SetHeight(1)
  w.rewardLabel, w.reward = Text(body, "caption", "posterMuted"), Text(body, "posterReward", "posterStamp")
  w.killProgress = Text(body, "bodySmall", "posterStamp")
  w.note, w.owner = Text(body, "body"), Text(body, "body", "posterMuted")
  w.location, w.detail = Text(body, "body", "posterMuted"), Text(body, "body", "posterMuted")
  w:Hide()
  return w
end

function Wanted.Layout(w, width)
  if w.thumbnail then return B.BoardRow.Layout(w, width) end
  local scale = Core.FontScale()
  local y = 18
  width = width or Wanted.PopupWidth()
  w:SetWidth(width)
  if w.content then
    w.content:SetWidth(width)
    if w.close then w.close:SetFrameLevel(w.content:GetFrameLevel() + 5) end
  end
  local function Place(fs, gap, x, span, align)
    if fs:GetText() == "" then fs:Hide(); return end
    fs:Show(); fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", x or 24, -y); fs:SetWidth(span or width - 48)
    fs:SetJustifyH(align or "CENTER")
    fs:SetHeight(0)
    local height = math.ceil(fs:GetStringHeight()) + 2
    fs:SetHeight(height); y = y + height + gap
  end
  Place(w.status, 5); Place(w.trackingLabel, 8); Place(w.title, 14)
  local portraitSize = math.min(160 + math.max(0, scale - 1) * 32, math.max(112, width * 0.24))
  w.portraitWell:ClearAllPoints(); w.portraitWell:SetPoint("TOPLEFT", (width - portraitSize) / 2, -y)
  w.portraitWell:SetSize(portraitSize, portraitSize)
  y = y + portraitSize + 6
  Place(w.likeness, 12)
  Place(w.name, 5); Place(w.class, 12)
  Place(w.rewardLabel, 3); Place(w.reward, 14)
  w.rule:ClearAllPoints(); w.rule:SetPoint("TOPLEFT", 24, -y); w.rule:SetWidth(width - 48)
  y = y + 12
  Place(w.killProgress, 10); Place(w.note, 14)
  if width >= 580 * math.max(1, scale) and w.owner:GetText() ~= "" and w.detail:GetText() ~= "" then
    local top, column = y, (width - 72) / 2
    Place(w.owner, 6, 24, column); Place(w.location, 10, 24, column)
    local left = y; y = top
    Place(w.detail, 10, 48 + column, column)
    y = math.max(y, left)
  else
    Place(w.owner, 6); Place(w.location, 10); Place(w.detail, 10)
  end
  if w.captureStatus then
    Place(w.captureStatus, 10, 44, width - 88)
    w.check:ClearAllPoints(); w.check:SetPoint("RIGHT", w.captureStatus, "CENTER",
      -math.min(w.captureStatus:GetStringWidth(), w.captureStatus:GetWidth()) / 2 - 4, 0)
  end
  local contentHeight, actionY, count = y + 18, w.content and 12 or y + 6, 0
  for _, key in ipairs({ "details", "addGold", "secondaryAction", "retry" }) do
    local button = w[key]
    if button and button:IsShown() then
      button:SetParent(w.footer or w)
      Kit.Place(button, "TOPLEFT", w.footer or w, "TOPLEFT", 24, -actionY, width - 48, 28 * scale)
      actionY, count = actionY + button:GetHeight() + 8, count + 1
    end
  end
  if w.content then
    local footer = count > 0 and actionY + 10 or 0
    local height = math.min(contentHeight + footer, UIParent:GetHeight() - 48)
    local overflow = contentHeight + footer > height
    w.content:SetHeight(contentHeight); w:SetHeight(height)
    Kit.Place(w.footer, "BOTTOMLEFT", w, "BOTTOMLEFT", 0, 0, width, math.max(1, footer))
    w.footer:SetShown(footer > 0)
    Kit.Place(w.viewport, "TOPLEFT", w, "TOPLEFT", 0, 0, width, math.max(1, height - footer - (overflow and 28 or 0)))
    Kit.Place(w.scrollHint, "BOTTOM", w, "BOTTOM", 0, footer + 8)
    w.scrollHint:SetShown(overflow)
    w.viewport:SetVerticalScroll(math.max(0, math.min(w.viewport:GetVerticalScroll(), w.content:GetHeight() - w.viewport:GetHeight())))
  else w:SetHeight(count > 0 and actionY + 10 or contentHeight) end
end

function Wanted.Fill(w, b, opts)
  opts = opts or {}
  -- Retain a captured likeness across refreshes of this player's card;
  -- recycled cards must never keep the previous player's face.
  local changed = not w.posterBounty or B.Key(w.posterBounty.name) ~= B.Key(b.name)
    or w.posterScope ~= B.Scope.Key() or w.posterPreview ~= (opts.preview == true)
  if changed then Wanted.ClearPortrait(w) end
  if w.viewport and (changed or not w:IsShown() or opts.resetScroll) then w.viewport:SetVerticalScroll(0) end
  w.posterScope = B.Scope.Key()
  w.posterBounty, w.portraitLabel, w.compact = b, opts.portraitLabel, opts.compact
  w.posterPreview = opts.preview == true
  local unit, saved = R.FindUnit(b.name, opts.unit), not opts.preview and R.Record(b.name)
  local _, class
  if unit then _, class = U.call(UnitClass, unit) end
  class = U.value(class) or b.class or w.posterClass or saved and saved.class ~= "" and saved.class or nil
  w.posterClass = class
  if not w.hasPortrait then
    if not Kit.ClassIcon(w.fallback, class) then w.fallback:SetTexture(B.ICON); w.fallback:Show() end
    w.likeness:SetText("PORTRAIT UNAVAILABLE")
  else w.likeness:SetText(Likeness(w)) end
  w.title:SetText(opts.title or "WANTED")
  w.status:SetText(opts.status or "BOUNTY")
  w.trackingLabel:SetText(opts.tracking or (not opts.preview and B.Matches.Label(b) or ""))
  w.name:SetText(Core.DisplayName(b.name)); w.class:SetText(U.ClassName(class) or "Wanted player")
  local reward = b.imported and b.pledgedGold or b.gold
  w.rewardLabel:SetText(reward > 0 and (B.Terms.Count(b) > 1 and "GOLD PER APPROVED KILL" or "REWARD") or "WANTED PLAYER")
  if b.mega then w.rewardLabel:SetText("LIVE POT PER APPROVED KILL") end
  w.reward:SetText(reward > 0 and U.Gold(reward) or "No gold reward")
  w.killProgress:SetText(opts.progress or (not opts.preview and B.Terms.Progress(b) or ""))
  w.note:SetText(b.note or ""); w.owner:SetText(opts.owner or "")
  w.location:SetText(opts.location or ""); w.detail:SetText(opts.detail or (B.Terms.Custom(b) and B.Terms.Summary(b) or ""))
  if w.portraitKind ~= "native" then Wanted.Portrait(w, unit) end
  Wanted.Layout(w, opts.width)
end

U.Events({ UNIT_PORTRAIT_UPDATE = function(_, unit)
  for w in pairs(views) do
    if w:IsVisible() and w.posterBounty and R.Matches(unit, w.posterBounty.name) then
      R.Capture(w.posterBounty.name, unit, w.posterPreview, true)
      Wanted.Portrait(w, unit)
    end
  end
end }, "bounty portraits")

B.Listen("portrait", function(name)
  for w in pairs(views) do
    if w:IsVisible() and w.posterBounty and B.Key(w.posterBounty.name) == B.Key(name) and w.portraitKind ~= "native" then
      Wanted.Portrait(w, R.FindUnit(name))
    end
  end
end)

-- A portrait can become ready after a page opens without another sighting.
-- Retry only missing images; captured faces cannot follow a reused token.
U.Every(0.5, function()
  for w in pairs(views) do
    if w:IsVisible() and w.posterBounty and w.portraitKind ~= "native" then
      Wanted.Portrait(w, R.FindUnit(w.posterBounty.name, w.portraitUnit))
    end
  end
end, "bounty portraits")
