-- Helpers for command tests: run a /hg command in a simulator and read
-- what it printed. Chat reads "|" as an escape, so a lone "|r", "|n" or
-- "|h" in printed syntax silently drops or garbles letters ("s|i|raid"
-- shows as "s|iaid"). run() fails on any escape except colours and "||".
local M = {}

local function Escapes(text)
  local i, open = 1, 0
  while true do
    local at = text:find("|", i, true)
    if not at then return nil end
    local code = text:sub(at + 1, at + 1)
    if code == "|" then
      i = at + 2
    elseif code == "c" and text:sub(at + 2, at + 9):match("^%x%x%x%x%x%x%x%x$") then
      open, i = open + 1, at + 10
    elseif code == "r" and open > 0 then
      open, i = open - 1, at + 2
    elseif code:match("%a") then
      return text:sub(math.max(1, at - 12), at + 12)
    else
      i = at + 1
    end
  end
end
M.Escapes = Escapes

-- Plain text of chat lines: colours dropped and "||" read as "|".
function M.Plain(text)
  return (text:gsub("||", "\0"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%z", "|"))
end

-- Runs /hg <text>; returns the new chat lines as one plain string.
function M.run(sim, text)
  local before = #sim.messages
  sim:command(text)
  local lines = {}
  for i = before + 1, #sim.messages do
    local bad = Escapes(sim.messages[i])
    assert(not bad, "/hg " .. text .. " prints a stray escape near: " .. tostring(bad))
    lines[#lines + 1] = M.Plain(sim.messages[i])
  end
  return table.concat(lines, "\n")
end

function M.has(out, text) return out:find(text, 1, true) ~= nil end

return M
