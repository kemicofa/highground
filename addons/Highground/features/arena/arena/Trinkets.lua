local _, ns = ...
local A, U = ns.Arena, ns.Util
local call, plain = U.call, U.value

A.TRINKET_ICON = "Interface\\Icons\\INV_Jewelry_TrinketPVP_01"
A.asked = {}

local function Paint(r)
  r.trinket:SetDesaturated(not r.trinketKnown and not A.preview)
  r.trinketState:SetText(not A.preview and not r.trinketKnown and "?" or "")
  r.trinketState:SetShown(r.trinket:IsShown())
end

local function Spell(r, id)
  -- Raw (possibly restricted) icons go straight to the widget.
  local icon = call(ns.Api.Fn("C_Spell", "GetSpellTexture"), id)
  if type(icon) ~= "nil" then pcall(r.trinket.SetTexture, r.trinket, icon) end
end

function A.SetTrinketSpell(unit, spellID)
  unit = plain(unit)
  local i = type(unit) == "string" and tonumber(unit:match("^arena(%d)$"))
  local r = i and A.rows and A.rows[i]
  if r then Spell(r, spellID) end
end

function A.UpdateTrinket(r)
  local cd, pvp, unit = r.trinketCD, C_PvP, r.unit
  if A.preview then cd:Clear(); Paint(r); return end
  if not A.Enabled() or not A.InArena() or not U.read(UnitExists, unit) then return end
  r.trinketUnit = unit
  if A.asked[r.index] ~= unit and pvp and pvp.RequestCrowdControlSpell then
    A.asked[r.index] = unit
    call(pvp.RequestCrowdControlSpell, unit)
  end
  local id, start, length = call(pvp and pvp.GetArenaCrowdControlInfo, unit)
  local readable = plain(id)
  local hasSpell = type(id) ~= "nil" and (readable == nil or (type(readable) == "number" and readable > 0))
  if hasSpell then Spell(r, id) end
  -- An empty duration object can exist even with no trinket data. Require
  -- a spell response before treating it as a live timer.
  local duration = hasSpell and call(pvp and pvp.GetArenaCrowdControlDuration, unit)
  if duration and cd.SetCooldownFromDurationObject and pcall(cd.SetCooldownFromDurationObject, cd, duration, true) then
    r.trinketKnown = true
  else
    start, length = plain(start), plain(length)
    r.trinketKnown = hasSpell and type(start) == "number" and type(length) == "number" and length >= 0
    if r.trinketKnown and length > 0 then cd:SetCooldown(start / 1000, length / 1000)
    else cd:Clear() end
  end
  Paint(r)
end

-- Request data when the actual opponent becomes visible or changes unit
-- token. Native cooldown events update it thereafter; row ticks never
-- restart completed sweeps. Missing data stays explicitly unknown.
function A.RefreshTrinket(r, exists)
  if not exists then r.trinketUnit = nil
  elseif r.trinketUnit ~= r.unit then A.UpdateTrinket(r) end
  Paint(r)
end

function A.UpdateTrinkets()
  for i = 1, A.rows and (A.shownCount or 0) or 0 do A.UpdateTrinket(A.rows[i]) end
end
