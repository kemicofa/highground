local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Docking (compact): main panel, flag carriers, resurrection, forecast, timers.
-- The first shown one sits at the main panel's saved position; each next one
-- hangs under the previous. The arena panel stays on its own. Without the
-- main panel (Highground Battlegrounds) the first window takes its place.
---------------------------------------------------------------------------
local PREFIX = ns.FRAME_PREFIX or "Highground"
Core.DOCK = { PREFIX .. "Frame", PREFIX .. "FlagsFrame", PREFIX .. "TimersFrame", PREFIX .. "ForecastFrame", PREFIX .. "BasesFrame" }

local function Protected(w)
  return w == Core.frame or w.secure
end

local function DockFrames()
  local list = {}
  for _, name in ipairs(Core.DOCK) do
    local w = _G[name]
    if w and w:IsShown() then list[#list + 1] = w end
  end
  return list
end

-- The frame that moves the column: the first shown one.
function Core.DockHead()
  if not Core.compact then return nil end
  return DockFrames()[1]
end
ns.DockHead = Core.DockHead

function Core.PlaceDockHead(w)
  local point = Core.pos and Core.pos.point
  w:ClearAllPoints()
  if point then
    w:SetPoint(point[1], UIParent, point[2], point[3], point[4])
  elseif not Core.compact and w == Core.frame then
    -- Keep the initial enemy list below the top-center objective panels,
    -- including at smaller UI resolutions. Explicit player positions win.
    w:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -320)
  else
    w:SetPoint("RIGHT", UIParent, "RIGHT", -260, 80)
  end
end

function Core.Dock()
  if Core.layoutModePending and not InCombatLockdown() then
    Core.ApplyLayout()
    return
  end
  if not Core.compact then return end
  local combat = InCombatLockdown()
  local prev
  for _, w in ipairs(DockFrames()) do
    local want = prev or "head"
    if w.dockedTo ~= want and not (combat and Protected(w)) then
      if prev then
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -Core.THEME.compact.dockGap)
      else
        Core.PlaceDockHead(w)
      end
      w.dockedTo = want
    end
    prev = w
  end
end
ns.Dock = Core.Dock

-- Leaving compact: every window back to its own saved spot.
function Core.Undock()
  if Core.compact then return end
  local T = ns.Timers
  for _, name in ipairs(Core.DOCK) do
    local w = _G[name]
    if w and w.dockedTo then
      w.dockedTo = nil
      if w == Core.frame then
        Core.PlaceDockHead(w)
      elseif T then
        T.PlaceWin(w)
      end
    end
  end
end

-- Dragging a docked window moves the whole column. A protected head can't
-- stop in combat: a drag released then ends, and is saved, after combat.
local moving, regen -- the head being dragged
local function StopColumn(head)
  if InCombatLockdown() and Protected(head) then
    if moving ~= head then return end
    if not regen then
      regen = CreateFrame("Frame")
      regen:SetScript("OnEvent", function(f)
        f:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if moving then ns.Util.RunGuarded("column drag", function() StopColumn(moving) end) end
      end)
    end
    regen:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  moving = nil
  head:StopMovingOrSizing()
  local p, _, rp, x, y = head:GetPoint()
  Core.pos.point = { p, rp, x, y }
end

function Core.DockDrag(w, start)
  local head = Core.DockHead()
  if not head then return false end
  if start then
    if not (Core.db.locked or (InCombatLockdown() and Protected(head))) then moving = head; head:StartMoving() end
  else
    StopColumn(moving or head)
  end
  return true
end
ns.DockDrag = Core.DockDrag
