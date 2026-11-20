local _, ns = ...
local O, Core = ns.Onboarding, ns.Core
local C = O.Coach

local function Value(v)
  if type(v) == "function" then return v() end
  return v
end

local function Clickable(button)
  return button and button.Click and button.IsEnabled and button:IsVisible() and button:IsEnabled()
end

function C.Stop()
  if C.router then C.router:Reset("stopped") end
  C.running, C.target, C.steps, C.key = nil, nil, nil, nil
  C.entering, C.lastX, C.lastY, C.pendingAction = nil, nil, nil, nil
  if C.BountySample then C.BountySample.Stop() end
  if C.ReputationSample then C.ReputationSample.Stop() end
  C.changing = true
  if C.root then C.HideSpotlight(); C.win:Hide(); C.root:Hide() end
  C.changing = nil
end

function C.Observe(target, event)
  if not (target and target.HookScript and event) then return end
  target.highgroundCoachHooks = target.highgroundCoachHooks or {}
  if target.highgroundCoachHooks[event] then return end
  target.highgroundCoachHooks[event] = true
  target:HookScript(event, function()
    if not C.running then return end
    local step = C.steps[C.index]
    local observed = step.observe and step.observe() or C.target
    if observed ~= target or step.event ~= event then return end
    C.observed = true
    C.win.hint:SetText("Done. Use Next when you're ready.")
    C.Layout(); C.Update()
  end)
end

function C.Update()
  if not C.running or C.entering then return end
  local step = C.steps[C.index]
  C.target = step.target and step.target()
  local context = Value(step.context)
  if not context and C.target then
    local parent = C.target
    while parent and parent:GetParent() and parent:GetParent() ~= UIParent do parent = parent:GetParent() end
    context = parent
  end
  local visible = C.Position(C.target, context)
  if step.complete then C.observed = step.complete() == true end
  if step.advance and not C.router._busy then
    local nextStep = step.advance()
    if nextStep == true then return C.Step(1) end
    if type(nextStep) == "string" then
      for i, candidate in ipairs(C.steps) do if candidate.id == nextStep and i ~= C.index then return C.Go(i) end end
    end
  end
  C.win.next:SetEnabled(not step.requireAction or C.observed == true or Clickable(Value(step.action)))
  local hint = Value(step.hint) or (C.observed and "Done. Use Next when you're ready."
    or "")
  if not visible then hint = Value(step.missing) or "This example is closed. Use Replay to reopen it, or Back to return." end
  if C.win.hint:GetText() ~= hint then C.win.hint:SetText(hint); C.Layout(); C.Position(C.target, context) end
  C.Observe(step.observe and step.observe() or C.target, step.event)
end

function C.Refresh()
  if not C.running or C.entering then return end
  local step, w = C.steps[C.index], C.win
  w.caption:SetText((O.Current().caption or O.Current().label) .. " · " .. C.index .. " / " .. #C.steps)
  w.title:SetText(Value(step.title)); w.body:SetText(Value(step.text))
  w.hint:SetText(Value(step.hint) or "")
  C.feature = step.feature
  if C.feature then
    w.enable.label:SetText(step.settingLabel or "Enable in game")
    w.enable:SetChecked(Core.On(C.feature), true)
  end
  w.back:SetEnabled(true)
  w.next:SetText(C.index == #C.steps and "Done" or "Next")
  C.Layout(); C.Update()
end

local function Enter(index, state)
  if not C.running or not C.steps[index] then return end
  C.entering = true
  C.pendingAction = nil
  C.index, C.observed = index, state and state.observed
  C.animateTarget = true
  C.win.scroll:Scroll(0)
  local step = C.steps[index]
  if step.enter then step.enter(state and state.view) end
  C.entering = nil
  O.State().samples[C.key] = step.id
  -- Escape ends the visual walkthrough before closing one of its examples.
  for i = #UISpecialFrames, 1, -1 do
    if UISpecialFrames[i] == "HighgroundSampleCoach" then table.remove(UISpecialFrames, i) end
  end
  UISpecialFrames[#UISpecialFrames + 1] = "HighgroundSampleCoach"
  C.root:Show(); C.win:Show(); C.Refresh()
end

function C.Go(index)
  if not C.running or not C.steps[index] then return end
  return C.router:Navigate(C.steps[index].id, { refresh = true })
end

function C.Step(delta)
  if not C.running then return end
  C.pendingAction = nil
  if delta < 0 then
    if C.router:CanGo(-1) then return C.router:Back() end
    if C.index == 1 then return O.Return() end
  end
  local index = C.index + delta
  if delta > 0 then
    local destination = Value(C.steps[C.index].next)
    if destination then
      for i, step in ipairs(C.steps) do if step.id == destination then index = i; break end end
    end
  end
  if index > #C.steps then
    O.State().samples[C.key] = "done"
    O.Mark(O.active or O.Current().key)
    O.Return()
  elseif index >= 1 then
    local history, cursor = C.router:History()
    local visit = history[cursor + delta]
    if visit and visit.name == C.steps[index].id then return C.router:Go(delta) end
    return C.Go(index)
  end
end

-- Only explicit sample actions opt in. The native button owns validation,
-- side effects and hooks; the coach never replaces its click handler.
function C.Continue()
  if not C.running or C.pendingAction then return end
  local step, router = C.steps[C.index], C.router
  local button = Value(step.action)
  if not button then
    if not step.requireAction or C.observed then return C.Step(1) end
    return
  end
  if not Clickable(button) then return end
  if not button.highgroundCoachAction then
    button.highgroundCoachAction = true
    button:HookScript("OnClick", function()
      if C.pendingAction and C.pendingAction.button == button then C.pendingAction = nil end
    end)
  end
  local pending = { button = button }; C.pendingAction = pending
  local function Activate()
    if C.pendingAction ~= pending or not C.running or C.router ~= router or C.steps[C.index] ~= step then return end
    C.pendingAction = nil
    if not ns.Setup.CanArrange() or Value(step.action) ~= button or not Clickable(button) then return end
    button:Click("LeftButton")
    C.Update()
  end
  if Core.ReducedMotion() then return Activate() end
  C.PointAt(button, C.win.next)
  C_Timer.After(0.55, Activate)
end

function C.Replay()
  if not C.running then return end
  C.pendingAction = nil
  C.observed = nil
  return C.router:Refresh()
end

function C.Start(key, steps)
  if not steps or #steps == 0 then return O.Return() end
  C.Stop(); C.Build()
  if type(O.State().samples) ~= "table" then O.State().samples = {} end
  C.key, C.steps, C.running = key, steps, true
  C.router = ns.Router.New()
  C.router:Register("stopped")
  for i, step in ipairs(steps) do
    C.router:Register(step.id, {
      capture = function() return { observed = C.observed, view = step.capture and step.capture() } end,
      beforeEnter = function() return C.running == true end,
      enter = function(to) Enter(i, to.state) end,
    })
  end
  C.router:On("cancel", function(event)
    C.entering = nil
    if C.running and C.win then C.win.hint:SetText(event.failure.message .. " Use Guides to return.") end
  end)
  local current, index = O.State().samples[key], 1
  for i, step in ipairs(steps) do if step.id == current then index = i end end
  if O.dock then O.dock:Hide() end
  C.Go(index)
end
