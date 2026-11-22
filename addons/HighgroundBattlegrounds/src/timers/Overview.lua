local _, ns = ...
local T, U = ns.Timers, ns.Util

local function ObjectivePlan(mine)
  local bg = ns.GetBG and ns.GetBG()
  if not bg then return end
  if bg.kind == "ctf" then
    local carriers = ns.Flags and ns.Flags.carriers or {}
    local ours, theirs = carriers[mine], carriers[T.Other(mine)]
    if theirs and theirs.name then return "Return our flag; protect carrier" end
    if ours and ours.name then return "Escort our carrier home" end
    return "Capture their flag; defend ours"
  elseif bg.kind == "orb" then return "Hold orbs; protect carriers"
  elseif bg.kind == "carry" then return "Hold towers; deliver the flag"
  elseif bg.kind == "nodes" then return "Capture and defend bases" end
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
    if row.tag == "WIN" then win = row end
    if row.tag == "NEED" and row.text:find(mine == "A" and "Alliance" or "Horde", 1, true) == 1 then need = row end
  end
  local plan
  if win then
    local ours = win.text:find(mine == "A" and "Alliance" or "Horde", 1, true) == 1
    local message = ours and "Hold bases to win" or need and need.text:gsub("^%a+ needs", "Hold") or "Take another objective"
    plan = NewRow(pool)
    plan.tag, plan.color, plan.text, plan.time = "PLAN", ns.Theme.Rgb(ours and "success" or "warning"), message, ""
    plan.detail = message .. ". Assumes current scoring continues and captures in progress complete."
  else
    local message = ObjectivePlan(mine)
    if message then
      plan = NewRow(pool)
      plan.tag, plan.text, plan.time, plan.color = "PLAN", message, "", ns.Theme.Rgb("info")
    end
  end
  if plan then table.insert(rows, 1, plan) end
  wipe(nodes)
  for _, node in pairs(T.nodes) do if node.hasGraveyard then nodes[#nodes + 1] = node end end
  sortMine = mine
  table.sort(nodes, ByUrgency)
  for _, node in ipairs(nodes) do
    local count, age = T.BaseSightings(node, now)
    local sight = count > 0 and string.format(" · %d seen %ds ago", count, age) or " · no recent sightings"
    local row = NewRow(pool)
    rows[#rows + 1] = row
    row.tag = node.assault and "CONTEST" or node.owner == mine and "OURS" or node.owner and "THEIRS" or "NEUTRAL"
    row.text = node.name .. sight
    row.color = node.owner and T.TeamColor(node.owner) or ns.Theme.Rgb("textMuted")
    row.left = node.assault and node.capEnd and math.max(0, node.capEnd - now)
    row.total, row.time = T.CapTime(), not node.assault and "" or nil
    if node.assault and node.owner == mine and node.capEnd and node.capEnd > now and node.capEnd - now <= 10 then
      local id = node.name .. ":" .. tostring(node.capEnd)
      T.lastUrgent = T.lastUrgent or {}
      if T.lastUrgent[node.name] ~= id then
        T.lastUrgent[node.name] = id
        ns.Alerts.Emit("objective", id, node.name .. " falls in " .. T.Clock(node.capEnd - now), U.AlertSound)
      end
    end
  end
end
