local _, ns = ...
local Bounty, Theme, Kit = ns.Bounty, ns.Theme, ns.Kit

---------------------------------------------------------------------------
-- Bounty board pieces on the UI kit (ui/kit/): state labels and colours,
-- relative times and browser tooltips (Bounty.Widgets, also ns.Widgets).
---------------------------------------------------------------------------
local W = {}
Bounty.Widgets = W
ns.Widgets = W

-- Only one bounty popup at a time. Its entire frame tree sits above the
-- board, including when the board has been reparented into the hub.
local windows = {}
function W.HasOpenWindow()
  for w in pairs(windows) do if w:IsShown() then return true end end
  return false
end
function W.ShowWindow(w)
  windows[w] = true
  w:SetFrameStrata("FULLSCREEN_DIALOG")
  Kit.Windows.Show(w)
  -- Popup contents must stay opaque even during the normal dialog entrance.
  if ns.Motion then ns.Motion.Stop(w, 1) else w:SetAlpha(1) end
  if w.Raise then w:Raise() end
end

-- Forms and claims are pages of the board. Keep the board's
-- filters and position while replacing its contents, including in the hub.
-- Full wanted posters, previews and imports use the independent popup above.
function W.MountPage(w)
  Kit.Windows.SetResume(w, function() Bounty.Navigation.Resume() end)
  local board = Bounty.Board.Build()
  Kit.Windows.Show(w, function()
    if board.page and board.page ~= w then board.page:Hide() end
    if not board:IsVisible() then Bounty.Board.Open() end
    if not w.bountyPage then
      local home = { parent = w:GetParent(), width = w:GetWidth(), height = w:GetHeight(),
        movable = w:IsMovable(), closeShown = w.close and w.close:IsShown(), points = {} }
      for i = 1, w.GetNumPoints and w:GetNumPoints() or 1 do home.points[i] = { w:GetPoint(i) } end
      w.bountyPage = home
      w:SetParent(board); w:ClearAllPoints(); w:SetAllPoints(board)
      w:SetMovable(false); w:SetFrameLevel(board:GetFrameLevel() + 5)
    end
    if not w.bountyPageHook then
      w.bountyPageHook = true
      w:HookScript("OnHide", function()
        if w:IsShown() then return end -- an ancestor was hidden; keep this page mounted
        local home = w.bountyPage
        if not home then return end
        w.bountyPage = nil
        if board.page == w then
          board.page = nil; board.browser:Show(); board.title:Show()
          board.close:SetShown(board:IsMovable()); Bounty.Board.Refresh()
        end
        w:SetParent(home.parent); w:ClearAllPoints(); w:SetSize(home.width, home.height)
        for _, point in ipairs(home.points) do if point[1] then w:SetPoint(unpack(point)) end end
        w:SetMovable(home.movable)
        if w.close then w.close:SetShown(home.closeShown) end
        Bounty.Navigation.Closed()
      end)
    end
    board.page = w
    board.browser:Hide(); board.title:Hide(); board.close:Hide()
    if w.close then w.close:SetShown(board:IsMovable()) end
    if w.LayoutPage then w:LayoutPage() end
  end)
  windows[w] = true
  if ns.Motion then ns.Motion.Stop(w, 1) end
end

-- Bounty states: { label, r, g, b, token = colour token }, rebuilt when
-- the theme changes.
local STATES = { public = ns.Localization.Define({ ns.Locale:Get("shared.widgets.shared.d25692"), "gold" }, { [1] = "shared.widgets.shared.d25692" }), personal = ns.Localization.Define({ ns.Locale:Get("shared.widgets.personal.3c40f6"), "textMuted" }, { [1] = "shared.widgets.personal.3c40f6" }), pending = ns.Localization.Define({ ns.Locale:Get("shared.widgets.pending.0a7b38"), "pending" }, { [1] = "shared.widgets.pending.0a7b38" }),
  approved = ns.Localization.Define({ nil, "gold" }, { [1] = "shared.copy.approved.a0cff1" }) }
W.STATE = {}
local function BuildStates()
  for key, def in pairs(STATES) do
    local s = W.STATE[key] or {}
    local r, g, b = Theme.Color(def[2])
    s[1], s[2], s[3], s[4], s.token = def[1], r, g, b, def[2]
    W.STATE[key] = s
  end
end
BuildStates()
ns.Localization.Watch(W.STATE, BuildStates)
Theme.OnChange(BuildStates)

-- "NOW", "5M AGO", "3H AGO", "2D AGO". Coarser than Util.Ago (which counts
-- seconds and stops at minutes): sightings can be days old.
function W.Ago(seconds)
  seconds = math.max(0, math.floor(seconds))
  if seconds < 60 then return ns.Locale:Get("highground.render.now.9841c4") end
  if seconds < 3600 then return ns.Locale:Format("shared.widgets.value1_m_ago.ef109b", { value1 = math.floor(seconds / 60) }) end
  if seconds < 86400 then return ns.Locale:Format("shared.widgets.value1_h_ago.d62378", { value1 = math.floor(seconds / 3600) }) end
  return ns.Locale:Format("shared.widgets.value1_d_ago.e96295", { value1 = math.floor(seconds / 86400) })
end

function W.BrowserHelp(w, descriptions)
  Kit.Tooltip(w.search, function() return { ns.Locale:Get("shared.widgets.search_this_list.37c376"), ns.Locale:Get("shared.widgets.filter_by_player_status_or_any_text.3ae086") } end)
  Kit.Tooltip(w.prev, function() return { ns.Locale:Get("shared.board.previous_page.81f547"), ns.Locale:Get("shared.widgets.show_the_previous_entries_in_this_list.104287") } end)
  Kit.Tooltip(w.next, function() return { ns.Locale:Get("macros.scripts.next_page.4bfc19"), ns.Locale:Get("shared.widgets.show_the_next_entries_in_this_list.abdc42") } end)
  for i, button in ipairs(w.actions) do
    if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
    Kit.Tooltip(button, { button.action.label, descriptions[i] })
  end
end
