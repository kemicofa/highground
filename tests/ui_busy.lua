return function(s, t, fire)
  local K, C = s.ns.Kit, s.ns.Core
  t.test("busy buttons lock duplicate work and preserve labels and eligibility", function()
    local pending, progress, calls, finished, reads = false, nil, 0, 0, 0
    local parent = s.env.CreateFrame("Frame", nil, s.env.UIParent)
    local b = K.Button(parent, "Check", 120, 28, { onClick = function() calls = calls + 1; pending = true end })
    local frames, timers = #s.frames, #s.timers
    K.BusyButton(b, function() reads = reads + 1; return pending, "Checking…", progress end,
      function() finished = finished + 1 end)
    for _ = 1, 10 do b:RefreshBusy() end
    t.equal(#s.frames, frames, "idle controls create no loader widgets")
    t.equal(#s.timers, timers, "idle controls start no polling")
    fire(b, "OnClick")
    assert(not b:IsEnabled() and b.busyBar:IsVisible() and b.busyPulse.wanted)
    t.equal(b.label:GetText(), "Checking…", "pending action is named")
    local ticker = s.timers[#s.timers]
    frames, timers = #s.frames, #s.timers
    for _ = 1, 10 do b:SetEnabled(true); b:RefreshBusy(); fire(b, "OnClick") end
    t.equal(calls, 1, "refreshes and duplicate clicks cannot restart the operation")
    t.equal(#s.frames, frames, "busy refreshes reuse loader widgets")
    t.equal(#s.timers, timers, "busy refreshes reuse one timer")
    progress = 0.5; b:RefreshBusy()
    t.close(b.busyBar:GetWidth(), 56, "progress uses the measured fraction")
    assert(not b.busyPulse.wanted, "measured progress does not pulse")
    progress = nil; C.SetReducedMotion(true); b:RefreshBusy()
    assert(b.busyBar:IsVisible() and not b.busyPulse.group:IsPlaying(), "reduced motion keeps a steady loading cue")
    b:SetText("Retry"); b:Disable(); parent:Hide()
    fire(b, "OnHide") -- Simulator does not propagate native child visibility events.
    assert(ticker.cancelled and not b.busyPulse.wanted, "hiding the parent cancels polling and animation")
    local hiddenReads = reads; s:advance(0.4)
    t.equal(reads, hiddenReads, "hidden controls perform no status polling")
    parent:Show(); fire(b, "OnShow")
    assert(not b:IsEnabled() and b.busyBar:IsVisible(), "reopening resumes pending feedback")
    pending = false; s:advance(0.3)
    t.equal(finished, 1, "completion is observed once")
    assert(not b:IsEnabled() and not b.busyBar:IsShown(), "completion respects independently disabled eligibility")
    t.equal(b.label:GetText(), "Retry", "latest intended label restored")
    b:Enable(); fire(b, "OnClick"); pending = false; b:RefreshBusy()
    assert(b:IsEnabled() and not b.busyBar:IsShown(), "the next attempt restores eligible controls")
    t.equal(calls, 2, "retry starts once")
    t.equal(finished, 2, "retry completes once")
    C.SetReducedMotion(false); parent:Hide()
  end)
end
