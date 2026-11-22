local _, ns = ...
local Timers = ns.Timers

local Tip = Timers.TipLine
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
      label = ns.Locale:Format("battlegrounds.layer.label_cap_value3.2a8bda", { label = label, value3 = (cap.capEnd and Timers.Clock(cap.capEnd - now) or "?") })
    end
    local name = Timers.GYMapName(g)
    if name ~= "" and name ~= "?" then label = name .. "\n" .. label end
    items[#items + 1] = {
      x = g.x, y = g.y + (g.configured and 0 or 0.025), size = 16,
      ring = c, icon = "Interface\\Icons\\Spell_Holy_Resurrection",
      label = label, labelColor = c, alpha = nw and 1 or 0.6,
      tooltip = function(tt)
        Tip(tt, ns.Locale:Format("battlegrounds.layer.value1_graveyard_value3.8368c3", { value1 = (g.team == Timers.MyTeam() and ns.Locale:Get("battlegrounds.layer.your.ba596f") or ns.Locale:Get("battlegrounds.layer.enemy.a25632")), value3 = Timers.GYName(g) }), c)
        if nw then
          Tip(tt, ns.Locale:Format("battlegrounds.layer.next_res_in_value1_value2.944c3a", { value1 = string.format("%s", Timers.Clock(nw - now)), value2 = string.format("%s", est and ns.Locale:Get("battlegrounds.layer.estimated_from_enemy_deaths.71fbd2") or g.conf == "cap" and ns.Locale:Get("battlegrounds.layer.from_base_capture_time.8580e8") or "") }), "white")
        else
          Tip(tt, ns.Locale:Get("battlegrounds.layer.res_timer_unknown_yet.39019e"), "textMuted")
        end
        if cap then
          Tip(tt, ns.Locale:Format("battlegrounds.layer.value1_capping_cap_name_value4.d9f5e0", { value1 = (cap.assault == Timers.MyTeam() and ns.Locale:Get("battlegrounds.layer.your_team.80b301") or ns.Locale:Get("battlegrounds.layer.enemy.a25632")), cap_name = cap.name, value4 = (cap.capEnd and (": " .. Timers.Clock(cap.capEnd - now)) or "") }), Timers.TeamColor(cap.assault))
        end
      end,
    }
  end
  if ns.flagRespawnAt and ns.flagRespawnAt > now then
    items[#items + 1] = {
      x = 0.5, y = 0.5, size = 14, ring = ns.Theme.Rgb("white"), label = ns.Locale:Format("battlegrounds.layer.flag_value2.b526b8", { value2 = Timers.Clock(ns.flagRespawnAt - now) }),
      tooltip = function(tt)
        Tip(tt, ns.Locale:Format("battlegrounds.layer.flag_respawns_in_value2.245d42", { value2 = Timers.Clock(ns.flagRespawnAt - now) }), "white")
      end,
    }
  end
  for _, n in pairs(Timers.nodes) do
    if n.assault and not capOn[n.name] then
      local c = Timers.TeamColor(n.assault)
      items[#items + 1] = {
        -- Timer text only, in the capturing team's color, above the base icon.
        x = n.x, y = n.y - 0.03, size = 12,
        label = n.capEnd and Timers.Clock(n.capEnd - now) or "?", labelColor = c,
        tooltip = function(tt)
          Tip(tt, n.name, "gold")
          Tip(tt, ns.Locale:Format("battlegrounds.layer.value1_capping_value3.18befe", { value1 = (n.assault == Timers.MyTeam() and ns.Locale:Get("battlegrounds.layer.your_team.80b301") or ns.Locale:Get("battlegrounds.layer.enemy.a25632")), value3 = (n.capEnd and (": " .. Timers.Clock(n.capEnd - now)) or "") }), c)
        end,
      }
    end
  end
  return items
end)
