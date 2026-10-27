-- Deterministic event loop and clock. Runs the unmodified TOC/XML load order.
local Runtime = {}
Runtime.__index = Runtime

-- This file's folder: the fixtures load from here, whatever the working
-- directory (another addon's tests reach them through its shared/ link).
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "tests/simulation/"

function Runtime:load(path)
  self.loaded[#self.loaded + 1] = path
  if path:match("%.lua$") then
    setfenv(assert(loadfile(path)), self.env)(self.addon, self.ns)
  elseif path:match("%.xml$") then
    local file = assert(io.open(path)); local xml = file:read("*a"); file:close()
    for kind, relative in xml:gmatch('<(%w+)%s+file="([^"]+)"') do
      assert(kind == "Script" or kind == "Include", "Unsupported XML dependency: " .. kind)
      self:load((path:match("^(.*)/") or ".") .. "/" .. relative)
    end
    for name, attributes, body in xml:gmatch('<Frame%s+name="([^"]+)"(.-)>(.-)</Frame>') do
      self.templates[name] = { mixin = assert(attributes:match('mixin="([^"]+)"')), body = body }
    end
  else
    error("Unsupported manifest entry: " .. path)
  end
end

function Runtime:assertHealthy()
  local db = self.env[self.savedVariable] or {}
  local errors = {}
  for name, record in pairs(db.errors or {}) do errors[#errors + 1] = name .. "\n" .. record.trace end
  -- Guarded failures before WarboardDB exists are only in GuardStats.
  for stage, st in pairs(self.ns.Util and self.ns.Util.GuardStats or {}) do
    if not (db.errors and db.errors[st.lastError]) then errors[#errors + 1] = st.lastError or stage end
  end
  for _, value in ipairs({ db.healthErr or false, db.intelErr or false, db.pressureError or false,
    self.ns.pinStats and self.ns.pinStats.lastError or false }) do
    if value then errors[#errors + 1] = tostring(value) end
  end
  table.sort(errors)
  assert(#errors == 0, "At t=" .. self.now .. " after " .. (self.lastAction or "load") .. ":\n" .. table.concat(errors, "\n"))
end

function Runtime:event(event, ...)
  self.lastAction = event
  local count = #self.frames
  for i = 1, count do
    local f = self.frames[i]
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
  self:assertHealthy()
end

function Runtime:advance(seconds)
  assert(seconds >= 0)
  local finish = self.now + seconds
  while self.now < finish - 0.0000001 do
    local delta = math.min(0.05, finish - self.now)
    self.now = self.now + delta
    self.lastAction = "advance"
    for _, timer in ipairs(self.timers) do
      if not timer.cancelled and self.now + 0.0000001 >= timer.due then
        if timer.interval then timer.due = timer.due + timer.interval else timer.cancelled = true end
        timer.callback()
      end
    end
    local count = #self.frames
    for i = 1, count do
      local f = self.frames[i]
      if f.scripts.OnUpdate and f:IsVisible() then f.scripts.OnUpdate(f, delta) end
    end
    self:assertHealthy()
  end
end

function Runtime:command(text)
  self.lastAction = "/wb " .. text
  self.env.SlashCmdList.WARBOARD(text)
  self:assertHealthy()
end

function Runtime:setCombat(on)
  self.combat = on
  self:event(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

function Runtime:combatLog(kind, source, destination, spellID)
  self.combatEvent = { self.now, kind, false, "Player-source", source, 0, 0,
    "Player-destination", destination, 0, 0, spellID }
  self:event("COMBAT_LOG_EVENT_UNFILTERED")
end

function Runtime:join(mapID, instanceID, name)
  self.mapID, self.instanceID, self.mapName = mapID or 93, instanceID or 529, name or "Arathi Basin"
  self.inBG, self.matchStart, self.matchComplete = true, self.now, false
  self:event("PLAYER_ENTERING_WORLD")
  self:event("UPDATE_BATTLEFIELD_SCORE")
  self:advance(1)
end

function Runtime:joinArena()
  self.inArena = true
  self:event("PLAYER_ENTERING_WORLD")
  self:advance(1)
end

function Runtime:leave()
  self.inBG, self.inArena = false, false
  self:event("PLAYER_ENTERING_WORLD")
  self:advance(1)
end

function Runtime:enemy(name, fields)
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

function Runtime:entry(name) return self.ns.enemies[name .. "-Realm"] end

function Runtime:poi(icon)
  self.pois[1] = { name = "Stables", position = { x = 0.2, y = 0.3 }, textureIndex = icon }
  self:event("AREA_POIS_UPDATED")
end

-- configure(sim) may set sim.addon, sim.savedVariable and sim.manifest to
-- load another addon of the repository (default: Highground).
return function(client, saved, configure)
  local sim = setmetatable({ client = client or "cata", now = 100, addon = "Highground", savedVariable = "WarboardDB", matchStart = 100, specIndex = 1,
    inBG = false, combat = false, rated = true, area = "Stables", mapName = "Arathi Basin",
    frames = {}, timers = {}, templates = {}, loaded = {}, ns = {}, sent = {}, messages = {}, sounds = {}, chat = {}, notices = {},
    units = { player = { name = "Me", classID = 8 } }, plates = {}, pois = {}, flagPositions = {},
    scores = { { name = "Me-Realm", classToken = "MAGE", faction = 1 } }, scoreRequests = 0 }, Runtime)
  local env = setmetatable({}, { __index = _G })
  sim.env, env._G, env.WarboardDB = env, env, saved
  dofile(HERE .. "frames.lua")(sim, env)
  dofile(HERE .. "api.lua")(sim, env)
  dofile(HERE .. "maps.lua")(sim, env)
  dofile(HERE .. "clicks.lua")(sim, env)
  local function schedule(seconds, callback, recurring)
    assert(seconds > 0)
    local timer = { due = sim.now + seconds, interval = recurring and seconds, callback = callback }
    function timer:Cancel() self.cancelled = true end
    sim.timers[#sim.timers + 1] = timer
    return timer
  end
  env.C_Timer = { After = function(delay, callback) schedule(delay, callback) end,
    NewTicker = function(delay, callback) return schedule(delay, callback, true) end }
  if configure then configure(sim) end -- optional game APIs and load-on-demand UI fixtures
  if sim.savedVariable ~= "WarboardDB" then env.WarboardDB, env[sim.savedVariable] = nil, saved end
  local manifest = sim.manifest or (sim.client == "cata" and "Highground_Cata.toc" or "Highground.toc")
  for line in io.lines(manifest) do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1, 1) ~= "#" then sim:load(line) end
  end
  sim:event("ADDON_LOADED", sim.addon)
  sim:event("PLAYER_LOGIN")
  return sim
end
