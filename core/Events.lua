local ADDON, ns = ...
local Core = ns.Core
local Options = ns.Options

local ev = CreateFrame("Frame")
function Core.Reg(event)
  pcall(ev.RegisterEvent, ev, event)
end

ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    WarboardDB = WarboardDB or {}
    Core.db = WarboardDB
    for k, v in pairs(Core.DEFAULTS) do
      if Core.db[k] == nil then
        Core.db[k] = type(v) == "table" and {} or v
      end
    end
    ns.InitializeUIScale()
    for _, profile in pairs(type(Core.db.profiles) == "table" and Core.db.profiles or {}) do
      if type(profile) == "table" and type(profile.points) == "table" then ns.NormalizePointSettings(profile.points) end
    end
    if (Core.db.sniperVersion or 1) < 4 then
      Core.db.sniperY, Core.db.sniperVersion = -62, 4 -- scope sits on the upper torso
    end
    if (Core.db.soundVersion or 1) < 2 then
      Core.db.sniperSound, Core.db.soundVersion = 1, 2 -- custom lock-on sound is the new default
    end
    if (Core.db.rowsVersion or 1) < 2 then
      -- Rows used to default to 10: show the whole enemy team instead.
      if Core.db.rows == 10 then Core.db.rows = Core.MAX_ROWS end
      Core.db.rowsVersion = 2
    end
    if (Core.db.gyLearnedVersion or 1) < 2 then
      -- Start areas learned before the side was confirmed may carry the
      -- wrong team (cross-faction games); they are relearned on release.
      for _, list in pairs(type(Core.db.gyLearned) == "table" and Core.db.gyLearned or {}) do
        for i = #list, 1, -1 do
          if list[i].fromPlace then table.remove(list, i) end
        end
      end
      Core.db.gyLearnedVersion = 2
    end
    -- Per-character window positions, seeded once from the old account-wide
    -- ones so an existing layout doesn't move.
    WarboardCharDB = type(WarboardCharDB) == "table" and WarboardCharDB or {}
    Core.pos = WarboardCharDB
    if not Core.pos.seeded then
      for _, key in ipairs(Core.POSITION_KEYS) do
        if Core.pos[key] == nil and type(Core.db[key]) == "table" then
          Core.pos[key] = { unpack(Core.db[key]) }
        end
      end
      Core.pos.seeded = true
    end
    Core.myRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or ""
    Core.db.apiMissing = {}
    for _, name in ipairs(Core.API_USED) do
      if type(_G[name]) ~= "function" then
        Core.db.apiMissing[#Core.db.apiMissing + 1] = name
      end
    end
    Core.BuildSpecLookup()
    Core.BuildKits()
    Core.NormalizeTuning(Core.db)
    Core.db.points = Core.db.points or {}
    if Core.PruneCaptureLogs then Core.PruneCaptureLogs() end
    Core.db.healthErr = nil -- first health error of this session only; old ones are fixed
    if Core.db.capProbeOn and Core.SetCapProbe and not Core.IS_RETAIL then Core.SetCapProbe(true) end
    Options.Register()
    Core.BuildCurve()
    ns.ApplyUIScale()
    Core.frame:ClearAllPoints()
    local point = Core.pos.point
    if point then
      Core.frame:SetPoint(point[1], UIParent, point[2], point[3], point[4])
    else
      Core.frame:SetPoint("RIGHT", UIParent, "RIGHT", -260, 80)
    end
    if Core.ApplyStyle then Core.ApplyStyle() end
  elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    if event == "PLAYER_ENTERING_WORLD" and not Core.testMode then
      ns.MatchSerial = (ns.MatchSerial or 0) + 1
      wipe(Core.enemies)
      wipe(Core.order)
      Core.allyFaction, Core.currentBG, Core.currentProfile, Core.mapKey = nil, nil, nil, nil
      Core.obj.mode, Core.obj.assaultStart = nil, nil
      ns.flagRespawnAt = nil
      if Core.active then Core.ObjectiveStart() end
    end
    Core.myRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or Core.myRealm
    if not ns.MapWhere and not ns.mapWarned then
      ns.mapWarned = true
      print("|cffff5533Warboard|r intel map not loaded yet: restart the game client fully once (new file).")
    end
    Core.CheckZone()
  elseif event == "UPDATE_BATTLEFIELD_SCORE" then
    if not Core.active then
      Core.CheckZone()
    end
    if Core.active then
      Core.Guard("roster", Core.RefreshRoster)
    end
    if C_PvP.IsMatchComplete and C_PvP.IsMatchComplete() then
      Core.HarvestHistory()
    end
  elseif event == "PVP_MATCH_COMPLETE" then
    Core.HarvestHistory()
  elseif event == "CHAT_MSG_BG_SYSTEM_ALLIANCE" or event == "CHAT_MSG_BG_SYSTEM_HORDE"
    or event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
    Core.OnObjectiveChat(event, arg1)
  elseif event == "NAME_PLATE_UNIT_REMOVED" then
    if arg1 == Core.sniper.unit then
      Core.sniper:Hide()
      Core.sniper.pulse:Stop()
      Core.sniper.anchor, Core.sniper.unit = nil, nil
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    if Core.active then
      Core.Tick()
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    ns.ApplyUIScale()
    Core.UpdateTargetButton()
    if Core.layoutPending then
      Core.frame:SetShown(Core.active and Core.db.killorder ~= false)
      Core.Layout()
    end
    if Core.active then Core.Guard("render", Core.Render) end
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ACTIVE_TALENT_GROUP_CHANGED"
    or event == "PLAYER_TALENT_UPDATE" then
    Core.UpdateMe()
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if Core.active and not Core.testMode then
      Core.OnCombatLog()
    end
  end
end)

Core.Reg("ADDON_LOADED")
Core.Reg("PLAYER_ENTERING_WORLD")
Core.Reg("ZONE_CHANGED_NEW_AREA")
Core.Reg("UPDATE_BATTLEFIELD_SCORE")
Core.Reg("PVP_MATCH_COMPLETE")
Core.Reg("PLAYER_REGEN_ENABLED")
Core.Reg("PLAYER_TARGET_CHANGED")
Core.Reg("NAME_PLATE_UNIT_REMOVED")
Core.Reg("CHAT_MSG_BG_SYSTEM_ALLIANCE")
Core.Reg("CHAT_MSG_BG_SYSTEM_HORDE")
Core.Reg("CHAT_MSG_BG_SYSTEM_NEUTRAL")
Core.Reg("PLAYER_SPECIALIZATION_CHANGED")
Core.Reg("ACTIVE_TALENT_GROUP_CHANGED")
Core.Reg("PLAYER_TALENT_UPDATE")
if not Core.IS_RETAIL and CombatLogGetCurrentEventInfo and ns.Defensives then
  Core.Reg("COMBAT_LOG_EVENT_UNFILTERED")
end
