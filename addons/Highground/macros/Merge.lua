local _, ns = ...
local Macros = ns.Macros

---------------------------------------------------------------------------
-- Macros.Merge(base, mine, theirs): three-way merge of macro lines. base is
-- what the builder made last, mine the text now (hand edits), theirs what
-- the builder makes now. A stretch only one side changed takes that side.
-- Where both changed it, the builder's lines win (the newest choice) and
-- lines typed by hand there follow them. Pure: no game calls.
---------------------------------------------------------------------------
local function Lines(s)
  local t = {}
  for l in (s .. "\n"):gmatch("(.-)\n") do t[#t + 1] = l end
  if t[#t] == "" and #t > 1 then t[#t] = nil end
  return t
end

-- Longest common subsequence: { [index in a] = index in b }.
local function Match(a, b)
  local L = {}
  for i = #a + 1, 1, -1 do
    L[i] = {}
    for j = #b + 1, 1, -1 do
      if i > #a or j > #b then L[i][j] = 0
      elseif a[i] == b[j] then L[i][j] = L[i + 1][j + 1] + 1
      else L[i][j] = math.max(L[i + 1][j], L[i][j + 1]) end
    end
  end
  local map, i, j = {}, 1, 1
  while i <= #a and j <= #b do
    if a[i] == b[j] then map[i] = j; i = i + 1; j = j + 1
    elseif L[i + 1][j] >= L[i][j + 1] then i = i + 1
    else j = j + 1 end
  end
  return map
end

local function Same(x, y)
  if #x ~= #y then return false end
  for i = 1, #x do if x[i] ~= y[i] then return false end end
  return true
end

local function Slice(t, from, to)
  local c = {}
  for k = from, to do c[#c + 1] = t[k] end
  return c
end

function Macros.Merge(base, mine, theirs)
  local B, M, T = Lines(base), Lines(mine), Lines(theirs)
  local toM, toT = Match(B, M), Match(B, T)
  local out, pb, pm, pt = {}, 0, 0, 0
  for i = 1, #B + 1 do
    local mi, ti = toM[i], toT[i]
    if i > #B then mi, ti = #M + 1, #T + 1 end
    if mi and ti then -- a line both kept: settle the stretch before it
      local b, m, t = Slice(B, pb + 1, i - 1), Slice(M, pm + 1, mi - 1), Slice(T, pt + 1, ti - 1)
      local take = (Same(m, b) and t) or (Same(t, b) and m) or (Same(m, t) and m)
      if take then
        for _, l in ipairs(take) do out[#out + 1] = l end
      else
        local old, new = {}, {}
        for _, l in ipairs(b) do old[l] = true end
        for _, l in ipairs(t) do new[l] = true; out[#out + 1] = l end
        for _, l in ipairs(m) do if not old[l] and not new[l] then out[#out + 1] = l end end
      end
      if i <= #B then out[#out + 1] = B[i] end
      pb, pm, pt = i, mi, ti
    end
  end
  return table.concat(out, "\n")
end
