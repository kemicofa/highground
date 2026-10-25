local _, ns = ...
local Core = ns.Core
local Options = ns.Options

-- Burst markers page: one mode per offensive cooldown that leaves a buff
-- (kit entries with a `mark` default). Saved in WarboardDB.burstModes only
-- where it differs from the default.
if ns.Kits then
  local page = Options.MakePage("burst")
  local LABELS = { auto = "Auto", purge = "Purge only", cc = "CC", off = "Off" }
  page.build = function()
    local reset = CreateFrame("Button", nil, page.frame, "UIPanelButtonTemplate")
    reset:SetSize(140, 22)
    reset:SetPoint("TOPLEFT", 16, -82)
    reset:SetText("Reset to defaults")

    local rows = {}
    local classes = {}
    for class in pairs(ns.Kits) do classes[#classes + 1] = class end
    table.sort(classes, function(a, b)
      return (LOCALIZED_CLASS_NAMES_MALE[a] or a) < (LOCALIZED_CLASS_NAMES_MALE[b] or b)
    end)
    local y = -4
    for _, class in ipairs(classes) do
      local entries = {}
      for _, entry in ipairs(ns.Kits[class]) do
        if entry.mark then entries[#entries + 1] = entry end
      end
      table.sort(entries, function(a, b) return a[4] < b[4] end)
      if #entries > 0 then
        local header = page.child:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        header:SetPoint("TOPLEFT", 16, y - 6)
        header:SetText(LOCALIZED_CLASS_NAMES_MALE[class] or class)
        y = y - 28
        for _, entry in ipairs(entries) do
          local button = CreateFrame("Button", nil, page.child, "UIPanelButtonTemplate")
          button:SetSize(96, 20)
          button:SetPoint("TOPLEFT", 20, y)
          button.entry = entry
          local label = page.child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
          label:SetPoint("LEFT", button, "RIGHT", 10, 0)
          label:SetText(entry[4] .. "  |cff888888default " .. LABELS[entry.mark] .. "|r")
          button:SetScript("OnClick", function(self)
            local current, nextMode = Core.BurstMode(self.entry), nil
            for i, mode in ipairs(Core.BURST_MODES) do
              if mode == current then nextMode = Core.BURST_MODES[i % #Core.BURST_MODES + 1] end
            end
            Core.db.burstModes = Core.db.burstModes or {}
            Core.db.burstModes[self.entry[1]] = nextMode ~= self.entry.mark and nextMode or nil
            page.RefreshBurst()
          end)
          rows[#rows + 1] = button
          y = y - 24
        end
      end
    end
    page.child:SetHeight(math.max(40, -y + 10))
    page.burstButtons = rows
    page.RefreshBurst = function()
      for _, button in ipairs(rows) do button:SetText(LABELS[Core.BurstMode(button.entry)]) end
    end
    reset:SetScript("OnClick", function()
      Core.db.burstModes = nil
      page.RefreshBurst()
    end)
    page.RefreshBurst()
  end
end
