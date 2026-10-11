local _, ns = ...
local Timers = ns.Timers

local AddLayer = ns.AddMapLayer or function() end -- Pins.xml failed to load: timers still run
AddLayer(function(mapID)
  local items = {}
  if not (Timers.Enabled() and mapID == Timers.MapID() and ns.IsActive and ns.IsActive()) then
    return items
  end
  local now = GetTime()
  local placed = Timers.LiveGYs(mapID, now)
  local capOn = {} -- [node name] = true: its capture timer is on a graveyard marker
  for _, it in ipairs(placed) do
    local g, nw, est = it.g, it.nw, it.est
    local c = Timers.TeamColor(g.team)
    local n = g.node and Timers.nodes[g.node]
    if not n then
      for _, nd in pairs(Timers.nodes) do
        if nd.assault and nd.x and (nd.x - g.x) ^ 2 + (nd.y - g.y) ^ 2 < 0.05 ^ 2 then
          n = nd
        end
      end
    end
    local cap = n and n.assault and n or nil
    local label = nw and (((est or g.conf == "cap") and "~" or "") .. Timers.Clock(nw - now)) or "?"
    if cap then
      capOn[cap.name] = true
      label = label .. "  cap " .. (cap.capEnd and Timers.Clock(cap.capEnd - now) or "?")
    end
    local name = Timers.GYMapName(g)
    if name ~= "" and name ~= "?" then label = name .. "\n" .. label end
    items[#items + 1] = {
      x = g.x, y = g.y + (g.configured and 0 or 0.025), size = 16,
      ring = c, icon = "Interface\\Icons\\Spell_Holy_Resurrection",
      label = label, labelColor = c, alpha = nw and 1 or 0.6,
      tooltip = function(tt)
        tt:AddLine((g.team == Timers.MyTeam() and "Your" or "Enemy") .. " graveyard: " .. Timers.GYName(g), c[1], c[2], c[3])
        if nw then
          tt:AddLine(string.format("Next res in %s%s", Timers.Clock(nw - now),
            est and " (estimated from enemy deaths)" or g.conf == "cap" and " (from base capture time)" or ""), 1, 1, 1)
        else
          tt:AddLine("Res timer unknown yet", 0.7, 0.7, 0.7)
        end
        if cap then
          local cc = Timers.TeamColor(cap.assault)
          tt:AddLine((cap.assault == Timers.MyTeam() and "Your team" or "Enemy") .. " capping " .. cap.name
            .. (cap.capEnd and (": " .. Timers.Clock(cap.capEnd - now)) or ""), cc[1], cc[2], cc[3])
        end
      end,
    }
  end
  if ns.flagRespawnAt and ns.flagRespawnAt > now then
    items[#items + 1] = {
      x = 0.5, y = 0.5, size = 14, ring = { 1, 1, 1 }, label = "FLAG " .. Timers.Clock(ns.flagRespawnAt - now),
      tooltip = function(tt)
        tt:AddLine("Flag respawns in " .. Timers.Clock(ns.flagRespawnAt - now), 1, 1, 1)
      end,
    }
  end
  for _, n in pairs(Timers.nodes) do
    if n.assault and not capOn[n.name] then
      local c = Timers.TeamColor(n.assault)
      items[#items + 1] = {
        x = n.x, y = n.y - 0.03, size = 12, ring = c,
        label = n.capEnd and Timers.Clock(n.capEnd - now) or "?", labelColor = c,
        tooltip = function(tt)
          tt:AddLine(n.name, 1, 0.82, 0)
          tt:AddLine((n.assault == Timers.MyTeam() and "Your team" or "Enemy") .. " capping"
            .. (n.capEnd and (": " .. Timers.Clock(n.capEnd - now)) or ""), c[1], c[2], c[3])
        end,
      }
    end
  end
  return items
end)
