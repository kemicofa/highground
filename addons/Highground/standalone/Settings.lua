local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local S = Theme.Space

---------------------------------------------------------------------------
-- A standalone addon's settings page, built from the same catalog as
-- Highground's (config/Options.lua): feature switches become toggles,
-- behavior settings toggles or number steppers. Registered under the
-- addon's title in Blizzard's settings; /<command> config opens it.
--   Settings.Page({ hint = text, keys = { "nearby", "nearbyRows", ... },
--     buttons = { { label, onClick }, ... } })
---------------------------------------------------------------------------
local Settings_ = {}
ns.StandaloneSettings = Settings_

local DEFS = {}
for _, def in ipairs(ns.OptionsConfig.features) do if def.key then DEFS[def.key] = def end end
for _, def in ipairs(ns.OptionsConfig.behavior) do DEFS[def.key] = DEFS[def.key] or def end

local function Toggle(parent, def)
  local t = Kit.Toggle(parent, def.label or def.desc, { desc = def.label and def.desc or nil, width = 520,
    onChange = function(_, on) Core.SetFeature(def.key, on) end })
  function t.Refresh() t:SetChecked(def.type == "boolean" and Core.O(def.key) or Core.On(def.key), true) end
  return t
end

local function Stepper(parent, def)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(520, Theme.Size("control"))
  row.stepper = Kit.Stepper(row, { min = def.min, max = def.max, step = def.step or (def.integer and 1 or nil),
    width = 120, onChange = function(_, v) Core.SetOption(def.key, v) end })
  row.stepper:SetPoint("LEFT")
  row.label = Theme.Text(row, "control")
  row.label:SetPoint("LEFT", row.stepper, "RIGHT", S("md"), 0)
  row.label:SetPoint("RIGHT")
  row.label:SetJustifyH("LEFT")
  row.label:SetText(def.desc .. (def.unit and (" (" .. def.unit .. ")") or ""))
  function row.Refresh() row.stepper:SetValue(Core.O(def.key), true) end
  return row
end

-- Build the page and register it. Returns the page frame.
function Settings_.Page(opts)
  local f = CreateFrame("Frame")
  f:Hide()
  f.name = ns.LABEL
  Theme.Fill(f, "BACKGROUND", "bg"):SetAllPoints()
  local title = Theme.Text(f, "title")
  title:SetPoint("TOPLEFT", S("xl"), -S("xl"))
  title:SetText(ns.LABEL)
  local hint = Theme.Text(f, "body", "textMuted")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -S("sm"))
  hint:SetPoint("RIGHT", -S("xl"), 0)
  hint:SetJustifyH("LEFT")
  hint:SetText(opts.hint or "")
  f.rows = {}
  local top = 78 -- below the title and hint
  local function Place(region, indent, gap)
    top = top + gap
    region:SetPoint("TOPLEFT", f, "TOPLEFT", S("xl") + indent, -top)
    top = top + region:GetHeight()
  end
  for _, key in ipairs(opts.keys) do
    local def = DEFS[key]
    if def and ns.OptionAvailable(def) then
      local row = (def.type == "boolean" or not def.min) and Toggle(f, def) or Stepper(f, def)
      Place(row, def.parent and S("xl") or 0, S("md"))
      f.rows[#f.rows + 1] = row
    end
  end
  for _, b in ipairs(opts.buttons or {}) do
    Place(Kit.Button(f, b[1], 180, nil, { onClick = b[2] }), 0, S("lg"))
  end
  function f.Refresh() for _, row in ipairs(f.rows) do row.Refresh() end end
  f:SetScript("OnShow", f.Refresh)
  Settings_.frame = f
  if Settings and Settings.RegisterCanvasLayoutCategory then
    Settings_.category = Settings.RegisterCanvasLayoutCategory(f, ns.LABEL)
    Settings.RegisterAddOnCategory(Settings_.category)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(f)
  end
  return f
end

function Settings_.Open()
  if Settings_.category and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(Settings_.category:GetID())
  elseif InterfaceOptionsFrame_OpenToCategory and Settings_.frame then
    InterfaceOptionsFrame_OpenToCategory(Settings_.frame)
    InterfaceOptionsFrame_OpenToCategory(Settings_.frame)
  end
end

function Settings_.Refresh()
  if Settings_.frame and Settings_.frame:IsShown() then Settings_.frame.Refresh() end
end
