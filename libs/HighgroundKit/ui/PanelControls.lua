local _, ns = ...
local Core, Kit, Theme, Motion = ns.Core, ns.Kit, ns.Theme, ns.Motion
local Panels = { windows = {} }
ns.PanelControls = Panels

function Panels.Locked()
  return Core.db and Core.db.locked == true
end

function Panels.Action()
  return Panels.Locked() and ns.Locale:Get("highground.commands.unlock_panels.fc32e8") or ns.Locale:Get("highground.commands.lock_panels.6d05de")
end

function Panels.Hint()
  if InCombatLockdown() then return ns.Locale:Get("shared.panelcontrols.panels_can_be_moved_after_combat_ends.021fb4") end
  return Panels.Locked() and ns.Locale:Get("shared.panelcontrols.unlock_panels_to_drag_their_headers.82252b")
    or ns.Locale:Get("shared.panelcontrols.drag_panel_headers_to_move_lock_panels.ca431e")
end

function Panels.Tooltip()
  return { { Panels.Locked() and ns.Locale:Get("shared.panelcontrols.panels_locked.0d4345") or ns.Locale:Get("shared.panelcontrols.panels_unlocked.e99984"), "text" },
    { Panels.Hint(), "textMuted", true },
    { ns.Locale:Get("shared.panelcontrols.use_any_panel_cogwheel_to_lock_or.7dd27d"), "textMuted", true } }
end

-- Unlocking restores drag handles without changing the saved appearance.
function ns.ShowPanelHeaders()
  return Core.db and not Panels.Locked()
end

function Core.SetPanelsLocked(locked)
  if not Core.db then return end
  Core.db.locked = locked == true
  if ns.ApplyOpacity then ns.ApplyOpacity() end
  Panels.Refresh()
end

function Panels.Toggle()
  GameTooltip_Hide()
  Core.SetPanelsLocked(not Panels.Locked())
  ns.Util.Say((Panels.Locked() and ns.Locale:Get("highground.home.panels_locked.4a91c7") or ns.Locale:Get("highground.home.panels_unlocked.30cc9d")) .. Panels.Hint())
end

function Panels.MenuItem()
  return { text = Panels.Action(), run = Panels.Toggle }
end

-- SecureHide leaves a shown frame at alpha zero in combat. It must not
-- own the column's only cog, or leave an invisible button catching clicks.
function Panels.Visible(w)
  if not w:IsVisible() then return false end
  local parent = w
  while parent do
    if parent:GetAlpha() <= 0 then return false end
    parent = parent:GetParent()
  end
  return true
end

-- The dock has four named slots. Read them directly instead of constructing
-- a frame-keyed membership table on every 0.1-second reconciliation.
local function InDock(w)
  if not Core.compact or not Core.DOCK or not w or not w.gear then return false end
  for _, name in ipairs(Core.DOCK) do if _G[name] == w then return true end end
  return false
end

local function DockState()
  local head, hover
  if Core.compact and Core.DOCK then
    for _, name in ipairs(Core.DOCK) do
      local w = _G[name]
      if w and w.gear and Panels.Visible(w) then
        head = head or w
        hover = hover or w:IsMouseOver() or w.gear:IsMouseOver()
      end
    end
  end
  return head, hover
end

local function FadeTarget(active)
  return Core.PanelTransparency() and not active and Core.THEME.opacity.idle or 1
end

local function PaintFade(fade, value)
  fade.value = value
  for _, surface in ipairs(Core.surfaces) do
    if Core.PanelFade(surface) == fade then Core.PaintSurface(surface) end
  end
  for _, frame in ipairs(Core.backdrops) do
    if Core.PanelFade(frame) == fade then Core.PaintBackdrop(frame, true) end
  end
end

local function FadePanel(w, active)
  local fade, target = w.wbPanelFade, FadeTarget(active)
  if not fade then
    -- Animate a plain helper, never the secure window or its click targets.
    fade = CreateFrame("Frame", nil, w)
    w.wbPanelFade = fade
    fade:EnableMouse(false)
    fade.target = target
    PaintFade(fade, target)
  end
  fade.active = active
  if fade.target ~= target then
    fade.target = target
    Motion.Value(fade, fade.value, target, "hover", PaintFade)
  end
end

-- Settings, themes and profiles repaint at once, including hidden panels.
function Panels.RefreshOpacity()
  for _, w in ipairs(Panels.windows) do
    local fade = w.wbPanelFade
    if fade then
      Motion.Stop(fade)
      fade.value = FadeTarget(fade.active)
      fade.target = fade.value
    end
  end
end

function Panels.RefreshGears()
  local head, groupHover = DockState()
  local menu = Kit.Dropdown.Frame()
  local menuOpen = menu and menu:IsShown()
  local groupOpen = menuOpen and menu.anchor and InDock(menu.anchor.panel)
  for _, w in ipairs(Panels.windows) do
    local gear, docked = w.gear, InDock(w)
    local shown = Panels.Visible(w) and (not docked or w == head)
    local hover = docked and groupHover or w:IsMouseOver() or gear:IsMouseOver()
    local open = menuOpen and menu.anchor == gear
    FadePanel(w, hover or open or (docked and groupOpen))
    if gear.available ~= shown or gear:IsShown() ~= shown then
      gear.available = shown
      gear:EnableMouse(shown)
      gear:SetShown(shown)
      if not shown then
        Motion.Stop(gear)
        Theme.Tint(gear:GetNormalTexture(), "textMuted")
        if GameTooltip:GetOwner() == gear then GameTooltip_Hide() end
        if menu and menu.anchor == gear then Kit.Dropdown.Hide() end
      end
    end
    if shown then
      Motion.Alpha(gear, (not Panels.Locked() or hover or open) and 1 or Theme.Alpha("panelCog"))
    end
  end
end

function Panels.Refresh()
  Panels.RefreshGears()
  if ns.Hub and ns.Hub.RefreshHome then ns.Hub.RefreshHome() end
end

function Panels.Layout(w, height, padding)
  local gear = w.gear
  local size = math.min(Theme.Size("control"), height - 2)
  gear:SetSize(size, size)
  gear:ClearAllPoints()
  gear:SetPoint("RIGHT", w, "TOPRIGHT", -padding, -height / 2)
  local icon = gear:GetNormalTexture()
  icon:ClearAllPoints()
  icon:SetPoint("CENTER")
  icon:SetSize(math.min(20, size - 4), math.min(20, size - 4))
end

local watcher
function Panels.Register(w, key)
  if w.gear then return w.gear end
  local gear = CreateFrame("Button", nil, w)
  w.gear, gear.panel, gear.key = gear, w, key or w.key
  gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  Theme.Tint(gear:GetNormalTexture(), "textMuted")
  gear:SetAlpha(Panels.Locked() and Theme.Alpha("panelCog") or 1)
  gear:SetScript("OnEnter", function(self)
    Theme.Tint(self:GetNormalTexture(), "white")
    Motion.Alpha(self, 1)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    Theme.TipLine(GameTooltip, ns.Locale:Get("shared.panelcontrols.panel_controls.f20c7d"), "text")
    for _, line in ipairs(Panels.Tooltip()) do Theme.TipLine(GameTooltip, line[1], line[2], line[3]) end
    GameTooltip:Show()
  end)
  gear:SetScript("OnLeave", function(self)
    Theme.Tint(self:GetNormalTexture(), "textMuted")
    GameTooltip_Hide()
    Panels.Refresh()
  end)
  gear:SetScript("OnClick", function(self)
    if not self.available then return end
    GameTooltip_Hide()
    Panels.ToggleMenu(self)
  end)
  Panels.windows[#Panels.windows + 1] = w
  w:HookScript("OnShow", Panels.RefreshGears)
  w:HookScript("OnHide", Panels.RefreshGears)
  -- One small reconciliation also catches alpha-only hides, direct saved
  -- lock changes and hovering children (whose mouse events do not bubble).
  if not watcher then watcher = ns.Util.Every(0.1, Panels.RefreshGears, "panel controls") end
  Panels.RefreshGears()
  return gear
end

Theme.OnChange(ns.ApplyOpacity)
ns.Util.Events({ PLAYER_REGEN_DISABLED = Panels.Refresh, PLAYER_REGEN_ENABLED = Panels.Refresh,
  PLAYER_ENTERING_WORLD = Panels.Refresh }, "panel controls")
