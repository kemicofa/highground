local _, ns = ...
local Core, Options, Commands = ns.Core, ns.Options, ns.Commands

function Commands.intel(arg, msg, say)
  if not ns.MapWhere then
    say("|cffff5555intel map not loaded|r: Restart the game client fully after installing an update.")
    return
  end
  if arg == "test" and ns.IntelTest then
    say(ns.IntelTest() and "test pin ON: open the map, an orange rogue pin should sit mid-map" or "test pin off")
  elseif arg == "off" then
    Core.db.intel = false
  elseif arg == "on" then
    Core.db.intel = true
  elseif arg == "share off" then
    Core.db.intelShare = false
  elseif arg == "share on" then
    Core.db.intelShare = true
  end
  say(string.format("intel map %s, sharing with teammates %s", Core.db.intel == false and "OFF" or "on",
    Core.db.intelShare == false and "OFF" or "on"))
  if ns.IntelStatus then
    say(ns.IntelStatus())
  end
end

function Commands.timers(arg, msg, say)
  if arg == "off" or arg == "on" then
    Core.db.timers = arg == "on"
  elseif arg == "reset" and ns.TimersWindowReset then
    ns.TimersWindowReset()
    say("res timers and bases windows moved back to their default spots")
  end
  say("timers " .. (Core.db.timers == false and "OFF" or "on") .. (ns.TimersStatus and (" | " .. ns.TimersStatus()) or " (timer modules not loaded: restart the client)"))
end

function Commands.test(arg, msg, say)
  if Core.testMode then
    Core.testMode = false
    Core.SetActive(false)
    wipe(Core.enemies)
    Core.CheckZone()
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
      or "|cffff4040nothing|r (no kill target yet: in a BG, or /wb test first)"))
  end
end

function Commands.pressure(arg, msg, say)
  if ns.PressureCommand then
    ns.PressureCommand(arg, say)
  else
    say("Enemy focus markers have not loaded; restart the game after updating the addon.")
  end
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
  elseif sub == "y" and tonumber(val) then
    Core.db.sniperY = math.max(-200, math.min(120, tonumber(val)))
    say("sniper offset from nameplate bottom: " .. Core.db.sniperY .. " (negative = lower, onto the body)")
  else
    Core.db.sniper = not Core.db.sniper
    say("sniper scope over the kill target: " .. (Core.db.sniper and "on" or "off") .. "  (/wb sniper y N to raise/lower)")
  end
end

function Commands.sound(arg, msg, say)
  Core.db.sound = not Core.db.sound
  say("kill-window sound: " .. (Core.db.sound and "on" or "off"))
end

function Commands.go(arg, msg, say)
  if Core.sniperTest.on then
    Core.sniperTest.go = not Core.sniperTest.go
    if Core.sniperTest.go and Core.db.sound then
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
  Core.db.point = nil
  Core.frame:ClearAllPoints()
  Core.frame:SetPoint("RIGHT", UIParent, "RIGHT", -260, 80)
end
