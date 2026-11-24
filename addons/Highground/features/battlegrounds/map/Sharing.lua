local _, ns = ...
local Intel, Comms = ns.Intel, ns.Comms

---------------------------------------------------------------------------
-- Intel sharing (prefix HighgroundI, group channel). Message v3:
--   3:mapID:@,myArea;key,x,y,r,age,how,area;key,D;key,A,tenths;...
-- x/y in 1/10000 of the map, 0 = unknown; age in seconds so clocks don't
-- need to agree; how keeps the position's provenance, unknown included.
-- A death (D) is followed by its age in tenths of a second (A) when under
-- a minute. Older versions skip A and time the death on arrival.
-- Legacy v2 could send a release graveyard as the observer's position:
-- its area and death reports are accepted, its bare coordinates never.
---------------------------------------------------------------------------
local Clean = ns.Util.Clean

Intel.MAX_DEATH_AGE = 600 -- tenths of a second

-- One message's tokens and keys, and the keys of refused messages: buffers
-- reused by every send (every SEND_EVERY seconds).
local parts, keys, kept = {}, {}, {}
local head, len, chan, refused
local function Flush()
  if #parts > 0 then
    if not refused and Comms.Send(Intel.PREFIX, head .. table.concat(parts, ";"), chan) then
      Intel.stats.sent = Intel.stats.sent + 1
    else
      Intel.stats.unsent = Intel.stats.unsent + 1
      refused = true
      for _, key in ipairs(keys) do kept[key] = true end
    end
  end
  wipe(parts); wipe(keys)
  len = #head
end
local function Add(tok, key)
  if len + #tok + 1 > 250 then
    Flush()
  end
  parts[#parts + 1] = tok
  keys[#keys + 1] = key
  len = len + #tok + 1
end

function Intel.Send()
  chan = Comms.GroupChannel()
  local mapID = Intel.MapID()
  if not (chan and mapID and Intel.DB() ~= nil and ns.Core.ShareOn()) then
    wipe(Intel.mine)
    return
  end
  -- Refused sightings stay in Intel.mine; the next send reports their
  -- state then, so a late message is never staler than the sighting.
  if Comms.Blocked() then
    Intel.stats.unsent = Intel.stats.unsent + 1
    return
  end
  local now = GetTime()
  head = "3:" .. mapID .. ":"
  len, refused = #head, false
  wipe(parts); wipe(keys); wipe(kept)
  local area = Intel.MyArea()
  if area then
    Add("@," .. Clean(area))
  end
  for key in pairs(Intel.mine) do
    local it = Intel.intel[key]
    if it and it.dead then
      local tenths = math.floor(math.max(0, now - it.t) * 10 + 0.5)
      Add(tenths <= Intel.MAX_DEATH_AGE and string.format("%s,D;%s,A,%d", key, key, tenths) or key .. ",D", key)
    elseif it and it.by == Intel.myName then
      Add(string.format("%s,%d,%d,%d,%d,%s,%s", key, (it.x or 0) * 10000, (it.y or 0) * 10000, it.r,
        math.max(0, now - it.t), it.how or (it.x and "nearby" or "unknown"), Clean(it.area)), key)
    end
  end
  Flush()
  wipe(Intel.mine)
  for key in pairs(kept) do Intel.mine[key] = true end
end

local deaths = {} -- [key] = when: one message's deaths, with their ages
function Intel.Receive(text, sender)
  local short = sender and sender:match("^[^-]+")
  if short == Intel.myName then
    return
  end
  local ver, map, body = text:match("^(%d+):(%d+):(.*)$")
  if (ver ~= "2" and ver ~= "3") or tonumber(map) ~= Intel.MapID() then
    return
  end
  local now = GetTime()
  Intel.stats.recv = Intel.stats.recv + 1
  wipe(deaths)
  for tok in body:gmatch("[^;]+") do
    local key, rest = tok:match("^([^,]+),(.+)$")
    if key == "@" then
      Intel.allyArea[short] = { area = Clean(rest), t = now }
    elseif key and ns.enemies and ns.enemies[key] then
      if rest == "D" then
        deaths[key] = now
      elseif rest:sub(1, 2) == "A," then
        -- The age of the death just before it in this message.
        local tenths = tonumber(rest:match("^A,(%d+)$"))
        if deaths[key] and tenths and tenths <= Intel.MAX_DEATH_AGE then deaths[key] = now - tenths / 10 end
      else
        local x, y, r, age, detail = rest:match("^(%d+),(%d+),(%d+),(%d+),?(.*)$")
        if x then
          x, y = tonumber(x) / 10000, tonumber(y) / 10000
          local how, area
          if ver == "3" then how, area = detail:match("^([^,]+),(.*)$") else area = detail end
          area = Clean(area) -- shown in tooltips: no escape codes
          area = area ~= "" and area or nil
          if ver == "2" then
            x, y = Intel.AreaXY(tonumber(map), area)
            how = x and "area" or "unknown"
          elseif how == "unknown" or not Intel.ValidXY(x, y) then
            x, y, how = nil, nil, "unknown"
          elseif how ~= "coords" and how ~= "nearby" and how ~= "area" and how ~= "recent" then
            x, y, how = nil, nil, "unknown"
          end
          Intel.Record(key, x, y, tonumber(r), short, now - tonumber(age), area, how)
        end
      end
    end
  end
  for key, t in pairs(deaths) do Intel.Died(key, t) end
end

-- Short text for tooltips / the hero card, or nil when unknown. The second
-- value is false when the enemy was seen without coordinates.
function Intel.Where(key)
  local it = Intel.intel[key]
  if not it or it.dead or not Intel.Enabled() then
    return nil
  end
  local age = GetTime() - it.t
  if age > Intel.KEEP then
    return nil
  end
  local where
  if not it.x then
    where = ns.Locale:Format("battlegrounds.sharing.value1_position_unknown.65a2ee", { value1 = (it.area and (ns.Locale:Format("battlegrounds.sharing.in_it_area.29cadb", { it_area = it.area })) or "") })
  else
    where = ((it.how == "nearby" or it.how == "recent") and ns.Locale:Get("battlegrounds.sharing.near.562fe1") or ns.Locale:Get("battlegrounds.sharing.at.3bcaf6"))
      .. (it.how == "recent" and it.near or it.area or Intel.Place(it.x, it.y))
    if it.how == "area" or it.how == "objective" or it.how == "recent" then where = ns.Locale:Format("battlegrounds.sharing.where_approx.065606", { where = where }) end
  end
  local placed = it.x ~= nil
  if it.how == "objective" then
    return ns.Locale:Format("battlegrounds.sharing.last_seen_where_age_s_ago_node.522e26", { where = string.format("%s", where), age = string.format("%d", age) }), placed
  end
  if age < Intel.FRESH then
    return where .. (it.by ~= Intel.myName and (" (" .. it.by .. ")") or ""), placed
  end
  return ns.Locale:Format("battlegrounds.sharing.last_seen_where_age_s_ago.1d61a4", { where = string.format("%s", where), age = string.format("%d", age) }), placed
end
ns.MapWhere = Intel.Where
