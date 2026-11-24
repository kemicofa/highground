-- Optional native-like anchor validation. Check at SetPoint time, not only
-- after layout: a temporary cycle already raises an error in the client.
return function(sim)
  local env = sim.env
  local methods = getmetatable(env.UIParent).__index
  local function relative(frame, value)
    if type(value) == "string" then return env[value] end
    return type(value) == "table" and value or frame.parent
  end
  local function depends(frame, target, visited)
    if frame == target then return true end
    if type(frame) ~= "table" or visited[frame] then return false end
    visited[frame] = true
    if frame.allPoints and depends(frame.allPoints, target, visited) then return true end
    -- The base simulator records calls; only the last value of each point
    -- is active, as in WoW and the geometry helper.
    local points = {}
    for i = #frame.points, 1, -1 do
      local point = frame.points[i]
      if not points[point[1]] then
        points[point[1]] = true
        if depends(relative(frame, point[2]), target, visited) then return true end
      end
    end
    return false
  end
  local function check(frame, other)
    if depends(other, frame, {}) then
      error("Cannot anchor to a region dependent on it: " .. (frame.name or frame.kind), 3)
    end
  end
  local setPoint, setAll = methods.SetPoint, methods.SetAllPoints
  methods.SetPoint = function(frame, point, other, ...)
    check(frame, relative(frame, other))
    return setPoint(frame, point, other, ...)
  end
  methods.SetAllPoints = function(frame, other)
    check(frame, relative(frame, other))
    return setAll(frame, other)
  end
end
