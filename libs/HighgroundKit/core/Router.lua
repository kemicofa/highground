local _, ns = ...

-- Named, in-memory routes for addon UI. No frames, timers or saved variables.
-- Load RouterNavigation.lua next. See Highground/docs/router.md for the API.
local Router = {}
Router.__index = Router
ns.Router = Router

local EVENTS = { before = true, redirect = true, change = true, cancel = true, error = true, history = true }

-- Locations contain data, never live frames or model objects. Copies isolate
-- history from callers and from callbacks; reject cycles and non-data values.
-- Apply the depth limit on input; history/event envelopes add trusted nesting.
local function Copy(value, seen, remaining)
  local kind = type(value)
  if kind == "nil" or kind == "string" or kind == "boolean" then return value end
  if kind == "number" and value == value and math.abs(value) < math.huge then return value end
  assert(kind == "table" and getmetatable(value) == nil, "Route data must contain only plain tables and scalar values")
  seen = seen or {}
  assert(not seen[value] and (remaining == nil or remaining > 0), "Route data is cyclic or too deeply nested")
  seen[value] = true
  local out = {}
  for key, item in pairs(value) do
    assert(type(key) == "string" or type(key) == "number", "Route data keys must be strings or numbers")
    out[Copy(key)] = Copy(item, seen, remaining and remaining - 1)
  end
  seen[value] = nil
  return out
end
Router._Copy = Copy

local function Equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not Equal(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
function Router._SameRoute(a, b)
  return a and b and a.name == b.name and Equal(a.params, b.params)
end
function Router._Same(a, b) return Router._SameRoute(a, b) and Equal(a.state, b.state) end

function Router._Failure(code, message) return { code = code, message = tostring(message or code) } end

local function Integer(value) return type(value) == "number" and value == math.floor(value) and math.abs(value) < math.huge end

function Router.New(opts)
  opts = opts or {}
  local limit, redirects = opts.limit or 50, opts.maxRedirects or 16
  assert(Integer(limit) and limit > 0, "History limit must be a positive integer")
  assert(Integer(redirects) and redirects > 0, "Redirect limit must be a positive integer")
  return setmetatable({ _routes = {}, _listeners = {}, _guards = {}, _entries = {}, _index = 0,
    _limit = limit, _maxRedirects = redirects }, Router)
end

function Router:Register(name, definition)
  assert(not self._busy, "Cannot register a route during navigation")
  assert(type(name) == "string" and name ~= "", "A route needs a non-empty name")
  assert(not self._routes[name], "Route already registered: " .. name)
  definition = definition or {}
  assert(type(definition) == "table", "Route definition must be a table")
  local route = { meta = Copy(definition.meta, nil, 23) }
  for _, key in ipairs({ "enter", "capture", "beforeEnter", "beforeLeave" }) do
    assert(definition[key] == nil or type(definition[key]) == "function", key .. " must be a function")
    route[key] = definition[key]
  end
  local redirect = definition.redirect
  assert(redirect == nil or type(redirect) == "string" or type(redirect) == "table" or type(redirect) == "function",
    "Redirect must be a route name, location or function")
  route.redirect = type(redirect) == "function" and redirect or Copy(redirect, nil, 24)
  self._routes[name] = route
  return self
end

function Router:Has(name) return type(name) == "string" and self._routes[name] ~= nil end

-- Resolve validates and copies a location without running redirects or guards.
function Router:Resolve(target)
  if type(target) == "string" then target = { name = target } end
  if type(target) ~= "table" or type(target.name) ~= "string" or target.name == "" then
    return nil, self._Failure("invalid_target", ns.Locale:Get("shared.router.expected_a_route_name_or_name_params.51d69d"))
  end
  local route = self._routes[target.name]
  if not route then return nil, self._Failure("unknown_route", ns.Locale:Format("shared.router.unknown_route_target_name.844bc2", { target_name = target.name })) end
  if target.params ~= nil and type(target.params) ~= "table" then
    return nil, self._Failure("invalid_target", ns.Locale:Get("shared.router.route_params_must_be_a_table.1790f0"))
  end
  local ok, location = pcall(Copy,
    { name = target.name, params = target.params or {}, state = target.state, meta = route.meta }, nil, 24)
  if not ok then return nil, self._Failure("invalid_target", location) end
  return location
end

local function Subscribe(list, callback)
  assert(type(callback) == "function", "Expected a callback")
  local entry = { callback = callback, active = true }
  list[#list + 1] = entry
  return function()
    if not entry.active then return end
    entry.active = false
    for i, item in ipairs(list) do if item == entry then table.remove(list, i); break end end
  end
end

-- Snapshot the subscription list, retaining active flags so removal during
-- dispatch takes effect immediately and additions wait for the next dispatch.
function Router._Subscribers(list)
  local out = {}
  for i, entry in ipairs(list or {}) do out[i] = entry end
  return out
end

function Router:On(event, callback)
  assert(EVENTS[event], "Unknown router event: " .. tostring(event))
  self._listeners[event] = self._listeners[event] or {}
  return Subscribe(self._listeners[event], callback)
end

function Router:BeforeEach(callback) return Subscribe(self._guards, callback) end

function Router:_Call(stage, callback, ...)
  if ns.Util and ns.Util.Guard then return ns.Util.Guard("router:" .. stage, callback, ...) end
  return pcall(callback, ...)
end

function Router:_Emit(event, data)
  for _, entry in ipairs(self._Subscribers(self._listeners[event])) do
    if entry.active then
      local ok, err = self:_Call(event, entry.callback, Copy(data))
      if not ok and event ~= "error" then
        self:_Emit("error", { to = data.to, from = data.from, action = data.action,
          stage = event, failure = self._Failure("callback_error", err) })
      end
    end
  end
end

function Router:Current() return Copy(self._entries[self._index]) end
function Router:History() return Copy(self._entries), self._index end

function Router:CanGo(delta)
  return Integer(delta) and delta ~= 0 and self._index + delta >= 1 and self._index + delta <= #self._entries
end

function Router:ClearHistory()
  if self._busy then return false, self._Failure("busy") end
  local current = self._entries[self._index]
  self._entries, self._index = current and { current } or {}, current and 1 or 0
  self._busy = true
  self:_Emit("history", { to = current, action = "CLEAR" })
  self._busy = nil
  return true
end

-- Retire an inactive destination's visits while keeping its registration.
-- Navigate away first; Unregister additionally removes the route itself.
function Router:Forget(name)
  if self._busy then return false, self._Failure("busy") end
  if not self:Has(name) then return false, self._Failure("unknown_route") end
  local current = self._entries[self._index]
  if current and current.name == name then return false, self._Failure("active_route") end
  for i = #self._entries, 1, -1 do
    if self._entries[i].name == name then
      table.remove(self._entries, i)
      if i < self._index then self._index = self._index - 1 end
    end
  end
  self._busy = true
  self:_Emit("history", { to = current, action = "REMOVE" })
  self._busy = nil
  return true
end

function Router:Unregister(name)
  local ok, failure = self:Forget(name)
  if ok then self._routes[name] = nil end
  return ok, failure
end

-- Closed dialogs must not reappear through Forward, while older parents
-- remain available for nested return paths.
function Router:TrimForward()
  if self._busy then return false, self._Failure("busy") end
  for i = #self._entries, self._index + 1, -1 do self._entries[i] = nil end
  self._busy = true
  self:_Emit("history", { to = self:Current(), action = "TRIM" })
  self._busy = nil
  return true
end
