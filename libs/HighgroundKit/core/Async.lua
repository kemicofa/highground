local _, ns = ...

-- One logical operation, many attempts. Timer callbacks must retain the
-- attempt returned by Start, never just the data being retried. This module
-- owns no timers: callers decide when to finish, cancel or time out.
local Async = {}
Async.__index = Async
ns.Async = Async
local TERMINAL = { succeeded = true, failed = true, cancelled = true, unavailable = true }

function Async.New() return setmetatable({ state = "idle" }, Async) end

function Async:IsCurrent(attempt)
  return attempt ~= nil and self.current == attempt and attempt.state == "pending"
end

function Async:Finish(attempt, state, message)
  assert(TERMINAL[state], "Unknown async outcome: " .. tostring(state))
  if not self:IsCurrent(attempt) then return false end
  attempt.state, attempt.message = state, message
  self.current, self.state = nil, state
  return true
end

function Async:Cancel(message)
  if not self.current then return false end
  return self:Finish(self.current, "cancelled", message)
end

function Async:Start(value)
  self:Cancel()
  local attempt = { state = "pending", value = value }
  self.current, self.state = attempt, "pending"
  return attempt
end
