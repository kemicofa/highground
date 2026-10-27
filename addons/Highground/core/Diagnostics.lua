local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Slash
---------------------------------------------------------------------------
-- /wb probe: report which APIs return readable vs secret values right now,
-- on your target. Results are also saved to WarboardDB.lastProbe.
function Core.Probe(say)
  local out = {}
  local function show(label, f, ...)
    local res = { pcall(f, ...) }
    local text
    if not res[1] then
      text = "ERROR " .. tostring(res[2])
    else
      local parts = {}
      for i = 2, math.max(#res, 2) do
        local v = res[i]
        if v == nil then
          parts[#parts + 1] = "nil"
        elseif Core.issecret(v) then
          parts[#parts + 1] = "SECRET"
        elseif type(v) == "table" then
          local okLen, n = pcall(function() return #v end)
          parts[#parts + 1] = okLen and Core.plain(n) and ("table#" .. n) or "table(SECRET len)"
        else
          parts[#parts + 1] = tostring(v)
        end
      end
      text = table.concat(parts, ", ")
    end
    out[#out + 1] = label .. " = " .. text
    say(label .. " = " .. ns.Theme.TipHex("gold") .. text .. "|r")
  end
  local _, instanceType = IsInInstance()
  show("instance", function() return instanceType end)
  show("IsRatedBattleground", C_PvP.IsRatedBattleground)
  show("IsSoloRBG", C_PvP.IsSoloRBG)
  show("GetActiveMatchState", C_PvP.GetActiveMatchState)
  show("addon active / enemies / allyFaction", function()
    local n = 0
    for _ in pairs(Core.enemies) do n = n + 1 end
    return Core.active, n, tostring(Core.allyFaction)
  end)
  if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
    show("InChatMessagingLockdown", C_ChatInfo.InChatMessagingLockdown)
  end
  show("NumBattlefieldScores", GetNumBattlefieldScores)
  show("rows per team (faction:count)", function()
    local counts = {}
    for i = 1, GetNumBattlefieldScores() or 0 do
      local info = Core.ScoreInfo(i)
      local f = info and info.faction
      if Core.plain(f) then
        counts[f] = (counts[f] or 0) + 1
      end
    end
    local parts = {}
    for f, c in pairs(counts) do
      parts[#parts + 1] = f .. ":" .. c
    end
    return table.concat(parts, " ")
  end)
  if (GetNumBattlefieldScores() or 0) > 0 then
    show("score[1].name/class/spec/faction", function()
      local i = Core.ScoreInfo(1)
      if i then return i.name, i.classToken, i.talentSpec, i.faction end
    end)
  end
  local u = "target"
  if not UnitExists(u) then
    say("no target: target an enemy player and run /wb probe again for unit checks")
  else
    show("UnitName", UnitName, u)
    show("UnitClass", UnitClass, u)
    show("UnitIsPlayer", UnitIsPlayer, u)
    show("UnitCanAttack", UnitCanAttack, "player", u)
    show("CanonUnit / in roster", function()
      local k = Core.CanonUnit(u)
      return k, k and Core.enemies[k] ~= nil
    end)
    show("UnitIsDeadOrGhost", UnitIsDeadOrGhost, u)
    show("UnitHealthPercent", UnitHealthPercent, u, true)
    show("BIG_DEFENSIVE auras", C_UnitAuras.GetUnitAuras, u, "HELPFUL|BIG_DEFENSIVE")
    show("EXTERNAL_DEFENSIVE auras", C_UnitAuras.GetUnitAuras, u, "HELPFUL|EXTERNAL_DEFENSIVE")
    show("CROWD_CONTROL auras", C_UnitAuras.GetUnitAuras, u, "HARMFUL|CROWD_CONTROL")
    show("IMPORTANT (non-def) auras", C_UnitAuras.GetUnitAuras, u, "HELPFUL|IMPORTANT|!BIG_DEFENSIVE|!EXTERNAL_DEFENSIVE")
    show("GetRaidTargetIndex", GetRaidTargetIndex, u)
    show("UnitPowerMax mana", UnitPowerMax, u, 0)
    show("UnitHealthMax", UnitHealthMax, u)
    show("UnitPowerType", UnitPowerType, u)
    show("target's target is you", UnitIsUnit, u .. "target", "player")
    show("raid1target name", UnitName, "raid1target")
    show("nearest band (yards) / secret answer", Core.NearestBand, u)
  end
  show("rows bound (row1 macro)", function()
    return WarboardRow1 and WarboardRow1:GetAttribute("macrotext1")
  end)
  Core.db.lastProbe = { t = date("%Y-%m-%d %H:%M:%S"), lines = out }
  say("saved to SavedVariables (written on /reload or logout)")
end
