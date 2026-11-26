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
--   sim.missingAddons, sim.disabledAddons  { [folder] = true } that
--                     C_AddOns.LoadAddOn reports missing or disabled
-- and add game APIs, sim methods or health checks (sim.checks). saved is
-- installed as env[sim.savedVariable] after the last configure.
-- Paths in the TOC are relative to the working directory: run from the
-- addon's folder.
---------------------------------------------------------------------------
local Runtime = {}
Runtime.__index = Runtime

-- This file's folder, whatever the working directory.
local HERE = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"

-- Compiled chunks shared by every simulator in this process (also across
-- dofile calls of this file): parsing the whole TOC again for each new sim
-- dominated suites that create many. Running a cached main chunk under a
-- new setfenv is equivalent to loading it again, because the closures it
-- creates keep the environment of the run that created them. A changed
-- file is compiled again.
local chunks = package.loaded["wowsim.chunks"] or {}
package.loaded["wowsim.chunks"] = chunks
local function compile(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  local cached = chunks[path]
  if not cached or cached.source ~= source then
    cached = { source = source, chunk = assert(loadstring(source, "@" .. path)) }
    chunks[path] = cached
  end
  return cached.chunk
end

function Runtime:load(path)
  self.loaded[#self.loaded + 1] = path
  if path:match("%.lua$") then
    setfenv(compile(path), self.env)(self.addon, self.ns)
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
-- Health checks run after every step, so a passing check allocates nothing:
-- it returns this shared, never-modified empty list.
local NONE = {}
local function loggedErrors(sim, db)
  -- Damaged saved tables are the addon's to repair, not simulator errors.
  local saved = type(db.errors) == "table" and db.errors or NONE
  local stats = sim.ns.Util and sim.ns.Util.GuardStats
  if not next(saved) and not (stats and next(stats)) then return NONE end
  local errors = {}
  for name, record in pairs(saved) do errors[#errors + 1] = name .. "\n" .. tostring(type(record) == "table" and record.trace) end
  for stage, st in pairs(stats or NONE) do
    if not saved[st.lastError] then errors[#errors + 1] = st.lastError or stage end
  end
  return errors
end
Runtime.NONE = NONE

-- C_AddOns.LoadAddOn: runs a sibling folder's TOC (../<name>/<name>.toc)
-- once, in the addon's own namespace as in the game. Returns loaded, reason:
-- "MISSING" without that folder or when sim.missingAddons[name] is set,
-- "DISABLED" when sim.disabledAddons[name] is set.
function Runtime:loadAddOn(name)
  if name == self.addon or self.addons[name] then return true end
  if (self.disabledAddons or NONE)[name] then return false, "DISABLED" end
  local folder = "../" .. name .. "/"
  local manifest = not (self.missingAddons or NONE)[name] and io.open(folder .. name .. ".toc")
  if not manifest then return false, "MISSING" end
  local ns = {}
  self.addons[name] = ns
  for line in manifest:lines() do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1, 1) ~= "#" then setfenv(compile(folder .. line), self.env)(name, ns) end
  end
  manifest:close()
  self:event("ADDON_LOADED", name)
  return true
end

-- Fails with every error found by sim.checks (each check(sim, db) returns a
-- list of messages). Runs after every event, clock step and click.
function Runtime:assertHealthy()
  local db = self.env[self.savedVariable] or NONE
  local errors
  for _, check in ipairs(self.checks) do
    for _, message in ipairs(check(self, db)) do
      errors = errors or {}
      errors[#errors + 1] = message
    end
  end
  if not errors then return end
  table.sort(errors)
  error("At t=" .. self.now .. " after " .. (self.lastAction or "load") .. ":\n" .. table.concat(errors, "\n"), 0)
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
-- OnUpdate, then each sim.afterStep(sim, delta) runs (such as deferred
-- resize events, resize.lua).
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
        if timer.remaining then
          timer.remaining = timer.remaining - 1
          if timer.remaining < 1 then timer.cancelled = true end
        end
        if timer.handle then timer.callback(timer) else timer.callback() end
      end
    end
    local count, index, visited = #self.frames, 1, 0
    while index <= #self.updateFrames do
      local f = self.updateFrames[index]
      if f.simOrder > count then break end -- newly created frames wait for the next step
      if f.simOrder > visited then
        visited = f.simOrder
        if f.scripts.OnUpdate and f:IsVisible() then f.scripts.OnUpdate(f, delta) end
      end
      -- A callback may insert an older frame before this cursor. Skip any
      -- already visited frames; newly subscribed later frames still run now.
      index = index + 1
    end
    for i = 1, #self.afterStep do self.afterStep[i](self, delta) end
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

-- SavedVariables of load-on-demand folders: sim.addonSaved[global] becomes
-- each global the folder's TOC names (## SavedVariables) when it loads,
-- before its ADDON_LOADED. (The game applies them after the folder's files,
-- so its code must not assign them unconditionally.)
local loadAddOn = Runtime.loadAddOn
function Runtime:loadAddOn(name)
  local manifest = name ~= self.addon and not self.addons[name] and not (self.disabledAddons or NONE)[name]
    and not (self.missingAddons or NONE)[name] and io.open("../" .. name .. "/" .. name .. ".toc")
  if manifest then
    local globals = manifest:read("*a"):match("\n##%s*SavedVariables:%s*([^\n]*)")
    manifest:close()
    for global in (globals or ""):gmatch("[%w_]+") do
      local value = (self.addonSaved or NONE)[global]
      if value ~= nil then self.env[global] = value end
    end
  end
  return loadAddOn(self, name)
end

-- Unit flags for combatLog fields (COMBATLOG_OBJECT_* combinations).
Runtime.combatFlags = { mine = 0x511, friendlyPlayer = 0x518, hostilePlayer = 0x548, hostileNPC = 0xa48 }

-- Fires COMBAT_LOG_EVENT_UNFILTERED. fields (optional): sourceGUID,
-- sourceFlags, destGUID, destFlags, spellName, school, and suffix: values
-- after the spell parameters (after the base ones for SWING_ events), such
-- as { amount, overkill }. Without fields, GUIDs are placeholders and flags 0.
function Runtime:combatLog(kind, source, destination, spellID, fields)
  fields = fields or NONE
  local event = { self.now, kind, false, fields.sourceGUID or "Player-source", source, fields.sourceFlags or 0, 0,
    fields.destGUID or "Player-destination", destination, fields.destFlags or 0, 0 }
  local suffix = 12
  if not kind:match("^SWING_") then
    event[12], event[13], event[14], suffix = spellID, fields.spellName, fields.school, 15
  end
  local extra = fields.suffix or NONE
  for i = 1, #extra do event[suffix + i - 1] = extra[i] end
  event.n = math.max(#extra > 0 and suffix + #extra - 1 or 0, suffix == 15 and 12 or 11)
  self.combatEvent = event
  self:event("COMBAT_LOG_EVENT_UNFILTERED")
end

return function(client, saved, ...)
  local sim = setmetatable({ client = client or "cata", now = 100, specIndex = 1,
    combat = false, frames = {}, updateFrames = {}, afterStep = {}, timers = {}, templates = {}, loaded = {}, ns = {}, sent = {}, addons = {},
    messages = {}, sounds = {}, chat = {}, notices = {}, units = { player = { name = "Me", classID = 8 } },
    plates = {}, checks = { loggedErrors } }, Runtime)
  local env = setmetatable({}, { __index = _G })
  sim.env, env._G = env, env
  compile(HERE .. "frames.lua")()(sim, env)
  compile(HERE .. "api.lua")()(sim, env)
  compile(HERE .. "clicks.lua")()(sim, env)
  -- C_Timer as in the game: a zero delay waits for the next step, timer
  -- and ticker handles are passed to their callback, and a ticker stops
  -- after its optional iteration count.
  local function schedule(seconds, callback, handle, recurring, iterations)
    assert(type(seconds) == "number" and seconds >= 0, "C_Timer: invalid delay")
    assert(type(callback) == "function", "C_Timer: callback must be a function")
    assert(iterations == nil or type(iterations) == "number" and iterations >= 1, "C_Timer: invalid iterations")
    local timer = { due = sim.now + math.max(seconds, 0.000001), interval = recurring and seconds,
      callback = callback, handle = handle, remaining = iterations }
    function timer:Cancel() self.cancelled = true end
    function timer:IsCancelled() return self.cancelled == true end
    sim.timers[#sim.timers + 1] = timer
    return timer
  end
  env.C_Timer = { After = function(delay, callback) schedule(delay, callback) end,
    NewTimer = function(delay, callback) return schedule(delay, callback, true) end,
    NewTicker = function(delay, callback, iterations) return schedule(delay, callback, true, true, iterations) end }
  for i = 1, select("#", ...) do
    local configure = select(i, ...)
    if configure then configure(sim, env) end
  end
  assert(sim.addon, "configure must set sim.addon")
  sim.savedVariable = sim.savedVariable or sim.addon .. "DB"
  env[sim.savedVariable] = saved
  local manifest = sim.manifest or (sim.addon .. (sim.client == "cata" and "_Cata" or "") .. ".toc")
  sim.metadata = {} -- "## Field: value" lines, for C_AddOns.GetAddOnMetadata
  for line in io.lines(manifest) do
    local field, value = line:match("^##%s*([%w%-]+):%s*(.-)%s*$")
    if field then sim.metadata[field] = value end
  end
  for line in io.lines(manifest) do
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" and line:sub(1, 1) ~= "#" then sim:load(line) end
  end
  sim:event("ADDON_LOADED", sim.addon)
  sim:event("PLAYER_LOGIN")
  return sim
end
