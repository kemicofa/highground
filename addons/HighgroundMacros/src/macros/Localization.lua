local _, ns = ...
local M = ns.Macros
local H = M.Host

local function Foreign() local locale = H.Locale(); return locale ~= "enUS" and locale ~= "enGB" end

-- The client's name for a preset spell (macros/SpellNames.lua), by class,
-- then game; unknown names (already localized input) stay as they are.
function M.LocalSpell(name, game, class)
  if type(name) ~= "string" or not Foreign() then return name end
  local id = class and M.CLASS_SPELL_IDS[class] and M.CLASS_SPELL_IDS[class][name] or M.SpellIDs[name]
  if type(id) == "table" then id = M.ForGame(id, game) end
  if id then
    local localized = H.value(H.SpellName(id))
    if type(localized) == "string" then return localized end
  end
  return name
end

-- One comma-separated name, keeping its spacing and "!".
local function Name(piece, game, class)
  local lead, bang, name, trail = piece:match("^(%s*)(!?)(.-)(%s*)$")
  if name == "" then return piece end
  return lead .. bang .. M.LocalSpell(name, game, class) .. trail
end

-- "[a][b] reset=3 A, B": conditions and reset= kept, the names localized.
local function Clause(clause, game, class)
  local at = 1
  while true do
    local _, stop = clause:find("^%s*%b[]", at)
    if not stop then break end
    at = stop + 1
  end
  local action = clause:sub(at)
  local reset, list = action:match("^(%s*reset=%S+%s+)(.*)$")
  if not reset then reset, list = "", action end
  list = (list .. ","):gsub("([^,]*),", function(piece) return Name(piece, game, class) .. "," end)
  return clause:sub(1, at - 1) .. reset .. list:sub(1, -2)
end

-- Resolve only spell arguments, preserving commands, conditions, script
-- text, player names and item slots exactly. User-authored macros are not
-- rewritten on save or import.
local SPELL_COMMANDS = { ["/cast"] = true, ["/castsequence"] = true, ["/castrandom"] = true,
  ["/cancelaura"] = true, ["#showtooltip"] = true }
function M.LocalBody(body, game, class)
  if not Foreign() then return body end
  local lines = {}
  for line in (body .. "\n"):gmatch("(.-)\n") do
    local command, space, rest = line:match("^([/#]%a+)(%s+)(.+)$")
    if command and SPELL_COMMANDS[command] then
      local clauses = {}
      for clause in (rest .. ";"):gmatch("([^;]*);") do clauses[#clauses + 1] = Clause(clause, game, class) end
      line = command .. space .. table.concat(clauses, ";")
    end
    lines[#lines + 1] = line
  end
  return table.concat(lines, "\n")
end
