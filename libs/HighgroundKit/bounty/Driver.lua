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
      ns.Theme.TipLine(tip, "Shared bounty: " .. Bounty.GoldText(b) .. " with funds reported available", "gold")
      ns.Theme.TipLine(tip, #b.contributions .. " contributions; " .. ns.Util.Gold(b.pledgedGold) .. " pledged", "textMuted")
    else ns.Theme.TipLine(tip, "Bounty: " .. Bounty.GoldText(b) .. " from " .. Core.DisplayName(b.by or "?"), "gold") end
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
      root:CreateButton((ns.LABEL or "Highground") .. ": put a bounty", function() Bounty.Board.Open(key) end)
    end)
  end
end

local function RequestRoster()
  if C_GuildInfo and C_GuildInfo.GuildRoster then
    pcall(C_GuildInfo.GuildRoster)
  elseif GuildRoster then
    pcall(GuildRoster)
  end
end

local synced = false
local function SyncOnce()
  if synced or not Bounty.InGuild() then return end
  synced = true
  RequestRoster()
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
  PLAYER_GUILD_UPDATE = function()
    Try(SyncOnce)
    Try(Bounty.Board.Refresh)
  end,
  GUILD_ROSTER_UPDATE = function()
    Try(Bounty.ReadRoster)
    Try(Bounty.Board.Refresh)
  end,
  UPDATE_MOUSEOVER_UNIT = function() Try(Bounty.SpotUnit, "mouseover") end,
  PLAYER_TARGET_CHANGED = function() Try(Bounty.SpotUnit, "target") end,
}
if ns.Caps.combatLog and CombatLogGetCurrentEventInfo then
  handlers.COMBAT_LOG_EVENT_UNFILTERED = function() Try(Bounty.OnCombatLog) end
end
Util.Events(handlers, "bounty")
ns.Comms.Listen(Bounty.PREFIX, function(text, channel, sender)
  if channel == "GUILD" then Try(Bounty.Receive, text, sender) end
end, "bounty")

Util.Every(Bounty.SCAN, function()
  local now = GetTime()
  Bounty.SummarizeSync(now)
  Try(Bounty.Tick, now)
  Try(Bounty.UpdatePlates)
end, "bounty")

Util.Every(1, function()
  Try(Bounty.ScanRosters)
  Try(Bounty.Board.Refresh) -- "seen" times age
end, "bounty")
