local _, ns = ...
local Timers = ns.Timers
local Flags = ns.Flags
local Util, Core, Guard = ns.Util, ns.Core, ns.Util.Guard

-- Quest trackers and carrier frames, hidden in battlegrounds. Questie
-- builds its tracker after login and shows it again on quest updates, so
-- its frame is looked up each time and re-hidden from its OnShow.
local arenaHidden
local function QuestieShow(tr)
  local loader = QuestieLoader
  local ok, tracker = pcall(function() return loader and loader:ImportModule("QuestieTracker") end)
  -- Questie's own Show keeps its tracker setting and its in-instance hide.
  if not (ok and type(tracker) == "table" and tracker.Show and pcall(tracker.Show, tracker)) then tr:Show() end
end
local TRACKERS = {
  { frame = function() return WatchFrame or ObjectiveTrackerFrame end, show = function(tr)
    tr:Show()
    if tr == WatchFrame and WatchFrame_Update then pcall(WatchFrame_Update, WatchFrame) end
  end },
  { frame = function() return Questie_BaseFrame end, show = QuestieShow },
}
local function ApplyTracker(t, hide)
  local tr = t.frame()
  if not tr then return end
  if not t.hooked then
    t.hooked = true
    tr:HookScript("OnShow", function()
      if Flags.InBG() then Flags.ApplyBlizzard() end
    end)
  end
  if hide and tr:IsShown() then
    -- Questie's quest item buttons are secure: in combat, fade only.
    if InCombatLockdown() then
      tr:SetAlpha(0)
    else
      tr:Hide()
      tr:SetAlpha(1)
    end
    t.hidden = true
  elseif not hide and t.hidden then
    tr:SetAlpha(1)
    if not InCombatLockdown() then
      t.hidden = false
      t.show(tr)
    end
  end
end
function Flags.ApplyBlizzard()
  local db = Timers.DB()
  local inBG = Flags.InBG()
  local hide = inBG and ns.IsActive and ns.IsActive() and db and Core.On("hideTracker")
  for _, t in ipairs(TRACKERS) do ApplyTracker(t, hide) end
  local af = ArenaEnemyFrames
  if af then
    local hideArena = inBG and Flags.FlagsEnabled() and db and Core.On("hideCarrierFrames") and Flags.FlagBG() and Flags.flagWin and Flags.flagWin:IsShown()
    if hideArena then
      if af:IsShown() then
        arenaHidden = arenaHidden or { shown = true, alpha = af:GetAlpha() }
        if InCombatLockdown() then
          af:SetAlpha(0)
        else
          af:Hide()
        end
      end
    elseif arenaHidden then
      af:SetAlpha(arenaHidden.alpha)
      if not InCombatLockdown() then
        local shown = arenaHidden.shown
        arenaHidden = nil
        if shown then af:Show() end
      end
    end
  end
end

local hooked = {}
function Flags.Hook()
  if ArenaEnemyFrames_UpdateVisible and not hooked.arena then
    hooked.arena = true
    hooksecurefunc("ArenaEnemyFrames_UpdateVisible", Flags.ApplyBlizzard)
  end
end

local function OnChat(event, msg)
  if Flags.ReadChat() and Flags.InBG() and Flags.FlagBG() then Guard("flags chat", Flags.OnChat, event, msg) end
end
local Tick
local function OnWorld(event)
  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    wipe(Flags.carriers)
    wipe(Flags.lastCarrier)
  end
  Flags.Hook()
  Guard("flags blizzard", Flags.ApplyBlizzard)
  if event == "PLAYER_REGEN_ENABLED" then
    if Flags.pendingMacro then Flags.SetMacros() end
    -- A window faded out in combat after its ticker stopped: hide it now.
    Tick()
  end
end
local handlers = {
  CHAT_MSG_BG_SYSTEM_ALLIANCE = OnChat, CHAT_MSG_BG_SYSTEM_HORDE = OnChat, CHAT_MSG_BG_SYSTEM_NEUTRAL = OnChat,
}
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED",
  "ADDON_LOADED" }) do
  handlers[ev] = OnWorld
end
Util.Events(handlers, "flags events", "battlegrounds")
local function UpdateFlags() Flags.UpdateFlags(GetTime()) end
function Tick()
  if Timers.previewing then return end -- sample carriers (timers/Driver.lua)
  Util.RunGuarded("flags", UpdateFlags)
  Util.RunGuarded("flags blizzard", Flags.ApplyBlizzard)
end
-- In a tracked battleground, or while preview carriers are shown. Stopping
-- runs it once more to hide the window (a preview ended by entering an arena
-- included) and restore Blizzard's frames; world and combat events retry.
ns.PvPEvents.Every(0.25, Tick, "flags", function()
  return Timers.previewing or (ns.IsActive and ns.IsActive()) or false
end, "battlegrounds", Tick)
ns.Test = ns.Test or {}
ns.Test.flags = { carriers = Flags.carriers, lastCarrier = Flags.lastCarrier, OnChat = Flags.OnChat, rows = function()
  return Flags.frows
end }
