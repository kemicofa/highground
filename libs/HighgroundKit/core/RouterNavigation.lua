local _, ns = ...
local Router = ns.Router
local Copy, Same, Failure = Router._Copy, Router._Same, Router._Failure

function Router:_Fail(failure, to, from, action, stage)
  local event = { to = to, from = from, action = action, failure = failure, stage = stage }
  if failure.code == "callback_error" then self:_Emit("error", event) end
  self:_Emit("cancel", event)
  return false, failure
end

local function Call(router, stage, fn, to, from, action)
  local ok, result, reason = router:_Call(stage, fn, Copy(to), Copy(from), action)
  if not ok then return nil, Failure("callback_error", result) end
  if result == false then return nil, Failure("blocked", reason or (stage .. " cancelled navigation")) end
  if result == nil or result == true then return true end
  if type(result) == "string" or type(result) == "table" then return result end
  return nil, Failure("invalid_redirect", "Guards must return nil, true, false or a location")
end

function Router:_Guards(to, from, action)
  local previous = from and self._routes[from.name]
  local guards = self._Subscribers(self._guards)
  if previous and previous.beforeLeave and not Same(to, from) then
    table.insert(guards, 1, { active = true, callback = previous.beforeLeave })
  end
  local route = self._routes[to.name]
  if route.beforeEnter then guards[#guards + 1] = { active = true, callback = route.beforeEnter } end
  for _, entry in ipairs(guards) do
    if entry.active then
      local result, failure = Call(self, "guard", entry.callback, to, from, action)
      if result ~= true then return result, failure end
    end
  end
  return true
end

function Router:_Commit(to, action, index)
  if action == "RESET" then self._entries, self._index = {}, 0 end
  local entries = self._entries
  if action == "POP" then
    self._index = index
  elseif action == "PUSH" then
    for i = #entries, self._index + 1, -1 do entries[i] = nil end
    self._index = self._index + 1
  elseif self._index == 0 then
    self._index = 1
  end
  -- A redirect during Back/Forward replaces the destination slot; it never
  -- adds an intermediate route or moves the cursor before guards accept it.
  entries[self._index] = Copy(to)
  while #entries > self._limit do table.remove(entries, 1); self._index = self._index - 1 end
end

function Router:_Transition(target, action, index, refresh)
  local from, visited, redirects = self:Current(), {}, 0
  while true do
    local to, failure = self:Resolve(target)
    if not to then return self:_Fail(failure, nil, from, action, "resolve") end
    -- Selecting the active destination without state keeps its captured UI.
    -- Explicit state, history traversal and reset still own their snapshots.
    if action ~= "POP" and action ~= "RESET" and to.state == nil and self._SameRoute(to, from) then
      to.state = Copy(from.state)
    end
    for _, location in ipairs(visited) do
      if Same(location, to) then return self:_Fail(Failure("redirect_loop"), to, from, action, "redirect") end
    end
    if redirects > self._maxRedirects then
      return self:_Fail(Failure("redirect_limit"), to, from, action, "redirect")
    end
    visited[#visited + 1] = to
    local route, nextTarget = self._routes[to.name]
    if route.redirect == nil and action ~= "POP" and action ~= "RESET" and Same(to, from) then
      if not refresh and action ~= "REFRESH" then return true, Copy(from) end
      action = "REFRESH"
    end
    self:_Emit("before", { to = to, from = from, action = action })
    if route.redirect ~= nil then
      nextTarget = route.redirect
      if type(nextTarget) == "function" then
        nextTarget, failure = Call(self, "redirect", nextTarget, to, from, action)
        if failure then return self:_Fail(failure, to, from, action, "redirect") end
      end
      if type(nextTarget) ~= "string" and type(nextTarget) ~= "table" then
        return self:_Fail(Failure("invalid_redirect", "A redirect must return a location"), to, from, action, "redirect")
      end
    else
      local result
      result, failure = self:_Guards(to, from, action)
      if failure then return self:_Fail(failure, to, from, action, "guard") end
      if result ~= true then nextTarget = result end
    end
    if nextTarget then
      -- Validate before broadcasting: event payloads contain only route data.
      local resolved
      resolved, failure = self:Resolve(nextTarget)
      if not resolved then return self:_Fail(failure, to, from, action, "redirect") end
      self:_Emit("redirect", { to = resolved, from = from, redirectedFrom = to, action = action })
      target, redirects = resolved, redirects + 1
    else
      if route.enter then
        local ok, accepted, reason = self:_Call("enter", route.enter, Copy(to), Copy(from), action)
        if not ok then return self:_Fail(Failure("callback_error", accepted), to, from, action, "enter") end
        if accepted == false then return self:_Fail(Failure("blocked", reason), to, from, action, "enter") end
      end
      self:_Commit(to, action, index)
      local event = { to = to, from = from, action = action }
      self:_Emit("change", event)
      self:_Emit("history", event)
      return true, Copy(to)
    end
  end
end

function Router:_Navigate(target, action, index, refresh, restoreState)
  -- Navigation is synchronous. Guards redirect by returning a location;
  -- nested navigation from a callback cannot interleave history commits.
  if self._busy then return false, Failure("busy", "Navigation is already in progress") end
  self._busy = true
  local ok, accepted, result = pcall(function()
    local from = self:Current()
    -- Explicit state may match an older snapshot even though live UI differs.
    -- Capture the departure without replacing an intentional restoration.
    local resume = action == "REFRESH" or not restoreState and action ~= "POP" and action ~= "RESET" and Same(self:Resolve(target), from)
    local route = from and self._routes[from.name]
    if route and route.capture then
      local captured, state = self:_Call("capture", route.capture, Copy(from))
      if not captured then return self:_Fail(Failure("callback_error", state), nil, from, action, "capture") end
      local saved, failure = self:Resolve({ name = from.name, params = from.params, state = state })
      if not saved then return self:_Fail(failure, nil, from, action, "capture") end
      self._entries[self._index] = saved
      if resume then target = Copy(saved) end
    end
    return self:_Transition(target, action, index, refresh)
  end)
  if not ok then accepted, result = self:_Fail(Failure("callback_error", accepted), nil, self:Current(), action, "navigation") end
  self._busy = nil
  return accepted, result
end

function Router:Navigate(target, opts)
  opts = opts or {}
  return self:_Navigate(target, opts.replace and "REPLACE" or "PUSH", nil, opts.refresh, opts.restoreState)
end
Router.Push = Router.Navigate

function Router:Replace(target) return self:_Navigate(target, "REPLACE") end
Router.Redirect = Router.Replace
function Router:Reset(target) return self:_Navigate(target, "RESET") end

function Router:Go(delta)
  if self._busy then return false, Failure("busy") end
  if not self:CanGo(delta) then return false, Failure("history_boundary", "No history entry at that offset") end
  local index = self._index + delta
  return self:_Navigate(self._entries[index], "POP", index)
end
function Router:Back() return self:Go(-1) end
function Router:Forward() return self:Go(1) end

function Router:Refresh()
  if self._busy then return false, Failure("busy") end
  if self._index == 0 then return false, Failure("history_boundary", "No current route to refresh") end
  return self:_Navigate(self._entries[self._index], "REFRESH")
end
