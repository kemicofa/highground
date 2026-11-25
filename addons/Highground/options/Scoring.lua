local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

-- Explicit page keys keep client-specific groups from shifting pages.
Options.page, Options.pointPages = nil, {}
local function DeferRows(page, kind)
  local definitions = {}
  page.build = function()
    for _, def in ipairs(definitions) do
      Options.Row(page, { kind = kind, key = def.key, def = kind == "weight" and 1 or def.def,
        step = kind == "weight" and 0.1 or def.step, source = def, desc = def.desc })
    end
  end
  return definitions
end
local pending
for _, def in ipairs(Core.POINTS) do
  if def.group then
    Options.page = ns.OptionAvailable(def) and Options.MakePage(def.page) or nil
    Options.pointPages[def.page] = Options.page
    pending = Options.page and DeferRows(Options.page, "point")
  elseif Options.page and ns.OptionAvailable(def) then
    pending[#pending + 1] = def
  end
end

local mult = Options.MakePage("multipliers")
local weights = DeferRows(mult, "weight")
for _, w in ipairs(Core.WEIGHTS) do
  if ns.OptionAvailable(w) then
    weights[#weights + 1] = w
  end
end

-- Spec ratings: squishy + value side by side; built on first view (spec
-- names are only known after login). One stepper and its x (reset), from
-- `offset` px off the right edge; returns the stepper.
function Options.SpecStepper(f, offset, row)
  row.reset = Kit.Button(f, "x", Z("row"), Z("row"))
  row.reset:SetPoint("RIGHT", -offset, 0)
  local stepper = Options.Stepper(f, 34)
  stepper:SetPoint("RIGHT", row.reset, "LEFT", -S("xs"), 0)
  row.stepper, row.box = stepper, stepper.box
  row.label = row.box
  Options.Wire(row, stepper.minus, stepper.plus, 1)
  return stepper
end
local specs = Options.MakePage("specs")
specs.build = function()
  for i, key in ipairs({ "highground.profilesummary.killability.7d81d0", "highground.profilesummary.impact.62036a" }) do
    local label = ns.Localization.Bind(Kit.Caption(specs.child, ns.Locale:Get(key)), key)
    label:SetPoint("TOPRIGHT", -S("md") - (2 - i) * 130, specs.y - S("sm"))
    label:SetWidth(108)
    label:SetJustifyH("CENTER")
  end
  specs.y = specs.y - 26
  local classes = {}
  for class in pairs(Core.classSpecs) do
    classes[#classes + 1] = class
  end
  ns.Util.SortClasses(classes)
  for _, class in ipairs(classes) do
    local c = ns.Util.ClassColor(class)
    for _, specID in ipairs(Core.classSpecs[class]) do
      local si = Core.specInfo[specID]
      local base = Core.BaseProfile(specID)
      local f = CreateFrame("Frame", nil, specs.child)
      f:SetPoint("TOPLEFT", 8, specs.y)
      f:SetPoint("RIGHT", specs.child, "RIGHT", -8, 0)
      f:SetHeight(Z("control"))
      specs.y = specs.y - 24
      local name = Theme.Text(f, "bodyLarge")
      name:SetPoint("LEFT", S("md"), 0)
      name:SetWordWrap(false)
      name:SetJustifyH("LEFT")
      name:SetText((si and si.name or specID) .. " " .. ns.Util.ClassName(class))
      if c then Theme.PaintClass(name, c) end
      local first = Options.SpecStepper(f, 130, { page = specs, kind = "spec", specID = specID, stat = "k", def = base.k })
      name:SetPoint("RIGHT", first, "LEFT", -S("md"), 0)
      Options.SpecStepper(f, 0, { page = specs, kind = "spec", specID = specID, stat = "i", def = base.i })
    end
  end
  specs.child:SetHeight(-specs.y + 10)
end
