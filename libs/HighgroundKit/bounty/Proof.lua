local _, ns = ...
local B, Kit, U = ns.Bounty, ns.Kit, ns.Util
local P = { queue = {}, recent = {}, capture = ns.Async.New() }
B.Proof = P

local function Description(item)
  local text = B.Kills.EvidenceText(item.evidence, true) .. "\n" .. date("%d %b · %H:%M:%S", item.at)
    .. "\nKilling blow: " .. B.Kills.CauseText(item.cause)
  local c = not item.preview and B.Ledger.Find(item.bounty.name, item.at)
  local status = c and (B.Ledger.Tracking(c) and "Saved to your private history."
    or c.state == "approved" and "Reward approved · arrange payment with the poster."
    or c.state == "paid" and "Payment recorded."
    or c.state == "rejected" and "Report declined."
    or c.public and not c.received and (B.Public.Now() > c.killedAt + B.Public.CLAIM_WINDOW
      and "Delivery unconfirmed · contact the poster and share proof."
      or "Report saved · waiting for the poster to receive it.")
    or "Report saved · awaiting reward review.") or item.reportText
  if status then text = text .. "\n" .. status end
  return text
end

local function Heading(evidence)
  if evidence == "observed killing blow" then return "KILLED", "KILL CONFIRMED" end
  if evidence == "honor credit" then return "HONOR CREDIT", "KILLING BLOW UNCONFIRMED" end
  if evidence == "observed death" then return "DEATH OBSERVED", "KILLER UNCONFIRMED" end
  return "REPORTED", "MANUAL KILL REPORT"
end

function P.Refresh(item)
  local w = P.win
  if not (w and w.item == item) then return end
  w.detail:SetText(Description(item))
  w.captureStatus:SetText(item.captureText or "Screenshot pending…")
  w.killProgress:SetText(B.Terms.Progress(item.bounty))
  -- The texture is the checkmark; the text also makes status accessible.
  w.check:SetShown(item.screenshot == true)
  w.close:SetEnabled(not item.capturing)
  w.details:SetEnabled(not item.capturing)
  w.details:SetText(B.Ledger.Find(item.bounty.name, item.at) and "View report" or "View bounty")
  w.retry:SetShown(item.captureState == "failed")
  B.Wanted.Layout(w, B.Wanted.PopupWidth())
end

function P.Capture(item)
  if P.active or not item or item.screenshot then return end
  if not P.win or not P.win:IsVisible() or P.win.item ~= item then return end
  local attempt = P.capture:Start(item)
  if type(Screenshot) ~= "function" then
    item.captureState, item.captureText = "unavailable", "Screenshot unavailable. Use the game's screenshot key."
    P.capture:Finish(attempt, "unavailable", item.captureText)
    P.Refresh(item); return
  end
  P.active, item.capturing, item.captureText = item, true, "Taking screenshot…"
  item.captureState = "pending"
  item.requested = nil
  P.Refresh(item)
  -- Let the wanted poster render before requesting the image.
  C_Timer.After(0.25, function()
    if not P.capture:IsCurrent(attempt) then return end
    if not P.win:IsVisible() or P.win.item ~= item then P.Result(false, nil, attempt); return end
    item.requested = true
    if not pcall(Screenshot) then P.Result(false, nil, attempt); return end
    C_Timer.After(8, function()
      P.Result(false, "Screenshot not confirmed. Retry or use the screenshot key.", attempt)
    end)
  end)
end

function P.Result(success, message, attempt)
  attempt = attempt or P.capture.current
  local state = success and "succeeded" or "failed"
  if not P.capture:Finish(attempt, state, message) then return end
  local item = attempt.value
  P.active, item.capturing = nil, nil
  item.captureState, item.requested = state, nil
  item.screenshot = success == true
  item.captureText = success and "Screenshot saved successfully in WoW/Screenshots."
    or message or "Screenshot failed. Retry or use the screenshot key."
  P.Refresh(item)
  -- Rapid kills each get a capture; the last poster stays until dismissed.
  if #P.queue > 0 then P.Next() end
end

function P.CancelCapture()
  local item = P.active
  P.capture:Cancel()
  P.active = nil
  if item then item.captureState, item.capturing, item.requested = "cancelled", nil, nil end
end

function P.Build()
  if P.win then return P.win end
  local w = B.Wanted.Build(UIParent, (ns.FRAME_PREFIX or "Highground") .. "BountyKilled")
  P.win = w
  w:SetFrameStrata("FULLSCREEN_DIALOG"); w:SetFrameLevel(110)
  w:SetMovable(true); w:SetClampedToScreen(true); w:EnableMouse(true); w:RegisterForDrag("LeftButton")
  Kit.PlaceWindow(w, "bountyKilled", { "TOPRIGHT", "TOPRIGHT", -36, -90 })
  w:SetScript("OnDragStart", function(self) self:StartMoving() end)
  w:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); Kit.SavePoint("bountyKilled", self) end)
  w.close = Kit.Button(w, "×", 24, 24, { onClick = function() w:Hide() end })
  w.close:SetPoint("TOPRIGHT", -8, -8)
  w.check = (w.content or w):CreateTexture(nil, "OVERLAY"); w.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  w.captureStatus = B.Wanted.Text(w.content or w, "bodySmall", "posterMuted")
  w.check:SetSize(16, 16); w.check:SetPoint("RIGHT", w.captureStatus, "LEFT", -4, 0); w.check:Hide()
  w.details = Kit.Button(w, "View report", 280, 30, { tone = "gold", onClick = function()
    local item = w.item
    if not item then return end
    local report = B.Ledger.Find(item.bounty.name, item.at)
    if report then B.Ledger.Open(item.bounty.name, item.at, report.id)
    else B.Public.OpenDetails(item.bounty.name) end
    w:Hide()
  end })
  w.proof = Kit.Button(w, "Copy proof (optional)", 280, 28, { onClick = function() if w.item then B.Exchange.Proof(w.item) end end })
  w.secondaryAction = w.proof
  w.retry = Kit.Button(w, "Retry screenshot", 160, 24, { onClick = function() P.Capture(w.item) end })
  w.retry:SetPoint("TOPRIGHT", w, "BOTTOMRIGHT", 0, -6)
  w:SetScript("OnShow", function(self) if self.item then P.Capture(self.item) end end)
  w:SetScript("OnHide", function(self)
    if self:IsShown() then return end -- Alt-Z does not discard the request.
    self:StopMovingOrSizing()
    if P.active == self.item then P.CancelCapture() end
    self.item = nil
    P.Next()
  end)
  ns.Core.OnFontScaleChange(function() if w.item then P.Refresh(w.item) end end)
  return w
end

function P.Next()
  local item = table.remove(P.queue, 1)
  if not item then return end
  local w = P.Build()
  w.item = item
  local b = item.bounty
  local title, status = Heading(item.evidence)
  B.Wanted.Fill(w, b, { status = status, title = title, compact = true,
    owner = "", location = item.zone, detail = Description(item), width = B.Wanted.PopupWidth(),
    unit = B.Portraits.FindUnit(b.name), resetScroll = true })
  w:Show(); P.Refresh(item); P.Capture(item)
end

function P.Show(b, evidence, at, cause, reportText)
  if not b then return end
  at = at or B.Public.Now()
  local identity = B.Scope.Key() .. ":" .. B.Key(b.name) .. ":" .. at
  if P.recent[identity] then return end
  for key, stamp in pairs(P.recent) do if at - stamp > 3600 then P.recent[key] = nil end end
  P.recent[identity] = at
  local item = { bounty = B.Public.Copy(b), at = at, evidence = evidence or "manual report",
    cause = cause and B.Public.Copy(cause), reportText = reportText,
    global = b.state == "public", ruleset = B.Scope.Ruleset(), scope = B.Scope.Key(), zone = U.ZoneName() }
  if item.global then item.bounty.gold = b.pledgedGold or b.gold end
  P.queue[#P.queue + 1] = item
  if not P.active then P.Next() end
end

function P.Preview(b, item)
  local w = P.previewWin
  if not w then
    w = B.Wanted.Build(UIParent, (ns.FRAME_PREFIX or "Highground") .. "BountyKilledPreview")
    P.previewWin = w
    w:SetFrameStrata("FULLSCREEN_DIALOG"); w:SetFrameLevel(110)
    w:SetMovable(true); w:SetClampedToScreen(true); w:EnableMouse(true); w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", function(self) if self:IsMovable() then self:StartMoving() end end)
    w:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing(); if B.Preview.testing then Kit.SavePoint("bountyKilled", self) end
    end)
    w:SetScript("OnHide", function(self) if not self:IsShown() then self:StopMovingOrSizing() end end)
    if UISpecialFrames then table.insert(UISpecialFrames, (ns.FRAME_PREFIX or "Highground") .. "BountyKilledPreview") end
    w.details = Kit.Button(w, "View sample report", 280, 30, { tone = "gold", onClick = function() B.Preview.OpenClaims() end })
    w.proof = Kit.Button(w, "Copy sample proof (optional)", 280, 28, { onClick = function() B.Exchange.Proof(w.item) end })
    w.close = Kit.Button(w, "×", 24, 24, { onClick = function() w:Hide() end }); w.close:SetPoint("TOPRIGHT", -8, -8)
    w.check = (w.content or w):CreateTexture(nil, "OVERLAY"); w.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    w.captureStatus = B.Wanted.Text(w.content or w, "bodySmall", "posterMuted")
    w.check:SetSize(16, 16); w.check:SetPoint("RIGHT", w.captureStatus, "LEFT", -4, 0)
    w.retry = Kit.Button(w, "Retry sample capture", 230, 28, { onClick = function() B.Preview.Capture("saved") end })
    w.retry:SetPoint("TOPRIGHT", w, "BOTTOMRIGHT", 0, -6)
    ns.Core.OnFontScaleChange(function() if w:IsShown() then B.Wanted.Layout(w, B.Wanted.PopupWidth()) end end)
  end
  item = item or B.Preview.ProofItem()
  w.details:SetText(B.Preview.testing and "View report" or "View sample report")
  w.proof:SetText(B.Preview.testing and "Copy proof (optional)" or "Copy sample proof (optional)")
  w.retry:SetText(B.Preview.testing and "Retry screenshot" or "Retry sample capture")
  Kit.PlaceWindow(w, "bountyKilled", { "TOPRIGHT", "TOPRIGHT", -36, -90 })
  w.item = item
  w.captureStatus:SetText(item.captureText or "Sample screenshot pending")
  w.check:SetShown(item.screenshot == true); w.retry:SetShown(item.captureState == "failed")
  w.secondaryAction = w.proof
  local title, status = Heading(item.evidence)
  B.Wanted.Fill(w, b, { title = title, status = "PREVIEW · " .. status, preview = true, compact = true,
    width = B.Wanted.PopupWidth(), owner = "Sample report · awaiting reward review", location = "Tarren Mill",
    detail = Description(item), progress = B.Preview.Progress(b),
    tracking = B.Preview.testing and (B.Preview.state.interest == "tracking" and "TRACKING" or "NOT TRACKING") or nil,
    portraitLabel = b.previewPortraitLabel })
  w:Show()
  return w
end

U.Events({ SCREENSHOT_SUCCEEDED = function() if P.active and P.active.requested then P.Result(true) end end,
  SCREENSHOT_FAILED = function() if P.active and P.active.requested then P.Result(false) end end }, "bounty proof capture", "bounties")
B.Listen("scope", function()
  P.CancelCapture(); wipe(P.queue); wipe(P.recent)
  if P.win then P.win:Hide() end
  if P.previewWin then P.previewWin:Hide() end
end)
B.Listen("updated", function() if P.win and P.win.item then P.Refresh(P.win.item) end end)
