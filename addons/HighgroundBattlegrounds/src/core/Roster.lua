local _, ns = ...
local Core = ns.Core

-- Roster (scoreboard)
---------------------------------------------------------------------------
-- One scoreboard row as a table. Retail: C_PvP.GetScoreInfo. Cata Classic
-- 4.4.2 only has GetBattlefieldScore; talentSpec is its 16th return and is
-- readable mid-match there.
-- Scoreboard class -> class token. Some servers send the class name
-- ("Death Knight") where the token ("DEATHKNIGHT") belongs: drop spaces, else
-- match the client's localized class names.
function Core.ClassToken(value)
  if type(value) ~= "string" or not Core.plain(value) then return nil end
  local token = value:upper():gsub("[%s_%-]", "")
  if RAID_CLASS_COLORS and RAID_CLASS_COLORS[token] then return token end
  for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
    for t, localized in pairs(names) do
      if localized == value then return t end
    end
  end
  return token
end

function Core.ScoreInfo(idx)
  if C_PvP and C_PvP.GetScoreInfo then
    return C_PvP.GetScoreInfo(idx)
  end
  local name, _, _, _, _, faction, _, class, classToken, _, _, _, _, _, _, talentSpec = GetBattlefieldScore(idx)
  if name then
    return { name = name, faction = faction, classToken = Core.ClassToken(classToken) or Core.ClassToken(class),
      talentSpec = talentSpec }
  end
end

function Core.RaidNames()
  local set = {}
  set[Core.CanonUnit("player") or ""] = true
  for i = 1, GetNumGroupMembers() or 0 do
    local name = GetRaidRosterInfo(i)
    local key = Core.Canon(name)
    if key then
      set[key] = true
    end
  end
  return set
end

local resettingFilter = false
-- Core.rosterStatus explains an empty roster in /hg err and probe.

-- Reused per refresh: the scoreboard is read every few seconds and on each
-- score event. rows[1..count] are this refresh's readable rows.
local rows, count, factions, seen = {}, 0, {}, {}

-- One scoreboard row: name, class token, faction, spec (Cata's 16th return).
local function ReadRow(idx)
  if C_PvP and C_PvP.GetScoreInfo then
    local info = C_PvP.GetScoreInfo(idx)
    if info then return info.name, info.classToken, info.faction, info.talentSpec end
    return
  end
  local name, _, _, _, _, faction, _, class, classToken, _, _, _, _, _, _, talentSpec = GetBattlefieldScore(idx)
  if name then return name, Core.ClassToken(classToken) or Core.ClassToken(class), faction, talentSpec end
end

function Core.RefreshRoster()
  if Core.testMode then
    return
  end
  Core.rosterAt, Core.rosterDirty = GetTime(), nil
  local n = GetNumBattlefieldScores() or 0
  count = 0
  -- Why rows get skipped, saved for diagnosis (HighgroundDB.rosterDebug).
  local dbg = Core.db.rosterDebug or {}
  wipe(dbg)
  dbg.t, dbg.scores, dbg.noInfo, dbg.badName, dbg.badClass, dbg.badFaction = date("%H:%M:%S"), n, 0, 0, 0, 0
  for idx = 1, n do
    local name, class, faction, spec = ReadRow(idx)
    if name == nil then
      dbg.noInfo = dbg.noInfo + 1
    else
      local key = Core.Canon(name)
      if not key then
        dbg.badName = dbg.badName + 1
      elseif not Core.plain(class) then
        dbg.badClass = dbg.badClass + 1
      elseif not Core.plain(faction) then
        dbg.badFaction = dbg.badFaction + 1
      else
        count = count + 1
        local r = rows[count] or {}
        rows[count] = r
        r.key, r.class, r.faction, r.spec = key, class, faction, spec
      end
    end
  end
  for i = count + 1, #rows do rows[i] = nil end
  dbg.rows = #rows
  dbg.allyFaction = Core.allyFaction
  local ok, st = pcall(C_PvP and C_PvP.GetActiveMatchState)
  dbg.matchState = ok and Core.plain(st) and st or nil
  Core.db.rosterDebug = dbg
  if n == 0 then
    Core.rosterStatus = ns.Locale:Get("battlegrounds.roster.no_scoreboard_yet.fa0ffc")
    return
  end

  -- Your own scoreboard row is the most reliable team source: scoreboard
  -- names are NeverSecret, while group roster names may come back secret.
  -- Read it before waiting for the enemy team, since battlegrounds can be
  -- cross-faction and the character's own faction is not your side.
  if Core.allyFaction == nil then
    local myKey = Core.CanonUnit("player")
    for _, r in ipairs(rows) do
      if r.key == myKey then
        Core.allyFaction = r.faction
        break
      end
    end
  end

  -- Scoreboard filtered to one team (a faction tab was clicked): reset it to
  -- both teams once the scoreboard window is closed, and keep current state.
  wipe(factions)
  local nf = 0
  for _, r in ipairs(rows) do
    if not factions[r.faction] then
      factions[r.faction] = true
      nf = nf + 1
    end
  end
  if nf < 2 then
    local board = PVPMatchScoreboard or WorldStateScoreFrame
    if not (board and board:IsShown()) and SetBattlefieldScoreFaction and not resettingFilter then
      resettingFilter = true
      pcall(SetBattlefieldScoreFaction, -1)
      resettingFilter = false
      Core.RequestScores()
    end
    Core.rosterStatus = nf == 0 and ns.Locale:Get("battlegrounds.roster.scoreboard_rows_unreadable.69cd7f") or ns.Locale:Get("battlegrounds.roster.enemy_team_not_on_scoreboard_yet.dd2ad1")
    dbg.status = Core.rosterStatus
    return
  end

  if Core.allyFaction == nil then
    local raid, votes = Core.RaidNames(), {}
    for _, r in ipairs(rows) do
      if raid[r.key] then
        votes[r.faction] = (votes[r.faction] or 0) + 1
      end
    end
    local best, bestN = nil, 1 -- need at least two matching group members
    for f, c in pairs(votes) do
      if c > bestN then
        best, bestN = f, c
      end
    end
    Core.allyFaction = best
  end
  if Core.allyFaction == nil and GetBattlefieldArenaFaction then
    local ok, f = pcall(GetBattlefieldArenaFaction)
    if ok and Core.plain(f) and factions[f] then
      Core.allyFaction = f
    end
  end
  if Core.allyFaction == nil then
    Core.rosterStatus = ns.Locale:Get("battlegrounds.roster.can_t_tell_which_team_is_yours.f944a6")
    dbg.status = Core.rosterStatus
    return
  end
  Core.rosterStatus = nil

  -- A read with only one team means Blizzard's scoreboard is filtered (a
  -- faction tab was clicked, e.g. while dead) or still loading. Never drop
  -- enemies on such a read; reset the filter once the scoreboard is closed.
  local allyRows, enemyRows = 0, 0
  for _, r in ipairs(rows) do
    if r.faction == Core.allyFaction then
      allyRows = allyRows + 1
    else
      enemyRows = enemyRows + 1
    end
  end
  if allyRows == 0 or enemyRows == 0 then
    local board = PVPMatchScoreboard or WorldStateScoreFrame
    if not (board and board:IsShown()) and SetBattlefieldScoreFaction and not resettingFilter then
      resettingFilter = true
      SetBattlefieldScoreFaction(-1)
      resettingFilter = false
      Core.RequestScores()
    end
    return
  end

  wipe(seen)
  for _, r in ipairs(rows) do
    if r.faction ~= Core.allyFaction then
      seen[r.key] = true
      local e = Core.enemies[r.key]
      if not e then
        e = { key = r.key, display = Core.DisplayName(r.key) }
        Core.enemies[r.key] = e
      end
      e.class = r.class
      local spec = r.spec
      -- Raw scoreboard spec, possibly secret: only ever handed to SetText.
      -- A class name repeats the row's icon and colour, so it is not kept;
      -- WoW Forever reports the class there, readable or not.
      e.specLive = nil
      local className = ns.Util.ClassName(r.class)
      if type(spec) == "string" and ns.GAME ~= "forever" and not (Core.plain(spec) and className
        and spec:lower() == tostring(className):lower()) then
        e.specLive = spec
      end
      if Core.plain(spec) and type(spec) == "string" and spec ~= "" and Core.specByName[r.class] then
        local id = Core.specByName[r.class][spec]
        if id then
          e.specID, e.specSrc, e.specReason = id, "live", nil
          e.liveSpecAt = GetTime()
        end
      end
      if not e.specID then
        e.specID = Core.HistoricSpec(r.key, r.class)
        e.specSrc = e.specID and "hist" or nil
      end
      if e.specSrc ~= "tag" and Core.ApplySpecTag then Core.ApplySpecTag(e) end
    end
  end
  for key in pairs(Core.enemies) do
    if not seen[key] then
      Core.enemies[key] = nil
    end
  end
end

-- Remembered specs: at most HISTORY_MAX names per region, none unseen for
-- HISTORY_DAYS; the most recently seen are kept. Damaged entries go first.
Core.HISTORY_MAX, Core.HISTORY_DAYS = 4000, 120
local function Seen(h) return type(h) == "table" and tonumber(h.t) or -math.huge end
local function OldestFirst(a, b) return a[2] < b[2] end
local prunedMatch
-- WoW Forever's scoreboard names the class where the spec goes, and
-- earlier versions saved that as history: it is no spec, so it goes too.
local function ClassOnly(h)
  if type(h) ~= "table" or type(h.spec) ~= "string" or type(h.class) ~= "string" then return false end
  local spec = h.spec:lower()
  local female = LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[h.class]
  for _, name in ipairs({ ns.Util.ClassName(h.class), female or false }) do
    if type(name) == "string" and spec == name:lower() then return true end
  end
  return false
end
function Core.PruneHistory(history, now)
  local cutoff, count = now - Core.HISTORY_DAYS * 86400, 0
  for key, h in pairs(history) do
    if Seen(h) < cutoff or ClassOnly(h) then history[key] = nil else count = count + 1 end
  end
  if count <= Core.HISTORY_MAX then return end
  local list = {}
  for key, h in pairs(history) do list[#list + 1] = { key, Seen(h) } end
  table.sort(list, OldestFirst)
  for i = 1, count - Core.HISTORY_MAX do history[list[i][1]] = nil end
end

-- After the match, specs are no longer secret: remember them for next time.
function Core.HarvestHistory()
  for idx = 1, GetNumBattlefieldScores() or 0 do
    local info = Core.ScoreInfo(idx)
    if info then
      local key = Core.Canon(info.name)
      local class, spec = info.classToken, info.talentSpec
      local id = key and Core.plain(class) and Core.plain(spec) and type(spec) == "string"
        and Core.specByName[class] and Core.specByName[class][spec]
      -- Only a spec this client knows: WoW Forever reports the class there.
      if id then
        ns.Scope.Saved("history", "social")[key] = { class = class, spec = spec, t = time() }
        local e = Core.enemies[key]
        if e then Core.RecordSpecMana(e, id) end
        if e and (e.maxMana or e.maxHP) and not e.fingerprinted then
          e.fingerprinted = true
          local fingerprints = ns.Scope.Saved("fingerprints", "rules")
          local fp = class .. "/" .. spec
          local list = ns.Saved.Table(fingerprints, fp)
          list[#list + 1] = { mana = e.maxMana, hp = e.maxHP }
          if #list > 50 then
            table.remove(list, 1)
          end
        end
      end
    end
  end
  -- Scoreboard updates repeat after a match ends: prune once per match.
  if prunedMatch ~= (ns.MatchSerial or 0) then
    prunedMatch = ns.MatchSerial or 0
    Core.PruneHistory(ns.Scope.Saved("history", "social"), time())
    Core.PruneHistory(ns.Scope.Saved("specTags", "social"), time())
  end
end
