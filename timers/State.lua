local _, ns = ...
ns.Timers = {}
local Timers = ns.Timers

-- Battleground timers: base captures and resurrection waves, for both
-- teams, per location. Shown in the Warboard panel (strip under the hero
-- card) and on the map (map/Pins.lua layer). All automatic.
--
-- Base captures: map POIs change icon when a base is assaulted (the
-- "contested" icon set Capping uses on this client). Assault -> countdown
-- (duration from the battleground rules); owner from the POI's factionID / icon /
-- how the contest ended.
--
-- Res waves use the configured period and an observed spirit-guide clock.
-- Sources, best first:
--   1. you are dead:  GetAreaSpiritHealerTime()       exact, your team
--   2. a teammate goes ghost -> alive                   exact (+-0.25s)
--   3. a base is captured: its graveyard starts its clock then  approx
--   4. enemy Spirit Guide spell in the combat log       exact, enemy team
--   5. an enemy dies, then is seen again: the wave was in between. Every
--      such interval votes; the clock is where the votes pile up   estimate
-- Graveyard positions are learned from where people come back to life and
-- saved per map for next time. Teammates running Warboard share 1 and 5.

Timers.PREFIX = "WarboardT"
Timers.ALLY_COLOR, Timers.ENEMY_COLOR = { 0.35, 0.8, 1 }, { 1, 0.32, 0.3 }
Timers.FACTION_TEAM = { [469] = "A", [67] = "H", [1] = "A", [0] = "H" }

function Timers.plain(v)
  return not (issecretvalue and issecretvalue(v)) and v ~= nil
end

function Timers.DB()
  return ns.GetDB and ns.GetDB()
end

function Timers.Rules()
  return ns.GetBGRules and ns.GetBGRules() or {}
end

function Timers.RulesKey()
  local bg = ns.GetBG and ns.GetBG()
  return bg and bg.rulesKey
end

function Timers.WavePeriod()
  local res = Timers.Rules().resurrection
  return res and res.period
end

function Timers.Enabled()
  local db = Timers.DB()
  return db and db.timers ~= false
end

Timers.stats = { waves = 0, votes = 0, guide = 0, caps = 0, sent = 0, recv = 0 }

function Timers.Try(stage, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then
    Timers.stats.errors = (Timers.stats.errors or 0) + 1
    Timers.stats.lastError = Timers.stats.lastError or (stage .. ": " .. tostring(err))
  end
end

function Timers.MyTeam()
  local f = ns.GetAllyFaction and ns.GetAllyFaction()
  if f == 1 then
    return "A"
  elseif f == 0 then
    return "H"
  end
  return UnitFactionGroup("player") == "Alliance" and "A" or "H"
end

function Timers.Other(team)
  return team == "A" and "H" or "A"
end

-- Team of a player named in a battleground announcement. Cross-faction
-- games announce on the character's faction channel, so the channel does
-- not tell the team; your group and the scoreboard's enemies do.
function Timers.TeamOfName(name)
  if type(name) ~= "string" or not Timers.plain(name) then return nil end
  local short = name:match("^[^-]+")
  if short == UnitName("player") then return Timers.MyTeam() end
  local raid = IsInRaid and IsInRaid()
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  for i = 1, raid and n or math.max(n - 1, 0) do
    local ok, member = pcall(UnitName, (raid and "raid" or "party") .. i)
    if ok and Timers.plain(member) and member == short then return Timers.MyTeam() end
  end
  if ns.EnemyKeyByName and ns.EnemyKeyByName(name) then return Timers.Other(Timers.MyTeam()) end
end

function Timers.MapID()
  return ns.CurrentMapID and ns.CurrentMapID()
end

-- Where a unit is: coordinates when the client gives them, else its area
-- (sub-zone) and that area's anchor on the map (map/Areas.lua).
-- A zone-wide area name ("Twin Peaks") doesn't identify a graveyard: drop it.
function Timers.Loc(unit, name)
  local m = Timers.MapID()
  if m and ns.Locate then
    local x, y, area, how = ns.Locate(m, unit, name)
    if area and ns.IsZoneName and ns.IsZoneName(m, area) then
      area = nil
    end
    return x, y, area, how
  end
end

function Timers.XY(unit)
  local m = Timers.MapID()
  if m and ns.UnitXY then
    return ns.UnitXY(m, unit)
  end
end

function Timers.Place(x, y)
  return ns.Place and ns.Place(x, y) or "?"
end

function Timers.Clock(sec)
  sec = math.max(0, math.floor(sec + 0.5))
  if sec >= 60 then
    return string.format("%d:%02d", sec / 60, sec % 60)
  end
  return sec .. "s"
end

---------------------------------------------------------------------------
-- State (wiped when the map changes)
---------------------------------------------------------------------------
Timers.nodes = {} -- [poiName] = { x, y, icon, owner, assault, capStart, capEnd }
Timers.gys = {} -- list of { team, x, y, label, wave, conf, bins, votes, node }
Timers.guideGY = {} -- [spirit guide GUID] = gy

Timers.ghost, Timers.pendingRez, Timers.lastGuide, Timers.outbox, Timers.track = {}, {}, {}, {}, {}

Timers.gameGYs = {} -- [mapID] = { {name, x, y} } | false: the game's own graveyard list
