local _, ns = ...
local B, Core, Kit, T = ns.Bounty, ns.Core, ns.Kit, ns.Theme
local Poster = { pending = {}, previewPending = {}, DURATION = 10, MAX_PENDING = 3, MAX_AGE = 30 }
B.Poster = Poster

local Wanted = B.Wanted
Poster.Observe = Wanted.Observe

local function Allowed(b)
  local current = B.Enabled() and Core.O("bountyAnnounce")
    and (not ns.Alerts or ns.Alerts.Allowed("bounty", "text"))
    and not (ns.NearbyHistory and ns.NearbyHistory.Muted(b.name))
    and B.Find(b.name, true)
  return current and B.Key(current.name) == B.Key(b.name) and current
end

local Layout = Wanted.Layout

local function OpenDetails(w)
  local item = w.item
  if not item then return end
  w:Hide()
  if item.preview then
    if item.row then
      if B.Preview.testing then B.Preview.TestDetails(item.row) else B.Details.Open(item.row, true) end
    end
  else
    local scope = item.bounty.state == "public" and "public" or item.bounty.state == "personal" and "mine" or "guild"
    B.Board.Open()
    B.Board.SetTab(scope)
    local row = B.BoardModel.Find(scope, item.bounty.name)
    if row then B.Details.Open(row) end
  end
end

function Poster.Build(preview)
  local field = preview and "previewWin" or "win"
  if Poster[field] then return Poster[field] end
  local name = (ns.FRAME_PREFIX or "Highground") .. (preview and "BountyPosterPreview" or "BountyPoster")
  local w = Wanted.Build(UIParent, name)
  Poster[field] = w
  w:Hide(); w:SetFrameStrata("FULLSCREEN_DIALOG"); w:SetFrameLevel(100)
  w:EnableMouse(true); w:SetMovable(true); w:SetClampedToScreen(true)
  Kit.PlaceWindow(w, "bountyPoster", { "TOPRIGHT", "TOPRIGHT", -36, -110 })
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self) if self:IsMovable() then self:StartMoving(); self.dragging = true end end)
  w:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing(); self.dragging = nil
    if not preview or B.Preview.testing then Kit.SavePoint("bountyPoster", self) end
  end)
  if UISpecialFrames then table.insert(UISpecialFrames, name) end
  -- Same controls as the tracking and kill alerts.
  w.details = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.boardactions.view_bounty.be066d"), 230, 30, { tone = "posterPrimary", onClick = function() OpenDetails(w) end }),
    "shared.boardactions.view_bounty.be066d")
  Kit.Tooltip(w.details, function() return { ns.Locale:Get("shared.boardactions.view_bounty.be066d"), ns.Locale:Get("shared.poster.open_the_reward_and_its_details_drag.6de8e7") } end)
  w.close = Kit.Button(w, "×", 24, 24, { tone = "posterSecondary", onClick = function() w:Hide() end })
  w.close:SetPoint("TOPRIGHT", -8, -8)
  Kit.Tooltip(w.close, function() return { ns.Locale:Get("shared.poster.dismiss_this_poster.28d69f"), ns.Locale:Get("shared.poster.other_queued_bounty_sightings_will_follow.2ae702") } end)
  w.progress = T.Fill(w, "OVERLAY", "posterStamp")
  w.progress:SetHeight(2); w.progress:SetPoint("BOTTOMLEFT", 8, 8)
  w:SetScript("OnUpdate", function(self, elapsed)
    if not self.item then return end
    self.checkElapsed = self.checkElapsed + elapsed
    if self.checkElapsed >= 0.25 then
      self.checkElapsed = 0
      if not self.item.preview and not Allowed(self.item.bounty) then self:Hide(); return end
    end
    if not (self.tourDocked or self.dragging or self:IsMouseOver()) then self.remaining = self.remaining - elapsed end
    self.progress:SetWidth(math.max(1, (self:GetWidth() - 16) * self.remaining / Poster.DURATION))
    if self.remaining <= 0 then self:Hide() end
  end)
  w:SetScript("OnHide", function(self)
    -- Hiding UIParent (Alt-Z/cinematics) is not a dismissal. The same
    -- alert resumes when the UI returns, with its portrait and timer intact.
    if self:IsShown() then return end
    if self.dragging then self:StopMovingOrSizing(); if not preview then Kit.SavePoint("bountyPoster", self) end end
    self.item, self.hasPortrait, self.dragging = nil, nil, nil
    self.posterBounty = nil; Wanted.ClearPortrait(self)
    if ns.Motion then ns.Motion.Stop(self, 1) end
    if not preview or B.Preview.testing then Poster.Next(preview) end
  end)
  Core.OnFontScaleChange(function() if w.item then Layout(w) end end)
  return w
end

local function Present(w, item)
  local b = item.bounty
  local pot = not item.preview and B.Pot.Find(b.name)
  if pot and #pot.contributions > 1 then b = B.Public.Copy(pot); b.gold = pot.pledgedGold end
  w.item, w.remaining, w.checkElapsed = item, Poster.DURATION, 0
  local status = item.report and (B.Sightings.Near(item.report) and ns.Locale:Get("shared.poster.reported_in_your_zone.325a83") or ns.Locale:Get("shared.poster.sighting_reported.19830d"))
  local location = item.report and B.Sightings.Report(item.report)
    or item.where and (ns.Locale:Format("shared.poster.seen_in_item_where.c49abd", { item_where = item.where })) or ns.Locale:Get("shared.poster.target_spotted.ae9963")
  Wanted.Fill(w, b, { status = item.preview and ns.Locale:Get("shared.poster.preview_bounty_spotted.0f4329") or status or ns.Locale:Get("shared.poster.bounty_spotted.571cce"),
    from = B.From(b), location = location,
    tracking = item.preview and B.Preview.testing and (b.state == "personal" or B.Preview.state.interest == "tracking") and ns.Locale:Get("shared.matches.tracking.9ad1ea")
      or item.preview and B.Preview.testing and ns.Locale:Get("shared.matches.not_tracking.7b1dc4") or nil,
    unit = item.unit, preview = item.preview, portraitLabel = item.preview and b.previewPortraitLabel })
  w.progress:SetWidth(w:GetWidth() - 16)
  Kit.PlaceWindow(w, "bountyPoster", { "TOPRIGHT", "TOPRIGHT", -36, -110 })
  -- A new poster slides in from the right; an update to an open one stays put.
  local opening = not w:IsShown()
  w:Show()
  if opening and ns.Motion then ns.Motion.Reveal(w); ns.Motion.Slide(w, 16, 0) end
end

function Poster.Next(preview)
  local pending = preview and Poster.previewPending or Poster.pending
  while #pending > 0 do
    local item = table.remove(pending, 1)
    local bounty = preview and item.bounty or Allowed(item.bounty)
    if bounty and GetTime() - item.at <= Poster.MAX_AGE then
      bounty.class = bounty.class or item.bounty.class
      item.bounty = bounty
      Present(Poster.Build(preview), item)
      return
    end
  end
end

function Poster.Show(b, where, unit, preview, report)
  local item = { bounty = b, where = where, unit = unit, preview = preview, at = GetTime(),
    row = preview and B.Preview and B.Preview.row, report = report }
  if preview and not B.Preview.testing then Present(Poster.Build(true), item); return end
  if not preview and not Allowed(b) then return end
  local pending = preview and Poster.previewPending or Poster.pending
  local w = Poster[preview and "previewWin" or "win"]
  if w and w:IsShown() then
    if B.Key(w.item.bounty.name) == B.Key(b.name) then
      if w.item.report then Present(w, item) else Poster.Observe(b, unit) end
      return
    end
    for _, queued in ipairs(pending) do if B.Key(queued.bounty.name) == B.Key(b.name) then return end end
    if #pending >= Poster.MAX_PENDING then table.remove(pending, 1) end
    if report and B.Sightings.Near(report) then table.insert(pending, 1, item)
    else pending[#pending + 1] = item end
  else Present(Poster.Build(preview), item) end
end

function Poster.StopPreview()
  wipe(Poster.previewPending)
  if Poster.previewWin then Poster.previewWin:Hide() end
end

B.Listen("updated", function()
  local w = Poster.win
  if not (w and w.item and w:IsShown()) then return end
  local b = Allowed(w.item.bounty)
  if not b then w:Hide(); return end
  w.item.bounty = b
  local pot = B.Pot.Find(b.name)
  w.reward:SetText(ns.Util.Gold(pot and pot.pledgedGold or b.gold))
  w.from:SetText(B.From(pot and #pot.contributions > 1 and pot or b) or "")
  w.killProgress:SetText(B.Terms.Progress(b))
  Layout(w)
end)
