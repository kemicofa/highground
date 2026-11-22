local _, ns = ...
local Core, Theme, Options = ns.Core, ns.Theme, ns.Options
local S = Theme.Space

-- Nearby and Bounties settings pages: the behavior options tagged
-- with the page's key.
local function Build(key)
  local page = Options.FeaturePage(key, key == "bounty" and "bounties" or "nearby")
  local toggles = {}
  local open = Options.ToolLink(page, key == "bounty" and "bountyboard" or "journal")
  if key == "bounty" then page.openBoard = open end
  for _, def in ipairs(ns.OptionsConfig.behavior) do
    if def.page == key and def.key ~= "nearbyRows" and def.key ~= "bountyAnnounce" and ns.OptionAvailable(def) then
      if def.type == "boolean" then
        local check = Options.Toggle(page.child, def.desc, nil, function(_, on)
          Options.Set({ kind = "option", key = def.key }, on)
        end)
        check:SetPoint("TOPLEFT", S("xl"), page.y - S("xs"))
        toggles[def.key] = check
        page.y = page.y - 28
      else
        Options.Row(page, { kind = "option", key = def.key, def = def.def, step = def.step,
          desc = def.desc, detail = "Unit: " .. def.unit })
      end
    end
  end
  page.RefreshBehavior = function()
    for k, check in pairs(toggles) do check:SetChecked(Core.O(k) and true or false, true) end
  end
  Options.AddAlertControls(page, key == "bounty" and "bounties" or "nearby")
  page.child:SetHeight(-page.y + 12)
end

Build("nearby")
Build("bounty")
