local _, ns = ...
local Core, Bounty = ns.Core, ns.Bounty

---------------------------------------------------------------------------
-- Bounty wiring: game events, guild messages (core/Comms.lua), the
-- nameplate and roster scans, tooltip lines and right-click menu entries.
---------------------------------------------------------------------------
local Util = ns.Util
local Call, Plain = Util.call, Util.value

-- Each step guarded on its own, once saved variables are loaded.
local function Try(fn, ...)
  if Core.db then Util.Guard("bounty", fn, ...) end
end

-- Unit tooltips name the reward on a bounty target.
local function TooltipLine(tip)
  if not (Bounty.Enabled() and tip and tip.GetUnit) then return end
  local _, unit = tip:GetUnit()
  if not unit or not Plain(Call(UnitIsPlayer, unit)) then return end
  local key = Core.CanonUnit(unit)
  local b = key and Bounty.Find(key)
  if b then
    if b.state == "public" then
      ns.Theme.TipLine(tip, ns.Locale:Format("shared.driver.shared_bounty_value2_with_funds_reported_available.821b9d", { value2 = Bounty.GoldText(b) }), "gold")
      ns.Theme.TipLine(tip, ns.Locale:Format("shared.driver.value1_contributions_value3_pledged.e2aced", { value1 = #b.contributions, value3 = ns.Util.Gold(b.pledgedGold) }), "textMuted")
    else ns.Theme.TipLine(tip, ns.Locale:Format("shared.driver.bounty_value2_from_value4.19669f", { value2 = Bounty.GoldText(b), value4 = Core.DisplayName(b.by or "?") }), "gold") end
  end
end

local function HookTooltip()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tip) Try(TooltipLine, tip) end)
  elseif GameTooltip and GameTooltip.HookScript then
    pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", function(tip) Try(TooltipLine, tip) end)
  end
end

-- "Put a bounty" in other players' right-click menus (Retail and Forever menus).
local MENUS = { "MENU_UNIT_TARGET", "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_FOCUS", "MENU_UNIT_PLAYER" }
local function HookMenus()
  if not (Menu and Menu.ModifyMenu) then return end
  for _, tag in ipairs(MENUS) do
    pcall(Menu.ModifyMenu, tag, function(_, root, context)
      local unit = context and context.unit
      if not (unit and Bounty.IsOtherPlayer(unit)) then return end
      local key = Core.CanonUnit(unit)
      if not key then return end
      root:CreateDivider()
      root:CreateButton(ns.Locale:Format("shared.driver.value1_put_a_bounty.ef359c", { value1 = (ns.LABEL or "Highground") }), function() Bounty.Board.Open(key) end)
    end)
  end
end

local synced
local function SyncOnce()
  local guild = Bounty.GuildKey()
  if not guild then synced = nil; return end
  if synced == guild then return end
  synced = guild
  ns.Guild.RequestRoster()
  Bounty.Expire()
  Bounty.syncing = GetTime()
  Bounty.RequestSync()
end

local handlers = {
  PLAYER_LOGIN = function()
    HookTooltip()
    Bounty.Share.Install()
    Try(HookMenus)
    Try(SyncOnce)
  end,
  PLAYER_GUILD_UPDATE = function(_, unit)
    if unit and unit ~= "player" then return end
    Try(SyncOnce)
    Try(Bounty.Board.Refresh)
  end,
  GUILD_ROSTER_UPDATE = function()
    Try(Bounty.Board.Refresh)
  end,
  UPDATE_MOUSEOVER_UNIT = function() Try(Bounty.SpotUnit, "mouseover") end,
  PLAYER_TARGET_CHANGED = function() Try(Bounty.SpotUnit, "target") end,
  PLAYER_FOCUS_CHANGED = function() Try(Bounty.SpotUnit, "focus") end,
  NAME_PLATE_UNIT_ADDED = function(_, unit) Try(Bounty.SpotUnit, unit) end,
}
Bounty.Listen("scope", function() synced = false; Try(SyncOnce) end)
if ns.Caps.combatLog and CombatLogGetCurrentEventInfo then
  handlers.COMBAT_LOG_EVENT_UNFILTERED = function() Try(Bounty.OnCombatLog) end
else
  handlers.CHAT_MSG_COMBAT_HONOR_GAIN = function(...) Try(Bounty.Kills.Honor, ...) end
end
Util.Events(handlers, "bounty", "bounties")
ns.Comms.Listen(Bounty.PREFIX, function(text, channel, sender)
  if channel == "GUILD" then Try(Bounty.Receive, text, sender) end
end, "bounty", "bounties")

-- Timer callbacks need no returned values. Keep each step independently
-- guarded without packing arguments/results on every idle tick.
local function Tick() Bounty.Tick(GetTime()) end
Util.Every(Bounty.SCAN, function()
  if not Core.db then return end
  local now = GetTime()
  Bounty.SummarizeSync(now)
  Util.RunGuarded("bounty", Tick)
  Util.RunGuarded("bounty", Bounty.UpdatePlates)
end, "bounty", "bounties")

Util.Every(1, function()
  if not Core.db then return end
  Util.RunGuarded("bounty", Bounty.ScanRosters)
  Util.RunGuarded("bounty", Bounty.Board.Tick) -- age labels; changes refresh through events
end, "bounty", "bounties")
