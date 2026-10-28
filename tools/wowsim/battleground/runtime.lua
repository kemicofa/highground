---------------------------------------------------------------------------
-- The repository's WoW simulator (tools/wowsim) plus a battleground
-- boundary, for Highground and Highground Battlegrounds: scoreboard, PvP state, area POIs, flags,
-- graveyards, the map canvases (maps.lua), sim:join/joinArena/leave,
-- sim:enemy/entry/poi, sim:command (/hg) and the health, intel, pressure
-- and pin errors Highground records.
--
--   local new = dofile("../../tools/wowsim/battleground/runtime.lua")
--   local sim = new(client, saved, configure)
--
-- Run from an addon's folder. The addon defaults to Highground; configure(sim)
-- runs after this extension, before the TOC loads (see ../runtime.lua for
-- its fields).
---------------------------------------------------------------------------
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "../../tools/wowsim/battleground/"
local wowsim = dofile(HERE .. "../runtime.lua")

local Battleground = {}

function Battleground:command(text) self:slash("HIGHGROUND", text, "/hg " .. text) end

function Battleground:join(mapID, instanceID, name)
  self.mapID, self.instanceID, self.mapName = mapID or 93, instanceID or 529, name or "Arathi Basin"
  self.inBG, self.matchStart, self.matchComplete = true, self.now, false
  self:event("PLAYER_ENTERING_WORLD")
  self:event("UPDATE_BATTLEFIELD_SCORE")
  self:advance(1)
end

function Battleground:joinArena()
  self.inArena = true
  self:event("PLAYER_ENTERING_WORLD")
  self:advance(1)
end

function Battleground:leave()
  self.inBG, self.inArena = false, false
  self:event("PLAYER_ENTERING_WORLD")
  self:advance(1)
end

-- A scoreboard enemy with a nameplate unit; returns the unit and token.
function Battleground:enemy(name, fields)
  fields = fields or {}
  fields.name, fields.enemy = name, true
  fields.classID, fields.yards = fields.classID or 8, fields.yards or 20
  local token = "nameplate" .. (#self.scores)
  self.units[token] = fields
  self.plates[token] = self.env.CreateFrame("Frame", nil, self.env.UIParent)
  local _, class = self.env.UnitClass(token)
  local _, spec = self.env.GetSpecializationInfoForClassID(fields.classID, fields.specIndex or 1)
  self.scores[#self.scores + 1] = { name = name .. "-Realm", classToken = class,
    faction = 1 - (self.faction or 1), talentSpec = spec }
  return fields, token
end

function Battleground:entry(name) return self.ns.enemies[name .. "-Realm"] end

function Battleground:poi(icon)
  self.pois[1] = { name = "Stables", position = { x = 0.2, y = 0.3 }, textureIndex = icon }
  self:event("AREA_POIS_UPDATED")
end

-- Errors Highground keeps outside the error log.
local function highgroundErrors(sim, db)
  local errors = {}
  for _, value in ipairs({ db.healthErr or false, db.intelErr or false, db.pressureError or false,
    sim.ns.pinStats and sim.ns.pinStats.lastError or false }) do
    if value then errors[#errors + 1] = tostring(value) end
  end
  return errors
end

-- Replaces the generic IsInGroup, IsInInstance and GetInstanceInfo: in
-- Highground's scenarios sim.inBG and sim.inArena drive them.
local function battlegroundAPI(sim, env)
  env.IsInGroup = function() return sim.inBG end
  env.IsInInstance = function()
    if sim.inArena then return true, "arena" end
    return sim.inBG, sim.inBG and "pvp" or "none"
  end
  env.GetInstanceInfo = function() return sim.mapName, "pvp", 0, "", 10, 0, false, sim.instanceID end
  env.GetNumBattlefieldScores = function() return #sim.scores end
  env.GetBattlefieldScore = function(index)
    local row = sim.scores[index]; if not row then return end
    return row.name, 0, 0, 0, 0, row.faction, "Human", "Class", row.classToken, 0, 0, 0, 0, 0, 0, row.talentSpec
  end
  env.GetBattlefieldArenaFaction = function() return sim.faction or 1 end
  env.GetBattlefieldInstanceRunTime = function() return (sim.now - sim.matchStart) * 1000 end
  env.RequestBattlefieldScoreData = function() sim.scoreRequests = sim.scoreRequests + 1 end
  env.SetBattlefieldScoreFaction = function(value) sim.scoreFilter = value end
  env.C_PvP = {
    IsRatedBattleground = function() return sim.rated end,
    IsSoloRBG = function() return sim.blitz end,
    IsMatchComplete = function() return sim.matchComplete end,
    GetActiveMatchState = function() return sim.inBG and 3 or 0 end,
  }
  if sim.client == "retail" then env.C_PvP.GetScoreInfo = function(i) return sim.scores[i] end end
  env.GetAreaSpiritHealerTime = function() return sim.healerTime end
  env.GetNumBattlefieldFlagPositions = function() return #sim.flagPositions end
  env.GetBattlefieldFlagPosition = function(i) return unpack(sim.flagPositions[i]) end
  env.C_AreaPoiInfo = {
    GetAreaPOIForMap = function() local ids = {}; for i in ipairs(sim.pois) do ids[#ids + 1] = i end; return ids end,
    GetAreaPOIInfo = function(_, i) return sim.pois[i] end,
  }
  env.C_DeathInfo = {
    GetGraveyardsForMap = function() return sim.graveyards end,
    GetDeathReleasePosition = function() return sim.releasePosition end,
  }
  env.C_UIWidgetManager = {}
end

local function extend(sim, env)
  for name, method in pairs(Battleground) do sim[name] = method end
  sim.addon = "Highground" -- saved variable HighgroundDB
  sim.matchStart, sim.inBG, sim.rated, sim.area, sim.mapName = 100, false, true, "Stables", "Arathi Basin"
  sim.pois, sim.flagPositions, sim.scoreRequests = {}, {}, 0
  sim.scores = { { name = "Me-Realm", classToken = "MAGE", faction = 1 } }
  sim.checks[#sim.checks + 1] = highgroundErrors
  -- Spec names from the client configuration; range from the player's
  -- range bands (config/<client>/Classes.lua).
  sim.specName = function(class, index)
    local fallback = sim.ns.SpecFallbacks and sim.ns.SpecFallbacks[class]
    return fallback and fallback[index].name
  end
  sim.inRange = function(id, unit)
    local cfg = sim.ns.Core.me.range
    for _, band in ipairs(cfg and cfg.bands or {}) do
      for _, spell in ipairs(band[2]) do
        if spell == id then return (unit and unit.yards or 100) <= band[1] end
      end
    end
  end
  battlegroundAPI(sim, env)
  dofile(HERE .. "maps.lua")(sim, env)
end

return function(client, saved, configure)
  return wowsim(client, saved, extend, configure)
end
