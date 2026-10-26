local _, ns = ...
local Core, Bounty = ns.Core, ns.Bounty

local Call, Plain = ns.Util.call, ns.Util.value

local function Try(fn, ...)
  if not Core.db then return end
  local n, args = select("#", ...), { ... }
  Core.Guard("bounty", function() fn(unpack(args, 1, n)) end)
end

-- Unit tooltips name the reward on a bounty target.
local function TooltipLine(tip)
  if not (Bounty.Enabled() and tip and tip.GetUnit) then return end
  local _, unit = tip:GetUnit()
  if not unit or not Plain(Call(UnitIsPlayer, unit)) then return end
  local key = Core.CanonUnit(unit)
  local b = key and Bounty.Find(key)
  if b then
    local g = Bounty.GOLD
    tip:AddLine("Bounty: " .. Bounty.GoldText(b) .. " from " .. Core.DisplayName(b.by or "?"), g[1], g[2], g[3])
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
      root:CreateButton("Warboard: put a bounty", function() Bounty.Board.Open(key) end)
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

local f = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_LOGIN", "PLAYER_GUILD_UPDATE", "GUILD_ROSTER_UPDATE", "CHAT_MSG_ADDON", "UPDATE_MOUSEOVER_UNIT",
  "PLAYER_TARGET_CHANGED" }) do
  pcall(f.RegisterEvent, f, ev)
end
if ns.Caps.combatLog and CombatLogGetCurrentEventInfo then
  pcall(f.RegisterEvent, f, "COMBAT_LOG_EVENT_UNFILTERED")
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

f:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    Try(Bounty.OnCombatLog)
  elseif event == "CHAT_MSG_ADDON" then
    if a1 == Bounty.PREFIX and a3 == "GUILD" and type(a2) == "string" then
      Try(Bounty.Receive, a2, a4)
    end
  elseif event == "PLAYER_LOGIN" then
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
      C_ChatInfo.RegisterAddonMessagePrefix(Bounty.PREFIX)
    end
    HookTooltip()
    Try(HookMenus)
    Try(SyncOnce)
  elseif event == "PLAYER_GUILD_UPDATE" then
    Try(SyncOnce)
    if Bounty.Board.Refresh then Try(Bounty.Board.Refresh) end
  elseif event == "GUILD_ROSTER_UPDATE" then
    Try(Bounty.ReadRoster)
    Try(Bounty.Board.Refresh)
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    Try(Bounty.SpotUnit, "mouseover")
  elseif event == "PLAYER_TARGET_CHANGED" then
    Try(Bounty.SpotUnit, "target")
  end
end)

local plates, rosters = 0, 0
f:SetScript("OnUpdate", function(_, dt)
  plates, rosters = plates + dt, rosters + dt
  if plates < Bounty.SCAN then return end
  plates = 0
  local now = GetTime()
  -- Sync replies arrive over a few seconds; summarize them once.
  if Bounty.syncing and now - Bounty.syncing > Bounty.REPLY_DELAY[2] + 4 then
    if (Bounty.synced or 0) > 0 and Bounty.Enabled() then
      Bounty.Say(Bounty.synced .. " guild bounties received (/wb bounty)")
    end
    Bounty.syncing, Bounty.synced = nil, nil
  end
  Try(Bounty.Tick, now)
  Try(Bounty.UpdatePlates)
  if rosters >= 1 then
    rosters = 0
    Try(Bounty.ScanRosters)
    Try(Bounty.Board.Refresh) -- "seen" times age
  end
end)
