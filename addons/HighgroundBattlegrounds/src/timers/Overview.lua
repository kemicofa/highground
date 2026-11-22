local _, ns = ...
local T, U = ns.Timers, ns.Util

local function ObjectivePlan(mine)
  local bg = ns.GetBG and ns.GetBG()
  if not bg then return end
  if bg.kind == "ctf" then
    local carriers = ns.Flags and ns.Flags.carriers or {}
    local ours, theirs = carriers[mine], carriers[T.Other(mine)]
    if theirs and theirs.name then return ns.Locale:Get("battlegrounds.overview.return_our_flag_protect_carrier.8dd9d1") end
    if ours and ours.name then return ns.Locale:Get("battlegrounds.overview.escort_our_carrier_home.3c6acd") end
    return ns.Locale:Get("battlegrounds.overview.capture_their_flag_defend_ours.3ca1da")
  elseif bg.kind == "orb" then return ns.Locale:Get("battlegrounds.overview.hold_orbs_protect_carriers.b8a117")
  elseif bg.kind == "carry" then return ns.Locale:Get("battlegrounds.overview.hold_towers_deliver_the_flag.88f126")
  elseif bg.kind == "nodes" then return ns.Locale:Get("battlegrounds.overview.capture_and_defend_bases.cfcae3") end
end

-- Sightings are observations, never an estimate of the whole enemy team.
function T.BaseSightings(node, now)
  local count, newest = 0, nil
  for _, seen in pairs(ns.Intel and ns.Intel.intel or {}) do
    if not seen.dead and now - seen.t <= 30 and seen.how ~= "recent"
      and ((seen.area and ns.NodeForArea(seen.area) == node.name)
        or (seen.x and node.x and (seen.x - node.x)^2 + (seen.y - node.y)^2 < 0.035^2)) then
      count, newest = count + 1, math.max(newest or 0, seen.t)
    end
  end
  return count, newest and now - newest
end

-- Rows come from the window's pool (Timers.RowPool); the node list and its
-- order are reused between refreshes.
local nodes, sortMine = {}, nil
local function ByUrgency(a, b)
  local at = a.assault and a.owner == sortMine and (a.capEnd or math.huge) or math.huge
  local bt = b.assault and b.owner == sortMine and (b.capEnd or math.huge) or math.huge
  return at < bt or (at == bt and a.name < b.name)
end
local function NewRow(pool) return pool and pool:New() or {} end

function T.AddOverview(rows, now, pool)
  if not ns.Core.On("objectiveOverview") then return end
  local mine = T.MyTeam()
  local win, need
  for _, row in ipairs(rows) do
    -- kind/team, not the translated tag and team names.
    if row.kind == "WIN" then win = row end
    if row.kind == "NEED" and row.team == mine then need = row end
  end
  local plan
  if win then
    local ours = win.team == mine
    local message = ours and ns.Locale:Get("battlegrounds.overview.hold_bases_to_win.b95577") or need and need.text:gsub("^%a+ needs", "Hold") or ns.Locale:Get("battlegrounds.overview.take_another_objective.d552f5")
    plan = NewRow(pool)
    plan.tag, plan.color, plan.text, plan.time = ns.Locale:Get("battlegrounds.mechanics.plan.5a61e6"),
      ns.Theme.Rgb(ours and "success" or "warning"), message, ""
    plan.detail = ns.Locale:Format("battlegrounds.overview.message_assumes_current_scoring_continues_and_captures.99b696", { message = message })
  else
    local message = ObjectivePlan(mine)
    if message then
      plan = NewRow(pool)
      plan.tag, plan.text, plan.time, plan.color = ns.Locale:Get("battlegrounds.mechanics.plan.5a61e6"), message, "", ns.Theme.Rgb("info")
    end
  end
  if plan then table.insert(rows, 1, plan) end
  wipe(nodes)
  for _, node in pairs(T.nodes) do if node.hasGraveyard then nodes[#nodes + 1] = node end end
  sortMine = mine
  table.sort(nodes, ByUrgency)
  for _, node in ipairs(nodes) do
    local count, age = T.BaseSightings(node, now)
    local sight = count > 0 and ns.Locale:Format("battlegrounds.overview.count_seen_age_s_ago.3861e1", { count = string.format("%d", count), age = string.format("%d", age) }) or ns.Locale:Get("battlegrounds.overview.no_recent_sightings.5bf248")
    local row = NewRow(pool)
    rows[#rows + 1] = row
    row.tag = node.assault and ns.Locale:Get("battlegrounds.overview.contest.22f1df") or node.owner == mine and ns.Locale:Get("battlegrounds.overview.ours.f466db")
      or node.owner and ns.Locale:Get("battlegrounds.overview.theirs.8f27a7") or ns.Locale:Get("battlegrounds.overview.neutral.4edd34")
    row.text = node.name .. sight
    row.color = node.owner and T.TeamColor(node.owner) or ns.Theme.Rgb("textMuted")
    row.left = node.assault and node.capEnd and math.max(0, node.capEnd - now)
    row.total, row.time = T.CapTime(), not node.assault and "" or nil
    if node.assault and node.owner == mine and node.capEnd and node.capEnd > now and node.capEnd - now <= 10 then
      local id = node.name .. ":" .. tostring(node.capEnd)
      T.lastUrgent = T.lastUrgent or {}
      if T.lastUrgent[node.name] ~= id then
        T.lastUrgent[node.name] = id
        ns.Alerts.Emit("objective", id, ns.Locale:Format("battlegrounds.overview.node_name_falls_in_value3.fd19ef", { node_name = node.name, value3 = T.Clock(node.capEnd - now) }), U.AlertSound)
      end
    end
  end
end
