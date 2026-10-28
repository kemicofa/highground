---------------------------------------------------------------------------
-- Bounty scenario helpers (scenarios/bounty.lua, bountyboard.lua): sounds
-- and guild packets sent, nameplates, guild messages, a guild roster and
-- the board's rows and buttons.
---------------------------------------------------------------------------
return function(new)
  local SOUND = "Interface\\AddOns\\Highground\\features\\bounties\\sounds\\bounty.ogg"

  local function bountySounds(sim)
    local n = 0
    for _, s in ipairs(sim.sounds) do if s == SOUND then n = n + 1 end end
    return n
  end

  local function guildSent(sim, pattern)
    local out = {}
    for _, m in ipairs(sim.sent) do
      if m.prefix == "HighgroundB" and m.channel == "GUILD" and (not pattern or m.message:find(pattern)) then
        out[#out + 1] = m.message
      end
    end
    return out
  end

  local function plate(sim, i, name, fields)
    fields = fields or {}
    fields.name, fields.classID = name, fields.classID or 4
    if fields.enemy == nil then fields.enemy = true end
    local token = "nameplate" .. i
    sim.units[token] = fields
    sim.plates[token] = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
    sim:event("NAME_PLATE_UNIT_ADDED", token)
    return fields
  end

  local function guildMessage(sim, text, sender)
    sim:event("CHAT_MSG_ADDON", "HighgroundB", text, "GUILD", sender)
  end

  local function lastMessage(sim) return sim.messages[#sim.messages] or "" end
  local function shown(frame) return frame ~= nil and frame:IsShown() end

  -- Guild master Boss, officer Officer, members Me (unless `rank`), Member and Rando.
  local function inGuild(client, rank, configure)
    local sim = new(client, nil, configure)
    sim.guild, sim.rank = "Night Watch", rank or 5
    sim.roster = { { "Boss-Realm", 0 }, { "Officer-Realm", 1 }, { "Me-Realm", sim.rank },
      { "Member-Realm", 5 }, { "Rando-Realm", 5 } }
    sim:event("PLAYER_GUILD_UPDATE")
    sim:event("GUILD_ROSTER_UPDATE")
    sim:advance(12) -- past the join sync, whose replies are summarized
    return sim
  end

  local function boardRow(sim, name)
    for _, r in ipairs(sim.env.HighgroundBountyFrame.rows) do
      if r:IsShown() and r.entry and (r.entry.name == name or r.entry.name == name .. "-Realm") then return r end
    end
  end

  local function button(row, label)
    for _, b in ipairs(row.buttons) do
      if b:IsShown() and b.text == label then return b end
    end
  end
  return { bountySounds = bountySounds, guildSent = guildSent, plate = plate, guildMessage = guildMessage,
    lastMessage = lastMessage, shown = shown, inGuild = inGuild, boardRow = boardRow, button = button }
end
