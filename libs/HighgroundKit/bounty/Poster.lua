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
    for _, row in ipairs(B.BoardModel.Rows(scope)) do
      if B.Key(row.name) == B.Key(item.bounty.name) then B.Details.Open(row); break end
    end
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
  w.details = Kit.Button(w, "View bounty", 230, 30, { tone = "gold", onClick = function() OpenDetails(w) end })
  Kit.Tooltip(w.details, { "View bounty", "Open the reward and its details. Drag the poster to move future alerts; hover to keep it open." })
  w.close = Kit.Button(w, "×", 24, 24, { onClick = function() w:Hide() end })
  w.close:SetPoint("TOPRIGHT", -8, -8)
  Kit.Tooltip(w.close, { "Dismiss this poster", "Other queued bounty sightings will follow." })
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
  local owner = b.state == "personal" and "Your bounty" or ("Posted by " .. Core.DisplayName(b.by or "?"))
  if b.state == "public" then owner = #b.contributions .. (b.imported and " contributors · imported offer, funds unverified" or " contributors · funds reported available") end
  if b.mega then owner = "Mega bounty · " .. #b.contributions .. " contributors" end
  local status = item.report and (B.Sightings.Near(item.report) and "REPORTED IN YOUR ZONE" or "SIGHTING REPORTED")
  local location = item.report and ("Reported: " .. B.Sightings.Describe(item.report))
    or item.where and ("Seen in " .. item.where) or "Target spotted"
  Wanted.Fill(w, b, { status = item.preview and "PREVIEW · BOUNTY SPOTTED" or status or "BOUNTY SPOTTED",
    owner = owner, location = location,
    tracking = item.preview and B.Preview.testing and (b.state == "personal" or B.Preview.state.interest == "tracking") and "TRACKING"
      or item.preview and B.Preview.testing and "NOT TRACKING" or nil,
    unit = item.unit, preview = item.preview, portraitLabel = item.preview and b.previewPortraitLabel })
  w.progress:SetWidth(w:GetWidth() - 16)
  Kit.PlaceWindow(w, "bountyPoster", { "TOPRIGHT", "TOPRIGHT", -36, -110 })
  w:Show()
  if ns.Motion then ns.Motion.Reveal(w) end
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
  if pot and #pot.contributions > 1 then w.owner:SetText("Mega bounty · " .. #pot.contributions .. " contributors") end
  w.killProgress:SetText(B.Terms.Progress(b))
  Layout(w)
end)
