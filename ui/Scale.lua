local _, ns = ...
local Core = ns.Core

-- One saved scale for every HUD panel. Protected panels only resize out of
-- combat; the latest requested scale is applied on PLAYER_REGEN_ENABLED.
function ns.InitializeUIScale()
  if not Core.db.uiScaleVersion then
    if Core.db.scale == 1 then Core.db.scale = Core.THEME.scale.default end
    Core.db.uiScaleVersion = 1
  end
end

function ns.ApplyUIScale()
  if not Core.db then return false end
  local applied = not InCombatLockdown()
  if applied then
    Core.frame:SetScale(Core.db.scale)
    if ns.TimersApplyScale then ns.TimersApplyScale() end
  end
  if ns.RefreshUIScaleOption then ns.RefreshUIScaleOption() end
  return applied
end

function ns.SetUIScale(value)
  value = tonumber(value)
  if not Core.db or not value or value ~= value or math.abs(value) == math.huge then return false end
  Core.db.scale = math.max(Core.THEME.scale.min, math.min(Core.THEME.scale.max, value))
  return ns.ApplyUIScale()
end

function Core.BuildCurve()
  if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then
    return
  end
  Core.execCurve = C_CurveUtil.CreateColorCurve()
  Core.execCurve:SetType(Enum.LuaCurveType.Step)
  Core.execCurve:AddPoint(0, CreateColor(1, 0, 0, 1))
  Core.execCurve:AddPoint(Core.db.executePct, CreateColor(1, 0, 0, 0))
end
