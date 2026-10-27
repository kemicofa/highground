local _, ns = ...
local Macros = ns.Macros

---------------------------------------------------------------------------
-- Macro compiler, back half: explain a compiled macro in plain English,
-- line by line. Pure: Explain(result) -> { "line text", ... }. The game
-- checks are in macros/Analyze.lua.
---------------------------------------------------------------------------
local UNIT_NAMES = { target = "your target", player = "yourself", focus = "your focus", pet = "your pet",
  mouseover = "the unit under your mouse", cursor = "the ground at your cursor", none = "nothing (you pick)",
  targettarget = "your target's target", focustarget = "your focus's target" }
local MODS = { shift = "Shift", ctrl = "Ctrl", alt = "Alt" }
local MARKERS = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
local SLOTS = { ["1"] = "your head item", ["2"] = "your neck item", ["3"] = "your shoulder item",
  ["5"] = "your chest item", ["6"] = "your belt", ["7"] = "your legs item", ["8"] = "your boots",
  ["9"] = "your wrist item", ["10"] = "your gloves", ["11"] = "your first ring", ["12"] = "your second ring",
  ["13"] = "your top trinket", ["14"] = "your bottom trinket", ["15"] = "your cloak",
  ["16"] = "your main-hand item", ["17"] = "your off-hand item" }
Macros.SLOT_NAMES = SLOTS

local function UnitLabel(unit)
  if UNIT_NAMES[unit] then return UNIT_NAMES[unit] end
  -- Someone's target: "party1target", "Bob-target".
  local base = unit:match("^(.-)%-?target$")
  if base and base ~= "" then return UnitLabel(base) .. "'s target" end
  local kind, num = unit:match("^(%a+)(%d+)$")
  if kind == "arena" then return "arena enemy " .. num end
  if kind == "party" then return "party member " .. num end
  if kind == "raid" then return "raid member " .. num end
  if kind == "arenapet" then return "arena enemy " .. num .. "'s pet" end
  if kind == "boss" then return "boss " .. num end
  return unit
end

local function Values(v) return (v or ""):gsub("/", " or ") end

-- One condition about the unit ("it is a living enemy") or about you.
local function Cond(c)
  local n, v, no = c.name, c.value, c.no
  if n == "harm" then return no and "it is not an enemy" or "it is an enemy" end
  if n == "help" then return no and "it is not a friend" or "it is a friend" end
  if n == "dead" then return no and "it is alive" or "it is dead" end
  if n == "exists" then return no and "it doesn't exist" or "it exists" end
  if n == "combat" then return no and "you are out of combat" or "you are in combat" end
  if n == "mod" or n == "modifier" then
    local keys = v and Values(v):gsub("%a+", function(k) return MODS[k:lower()] or k end)
    return no and "no modifier key is held" or ((keys or "a modifier key") .. " is held")
  end
  if n == "stance" or n == "form" then
    return (no and "you are not in " or "you are in ") .. (v and ("stance " .. Values(v)) or "any stance or form")
  end
  if n == "stealth" then return no and "you are not stealthed" or "you are stealthed" end
  if n == "known" then return (no and "you don't know " or "you know ") .. (v or "it") end
  if n == "pet" then return no and "you have no pet" or ((v and ("your pet is " .. Values(v))) or "you have a pet") end
  if n == "equipped" or n == "worn" then return (no and "you don't have " or "you have ") .. (v or "it") .. " equipped" end
  if n == "btn" or n == "button" then return "you click with button " .. Values(v) end
  if n == "channeling" then return no and "you are not channeling" or "you are channeling" .. (v and (" " .. v) or "") end
  local words = { group = "you are in a group", party = "it is in your party", raid = "it is in your raid",
    indoors = "you are indoors", outdoors = "you are outdoors", mounted = "you are mounted",
    swimming = "you are swimming", flying = "you are flying", resting = "you are resting" }
  if words[n] then return (no and "not: " or "") .. words[n] end
  return (no and "not " or "") .. n .. (v and (" " .. v) or "")
end

local function Conds(g)
  local harm, help, alive
  local parts = {}
  for _, c in ipairs(g.conds) do
    if c.name == "harm" and not c.no then harm = true
    elseif c.name == "help" and not c.no then help = true
    elseif c.name == "dead" and c.no then alive = true
    else parts[#parts + 1] = Cond(c) end
  end
  if harm or help then
    table.insert(parts, 1, "it is a " .. (alive and "living " or "") .. (harm and "enemy" or "friend"))
  elseif alive then
    table.insert(parts, 1, "it is alive")
  end
  return table.concat(parts, " and ")
end

local VERBS = { cast = "Casts", use = "Uses", castrandom = "Casts one of", userandom = "Uses one of" }

local function Action(cmd, action)
  local force = action:sub(1, 1) == "!"
  if force then action = action:sub(2) end
  if cmd == "use" and SLOTS[action] then action = SLOTS[action] end
  return action, force
end

-- "/cast [@focus,harm,nodead][] Kick" -> one sentence.
local function CastSentence(entry)
  local out = {}
  for ci, c in ipairs(entry.clauses) do
    local action, force = Action(entry.cmd, c.action)
    local anyUnit = false
    for _, g in ipairs(c.groups) do if g.unit then anyUnit = true end end
    local pieces = {}
    for gi, g in ipairs(c.groups) do
      local unit = g.unit or (anyUnit and "target") or nil
      local cond = Conds(g)
      local piece = (unit and ("on " .. UnitLabel(unit)) or "")
      if cond ~= "" then piece = piece .. (piece ~= "" and " " or "") .. "if " .. cond end
      if piece == "" then piece = gi > 1 and "in any case" or "" end
      pieces[#pieces + 1] = piece
    end
    local head = (ci == 1 and "" or "Otherwise, ") .. (VERBS[entry.cmd] or "Casts") .. " " .. action
    local text = head .. (pieces[1] and pieces[1] ~= "" and (" " .. pieces[1]) or "")
    for i = 2, #pieces do text = text .. "; otherwise " .. pieces[i] end
    if force then text = text .. " (the ! keeps it on: pressing again never cancels it)" end
    out[#out + 1] = text .. "."
  end
  return table.concat(out, " ")
end

local function Simple(entry)
  local c = entry.clauses and entry.clauses[1]
  local g = c and c.groups[1]
  local unit = g and g.unit and UnitLabel(g.unit)
  local cond = g and Conds(g) or ""
  local when = cond ~= "" and (" if " .. cond) or ""
  local arg = c and c.action or entry.args
  local cmd = entry.cmd
  local t = {
    stopcasting = "Stops your current cast, so the next spell goes off at once",
    startattack = "Starts auto attacking " .. (unit or "your target"),
    stopattack = "Stops auto attacking",
    cancelaura = "Removes " .. arg .. " from you, if you have it",
    cancelform = "Leaves your current form",
    focus = "Sets your focus to " .. (unit or (arg ~= "" and arg) or "your target"),
    clearfocus = "Clears your focus",
    target = "Targets " .. (unit or (arg ~= "" and arg) or "your target"),
    targetexact = "Targets exactly " .. arg,
    cleartarget = "Clears your target",
    targetenemy = "Targets the nearest enemy",
    targetenemyplayer = "Targets the nearest enemy player",
    targetlasttarget = "Targets your previous target",
    petattack = "Sends your pet to attack " .. (unit or "your target"),
    petfollow = "Calls your pet back to follow you",
    petpassive = "Sets your pet to passive",
    petstay = "Tells your pet to stay",
    click = "Clicks the button " .. arg .. " (an addon's or the game's button)",
    tm = "Puts the " .. (MARKERS[tonumber(arg) or 0] or "raid") .. " marker on " .. (unit or "your target"),
    ping = "Pings " .. (unit or "your target") .. (arg ~= "" and (" (" .. arg .. ")") or ""),
    stopmacro = "Stops the macro here",
    dismount = "Dismounts",
    equip = "Equips " .. arg,
    equipslot = "Equips into a slot: " .. arg,
  }
  t.targetmarker = t.tm
  if t[cmd] then return t[cmd] .. when .. "." end
  if cmd == "castsequence" then
    local steps = c and c.steps or {}
    local resets = {}
    local WORDS = { target = "a new target", combat = "leaving combat", shift = "pressing it with Shift",
      ctrl = "pressing it with Ctrl", alt = "pressing it with Alt" }
    for r in ((c and c.reset or "") .. "/"):gmatch("([^/]*)/") do
      if tonumber(r) then resets[#resets + 1] = r .. " seconds without pressing it"
      elseif WORDS[r:lower()] then resets[#resets + 1] = WORDS[r:lower()] end
    end
    return "Casts " .. table.concat(steps, ", then ") .. " on successive presses"
      .. (#resets > 0 and (", starting over after " .. table.concat(resets, " or ")) or ", then starts over")
      .. when .. "."
  end
  if entry.kind == "emote" then
    return "Does the /" .. cmd .. " emote" .. (entry.args ~= "" and (" (" .. entry.args .. ")") or "") .. "."
  end
  if cmd == "random" or cmd == "roll" or cmd == "rnd" then
    return "Rolls a random number" .. (entry.args ~= "" and (" (" .. entry.args .. ")") or " from 1 to 100") .. "."
  end
  if entry.kind == "plain" then
    if cmd == "run" or cmd == "script" then return "Runs a Lua script." end
    if cmd == "wb" or cmd == "warboard" then return "Runs the Highground command /wb " .. entry.args .. "." end
    return "Sends /" .. cmd .. " " .. entry.args .. "."
  end
  return "Runs /" .. cmd .. "."
end

function Macros.Explain(result)
  local out, cancelled = {}, {}
  for _, e in ipairs(result.lines) do
    if e.cmd == "cancelaura" and e.clauses then
      for _, c in ipairs(e.clauses) do cancelled[c.action:lower()] = c.action end
    end
    if e.directive then
      out[#out + 1] = "Shows the icon and tooltip of " .. (e.arg ~= "" and e.arg or "the spell it will cast") .. "."
    elseif e.chat then
      out[#out + 1] = "Says \"" .. e.raw .. "\" in chat."
    elseif e.cmd and VERBS[e.cmd] and e.clauses then
      local text = CastSentence(e)
      for _, c in ipairs(e.clauses) do
        local spell = cancelled[c.action:gsub("^!", ""):lower()]
        if spell then text = text .. " Pressing it while " .. spell .. " is on you cancels it instead." end
      end
      out[#out + 1] = text
    elseif e.cmd then
      out[#out + 1] = Simple(e)
    end
  end
  return out
end
