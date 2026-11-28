local _, ns = ...
local B, Kit, U = ns.Bounty, ns.Kit, ns.Util
local P = { queue = {}, recent = {}, capture = ns.Async.New() }
B.Proof = P

local function Description(item)
  local text = ns.Locale:Format("shared.proof.value1_value3_killing_blow_value5.5fdfc2", { value1 = B.Kills.EvidenceText(item.evidence, true), value3 = ns.Util.Exact(item.at), value5 = B.Kills.CauseText(item.cause) })
  local c = not item.preview and B.Ledger.Find(item.bounty.name, item.at)
  local status = c and (B.Ledger.Tracking(c) and ns.Locale:Get("shared.proof.saved_to_your_private_history.719c5c")
    or c.state == "approved" and ns.Locale:Get("shared.proof.reward_approved_arrange_payment_with_the_poster.1578cf")
    or c.state == "paid" and ns.Locale:Get("shared.proof.payment_recorded.c63aeb")
    or c.state == "rejected" and ns.Locale:Get("shared.proof.report_declined.c39fab")
    or c.public and not c.received and (B.Public.Now() > c.killedAt + B.Public.CLAIM_WINDOW
      and ns.Locale:Get("shared.proof.delivery_unconfirmed_contact_the_poster_and_share.d711e7")
      or ns.Locale:Get("shared.proof.report_saved_waiting_for_the_poster_to.d663a9"))
    or ns.Locale:Get("shared.proof.report_saved_awaiting_reward_review.beb92b")) or item.reportText
  if status then text = text .. "\n" .. status end
  return text
end

local function Heading(evidence)
  if evidence == "observed killing blow" then return ns.Locale:Get("shared.proof.killed.c9ca0b"), ns.Locale:Get("shared.proof.kill_confirmed.f52b59") end
  if evidence == "honor credit" then return ns.Locale:Get("shared.proof.honor_credit.b02393"), ns.Locale:Get("shared.proof.killing_blow_unconfirmed.7d8c1e") end
  if evidence == "observed death" then return ns.Locale:Get("shared.proof.death_observed.5d4ab2"), ns.Locale:Get("shared.proof.killer_unconfirmed.99d25d") end
  return ns.Locale:Get("shared.boardrow.reported.7c64c1"), ns.Locale:Get("shared.proof.manual_kill_report.4da2a0")
end

function P.Refresh(item)
  local w = P.win
  if not (w and w.item == item) then return end
  w.detail:SetText(Description(item))
  w.captureStatus:SetText(item.captureText or ns.Locale:Get("shared.proof.screenshot_pending.0ea010"))
  w.killProgress:SetText(B.Terms.Progress(item.bounty))
  -- The texture is the checkmark; the text also makes status accessible.
  w.check:SetShown(item.screenshot == true)
  w.close:SetEnabled(not item.capturing)
  w.details:SetEnabled(not item.capturing)
  w.details:SetText(B.Ledger.Find(item.bounty.name, item.at) and ns.Locale:Get("highground.coachbountysamples.view_report.7398c9") or ns.Locale:Get("shared.boardactions.view_bounty.be066d"))
  w.retry:SetShown(item.captureState == "failed" or item.capturing == true)
  w.retry:RefreshBusy()
  B.Wanted.Layout(w, B.Wanted.PopupWidth())
end

function P.Capture(item)
  if P.active or not item or item.screenshot then return end
  if not P.win or not P.win:IsVisible() or P.win.item ~= item then return end
  local attempt = P.capture:Start(item)
  if type(Screenshot) ~= "function" then
    item.captureState, item.captureText = "unavailable", ns.Locale:Get("shared.proof.screenshot_unavailable_use_the_game_s_screenshot.d28fad")
    P.capture:Finish(attempt, "unavailable", item.captureText)
    P.Refresh(item); return
  end
  P.active, item.capturing, item.captureText = item, true, ns.Locale:Get("shared.previewflows.taking_screenshot.4b1e7c")
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
      P.Result(false, ns.Locale:Get("shared.proof.screenshot_not_confirmed_retry_or_use_the.bfe99f"), attempt)
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
  item.captureText = success and ns.Locale:Get("shared.previewflows.screenshot_saved_successfully_in_wow_screenshots.b0687a")
    or message or ns.Locale:Get("shared.previewflows.screenshot_failed_retry_or_use_the_screenshot.73a99d")
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
  w.close = Kit.Button(w, "×", 24, 24, { tone = "posterSecondary", onClick = function() w:Hide() end })
  w.close:SetPoint("TOPRIGHT", -8, -8)
  w.check = (w.content or w):CreateTexture(nil, "OVERLAY"); w.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  w.captureStatus = B.Wanted.Text(w.content or w, "bodySmall", "posterMuted")
  w.check:SetSize(16, 16); w.check:SetPoint("RIGHT", w.captureStatus, "LEFT", -4, 0); w.check:Hide()
  w.details = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.coachbountysamples.view_report.7398c9"), 280, 30, { tone = "posterPrimary", onClick = function()
    local item = w.item
    if not item then return end
    local report = B.Ledger.Find(item.bounty.name, item.at)
    if report then B.Ledger.Open(item.bounty.name, item.at, report.id)
    else B.Public.OpenDetails(item.bounty.name) end
    w:Hide()
  end }), "highground.coachbountysamples.view_report.7398c9")
  w.proof = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.proof.copy_proof_optional.34c260"), 280, 28, { tone = "posterSecondary", onClick = function() if w.item then B.Exchange.Proof(w.item) end end }), "shared.proof.copy_proof_optional.34c260")
  w.secondaryAction = w.proof
  w.retry = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.proof.retry_screenshot.09452c"), 160, 24, { tone = "posterSecondary", onClick = function() P.Capture(w.item) end }), "shared.proof.retry_screenshot.09452c")
  Kit.BusyButton(w.retry, function() return w.item and w.item.capturing == true, ns.Locale:Get("shared.proof.capturing.d8f2a9") end)
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
    w.details = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.proof.view_sample_report.450829"), 280, 30, { tone = "posterPrimary", onClick = function() B.Preview.OpenClaims() end }), "shared.proof.view_sample_report.450829")
    w.proof = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.proof.copy_sample_proof_optional.96412b"), 280, 28, { tone = "posterSecondary", onClick = function() B.Exchange.Proof(w.item) end }), "shared.proof.copy_sample_proof_optional.96412b")
    w.close = Kit.Button(w, "×", 24, 24, { tone = "posterSecondary", onClick = function() w:Hide() end }); w.close:SetPoint("TOPRIGHT", -8, -8)
    w.check = (w.content or w):CreateTexture(nil, "OVERLAY"); w.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    w.captureStatus = B.Wanted.Text(w.content or w, "bodySmall", "posterMuted")
    w.check:SetSize(16, 16); w.check:SetPoint("RIGHT", w.captureStatus, "LEFT", -4, 0)
    w.retry = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.proof.retry_sample_capture.f2f55b"), 230, 28, { tone = "posterSecondary", onClick = function() B.Preview.RetryCapture() end }), "shared.proof.retry_sample_capture.f2f55b")
    Kit.BusyButton(w.retry, function() return w.item and w.item.captureState == "pending", ns.Locale:Get("shared.proof.capturing.d8f2a9") end)
    w.retry:SetPoint("TOPRIGHT", w, "BOTTOMRIGHT", 0, -6)
    ns.Core.OnFontScaleChange(function() if w:IsShown() then B.Wanted.Layout(w, B.Wanted.PopupWidth()) end end)
  end
  item = item or B.Preview.ProofItem()
  w.details:SetText(B.Preview.testing and ns.Locale:Get("highground.coachbountysamples.view_report.7398c9") or ns.Locale:Get("shared.proof.view_sample_report.450829"))
  w.proof:SetText(B.Preview.testing and ns.Locale:Get("shared.proof.copy_proof_optional.34c260") or ns.Locale:Get("shared.proof.copy_sample_proof_optional.96412b"))
  w.retry:SetText(B.Preview.testing and ns.Locale:Get("shared.proof.retry_screenshot.09452c") or ns.Locale:Get("shared.proof.retry_sample_capture.f2f55b"))
  Kit.PlaceWindow(w, "bountyKilled", { "TOPRIGHT", "TOPRIGHT", -36, -90 })
  w.item = item
  w.captureStatus:SetText(item.captureText or ns.Locale:Get("shared.proof.sample_screenshot_pending.0f2db0"))
  w.check:SetShown(item.screenshot == true)
  w.retry:SetShown(item.captureState == "failed" or item.captureState == "pending")
  w.retry:RefreshBusy()
  w.secondaryAction = w.proof
  local title, status = Heading(item.evidence)
  B.Wanted.Fill(w, b, { title = title, status = ns.Locale:Format("shared.proof.preview_status.55eaf3", { status = status }), preview = true, compact = true,
    width = B.Wanted.PopupWidth(), owner = ns.Locale:Get("shared.copy.sample_report_awaiting_reward_review.fe80c8"), location = ns.Locale:Get("shared.preview.tarren_mill.f2b545"),
    detail = Description(item), progress = B.Preview.Progress(b),
    tracking = B.Preview.testing and (B.Preview.state.interest == "tracking" and ns.Locale:Get("shared.matches.tracking.9ad1ea") or ns.Locale:Get("shared.matches.not_tracking.7b1dc4")) or nil,
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
