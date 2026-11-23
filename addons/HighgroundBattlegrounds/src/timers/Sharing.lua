local _, ns = ...
local Timers, Comms = ns.Timers, ns.Comms

---------------------------------------------------------------------------
-- Timer sharing (prefix HighgroundT, group channel): exact waves (you dead
-- at a healer) and enemy vote intervals, at most 10 queued per flush.
--   2:mapID:W,team,x,y,secondsUntilWave,area
--   2:mapID:V,x,y,diedAgo,seenAgo,area
-- x/y in 1/10000 of the map, 0 = unknown; area is the sub-zone name.
---------------------------------------------------------------------------
-- A full outbox (messages kept while sending is refused) drops its oldest.
function Timers.Queue(msg)
  if #Timers.outbox >= 10 then
    table.remove(Timers.outbox, 1)
  end
  Timers.outbox[#Timers.outbox + 1] = msg
end

function ns.ShareWave(g)
  if not g then return end
  local now = GetTime()
  local nw = Timers.NextWave(g, now)
  if nw and (not g.sharedAt or now - g.sharedAt > 10) then
    g.sharedAt = now
    Timers.Queue({ kind = "W", team = g.team, x = g.x, y = g.y, at = nw, area = g.label })
  end
end

function ns.ShareVote(x, y, t0, t1, area)
  Timers.Queue({ kind = "V", x = x, y = y, t0 = t0, t1 = t1, area = area })
end

function Timers.Flush()
  local db = Timers.DB()
  local chan = Comms.GroupChannel()
  local mapID = Timers.MapID()
  if #Timers.outbox == 0 or not (chan and mapID and db and ns.Core.On("intelShare") and Comms.CanSend()) then
    wipe(Timers.outbox)
    return
  end
  -- Refused messages stay queued and are encoded again, from their absolute
  -- times, on the next flush.
  if Comms.Blocked() then
    Timers.stats.unsent = Timers.stats.unsent + 1
    return
  end
  local now, entries = GetTime(), {}
  for _, msg in ipairs(Timers.outbox) do
    local area = ns.Util.Clean(msg.area)
    local x, y = math.floor((msg.x or 0) * 10000), math.floor((msg.y or 0) * 10000)
    local part
    if msg.kind == "W" then
      local at, period = msg.at, Timers.WaveCycle()
      if at < now and period then at = at + math.ceil((now - at) / period) * period end
      if at >= now then
        part = string.format("W,%s,%d,%d,%d,%s", msg.team, x, y, math.floor(at - now + 0.5), area)
      end
    else
      part = string.format("V,%d,%d,%d,%d,%s", x, y, math.floor(now - msg.t0), math.floor(now - msg.t1), area)
    end
    if part then entries[#entries + 1] = { msg = msg, part = part } end
  end
  -- Send complete records only: truncating a long area name can relocate a
  -- wave, and truncating a timestamp can corrupt its phase. After a refused
  -- packet, keep it and the rest for the next flush.
  local prefix, packet, batch, kept = "2:" .. mapID .. ":", "", {}, {}
  local function Send()
    if packet == "" then return end
    if #kept == 0 and Comms.Send(Timers.PREFIX, prefix .. packet, chan) then
      Timers.stats.sent = Timers.stats.sent + 1
    else
      Timers.stats.unsent = Timers.stats.unsent + 1
      for _, msg in ipairs(batch) do kept[#kept + 1] = msg end
    end
    packet, batch = "", {}
  end
  for _, e in ipairs(entries) do
    if #prefix + #e.part <= 255 then
      if #prefix + #packet + #e.part + 1 > 255 then Send() end
      packet = packet == "" and e.part or (packet .. ";" .. e.part)
      batch[#batch + 1] = e.msg
    end
  end
  Send()
  wipe(Timers.outbox)
  for i, msg in ipairs(kept) do Timers.outbox[i] = msg end
end

function Timers.Receive(text, sender)
  if ns.Core.IsMe(sender) then
    return
  end
  local ver, map, body = text:match("^(%d+):(%d+):(.*)$")
  if ver ~= "2" or tonumber(map) ~= Timers.MapID() then
    return
  end
  Timers.stats.recv = Timers.stats.recv + 1
  local now = GetTime()
  local function spot(x, y, area)
    x, y = tonumber(x) or 0, tonumber(y) or 0
    area = area ~= "" and area or nil
    if x == 0 and y == 0 then
      if Timers.ConfiguredGYs() then return nil, nil, area end
      return ns.AreaXY and ns.AreaXY(Timers.MapID(), area), nil, area
    end
    return x / 10000, y / 10000, area
  end
  for tok in body:gmatch("[^;]+") do
    local kind, rest = tok:match("^(%a),(.+)$")
    if kind == "W" then
      local team, x, y, left, area = rest:match("^(%a),(%d+),(%d+),(%-?%d+),?(.*)$")
      if (team == "A" or team == "H") and left then
        local gx, gy, garea = spot(x, y, area)
        if gx and not gy then
          gx, gy = ns.AreaXY(Timers.MapID(), garea)
        end
        local g = (gx or garea) and Timers.GetGY(team, gx, gy, true, garea) or Timers.TeamGY(team)
        Timers.SetWave(g, now + tonumber(left), "shared") -- transit time is not locally observable
      end
    elseif kind == "V" then
      local x, y, ago0, ago1, area = rest:match("^(%d+),(%d+),(%d+),(%d+),?(.*)$")
      if x and ago1 then
        local gx, gy, garea = spot(x, y, area)
        if gx and not gy then
          gx, gy = ns.AreaXY(Timers.MapID(), garea)
        end
        local g = Timers.VoteGY(Timers.Other(Timers.MyTeam()), gx, gy, garea)
        if g then Timers.Vote(g, now - tonumber(ago0), now - tonumber(ago1)) end
      end
    end
  end
end
