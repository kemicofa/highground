local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

-- Burst markers page: one mode per offensive cooldown that leaves a buff
-- (kit entries with a `mark` default). Saved in HighgroundDB.burstModes only
-- where it differs from the default.
if ns.Kits then
  local page = Options.MakePage("burst")
  local LABELS = ns.Localization.Define(ns.Localization.Define({ auto = ns.Locale:Get("highground.burstmarks.auto.c614ba"), purge = ns.Locale:Get("highground.burstmarks.purge_only.f37810"), cc = ns.Locale:Get("highground.coachtargeting.cc.c5a976"), off = ns.Locale:Get("highground.profileassignments.off.e3de5a") }, { auto = "highground.burstmarks.auto.c614ba", cc = "highground.coachtargeting.cc.c5a976", off = "highground.profileassignments.off.e3de5a" }), { purge = "highground.burstmarks.purge_only.f37810" })
  local CHOICES = {}
  for i, mode in ipairs(Core.BURST_MODES) do CHOICES[i] = { key = mode, label = LABELS[mode] } end
  page.build = function()
    local reset = ns.Localization.Bind(Kit.Button(page.frame, ns.Locale:Get("highground.burstmarks.reset_to_defaults.ddefe4"), 140, Z("control")), "highground.burstmarks.reset_to_defaults.ddefe4")
    reset:SetPoint("TOPLEFT", S("xl"), -82)

    local rows = {}
    local classes = {}
    for class in pairs(ns.Kits) do classes[#classes + 1] = class end
    ns.Util.SortClasses(classes)
    local y = -4
    for _, class in ipairs(classes) do
      local entries = {}
      for _, entry in ipairs(ns.Kits[class]) do
        if entry.mark then entries[#entries + 1] = entry end
      end
      table.sort(entries, function(a, b) return a[4] < b[4] end)
      if #entries > 0 then
        local header = Kit.Section(page.child, ns.Util.ClassName(class))
        header:SetPoint("TOPLEFT", S("xl"), y - S("md"))
        y = y - 28
        for _, entry in ipairs(entries) do
          -- Click for the next mode; default modes are not saved.
          local button = Kit.Select(page.child, { choices = CHOICES, width = 110, onChange = function(self, mode)
            Core.db.burstModes = Core.db.burstModes or {}
            Core.db.burstModes[self.entry[1]] = mode ~= self.entry.mark and mode or nil
            page.RefreshBurst()
          end })
          button:SetPoint("TOPLEFT", 20, y)
          button.entry = entry
          local label = Theme.Text(page.child, "bodyLarge")
          label:SetPoint("LEFT", button, "RIGHT", S("md") + S("xs"), 0)
          label:SetText(entry[4])
          local note = Theme.Text(page.child, "body", "textMuted")
          note:SetPoint("LEFT", label, "RIGHT", S("md"), 0)
          note:SetText(ns.Locale:Format("highground.burstmarks.default_value2.c23b63", { value2 = LABELS[entry.mark] }))
          rows[#rows + 1] = button
          y = y - (Z("control") + S("xs"))
        end
      end
    end
    page.child:SetHeight(math.max(40, -y + 10))
    page.burstButtons = rows
    page.RefreshBurst = function()
      for _, button in ipairs(rows) do button:SetValue(Core.BurstMode(button.entry), true) end
    end
    reset:SetScript("OnClick", function()
      Core.db.burstModes = nil
      page.RefreshBurst()
    end)
    page.RefreshBurst()
  end
end
