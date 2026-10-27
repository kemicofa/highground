local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local C = Macros.Compiler

---------------------------------------------------------------------------
-- Syntax colours for macro text: Highlight(text) returns the same text with
-- colour codes, line for line, so it can lie exactly under a transparent
-- edit box (macros/BuildPanel.lua). Colours are theme tokens.
---------------------------------------------------------------------------
Macros.HIGHLIGHT = {
  directive = "gold", command = "accent", unknown = "warning", punct = "textMuted", unit = "scopeCharacter",
  condition = "success", value = "gold", action = "text", plain = "textMuted", chat = "warning",
}
local ROLE = Macros.HIGHLIGHT

-- "|" starts an escape in a font string: show it as itself.
local function Escape(s) return (s:gsub("|", "||")) end

local function Paint(role, s)
  if s == "" then return "" end
  return Host.Theme.Hex(ROLE[role]) .. Escape(s) .. "|r"
end

-- Inside "[ ]": "@unit", "name:value" or a bare condition, comma separated.
local function Part(part)
  local lead, body, trail = part:match("^(%s*)(.-)(%s*)$")
  local name, colon, value = body:match("^(%a+)(%s*:%s*)(.*)$")
  local key, unit = body:match("^(target%s*=)(.*)$")
  if body:sub(1, 1) == "@" then return lead .. Paint("unit", body) .. trail end
  if key then return lead .. Paint("condition", key) .. Paint("unit", unit) .. trail end
  if name then return lead .. Paint("condition", name) .. Paint("punct", colon) .. Paint("value", value) .. trail end
  return lead .. Paint("condition", body) .. trail
end

-- Comma-separated pieces, each through fn, commas muted.
local function List(s, fn)
  local out = {}
  for piece in (s .. ","):gmatch("([^,]*),") do out[#out + 1] = fn(piece) end
  return table.concat(out, Paint("punct", ","))
end

-- The action after the conditions: "!" and "reset=" quieter, ranks muted.
local function Action(s)
  local lead, bang, rest = s:match("^(%s*)(!?)(.*)$")
  local reset, after = rest:match("^(reset=%S+)(.*)$")
  local out = lead .. Paint("punct", bang)
  if reset then out, rest = out .. Paint("value", reset), after end
  return out .. List(rest, function(text)
    local name, rank = text:match("^(.-)(%([^%(%)]*%)%s*)$")
    return Paint("action", name or text) .. Paint("punct", rank or "")
  end)
end

-- "[a][b] Spell; [c] Other".
local function Clauses(args)
  local out, i, n = {}, 1, #args
  while i <= n do
    local ch = args:sub(i, i)
    if ch == "[" then
      local close = args:find("]", i + 1, true)
      if not close then out[#out + 1] = Paint("unknown", args:sub(i)); break end
      out[#out + 1] = Paint("punct", "[") .. List(args:sub(i + 1, close - 1), Part) .. Paint("punct", "]")
      i = close + 1
    elseif ch == ";" then
      out[#out + 1] = Paint("punct", ";")
      i = i + 1
    else
      local stop = args:find("[%[;]", i) or n + 1
      out[#out + 1] = Action(args:sub(i, stop - 1))
      i = stop
    end
  end
  return table.concat(out)
end

local function Line(line)
  if line:match("^%s*$") then return line end
  local lead, rest = line:match("^(%s*)(.*)$")
  if rest:sub(1, 1) == "#" then
    local word, args = rest:match("^(#%S*)(.*)$")
    return lead .. Paint("directive", word) .. Action(args)
  end
  if rest:sub(1, 1) ~= "/" then return lead .. Paint("chat", rest) end
  local cmd, space, args = rest:match("^(/%S*)(%s*)(.*)$")
  local name = cmd:sub(2):lower()
  local kind = C.COMMANDS[name] or (C.EMOTES[name] and "emote") or C.InClient(name)
  local out = lead .. Paint(kind and "command" or "unknown", cmd) .. space
  if kind == "cond" or kind == "seq" then return out .. Clauses(args) end
  return out .. Paint("plain", args)
end

-- fits(line): whether a line fits on one row of the box. A line that wraps
-- stays uncoloured: colour codes break where the game wraps it, and the
-- plain copy wraps exactly like the box's own text under it.
function Macros.Highlight(text, fits)
  local out = {}
  for line in ((text or "") .. "\n"):gmatch("(.-)\n") do
    out[#out + 1] = (fits and not fits(line)) and Escape(line) or Line(line)
  end
  return table.concat(out, "\n")
end
