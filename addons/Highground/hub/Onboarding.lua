local _, ns = ...
local Core, Kit = ns.Core, ns.Kit
local O = { steps = {} }
ns.Onboarding = O

-- O.exploring names how the active guide runs, or nil when none does:
-- "page" opens a real settings page with the return dock; the others run
-- owned samples or walkthroughs that must stop before live combat.
O.SAMPLE_MODES = { preview = true, map = true, bounties = true, calls = true, native = true }

-- Progress is account-wide and separate from profiles. Upgrades keep the
-- old checklist marks without automatically opening the new guide.
function O.State()
  if type(Core.db.onboarding) ~= "table" then Core.db.onboarding = {} end
  local state = Core.db.onboarding
  if type(state.steps) ~= "table" then state.steps = {} end
  if type(state.samples) == "table" and state.samples.targeting and not state.samples.enemies then
    state.samples.enemies = state.samples.targeting
  end
  -- The old Battlegrounds chapter covered objectives only. Preserve that
  -- progress without completing the newly grouped targeting walkthrough.
  if not state.battlegroundPaths then
    if type(state.samples) == "table" then
      state.samples.objectives = state.samples.objectives or state.samples.battlegrounds
      state.samples.battlegrounds = nil
    end
    if state.steps.battlegrounds then state.steps.objectives = true; state.steps.battlegrounds = nil end
    if state.current == "battlegrounds" then state.current = "objectives" end
    state.battlegroundPaths = true
  end
  return state
end

function O.Find(key)
  key = O.aliases and O.aliases[key] or key
  if key == O.directory.key then return O.directory, 0 end
  for i, step in ipairs(O.steps) do if step.key == key then return step, i end end
end

function O.Current()
  local step, index = O.Find(O.State().current)
  return step or O.directory, index or 0
end

function O.Done(key)
  local step = O.Find(key)
  if step and step.paths then
    for _, child in ipairs(step.paths) do if not O.Done(child) then return false end end
    return true
  end
  return O.State().steps[step and step.key or key] == true
end

function O.Mark(key)
  local step = O.Find(key)
  if step then O.State().steps[step.key] = true end
end

-- A guide's progress for the chooser: "new", "started" (stopped before its
-- last step, so it can resume) or "completed".
function O.GuideStatus(key)
  local samples = O.State().samples
  local sample = type(samples) == "table" and samples[key] or nil
  if sample ~= nil and sample ~= "done" then return "started" end
  return O.Done(key) and "completed" or "new"
end

function O.Progress()
  local count = 0
  for _, step in ipairs(O.steps) do if O.Done(step.key) then count = count + 1 end end
  return count, #O.steps
end

-- handOff keeps the Highground window's visit for the walkthrough's return.
local function Hide(handOff)
  O.moving = true
  if handOff then ns.Hub.Suspend() end
  ns.Hub.Release(O.win)
  if O.win then O.win:Hide() end
  O.moving = nil
end

function O.StopExploring()
  local exploring = O.exploring
  local moving = O.moving
  O.moving = true -- Closing a guided Addons page must not dismiss its own tour recursively.
  O.active, O.exploring = nil, nil
  if O.dock then O.dock:Hide() end
  if O.Coach then
    O.Coach.Stop()
    if O.Coach.Examples then O.Coach.Examples.Stop() end
    if O.Coach.Map then O.Coach.Map.Stop() end
    if O.Coach.Native then O.Coach.Native.Stop() end
  end
  if exploring and ns.Setup.placement then ns.Setup.EndPlacement(false) end
  if exploring == "bounties" and ns.Bounty.Preview then ns.Bounty.Preview.Stop() end
  if exploring == "calls" then ns.QuickCalls.EndGuide() end
  O.moving = moving
end

function O.Dismiss()
  local state = O.State()
  state.dismissed, state.pending = true, nil
  O.StopExploring()
  -- Back to game also closes the Highground window that hiding the guide returns to.
  local hub = ns.Hub.win and ns.Hub.win:IsShown()
  Hide()
  if not hub and ns.Hub.win and ns.Hub.win:IsShown() then ns.Hub.win:Hide() end
  if ns.Hub.RefreshHome then ns.Hub.RefreshHome() end
end

function O.Finish()
  O.Mark(O.Current().key)
  O.State().completed = true
  O.Dismiss()
end

function O.GetRouter()
  if not O.router then
    O.router = ns.Router.New()
    for i = 0, #O.steps do
      local step = i == 0 and O.directory or O.steps[i]
      O.router:Register(step.key, {
        capture = function() return { scroll = O.win and O.win.scroll.offset or 0 } end,
        enter = function(to)
          local state = O.State()
          state.current, state.completed = to.name, nil
          if O.win then O.win:Refresh(); O.win.scroll:Scroll(to.state and to.state.scroll or 0) end
        end,
      })
    end
  end
  return O.router
end

function O.Go(key)
  local step = O.Find(key)
  if not step then return end
  return O.GetRouter():Navigate(step.key)
end

function O.Next()
  local step, index = O.Current()
  O.Mark(step.key)
  if index == #O.steps then return O.Finish() end
  O.Go(O.steps[index + 1].key)
end

function O.Back()
  local _, index = O.Current()
  if index > 1 then O.Go(O.steps[index - 1].key) end
end

-- Leaving a walkthrough returns to the Highground page that launched it,
-- else the guide. toGuide (the Guides button) always shows the guide.
function O.Return(toGuide)
  local origin = O.origin
  O.StopExploring()
  if O.inHub or toGuide and origin then ns.Hub.Open("addons")
  elseif origin then ns.Hub.Open(origin)
  else O.Open(); O.origin = nil end -- a page the guide opened is not where it started
end

function O.Visit(page)
  O.StopExploring()
  Hide(true)
  return ns.Hub.Open(page)
end

function O.Reviewed(key)
  O.Mark(key)
  if O.active == key then O.Return() end
end

function O.Explore(action)
  if not action then return end
  local modules = ns.Modules
  if modules then
    local owner = O.Current().module or action.feature and modules.featureOwners[action.feature]
      or (action.bounties and "bounties") or (action.map or action.quickCalls) and "battlegrounds"
      or action.tool and ns.Options.ToolOwner(action.tool) or action.page and ns.Hub.ModuleRoutes[action.page]
    if owner and not modules.Require(owner) then return end
  end
  if action.paths then return O.win:Refresh() end
  if action.preview or action.map or action.bounties or action.quickCalls or action.native then
    local allowed, problem = ns.Setup.CanArrange()
    if not allowed then O.win.status:SetText(problem); return end
    if action.feature and not Core.On(action.feature) then
      ns.Localization.Bind(O.win.status, "highground.onboarding.this_panel_is_off_check_enable_in.102b57"); return
    end
    if action.preview == "bg" and not (Core.On("killorder") or Core.On("timers")
      or Core.On("flags") or Core.On("quickCalls")) then
      ns.Localization.Bind(O.win.status, "highground.onboarding.battleground_panels_are_off_enable_a_panel.fb475b"); return
    end
  end
  if action.bounties and not (ns.Bounty and ns.Bounty.Preview and ns.Bounty.Preview.StartGuided) then
    ns.Localization.Bind(O.win.status, "highground.onboarding.the_bounty_tour_is_unavailable_open_bounties.b0fa39"); return
  end
  if ns.PreviewTests and ns.PreviewTests.managed then ns.PreviewTests.StopAll() end
  O.active = action.review or O.Current().key
  O.exploring = action.preview and "preview" or action.map and "map" or action.bounties and "bounties"
    or action.quickCalls and "calls" or action.native and "native" or "page"
  Hide(true)
  if O.exploring ~= "page" then ns.Hub.Suspend() end
  if action.preview then
    -- Placement owns cleanup, combat protection and lock restoration.
    ns.Setup.BeginPlacement(true)
    ns.Setup.PreviewContext(action.preview)
    ns.Setup.layoutBar.context:SetValue(action.preview, true)
    O.Coach.Start(O.Current().key, O.Coach.PanelSteps(action.preview, O.Current().key))
  elseif action.native then
    O.Coach.Start(action.native, O.Coach.Native.Start(action.native))
  elseif action.quickCalls then
    O.Coach.Start("callouts", O.Coach.CallSteps())
  elseif action.map then
    O.Coach.Start("map", O.Coach.MapSteps())
  elseif action.bounties then
    ns.Bounty.Preview.StartGuided(function() if O.exploring == "bounties" then O.Return() end end)
    O.Coach.Start(O.Current().key, O.Coach.BountySteps(action.bounties))
  elseif action.tool then
    ns.Options.OpenTool(action.tool)
  else
    ns.Hub.Open(action.page)
    if action.group then ns.Options.general.SelectGroup(action.group) end
  end
  if O.exploring == "page" then O.ShowDock() end
end

-- Preserve the existing setup/settings completion hooks.
function O.Start(key)
  local step = O.Find(key)
  if not step then return end
  O.Open(); O.Go(key)
  O.Explore(step.actions and step.actions[1])
end

function O.Open(embedded)
  -- The addon-controls walkthrough highlights this same directory. Mount
  -- its frame without stopping the coach that is opening it.
  if embedded and O.Coach.Native.changing and O.Coach.Native.active == "addons" then return O.Build() end
  O.StopExploring()
  local state = O.State()
  if state.completed then state.current = "welcome" end
  state.current = O.Current().key
  state.offered, state.pending, state.dismissed = true, nil, nil
  O.inHub = embedded == true
  local hub = not O.inHub and ns.Hub.win
  O.origin = hub and hub:IsShown() and ns.Hub.GetRouter():Current() or nil
  if ns.Setup.placement then ns.Setup.EndPlacement(false) end
  local w = O.Build()
  Kit.AttachNavigation(w, O.GetRouter())
  O.GetRouter():Navigate(state.current, { refresh = true })
  w:Refresh()
  if not embedded then Kit.Windows.Show(w, function() ns.Hub.Release(w) end) end
  return w
end

function O.TryOffer()
  local state = O.State()
  if not state.pending or state.offered or state.dismissed or state.completed then return end
  if InCombatLockdown() or IsInInstance() then return end
  local active = Kit.Windows.Active()
  if active and active:IsVisible() then return end
  O.Open()
end

local function ScheduleOffer() C_Timer.After(2, O.TryOffer) end

ns.Util.Events({
  PLAYER_LOGIN = function()
    local state = O.State()
    if state.version ~= 2 then
      state.version, state.pending = 2, nil
      if Core.firstInstall then state.current, state.pending = "welcome", true end
    end
    if Core.firstInstall and not state.offered then
      ns.Util.Say(ns.Locale:Get("highground.onboarding.welcome_addons_has_switches_settings_shortcuts_and.d95fb2"))
    end
    ScheduleOffer()
  end,
  PLAYER_ENTERING_WORLD = function()
    if IsInInstance() and (O.exploring or O.win and O.win:IsVisible()) then O.Dismiss() end
    ScheduleOffer()
  end,
  PLAYER_REGEN_ENABLED = function()
    if O.win and O.win:IsVisible() then O.win:Refresh() end
    ScheduleOffer()
  end,
  PLAYER_REGEN_DISABLED = function()
    -- Stop owned samples before live combat. Resuming is explicit.
    if O.SAMPLE_MODES[O.exploring] or O.win and O.win:IsVisible() then O.Dismiss() end
  end,
}, "first installation guide")

ns.Commands.guide = function(arg)
  if arg and O.Find(arg) then return O.Start(arg) end
  O.Open()
end
ns.Commands.checklist = ns.Commands.guide
