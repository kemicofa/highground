local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

-- Tracking preferences are feature choices: saved across sessions, and
-- preserved when resetting or loading scoring profiles.
if ns.Kits then
  local tracking = Options.MakePage("tracking")
  tracking.build = function()
    local kinds = { trinket = "Trinket", immune = "Immunity", def = "Defensive",
      external = "External defensive", burst = "Offensive", interrupt = "Interrupt",
      cc = "Crowd control", mobility = "Mobility", utility = "Utility" }
    local search = Kit.Input(tracking.frame, 160, "Search")
    search:SetPoint("TOPLEFT", S("xl"), -84)
    search:SetMaxLetters(80)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    local enable = Kit.Button(tracking.frame, "Track shown", 100, Z("control"))
    enable:SetPoint("LEFT", search, "RIGHT", S("lg"), 0)
    local disable = Kit.Button(tracking.frame, "Untrack shown", 100, Z("control"))
    disable:SetPoint("LEFT", enable, "RIGHT", S("md"), 0)

    local groups = {}
    tracking.trackingBoxes, tracking.search = {}, search
    local function AddGroup(class, entries)
      local name = class and ns.Util.ClassName(class) or "All classes"
      local group = { boxes = {}, header = Kit.Section(tracking.child, name) }
      groups[#groups + 1] = group
      local sorted = {}
      for _, entry in ipairs(entries or {}) do sorted[#sorted + 1] = entry end
      table.sort(sorted, function(a, b) return a[4] < b[4] end)
      for _, entry in ipairs(sorted) do
        local kind = kinds[entry[3]] or entry[3]
        local cb = Options.Toggle(tracking.child, entry[4], kind .. " · " .. Core.Clock(entry[2]), function(self, on)
          Core.db.disabledCooldowns = Core.db.disabledCooldowns or {}
          Core.db.disabledCooldowns[self.spellID] = not on or nil
          for _, e in pairs(Core.enemies) do ns.FilterCooldownState(e, Core.db) end
          tracking.RefreshTracking()
          Options.PointsChanged()
        end)
        cb.spellID = entry[1]
        cb.searchText = string.lower(name .. " " .. (class or "") .. " " .. entry[4]
          .. " " .. Core.SpellName(entry[1]) .. " " .. kind)
        group.boxes[#group.boxes + 1] = cb
        tracking.trackingBoxes[#tracking.trackingBoxes + 1] = cb
      end
    end
    AddGroup(nil, ns.KitCommon)
    local classes = {}
    for class in pairs(ns.Kits) do classes[#classes + 1] = class end
    ns.Util.SortClasses(classes)
    for _, class in ipairs(classes) do AddGroup(class, ns.Kits[class]) end

    local empty = Theme.Text(tracking.child, "bodyLarge", "textMuted")
    empty:SetPoint("TOPLEFT", S("xl"), -S("md"))
    empty:SetText("No matching cooldowns. Search by spell, class or type.")
    tracking.RefreshTracking = function()
      local query = ns.Util.Trim(search:GetText():lower())
      local y, count = -4, 0
      for _, group in ipairs(groups) do
        local shown = false
        for _, cb in ipairs(group.boxes) do
          cb.matches = cb.searchText:find(query, 1, true) ~= nil
          cb:SetShown(cb.matches)
          cb:SetChecked(ns.CooldownTracked(Core.db, cb.spellID), true)
          if cb.matches then
            if not shown then
              group.header:ClearAllPoints()
              group.header:SetPoint("TOPLEFT", S("xl"), y - S("md"))
              y, shown = y - 28, true
            end
            cb:ClearAllPoints()
            cb:SetPoint("TOPLEFT", S("xl"), y - S("xs"))
            y, count = y - 26, count + 1
          end
        end
        group.header:SetShown(shown)
        group.header.rule:SetShown(shown)
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
