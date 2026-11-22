local _, ns = ...
local Core = ns.Core
local Kit = ns.Kit

---------------------------------------------------------------------------
-- Minimap button: left-click opens the Highground window, right-click a
-- quick menu (Kit.Dropdown), drag moves it around the minimap (angle saved
-- in HighgroundDB.minimapAngle). Retail and Forever also list Highground
-- in the addon compartment. The General page switch "minimap" hides the
-- button.
---------------------------------------------------------------------------
local Mini = {}
ns.MinimapButton = Mini
Mini.ICON = Core.BRAND_ICON
Mini.DEFAULT_ANGLE = 200 -- degrees, lower left
Mini.MENU_WIDTH = 220

local function Hub(section) return function() if ns.Hub then ns.Hub.Open(section) else ns.Options.Open() end end end
-- Quick menu entries, top to bottom: { text, run }.
Mini.ITEMS = {
  { text = "Highground", run = Hub("home") },
  ns.Localization.Define({ text = ns.Locale:Get("highground.hub.addons.f32c2d"), run = Hub("addons") }, { text = "highground.hub.addons.f32c2d" }),
  ns.Localization.Define({ text = ns.Locale:Get("highground.modules.macros.899bd6"), run = Hub("macros") }, { text = "highground.modules.macros.899bd6" }),
  ns.Localization.Define({ text = ns.Locale:Get("highground.hub.bounty_board.f37f61"), run = Hub("bountyboard") }, { text = "highground.hub.bounty_board.f37f61" }),
  ns.Localization.Define({ text = ns.Locale:Get("highground.modules.reputation.5f2160"), run = Hub("reputation") }, { text = "highground.modules.reputation.5f2160" }),
  ns.Localization.Define({ text = ns.Locale:Get("highground.minimap.help_and_commands.37209b"), run = Hub("tools") }, { text = "highground.minimap.help_and_commands.37209b" }),
}

function Mini.Place(angle)
  local b = Mini.button
  if not (b and Minimap) then return end
  local rad = math.rad(angle or (Core.db and Core.db.minimapAngle) or Mini.DEFAULT_ANGLE)
  local radius = (Minimap:GetWidth() or 140) / 2 + 8
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

-- Open the quick menu under anchor, or close it when it is open there.
-- The list hangs down and to the left, away from the screen edge the
-- minimap sits on, with no entry highlighted until hovered. Picking an
-- entry closes it, then runs the entry.
function Mini.ToggleMenu(anchor)
  local D = Kit.Dropdown
  local items = { ns.PanelControls.MenuItem() }
  for _, item in ipairs(Mini.ITEMS) do items[#items + 1] = item end
  if D.Open(anchor, items, function(item) item.run() end,
    { width = Mini.MENU_WIDTH * math.max(1, Core.FontScale()) }) then
    D.Select(0, true)
    local list = D.Frame()
    list:ClearAllPoints()
    list:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", 0, 0)
  end
end

-- The button when it is on screen, else the addon compartment (the
-- dropdown closes at once when its anchor is hidden).
local function MenuAnchor()
  local b = Mini.button
  if b and b:IsVisible() then return b end
  return AddonCompartmentFrame
end

function Mini.Click(button)
  if button == "RightButton" then
    local anchor = MenuAnchor()
    if anchor then Mini.ToggleMenu(anchor) end
  elseif ns.Hub then ns.Hub.Toggle()
  else ns.Options.Open() end
end

function Mini.Build()
  if Mini.button or not Minimap then return Mini.button end
  local b = CreateFrame("Button", "HighgroundMinimapButton", Minimap)
  Mini.button = b
  b:SetSize(32, 32)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local backing = b:CreateTexture(nil, "BACKGROUND")
  backing:SetSize(26, 26)
  backing:SetPoint("CENTER", 0, 1)
  backing:SetTexture(Core.CIRCLE)
  ns.Theme.Tint(backing, "hudBg")
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(24, 24)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture(Mini.ICON)
  icon:SetTexCoord(0, 1, 0, 1)
  b.icon = icon
  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(54, 54)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  pcall(b.SetHighlightTexture, b, "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:SetScript("OnClick", function(_, button) Mini.Click(button) end)
  Kit.Tooltip(b, function() return { "Highground", { ns.Locale:Get("highground.minimap.left_click_open_highground.051519"), "text", false },
    { ns.Locale:Get("highground.minimap.right_click_panel_lock_macros_and_more.5bfef1"), "text", false },
    { ns.Locale:Get("highground.minimap.drag_move_around_the_minimap.6a9487"), "textMuted", false } } end, { anchor = "ANCHOR_LEFT" })
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      if not (mx and px and scale) then return end
      local angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
      if Core.db then Core.db.minimapAngle = angle end
      Mini.Place(angle)
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  Mini.Place()
  return b
end

function Mini.Apply()
  local on = Core.On("minimap")
  if on then Mini.Build() end
  if Mini.button then Mini.button:SetShown(on) end
end

ns.Util.Events({
  PLAYER_LOGIN = function()
    Core.Guard("minimap", Mini.Apply)
    -- Retail and Forever: the AddOns button beside the minimap.
    if AddonCompartmentFrame and AddonCompartmentFrame.RegisterAddon then
      pcall(AddonCompartmentFrame.RegisterAddon, AddonCompartmentFrame, {
        text = "Highground", icon = Mini.ICON, notCheckable = true,
        func = function(_, _, _, _, button) Mini.Click(button) end,
      })
    end
  end,
}, "minimap")
