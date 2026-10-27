local _, ns = ...
local Core = ns.Core
ns.Options = {}
local Options = ns.Options

---------------------------------------------------------------------------
-- Options page: Options > AddOns > Highground (also /wb config or the gear
-- in the panel header). Every point value + the per-component multipliers.
---------------------------------------------------------------------------

Options.panel = CreateFrame("Frame", "WarboardOptions")
Options.panel.name = "Highground"
Options.panel:Hide()
-- Pages are see-through on dark themes; a light theme fills them (alpha
-- token "page"), as Blizzard's settings panel behind them is dark.
function Options.PageFill(frame)
  ns.Theme.Fill(frame, "BACKGROUND", "bg", "page"):SetAllPoints()
end
Options.PageFill(Options.panel)

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
-- Highground in the options sidebar. Rows of every page share Get/Set/Refresh.
Options.pages = {} -- { name, frame } registered as sub-categories
