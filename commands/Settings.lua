local _, ns = ...
local Core, Options, Commands = ns.Core, ns.Options, ns.Commands
local Hex = ns.Theme.Hex

-- /wb export [NAME]: a saved profile, or your current settings.
function Commands.export(arg, msg, say)
  Options.Profiles.ShowExport((msg or ""):match("^%S+%s+(.+)$"))
end

function Commands.import(arg, msg, say)
  if arg ~= "" then
    -- /wb import WB1;... (lowercased by the slash parser: re-read raw)
    local raw = (msg or ""):match("^%S+%s+(.+)$")
    local ok, res = Options.Profiles.ImportText(raw)
    say(res)
  else
    Options.Profiles.ShowImport()
  end
end

function Commands.profile(arg, msg, say)
  local sub, name = arg:match("^(%S*)%s*(.-)$")
  local rawName = (msg or ""):match("^%S+%s+%S+%s+(.+)$") -- keep the name's case
  if sub == "save" and rawName then
    Options.Profiles.SaveProfile(rawName)
    Core.db.activeProfile = rawName
    say("saved profile " .. rawName)
  elseif sub == "load" and rawName then
    local ok, err = Options.Profiles.LoadProfile(rawName)
    say(ok and ("loaded profile " .. rawName) or err or ("no profile named " .. rawName))
  elseif sub == "delete" and rawName and Core.db.profiles and Core.db.profiles[rawName] then
    Core.db.profiles[rawName] = nil
    say("deleted profile " .. rawName)
  else
    local names = {}
    for n in Options.Profiles.SortedPairs(Core.db.profiles or {}) do
      names[#names + 1] = n
    end
    say(#names > 0 and ("profiles: " .. table.concat(names, ", ")) or "no saved profiles")
    say("/wb profile save|load|delete NAME, /wb export, /wb import")
  end
end

-- /wb config: the Warboard window (/wb config blizzard: the Options panel).
function Commands.config(arg, msg, say)
  if arg == "blizzard" or not ns.Hub then return Options.Open() end
  ns.Hub.Open(arg ~= "" and arg or nil)
end

function Commands.points(arg, msg, say)
  local key, val = arg:match("^(%S+)%s*(%S*)$")
  local real
  for k in pairs(Core.POINT_DEFAULT) do
    if key and k:lower() == key:lower() then
      real = k
    end
  end
  if not key then
    local n = 0
    for k, v in pairs(Core.db.points or {}) do
      n = n + 1
      say(string.format("%s = %s (default %s)", k, Options.Format(v), Options.Format(Core.POINT_DEFAULT[k] or 0)))
    end
    say(n == 0 and "all points at default. /wb config to edit, /wb points KEY N to set" or "/wb points KEY reset")
  elseif not real then
    say("unknown key; see Options > AddOns > Warboard")
  elseif val == "reset" or val == "" then
    local ok, err = Core.SetTuning("point", real, Core.POINT_DEFAULT[real])
    if not ok then say(err); return end
    say(real .. " reset to " .. Options.Format(Core.POINT_DEFAULT[real]))
    Options.PointsChanged()
  elseif tonumber(val) then
    local ok, err = Core.SetTuning("point", real, tonumber(val))
    if not ok then say(err); return end
    say(real .. " = " .. val)
    Options.PointsChanged()
  end
end

function Commands.weights(arg, msg, say)
  for _, w in ipairs(Core.WEIGHTS) do
    say(string.format("%-9s x%.1f  %s%s|r", w.key, Core.W(w.key), Hex("textMuted"), w.desc))
  end
  say("/wb weight NAME X  (0-5)  |  /wb weight reset")
end

function Commands.weight(arg, msg, say)
  if arg == "" then return Commands.weights(arg, msg, say) end
  local name, val = arg:match("^(%S+)%s*(.-)$")
  if name == "reset" then
    Core.db.weights = {}
    say("all coefficients reset to 1.0")
  else
    local known
    for _, w in ipairs(Core.WEIGHTS) do
      if w.key == name then
        known = w
      end
    end
    local x = tonumber(val)
    if known and x then
      local ok, err = Core.SetTuning("weight", name, x)
      if not ok then say(err); return end
      say(string.format("%s coefficient: x%.1f", name, (Core.db.weights or {})[name] or 1))
    else
      say("unknown weight or value. /wb weights to list")
    end
  end
  Options.PointsChanged()
end

function Commands.live(arg, msg, say)
  Core.SetTuning("option", "liveSort", not Core.O("liveSort"))
  say("live re-ordering: " .. (Core.O("liveSort") and "on (defensives/CC/burst/range move rows)" or "off (stable order, live state shown as icons)"))
  Options.PointsChanged()
end

function Commands.all(arg, msg, say)
  local on = Core.SetFeature("allBGs", not Core.db.allBGs)
  say("all battlegrounds: " .. (on and "on" or "off (rated only)"))
end

function Commands.rows(arg, msg, say)
  if not tonumber(arg) then return Commands.help(arg, msg, say) end
  Core.db.rows = math.max(1, math.min(Core.MAX_ROWS, tonumber(arg)))
  say("rows: " .. Core.db.rows)
end

function Commands.scale(arg, msg, say)
  if not tonumber(arg) then return Commands.help(arg, msg, say) end
  local applied = ns.SetUIScale(tonumber(arg))
  say(string.format("UI scale: %d%%%s", math.floor(Core.db.scale * 100 + 0.5), applied and "" or " (applies after combat)"))
end

function Commands.compact(arg, msg, say)
  local on = arg == "on" or (arg ~= "off" and not Core.IsCompact())
  Core.SetFeature("compact", on)
  local applied = Core.compact == on -- in combat the layout waits
  say("compact layout: " .. (on and "on" or "off") .. (applied and "" or " (applies after combat)"))
end

function Commands.opacity(arg, msg, say)
  if not tonumber(arg) then return Commands.help(arg, msg, say) end
  ns.SetBgAlpha(tonumber(arg) / 100)
  say(string.format("background opacity: %d%%", math.floor(Core.BgAlpha() * 100 + 0.5)))
end

function Commands.exec(arg, msg, say)
  if not tonumber(arg) then return Commands.help(arg, msg, say) end
  local ok, err = Core.SetTuning("option", "executePct", tonumber(arg) / 100)
  if not ok then say(err); return end
  Options.PointsChanged()
  say(string.format("execute highlight below %d%%", Core.db.executePct * 100))
end

Commands.options = Commands.config

-- /wb nearby [on | off | test | clear]: the open-world enemy list (world/Nearby.lua).
function Commands.nearby(arg, msg, say)
  if arg == "on" or arg == "off" then
    Core.SetFeature("nearby", arg == "on")
  elseif arg == "test" and ns.NearbyPreview then
    local on = ns.NearbyPreview()
    if on == nil then say("leave combat first"); return end
    say("nearby enemies preview " .. (on and "ON: drag it into place, /wb nearby test again to hide" or "off"))
    return
  elseif arg == "clear" and ns.NearbyClear then
    ns.NearbyClear()
    say("nearby enemies cleared")
    return
  end
  local n = 0
  for _ in pairs(ns.Nearby and ns.Nearby.seen or {}) do n = n + 1 end
  say("nearby enemies " .. (Core.On("nearby") and "on" or "OFF") .. " (" .. n .. " remembered)"
    .. " | /wb nearby on | off | test | clear")
end
