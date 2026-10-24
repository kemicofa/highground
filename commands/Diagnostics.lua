local _, ns = ...
local Core, Options, Commands = ns.Core, ns.Options, ns.Commands

function Commands.why(arg, msg, say)
  local cfg = (Core.me.range or ns.RangeBands[Core.me.class])
  local reach = cfg and (cfg.reachYards or cfg.attackYards) or 40
  say(string.format("kill target = eligible live priority within %d yd (%s), with a switch margin. Your target doesn't count.",
    reach, Core.me.class or "?"))
  say("kill target: " .. (Core.killNow and Core.killNow.display or "none eligible"))
  local list = {}
  for _, e in ipairs(Core.order) do
    list[#list + 1] = e
  end
  table.sort(list, function(a, b)
    return (a.live or 0) > (b.live or 0)
  end)
  for i = 1, math.min(#list, 10) do
    local e = list[i]
    local parts = {}
    for _, w in ipairs(Core.WEIGHTS) do
      local v = e.comp and e.comp[w.key]
      if v and math.abs(v) >= 0.5 then
        parts[#parts + 1] = string.format("%s%+.0f", w.key, v)
      end
    end
    local where = Core.TargetBlocked(e) or e.yards and string.format("%dyd", e.yards)
      or e.plateUnit and ">range" or "unseen"
    say(string.format("%s%d. %s  live %.0f  %s  %s%s", e == Core.killNow and "|cffff6b1f" or "", i,
      e.display:match("^[^-]+"), e.live or 0, where, table.concat(parts, " "), e == Core.killNow and "|r" or ""))
  end
  local a = Core.db.liveStats and Core.db.liveStats.auras
  say(string.format("aura reads: plain %d, secret %d, error %d%s", a and a.plain or 0, a and a.secret or 0,
    a and a.error or 0, Core.db.auraErr and (" (" .. Core.db.auraErr .. ")") or ""))
end

function Commands.kit(arg, msg, say)
  local key = UnitExists("target") and Core.CanonUnit("target")
  local e = (key and Core.enemies[key]) or Core.killNow
  if not e then
    say("target an enemy (or have a kill target) first")
  elseif not ns.Kits then
    say("cooldown tracking needs the combat log (Cata Classic only)")
  else
    say(e.display .. " (" .. (e.specID and Core.specInfo[e.specID] and Core.specInfo[e.specID].name or "?") .. " " .. e.class .. ")")
    for _, entry in ipairs(Core.KitFor(e)) do
      local left = Core.CdLeft(e, entry)
      local active = e.activeCooldowns and e.activeCooldowns[entry[1]]
      local status = active and "ACTIVE" or left and ("DOWN " .. Core.Clock(left))
        or (e.cds and e.cds[entry[1]] and "estimated ready" or "not observed")
      say(string.format("  %-20s %s", entry[4], status))
    end
  end
end

function Commands.err(arg, msg, say)
  if Core.db.apiMissing and #Core.db.apiMissing > 0 then
    say("missing on this client: " .. table.concat(Core.db.apiMissing, ", "))
  end
  local n = 0
  for key, rec in pairs(Core.db.errors or {}) do
    n = n + 1
    say(string.format("|cffff4040%s|r x%d (since %s)", key, rec.count, rec.first))
  end
  say(n == 0 and "no errors recorded" or "full traces saved: /reload so they can be read from SavedVariables")
  for group, g in pairs(Core.db.liveStats or {}) do
    if type(g) == "table" then
      local parts = {}
      for k, v in pairs(g) do
        parts[#parts + 1] = k .. "=" .. v
      end
      say(group .. ": " .. table.concat(parts, " "))
    end
  end
  if Core.db.liveStats and Core.db.liveStats.maxVisible then
    say("most enemies visible at once: " .. Core.db.liveStats.maxVisible)
  end
  if Core.db.healthErr then
    say("health error: " .. Core.db.healthErr)
  end
  say("roster: " .. (Core.rosterStatus or "ok") .. string.format(" | active=%s enemies=%d allyFaction=%s",
    tostring(Core.active), (function() local c = 0 for _ in pairs(Core.enemies) do c = c + 1 end return c end)(),
    tostring(Core.allyFaction)))
end

function Commands.clearerr(arg, msg, say)
  Core.db.errors, Core.lastError = nil, nil
  say("errors cleared")
end

function Commands.probe(arg, msg, say)
  Core.Probe(say)
end

function Commands.map(arg, msg, say)
  Core.mapKey = nil
  Core.DetectMap()
  local ui = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local name, _, _, _, _, _, _, inst = GetInstanceInfo()
  say(string.format("%s  uiMap=%s instance=%s", tostring(name), tostring(ui), tostring(inst)))
  if Core.currentBG then
    local tilts = {}
    for k, v in pairs(Core.currentProfile or {}) do
      if k ~= "label" then tilts[#tilts + 1] = k .. " x" .. v end
    end
    say(string.format("profile: %s (%s)%s  %s", Core.currentBG.name, Core.currentProfile.label, Core.isBlitz and " +Blitz" or "",
      table.concat(tilts, ", ")))
  else
    say("no battleground profile for this map (default weights)")
  end
end

function Commands.help(arg, msg, say)
  Core.UpdateMe()
  local si = Core.me.specID and Core.specInfo[Core.me.specID]
  say(string.format("you: %s %s (%s, %s)", si and si.name or "?", Core.me.class or "?", Core.me.dmg,
    Core.me.melee and "melee" or "ranged"))
  say("/wb intel | priority | arena | config | profile | export | import | points | why | kit | test | go | call | mark | probe | cap why|probe|clear | map | sound | sniper | pressure | weights | live | lock | unlock | all | rows N | scale X | compact [on|off] | opacity PCT | exec PCT | reset")
  say("Keybind 'Target kill-order #1' under Key Bindings > AddOns.")
end
