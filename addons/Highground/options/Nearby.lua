local _, ns = ...
local Core, Theme, Kit, Options = ns.Core, ns.Theme, ns.Kit, ns.Options
local S, Z = Theme.Space, Theme.Size

-- Nearby and Bounties settings pages: the behavior options tagged
-- with the page's key.
local function Build(key)
  local page = Options.FeaturePage(key, key == "bounty" and "bounties" or "nearby")
  local toggles = {}
  if key == "bounty" then
    local open = ns.Localization.Bind(Kit.Button(page.child, ns.Locale:Get("highground.modules.open_bounty_board.69b5a7"), 180, Z("input"), { tone = "gold" }), "highground.modules.open_bounty_board.69b5a7")
    open:SetPoint("TOPLEFT", S("xl"), page.y)
    open:SetScript("OnClick", function() ns.Bounty.Board.Open() end)
    page.openBoard = open
    page.y = page.y - 34
  end
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
          desc = def.desc, detail = ns.Locale:Format("highground.nearby.unit_def_unit.cb8056", { def_unit = ns.OptionUnit(def) }) })
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
