local _, ns = ...
local Core, Theme, Kit, Options = ns.Core, ns.Theme, ns.Kit, ns.Options
local active, hooked

-- The shared Blizzard picker differs on older clients. Both paths apply live
-- changes, while Cancel restores the exact saved value (including Defaults).
function Options.PickSniperColor(layer, owner)
  local picker = ColorPickerFrame
  if not picker then return false end
  if active and picker:IsShown() then active.cancel() end
  picker:Hide()
  if hooked ~= picker then
    picker:HookScript("OnHide", function() active = nil end)
    hooked = picker
  end
  local def = Core.SNIPER_COLOR_LAYERS[layer]
  if not def then return false end
  local previous, color = Core.db[def.key] or "", Core.SniperLayerColor(layer, false)
  local session = { owner = owner }
  active = session
  local opening = true
  local function Apply()
    if opening or active ~= session then return end
    local r, g, b = picker:GetColorRGB()
    Core.SetSniperLayerColor(layer, Core.SniperHex({ r, g, b }))
  end
  function session.cancel()
    if active ~= session then return end
    active = nil
    Core.SetSniperLayerColor(layer, previous)
  end
  if picker.SetupColorPickerAndShow then
    picker:SetupColorPickerAndShow({ r = color[1], g = color[2], b = color[3], hasOpacity = false,
      swatchFunc = Apply, cancelFunc = session.cancel })
  else
    picker.func, picker.swatchFunc, picker.cancelFunc = Apply, Apply, session.cancel
    picker.opacityFunc, picker.hasOpacity = nil, false
    picker.previousValues = { r = color[1], g = color[2], b = color[3] }
    picker:SetColorRGB(color[1], color[2], color[3])
    picker:Show()
  end
  opening = false
  return true
end

function Options.SniperColorControls(page, controlX)
  local parent, rows = page.child, {}
  page.sniperColors = rows
  for _, layer in ipairs({ "ring", "skull", "aim" }) do
    local def = Core.SNIPER_COLOR_LAYERS[layer]
    local label = Theme.Text(parent, "bodyLarge")
    label:SetPoint("TOPLEFT", 24, page.y - Theme.Space("sm")); ns.Localization.BindField(label, def, "label")
    local button = Kit.Button(parent, "", 120, Theme.Size("control"))
    button:SetPoint("TOPLEFT", controlX, page.y)
    button.label:ClearAllPoints(); button.label:SetPoint("LEFT", 28, 0)
    local swatch = Theme.Fill(button, "OVERLAY", "white")
    swatch:SetSize(14, 14); swatch:SetPoint("LEFT", 8, 0)
    local reset = ns.Localization.Bind(Kit.Button(parent, ns.Locale:Get("highground.appearance.default.808d7d"), 70, Theme.Size("control")), "highground.appearance.default.808d7d")
    reset:SetPoint("LEFT", button, "RIGHT", 10, 0)
    button:SetScript("OnClick", function() Options.PickSniperColor(layer, button) end)
    reset:SetScript("OnClick", function() Core.SetSniperLayerColor(layer, "") end)
    button:HookScript("OnHide", function()
      if active and active.owner == button and ColorPickerFrame and ColorPickerFrame:IsShown() then
        active.cancel(); ColorPickerFrame:Hide()
      end
    end)
    Kit.Tooltip(button, function() return { def.label, ns.Locale:Get("highground.snipercolors.choose_any_colour_custom_colours_also_remain.d324d5") } end)
    rows[layer] = { button = button, reset = reset, swatch = swatch }
    page.y = page.y - 26
  end
  parent:SetHeight(-page.y + 10)
  function page.RefreshSniperColors()
    for layer, row in pairs(rows) do
      local def = Core.SNIPER_COLOR_LAYERS[layer]
      local color = Core.SniperLayerColor(layer, false)
      Theme.Paint(row.swatch, color)
      row.button:SetText("#" .. Core.SniperHex(color))
      local enabled = layer ~= "skull" or Core.db.sniperStyle ~= "legacy"
      row.button:SetEnabled(enabled)
      row.reset:SetEnabled(enabled and (Core.db[def.key] or "") ~= "")
    end
  end
end
