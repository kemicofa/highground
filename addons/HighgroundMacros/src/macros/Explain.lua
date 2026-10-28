local _, ns = ...
local Macros = ns.Macros

---------------------------------------------------------------------------
-- Macro compiler, back half: explain a compiled macro in plain English,
-- line by line. Pure: Explain(result) -> { "line text", ... }. The game
-- checks are in macros/Analyze.lua.
---------------------------------------------------------------------------
local Config = Macros.Config
local UNITS, MODS, MARKERS, SLOTS = Config.UNITS, Config.MODS, Config.MARKERS, Config.SLOTS
Macros.SLOT_NAMES = SLOTS
local RESETS = {} -- reset= word -> phrase
for _, r in ipairs(Config.RESETS) do RESETS[r.key] = r.phrase end

local function UnitLabel(unit)
  if UNITS[unit] then return UNITS[unit].phrase end
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
  local phrase = Config.CONDITION_WORDS[n]
  if phrase then return (no and "not: " or "") .. phrase end
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

-- Game buttons often clicked from macros.
local CLICKS = {
  MerchantNextPageButton = "Turns to the next vendor page",
  MerchantPrevPageButton = "Turns to the previous vendor page",
  StaticPopup1Button1 = "Clicks the first button of the open popup",
}

-- A call's arguments, split on top-level commas.
local function Args(s)
  local out, depth, quote, start = {}, 0, nil, 1
  for i = 1, #s do
    local ch = s:sub(i, i)
    if quote then
      if ch == quote then quote = nil end
    elseif ch == '"' or ch == "'" then quote = ch
    elseif ch == "(" or ch == "{" then depth = depth + 1
    elseif ch == ")" or ch == "}" then depth = depth - 1
    elseif ch == "," and depth == 0 then
      out[#out + 1] = s:sub(start, i - 1):match("^%s*(.-)%s*$"); start = i + 1
    end
  end
  local last = s:sub(start):match("^%s*(.-)%s*$")
  if last ~= "" or #out > 0 then out[#out + 1] = last end
  return out
end

-- A string literal's text, or nil.
local function Str(a) return a and (a:match('^"([^"]*)"$') or a:match("^'([^']*)'$")) end
-- A literal's text: strings unquoted, numbers and true/false as written.
local function Lit(a) return Str(a) or (a and (tonumber(a) or a == "true" or a == "false") and a) or nil end

local CHANNELS = { SAY = "nearby", YELL = "nearby", PARTY = "party", RAID = "raid", GUILD = "guild",
  OFFICER = "officer chat", INSTANCE_CHAT = "the instance", RAID_WARNING = "a raid warning" }

local function Chat(a)
  local msg, chan = Str(a[1]), (Str(a[2]) or "SAY"):upper()
  local what = msg and ('"' .. msg .. '"') or "a message"
  if chan == "WHISPER" then return "Whispers " .. what .. " to " .. (Lit(a[4]) or "someone") end
  return (chan == "YELL" and "Yells " or "Says ") .. what .. " in " .. (CHANNELS[chan] or chan:lower())
end

local function Gossip(a) return "Picks dialogue option " .. (Lit(a[1]) or "?") .. " of the open NPC" end
local function SetCVar(a) return "Sets game setting " .. (Lit(a[1]) or "?") .. " to " .. (Lit(a[2]) or "a value") end
local function Junk() return "Sells grey items to the open vendor" end
local function EquipSet(a)
  local name = Str(a[1]) or (a[1] or ""):match("GetEquipmentSetID%(%s*[\"']([^\"']+)")
  return "Equips set " .. (name or "?")
end
local function UseBagItem(a, code)
  if code:find("9d9d9d", 1, true) then return Junk() end
  return "Uses an item from your bags"
end

-- Known calls -> phrase. Each gets the call's arguments and the whole script.
local CALLS = {
  SelectGossipOption = Gossip,
  ["C_GossipInfo.SelectOptionByIndex"] = Gossip,
  BuyMerchantItem = function(a, code)
    local qty = Lit(a[2]) or "1"
    local item = tonumber(a[1] or "") and ("vendor item " .. a[1])
      or code:match("==%s*[\"']([^\"']+)[\"']") or code:match("[\"']([^\"']+)[\"']%s*==")
    return "Buys " .. qty .. " × " .. (item or "an item") .. " from the open vendor"
  end,
  RepairAllItems = function(a)
    local guild = a[1] and a[1] ~= "" and a[1] ~= "false" and a[1] ~= "nil" and a[1] ~= "0"
    return "Repairs all gear" .. (guild and " (guild funds)" or "")
  end,
  ["C_MerchantFrame.SellAllJunkItems"] = Junk,
  UseContainerItem = UseBagItem,
  ["C_Container.UseContainerItem"] = UseBagItem,
  AcceptQuest = function() return "Accepts the open quest" end,
  CompleteQuest = function() return "Completes the open quest" end,
  GetQuestReward = function(a) return "Takes quest reward " .. (Lit(a[1]) or "?") end,
  ["C_MountJournal.SummonByID"] = function(a)
    if a[1] == "0" then return "Summons a random favorite mount" end
    return "Summons mount " .. (Lit(a[1]) or "?")
  end,
  Dismount = function() return "Dismounts" end,
  UseEquipmentSet = EquipSet,
  ["C_EquipmentSet.UseEquipmentSet"] = EquipSet,
  SetCVar = SetCVar,
  ["C_CVar.SetCVar"] = SetCVar,
  ["UIErrorsFrame:Clear"] = function() return "Clears error messages" end,
  LeaveBattlefield = function() return "Leaves the battleground" end,
  SetRaidTarget = function(a)
    local unit, n = Str(a[1]), tonumber(a[2] or "")
    local who = unit and UnitLabel(unit) or "a unit"
    if n == 0 then return "Clears the marker on " .. who end
    return "Puts the " .. (MARKERS[n or 0] or "raid") .. " marker on " .. who
  end,
  SendChatMessage = Chat,
  ["C_ChatInfo.SendChatMessage"] = Chat,
}

-- "/run ..." -> what its known calls do, in order; unknown scripts stay vague.
local function Walk(s, code, out, seen)
  for name, args in s:gmatch("([%a_][%w_%.:]*)%s*(%b())") do
    local fn = CALLS[name]
    local button = name:match("^([%w_]+):Click$")
    local text = fn and fn(Args(args:sub(2, -2)), code)
      or (button and (CLICKS[button] or ("Clicks the button " .. button)))
    if text and not seen[text] then
      seen[text] = true
      out[#out + 1] = text .. "."
    elseif not text then
      Walk(args:sub(2, -2), code, out, seen) -- calls inside, e.g. C_Timer.After(1, function() ... end)
    end
  end
end

local function Script(code)
  local out = {}
  Walk(code, code, out, {})
  return #out > 0 and table.concat(out, " ") or "Runs a Lua script."
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
    click = CLICKS[arg] or ("Clicks the button " .. arg .. " (an addon's or the game's button)"),
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
    for r in ((c and c.reset or "") .. "/"):gmatch("([^/]*)/") do
      if tonumber(r) then resets[#resets + 1] = r .. " seconds without pressing it"
      elseif RESETS[r:lower()] then resets[#resets + 1] = RESETS[r:lower()] end
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
    if cmd == "run" or cmd == "script" then return Script(entry.args) end
    if cmd == "hg" or cmd == "highground" then return "Runs the Highground command /hg " .. entry.args .. "." end
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
