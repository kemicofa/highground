local _, ns = ...
local Core = ns.Core
ns.Options = {}
local Options = ns.Options

---------------------------------------------------------------------------
-- Options page: Options > AddOns > Warboard (also /wb config or the gear
-- in the panel header). Every point value + the per-component multipliers.
---------------------------------------------------------------------------

Options.panel = CreateFrame("Frame", "WarboardOptions")
Options.panel.name = "Warboard"
Options.panel:Hide()

function Options.Format(v)
  if math.floor(v) == v then
    return tostring(v)
  end
  return (string.format("%.2f", v):gsub("0+$", ""))
end

function Options.PointsChanged()
  if Core.active then
    Core.Tick()
  end
end

-- Main page (profiles, reset) + one sub-page per group, listed under
-- Warboard in the options sidebar. Rows of every page share Get/Set/Refresh.
Options.pages = {} -- { name, frame } registered as sub-categories
