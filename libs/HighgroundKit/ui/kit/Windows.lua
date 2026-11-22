local _, ns = ...
local Kit = ns.Kit

-- Shared across embedded kit copies. Every ordinary dialog is a route;
-- gameplay HUDs are not registered. The router owns nested return history.
local Windows = _G.HighgroundWindowCoordinator
if Windows then Kit.Windows = Windows; return end
Windows = { entries = {}, frames = {}, serial = 0, router = ns.Router.New({ limit = 100 }) }
_G.HighgroundWindowCoordinator = Windows
Kit.Windows = Windows

local function Root(frame)
  local root, parent = frame, frame:GetParent()
  while parent do
    if Windows.entries[parent] then root = parent end
    parent = parent.GetParent and parent:GetParent()
  end
  return root
end

local function Switching(run)
  local previous = Windows.switching
  Windows.switching = true
  local ok, err = pcall(run)
  Windows.switching = previous
  if not ok then error(err, 0) end
end

local function HideOthers(root)
  local changed = true
  while changed do
    changed = false
    for other in pairs(Windows.entries) do
      if other ~= root and Root(other) == other and other:IsVisible() then
        other:Hide(); changed = true
      end
    end
  end
end

local function Location(frame)
  return { name = Windows.entries[frame].route, params = { root = Windows.entries[Root(frame)].route } }
end

local function Present(to, _, action)
  local frame = Windows.frames[to.name]
  local root = Windows.frames[to.params.root] or frame
  if not frame or not root then return false, ns.Locale:Get("shared.windows.window_is_unavailable.fbe169") end
  Switching(function()
    local returning = action == "POP" or action == "REFRESH"
    local rootEntry, leafEntry = Windows.entries[root], Windows.entries[frame]
    if returning and not root:IsVisible() and rootEntry.resume then rootEntry.resume(root) else root:Show() end
    if frame ~= root and not frame:IsVisible() then
      if returning and leafEntry.resume then leafEntry.resume(frame) else frame:Show() end
    end
    -- Returning a borrowed page can reparent it during OnHide; recheck roots.
    HideOthers(root)
  end)
  Windows.active, Windows.activeRoot = frame, root
  return true
end

Windows.router:Register("closed", { enter = function()
  Switching(function() HideOthers(nil) end)
  Windows.active, Windows.activeRoot = nil, nil
end })

local function Activate(frame)
  if Windows.switching or not frame:IsVisible() then return end
  local root, entry, previous = Root(frame), Windows.entries[frame], Windows.active
  local target, router = Location(frame), Windows.router
  local ok, failure
  if root ~= frame then
    ok, failure = router:Replace(target) -- hosted pages occupy their owner's slot
  elseif entry.child and previous and Root(previous) ~= root then
    ok, failure = router:Navigate(target)
  elseif previous == frame then
    ok, failure = router:Navigate(target, { refresh = true })
  else
    ok, failure = router:Reset(target) -- a new primary tool abandons old editors
  end
  if not ok then
    if frame ~= previous then Switching(function() frame:Hide() end) end
    local current = router:Current()
    if previous and current then Present(current, nil, "REFRESH") end
  end
  return ok, failure
end

local function Closed(frame)
  if Windows.switching or frame:IsShown() then return end
  local active, root, router = Windows.active, Windows.activeRoot, Windows.router
  if not active or (active ~= frame and root ~= frame) then return end
  if active == frame and root ~= frame then
    local parent = frame:GetParent()
    while parent do
      if Windows.entries[parent] and parent:IsVisible() then return Activate(parent) end
      parent = parent.GetParent and parent:GetParent()
    end
  end
  local ok
  if Windows.entries[root].child and router:CanGo(-1) then
    Windows.restoring = true
    ok = router:Back()
    Windows.restoring = nil
    if ok then router:TrimForward() end
  else
    ok = router:Reset("closed")
  end
  if not ok then Present(router:Current(), nil, "REFRESH") end
end

function Windows.Register(frame, opts)
  if Windows.entries[frame] then return end
  opts = opts or {}
  Windows.serial = Windows.serial + 1
  local name = "window:" .. Windows.serial
  Windows.entries[frame] = { route = name, child = opts.child, resume = opts.onResume }
  Windows.frames[name] = frame
  Windows.router:Register(name, { enter = Present, beforeEnter = opts.beforeEnter, beforeLeave = opts.beforeLeave,
    meta = { label = opts.title or (frame.GetName and frame:GetName()) or name } })
  frame:HookScript("OnShow", Activate)
  frame:HookScript("OnHide", Closed)
end

function Windows.SetResume(frame, resume) Windows.entries[frame].resume = resume end

-- Legacy Show/Hide and Escape use the same routes as explicit window opens.
function Windows.Show(frame, prepare)
  local switching = Windows.switching
  Switching(function()
    if prepare then prepare() end
    local root = Root(frame)
    if root ~= frame then root:Show() end
    frame:Show()
  end)
  if not switching then return Activate(frame) end
end

-- Retiring a hidden editor removes it from the return history. Its review
-- then goes straight to the original owner, preserving that owner's draft.
function Windows.Close(frame)
  local entry = Windows.entries[frame]
  if entry and not frame:IsShown() then Windows.router:Forget(entry.route) end
  frame:Hide()
end

-- A ruleset/account change must discard return paths into the old data.
function Windows.Forget(frame)
  local entry, router = Windows.entries[frame], Windows.router
  if not entry then return end
  local current = router:Current()
  if current and (current.name == entry.route or current.params.root == entry.route) then
    return router:Reset("closed")
  end
  return router:Forget(entry.route)
end

function Windows.Active() return Windows.active end
