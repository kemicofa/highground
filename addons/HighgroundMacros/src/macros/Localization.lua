local _, ns = ...
local M = ns.Macros
local H = M.Host

local function Foreign() local locale = H.Locale(); return locale ~= "enUS" and locale ~= "enGB" end
function M.LocalSpell(name, game, class)
  if type(name) ~= "string" or not Foreign() then return name end
  local id = M.SpellIDs[name]
  if name == "Nature's Swiftness" and class == "DRUID" then id = 17116 end
  if name == "Skull Bash" and game == "cata" then id = 80964 end
  if name == "Cure Poison" and class == "DRUID" then id = 8946 end
  if type(id) == "table" then id = M.ForGame(id, game) end
  if id then
    local localized = H.value(H.SpellName(id))
    if type(localized) == "string" then return localized end
  end
  return name -- Already localized player input stays untouched.
end

-- Resolve only spell arguments, preserving commands, conditions, script
-- text, player names and item slots exactly. User-authored macros are not
-- rewritten on save or import.
function M.LocalBody(body, game, class)
  if not Foreign() then return body end
  local lines = {}
  for line in (body .. "\n"):gmatch("(.-)\n") do
    local command, rest = line:match("^([/#]%a+)%s+(.+)$")
    if command == "/cast" or command == "/castsequence" or command == "/castrandom"
      or command == "/cancelaura" or command == "#showtooltip" then
      rest = rest:gsub("([^;,]+)", function(part)
        local prefix, name = part:match("^(.*%])%s*(.-)%s*$")
        if not name then prefix, name = part:match("^(%s*reset=%S+%s+)(.-)%s*$") end
        if not name then prefix, name = "", H.Trim(part) end
        local reset, rest = name:match("^(reset=%S+%s+)(.+)$")
        if reset then prefix, name = prefix .. " " .. reset, rest end
        local bang = name:sub(1, 1) == "!"
        if bang then name = name:sub(2) end
        return prefix .. (prefix ~= "" and " " or "") .. (bang and "!" or "") .. M.LocalSpell(name, game, class)
      end)
      line = command .. " " .. rest
    end
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n")
end
