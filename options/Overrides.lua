local _, ns = ...
local Core = ns.Core
local Options = ns.Options

-- Optional spell overrides live beneath the general cooldown settings.
-- The shared trinket is already represented by its canonical point row.
if ns.Kits and Options.pointPages.cooldowns then
  local defs = Options.pointPages.cooldowns
  defs.build = function()
    local button = CreateFrame("Button", nil, defs.child, "UIPanelButtonTemplate")
    button:SetSize(230, 22)
    button:SetPoint("TOPLEFT", 16, defs.y - 8)
    defs.y = defs.y - 38
    local collapsedHeight = -defs.y + 10
    local body = CreateFrame("Frame", nil, defs.child)
    body:SetPoint("TOPLEFT", 0, defs.y)
    body:SetPoint("RIGHT", 0, 0)
    local overrides = { child = body, y = -4 }
    Options.Section(overrides, "Individual spell overrides", "Blank inherits the default above. Enter a value to override; clear it or use x to inherit again.")
    local kinds = { immune = "immuneDown", def = "defDown" }
    local classes = {}
    for class in pairs(ns.Kits) do classes[#classes + 1] = class end
    table.sort(classes, function(a, b)
      return (LOCALIZED_CLASS_NAMES_MALE[a] or a) < (LOCALIZED_CLASS_NAMES_MALE[b] or b)
    end)
    local customized = false
    for _, class in ipairs(classes) do
      local list = {}
      for _, entry in ipairs(ns.Kits[class]) do
        if kinds[entry[3]] and not ns.OptionsConfig.pointAliases["kit" .. entry[1]] then
          list[#list + 1] = entry
        end
      end
      table.sort(list, function(a, b)
        if (a.spec or 0) == (b.spec or 0) then return a[4] < b[4] end
        return (a.spec or 0) < (b.spec or 0)
      end)
      if #list > 0 then Options.Section(overrides, LOCALIZED_CLASS_NAMES_MALE[class] or class) end
      for _, entry in ipairs(list) do
        local eligible = {}
        for index, spec in ipairs(Core.classSpecs[class] or {}) do
          if not entry.spec or entry.spec == index then
            eligible[#eligible + 1] = Core.specInfo[spec] and Core.specInfo[spec].name or tostring(index)
          end
        end
        local key, kindKey = "kit" .. entry[1], kinds[entry[3]]
        customized = customized or (Core.db.points and Core.db.points[key] ~= nil)
        local specName = table.concat(eligible, ", ")
        local desc = entry[4]
        Options.Row(overrides, { kind = "kitspell", key = key, kindKey = kindKey, def = Core.P(kindKey), desc = desc,
          detail = Core.Clock(entry[2]) .. " cooldown; " .. specName })
      end
    end
    local expanded = customized and true or false
    local function Expand()
      local count = 0
      for _, row in ipairs(Options.rows) do
        if row.kind == "kitspell" and Core.db.points and Core.db.points[row.key] ~= nil then count = count + 1 end
      end
      body:SetShown(expanded)
      button:SetText((expanded and "Hide" or "Show") .. " spell overrides" .. (count > 0 and (" (" .. count .. ")") or ""))
      defs.child:SetHeight(collapsedHeight + (expanded and -overrides.y + 10 or 0))
    end
    defs.RefreshOverrides = Expand
    button:SetScript("OnClick", function() expanded = not expanded; Expand() end)
    Expand()
  end
end
