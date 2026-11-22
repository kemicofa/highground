local _, ns = ...
local T = ns.Timers

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
local function CapRow(rows, node)
  for _, row in ipairs(rows) do
    if row.kind == "CAP" and row.node == node then return row end
  end
end
local sightArgs, planArgs, holdArgs = {}, {}, {} -- Format arguments, refilled each refresh

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
    local message
    if ours then
      message = ns.Locale:Get("battlegrounds.overview.hold_bases_to_win.b95577")
    elseif need then
      holdArgs.k, holdArgs.word, holdArgs.value4 = string.format("%d", need.count), need.noun, need.count > 1 and "s" or ""
      message = ns.Locale:Format("battlegrounds.overview.hold_k_word_value4.62953b", holdArgs)
    else
      message = ns.Locale:Get("battlegrounds.overview.take_another_objective.d552f5")
    end
    plan = T.Tag(NewRow(pool), "PLAN")
    plan.color, plan.text, plan.time = ns.Theme.Rgb(ours and "success" or "warning"), message, ""
    planArgs.message = message
    plan.detail = ns.Locale:Format("battlegrounds.overview.message_assumes_current_scoring_continues_and_captures.99b696", planArgs)
  end
  if plan then table.insert(rows, 1, plan) end
  wipe(nodes)
  for _, node in pairs(T.nodes) do if node.hasGraveyard then nodes[#nodes + 1] = node end end
  sortMine = mine
  table.sort(nodes, ByUrgency)
  for _, node in ipairs(nodes) do
    local count, age = T.BaseSightings(node, now)
    sightArgs.count, sightArgs.age = string.format("%d", count), age and string.format("%d", age) or "0"
    local seen = count > 0 and ns.Locale:Format("battlegrounds.overview.count_seen_age_s_ago.3861e1", sightArgs)
    local cap = node.assault and CapRow(rows, node)
    if cap then
      -- Its capture row already shows the base and countdown: add sightings.
      if seen then cap.text = cap.text .. seen end
    else
      local row = NewRow(pool)
      rows[#rows + 1] = row
      T.Tag(row, node.assault and "CONTEST" or node.owner == mine and "OURS" or node.owner and "THEIRS" or "NEUTRAL")
      row.text = node.name .. (seen or ns.Locale:Get("battlegrounds.overview.no_recent_sightings.5bf248"))
      row.color, row.team = node.owner and T.TeamColor(node.owner) or ns.Theme.Rgb("textMuted"), node.owner
      row.left = node.assault and node.capEnd and math.max(0, node.capEnd - now)
      row.total, row.time = T.CapTime(), not node.assault and "" or nil
    end
    if node.assault and node.owner == mine and node.capEnd and node.capEnd > now and node.capEnd - now <= 10 then
      local id = node.name .. ":" .. tostring(node.capEnd)
      T.lastUrgent = T.lastUrgent or {}
      if T.lastUrgent[node.name] ~= id then
        T.lastUrgent[node.name] = id
        ns.Alerts.Emit("objective", id, ns.Locale:Format("battlegrounds.overview.node_name_falls_in_value3.fd19ef", { node_name = node.name, value3 = T.Clock(node.capEnd - now) }), ns.Alerts.cues.objective)
      end
    end
  end
end
