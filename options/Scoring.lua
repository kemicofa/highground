local _, ns = ...
local Core = ns.Core
local Options = ns.Options

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
-- names are only known after login).
function Options.SpecStepper(f, offset, row)
  row.reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  row.reset:SetSize(18, 18)
  row.reset:SetPoint("RIGHT", -offset, 0)
  row.reset:SetText("x")
  local plus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  plus:SetSize(20, 18)
  plus:SetPoint("RIGHT", row.reset, "LEFT", -2, 0)
  plus:SetText("+")
  row.box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  row.box:SetSize(34, 18)
  row.box:SetPoint("RIGHT", plus, "LEFT", -6, 0)
  row.box:SetAutoFocus(false)
  row.box:SetJustifyH("CENTER")
  row.label = row.box
  local minus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  minus:SetSize(20, 18)
  minus:SetPoint("RIGHT", row.box, "LEFT", -8, 0)
  minus:SetText("-")
  Options.Wire(row, minus, plus, 1)
  return minus
end
local specs = Options.MakePage("specs")
specs.build = function()
  for i, title in ipairs({ "Killability", "Impact" }) do
    local label = specs.child:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPRIGHT", -8 - (2 - i) * 130, specs.y - 4)
    label:SetWidth(108)
    label:SetText(title)
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
      f:SetHeight(22)
      specs.y = specs.y - 24
      local name = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      name:SetPoint("LEFT", 8, 0)
      name:SetWordWrap(false)
      name:SetJustifyH("LEFT")
      name:SetText((si and si.name or specID) .. " " .. (LOCALIZED_CLASS_NAMES_MALE[class] or class))
      if c then
        name:SetTextColor(c.r, c.g, c.b)
      end
      local first = Options.SpecStepper(f, 130, { kind = "spec", specID = specID, stat = "k", def = base.k })
      name:SetPoint("RIGHT", first, "LEFT", -8, 0)
      Options.SpecStepper(f, 0, { kind = "spec", specID = specID, stat = "i", def = base.i })
    end
  end
  specs.child:SetHeight(-specs.y + 10)
end
