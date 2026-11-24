local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Objectives: flag / orb carriers and their stacks
--
-- Carrier stacks can't be read off enemy units in Midnight (aura data is
-- secret), so they're simulated like BattleGroundEnemiesFixed does:
--   WSG / Twin Peaks: one shared Focused Assault clock, starts when BOTH flags
--     are held, +1 stack per 30s (15s in Blitz); drops keep it running; a
--     capture, both flags home, or match end resets it.
--   Temple of Kotmogu: per-orb clock, 30% on pickup, +30% per 15s held.
--   Eye of the Storm / Deephaul Ravine: carrier only, no stacking debuff.
-- Carrier identity: BG system chat (English client) + arena1-4 tokens, which
-- Blizzard assigns to objective carriers in battlegrounds.
---------------------------------------------------------------------------
-- Battleground identity. UI map IDs (C_Map.GetBestMapForUnit) are the ones
-- BattleGroundEnemiesFixed verified in-game; instance IDs (8th return of
-- GetInstanceInfo) are the fallback. What the game actually reports is saved
-- to HighgroundDB.mapSeen so unknown/new maps can be added.
-- Identities and client/mode rules live in config/battlegrounds/*.lua.

-- Rated battleground (RBG): Cata's global, retail's C_PvP query.
function Core.IsRatedBG()
  local fn = ns.Api.Fn("C_PvP", "IsRatedBattleground")
  if not fn then return false end
  local ok, rated = pcall(fn)
  return ok and Core.plain(rated) and rated == true or false
end

-- Runs every tick: resolve again only when the map, instance or mode changes.
local lastUI, lastInst, lastMode
function Core.DetectMap()
  local ui = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local name, _, _, _, _, _, _, inst = GetInstanceInfo()
  Core.isBlitz = ns.Caps.blitz and C_PvP and C_PvP.IsSoloRBG and C_PvP.IsSoloRBG() or false
  Core.isRated = not Core.isBlitz and Core.IsRatedBG() or false
  local mode = Core.isBlitz and "blitz" or Core.isRated and "rated" or "standard"
  if Core.mapKey and ui == lastUI and inst == lastInst and mode == lastMode then return false end
  lastUI, lastInst, lastMode = ui, inst, mode
  local bg = ns.ResolveBattleground(ui, inst, ns.CLIENT, mode)
  local key = bg and bg.rulesKey or (tostring(ui) .. ":" .. tostring(inst) .. ":" .. tostring(Core.isBlitz))
  if key == Core.mapKey then
    return false
  end
  Core.mapKey = key
  Core.currentBG = bg
  Core.currentProfile = Core.currentBG and Core.currentBG.rules.priority or nil
  Core.db.mapSeen = Core.db.mapSeen or {}
  Core.db.mapSeen[tostring(name)] = { ui = ui, inst = inst, matched = Core.currentBG and Core.currentBG.name or false }
  return true
end

Core.obj = { mode = nil, assaultStart = nil, allyHas = false, hordeHas = false, trusted = false }

function Core.ObjectiveStart()
  Core.DetectMap()
  Core.obj.mode = Core.currentBG and Core.currentBG.rules.objective or nil
  ns.flagRespawnAt, Core.flagCapturedAt = nil, nil
  Core.obj.assaultStart, Core.obj.allyHas, Core.obj.hordeHas = nil, false, false
  -- Joined mid-match: an unseen assault clock may already be running, so
  -- don't trust stack counts until both flags are seen home.
  local runtime = GetBattlefieldInstanceRunTime and GetBattlefieldInstanceRunTime() or 0
  Core.obj.trusted = runtime < 90000
end

function Core.FlagStacks()
  if Core.obj.mode ~= "flag" or not Core.obj.assaultStart then
    return nil
  end
  return ns.AssaultStacks(time() - Core.obj.assaultStart, Core.currentBG and Core.currentBG.rules.flags)
end

-- Stack value shown/scored for a carrier: flag stack count, or orb %.
function Core.CarrierStacks(e)
  if e.testStacks then
    return e.testStacks
  end
  if not e.carrier then
    return nil
  end
  if Core.obj.mode == "flag" then
    return Core.FlagStacks()
  elseif Core.obj.mode == "orb" and e.orbSince then
    local rules = Core.currentBG and Core.currentBG.rules.orbs
    if rules then
      return rules.initialPercent + math.floor((time() - e.orbSince) / rules.interval) * rules.stepPercent
    end
  end
end

-- Whether you or a teammate has this first name (UnitName's first part on
-- WoW Forever, where the second return is a surname).
local function TeamFirstName(name)
  if ns.Util.read(UnitName, "player") == name then return true end
  local units, n = ns.UnitTokens.Group()
  for i = 1, n do
    if ns.Util.read(UnitName, units[i]) == name then return true end
  end
  return false
end

function Core.EnemyByChatName(name)
  if type(name) ~= "string" then
    return nil
  end
  name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local key = Core.Canon(name)
  if key and Core.enemies[key] then
    return Core.enemies[key]
  end
  -- A unique short name, else (WoW Forever: first name and surname) a unique
  -- first name; Forever announcements can use the first name alone.
  local found, first
  for _, e in pairs(Core.enemies) do
    local short = e.display:match("^[^-]+")
    if short == name then
      if found then
        return nil -- ambiguous short name
      end
      found = e
    elseif Core.FirstName(short) == name then
      first = first == nil and e or false -- false: ambiguous first name
    end
  end
  if found then return found end
  -- A first name you or a teammate also goes by could be either team's.
  if first and TeamFirstName(name) then return nil end
  return first or nil
end

function Core.ClearCarriers()
  for _, e in pairs(Core.enemies) do
    e.carrier, e.orbSince = false, nil
  end
end

function Core.ResetAssault()
  Core.obj.assaultStart, Core.obj.allyHas, Core.obj.hordeHas = nil, false, false
  Core.obj.trusted = true
end

function Core.OnObjectiveChat(event, msg)
  if not Core.active or not Core.obj.mode or type(msg) ~= "string" or Core.issecret(msg) then
    return
  end
  if ns.LocalizedChat then msg = ns.LocalizedChat(msg) end
  if Core.obj.mode == "carry" then
    -- Eye of the Storm (and Deephaul Ravine): one neutral flag.
    --   "X has taken the flag!"  "The flag has been dropped."
    --   "The Alliance have captured the flag!"  (respawns after 21s)
    local taker = msg:match("^(.+) has taken the flag!")
    if taker then
      Core.ClearCarriers()
      Core.flagCapturedAt = nil -- picked up: no reset to time
      local e = Core.EnemyByChatName(taker)
      if e then
        e.carrier = true -- your own team's carrier: no enemy carrier
      end
      return
    end
    if msg:find("flag has been dropped") or msg:find("flag has been reset") or msg:find("captured the") then
      Core.ClearCarriers()
      local now, Timers = GetTime(), ns.Timers
      if msg:find("captured the") then
        local seconds = Timers and Timers.FlagRespawnTime()
        Core.flagCapturedAt, ns.flagRespawnAt = now, seconds and (now + seconds) or nil
      elseif msg:find("flag has been reset") and Core.flagCapturedAt then
        -- The capture's flag is back: learn the gap for the next countdown.
        if Timers then Timers.LearnFlagRespawn(now - Core.flagCapturedAt) end
        Core.flagCapturedAt, ns.flagRespawnAt = nil, nil
      else
        Core.flagCapturedAt = nil
      end
      return
    end
  end
  if event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
    if msg:find("placed at their bases") or msg:find("wins") then
      Core.ResetAssault()
      Core.ClearCarriers()
      -- Flags back after a capture: learn the gap for the next countdown.
      local Timers = ns.Timers
      if Core.flagCapturedAt and Timers and msg:find("placed at their bases") then
        Timers.LearnFlagRespawn(GetTime() - Core.flagCapturedAt)
      end
      Core.flagCapturedAt, ns.flagRespawnAt = nil, nil
    end
    return
  end
  -- "The Horde flag was picked up by X": the flag's name, not the chat
  -- channel (the carrier's character faction in cross-faction games).
  local flagName = msg:match("The (%a+) [Ff]lag")
  local allianceChannel = flagName and flagName == "Horde" or (not flagName and event == "CHAT_MSG_BG_SYSTEM_ALLIANCE")

  if Core.obj.mode == "orb" then
    local who = msg:match("^(.-) has taken the")
    if who and Core.IsMe(who) then Core.playerObjective = GetTime() end
    local e = who and Core.EnemyByChatName(who)
    if e then
      e.carrier, e.orbSince, e.carrierSeen = true, time(), GetTime()
    end
    return
  end

  local picker = msg:match("picked up by (.+)!")
  local dropper = msg:match("dropped by (.+)!")
  if picker then
    local e = Core.EnemyByChatName(picker)
    if e then
      Core.ClearCarriers() -- one enemy carrier at a time on flag maps
      e.carrier = true
    end
    if Core.obj.mode == "flag" then
      if allianceChannel then Core.obj.hordeHas = true else Core.obj.allyHas = true end
      if Core.obj.trusted and Core.obj.allyHas and Core.obj.hordeHas and not Core.obj.assaultStart then
        Core.obj.assaultStart = time()
      end
    end
  elseif dropper then
    local e = Core.EnemyByChatName(dropper)
    if e then
      e.carrier = false
    end
    if Core.obj.mode == "flag" then
      if allianceChannel then Core.obj.hordeHas = false else Core.obj.allyHas = false end
    end
  elseif msg:find("returned to its base") then
    if Core.obj.mode == "flag" then
      if allianceChannel then Core.obj.hordeHas = false else Core.obj.allyHas = false end
      if not Core.obj.allyHas and not Core.obj.hordeHas then
        Core.ResetAssault()
      end
    end
  elseif msg:find("captured the") then
    Core.ClearCarriers()
    if Core.obj.mode == "flag" then
      Core.ResetAssault()
      -- Both flags return together, announced as "placed at their bases";
      -- the winning capture returns none.
      local now, Timers = GetTime(), ns.Timers
      local over = ns.Util.read(C_PvP and C_PvP.IsMatchComplete) == true
      local seconds = Timers and not over and Timers.FlagRespawnTime()
      Core.flagCapturedAt, ns.flagRespawnAt = not over and now or nil, seconds and (now + seconds) or nil
    end
  end
end

-- Arena tokens point at objective carriers anywhere on the map.
function Core.ScanCarrierTokens()
  if not Core.obj.mode then
    return
  end
  local now = GetTime()
  -- Orbs have no reliable drop message: a carrier whose arena token has been
  -- gone for 3s, or who died, no longer holds an orb (it resets on drop).
  if Core.obj.mode == "orb" then
    for _, e in pairs(Core.enemies) do
      if e.carrier and (e.dead or now - (e.carrierSeen or 0) > 3) then
        e.carrier, e.orbSince = false, nil
      end
    end
  end
  for i = 1, 4 do
    local unit = ns.UnitTokens.arena[i]
    local ok, exists = pcall(UnitExists, unit)
    if ok and Core.plain(exists) and exists then
      local key = Core.TickKey(unit)
      local e = key and Core.enemies[key]
      if e then
        if Core.obj.mode ~= "orb" and not e.carrier then
          Core.ClearCarriers()
        end
        e.carrier = true
        e.carrierSeen = now
        if Core.obj.mode == "orb" and not e.orbSince then
          e.orbSince = time() -- pickup missed: seed at base value
        end
      end
    end
  end
end
