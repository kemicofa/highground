local _, ns = ...
local Core, Options = ns.Core, ns.Options

-- Nearby enemies and Guild bounties pages: the behavior options tagged
-- with the page's key.
local function Build(key)
  local page = Options.MakePage(key)
  local toggles = {}
  if key == "bounty" then
    local open = CreateFrame("Button", nil, page.child, "UIPanelButtonTemplate")
    open:SetSize(180, 24)
    open:SetPoint("TOPLEFT", 16, page.y)
    open:SetText("Open bounty board")
    open:SetScript("OnClick", function() ns.Bounty.Board.Open() end)
    page.openBoard = open
    page.y = page.y - 34
  end
  for _, def in ipairs(ns.OptionsConfig.behavior) do
    if def.page == key and ns.OptionAvailable(def) then
      if def.type == "boolean" then
        local check = CreateFrame("CheckButton", nil, page.child, "UICheckButtonTemplate")
        check:SetSize(24, 24)
        check:SetPoint("TOPLEFT", 16, page.y)
        local label = page.child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        label:SetText(def.desc)
        check:SetScript("OnClick", function(self)
          Options.Set({ kind = "option", key = def.key }, self:GetChecked() and true or false)
        end)
        toggles[def.key] = check
        page.y = page.y - 28
      else
        Options.Row(page, { kind = "option", key = def.key, def = def.def, step = def.step,
          desc = def.desc, detail = "Unit: " .. def.unit })
      end
    end
  end
  page.RefreshBehavior = function()
    for k, check in pairs(toggles) do check:SetChecked(Core.O(k) and true or false) end
  end
  page.RefreshBehavior()
end

Build("nearby")
Build("bounty")
