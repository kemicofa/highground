local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
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
for _, r in ipairs(Config.RESETS) do RESETS[r.key] = r end

local function UnitLabel(unit)
  if UNITS[unit] then return UNITS[unit].phrase end
  -- Someone's target: "party1target", "Bob-target".
  local base = unit:match("^(.-)%-?target$")
  if base and base ~= "" then return Locale:Format("macros.explain.value1_s_target.443aff", { value1 = UnitLabel(base) }) end
  local kind, num = unit:match("^(%a+)(%d+)$")
  if kind == "arena" then return Locale:Format("macros.explain.arena_enemy_num.a9912f", { num = num }) end
  if kind == "party" then return Locale:Format("macros.explain.party_member_num.f31e2b", { num = num }) end
  if kind == "raid" then return Locale:Format("macros.explain.raid_member_num.69b475", { num = num }) end
  if kind == "arenapet" then return Locale:Format("macros.explain.arena_enemy_num_s_pet.e6381d", { num = num }) end
  if kind == "boss" then return Locale:Format("macros.explain.boss_num.0672f9", { num = num }) end
  return unit
end

local function Values(v) return (v or ""):gsub("/", Locale:Get("macros.explain.or.439ac6")) end

-- One condition about the unit ("it is a living enemy") or about you.
local function Cond(c)
  local n, v, no = c.name, c.value, c.no
  if n == "harm" then return no and Locale:Get("macros.explain.it_is_not_an_enemy.f3b0e1") or Locale:Get("macros.explain.it_is_an_enemy.77d09f") end
  if n == "help" then return no and Locale:Get("macros.explain.it_is_not_a_friend.f73b25") or Locale:Get("macros.explain.it_is_a_friend.cc55aa") end
  if n == "dead" then return no and Locale:Get("macros.explain.it_is_alive.5e90d5") or Locale:Get("macros.explain.it_is_dead.dc55b2") end
  if n == "exists" then return no and Locale:Get("macros.explain.it_doesn_t_exist.5feef8") or Locale:Get("macros.explain.it_exists.19f181") end
  if n == "combat" then return no and Locale:Get("macros.explain.you_are_out_of_combat.a9c8a1") or Locale:Get("macros.explain.you_are_in_combat.95e4bb") end
  if n == "mod" or n == "modifier" then
    local keys = v and Values(v):gsub("%a+", function(k) return MODS[k:lower()] or k end)
    return no and Locale:Get("macros.explain.no_modifier_key_is_held.24e68d") or (Locale:Format("macros.explain.value1_is_held.d24582", { value1 = (keys or Locale:Get("macros.explain.a_modifier_key.4c8b84")) }))
  end
  if n == "stance" or n == "form" then
    return Locale:Format(no and "shared.copy.you_are_not_in_stance.17ee46" or "shared.copy.you_are_in_stance.248cf8", { stance = v and Locale:Format("shared.copy.stance_value.b717b5", { value = Values(v) }) or Locale:Get("macros.explain.any_stance_or_form.245a23") })
  end
  if n == "stealth" then return no and Locale:Get("macros.explain.you_are_not_stealthed.5fcfcb") or Locale:Get("macros.explain.you_are_stealthed.51612a") end
  if n == "known" then return Locale:Format(no and "shared.copy.you_don_t_know_spell.24569b" or "shared.copy.you_know_spell.6de2c8", { spell = v or Locale:Get("shared.copy.it.6c5522") }) end
  if n == "pet" then return no and Locale:Get("macros.explain.you_have_no_pet.b37987") or ((v and (Locale:Format("macros.explain.your_pet_is_value2.cf8882", { value2 = Values(v) }))) or Locale:Get("macros.explain.you_have_a_pet.243d9e")) end
  if n == "equipped" or n == "worn" then return Locale:Format(no and "shared.copy.you_don_t_have_item_equipped.473d99" or "shared.copy.you_have_item_equipped.52470a", { item = v or Locale:Get("shared.copy.it.6c5522") }) end
  if n == "btn" or n == "button" then return Locale:Format("macros.explain.you_click_with_button_value2.241b3c", { value2 = Values(v) }) end
  if n == "channeling" then return no and Locale:Get("macros.explain.you_are_not_channeling.d16ff7") or Locale:Format("macros.explain.you_are_channeling_value2.4fabea", { value2 = (v and (" " .. v) or "") }) end
  local phrase = Config.CONDITION_WORDS[n]
  if phrase then return (no and Locale:Get("macros.explain.not.237892") or "") .. phrase end
  return (no and Locale:Get("macros.explain.not.26bc9f") or "") .. n .. (v and (" " .. v) or "")
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
    table.insert(parts, 1, (harm and (alive and Locale:Get("shared.copy.it_is_a_living_enemy.4a923e") or Locale:Get("macros.explain.it_is_an_enemy.77d09f")) or (alive and Locale:Get("shared.copy.it_is_a_living_friend.ca05d3") or Locale:Get("macros.explain.it_is_a_friend.cc55aa"))))
  elseif alive then
    table.insert(parts, 1, Locale:Get("macros.explain.it_is_alive.5e90d5"))
  end
  return table.concat(parts, Locale:Get("macros.explain.and.4f4133"))
end

local VERBS = Localization.Define(Localization.Define({ cast = Locale:Get("macros.explain.casts.e7500c"), use = Locale:Get("macros.explain.uses.62be47"), castrandom = Locale:Get("macros.explain.casts_one_of.0323b9"), userandom = Locale:Get("macros.explain.uses_one_of.bd1e21") }, { cast = "macros.explain.casts.e7500c", use = "macros.explain.uses.62be47" }), { castrandom = "macros.explain.casts_one_of.0323b9", userandom = "macros.explain.uses_one_of.bd1e21" })

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
      local piece = (unit and (Locale:Format("macros.explain.on_value2.16deee", { value2 = UnitLabel(unit) })) or "")
      if cond ~= "" then piece = Locale:Format("macros.explain.piece_value2_if_cond.685f53", { piece = piece, value2 = (piece ~= "" and " " or ""), cond = cond }) end
      if piece == "" then piece = gi > 1 and Locale:Get("macros.explain.in_any_case.f54e39") or "" end
      pieces[#pieces + 1] = piece
    end
    local head = (ci == 1 and "" or Locale:Get("macros.explain.otherwise.02b7cb")) .. (VERBS[entry.cmd] or Locale:Get("macros.explain.casts.e7500c")) .. " " .. action
    local text = head .. (pieces[1] and pieces[1] ~= "" and (" " .. pieces[1]) or "")
    for i = 2, #pieces do text = Locale:Format("macros.explain.text_otherwise_value3.9f2be3", { text = text, value3 = pieces[i] }) end
    if force then text = Locale:Format("macros.explain.text_the_keeps_it_on_pressing_again.021347", { text = text }) end
    out[#out + 1] = text .. "."
  end
  return table.concat(out, " ")
end

-- Game buttons often clicked from macros.
local CLICKS = Localization.Define({
  MerchantNextPageButton = Locale:Get("macros.explain.turns_to_the_next_vendor_page.19b067"),
  MerchantPrevPageButton = Locale:Get("macros.explain.turns_to_the_previous_vendor_page.59cf6c"),
  StaticPopup1Button1 = Locale:Get("macros.explain.clicks_the_first_button_of_the_open.caf7f9"),
}, { MerchantNextPageButton = "macros.explain.turns_to_the_next_vendor_page.19b067", MerchantPrevPageButton = "macros.explain.turns_to_the_previous_vendor_page.59cf6c", StaticPopup1Button1 = "macros.explain.clicks_the_first_button_of_the_open.caf7f9" })

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

local CHANNELS = Localization.Define({ SAY = "nearby", YELL = "nearby", PARTY = "party", RAID = "raid", GUILD = "guild",
  OFFICER = Locale:Get("macros.explain.officer_chat.e5d312"), INSTANCE_CHAT = Locale:Get("macros.explain.the_instance.93a69f"), RAID_WARNING = Locale:Get("macros.explain.a_raid_warning.dd85b2") }, { OFFICER = "macros.explain.officer_chat.e5d312", INSTANCE_CHAT = "macros.explain.the_instance.93a69f", RAID_WARNING = "macros.explain.a_raid_warning.dd85b2" })

local function Chat(a)
  local msg, chan = Str(a[1]), (Str(a[2]) or "SAY"):upper()
  local what = msg and ('"' .. msg .. '"') or Locale:Get("macros.explain.a_message.00f2d6")
  if chan == "WHISPER" then return Locale:Format("macros.explain.whispers_what_to_value4.4e59e2", { what = what, value4 = (Lit(a[4]) or "someone") }) end
  return Locale:Format("macros.explain.value1_what_in_value4.37fc38", { value1 = (chan == "YELL" and Locale:Get("macros.explain.yells.4799ac") or Locale:Get("macros.explain.says.26b8aa")), what = what, value4 = (CHANNELS[chan] or chan:lower()) })
end

local function Gossip(a) return Locale:Format("macros.explain.picks_dialogue_option_value2_of_the_open.d5bc4e", { value2 = (Lit(a[1]) or "?") }) end
local function SetCVar(a) return Locale:Format("macros.explain.sets_game_setting_value2_to_value4.9b3e59", { value2 = (Lit(a[1]) or "?"), value4 = (Lit(a[2]) or Locale:Get("macros.explain.a_value.9e4647")) }) end
local function Junk() return Locale:Get("macros.explain.sells_grey_items_to_the_open_vendor.4d38d1") end
local function EquipSet(a)
  local name = Str(a[1]) or (a[1] or ""):match("GetEquipmentSetID%(%s*[\"']([^\"']+)")
  return Locale:Format("macros.explain.equips_set_value2.545f39", { value2 = (name or "?") })
end
local function UseBagItem(a, code)
  if code:find("9d9d9d", 1, true) then return Junk() end
  return Locale:Get("macros.explain.uses_an_item_from_your_bags.a9a0d5")
end

-- Known calls -> phrase. Each gets the call's arguments and the whole script.
local CALLS = {
  SelectGossipOption = Gossip,
  ["C_GossipInfo.SelectOptionByIndex"] = Gossip,
  BuyMerchantItem = function(a, code)
    local qty = Lit(a[2]) or "1"
    local item = tonumber(a[1] or "") and (Locale:Format("macros.explain.vendor_item_value2.c01440", { value2 = a[1] }))
      or code:match("==%s*[\"']([^\"']+)[\"']") or code:match("[\"']([^\"']+)[\"']%s*==")
    return Locale:Format("macros.explain.buys_qty_value4_from_the_open_vendor.bbbd17", { qty = qty, value4 = (item or Locale:Get("macros.explain.an_item.b5d4f5")) })
  end,
  RepairAllItems = function(a)
    local guild = a[1] and a[1] ~= "" and a[1] ~= "false" and a[1] ~= "nil" and a[1] ~= "0"
    return Locale:Format("macros.explain.repairs_all_gear_value2.3deacd", { value2 = (guild and Locale:Get("macros.explain.guild_funds.fe1449") or "") })
  end,
  ["C_MerchantFrame.SellAllJunkItems"] = Junk,
  UseContainerItem = UseBagItem,
  ["C_Container.UseContainerItem"] = UseBagItem,
  AcceptQuest = function() return Locale:Get("macros.explain.accepts_the_open_quest.097cc0") end,
  CompleteQuest = function() return Locale:Get("macros.explain.completes_the_open_quest.5caea9") end,
  GetQuestReward = function(a) return Locale:Format("macros.explain.takes_quest_reward_value2.547d85", { value2 = (Lit(a[1]) or "?") }) end,
  ["C_MountJournal.SummonByID"] = function(a)
    if a[1] == "0" then return Locale:Get("macros.explain.summons_a_random_favorite_mount.19f77b") end
    return Locale:Format("macros.explain.summons_mount_value2.4ad6f9", { value2 = (Lit(a[1]) or "?") })
  end,
  Dismount = function() return Locale:Get("macros.explain.dismounts.1f809f") end,
  UseEquipmentSet = EquipSet,
  ["C_EquipmentSet.UseEquipmentSet"] = EquipSet,
  SetCVar = SetCVar,
  ["C_CVar.SetCVar"] = SetCVar,
  ["UIErrorsFrame:Clear"] = function() return Locale:Get("macros.explain.clears_error_messages.c152a9") end,
  LeaveBattlefield = function() return Locale:Get("macros.explain.leaves_the_battleground.c98c62") end,
  SetRaidTarget = function(a)
    local unit, n = Str(a[1]), tonumber(a[2] or "")
    local who = unit and UnitLabel(unit) or Locale:Get("macros.explain.a_unit.4f89f2")
    if n == 0 then return Locale:Format("macros.explain.clears_the_marker_on_who.a9e2b5", { who = who }) end
    return Locale:Format("macros.explain.puts_the_value2_marker_on_who.7fa05f", { value2 = (MARKERS[n or 0] or "raid"), who = who })
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
      or (button and (CLICKS[button] or (Locale:Format("macros.explain.clicks_the_button_button.5ed89e", { button = button }))))
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
  return #out > 0 and table.concat(out, " ") or Locale:Get("macros.explain.runs_a_lua_script.8f9009")
end

local function Simple(entry, castSeen)
  local c = entry.clauses and entry.clauses[1]
  local g = c and c.groups[1]
  local unit = g and g.unit and UnitLabel(g.unit)
  local cond = g and Conds(g) or ""
  local when = cond ~= "" and (Locale:Format("macros.explain.if_cond.5d6728", { cond = cond })) or ""
  local arg = c and c.action or entry.args
  local cmd = entry.cmd
  local t = {
    stopcasting = castSeen and Locale:Get("macros.explain.attempts_to_stop_your_cast_or_channel.51d88c")
      or Locale:Get("macros.explain.stops_your_current_cast_or_channel_before.96447a"),
    startattack = Locale:Format("macros.explain.starts_auto_attacking_value2.aace64", { value2 = (unit or Locale:Get("highground.display.your_target.487d8f")) }),
    stopattack = Locale:Get("macros.explain.stops_auto_attacking.e27a22"),
    cancelaura = Locale:Format("macros.explain.removes_arg_from_you_if_you_have.2458d0", { arg = arg }),
    cancelform = Locale:Get("macros.explain.leaves_your_current_form.e7fbeb"),
    focus = Locale:Format("macros.explain.sets_your_focus_to_value2.edb949", { value2 = (unit or (arg ~= "" and arg) or Locale:Get("highground.display.your_target.487d8f")) }),
    clearfocus = Locale:Get("macros.explain.clears_your_focus.293cd1"),
    target = Locale:Format("macros.explain.targets_value2.34155b", { value2 = (unit or (arg ~= "" and arg) or Locale:Get("highground.display.your_target.487d8f")) }),
    targetexact = Locale:Format("macros.explain.targets_exactly_arg.872965", { arg = arg }),
    cleartarget = Locale:Get("macros.explain.clears_your_target.7ead88"),
    targetenemy = Locale:Get("macros.explain.targets_the_nearest_enemy.47766e"),
    targetenemyplayer = Locale:Get("macros.explain.targets_the_nearest_enemy_player.91dc1f"),
    targetlasttarget = Locale:Get("macros.explain.targets_your_previous_target.2531c7"),
    petattack = Locale:Format("macros.explain.sends_your_pet_to_attack_value2.d624f5", { value2 = (unit or Locale:Get("highground.display.your_target.487d8f")) }),
    petfollow = Locale:Get("macros.explain.calls_your_pet_back_to_follow_you.25166f"),
    petpassive = Locale:Get("macros.explain.sets_your_pet_to_passive.235a05"),
    petstay = Locale:Get("macros.explain.tells_your_pet_to_stay.40980e"),
    click = CLICKS[arg] or (Locale:Format("macros.explain.clicks_the_button_arg_an_addon_s.2006eb", { arg = arg })),
    tm = Locale:Format("macros.explain.puts_the_value2_marker_on_value4.0a5807", { value2 = (MARKERS[tonumber(arg) or 0] or "raid"), value4 = (unit or Locale:Get("highground.display.your_target.487d8f")) }),
    ping = Locale:Format("macros.explain.pings_value2_value3.2cbd6d", { value2 = (unit or Locale:Get("highground.display.your_target.487d8f")), value3 = (arg ~= "" and (" (" .. arg .. ")") or "") }),
    stopmacro = Locale:Get("macros.explain.stops_the_macro_here.befb20"),
    dismount = Locale:Get("macros.explain.dismounts.1f809f"),
    equip = Locale:Format("macros.explain.equips_arg.486634", { arg = arg }),
    equipslot = Locale:Format("macros.explain.equips_into_a_slot_arg.a82429", { arg = arg }),
  }
  t.targetmarker = t.tm
  if t[cmd] then return t[cmd] .. when .. "." end
  if cmd == "castsequence" then
    local steps = c and c.steps or {}
    local resets = {}
    for r in ((c and c.reset or "") .. "/"):gmatch("([^/]*)/") do
      if tonumber(r) then resets[#resets + 1] = Locale:Format("macros.explain.r_seconds_without_pressing_it.e81513", { r = r })
      elseif RESETS[r:lower()] then resets[#resets + 1] = RESETS[r:lower()].phrase end
    end
    return Locale:Format("macros.explain.casts_value2_on_successive_presses_value4_when.ecef86", { value2 = table.concat(steps, Locale:Get("macros.explain.then.b4df91")), value4 = (#resets > 0 and (Locale:Format("macros.explain.starting_over_after_value2.24f1df", { value2 = table.concat(resets, Locale:Get("macros.explain.or.439ac6")) })) or Locale:Get("macros.explain.then_starts_over.559c21")), when = when })
  end
  if entry.kind == "emote" then
    return Locale:Format("macros.explain.does_the_cmd_emote_value4.580aef", { cmd = cmd, value4 = (entry.args ~= "" and (" (" .. entry.args .. ")") or "") })
  end
  if cmd == "random" or cmd == "roll" or cmd == "rnd" then
    return Locale:Format("macros.explain.rolls_a_random_number_value2.e8fac0", { value2 = (entry.args ~= "" and (" (" .. entry.args .. ")") or Locale:Get("macros.explain.from_1_to_100.fe7bc5")) })
  end
  if entry.kind == "plain" then
    if cmd == "run" or cmd == "script" then return Script(entry.args) end
    local chat = Config.CHAT_WORDS[cmd]
    if chat then
      local text = '"' .. entry.args:gsub("%%t", "<your target>"):gsub("%%f", "<your focus>") .. '"'
      if chat == "says" or chat == "yells" then return Locale:Format(chat == "says" and "shared.messages.says_text_nearby.ab5035" or "shared.messages.yells_text_nearby.b9fdb5", { text = text }) end
      if chat == "emote" then return Locale:Format("macros.explain.emotes_text.c4ba45", { text = text }) end
      return Locale:Format(({ ["party"] = "shared.messages.says_text_in_party_chat.9e09af", ["raid"] = "shared.messages.says_text_in_raid_chat.1150a7", ["raid warning"] = "shared.messages.says_text_in_raid_warning.d48d44", ["instance"] = "shared.messages.says_text_in_instance_chat.7bc607", ["guild"] = "shared.messages.says_text_in_guild_chat.cfe7f6", ["officer"] = "shared.messages.says_text_in_officer_chat.48e11a" })[chat], { text = text })
    end
    if cmd == "hg" or cmd == "highground" then return Locale:Format("macros.explain.runs_the_highground_command_hg_entry_args.e7f00a", { entry_args = entry.args }) end
    return Locale:Format("macros.explain.sends_cmd_entry_args.237d47", { cmd = cmd, entry_args = entry.args })
  end
  return Locale:Format("macros.explain.runs_cmd.b1fa8d", { cmd = cmd })
end

function Macros.Explain(result)
  local out, cancelled, castSeen = {}, {}, false
  for _, e in ipairs(result.lines) do
    if e.cmd == "cancelaura" and e.clauses then
      for _, c in ipairs(e.clauses) do cancelled[c.action:lower()] = c.action end
    end
    if e.directive then
      out[#out + 1] = Locale:Format("macros.explain.shows_the_icon_and_tooltip_of_value2.97f2cd", { value2 = (e.arg ~= "" and e.arg or Locale:Get("macros.explain.the_spell_it_will_cast.50ec70")) })
    elseif e.chat then
      out[#out + 1] = Locale:Format("macros.explain.says_e_raw_in_chat.72a684", { e_raw = e.raw })
    elseif e.cmd and VERBS[e.cmd] and e.clauses then
      local text = CastSentence(e)
      for _, c in ipairs(e.clauses) do
        local spell = cancelled[c.action:gsub("^!", ""):lower()]
        if spell then text = Locale:Format("macros.explain.text_pressing_it_while_spell_is_on.352d97", { text = text, spell = spell }) end
      end
      out[#out + 1] = text
    elseif e.cmd then
      out[#out + 1] = Simple(e, castSeen)
    end
    if e.cmd == "cast" or e.cmd == "castsequence" or e.cmd == "castrandom" then castSeen = true end
  end
  return out
end
