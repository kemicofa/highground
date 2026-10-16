local _, ns = ...
local Core = ns.Core

-- Out of combat only: bind rows to the current order, set their macros,
-- show/hide them and resize the panel.
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
      local name = e and Core.DisplayName(e.key)
      r:SetAttribute("macrotext1", name and ("/targetexact " .. name) or "")
      -- /focus takes a unit, not a name: target by exact name, focus that,
      -- then return to the previous target.
      Core.SetReturnMacro(r, "macrotext2", name and ("/targetexact " .. name .. "\n/focus"))
    end
    r:SetShown(e ~= nil)
  end
  Core.frame:SetHeight(Core.LIST_TOP + math.max(shown, 0) * (Core.ROW_H + Core.GAP) - (shown > 0 and Core.GAP or 0) + Core.FOOT_H)
end
