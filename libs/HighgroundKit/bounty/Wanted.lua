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
  w.portraitRevision = R.revision
  local kind = R.Apply(w, b.name, unit, w.posterPreview)
  if not kind then return end
  w.hasPortrait, w.portraitUnit, w.portraitKind = true, unit, kind
  w.portrait:SetShown(kind ~= "modelFrame"); w.fallback:Hide()
  if w.portraitModel then w.portraitModel:SetShown(kind == "modelFrame") end
  w.likeness:SetText(Likeness(w))
end

-- A missing image may wait for game art. A shown likeness can only improve
-- through a visible unit, a newly saved likeness or a captured image.
local function Retry(w, name, unit)
  return w.portraitKind ~= "native" and (unit ~= nil or not w.hasPortrait
    or w.portraitRevision ~= R.revision or R.HasNative(w, name, w.posterPreview))
end

function Wanted.ClearPortrait(w)
  R.Release(w)
  w.hasPortrait, w.portraitUnit, w.posterClass, w.portraitKind = nil, nil, nil, nil
  w.modelDisplayID, w.portraitRevision = nil, nil
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
  return math.min(320 + math.max(0, Core.FontScale() - 1) * 160, UIParent:GetWidth() - 48)
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
  w.popup = parent == UIParent
  local body = w
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
  if w.popup then Kit.Tooltip(w, function()
    if not w.thumbnail then return { w.name:GetText(), w.class:GetText(), w.likeness:GetText() } end
  end) end
  w:Hide()
  return w
end

-- Full details have room for a proper poster: a title, framed likeness and
-- reward, followed by the contract. Contribution rows keep their compact form.
function Wanted.PosterLayout(w, width)
  local scale = math.max(1, Core.FontScale())
  local pad, y = 24, 24
  local inner = width - pad * 2
  w:SetWidth(width)
  local function Place(fs, gap, x, span, align)
    fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", x or pad, -y)
    fs:SetWidth(span or inner); fs:SetJustifyH(align or "CENTER"); fs:SetHeight(0)
    local height = fs:GetText() ~= "" and math.ceil(fs:GetStringHeight()) + 2 or 0
    fs:SetHeight(math.max(1, height)); fs:SetShown(height > 0)
    if height > 0 then y = y + height + (gap or 6) end
  end
  T.SetRole(w.title, "display")
  Place(w.title, 6); Place(w.status, 18)
  local portrait, top = 136 * math.min(scale, 1.2), y
  local beside = inner >= 400 * scale
  w.portraitWell:ClearAllPoints(); w.portraitWell:Show()
  w.portraitWell:SetSize(portrait, portrait)
  w.portraitWell:SetPoint("TOPLEFT", beside and pad or (width - portrait) / 2, -y)
  local x = beside and pad + portrait + 22 or pad
  local span = beside and width - x - pad or inner
  local align = beside and "LEFT" or "CENTER"
  if not beside then y = y + portrait + 14 end
  Place(w.name, 6, x, span, align); Place(w.class, 14, x, span, align)
  Place(w.rewardLabel, 2, x, span, align); Place(w.reward, 6, x, span, align)
  y = math.max(y, top + portrait) + 18
  w.likeness:Hide()
  w.rule:ClearAllPoints(); w.rule:SetPoint("TOPLEFT", pad, -y); w.rule:SetWidth(inner); w.rule:Show()
  y = y + 16
  for _, fs in ipairs({ w.trackingLabel, w.killProgress, w.note, w.owner, w.location, w.detail }) do
    Place(fs, fs == w.note and 12 or 6, pad, inner, "LEFT")
  end
  if w.addGold and w.addGold:IsShown() then
    Kit.Place(w.addGold, "TOPLEFT", w, "TOPLEFT", pad, -y, inner, 32 * scale)
    y = y + w.addGold:GetHeight() + 6
  end
  w:SetHeight(math.max(y + 18, w.minPosterHeight or 0))
end

function Wanted.Layout(w, width)
  if w.thumbnail then return B.BoardRow.Layout(w, width) end
  local scale = Core.FontScale()
  width = width or Wanted.PopupWidth()
  if w.fullPoster and not w.contribution then return Wanted.PosterLayout(w, width) end
  w:SetWidth(width)
  local pad, gap = 18, 6
  local function Arrange(tight, withoutPortrait)
    local gap = tight and 3 or gap
    local y = 14
    local function Place(fs, after, x, span, align)
      if not fs or fs:GetText() == "" then if fs then fs:Hide() end; return end
      fs:Show(); fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", x or pad, -y)
      fs:SetWidth(span or width - pad * 2); fs:SetJustifyH(align or "CENTER")
      fs:SetHeight(0); fs:SetHeight(math.ceil(fs:GetStringHeight()) + 2)
      y = y + fs:GetHeight() + (after or gap)
    end
    for _, field in ipairs({ w.title, w.trackingLabel, w.portraitWell, w.likeness, w.name, w.class,
      w.rewardLabel, w.reward, w.killProgress, w.note, w.owner, w.location, w.detail, w.rule }) do field:Hide() end
    Place(w.status, 4, pad + (w.close and 12 or 0), width - pad * 2 - (w.close and 24 or 0))
    if w.popup then
      Place(w.title, gap)
      if not withoutPortrait then
        local portrait = tight and 48 or 80
        w.portraitWell:Show(); w.portraitWell:ClearAllPoints()
        w.portraitWell:SetPoint("TOPLEFT", (width - portrait) / 2, -y); w.portraitWell:SetSize(portrait, portrait)
        y = y + portrait + gap
      end
      Place(w.name, 4); Place(w.rewardLabel, 2); Place(w.reward, gap)
      if not tight then Place(w.trackingLabel, 4) end
      Place(w.location, gap)
      -- Notes, contributor terms and the full evidence remain in View bounty/report.
      if w.captureStatus then
        Place(w.captureStatus, gap, 38, width - 76)
        w.check:ClearAllPoints(); w.check:SetPoint("RIGHT", w.captureStatus, "LEFT", -4, 0)
      end
    elseif w.compact then
      if not w.contribution then
        local portrait, top = 64 * math.min(1.25, scale), y
        local x = pad + portrait + 12
        w.portraitWell:Show(); w.portraitWell:ClearAllPoints(); w.portraitWell:SetPoint("TOPLEFT", pad, -y)
        w.portraitWell:SetSize(portrait, portrait)
        Place(w.name, 4, x, width - x - pad, "LEFT")
        Place(w.reward, 4, x, width - x - pad, "LEFT")
        y = math.max(y, top + portrait + gap)
      else Place(w.reward, 4, pad, width - pad * 2, "LEFT") end
      for _, fs in ipairs({ w.trackingLabel, w.killProgress, w.note, w.owner, w.location, w.detail }) do
        Place(fs, 4, pad, width - pad * 2, "LEFT")
      end
    else
      Place(w.title); Place(w.name); Place(w.reward)
      for _, fs in ipairs({ w.note, w.owner, w.location, w.detail }) do Place(fs) end
    end
    for _, key in ipairs({ "details", "addGold", "secondaryAction", "retry" }) do
      local button = w[key]
      if button and button:IsShown() then
        button:SetParent(w)
        Kit.Place(button, "TOPLEFT", w, "TOPLEFT", pad, -y, width - pad * 2, 28 * scale)
        y = y + button:GetHeight() + gap
      end
    end
    return y + 10
  end
  local height = Arrange(false)
  if w.popup and height > UIParent:GetHeight() - 48 then height = Arrange(true) end
  if w.popup and height > UIParent:GetHeight() - 48 then height = Arrange(true, true) end
  w:SetHeight(height)
end

function Wanted.Fill(w, b, opts)
  opts = opts or {}
  -- Retain a captured likeness across refreshes of this player's card;
  -- recycled cards must never keep the previous player's face.
  local changed = not w.posterBounty or B.Key(w.posterBounty.name) ~= B.Key(b.name)
    or w.posterScope ~= B.Scope.Key() or w.posterPreview ~= (opts.preview == true)
  if changed then Wanted.ClearPortrait(w) end
  w.posterScope = B.Scope.Key()
  w.posterBounty, w.portraitLabel, w.compact = b, opts.portraitLabel, opts.compact or not w.popup
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
  if Retry(w, b.name, unit) then Wanted.Portrait(w, unit) end
  Wanted.Layout(w, opts.width)
end

U.Events({ UNIT_PORTRAIT_UPDATE = function(_, unit)
  for w in pairs(views) do
    if w:IsVisible() and w.posterBounty and R.Matches(unit, w.posterBounty.name) then
      R.Capture(w.posterBounty.name, unit, w.posterPreview, true)
      Wanted.Portrait(w, unit)
    end
  end
end }, "bounty portraits", "bounties")

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
    local b = w.portraitKind ~= "native" and w.posterBounty
    if b and w:IsVisible() then
      local unit = R.FindUnit(b.name, w.portraitUnit)
      if Retry(w, b.name, unit) then Wanted.Portrait(w, unit) end
    end
  end
end, "bounty portraits", "bounties")
