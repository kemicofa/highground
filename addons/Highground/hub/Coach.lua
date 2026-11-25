local _, ns = ...
local O, Core = ns.Onboarding, ns.Core
local C = O.Coach

local function Value(v)
  if type(v) == "function" then return v() end
  return v
end

-- A step without its own switch keeps the previous one, so a feature's
-- guide offers its switch on every step. feature = false ends the run.
function C.StepFeature(steps, index)
  for i = index, 1, -1 do
    local step = steps[i]
    if step.feature ~= nil then return step.feature or nil, step.settingLabel end
  end
end

local features
local function Feature(key)
  if not features then
    features = {}
    for _, def in ipairs(ns.OptionsConfig.features) do if def.key then features[def.key] = def end end
  end
  return features[key]
end

-- A child switch only works under its parents, so the guide reads and
-- enables the whole chain.
function C.FeatureOn(key)
  while key do
    if not Core.On(key) then return false end
    key = Feature(key) and Feature(key).parent
  end
  return true
end

function C.SetFeature(key, on)
  if InCombatLockdown() then return end
  Core.SetFeature(key, on)
  local parent = on and Feature(key) and Feature(key).parent
  while parent do
    if not Core.On(parent) then Core.SetFeature(parent, true) end
    parent = Feature(parent) and Feature(parent).parent
  end
end

-- What else must be on before an alert's sound plays in game.
local SOUND_GATES = {
  capture = { feature = "capAlert" }, objective = { feature = "objectiveOverview" },
  resurrection = { feature = "dieAlert" }, sap = { feature = "sapCall" }, go = { feature = "killorder" },
  lockon = { feature = "sniper" }, bounty = {}, nearby = {},
}

-- False when this client does not offer the alert's switch.
function C.SoundAvailable(category)
  local gate = SOUND_GATES[category]
  local def = gate and gate.feature and Feature(gate.feature)
  if not gate or gate.feature and not (def and ns.OptionAvailable(def)) then return false end
  for _, alert in ipairs(ns.Alerts.categories) do
    if alert.key == category then return not ns.Modules or ns.Modules.Active(alert.module) end
  end
  return false
end

-- Whether the alert plays its sound in game: its feature, its Sound switch
-- and the master sound switch.
function C.SoundOn(category)
  local gate = SOUND_GATES[category]
  if not gate or gate.feature and not C.FeatureOn(gate.feature) then return false end
  return ns.Alerts.Allowed(category, "sound")
end

-- On turns on everything the sound needs; off mutes only this alert's sound.
function C.SetSoundOn(category, on)
  local gate = SOUND_GATES[category]
  if not gate or InCombatLockdown() then return end
  ns.Alerts.SetChannel(category, "sound", on)
  if not on then return end
  if not Core.On("sound") then Core.SetFeature("sound", true) end
  if gate.feature then C.SetFeature(gate.feature, true) end
end

function C.FeatureLabel(key)
  local def = Feature(key)
  return def and def.label or ns.Locale:Get("highground.coach.enable_in_game.2b3569")
end

-- Shared target checks for every guide definition.
function C.Visible(frame) return frame and frame:IsVisible() and frame or nil end
function C.Clickable(button)
  return button and button.Click and button.IsEnabled and button:IsVisible() and button:IsEnabled() and button or nil
end
local Clickable = C.Clickable
-- Next can't choose from a menu, so a menu opener never stands in for a step's click.
local function Assist(target)
  local button = Clickable(target)
  return button and not button.opensMenu and button or nil
end

-- C.status: "idle" before any guide, "entering" while a step prepares, then
-- each update derives "missing" (target closed), "clipped" (scrolled out of
-- view), "waiting" (a required action is pending), "done" or "ready".
-- Stopping records "completed" after the last step, otherwise "aborted".
C.status = "idle"

function C.Stop()
  if C.router then C.router:Reset("stopped") end
  if C.running then C.status = C.finishing and "completed" or "aborted" end
  C.finishing = nil
  C.running, C.target, C.steps, C.key = nil, nil, nil, nil
  C.feature, C.sound = nil, nil
  C.entering, C.lastX, C.lastY, C.pendingAction = nil, nil, nil, nil
  if C.BountySample then C.BountySample.Stop() end
  if C.ReputationSample then C.ReputationSample.Stop() end
  ns.Hub.StopUsersSample()
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
    ns.Localization.Bind(C.win.hint, "highground.coach.done_use_next_when_you_re_ready.8b0590")
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
  local visible, hidden = C.Position(C.target, context)
  if step.complete then C.observed = step.complete() == true end
  if step.advance and not C.router._busy then
    local nextStep = step.advance()
    if nextStep == true then return C.Step(1) end
    if type(nextStep) == "string" then
      for i, candidate in ipairs(C.steps) do if candidate.id == nextStep and i ~= C.index then return C.Go(i) end end
    end
  end
  local waiting = step.requireAction and C.observed ~= true
  C.status = hidden or C.observed and "done" or waiting and "waiting" or "ready"
  local hint = Value(step.hint) or (C.observed and ns.Locale:Get("highground.coach.done_use_next_when_you_re_ready.8b0590")
    or "")
  if hidden == "clipped" then hint = ns.Locale:Get("guide.coach.clipped")
  elseif not visible then hint = Value(step.missing) or ns.Locale:Get("highground.coach.this_example_is_closed_use_replay_to.c72509") end
  if C.win.hint:GetText() ~= hint then C.win.hint:SetText(hint); C.Layout(); C.Position(C.target, context) end
  C.Observe(step.observe and step.observe() or C.target, step.event)
end

function C.Refresh()
  if not C.running or C.entering then return end
  local step, w = C.steps[C.index], C.win
  w.caption:SetText(ns.Locale:Format("guide.caption", { guide = O.Text(O.Current(), "caption") or O.Text(O.Current(), "label"), step = C.index, total = #C.steps }))
  w.title:SetText(Value(step.title)); w.body:SetText(Value(step.text))
  w.hint:SetText(Value(step.hint) or "")
  local feature, label = C.StepFeature(C.steps, C.index)
  -- A switch this client doesn't offer (Share observations on WoW Forever).
  if feature and Feature(feature) and not ns.OptionAvailable(Feature(feature)) then feature = nil end
  C.feature = feature
  if feature then
    w.enable.label:SetText(label or C.FeatureLabel(feature))
    w.enable:SetChecked(C.FeatureOn(feature), true)
    w.enable:SetEnabled(not InCombatLockdown() and (not ns.Modules or ns.Modules.FeatureEnabled(feature)))
  end
  C.sound = step.sound
  if C.RefreshSound then C.RefreshSound() end
  w.back:SetEnabled(true)
  w.next:SetText(C.index == #C.steps and ns.Locale:Get("highground.coach.done.e9b450") or ns.Locale:Get("highground.coach.next.bc9819"))
  C.Layout(); C.Update()
end

local function Enter(index, state)
  if not C.running or not C.steps[index] then return end
  C.entering, C.status = true, "entering"
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
    C.finishing = true
    O.Return()
  elseif index >= 1 then
    local history, cursor = C.router:History()
    local visit = history[cursor + delta]
    if visit and visit.name == C.steps[index].id then return C.router:Go(delta) end
    return C.Go(index)
  end
end

-- Next never waits on a hint the player didn't read: it clicks the step's
-- sample action, or moves on and the next step sets up its own sample. The
-- native button owns validation, side effects and hooks; the coach never
-- replaces its click handler.
function C.Continue()
  if not C.running or C.pendingAction then return end
  local step, router = C.steps[C.index], C.router
  local button = Value(step.action)
  if not Clickable(button) then return C.Step(1) end
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
  -- A step that asks for a click lets Next make it on the highlighted control.
  -- Only sample controls are required; real saves and sends stay optional.
  for _, step in ipairs(steps) do
    if step.requireAction and step.action == nil then
      local target = step.target
      step.action = function() return Assist(target and target()) end
    end
  end
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
    if C.running and C.win then C.win.hint:SetText(ns.Locale:Format("highground.coach.event_failure_message_use_guides_to_return.f760a7", { event_failure_message = event.failure.message })) end
  end)
  local current, index = O.State().samples[key], 1
  for i, step in ipairs(steps) do if step.id == current then index = i end end
  if O.dock then O.dock:Hide() end
  C.Go(index)
end

ns.Localization.Watch(C, C.Refresh)
