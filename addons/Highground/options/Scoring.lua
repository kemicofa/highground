local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

-- Explicit page keys keep client-specific groups from shifting pages.
Options.page, Options.pointPages = nil, {}
for _, def in ipairs(Core.POINTS) do
  if def.group then
    Options.page = ns.OptionAvailable(def) and Options.MakePage(def.page) or nil
    Options.pointPages[def.page] = Options.page
  elseif Options.page and ns.OptionAvailable(def) then
    Options.Row(Options.page, { kind = "point", key = def.key, def = def.def, step = def.step, desc = def.desc })
  end
end

local mult = Options.MakePage("multipliers")
for _, w in ipairs(Core.WEIGHTS) do
  if ns.OptionAvailable(w) then
    Options.Row(mult, { kind = "weight", key = w.key, def = 1, step = 0.1, desc = w.desc })
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
  for i, title in ipairs({ "Killability", "Impact" }) do
    local label = Kit.Caption(specs.child, title)
    label:SetPoint("TOPRIGHT", -S("md") - (2 - i) * 130, specs.y - S("sm"))
    label:SetWidth(108)
    label:SetJustifyH("CENTER")
  end
  specs.y = specs.y - 26
  local classes = {}
  for class in pairs(Core.classSpecs) do
    classes[#classes + 1] = class
  end
  table.sort(classes, function(a, b)
    return (LOCALIZED_CLASS_NAMES_MALE[a] or a) < (LOCALIZED_CLASS_NAMES_MALE[b] or b)
  end)
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
      name:SetText((si and si.name or specID) .. " " .. (LOCALIZED_CLASS_NAMES_MALE[class] or class))
      if c then Theme.Paint(name, { c.r, c.g, c.b }) end -- class colour, not a token
      local first = Options.SpecStepper(f, 130, { kind = "spec", specID = specID, stat = "k", def = base.k })
      name:SetPoint("RIGHT", first, "LEFT", -S("md"), 0)
      Options.SpecStepper(f, 0, { kind = "spec", specID = specID, stat = "i", def = base.i })
    end
  end
  specs.child:SetHeight(-specs.y + 10)
end
