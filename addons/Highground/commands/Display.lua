local _, ns = ...
local Core, Commands = ns.Core, ns.Commands
local Hex = ns.Theme.TipHex -- chat

function Commands.intel(arg, msg, say)
  if not ns.MapWhere then
    say(Hex("error") .. "intel map not loaded|r: Restart the game client fully after installing an update.")
    return
  end
  if arg == "test" and ns.IntelTest then
    say(ns.IntelTest() and "test pin ON: open the map, an orange rogue pin should sit mid-map" or "test pin off")
  elseif arg == "off" or arg == "on" then
    Core.SetFeature("intel", arg == "on")
  elseif arg == "share off" or arg == "share on" then
    Core.SetFeature("intelShare", arg == "share on")
  end
  say(string.format("intel map %s, sharing with teammates %s", Core.On("intel") and "on" or "OFF",
    Core.On("intelShare") and "on" or "OFF"))
  if ns.IntelStatus then
    say(ns.IntelStatus())
  end
end

function Commands.timers(arg, msg, say)
  if arg == "off" or arg == "on" then
    Core.SetFeature("timers", arg == "on")
  elseif arg == "reset" and ns.TimersWindowReset then
    ns.TimersWindowReset()
    say("res timers and bases windows moved back to their default spots")
  end
  say("timers " .. (Core.On("timers") and "on" or "OFF") .. (ns.TimersStatus and (" | " .. ns.TimersStatus()) or " (timer modules not loaded: restart the client)"))
end

function Commands.priority(arg, msg, say)
  if arg == "off" or arg == "on" then
    Core.SetFeature("killorder", arg == "on")
  end
  say("target recommendations " .. (Core.PriorityOn() and "on" or "OFF")
    .. (Core.PriorityOn() and "" or " (scope follows your target)") .. " | /wb priority on | off")
end

function Commands.arena(arg, msg, say)
  if arg == "off" or arg == "on" then
    Core.SetFeature("arena", arg == "on")
  elseif arg == "test" and ns.ArenaPreview then
    local on = ns.ArenaPreview()
    if on == nil then say("leave combat first"); return end
    say("arena panel preview " .. (on and "ON: drag it into place, /wb arena test again to hide" or "off"))
    return
  end
  say("arena enemy panel " .. (Core.On("arena") and "on" or "OFF")
    .. " (left-click target, right-click focus) | /wb arena on | off | test")
end

function Commands.test(arg, msg, say)
  if Core.StopTest() then
    say("test mode off")
  else
    Core.StartTest()
    local real = 0
    for key in pairs(Core.enemies) do
      if not key:find("-Test", 1, true) then
        real = real + 1
      end
    end
    say(string.format("test mode on: %d rows use nearby nameplate names (clickable), rest are fake. /wb test again to stop", real))
    if real == 0 then
      say("no nameplates nearby: show nameplates (V) near NPCs for clickable rows and the sniper scope, or use /wb sniper test")
    end
  end
end

function Commands.call(arg, msg, say)
  if Core.CALL_CHANNELS[arg] then
    Core.db.callChannel = arg
    say("calls go to " .. Core.CALL_CHANNELS[arg] .. "(press Enter to send)")
  elseif arg == "" then
    Core.CallTarget()
  else
    say("/wb call  = call now  |  /wb call s|i|raid|party|y  = channel")
  end
end

function Commands.mark(arg, msg, say)
  local sub, val = arg:match("^(%S*)%s*(.-)$")
  local names = { "star", "circle", "diamond", "triangle", "moon", "square", "cross", "skull" }
  local pings = { attack = true, warning = true, assist = true, onmyway = true }
  if sub == "icon" and tonumber(val) and tonumber(val) >= 1 and tonumber(val) <= 8 then
    Core.db.markIcon, Core.db.markMode = tonumber(val), "icon"
    Core.markBound = nil
    Core.UpdateTargetButton()
    say("mark button: raid icon " .. names[Core.db.markIcon])
  elseif sub == "ping" then
    if pings[val] then
      Core.db.pingType = val
    end
    Core.db.markMode = "ping"
    Core.markBound = nil
    Core.UpdateTargetButton()
    say("mark button: " .. Core.db.pingType .. " ping  (/wb mark ping attack|warning|assist|onmyway)")
  else
    say("Macro:  /click WarboardMarkButton   (pings/marks the kill target, keeps your target)")
    say("Now: " .. (Core.db.markMode == "icon" and ("raid icon " .. names[Core.db.markIcon or 8]) or (Core.db.pingType .. " ping"))
      .. "   |  /wb mark ping attack|warning|assist|onmyway  |  /wb mark icon 1-8")
    say("Mark + call:  /click WarboardMarkButton  then  /wb call  on the next line")
    say("Re-points out of combat only. Raid icons may need lead/assist; pings don't.")
    local mt = Core.markBtn:GetAttribute("macrotext")
    say("Button currently does: " .. ((mt and mt ~= "") and mt:gsub("\n", " | ")
      or Hex("danger") .. "nothing|r (no kill target yet: in a BG, or /wb test first)"))
  end
end

-- /wb burst: the last enemy burst buffs and what their marker showed.
function Commands.burst(arg, msg, say)
  if arg == "test" then
    Core.SetBurstTest(not Core.burstTest)
    return say(Core.burstTest and "burst marker test ON: target anyone with a visible nameplate. /wb burst test = stop"
      or "burst marker test off")
  end
  local list = Core.db.burstDiag or {}
  say("burst markers " .. (Core.On("burstMarks") and "on" or "off") .. "; enemy burst buffs seen: " .. #list)
  for i = 1, math.min(6, #list) do
    local d = list[i]
    say(string.format("  %s %s %s (%s): %s", d.t, tostring(d.who):match("^[^-]+"), tostring(d.name), tostring(d.mode),
      d.answer and ("marker " .. d.answer:upper()) or not d.nameplate and "no nameplate (too far or plates off)"
        or not d.read and "buff not read" or "no marker (dispel " .. tostring(d.dispel) .. ")"))
  end
end

function Commands.pressure(arg, msg, say)
  if ns.PressureCommand then
    ns.PressureCommand(arg, say)
  else
    say("Enemy focus markers have not loaded; restart the game after updating the addon.")
  end
end

-- /wb cap probe: record every possible sign of a capture (see
-- core/CapProbe.lua). /wb cap clear: forget the capture diagnostics.
local function CapProbe(say)
  if not ns.Caps.combatLog then say("the capture probe needs the combat log (Cata only)") return end
  Core.SetCapProbe(not Core.db.capProbeOn)
  if Core.db.capProbeOn then
    say("capture probe ON: cap bases, or stand by teammates who do, then /reload to save. /wb cap probe again = off")
  else
    say("capture probe off (" .. #(Core.db.capProbe or {}) .. " assaults recorded)")
  end
end

-- /wb cap why: target a capper mid-cast to see each capture-detection step.
function Commands.cap(arg, msg, say)
  if arg == "probe" then return CapProbe(say) end
  if arg == "clear" then
    Core.db.capLog, Core.db.capDiag, Core.db.capProbe = nil, nil, nil
    return say("capture diagnostics cleared (learned capture spell kept)")
  end
  if arg ~= "why" then return Commands.help(arg, msg, say) end
  local learned = {}
  for spell, l in pairs(Core.db.capSpells or {}) do
    if Core.IsCaptureCast(spell, nil) then learned[#learned + 1] = string.format("%s %ss", tostring(l.name), tostring(l.secs)) end
  end
  say("capture spells learned: " .. (#learned > 0 and table.concat(learned, ", ") or "none yet (cap a base yourself)"))
  local log = Core.db.capLog or {}
  say("combat-log capture events seen: " .. #log)
  for i = 1, math.min(3, #log) do
    local l = log[i]
    say(string.format("  %s %s %s %s", l.t, tostring(l.who), l.sub, tostring(l.name or l.spell)))
  end
  if not UnitExists("target") then say("for a live check, target the player who is capping, then /wb cap why") return end
  local okC, name, _, _, start, finish, _, _, _, spell = pcall(UnitCastingInfo, "target")
  if not (okC and name) then okC, name, _, _, start, finish, _, _, spell = pcall(UnitChannelInfo, "target") end
  say(string.format("target cast: %s (spell %s, %s)", tostring(name), tostring(spell),
    start and finish and string.format("%.1fs", (finish - start) / 1000) or "no timing"))
  say("counts as a capture: " .. tostring(name ~= nil and Core.IsCaptureCast(spell, name) or false))
  local e = Core.enemies[Core.CanonUnit("target") or ""]
  if not e then say("not in the enemy roster (a teammate, or the scoreboard has not listed them)") return end
  local cap = Core.Capping(e)
  say("tracked capture: " .. (cap and string.format("%.1fs left", cap.finish - GetTime()) or "none"))
  say("nameplate: " .. tostring(e.plateUnit or "none (enemy nameplates off or out of range)")
    .. " | nameplate bars " .. (Core.db.capPlates ~= false and "on" or "off"))
end

function Commands.sniper(arg, msg, say)
  local sub, val = arg:match("^(%S*)%s*(.-)$")
  if sub == "test" then
    Core.sniperTest.on = not Core.sniperTest.on
    Core.sniperTest.go = false
    if Core.sniperTest.on then
      Core.sniperDriver:Show()
      say("sniper test ON: target anything with a visible nameplate (V / Shift+V). /wb go = kill-window look. /wb sniper test = stop")
    else
      Core.sniperDriver:Hide()
      Core.UpdateSniper(nil)
      say("sniper test off")
    end
  elseif sub == "color" then
    if Core.SNIPER_COLORS[val] then
      Core.db.sniperColor = val
      say("sniper color: " .. val)
    else
      local names = {}
      for k in pairs(Core.SNIPER_COLORS) do names[#names + 1] = k end
      table.sort(names)
      say("/wb sniper color NAME  (" .. table.concat(names, ", ") .. ")")
    end
  elseif sub == "size" and tonumber(val) then
    Core.db.sniperScale = math.max(0.5, math.min(3, tonumber(val)))
    say("sniper size: x" .. Core.db.sniperScale)
  elseif sub == "sound" then
    local n = tonumber(val)
    if n and n >= 0 and n <= #Core.SNIPER_SOUNDS then
      Core.db.sniperSound = n
      Core.PlaySniperSound()
      say("lock-on sound: " .. (Core.SNIPER_SOUNDS[n] and Core.SNIPER_SOUNDS[n].name or "off"))
    else
      local list = {}
      for i, snd in ipairs(Core.SNIPER_SOUNDS) do
        list[#list + 1] = i .. "=" .. snd.name
      end
      say("/wb sniper sound N  (" .. table.concat(list, ", ") .. ", 0=off)")
    end
  elseif sub == "why" then
    -- Each step the scope needs, stopping at the first that fails.
    local function check(ok, pass, fail)
      say((ok and Hex("success") .. "ok|r " or Hex("error") .. "no|r ") .. (ok and pass or fail))
      return ok
    end
    if not check(Core.On("sniper"), "scope switched on", "scope switched off: /wb sniper turns it on") then return end
    if not check(UnitExists("target"), "you have a target", "no target") then return end
    if not check(C_NamePlate and C_NamePlate.GetNamePlateForUnit, "nameplate API present",
      "this client has no nameplate API") then return end
    local okP, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
    if not check(okP and plate, "target has a nameplate",
      "the game reports no nameplate for your target (nameplates hidden: press V, or a nameplate addon hides it)") then return end
    check(not (plate.IsForbidden and plate:IsForbidden()), "nameplate is usable", "nameplate is forbidden to addons here")
    local unit = Core.TargetPlateUnit()
    check(unit ~= nil, "nameplate unit token " .. tostring(unit),
      "no nameplate unit token (plate.namePlateUnitToken missing and no nameplateN matches your target)")
    local okA = pcall(Core.sniper.SetPoint, Core.sniper, "CENTER", plate, "BOTTOM", 0, Core.db.sniperY or -62)
    check(okA, "scope can anchor to the plate", "anchoring to the plate failed")
    check(Core.sniper:IsShown(), "scope is showing", "scope is hidden (try /wb sniper test)")
    if Core.active and not Core.sniperTest.on then
      say("in a match the scope marks the recommended kill target: " .. (Core.killNow and Core.killNow.display or "none in reach"))
    end
  elseif sub == "y" and tonumber(val) then
    Core.db.sniperY = math.max(-200, math.min(120, tonumber(val)))
    say("sniper offset from nameplate bottom: " .. Core.db.sniperY .. " (negative = lower, onto the body)")
  else
    local on = Core.SetFeature("sniper", not Core.On("sniper"))
    say("sniper scope over the " .. (Core.PriorityOn() and "kill target" or "your target") .. ": "
      .. (on and "on" or "off") .. "  (/wb sniper y N to raise/lower)")
  end
end

function Commands.sound(arg, msg, say)
  local on = Core.SetFeature("sound", not Core.On("sound"))
  say("Highground sounds: " .. (on and "on" or "off"))
end

function Commands.go(arg, msg, say)
  if Core.sniperTest.on then
    Core.sniperTest.go = not Core.sniperTest.go
    if Core.sniperTest.go and Core.On("sound") then
      Core.PlayGoSound()
    end
    say("sniper test: kill-window look " .. (Core.sniperTest.go and "on" or "off"))
    return
  end
  local top = Core.order[1]
  if top then
    top.burnedAt = GetTime()
    top.range = top.range or "attack"
    top.def, top.cc, top.dead = false, false, false
    if Core.testMode then
      Core.Tick()
    end
    say("kill-window preview on " .. top.display .. (Core.testMode and "" or " (live data may override)"))
  else
    say("no enemies listed: try /wb test first")
  end
end

function Commands.lock(arg, msg, say)
  Core.db.locked = true
  say("locked")
end

function Commands.unlock(arg, msg, say)
  Core.db.locked = false
  say("unlocked: drag to move")
end

function Commands.reset(arg, msg, say)
  Core.pos.point = nil
  Core.frame:ClearAllPoints()
  Core.frame:SetPoint("RIGHT", UIParent, "RIGHT", -260, 80)
end
