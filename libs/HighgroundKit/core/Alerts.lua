local addon, ns = ...
local U = ns.Util
local A = { categories = {}, pending = {}, last = {}, cues = {} }
ns.Alerts = A
local EMPTY = {}

-- One queue arbitrates sounds across features. Existing event cooldowns
-- still apply; a burst of sightings cannot drown out an objective warning.
for _, d in ipairs({
  ns.Localization.Define({ "capture", ns.Locale:Get("shared.alerts.base_capture.8c241b"), 5, true }, { [2] = "shared.alerts.base_capture.8c241b" }), ns.Localization.Define({ "objective", ns.Locale:Get("shared.alerts.objective_changes.dbb28b"), 5, true }, { [2] = "shared.alerts.objective_changes.dbb28b" }),
  ns.Localization.Define({ "resurrection", ns.Locale:Get("shared.alerts.resurrection.a19b05"), 4, true }, { [2] = "shared.alerts.resurrection.a19b05" }), ns.Localization.Define({ "go", ns.Locale:Get("battlegrounds.commands.kill_window.e9f9d7"), 4 }, { [2] = "battlegrounds.commands.kill_window.e9f9d7" }),
  ns.Localization.Define({ "sap", ns.Locale:Get("shared.alerts.sap_opportunity.20392d"), 3, true }, { [2] = "shared.alerts.sap_opportunity.20392d" }), ns.Localization.Define({ "bounty", ns.Locale:Get("shared.alerts.bounty_spotted.7c221e"), 2 }, { [2] = "shared.alerts.bounty_spotted.7c221e" }),
  ns.Localization.Define({ "stealth", ns.Locale:Get("shared.alerts.enemy_stealth.fa0e89"), 3 }, { [2] = "shared.alerts.enemy_stealth.fa0e89" }), ns.Localization.Define({ "nearby", ns.Locale:Get("shared.alerts.nearby_enemy.7dac16"), 1 }, { [2] = "shared.alerts.nearby_enemy.7dac16" }),
  ns.Localization.Define({ "tracked", ns.Locale:Get("tracking.alert.label"), 3 }, { [2] = "tracking.alert.label" }),
  ns.Localization.Define({ "lockon", ns.Locale:Get("shared.alerts.target_lock.c964c3"), 1 }, { [2] = "shared.alerts.target_lock.c964c3" }),
}) do
  A.categories[#A.categories + 1] = { key = d[1], label = d[2], priority = d[3], objective = d[4],
    module = d[1] == "bounty" and "bounties" or d[1] == "stealth" and "shared"
      or (d[1] == "nearby" or d[1] == "tracked") and "nearby" or "battlegrounds" }
end
-- Notify's sound for each category, created once: plays the chosen cue.
for _, def in ipairs(A.categories) do
  local key = def.key
  A.cues[key] = function() A.Play(key) end
end

-- Sounds an alert can use. Highground's files need a full client restart
-- after installation; until then each plays its game-sound fallback.
local FILES = "Interface\\AddOns\\" .. addon .. "\\libs\\sounds\\"
local function File(name)
  return function()
    if not U.call(PlaySoundFile, FILES .. name, "Master") then U.AlertSound() end
  end
end
local function Game(id) return function() U.call(PlaySound, id, "Master") end end
-- Cues owned by other files, present only when their addon is loaded.
local function Owned(owner, method)
  return function() return ns[owner] and ns[owner][method] end
end
local function Lockon()
  local sound = ns.Core.SNIPER_SOUNDS and ns.Core.SNIPER_SOUNDS[1]
  if sound and not U.call(PlaySoundFile, sound.file, "Master") then U.call(PlaySound, 37666, "Master") end
end
A.sounds = {}
for _, d in ipairs({
  { "capture", "alerts.sound.siren", File("alert-capture.ogg") },
  { "objective", "alerts.sound.horn", File("alert-objective.ogg") },
  { "resurrection", "alerts.sound.bells", File("alert-resurrection.ogg") },
  { "sap", "alerts.sound.pluck", File("alert-sap.ogg") },
  { "go", "alerts.sound.go", nil, Owned("Core", "GoSound") },
  { "lockon", "highground.sniper.highground_lock_on.8cbbfb", Lockon, function() return ns.Core.SNIPER_SOUNDS and Lockon end },
  { "bounty", "alerts.sound.bounty", nil, Owned("Bounty", "Sound") },
  { "nearby", "alerts.sound.nearby", nil, Owned("Nearby", "Sound") },
  { "tracked", "tracking.alert.sound", Game(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) },
  { "stealth", "alerts.sound.stealth", nil, Owned("Stealth", "EnterSound") },
  { "raidwarning", "alerts.sound.raid_warning", Game(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959) },
  { "readycheck", "alerts.sound.ready_check", Game(SOUNDKIT and SOUNDKIT.READY_CHECK or 8960) },
  { "ping", "alerts.sound.ping", Game(3175) },
  { "whisper", "alerts.sound.boss_whisper", Game(37666) },
  { "alarm", "alerts.sound.alarm", Game(12889) },
  { "prestige", "alerts.sound.prestige", Game(76995) },
}) do
  local play, owned = d[3], d[4]
  A.sounds[#A.sounds + 1] = { key = d[1], labelKey = d[2], player = owned or function() return play end }
end
local soundByKey = {}
for _, sound in ipairs(A.sounds) do soundByKey[sound.key] = sound end

-- Every category except stealth (an enter/leave pair) and lock-on (the
-- marker's own SNIPER_SOUNDS list) starts with the cue named after it.
local function Choosable(category) return soundByKey[category] ~= nil and category ~= "stealth" and category ~= "lockon" end
A.Choosable = Choosable

function A.SoundLabel(key)
  local sound = soundByKey[key]
  return sound and ns.Locale:Get(sound.labelKey) or key
end

-- Choices available in this host, the category's own cue first.
function A.SoundChoices(category)
  if category == "lockon" then
    local choices = {}
    for i, sound in ipairs(ns.Core.SNIPER_SOUNDS or {}) do choices[i] = { key = i, label = sound.name } end
    return choices
  end
  if not Choosable(category) then return {} end
  local choices = { { key = category, label = ns.Locale:Format("alerts.sound.default", { sound = A.SoundLabel(category) }) } }
  for _, sound in ipairs(A.sounds) do
    if sound.key ~= category and sound.player() then choices[#choices + 1] = { key = sound.key, label = A.SoundLabel(sound.key) } end
  end
  return choices
end

local function Saved()
  local db = ns.GetDB and ns.GetDB() or ns.Core.db
  local sounds = db and type(db.alerts) == "table" and db.alerts.sounds
  return type(sounds) == "table" and sounds or EMPTY
end

-- The chosen sound, or the category's own when none is saved or the saved
-- one is unavailable in this host.
function A.Sound(category)
  if category == "lockon" then return ns.Core.db and ns.Core.db.sniperSound or 1 end
  local key = Saved()[category]
  local sound = key and soundByKey[key]
  return sound and sound.player() and key or category
end

function A.SetSound(category, key)
  if category == "lockon" then
    key = tonumber(key)
    if not (key and key == math.floor(key) and key >= 1 and key <= #(ns.Core.SNIPER_SOUNDS or {})) then return false end
    ns.Core.db.sniperSound = key
    return true
  end
  local sound = Choosable(category) and soundByKey[key]
  if not (sound and sound.player()) then return false end
  local sounds = ns.Saved.Table(A.Settings(), "sounds")
  sounds[category] = key ~= category and key or nil
  return true
end

-- Plays a category's chosen sound now. Callers check whether it is allowed.
function A.Play(category, variant)
  if category == "stealth" then
    local play = ns.Stealth and (variant == "exit" and ns.Stealth.ExitSound or ns.Stealth.EnterSound)
    if play then play() end
    return play ~= nil
  end
  if category == "lockon" then return ns.Core.SniperSound and ns.Core.SniperSound() or false end
  local sound = soundByKey[A.Sound(category)]
  local play = sound and sound.player()
  if play then play() end
  return play ~= nil
end

function A.Settings()
  local db = ns.GetDB and ns.GetDB() or ns.Core.db
  if not db then return { channels = {} } end
  local alerts = ns.Saved.Table(db, "alerts")
  ns.Saved.Table(alerts, "channels")
  return alerts
end

-- Each alert's text and sound switches alone decide what it shows and plays;
-- the master sound switch mutes every sound. A preset sets all switches at
-- once and keeps nothing of its own.
local CHANNELS = { "text", "sound" }
local PRESETS = {
  everything = function() return true end,
  critical = function(def) return def.priority >= 4 end,
  objectives = function(def) return def.objective == true end,
  quiet = function(_, channel) return channel == "text" end,
}
A.PRESETS = { "everything", "critical", "objectives", "quiet" }

local function Category(key)
  for _, def in ipairs(A.categories) do if def.key == key then return def end end
end

local function Switch(settings, category, channel)
  local channels = type(settings.channels) == "table" and settings.channels[category]
  return not (type(channels) == "table" and channels[channel] == false)
end

-- Evaluate an isolated preference set as well as the live settings.
function A.AllowedFor(settings, category, channel, sounds)
  if not Category(category) or not Switch(settings, category, channel) then return false end
  return channel ~= "sound" or sounds ~= false
end

function A.Allowed(category, channel)
  -- Reading preferences must not create saved settings.
  local db = ns.GetDB and ns.GetDB() or ns.Core.db
  local settings = db and type(db.alerts) == "table" and db.alerts or EMPTY
  return A.AllowedFor(settings, category, channel, ns.Core.On("sound"))
end

-- One alert's switch, ignoring the master sound switch.
function A.ChannelOn(category, channel)
  local db = ns.GetDB and ns.GetDB() or ns.Core.db
  return Switch(db and type(db.alerts) == "table" and db.alerts or EMPTY, category, channel)
end

function A.SetChannel(category, channel, on)
  if not Category(category) or (channel ~= "text" and channel ~= "sound") then return false end
  local channels = A.Settings().channels
  channels[category] = type(channels[category]) == "table" and channels[category] or {}
  channels[category][channel] = on and true or false
  return true
end

-- The preset matching every switch in settings, or "custom".
function A.Preset(settings)
  for _, key in ipairs(A.PRESETS) do
    local allows, match = PRESETS[key], true
    for _, def in ipairs(A.categories) do
      for _, channel in ipairs(CHANNELS) do
        if Switch(settings, def.key, channel) ~= allows(def, channel) then match = false end
      end
    end
    if match then return key end
  end
  return "custom"
end

-- Sets every switch in settings (live or a profile candidate) to a preset.
function A.ApplyPreset(settings, mode)
  local allows = PRESETS[mode]
  if not allows then return false end
  settings.mode = nil
  if type(settings.channels) == "table" then wipe(settings.channels) else settings.channels = {} end
  for _, def in ipairs(A.categories) do
    local channel = {}
    for _, key in ipairs(CHANNELS) do channel[key] = allows(def, key) end
    settings.channels[def.key] = channel
  end
  return true
end

function A.SetMode(mode)
  if not A.ApplyPreset(A.Settings(), mode) then return false end
  wipe(A.pending)
  return true
end

-- Older saves filtered the switches through a saved alert level and had
-- separate bounty, nearby and lock-on sound switches. Fold them into the
-- per-alert switches; safe to repeat. Essentials only muted lock-on, so it
-- folds as Everything. owner holds .alerts (the saved database or a profile
-- setup) and prefs the sound options (the database or the setup's
-- preferences). False when the old level was unknown.
function A.Upgrade(owner, prefs)
  if owner.alerts == nil then owner.alerts = {} end
  local alerts = owner.alerts
  if type(alerts) ~= "table" then return true end
  if alerts.channels == nil then alerts.channels = {} end
  local function Off(category, channel)
    if type(alerts.channels) ~= "table" then return end
    local switches = alerts.channels[category]
    if switches == nil then switches = {}; alerts.channels[category] = switches end
    if type(switches) == "table" then switches[channel] = false end
  end
  local mode = alerts.mode
  local allows = PRESETS[mode]
  alerts.mode = nil
  if allows then
    for _, def in ipairs(A.categories) do
      for _, channel in ipairs(CHANNELS) do
        if not allows(def, channel) then Off(def.key, channel) end
      end
    end
  end
  if type(prefs) == "table" then
    if prefs.bountySound == false then Off("bounty", "sound") end
    if prefs.nearbySound == false then Off("nearby", "sound") end
    prefs.bountySound, prefs.nearbySound = nil, nil
    if prefs.sniperSound == 0 then Off("lockon", "sound"); prefs.sniperSound = 1 end
  end
  return mode == nil or mode == "essential" or allows ~= nil
end

-- An explicit audition uses the same cue as gameplay, without creating an
-- event, consuming its cooldown or changing any saved mute preference.
function A.PlaySample(category, variant)
  local definition = Category(category)
  if not definition then return false, ns.Locale:Get("alerts.sample.unknown") end
  if ns.Modules and definition.module ~= "shared" and not ns.Modules.Active(definition.module) then
    return false, ns.Locale:Get("alerts.sample.disabled")
  end
  if not A.Play(category, variant) then return false, ns.Locale:Get("alerts.sample.unavailable") end
  return true
end

local lastSound, lastPriority = -math.huge, 0
-- Sounds wait briefly so simultaneous events play only their highest-priority
-- cue. A flush is scheduled only while something is pending.
local FLUSH_DELAY, scheduled = 0.15, false
local function ScheduledFlush()
  scheduled = false
  U.RunGuarded("alerts", A.Flush)
end
local function Schedule()
  if scheduled then return end
  if not (C_Timer and C_Timer.After) then return A.Flush() end
  scheduled = true
  C_Timer.After(FLUSH_DELAY, ScheduledFlush)
end

function A.Flush()
  local now, best = GetTime(), nil
  for key, item in pairs(A.pending) do
    A.pending[key] = nil
    if item.sound and A.Allowed(item.category, "sound") and (not best or item.priority > best.priority) then best = item end
  end
  -- Lock-on answers your own targeting, so it skips the gap between sounds.
  if best and (now - lastSound >= 1.5 or best.priority > lastPriority or best.category == "lockon") then
    lastSound, lastPriority = now, best.priority
    best.sound()
  end
end

function A.Emit(category, key, text, sound, show)
  local now = GetTime()
  key = category .. ":" .. tostring(key or text or "event")
  if now - (A.last[key] or -math.huge) < 1 then return false end
  A.last[key] = now
  if text and A.Allowed(category, "text") then
    if show then show(text) else U.Say(text) end
  end
  local priority = 1
  for _, d in ipairs(A.categories) do if d.key == category then priority = d.priority end end
  A.pending[key] = { category = category, text = text, sound = sound, show = show, priority = priority }
  Schedule()
  return true
end

-- Text is immediate. Sounds are collected briefly so simultaneous events
-- play only their highest-priority cue.
function U.Notify(category, key, text, sound, show)
  return A.Emit(category, key, text, sound, show)
end

function U.Warning(text, tone)
  if RaidNotice_AddMessage and RaidWarningFrame then
    local r, g, b = ns.Theme.Color(tone or "warning")
    RaidNotice_AddMessage(RaidWarningFrame, text, { r = r, g = g, b = b })
  else U.Say(text) end
end

ns.Scope.Listen(function()
  wipe(A.pending); wipe(A.last)
  lastSound, lastPriority = -math.huge, 0
end)
U.Every(60, function()
  for key, at in pairs(A.last) do if GetTime() - at > 60 then A.last[key] = nil end end
end, "alert cleanup")
