local _, ns = ...
local Honor = {}
ns.Honor = Honor

-- Honor chat describes credit, including assists. It never proves a
-- killing blow. Consumers decide which identities and activities count.
-- The victim is string argument 1, even when a locale reorders arguments.
local function Pattern(fmt)
  if type(fmt) ~= "string" then return end
  local function Escape(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
  local parts, offset, argument, victim = { "^" }, 1, 0, false
  while true do
    local first, last, token = fmt:find("(%%[%d%$%.]*[sdf])", offset)
    if not first then break end
    parts[#parts + 1] = Escape((fmt:sub(offset, first - 1):gsub("%%%%", "%%")))
    argument = argument + 1
    local index = tonumber(token:match("^%%(%d+)%$")) or argument
    local capture = index == 1 and token:sub(-1) == "s"
    parts[#parts + 1] = capture and "(.-)" or ".-"
    victim = victim or capture
    offset = last + 1
  end
  parts[#parts + 1] = Escape((fmt:sub(offset):gsub("%%%%", "%%"))) .. "$"
  return victim and table.concat(parts) or nil
end

local FORMATS = { "COMBATLOG_HONORGAIN", "COMBATLOG_HONORGAIN_NO_RANK",
  "COMBATLOG_HONORGAIN_EXHAUSTION1", "COMBATLOG_HONORGAIN_NO_RANK_EXHAUSTION1" }

-- Keyed by the format text itself, so a changed global is rebuilt. At most
-- one entry per distinct client format string.
local patterns = {}
local function Cached(fmt)
  if type(fmt) ~= "string" then return end
  local pattern = patterns[fmt]
  if pattern == nil then pattern = Pattern(fmt) or false; patterns[fmt] = pattern end
  return pattern or nil
end

-- Raw victim name, with spaces and any explicit realm preserved. Honor
-- awards without a named victim must never imply a kill on our target.
function Honor.Name(message)
  message = ns.Util.value(message)
  if type(message) ~= "string" then return end
  for _, key in ipairs(FORMATS) do
    local pattern = Cached(_G[key])
    local name = pattern and message:match(pattern)
    if name and name ~= "" then return name end
  end
  -- Older clients may omit the localized globals but still send this line.
  local name = message:match("^(.-) dies, honorable kill")
  return name and name ~= "" and name or nil
end
