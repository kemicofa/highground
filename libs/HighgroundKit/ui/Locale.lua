local _, ns = ...
local Kit, Localization = ns.Kit, ns.Localization

-- A real preferences control and sample, shared with compatibility hosts.
function ns.CreateLocaleControl(parent, onChange)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(520, 180)
  local title = Kit.Paragraph(f, "heading")
  title:SetPoint("TOPLEFT"); title:SetPoint("RIGHT")
  Localization.Bind(title, "locale.title")
  local description = Kit.Paragraph(f, "body", "textMuted")
  description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8); description:SetPoint("RIGHT")
  Localization.Bind(description, "locale.description")
  f.select = Kit.Select(f, { choices = Localization.Choices(), width = 300, menu = true,
    onChange = function(_, key)
      Localization.SetPreference(key); f.Refresh()
      if onChange then onChange() end
    end })
  f.select:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -12)
  f.sample = Kit.Paragraph(f, "body")
  f.sample:SetPoint("TOPLEFT", f.select, "BOTTOMLEFT", 0, -12); f.sample:SetPoint("RIGHT")
  Localization.Bind(f.sample, "locale.sample")
  f.status = Kit.Paragraph(f, "body", "textMuted")
  f.status:SetPoint("TOPLEFT", f.sample, "BOTTOMLEFT", 0, -8); f.status:SetPoint("RIGHT")
  function f.Layout()
    local height = 48 + f.select:GetHeight()
    for _, text in ipairs({ title, description, f.sample, f.status }) do
      local h = text:GetStringHeight(); text:SetHeight(h); height = height + h
    end
    f:SetHeight(height)
  end
  function f.Refresh()
    f.select:SetChoices(Localization.Choices())
    f.select:SetValue(Localization.preference, true)
    f.status:SetText(Localization.Status())
    f.Layout()
  end
  f:SetScript("OnShow", f.Refresh)
  f:SetScript("OnSizeChanged", function() if not f.layingOut then f.layingOut = true; f.Layout(); f.layingOut = nil end end)
  ns.Core.OnFontScaleChange(function() if f:IsVisible() then f.Refresh() end end)
  f.Refresh()
  return f
end
