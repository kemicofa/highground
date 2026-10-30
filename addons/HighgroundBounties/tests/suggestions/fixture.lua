local F = dofile("../HighgroundBounties/tests/public/fixture.lua")
local H = { F = F }
H.roster = { { "Alice-Realm", 5 }, { "Mira-Realm", 5 }, { "Thorn-Realm", 5 }, { "Officer-Realm", 1 } }

function H.new(name, options)
  options = options or {}
  options.saved = options.saved or { bountySuggestions = true, bountyDeathShare = true }
  options.guild, options.roster = options.guild or "Night Watch", options.roster or H.roster
  if options.addon == "Highground" then options.runtime = dofile("../../tools/wowsim/battleground/runtime.lua") end
  if options.geometry then
    local runtime = options.runtime or dofile("../../tools/wowsim/runtime.lua")
    options.runtime = function(client, saved, configure)
      return runtime(client, saved, function(s, e) dofile("../../tools/wowsim/geometry.lua")(s); configure(s, e) end)
    end
  end
  return F.new(name or "Alice", options)
end

function H.death(s, name, recap, kind, overkill)
  s.units.player.dead = false; s:event("PLAYER_ALIVE")
  if s.ns.Caps.combatLog then
    local sub = kind or "SPELL_DAMAGE"
    s.combatEvent = { s.now, sub, false, "Player-enemy", name, 0x548, 0,
      s.units.player.guid, s.units.player.name, 0x511, 0 }
    local fields = sub == "SWING_DAMAGE" and { 100, overkill or 0, 1 }
      or sub == "ENVIRONMENTAL_DAMAGE" and { "FALLING", 100, overkill or 0 }
      or { 1, "Hit", 1, 100, overkill or 0 }
    for _, v in ipairs(fields) do s.combatEvent[#s.combatEvent + 1] = v end
    s:event("COMBAT_LOG_EVENT_UNFILTERED")
  else
    s.env.C_DeathRecap = { GetRecapEvents = function()
      return recap or { { timestamp = s.epoch + s.now, sourceName = name, sourceFlags = 0x548 } }
    end }
  end
  s.units.player.dead = true; s:event("PLAYER_DEAD"); s:event("PLAYER_DEAD")
  s:advance(3)
end

function H.packets(s)
  local out = {}
  for _, packet in ipairs(s.sent) do if packet.prefix == s.ns.Bounty.Suggestions.PREFIX then out[#out + 1] = packet end end
  return out
end

function H.deliver(from, to)
  F.deliver(from, to, H.packets(from))
end

function H.receive(s, text, sender, channel)
  s:event("CHAT_MSG_ADDON", s.ns.Bounty.Suggestions.PREFIX, text, channel or "GUILD", sender or "Mira-Realm")
end
return H
