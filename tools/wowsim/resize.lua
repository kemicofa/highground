---------------------------------------------------------------------------
-- Deferred resize events, as in the game. Opt-in: call from a configure
-- callback, before the TOC loads; installs geometry.lua when absent.
--
--   dofile("../../tools/wowsim/resize.lua")(sim)
--
-- After each 50 ms step:
-- * every visible frame with an OnSizeChanged script or hook whose
--   effective size (explicit, or from anchors and SetAllPoints) differs
--   from the size it last reported gets OnSizeChanged(width, height);
-- * every visible EditBox whose width changed during the step, even when a
--   later write restored it, or since the previous step, reflows its text
--   and gets OnTextChanged(false), as the live client does.
-- Handlers that resize again are answered on the next step, so a layout
-- cycle fires every step instead of hanging. sim.resizes counts both kinds
-- of event; sim.resizeLog, when set to a table, records
-- { frame, event, width, height, at } for each. sim.resizeKB is the heap
-- the measurements themselves allocated (subtract it from addon budgets).
---------------------------------------------------------------------------
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
return function(sim)
  if not sim.bounds then dofile(HERE .. "geometry.lua")(sim) end
  local env = sim.env
  local methods = getmetatable(env.UIParent).__index
  local tracked, sizes, boxes, widths, reflowed = {}, {}, {}, {}, {}
  sim.resizes, sim.resizeKB = 0, 0
  for _, name in ipairs({ "SetScript", "HookScript" }) do
    local original = methods[name]
    methods[name] = function(f, event, ...)
      original(f, event, ...)
      if event == "OnSizeChanged" and not sizes[f] then
        sizes[f] = { false, false }
        tracked[#tracked + 1] = f
      end
    end
  end
  local create = env.CreateFrame
  env.CreateFrame = function(kind, ...)
    local f = create(kind, ...)
    if f.kind == "EditBox" then boxes[#boxes + 1] = f end
    return f
  end
  -- A width written and restored within one step still reflowed the text
  -- of a box that has been laid out before.
  local setWidth, setSize = methods.SetWidth, methods.SetSize
  methods.SetWidth = function(f, value)
    if widths[f] and f.width ~= value then reflowed[f] = true end
    return setWidth(f, value)
  end
  methods.SetSize = function(f, w, h)
    if widths[f] and f.width ~= w then reflowed[f] = true end
    return setSize(f, w, h)
  end

  local function Near(a, b) return a and math.abs(a - b) < 0.001 end
  local queue, events, queueW, queueH = {}, {}, {}, {}
  local count
  local function Queue(f, event, w, h)
    count = count + 1
    queue[count], events[count], queueW[count], queueH[count] = f, event, w, h
  end
  local function Fire(f, event, ...)
    if f.scripts[event] then f.scripts[event](f, ...) end
    local hooks = f.hooks[event]
    if hooks then for _, callback in ipairs(hooks) do callback(f, ...) end end
  end
  sim.afterStep[#sim.afterStep + 1] = function()
    count = 0
    local heap = collectgarbage("count")
    -- Measure everything first, against the layout this step produced.
    sim.measureAll(function()
      for _, f in ipairs(tracked) do
        if f:IsVisible() then
          local w, h = f:GetWidth(), f:GetHeight()
          local last = sizes[f]
          if not (Near(last[1], w) and Near(last[2], h)) then
            last[1], last[2] = w, h
            Queue(f, "OnSizeChanged", w, h)
          end
        end
      end
      for _, f in ipairs(boxes) do
        if f:IsVisible() then
          local w = f:GetWidth()
          if reflowed[f] or widths[f] and not Near(widths[f], w) then Queue(f, "OnTextChanged", w, f:GetHeight()) end
          widths[f] = w
        end
      end
    end)
    sim.resizeKB = sim.resizeKB + math.max(0, collectgarbage("count") - heap)
    for f in pairs(reflowed) do reflowed[f] = nil end
    for i = 1, count do
      local f, event, w, h = queue[i], events[i], queueW[i], queueH[i]
      queue[i] = nil
      sim.resizes = sim.resizes + 1
      if sim.resizeLog then sim.resizeLog[#sim.resizeLog + 1] = { frame = f, event = event, width = w, height = h, at = sim.now } end
      if event == "OnSizeChanged" then Fire(f, event, w, h) else Fire(f, event, false) end
    end
  end
end
