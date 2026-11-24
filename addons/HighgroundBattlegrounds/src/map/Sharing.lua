local _, ns = ...
local Intel, Comms = ns.Intel, ns.Comms

---------------------------------------------------------------------------
-- Intel sharing (prefix HighgroundI, group channel). Message v3:
--   3:mapID:@,myArea;key,x,y,r,age,how,area;key,D;...
-- x/y in 1/10000 of the map, 0 = unknown; age in seconds so clocks don't
-- need to agree; how keeps the position's provenance, unknown included.
-- Legacy v2 could send a release graveyard as the observer's position:
-- its area and death reports are accepted, its bare coordinates never.
---------------------------------------------------------------------------
local Clean = ns.Util.Clean

function Intel.Send()
  local chan = Comms.GroupChannel()
  local mapID = Intel.MapID()
  if not (chan and mapID and Intel.On("intelShare")) then
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
  local head = "3:" .. mapID .. ":"
  local parts, keys, len, kept = {}, {}, #head, nil
  local function flush()
    if #parts > 0 then
      if not kept and Comms.Send(Intel.PREFIX, head .. table.concat(parts, ";"), chan) then
        Intel.stats.sent = Intel.stats.sent + 1
      else
        Intel.stats.unsent = Intel.stats.unsent + 1
        kept = kept or {}
        for _, key in ipairs(keys) do kept[key] = true end
      end
    end
    parts, keys, len = {}, {}, #head
  end
  local function add(tok, key)
    if len + #tok + 1 > 250 then
      flush()
    end
    parts[#parts + 1] = tok
    keys[#keys + 1] = key
    len = len + #tok + 1
  end
  local area = Intel.MyArea()
  if area then
    add("@," .. Clean(area))
  end
  for key in pairs(Intel.mine) do
    local it = Intel.intel[key]
    if it and it.dead then
      add(key .. ",D", key)
    elseif it and it.by == Intel.myName then
      add(string.format("%s,%d,%d,%d,%d,%s,%s", key, (it.x or 0) * 10000, (it.y or 0) * 10000, it.r,
        math.max(0, now - it.t), it.how or (it.x and "nearby" or "unknown"), Clean(it.area)), key)
    end
  end
  flush()
  wipe(Intel.mine)
  for key in pairs(kept or {}) do Intel.mine[key] = true end
end

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
  for tok in body:gmatch("[^;]+") do
    local key, rest = tok:match("^([^,]+),(.+)$")
    if key == "@" then
      Intel.allyArea[short] = { area = Clean(rest), t = now }
    elseif key and ns.enemies and ns.enemies[key] then
      if rest == "D" then
        Intel.Died(key, now)
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
