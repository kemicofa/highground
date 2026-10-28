local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local C = Macros.Compiler

---------------------------------------------------------------------------
-- Syntax colours for macro text, as colour codes (theme tokens).
--   Highlight(text): the text coloured line for line; the builder's edit
--     box shows it as is (Kit.ColorEditBox), so the box wraps it itself.
--   Highlight(text, fits): for a plain text display that wraps it: lines
--     too wide are broken by fits(line) into rows first, so the game never
--     wraps inside a colour code (macro cards).
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

-- A fits(line) function for Highlight: whether a line fits on one row of
-- widthOf (a region) in a font role, measured unwrapped on a hidden copy.
function Macros.Measurer(parent, role, widthOf)
  local fs = Host.Theme.Text(parent, role)
  fs:SetWordWrap(false)
  fs:SetAlpha(0)
  return function(line)
    if not fs.GetStringWidth then return true end
    fs:SetText((line:gsub("|", "||")))
    return (fs:GetStringWidth() or 0) <= (widthOf:GetWidth() or 0) - 2
  end
end

-- Coloured text into pieces { text, hex | nil } (plain text, pipes as is).
local function Pieces(coded)
  local out, i, n, hex, buf = {}, 1, #coded, nil, {}
  local function flush()
    if #buf > 0 then out[#out + 1] = { table.concat(buf), hex }; buf = {} end
  end
  while i <= n do
    local two = coded:sub(i, i + 1)
    if two == "||" then buf[#buf + 1] = "|"; i = i + 2
    elseif two == "|r" then flush(); hex = nil; i = i + 2
    elseif coded:sub(i, i + 1) == "|c" and coded:sub(i + 2, i + 9):match("^%x+$") and #coded:sub(i + 2, i + 9) == 8 then
      flush(); hex = coded:sub(i + 2, i + 9); i = i + 10
    else buf[#buf + 1] = coded:sub(i, i); i = i + 1 end
  end
  flush()
  return out
end

local function Render(pieces)
  local out = {}
  for _, p in ipairs(pieces) do
    out[#out + 1] = p[2] and ("|c" .. p[2] .. Escape(p[1]) .. "|r") or Escape(p[1])
  end
  return table.concat(out)
end

-- One coloured line as rows that each fit: break before the character that
-- would not fit, keeping each piece's colour across the break.
local function Rows(line, fits)
  local rows, row, plain = {}, {}, ""
  for _, p in ipairs(Pieces(Line(line))) do
    for ch in p[1]:gmatch(".") do
      if plain ~= "" and not fits(plain .. ch) then
        rows[#rows + 1] = Render(row); row, plain = {}, ""
      end
      local last = row[#row]
      if last and last[2] == p[2] then last[1] = last[1] .. ch else row[#row + 1] = { ch, p[2] } end
      plain = plain .. ch
    end
  end
  rows[#rows + 1] = Render(row)
  return table.concat(rows, "\n")
end

function Macros.Highlight(text, fits)
  local out = {}
  for line in ((text or "") .. "\n"):gmatch("(.-)\n") do
    out[#out + 1] = (fits and not fits(line)) and Rows(line, fits) or Line(line)
  end
  return table.concat(out, "\n")
end

-- Coloured text back to plain text (what an edit box holding it means).
function Macros.Uncolor(coded)
  local out = {}
  for _, p in ipairs(Pieces(coded or "")) do out[#out + 1] = p[1] end
  return table.concat(out)
end
