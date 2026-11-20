local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

-- Optional spell overrides live beneath the general cooldown settings.
-- The shared trinket is already represented by its canonical point row.
if ns.Kits and Options.pointPages.cooldowns then
  local defs = Options.pointPages.cooldowns
  local buildRows = defs.build
  defs.build = function()
    if buildRows then buildRows() end
    local button = Kit.Button(defs.child, "", 230, Z("control"))
    button:SetPoint("TOPLEFT", S("xl"), defs.y - S("md"))
    defs.y = defs.y - 38
    local collapsedHeight = -defs.y + 10
    local body = CreateFrame("Frame", nil, defs.child)
    body:SetPoint("TOPLEFT", 0, defs.y)
    body:SetPoint("RIGHT", 0, 0)
    local overrides = { child = body, y = -4, owner = defs }
    local kinds = { immune = "immuneDown", def = "defDown" }
    local classes, keys = {}, {}
    for class, entries in pairs(ns.Kits) do
      classes[#classes + 1] = class
      for _, entry in ipairs(entries) do
        local key = "kit" .. entry[1]
        if kinds[entry[3]] and not ns.OptionsConfig.pointAliases[key] then keys[key] = true end
      end
    end
    ns.Util.SortClasses(classes)
    local function Count()
      local count = 0
      for key in pairs(keys) do if Core.db.points and Core.db.points[key] ~= nil then count = count + 1 end end
      return count
    end
    local built
    local function BuildOverrides()
      if built then return end
      built = true
      Options.Section(overrides, "Individual spell overrides", "Blank inherits the default above. Enter a value to override; clear it or use x to inherit again.")
      for _, class in ipairs(classes) do
        local list = {}
        for _, entry in ipairs(ns.Kits[class]) do
          if kinds[entry[3]] and keys["kit" .. entry[1]] then list[#list + 1] = entry end
        end
        table.sort(list, function(a, b)
          if (a.spec or 0) == (b.spec or 0) then return a[4] < b[4] end
          return (a.spec or 0) < (b.spec or 0)
        end)
        if #list > 0 then Options.Section(overrides, ns.Util.ClassName(class)) end
        for _, entry in ipairs(list) do
          local eligible = {}
          for index, spec in ipairs(Core.classSpecs[class] or {}) do
            if not entry.spec or entry.spec == index then
              eligible[#eligible + 1] = Core.specInfo[spec] and Core.specInfo[spec].name or tostring(index)
            end
          end
          local key, kindKey = "kit" .. entry[1], kinds[entry[3]]
          Options.Row(overrides, { kind = "kitspell", key = key, kindKey = kindKey, def = Core.P(kindKey), desc = entry[4],
            detail = Core.Clock(entry[2]) .. " cooldown; " .. table.concat(eligible, ", ") })
        end
      end
    end
    local expanded = Count() > 0
    local function Expand()
      local count = Count()
      if expanded then BuildOverrides() end
      body:SetShown(expanded)
      button:SetText((expanded and "Hide" or "Show") .. " spell overrides" .. (count > 0 and (" (" .. count .. ")") or ""))
      defs.child:SetHeight(collapsedHeight + (expanded and -overrides.y + 10 or 0))
    end
    defs.RefreshOverrides = Expand
    button:SetScript("OnClick", function() expanded = not expanded; Expand(); Options.RefreshPage(defs) end)
    Expand()
  end
end
