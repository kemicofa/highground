local _, ns = ...
local Core, Theme = ns.Core, ns.Theme
local Motion = {}
ns.Motion = Motion

-- One driver, awake only while a transition is running. Each region owns
-- one transition; retargeting starts at its current value. Alpha never
-- changes geometry; Value also supports plain-frame accordion layouts.
-- Transition records are pooled, so repeated hover and focus changes
-- allocate nothing once the pool is warm.
local active, tick, settle, pool, driver = {}, {}, {}, {}, nil
local serial = 0

-- Named easings: a curve for the driver and the matching native smoothing
-- for animation groups. "out" (cubic, no overshoot) is the default.
local function Out(p) local q = 1 - p; return 1 - q * q * q end
local EASE = {
  out = Out,
  ["in"] = function(p) return p * p * p end,
  inOut = function(p) if p < 0.5 then return 4 * p * p * p end local q = 2 - 2 * p; return 1 - q * q * q / 2 end,
  linear = function(p) return p end,
}
local SMOOTHING = { out = "OUT", ["in"] = "IN", inOut = "IN_OUT", linear = "NONE" }
local function Ease(name)
  return EASE[name or "out"] or error("unknown easing: " .. tostring(name), 3)
end
function Motion.Smoothing(name)
  Ease(name)
  return SMOOTHING[name or "out"]
end

local function SettleAlpha(region, value)
  region:SetAlpha(value)
  -- Retain the actual native endpoint on its owner, without a global cache.
  region.wbMotionAlphaTarget, region.wbMotionAlphaValue = value, region:GetAlpha()
end

local function Reduced() return Core.db and Core.db.reducedMotion == true end

-- A motion token name, or seconds (0 for immediate updates).
function Motion.Duration(duration)
  if type(duration) == "string" then return Theme.Motion(duration) end
  return duration or Theme.Motion("hover")
end

-- Protected frames cannot change visibility, position or scale in combat.
-- Their transitions keep the current visibility and settle alpha instead.
local function Locked(region)
  if not (region.IsProtected and InCombatLockdown()) then return false end
  return region:IsProtected() and true or false
end
Motion.Locked = Locked

local function Idle()
  if driver and not next(active) then driver:SetScript("OnUpdate", nil); driver:Hide() end
end

-- A hide that combat turned into transparency. The protected frame stays
-- shown and keeps its mouse input until combat ends: Hide and EnableMouse
-- are both restricted. PLAYER_REGEN_ENABLED then hides each frame that is
-- still transparent and was not shown again, leaving it at its rest alpha.
-- Nothing listens while no hide is pending.
local deferred, regen = {}, nil
local function HideDeferred()
  if InCombatLockdown() then return end
  regen:UnregisterEvent("PLAYER_REGEN_ENABLED")
  local region, rest = next(deferred)
  while region do
    deferred[region] = nil
    if region:IsShown() and not active[region] and (region:GetAlpha() or 1) <= 0.000001 then
      SettleAlpha(region, rest); region:Hide()
    end
    region, rest = next(deferred)
  end
end

local function DeferHide(region, rest)
  if not region:IsShown() then return end
  deferred[region] = rest
  if not regen then
    regen = CreateFrame("Frame")
    regen:SetScript("OnEvent", function() ns.Util.RunGuarded("motion hide", HideDeferred) end)
  end
  regen:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function Recycle(state)
  state.apply, state.ease, state.hide, state.reveal = nil, nil, nil, nil
  pool[#pool + 1] = state
end
local function Release(region, state) active[region] = nil; Recycle(state) end

local function Finish(region, state)
  local apply, to, hide = state.apply, state.to, state.hide
  Release(region, state)
  if apply then apply(region, to) else SettleAlpha(region, to) end
  if hide then
    if Locked(region) then DeferHide(region, to) else region:Hide() end
  end
end

-- Layout and visibility callbacks can start or cancel other transitions.
-- Snapshot before invoking them so each starting state advances only once;
-- the serial skips a pooled record restarted during this frame.
local function Snapshot(into)
  local count = 0
  for region, state in pairs(active) do
    into[count + 1], into[count + 2], into[count + 3] = region, state, state.serial
    count = count + 3
  end
  return count
end

local function Update(_, elapsed)
  local count = Snapshot(tick)
  local reduced = Reduced()
  for i = 1, count, 3 do
    local region, state, id = tick[i], tick[i + 1], tick[i + 2]
    tick[i], tick[i + 1], tick[i + 2] = nil, nil, nil
    if active[region] == state and state.serial == id then
      state.elapsed = state.elapsed + elapsed
      local progress = state.elapsed / state.duration
      if progress >= 1 or reduced or not region:IsVisible() then
        Finish(region, state)
      else
        local value = state.from + (state.to - state.from) * state.ease(progress)
        if state.apply then state.apply(region, value) else region:SetAlpha(value) end
      end
    end
  end
  Idle()
end

-- Native one-shot cues (Flash, Pop, Slide) keep their groups on the region.
local function StopCues(region)
  local cues = region.wbMotion
  if cues then for _, cue in pairs(cues) do cue:Stop() end end
end

function Motion.IsPlaying(region) return active[region] ~= nil end

local function Cancel(region, alpha)
  if alpha and alpha > 0 then deferred[region] = nil end
  local state = active[region]
  if state then Release(region, state) end
  if alpha ~= nil then SettleAlpha(region, alpha) end
  Idle()
end

-- Cancel without invoking a stale completion. Optional alpha snaps to a
-- known state; otherwise the current visual value is preserved. One-shot
-- cues stop too; looping pulses keep their own handle.
function Motion.Stop(region, alpha)
  StopCues(region)
  Cancel(region, alpha)
end

-- Settle a transition at its requested endpoint, including its layout.
function Motion.Finish(region)
  if active[region] then Finish(region, active[region]) end
  StopCues(region)
  Idle()
end

local function Start(region, from, target, duration, apply, ease)
  duration = Motion.Duration(duration)
  local curve = Ease(ease)
  if Reduced() or duration <= 0 or not region:IsVisible() or from == target then
    Cancel(region)
    if apply then apply(region, target) else SettleAlpha(region, target) end
    return
  end
  local previous = active[region]
  if previous and previous.to == target and previous.apply == apply then previous.hide = nil; return end
  local state = table.remove(pool) or {}
  serial = serial + 1
  state.serial, state.from, state.to, state.elapsed, state.duration = serial, from, target, 0, duration
  state.apply, state.ease = apply, curve
  active[region] = state
  if previous then Recycle(previous) end
  if not driver then driver = CreateFrame("Frame", nil, UIParent) end
  driver:SetScript("OnUpdate", Update)
  driver:Show()
end

-- This primitive only changes alpha, never visibility or geometry. It is
-- safe on protected frames in combat.
function Motion.Alpha(region, alpha, duration, ease)
  if alpha > 0 then deferred[region] = nil end
  local current = region:GetAlpha() or 1
  -- A completed native write can round beyond floating-point epsilon. The
  -- unchanged requested/read-back pair is settled; external edits still retry.
  if not active[region] and region.wbMotionAlphaTarget == alpha and region.wbMotionAlphaValue == current then return end
  -- Native alpha may round the value we set. A visually settled endpoint
  -- must not start another transition on every reconciliation tick.
  if math.abs(current - alpha) < 0.000001 then current = alpha end
  Start(region, current, alpha, duration, nil, ease)
end

-- A scalar owned by a plain frame. apply(owner, value) updates its visual
-- state. Keep that callback stable when retargeting; never resize secure UI.
function Motion.Value(owner, from, target, duration, apply, ease)
  Start(owner, from, target, duration, apply, ease)
end

-- Fade a region in or out; fading out hides it at completion. Callers keep
-- action, selection and focus state synchronous with input. A protected
-- frame in combat keeps its visibility: it fades to transparent, still
-- receives clicks, and hides when combat ends unless shown again. A hidden
-- one stays hidden until the owner shows it out of combat.
function Motion.Show(region, on, duration)
  if on then
    if not region:IsShown() then
      if Locked(region) then return end
      region:SetAlpha(0); region:Show()
    end
    Motion.Alpha(region, 1, duration)
  else
    Motion.Alpha(region, 0, duration)
    local state = active[region]
    if state then state.hide = true
    elseif Locked(region) then DeferHide(region, 0)
    else region:Hide() end
  end
end
Motion.Fade = Motion.Show

-- Shallow entrances keep new content readable on the first frame. Nested
-- windows don't multiply fades, and repeated refreshes don't restart one.
function Motion.Reveal(region, duration, from)
  if Reduced() or not region:IsVisible() then Cancel(region, 1); return end
  if active[region] and active[region].reveal then return end
  local parent = region:GetParent()
  while parent do
    if active[parent] and active[parent].reveal then Cancel(region, 1); return end
    parent = parent:GetParent()
  end
  Cancel(region, from or Theme.Alpha("enter"))
  Motion.Alpha(region, 1, duration or "enter")
  if active[region] then active[region].reveal = true end
end

-- Semantic marks disappear immediately; entering marks start visible.
function Motion.Mark(region, on, immediate, duration)
  if Locked(region) then
    Cancel(region, on and 1 or 0)
    if not on then DeferHide(region, 1) end
    return
  end
  local shown = region:IsShown()
  if not on then Cancel(region, 1); region:Hide(); return end
  region:Show()
  if immediate then Cancel(region, 1)
  elseif not shown then Motion.Reveal(region, duration or "select", Theme.Alpha("markEnter")) end
end

-- Plain StatusBar progress: eases from the value currently drawn. Use it
-- for every update of that bar. Secret values are drawn directly.
local function Secret(value) return ns.Util ~= nil and ns.Util.secret(value) end
local function DrawProgress(bar, value) bar.wbProgress = value; bar:SetValue(value) end
function Motion.Progress(bar, value, duration)
  local from = bar.wbProgress
  if from == nil or Secret(value) then
    Cancel(bar)
    bar.wbProgress = not Secret(value) and value or nil
    bar:SetValue(value)
    return
  end
  Start(bar, from, value, duration or "progress", DrawProgress)
end

-- Changing the accessibility preference settles every in-flight state now.
-- Re-enabling motion never replays an old interaction.
function Motion.Refresh()
  if not Reduced() then return end
  local count = Snapshot(settle)
  for i = 1, count, 3 do
    local region, state, id = settle[i], settle[i + 1], settle[i + 2]
    settle[i], settle[i + 1], settle[i + 2] = nil, nil, nil
    if active[region] == state and state.serial == id then Finish(region, state) end
  end
  Idle()
end

---------------------------------------------------------------------------
-- Native cues: animation groups built once per region and kind, replayed
-- without Lua per-frame work and wrapped by Core.MotionGroup, so Reduced
-- motion shows the resting state. Motion.Stop(region) stops one-shot cues.
---------------------------------------------------------------------------
local function Cues(region)
  local cues = region.wbMotion
  if not cues then cues = {}; region.wbMotion = cues end
  return cues
end

-- A one-shot highlight on a region resting at alpha 0 (a changed rank, a
-- new row): it fades from peak to transparent. FlashCue builds or updates
-- the handle without playing it; Flash restarts it.
function Motion.FlashCue(region, peak, duration, ease)
  local cues = Cues(region)
  local cue = cues.flash
  if not cue then
    local group = region:CreateAnimationGroup()
    local fade = group:CreateAnimation("Alpha")
    fade:SetToAlpha(0)
    cue = Core.MotionGroup(group, region, 0)
    cue.fade, cues.flash = fade, cue
  end
  cue.fade:SetFromAlpha(peak or Theme.Alpha("flash"))
  cue.fade:SetDuration(Motion.Duration(duration or "flash"))
  cue.fade:SetSmoothing(Motion.Smoothing(ease or "in"))
  return cue
end

function Motion.Flash(region, peak, duration, ease)
  local cue = Motion.FlashCue(region, peak, duration, ease)
  cue:Stop(); cue:Play()
  return cue
end

-- A brief scale up and back for attention, about its centre. Protected
-- frames in combat skip it: scaling them is restricted.
function Motion.PopCue(region, scaleX, scaleY, duration)
  local cues = Cues(region)
  local cue = cues.pop
  if not cue then
    local group = region:CreateAnimationGroup()
    local grow, shrink = group:CreateAnimation("Scale"), group:CreateAnimation("Scale")
    grow:SetOrder(1); grow:SetSmoothing("OUT")
    shrink:SetOrder(2); shrink:SetSmoothing("IN")
    cue = Core.MotionGroup(group, region)
    cue.grow, cue.shrink, cues.pop = grow, shrink, cue
    local play = cue.Play
    function cue:Play() if not Locked(region) then return play(self) end end
  end
  scaleX = scaleX or 1.02
  scaleY = scaleY or scaleX
  local total = Motion.Duration(duration or "pop")
  cue.grow:SetScale(scaleX, scaleY); cue.grow:SetDuration(total * 0.4)
  cue.shrink:SetScale(1 / scaleX, 1 / scaleY); cue.shrink:SetDuration(total * 0.6)
  return cue
end

function Motion.Pop(region, scaleX, scaleY, duration)
  local cue = Motion.PopCue(region, scaleX, scaleY, duration)
  cue:Stop(); cue:Play()
  return cue
end

-- An entrance offset that settles at the region's own anchor; layout never
-- changes. Reduced motion, hidden regions and protected frames skip it.
function Motion.Slide(region, dx, dy, duration, ease)
  local cues = Cues(region)
  local cue = cues.slide
  if not cue then
    local group = region:CreateAnimationGroup()
    local jump, glide = group:CreateAnimation("Translation"), group:CreateAnimation("Translation")
    jump:SetDuration(0); jump:SetOrder(1); glide:SetOrder(2)
    cue = Core.MotionGroup(group, region)
    cue.jump, cue.glide, cues.slide = jump, glide, cue
  end
  cue:Stop()
  if Reduced() or not region:IsVisible() or region.IsProtected and region:IsProtected() then return cue end
  dx, dy = dx or 0, dy or 0
  cue.jump:SetOffset(dx, dy); cue.glide:SetOffset(-dx, -dy)
  cue.glide:SetDuration(Motion.Duration(duration or "slide"))
  cue.glide:SetSmoothing(Motion.Smoothing(ease))
  cue:Play()
  return cue
end

-- A looping alpha breath for urgent or featured light. duration is one
-- half-cycle. Reduced motion holds the from alpha. Owners stop the loop
-- when hidden; Motion.Stop leaves it alone.
function Motion.Pulse(region, from, to, duration)
  local group = region:CreateAnimationGroup()
  group:SetLooping("BOUNCE")
  local fade = group:CreateAnimation("Alpha")
  fade:SetFromAlpha(from); fade:SetToAlpha(to); fade:SetSmoothing("IN_OUT")
  fade:SetDuration(Motion.Duration(duration or "pulse"))
  local loop = Core.MotionGroup(group, region, from, true)
  loop.fade = fade
  return loop
end
