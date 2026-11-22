local _, ns = ...
local O, Core, Kit, Theme = ns.Options, ns.Core, ns.Kit, ns.Theme
local P = { pages = {} }
O.AppearancePreview = P

local function SampleFrame(name, title, sub)
  -- HUD samples stay alongside the active settings tool; ordinary dialogs
  -- participate in navigation and would replace it when opened.
  local w = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  w:SetSize(340, 260); w:SetClampedToScreen(true); Theme.Backdrop(w)
  local header = Kit.Header(w, { title = title, titleRole = "heading", sub = sub, padding = 16 })
  header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT")
  w.close = Kit.Button(w, "X", 28, 28, { onClick = function() P.Stop() end })
  header:SetActions({ w.close })
  return w
end

local function Marker()
  if not P.marker then
    local w = SampleFrame("HighgroundAppearanceMarker", "TARGET MARKER", "Sample nameplate")
    P.marker = w
    w.plate = CreateFrame("Frame", nil, w, "BackdropTemplate")
    w.plate:SetSize(160, 28); w.plate:SetPoint("CENTER", 0, 6); Theme.Backdrop(w.plate)
    Theme.Fill(w.plate, "ARTWORK", "success"):SetAllPoints()
    local name = Theme.Text(w.plate, "body", "text")
    name:SetPoint("CENTER"); name:SetText("Sample enemy")
    w.scope = Core.MakeScope(w)
  end
  local w = P.marker
  w.scope:SetScale(Core.db.sniperScale); Core.PaintScope(w.scope, false)
  Core.AnchorSniper(w.plate, w.scope); w.scope:Show(); w:Show()
  return w
end

local function BountyMarkers()
  local B = ns.Bounty
  if not P.bountyMarkers then
    local w = SampleFrame("HighgroundAppearanceBountyMarkers", "BOUNTY MARKERS", "Sample nameplate and enemy row")
    P.bountyMarkers = w
    w.plate = CreateFrame("Frame", nil, w)
    w.plate:SetSize(180, 28); w.plate:SetPoint("TOP", 18, -108)
    Theme.Fill(w.plate, "BACKGROUND", "danger"):SetAllPoints()
    local name = Theme.Text(w.plate, "body", "onAccent")
    name:SetPoint("CENTER"); name:SetText("Sample enemy")
    w.marker = B.NewPlateMark(w)
    w.marker:SetPoint("RIGHT", w.plate, "LEFT", -6, 0); w.marker.gold:SetText("500g")
    w.row = CreateFrame("Frame", nil, w)
    w.row:SetSize(280, 44); w.row:SetPoint("TOP", 0, -180)
    Theme.Fill(w.row, "BACKGROUND", "surface"):SetAllPoints()
    local rowName = Theme.Text(w.row, "body", "text")
    rowName:SetPoint("CENTER"); rowName:SetText("Sample enemy · Nearby")
    w.sample = select(2, B.Preview.Sample("nearby"))
  end
  local w, on = P.bountyMarkers, Core.On("bountyMarks")
  B.PaintRowMark(w.row, on and w.sample or nil); w.marker:SetShown(on)
  w:Show()
  return w
end

local function StopObjectives()
  ns.Timers.previewing = nil
  ns.Timers.HideWindows(); ns.Timers.SecureHide(ns.Flags.flagWin)
  if ns.QuickCalls then ns.QuickCalls.Update() end
end
local function Objective(which)
  ns.BattlegroundsPreview.Start(true)
  local res, bases = ns.Timers.Windows()
  local selected = which == "resurrection" and res or which == "objectives" and bases or ns.Flags.flagWin
  for _, w in ipairs({ res, bases, ns.Flags.flagWin, ns.QuickCalls and ns.QuickCalls.win }) do
    if w ~= selected then ns.Timers.SecureHide(w) end
  end
  return selected
end

-- Use the real renderers and existing isolated samples. Each session owns
-- only the sample it started; another guide/preview must be finished first.
local scenes = {
  { key = "enemies", module = "battlegrounds", label = "Enemy list and target card",
    start = function() Core.StartTest(true); return Core.frame end, stop = function() Core.StopTest() end },
  { key = "marker", module = "battlegrounds", label = "Target marker", start = Marker,
    stop = function() if P.marker then P.marker:Hide() end end, refresh = Marker },
  { key = "resurrection", module = "battlegrounds", label = "Resurrection timers", start = function() return Objective("resurrection") end, stop = StopObjectives },
  { key = "objectives", module = "battlegrounds", label = "Objective timers", start = function() return Objective("objectives") end, stop = StopObjectives },
  { key = "flags", module = "battlegrounds", label = "Flag carriers", start = function() return Objective("flags") end, stop = StopObjectives },
  { key = "arena", module = "arena", label = "Arena / duel opponents",
    start = function() ns.ArenaPreview(); return ns.Arena.win end,
    stop = function() ns.Arena.preview = false; ns.Arena.Update() end },
  { key = "nearby", module = "nearby", label = "Nearby enemies",
    start = function() ns.NearbyPreview(); return ns.Nearby.win end,
    stop = function() ns.Nearby.preview = false; ns.Nearby.Update() end },
  { key = "poster", module = "bounties", label = "Wanted poster",
    start = function() ns.Bounty.Preview.Command("poster"); return ns.Bounty.Poster.previewWin end,
    stop = function() ns.Bounty.Preview.Stop() end },
  { key = "bountymarkers", module = "bounties", label = "Bounty markers", start = BountyMarkers, refresh = BountyMarkers,
    stop = function() if P.bountyMarkers then P.bountyMarkers:Hide() end end },
}

local function Allowed()
  local kind = select(2, IsInInstance())
  if InCombatLockdown() or kind == "pvp" or kind == "arena" or ns.Arena and ns.Arena.duel then
    return false, "Preview outside combat, matches and duels."
  end
  if not P.session and (Core.testMode or Core.active or Core.sniperTest and Core.sniperTest.on
    or ns.Timers and ns.Timers.previewing or ns.Arena and ns.Arena.preview
    or ns.Nearby and (ns.Nearby.preview or ns.Nearby.test)
    or ns.Setup and ns.Setup.placement or ns.Bounty and ns.Bounty.Preview.state) then
    return false, "Finish the current guide or preview before starting another."
  end
  return true
end

local function Restore(state)
  local w = state.frame
  w:ClearAllPoints()
  for _, point in ipairs(state.points) do w:SetPoint(unpack(point)) end
  w:SetFrameStrata(state.strata); w:SetFrameLevel(state.level)
  w:SetScript("OnDragStart", state.dragStart); w:SetScript("OnDragStop", state.dragStop)
  w.tourDocked = state.tourDocked
end

function P.Position()
  local state = P.session
  if not state or InCombatLockdown() then return end
  local w = state.frame
  -- In front of the sidebar, beside the controls. Clamping keeps samples
  -- reachable on small displays, without saving a different HUD position.
  local scale = w:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local anchorScale = state.page.frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local width, height = w:GetWidth() * scale, w:GetHeight() * scale
  local cx, cy = state.page.frame:GetCenter()
  local left = ((cx or 0) - state.page.frame:GetWidth() / 2) * anchorScale
  local top = ((cy or 0) + state.page.frame:GetHeight() / 2) * anchorScale
  local x = math.max(12, math.min(UIParent:GetWidth() - width - 12, left - width - 12))
  local y = math.max(12, math.min(UIParent:GetHeight() - height - 12, UIParent:GetHeight() - top + 24))
  w:ClearAllPoints(); w:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x / scale, -y / scale)
end

function P.Stop()
  local state = P.session
  if not state then P.Refresh(); return end
  P.session = nil
  state.scene.stop()
  if InCombatLockdown() then
    ns.Timers.SecureHide(state.frame)
    P.restore = state
  else Restore(state) end
  P.Refresh()
end

function P.Start(page)
  P.Stop()
  local allowed, problem = Allowed()
  if not allowed then page.previewHint:SetText(problem); return end
  local scene
  for _, item in ipairs(scenes) do if item.key == page.previewChoice:GetValue() then scene = item; break end end
  if not scene or not ns.Modules.Active(scene.module) then return end
  local w = scene.start()
  if not w or not w:IsShown() then scene.stop(); page.previewHint:SetText("This sample is unavailable right now."); return end
  local state = { scene = scene, page = page, frame = w, points = {}, strata = w:GetFrameStrata(), level = w:GetFrameLevel(),
    dragStart = w:GetScript("OnDragStart"), dragStop = w:GetScript("OnDragStop"), tourDocked = w.tourDocked }
  for i = 1, w:GetNumPoints() do state.points[i] = { w:GetPoint(i) } end
  P.session = state
  w:SetScript("OnDragStart", nil); w:SetScript("OnDragStop", nil)
  w:SetFrameStrata("FULLSCREEN_DIALOG"); w:SetFrameLevel(120); w.tourDocked = true
  if not w.appearanceHook then
    w.appearanceHook = true
    w:HookScript("OnHide", function()
      if P.session and P.session.frame == w and not w:IsShown() then P.Stop() end
    end)
  end
  P.Position(); P.Refresh()
end

function P.Refresh()
  for _, page in ipairs(P.pages) do
    if page.frame:IsVisible() then page.RefreshPreview() end
  end
end

function O.AddAppearancePreview(page, owner)
  -- A fixed toolbar leaves Stop reachable while fine-tuning far down a page.
  local bar = CreateFrame("Frame", nil, page.frame)
  bar:SetPoint("TOPLEFT", page.hint, "BOTTOMLEFT", 0, -12); bar:SetPoint("RIGHT", -24, 0)
  page.previewBar = bar
  local label = Theme.Text(bar, "body", "text")
  label:SetPoint("TOPLEFT"); label:SetText("Preview your changes")
  page.previewChoice = Kit.Select(bar, { width = 280, menu = true, choices = {}, onChange = function()
    if P.session and P.session.page == page then P.Start(page) else page.RefreshPreview() end
  end })
  page.previewChoice:SetPoint("TOPLEFT", 0, -26)
  page.preview = Kit.Button(bar, "Start preview", 160, 32, { onClick = function()
    if P.session and P.session.page == page then P.Stop() else P.Start(page) end
  end })
  page.preview:SetPoint("TOPRIGHT", 0, -26)
  page.previewHint = Theme.Text(bar, "body", "textMuted")
  page.previewHint:SetPoint("TOPLEFT", 0, -66); page.previewHint:SetPoint("RIGHT")
  page.previewHint:SetJustifyH("LEFT"); page.previewHint:SetWordWrap(true)
  function page.RefreshPreview()
    local choices = {}
    for _, scene in ipairs(scenes) do
      if (not owner or scene.module == owner) and ns.Modules.Active(scene.module) then
        choices[#choices + 1] = { key = scene.key, label = scene.label }
      end
    end
    local selected = page.previewChoice:GetValue()
    page.previewChoice:SetChoices(choices)
    page.previewChoice:SetValue(selected or choices[1] and choices[1].key, true)
    local running = P.session and P.session.page == page
    local allowed, problem = Allowed()
    page.preview:SetText(running and "Stop preview" or "Start preview")
    page.preview:SetEnabled(running or allowed and #choices > 0)
    page.previewChoice:SetEnabled(allowed and #choices > 0)
    page.previewHint:SetText(#choices == 0 and "Enable an addon and reload to preview its panels."
      or not allowed and problem or running and "Sample data · Changes apply as you edit. Leaving this page stops the preview."
      or "Choose a sample, then Start preview. Your appearance changes save automatically.")
    page.previewChoice:SetWidth(math.max(120, bar:GetWidth() - page.preview:GetWidth() - 12))
    local height = 76 + page.previewHint:GetStringHeight()
    bar:SetHeight(height); page.toolbarHeight = height + 12
    page.LayoutHeader()
    if running then
      if P.session.scene.refresh then P.session.scene.refresh() end
      P.Position()
    end
  end
  page.frame:HookScript("OnShow", page.RefreshPreview)
  page.frame:HookScript("OnHide", function() if P.session and P.session.page == page then P.Stop() end end)
  bar:HookScript("OnSizeChanged", function() if not page.previewLayout then
    page.previewLayout = true; page.RefreshPreview(); page.previewLayout = nil
  end end)
  Core.OnFontScaleChange(function() if page.frame:IsVisible() then page.RefreshPreview() end end)
  P.pages[#P.pages + 1] = page
end

local function DuelChanged()
  P.Stop()
  -- The Arena observer handles the same event after these controls load.
  C_Timer.After(0.01, P.Refresh)
end

ns.Util.Events({
  PLAYER_REGEN_DISABLED = P.Stop,
  PLAYER_REGEN_ENABLED = function()
    if P.restore then
      local state = P.restore; P.restore = nil
      Restore(state)
      -- Protected sample windows finish hiding only after lockdown ends.
      if not Core.active and state.frame == Core.frame then state.frame:Hide(); state.frame:SetAlpha(1) end
      if state.scene.stop == StopObjectives then StopObjectives() end
    end
    P.Refresh()
  end,
  PLAYER_ENTERING_WORLD = function() if not Allowed() then P.Stop() end; P.Refresh() end,
  DUEL_REQUESTED = DuelChanged, DUEL_TO_THE_DEATH_REQUESTED = DuelChanged,
  DUEL_INBOUNDS = DuelChanged, DUEL_FINISHED = DuelChanged,
}, "appearance previews")
