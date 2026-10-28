local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host

---------------------------------------------------------------------------
-- Macro compiler, front half: parse macro text into lines of commands and
-- clauses, and report problems per line. macros/Explain.lua turns the
-- result into plain English.
--
--   Compile(text) -> {
--     lines = { { n, raw, directive?, cmd?, clauses = { { groups, action } } } },
--     problems = { { line, level = "error" | "warning", text } },
--     length, errors, warnings }
--   group = { unit = "focus"?, conds = { { name, value?, no = bool } } }
---------------------------------------------------------------------------
local C = {}
Macros.Compiler = C

local Config = Macros.Config
local Trim = Host.Trim

-- How a command reads its argument: "cond", "seq" or "plain" (the kinds
-- and lists are in config/Macros.lua), "emote" for C.EMOTES. Listed
-- commands without a kind of their own take their text as is. In game,
-- the client's own registry (C.InClient) also counts, so addon commands
-- and new ones need no list.
C.MORE_COMMANDS = Config.MORE_COMMANDS
C.COMMANDS, C.EMOTES = {}, {}
for name, kind in pairs(Config.COMMANDS) do C.COMMANDS[name] = kind end
for _, e in ipairs(Config.EMOTES) do C.EMOTES[e] = true end
for _, c in ipairs(C.MORE_COMMANDS) do
  if not C.COMMANDS[c] and not C.EMOTES[c] then C.COMMANDS[c] = "plain" end
end

-- Slash commands and emotes the running client knows: Blizzard's and every
-- addon's (SlashCmdList with its SLASH_NAMEn strings, EMOTEn_CMDm tokens).
-- Read once; empty outside the game.
local inClient
function C.InClient(cmd)
  if not inClient then
    inClient = {}
    for key in pairs(type(SlashCmdList) == "table" and SlashCmdList or {}) do
      for n = 1, 20 do
        local s = _G["SLASH_" .. key .. n]
        if type(s) ~= "string" then break end
        inClient[s:lower():gsub("^/", "")] = "plain"
      end
    end
    for i = 1, 800 do
      for j = 1, 9 do
        local s = _G["EMOTE" .. i .. "_CMD" .. j]
        if type(s) ~= "string" then break end
        inClient[s:lower():gsub("^/", "")] = "emote"
      end
    end
  end
  return inClient[cmd]
end
function C.InClientReset() inClient = nil end -- after addons load their commands

C.COMMAND_GAMES, C.NEEDS_ACTION = Config.COMMAND_GAMES, Config.NEEDS_ACTION
C.CONDITIONS, C.CONDITION_GAMES = Config.CONDITIONS, Config.CONDITION_GAMES
C.CONDITION_UNSURE, C.CONDITION_REMOVED = Config.CONDITION_UNSURE, Config.CONDITION_REMOVED
C.UNIT_CONDITIONS = Config.UNIT_CONDITIONS
-- "Cataclysm" for "cata" (config/Client.lua ns.Games).
local function GameName(game) return Host.GameInfo(game).name or game end

-- Whether a command or condition exists in game.
function C.Available(kind, name, game)
  game = game or Host.Game()
  local cap = kind == "command" and Config.COMMAND_CAPS[name]
  if cap then return Host.Can(cap, game) end
  local t = (kind == "command" and C.COMMAND_GAMES or C.CONDITION_GAMES)[name]
  return not t or t[game] == true
end

function C.ValidUnit(unit)
  unit = (unit or ""):lower()
  local base = unit:gsub("target$", "")
  if unit:match("target$") and base ~= "" then unit = base end -- focustarget, targettarget...
  if Config.UNIT_TOKENS[unit] or unit == "" then return true end
  for _, p in ipairs(Config.UNIT_PATTERNS) do if unit:match(p) then return true end end
  return false
end

-- /castsequence reset= words besides seconds, and the hint that lists them.
local RESET_KEYS, words = {}, {}
for _, r in ipairs(Config.RESETS) do RESET_KEYS[r.key] = true; words[#words + 1] = r.key end
local RESET_HINT = "use seconds, " .. table.concat(words, ", ", 1, #words - 1) .. " or " .. words[#words]

-- A group member's name as a unit ("Bob", "Bob-Realm", "Bob-target").
function C.NameUnit(unit)
  return unit:match("^%u[^%s,;%[%]]*$") ~= nil and not C.ValidUnit(unit)
end

-- One "[...]" group's text into { unit, conds }.
local function Group(text, add, game)
  local g = { conds = {} }
  for raw in (text .. ","):gmatch("([^,]*),") do
    local c = Trim(raw)
    if c ~= "" then
      local unit = c:match("^@(.+)$") or c:match("^target%s*=%s*(.+)$")
      if unit then
        unit = Trim(unit)
        if g.unit then add("warning", "two units in one [ ]: only " .. g.unit .. " counts") end
        if C.NameUnit(unit) then
          add("warning", unit .. ": a player's name works only for members of your party or raid")
        elseif not C.ValidUnit(unit) then
          add("warning", "unknown unit \"" .. unit .. "\"")
        end
        g.unit = g.unit or (C.NameUnit(unit) and unit or unit:lower()) -- names keep their spelling
      else
        local name, value = c:match("^([%a]+)%s*:%s*(.+)$")
        name = (name or c):lower()
        local no = false
        local base = name:sub(1, 2) == "no" and name:sub(3) or nil
        if not C.CONDITIONS[name] and base and (C.CONDITIONS[base] or C.CONDITION_REMOVED[base]) then
          name, no = base, true
        end
        if C.CONDITION_REMOVED[name] then
          add("error", "[" .. name .. "] was " .. C.CONDITION_REMOVED[name])
        elseif not C.CONDITIONS[name] then
          add("error", "unknown condition \"" .. c .. "\"")
        else
          if not C.Available("condition", name, game) then
            add("error", "[" .. name .. "] does not exist in " .. GameName(game))
          elseif C.CONDITION_UNSURE[name] and C.CONDITION_UNSURE[name][game] then
            add("warning", "[" .. name .. "] may not work in " .. GameName(game) .. ": test it")
          end
          g.conds[#g.conds + 1] = { name = name, value = value and Trim(value), no = no }
        end
      end
    end
  end
  return g
end

-- "[a][b] Action; [c] Other" into clauses. add(level, text) reports.
function C.Clauses(args, add, game)
  local clauses, i, n = {}, 1, #args
  local clause = { groups = {} }
  local function finish(action)
    clause.action = Trim(action)
    if clause.action:find("[%[%]]") then add("error", "stray [ or ] in \"" .. clause.action .. "\"") end
    clauses[#clauses + 1] = clause
    clause = { groups = {} }
  end
  while i <= n do
    local ch = args:sub(i, i)
    if ch:match("%s") then
      i = i + 1
    elseif ch == "[" then
      local close = args:find("]", i + 1, true)
      local inner = close and args:sub(i + 1, close - 1)
      if not close or inner:find("[", 1, true) then
        add("error", "missing ] after \"[" .. args:sub(i + 1, i + 12) .. "\"")
        return clauses
      end
      clause.groups[#clause.groups + 1] = Group(inner, add, game)
      i = close + 1
    else
      local semi = args:find(";", i, true)
      -- Conditions must come before the action: "[" after text is an error.
      finish(args:sub(i, semi and semi - 1 or n))
      i = semi and semi + 1 or n + 1
      if semi and Trim(args:sub(i)) == "" then add("warning", "nothing after the last ;") end
    end
  end
  if #clause.groups > 0 then finish("") end
  if #clauses == 0 then clauses[1] = { groups = {}, action = "" } end
  return clauses
end

-- Known API calls in a /run or /script line (macros/ScriptApi.lua): warns
-- about each and returns how many warnings it gave. Strings and comments
-- are skipped; Foo(), Foo"x", Foo{...} and _G.Foo() count as calls.
local Api = Macros.ScriptApi
local function In(set, game) return set == true or (set and set[game]) end
function C.ScriptCalls(code, add, game)
  code = code:gsub('"[^"]*"', '""'):gsub("'[^']*'", '""'):gsub("%-%-.*$", "")
  local compares = code:find("[<>]") or code:find("[=~]=")
  local where, warned, seen = GameName(game), 0, {}
  local function warn(msg) add("warning", msg); warned = warned + 1 end
  local function check(name, t)
    if not t or seen[t] then return end
    seen[t] = true
    local use = t.use and ": use " .. t.use or ""
    if In(t.blocked, game) then
      warn(name .. " is blocked in " .. (t.blocked == true and "" or where .. " ") .. "macros" .. use)
    elseif In(t.removed, game) then
      warn(name .. " does not exist in " .. where .. use)
    elseif In(t.deprecated, game) then
      warn(name .. " is deprecated in " .. where .. use)
    elseif In(t.unsure, game) then
      warn(name .. " may not exist in " .. where .. ": test it")
    end
    if In(t.combat, game) then warn(name .. " does nothing in combat") end
    if compares and In(t.secret, game) then
      warn(name .. " can be secret in combat, encounters and PvP in " .. where .. ": comparing it fails there")
    end
  end
  for at, name in code:gmatch("()([%a_][%w_%.]*)%s*[%(\"{]") do
    if not code:sub(at - 1, at - 1):find("[%w_%.:]") then
      name = name:gsub("^_G%.", "")
      local space = name:match("^([%a_][%w_]*)%.")
      check(space or name, space and Api.NAMESPACES[space])
      check(name, Api.CALLS[name])
    end
  end
  return warned
end

function C.Compile(text, game)
  text = text or ""
  game = game or Host.Game()
  local out = { lines = {}, problems = {}, length = #text, errors = 0, warnings = 0 }
  local function report(line, level, msg)
    out.problems[#out.problems + 1] = { line = line, level = level, text = msg }
    if level == "error" then out.errors = out.errors + 1 else out.warnings = out.warnings + 1 end
  end
  if #text > Macros.BODY_MAX then
    report(0, "error", string.format("%d characters: WoW allows %d", #text, Macros.BODY_MAX))
  end
  if Trim(text) == "" then report(0, "error", "the macro is empty") end
  local n, firstCode, markers = 0, nil, 0
  for raw in (text .. "\n"):gmatch("(.-)\r?\n") do
    n = n + 1
    local line = Trim(raw)
    local entry = { n = n, raw = line }
    local function add(level, msg) report(n, level, msg) end
    if line == "" then
      entry.blank = true
    elseif line:sub(1, 1) == "#" then
      local word, arg = line:match("^#(%a+)%s*(.-)$")
      word = (word or ""):lower()
      if word ~= "showtooltip" and word ~= "show" then
        add("warning", "unknown directive: only #showtooltip and #show do anything")
      elseif firstCode then
        add("warning", "#" .. word .. " only works on the first line")
      end
      entry.directive, entry.arg = word, Trim(arg or "")
      firstCode = firstCode or n
    elseif line:sub(1, 1) == "/" then
      firstCode = firstCode or n
      local cmd, args = line:match("^/(%S+)%s*(.-)$")
      cmd = (cmd or ""):lower()
      entry.cmd, entry.args = cmd, args or ""
      local kind = C.COMMANDS[cmd] or (C.EMOTES[cmd] and "emote") or C.InClient(cmd)
      if not kind then
        add("warning", "/" .. cmd .. " is not a WoW command (an addon's command, or a typo)")
        kind = "plain"
      elseif not C.Available("command", cmd, game) then
        add("error", "/" .. cmd .. " does not exist in " .. GameName(game))
      end
      if (cmd == "tm" or cmd == "targetmarker") and game ~= "cata" then
        markers = markers + 1
        if markers == 4 then add("warning", "the game only lets a macro mark 3 units in quick succession") end
      end
      entry.kind = kind
      if kind == "cond" or kind == "seq" then
        entry.clauses = C.Clauses(entry.args, add, game)
        for _, c in ipairs(entry.clauses) do
          if C.NEEDS_ACTION[cmd] and c.action == "" then add("error", "/" .. cmd .. " needs a spell or item after the conditions") end
          if kind == "seq" then
            local reset, rest = c.action:match("^reset=(%S+)%s*(.*)$")
            c.reset = reset
            for r in ((reset or "") .. "/"):gmatch("([^/]*)/") do
              if r ~= "" and not tonumber(r) and not RESET_KEYS[r:lower()] then
                add("error", "reset=" .. r .. ": " .. RESET_HINT)
              end
            end
            c.steps = Host.Split(rest or c.action)
            if #c.steps == 0 then add("error", "/castsequence needs spells separated by commas") end
          end
        end
      elseif cmd == "run" or cmd == "script" then
        if C.ScriptCalls(entry.args, add, game) == 0 then
          add("warning", "scripts can be blocked in combat or by the game version")
        end
      end
    else
      add("warning", "no / at the start: this line is said in chat")
      entry.chat = true
    end
    out.lines[#out.lines + 1] = entry
  end
  return out
end
