local _, ns = ...
local Core = ns.Core
local Options = ns.Options

-- Tracking preferences are feature choices: saved across sessions, and
-- preserved when resetting or loading scoring profiles.
if ns.Kits then
  local tracking = Options.MakePage("tracking")
  tracking.build = function()
    local kinds = { trinket = "Trinket", immune = "Immunity", def = "Defensive",
      external = "External defensive", burst = "Offensive", interrupt = "Interrupt",
      cc = "Crowd control", mobility = "Mobility" }
    local searchLabel = tracking.frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    searchLabel:SetPoint("TOPLEFT", 16, -82)
    searchLabel:SetText("Search")
    local search = CreateFrame("EditBox", nil, tracking.frame, "InputBoxTemplate")
    search:SetSize(160, 22)
    search:SetPoint("LEFT", searchLabel, "RIGHT", 12, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(80)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    local enable = CreateFrame("Button", nil, tracking.frame, "UIPanelButtonTemplate")
    enable:SetSize(100, 22)
    enable:SetPoint("LEFT", search, "RIGHT", 12, 0)
    enable:SetText("Track shown")
    local disable = CreateFrame("Button", nil, tracking.frame, "UIPanelButtonTemplate")
    disable:SetSize(100, 22)
    disable:SetPoint("LEFT", enable, "RIGHT", 8, 0)
    disable:SetText("Untrack shown")

    local groups = {}
    tracking.trackingBoxes, tracking.search = {}, search
    local function AddGroup(class, entries)
      local name = class and (LOCALIZED_CLASS_NAMES_MALE[class] or class) or "All classes"
      local group = { boxes = {}, header = tracking.child:CreateFontString(nil, "ARTWORK", "GameFontNormal") }
      group.header:SetText(name)
      groups[#groups + 1] = group
      local sorted = {}
      for _, entry in ipairs(entries or {}) do sorted[#sorted + 1] = entry end
      table.sort(sorted, function(a, b) return a[4] < b[4] end)
      for _, entry in ipairs(sorted) do
        local cb = CreateFrame("CheckButton", nil, tracking.child, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb.spellID = entry[1]
        cb.label = tracking.child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.label:SetPoint("RIGHT", -8, 0)
        cb.label:SetJustifyH("LEFT")
        cb.label:SetWordWrap(false)
        local kind = kinds[entry[3]] or entry[3]
        cb.label:SetText(entry[4] .. "  |cff888888" .. kind .. " · " .. Core.Clock(entry[2]) .. "|r")
        cb.searchText = string.lower(name .. " " .. (class or "") .. " " .. entry[4]
          .. " " .. Core.SpellName(entry[1]) .. " " .. kind)
        cb:SetScript("OnClick", function(self)
          Core.db.disabledCooldowns = Core.db.disabledCooldowns or {}
          Core.db.disabledCooldowns[self.spellID] = not self:GetChecked() or nil
          for _, e in pairs(Core.enemies) do ns.FilterCooldownState(e, Core.db) end
          tracking.RefreshTracking()
          Options.PointsChanged()
        end)
        group.boxes[#group.boxes + 1] = cb
        tracking.trackingBoxes[#tracking.trackingBoxes + 1] = cb
      end
    end
    AddGroup(nil, ns.KitCommon)
    local classes = {}
    for class in pairs(ns.Kits) do classes[#classes + 1] = class end
    table.sort(classes, function(a, b)
      return (LOCALIZED_CLASS_NAMES_MALE[a] or a) < (LOCALIZED_CLASS_NAMES_MALE[b] or b)
    end)
    for _, class in ipairs(classes) do AddGroup(class, ns.Kits[class]) end

    local empty = tracking.child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    empty:SetPoint("TOPLEFT", 16, -8)
    empty:SetText("No matching cooldowns. Search by spell, class or type.")
    tracking.RefreshTracking = function()
      local query = search:GetText():lower():match("^%s*(.-)%s*$")
      local y, count = -4, 0
      for _, group in ipairs(groups) do
        local shown = false
        for _, cb in ipairs(group.boxes) do
          cb.matches = cb.searchText:find(query, 1, true) ~= nil
          cb:SetShown(cb.matches)
          cb.label:SetShown(cb.matches)
          cb:SetChecked(ns.CooldownTracked(Core.db, cb.spellID))
          if cb.matches then
            if not shown then
              group.header:ClearAllPoints()
              group.header:SetPoint("TOPLEFT", 16, y - 6)
              y, shown = y - 28, true
            end
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", 16, y)
            y, count = y - 26, count + 1
          end
        end
        group.header:SetShown(shown)
      end
      empty:SetShown(count == 0)
      tracking.child:SetHeight(math.max(40, -y + 10))
    end
    local function SetShownTracked(on)
      Core.db.disabledCooldowns = Core.db.disabledCooldowns or {}
      for _, cb in ipairs(tracking.trackingBoxes) do
        if cb.matches then Core.db.disabledCooldowns[cb.spellID] = not on or nil end
      end
      for _, e in pairs(Core.enemies) do ns.FilterCooldownState(e, Core.db) end
      tracking.RefreshTracking()
      Options.PointsChanged()
    end
    enable:SetScript("OnClick", function() SetShownTracked(true) end)
    disable:SetScript("OnClick", function() SetShownTracked(false) end)
    search:SetScript("OnTextChanged", function()
      tracking.RefreshTracking()
      tracking.scroll:SetVerticalScroll(0)
    end)
    tracking.RefreshTracking()
  end
end
