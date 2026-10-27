local _, ns = ...
local Core, Theme, Kit, Options = ns.Core, ns.Theme, ns.Kit, ns.Options
local S, Z = Theme.Space, Theme.Size

-- Nearby enemies and Guild bounties pages: the behavior options tagged
-- with the page's key.
local function Build(key)
  local page = Options.MakePage(key)
  local toggles = {}
  if key == "bounty" then
    local open = Kit.Button(page.child, "Open bounty board", 180, Z("input"), { tone = "gold" })
    open:SetPoint("TOPLEFT", S("xl"), page.y)
    open:SetScript("OnClick", function() ns.Bounty.Board.Open() end)
    page.openBoard = open
    page.y = page.y - 34
  end
  for _, def in ipairs(ns.OptionsConfig.behavior) do
    if def.page == key and ns.OptionAvailable(def) then
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
  page.RefreshBehavior()
end

Build("nearby")
Build("bounty")
