local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Board layout. Out of combat only: bind rows to the current order, set
-- their target/focus macros (Core.SetTargetFocus, ui/Hud.lua), show or
-- hide them and resize the panel.
---------------------------------------------------------------------------
function Core.SetRows(value)
  value = tonumber(value)
  if not value or value ~= value or math.abs(value) == math.huge then return false end
  Core.db.rows = math.max(1, math.min(Core.MAX_ROWS, math.floor(value)))
  Core.Layout()
  return true
end

function Core.Layout()
  if InCombatLockdown() then
    Core.layoutPending = true
    return
  end
  Core.layoutPending = false
  local shown = math.min(#Core.order, Core.db.rows, Core.MAX_ROWS)
  for i = 1, Core.MAX_ROWS do
    local r = Core.rows[i]
    local e = i <= shown and Core.order[i] or nil
    if r.entry ~= e or (e and r.boundName ~= e.key) then
      r.entry = e
      r.boundName = e and e.key
      Core.SetTargetFocus(r, e and Core.DisplayName(e.key), "")
    end
    r:SetShown(e ~= nil)
  end
  Core.frame:SetHeight(Core.LIST_TOP + math.max(shown, 0) * (Core.ROW_H + Core.GAP) - (shown > 0 and Core.GAP or 0) + Core.FOOT_H)
end
