---------------------------------------------------------------------------
-- WoW simulator core: loads an addon's TOC (and the XML it includes) into
-- a fresh environment, then runs it on a deterministic event loop and a
-- virtual clock. Widgets, secure clicks and game APIs come from the other
-- files of this folder; the addon's code is never replaced.
--
--   local new = dofile("../../tools/wowsim/runtime.lua")
--   local sim = new(client, saved, configure...)
--
-- client is "cata" (Cataclysm Classic, also used for Classic Era and The
-- Burning Crusade with a build number) or "retail" (default "cata").
-- saved becomes the addon's SavedVariables table. Each configure(sim, env)
-- runs in order before the TOC loads and may set:
--   sim.addon         addon folder name (required)
--   sim.savedVariable global for saved (default sim.addon .. "DB")
--   sim.manifest      TOC to load (default <addon>_Cata.toc on "cata",
--                     <addon>.toc otherwise)
-- and add game APIs, sim methods or health checks (sim.checks). saved is
-- installed as env[sim.savedVariable] after the last configure.
-- Paths in the TOC are relative to the working directory: run from the
-- addon's folder.
---------------------------------------------------------------------------
local Runtime = {}
Runtime.__index = Runtime

-- This file's folder, whatever the working directory.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"

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

-- Errors the addon recorded with the shared core's error log: the saved
-- variables' errors table ({ trace } per name) and ns.Util.GuardStats for
-- guarded failures before the saved variables exist. Absent tables pass.
local function loggedErrors(sim, db)
  local errors = {}
  for name, record in pairs(db.errors or {}) do errors[#errors + 1] = name .. "\n" .. record.trace end
  for stage, st in pairs(sim.ns.Util and sim.ns.Util.GuardStats or {}) do
    if not (db.errors and db.errors[st.lastError]) then errors[#errors + 1] = st.lastError or stage end
  end
  return errors
end

-- Fails with every error found by sim.checks (each check(sim, db) returns a
-- list of messages). Runs after every event, clock step and click.
function Runtime:assertHealthy()
  local db = self.env[self.savedVariable] or {}
  local errors = {}
  for _, check in ipairs(self.checks) do
    for _, message in ipairs(check(self, db)) do errors[#errors + 1] = message end
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

-- Moves the clock in 50 ms steps: due timers fire, visible frames get
-- OnUpdate.
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

-- Runs SlashCmdList[key](text), as typing the command would.
function Runtime:slash(key, text, label)
  self.lastAction = label or (key .. " " .. text)
  assert(self.env.SlashCmdList[key], "No slash command " .. key)(text)
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

return function(client, saved, ...)
  local sim = setmetatable({ client = client or "cata", now = 100, specIndex = 1,
    combat = false, frames = {}, timers = {}, templates = {}, loaded = {}, ns = {}, sent = {},
    messages = {}, sounds = {}, chat = {}, notices = {}, units = { player = { name = "Me", classID = 8 } },
    plates = {}, checks = { loggedErrors } }, Runtime)
  local env = setmetatable({}, { __index = _G })
  sim.env, env._G = env, env
  dofile(HERE .. "frames.lua")(sim, env)
  dofile(HERE .. "api.lua")(sim, env)
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
  for i = 1, select("#", ...) do
    local configure = select(i, ...)
    if configure then configure(sim, env) end
  end
  assert(sim.addon, "configure must set sim.addon")
  sim.savedVariable = sim.savedVariable or sim.addon .. "DB"
  env[sim.savedVariable] = saved
  local manifest = sim.manifest or (sim.addon .. (sim.client == "cata" and "_Cata" or "") .. ".toc")
  for line in io.lines(manifest) do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1, 1) ~= "#" then sim:load(line) end
  end
  sim:event("ADDON_LOADED", sim.addon)
  sim:event("PLAYER_LOGIN")
  return sim
end
