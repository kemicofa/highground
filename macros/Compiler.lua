local _, ns = ...
local Macros = ns.Macros

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

-- How a command reads its argument: "cond" takes [conditions] and an
-- action, "seq" is /castsequence, "plain" takes text as is.
C.COMMANDS = {
  cast = "cond", use = "cond", castrandom = "cond", userandom = "cond", castsequence = "seq",
  stopcasting = "cond", stopattack = "cond", startattack = "cond", stopmacro = "cond",
  cancelaura = "cond", cancelform = "cond", dismount = "cond", leavevehicle = "cond",
  focus = "cond", clearfocus = "cond", target = "cond", targetexact = "plain", assist = "cond",
  cleartarget = "cond", targetenemy = "cond", targetenemyplayer = "cond", targetfriend = "cond",
  targetfriendplayer = "cond", targetlasttarget = "cond", targetlastenemy = "cond", targetparty = "cond",
  petattack = "cond", petfollow = "cond", petpassive = "cond", petstay = "cond", petdefensive = "cond",
  petassist = "cond", petaggressive = "cond", petmoveto = "cond",
  click = "cond", tm = "cond", targetmarker = "cond", wm = "cond", worldmarker = "cond", cwm = "cond",
  clearworldmarker = "cond", ping = "cond", equip = "cond", equipslot = "cond", equipset = "cond",
  run = "plain", script = "plain", console = "plain",
  say = "plain", s = "plain", yell = "plain", y = "plain", party = "plain", p = "plain", raid = "plain",
  ra = "plain", rw = "plain", instance = "plain", i = "plain", bg = "plain", emote = "plain", e = "plain",
  me = "plain", whisper = "plain", w = "plain", tell = "plain", t = "plain", guild = "plain", g = "plain",
  wb = "plain", warboard = "plain", ko = "plain", killorder = "plain",
  -- From Blizzard's UI source (SlashCommands.lua per client, 12.1 / 4.4.2 / Forever 1.60).
  spell = "cond", stopspelltarget = "cond", cancelqueuedspell = "cond", cqs = "cond", tar = "cond",
  a = "cond", eq = "cond", changeactionbar = "cond", swapactionbar = "cond", targetraid = "cond",
  targetlastfriend = "cond", maintank = "cond", mt = "cond", mtoff = "cond", mainassist = "cond",
  ma = "cond", maoff = "cond", petdismiss = "cond", petautocaston = "cond", petautocastoff = "cond",
  petautocasttoggle = "cond", usetoy = "cond", pingspell = "cond", pingitem = "cond", abandon = "plain",
  duel = "cond", yield = "cond", forfeit = "cond", concede = "cond", makgora = "plain",
  summonpet = "cond", sp = "cond", randompet = "cond", randomfavoritepet = "cond", rfp = "cond",
  dismisspet = "cond", countdown = "plain", cd = "plain", readycheck = "plain", rc = "plain",
  logout = "plain", quit = "plain",
}
-- Commands only some games have (others have them everywhere).
C.COMMAND_GAMES = {
  ping = { retail = true, forever = true }, pingspell = { retail = true, forever = true },
  pingitem = { retail = true, forever = true }, usetoy = { retail = true, forever = true },
  petassist = { retail = true, forever = true }, abandon = { retail = true, forever = true },
  rc = { retail = true, forever = true }, makgora = { cata = true, forever = true },
}
C.GAME_NAMES = { retail = "Retail", cata = "Cataclysm", forever = "WoW Forever" }
-- Commands that do nothing useful without an action after the conditions.
C.NEEDS_ACTION = { cast = true, use = true, castrandom = true, userandom = true, cancelaura = true,
  click = true, targetexact = true, equip = true, equipslot = true }

C.CONDITIONS = {
  harm = true, help = true, exists = true, dead = true, combat = true, mod = true, modifier = true,
  btn = true, button = true, channeling = true, equipped = true, worn = true, flyable = true,
  advflyable = true, flying = true, form = true, stance = true, group = true, indoors = true,
  outdoors = true, mounted = true, swimming = true, stealth = true, pet = true, party = true,
  raid = true, spec = true, talent = true, known = true, actionbar = true, bar = true, bonusbar = true,
  extrabar = true, overridebar = true, possessbar = true, vehicleui = true, unithasvehicleui = true,
  canexitvehicle = true, resting = true, petbattle = true, cursor = true, shapeshift = true,
  pvpcombat = true, house = true,
}
-- Conditions only some games have; [known] is confirmed on Retail only.
C.CONDITION_GAMES = { advflyable = { retail = true }, petbattle = { retail = true },
  pvpcombat = { retail = true }, house = { retail = true } }
C.CONDITION_UNSURE = { known = { cata = true, forever = true } }
C.CONDITION_REMOVED = { talent = "removed in Dragonflight", pvptalent = "no longer exists" }

-- Whether a command or condition exists in game.
function C.Available(kind, name, game)
  local t = (kind == "command" and C.COMMAND_GAMES or C.CONDITION_GAMES)[name]
  return not t or t[game or ns.GAME] == true
end
-- Conditions about the unit the spell lands on (the rest are about you).
C.UNIT_CONDITIONS = { harm = true, help = true, exists = true, dead = true, party = true, raid = true }

local UNIT_PATTERNS = { "^party[1-4]$", "^partypet[1-4]$", "^raid%d+$", "^raidpet%d+$", "^arena[1-5]$",
  "^arenapet[1-5]$", "^boss[1-8]$", "^nameplate%d+$" }
local UNITS = { target = true, player = true, focus = true, mouseover = true, pet = true, vehicle = true,
  cursor = true, none = true, softenemy = true, softfriend = true, softinteract = true, anyenemy = true,
  anyfriend = true, anyinteract = true }

function C.ValidUnit(unit)
  unit = (unit or ""):lower()
  local base = unit:gsub("target$", "")
  if unit:match("target$") and base ~= "" then unit = base end -- focustarget, targettarget...
  if UNITS[unit] or unit == "" then return true end
  for _, p in ipairs(UNIT_PATTERNS) do if unit:match(p) then return true end end
  return false
end

local function Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

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
        if not C.ValidUnit(unit) then add("warning", "unknown unit \"" .. unit .. "\"") end
        g.unit = g.unit or unit:lower()
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
            add("error", "[" .. name .. "] does not exist in " .. (C.GAME_NAMES[game] or game))
          elseif C.CONDITION_UNSURE[name] and C.CONDITION_UNSURE[name][game] then
            add("warning", "[" .. name .. "] may not work in " .. (C.GAME_NAMES[game] or game) .. ": test it")
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

function C.Compile(text, game)
  text = text or ""
  game = game or ns.GAME
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
      local kind = C.COMMANDS[cmd]
      if not kind then
        add("warning", "/" .. cmd .. " is not a WoW command (an addon's command, or a typo)")
        kind = "plain"
      elseif not C.Available("command", cmd, game) then
        add("error", "/" .. cmd .. " does not exist in " .. (C.GAME_NAMES[game] or game))
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
              local l = r:lower()
              if r ~= "" and not tonumber(r) and l ~= "target" and l ~= "combat" and l ~= "shift"
                and l ~= "ctrl" and l ~= "alt" then
                add("error", "reset=" .. r .. ": use seconds, target, combat, shift, ctrl or alt")
              end
            end
            c.steps = {}
            for step in ((rest or c.action) .. ","):gmatch("([^,]*),") do
              if Trim(step) ~= "" then c.steps[#c.steps + 1] = Trim(step) end
            end
            if #c.steps == 0 then add("error", "/castsequence needs spells separated by commas") end
          end
        end
      elseif (cmd == "run" or cmd == "script") then
        add("warning", "scripts can be blocked in combat or by the game version")
      end
    else
      add("warning", "no / at the start: this line is said in chat")
      entry.chat = true
    end
    out.lines[#out.lines + 1] = entry
  end
  return out
end
