local _, ns = ...
ns.Macros = ns.Macros or {}

---------------------------------------------------------------------------
-- Data of the macro tools (macros/*.lua), as ns.Macros.Config: the words
-- players see, the macro language the compiler checks, what autocomplete
-- offers and the buffs worth cancelling before a cast.
--   UNITS[token] = { label (button), short (variant button and name suffix),
--     phrase (in sentences), tip (tooltip title), about (tooltip text) }
-- A unit's target ("focustarget", "Bob-target") is built from these.
---------------------------------------------------------------------------
local Config = {}
ns.Macros.Config = Config

Config.UNITS = {
  target = ns.Localization.Define({ label = ns.Locale:Get("macros.macros.target.61ad50"), phrase = ns.Locale:Get("highground.display.your_target.487d8f"), tip = ns.Locale:Get("macros.macros.target.61ad50"), about = ns.Locale:Get("macros.macros.your_current_target.03609f") }, { label = "macros.macros.target.61ad50", phrase = "highground.display.your_target.487d8f", tip = "macros.macros.target.61ad50", about = "macros.macros.your_current_target.03609f" }),
  focus = ns.Localization.Define({ label = ns.Locale:Get("macros.macros.focus.fe7f55"), short = "F", phrase = ns.Locale:Get("macros.macros.your_focus.e1f34c"), tip = ns.Locale:Get("macros.macros.focus.fe7f55"), about = ns.Locale:Get("macros.macros.set_a_second_target_select_a_player.39f376") }, { label = "macros.macros.focus.fe7f55", phrase = "macros.macros.your_focus.e1f34c", tip = "macros.macros.focus.fe7f55", about = "macros.macros.set_a_second_target_select_a_player.39f376" }),
  mouseover = ns.Localization.Define({ label = ns.Locale:Get("macros.macros.mouseover.838654"), short = "MO", phrase = ns.Locale:Get("macros.macros.the_unit_under_your_mouse.ca656a"), tip = ns.Locale:Get("macros.macros.mouseover.838654"),
    about = ns.Locale:Get("macros.macros.the_unit_under_your_mouse_on_a.9f6381") }, { label = "macros.macros.mouseover.838654", phrase = "macros.macros.the_unit_under_your_mouse.ca656a", tip = "macros.macros.mouseover.838654", about = "macros.macros.the_unit_under_your_mouse_on_a.9f6381" }),
  cursor = ns.Localization.Define({ label = ns.Locale:Get("macros.macros.cursor.223994"), phrase = ns.Locale:Get("macros.macros.the_ground_at_your_cursor.099c7f"), tip = ns.Locale:Get("macros.macros.cursor.223994"),
    about = ns.Locale:Get("macros.macros.the_ground_at_your_cursor_no_targeting.732f7b") }, { label = "macros.macros.cursor.223994", phrase = "macros.macros.the_ground_at_your_cursor.099c7f", tip = "macros.macros.cursor.223994", about = "macros.macros.the_ground_at_your_cursor_no_targeting.732f7b" }),
  player = ns.Localization.Define({ label = ns.Locale:Get("macros.macros.self.e10251"), short = "Me", phrase = ns.Locale:Get("macros.macros.yourself.207705"), tip = ns.Locale:Get("macros.macros.me.94563e"), about = ns.Locale:Get("macros.macros.yourself.803037") }, { label = "macros.macros.self.e10251", phrase = "macros.macros.yourself.207705", tip = "macros.macros.me.94563e", about = "macros.macros.yourself.803037" }),
  pet = ns.Localization.Define({ label = ns.Locale:Get("macros.macros.pet.df2624"), phrase = ns.Locale:Get("macros.macros.your_pet.5ec089") }, { label = "macros.macros.pet.df2624", phrase = "macros.macros.your_pet.5ec089" }),
  none = ns.Localization.Define({ label = ns.Locale:Get("macros.macros.none.6eef66"), phrase = ns.Locale:Get("macros.macros.nothing_you_pick.16291f") }, { label = "macros.macros.none.6eef66", phrase = "macros.macros.nothing_you_pick.16291f" }),
}
for i = 1, 5 do
  Config.UNITS["arena" .. i] = { label = ns.Locale:Format("macros.macros.arena_i.faf632", { i = i }), short = "A" .. i, phrase = ns.Locale:Format("macros.macros.arena_enemy_i.cc345d", { i = i }),
    tip = ns.Locale:Format("macros.macros.arena_i.faf632", { i = i }), about = ns.Locale:Format("macros.macros.arena_enemy_i_value3.c28521", { i = i, value3 = (i == 1 and ns.Locale:Get("macros.macros.the_first_enemy_on_the_arena_frames.270332") or i > 3 and ns.Locale:Get("macros.macros.5v5_only.b901c2") or "") }) }
end
for i = 1, 4 do
  Config.UNITS["party" .. i] = { label = ns.Locale:Format("macros.macros.party_i.456271", { i = i }), short = "P" .. i, phrase = ns.Locale:Format("macros.macros.party_member_i.fbb84f", { i = i }),
    tip = ns.Locale:Format("macros.macros.party_i.456271", { i = i }), about = ns.Locale:Format("macros.macros.party_member_i_value3.17976e", { i = i, value3 = (i == 1 and ns.Locale:Get("macros.macros.the_first_under_you_on_the_party.ec660b") or "") }) }
end

-- Raid markers by number (/tm 1-8; 0 clears).
Config.MARKERS = ns.Localization.Define({ ns.Locale:Get("battlegrounds.commands.star.85a7de"), ns.Locale:Get("battlegrounds.commands.circle.1cc782"), ns.Locale:Get("battlegrounds.commands.diamond.b3850e"), ns.Locale:Get("battlegrounds.commands.triangle.73d3ae"), ns.Locale:Get("battlegrounds.commands.moon.846b90"), ns.Locale:Get("battlegrounds.commands.square.82810c"), ns.Locale:Get("battlegrounds.commands.cross.dbfe73"), ns.Locale:Get("highground.snipercolors.skull.bdb525") }, { [1] = "battlegrounds.commands.star.85a7de", [2] = "battlegrounds.commands.circle.1cc782", [3] = "battlegrounds.commands.diamond.b3850e", [4] = "battlegrounds.commands.triangle.73d3ae", [5] = "battlegrounds.commands.moon.846b90", [6] = "battlegrounds.commands.square.82810c", [7] = "battlegrounds.commands.cross.dbfe73", [8] = "highground.snipercolors.skull.bdb525" })
-- Modifier keys ([mod:shift], reset=shift).
Config.MODS = { shift = "Shift", ctrl = "Ctrl", alt = "Alt" }
-- /castsequence reset= words: button label, phrase in explanations and
-- autocomplete hint.
Config.RESETS = {
  ns.Localization.Define({ key = "target", button = ns.Locale:Get("macros.macros.new_target.4bddce"), phrase = ns.Locale:Get("macros.macros.a_new_target.473e80"), hint = ns.Locale:Get("macros.macros.new_target.17f3b4") }, { button = "macros.macros.new_target.4bddce", phrase = "macros.macros.a_new_target.473e80", hint = "macros.macros.new_target.17f3b4" }),
  ns.Localization.Define({ key = "combat", button = ns.Locale:Get("macros.macros.combat_ends.4f90c5"), phrase = ns.Locale:Get("macros.macros.leaving_combat.c08a42"), hint = ns.Locale:Get("macros.macros.leaving_combat.c08a42") }, { button = "macros.macros.combat_ends.4f90c5", phrase = "macros.macros.leaving_combat.c08a42", hint = "macros.macros.leaving_combat.c08a42" }),
  ns.Localization.Define({ key = "shift", button = "Shift", phrase = ns.Locale:Get("macros.macros.pressing_it_with_shift.b5e58b") }, { phrase = "macros.macros.pressing_it_with_shift.b5e58b" }),
  ns.Localization.Define({ key = "ctrl", button = "Ctrl", phrase = ns.Locale:Get("macros.macros.pressing_it_with_ctrl.845bac") }, { phrase = "macros.macros.pressing_it_with_ctrl.845bac" }),
  ns.Localization.Define({ key = "alt", button = "Alt", phrase = ns.Locale:Get("macros.macros.pressing_it_with_alt.05e881") }, { phrase = "macros.macros.pressing_it_with_alt.05e881" }),
}
-- Builder's alternative action (macros/Builder.lua alt): when it applies
-- ([cond] in the macro), in menu order, then what it does.
Config.ALT_WHEN = {
  shift = ns.Localization.Define({ cond = "mod:shift", label = ns.Locale:Get("macros.macros.shift_is_held.1d6c86") }, { label = "macros.macros.shift_is_held.1d6c86" }), ctrl = ns.Localization.Define({ cond = "mod:ctrl", label = ns.Locale:Get("macros.macros.ctrl_is_held.5d6c56") }, { label = "macros.macros.ctrl_is_held.5d6c56" }),
  alt = ns.Localization.Define({ cond = "mod:alt", label = ns.Locale:Get("macros.macros.alt_is_held.48229f") }, { label = "macros.macros.alt_is_held.48229f" }), nocombat = ns.Localization.Define({ cond = "nocombat", label = ns.Locale:Get("macros.macros.out_of_combat.e5b590") }, { label = "macros.macros.out_of_combat.e5b590" }),
  btn2 = ns.Localization.Define({ cond = "btn:2", label = ns.Locale:Get("macros.macros.right_clicked.2b6975") }, { label = "macros.macros.right_clicked.2b6975" }),
}
Config.ALT_ORDER = { "shift", "ctrl", "alt", "nocombat", "btn2" }
Config.ALT_DO = { ns.Localization.Define({ key = "self", label = ns.Locale:Get("macros.macros.cast_it_on_myself.c85126") }, { label = "macros.macros.cast_it_on_myself.c85126" }), ns.Localization.Define({ key = "focus", label = ns.Locale:Get("macros.macros.cast_it_on_my_focus.b7d50e") }, { label = "macros.macros.cast_it_on_my_focus.b7d50e" }),
  ns.Localization.Define({ key = "cursor", label = ns.Locale:Get("macros.macros.cast_it_at_my_cursor.453ffe") }, { label = "macros.macros.cast_it_at_my_cursor.453ffe" }), ns.Localization.Define({ key = "spell", label = ns.Locale:Get("macros.macros.cast_another_spell.e86421") }, { label = "macros.macros.cast_another_spell.e86421" }),
  ns.Localization.Define({ key = "rank", label = ns.Locale:Get("macros.macros.cast_a_lower_rank.9ff9fc"), ranks = true }, { label = "macros.macros.cast_a_lower_rank.9ff9fc" }) }
-- Builder's announce line (/p Polymorph on %t), in menu order. Midnight
-- clients allow only group chat during boss encounters.
Config.CHAT = { p = ns.Localization.Define({ label = ns.Locale:Get("macros.macros.party_chat.022bfb") }, { label = "macros.macros.party_chat.022bfb" }), ra = ns.Localization.Define({ label = ns.Locale:Get("macros.macros.raid_chat.6be3ae") }, { label = "macros.macros.raid_chat.6be3ae" }), i = ns.Localization.Define({ label = ns.Locale:Get("macros.macros.instance_chat.16d89d") }, { label = "macros.macros.instance_chat.16d89d" }),
  s = ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.commands.say.c90361") }, { label = "battlegrounds.commands.say.c90361" }), y = ns.Localization.Define({ label = ns.Locale:Get("battlegrounds.commands.yell.11dced") }, { label = "battlegrounds.commands.yell.11dced" }) }
Config.CHAT_ORDER = { "p", "ra", "i", "s", "y" }
-- Chat commands in explanations: where the text goes. %t and %f name your
-- target and focus when sent.
Config.CHAT_WORDS = { s = "says", say = "says", y = "yells", yell = "yells", p = "party", party = "party",
  ra = "raid", raid = "raid", rw = "raid warning", i = "instance", instance = "instance", g = "guild",
  guild = "guild", o = "officer", officer = "officer", e = "emote", emote = "emote", me = "emote" }

-- Equipment slots by number (/use 13), as said in explanations.
Config.SLOTS = ns.Localization.Define({ ["1"] = ns.Locale:Get("macros.macros.your_head_item.73acb8"), ["2"] = ns.Locale:Get("macros.macros.your_neck_item.274683"), ["3"] = ns.Locale:Get("macros.macros.your_shoulder_item.04e87b"),
  ["5"] = ns.Locale:Get("macros.macros.your_chest_item.31fda0"), ["6"] = ns.Locale:Get("macros.macros.your_belt.21073a"), ["7"] = ns.Locale:Get("macros.macros.your_legs_item.0c328c"), ["8"] = ns.Locale:Get("macros.macros.your_boots.9c338f"),
  ["9"] = ns.Locale:Get("macros.macros.your_wrist_item.dbb14a"), ["10"] = ns.Locale:Get("macros.macros.your_gloves.186eda"), ["11"] = ns.Locale:Get("macros.macros.your_first_ring.cb0a83"), ["12"] = ns.Locale:Get("macros.macros.your_second_ring.c8c559"),
  ["13"] = ns.Locale:Get("macros.macros.your_top_trinket.ce319e"), ["14"] = ns.Locale:Get("macros.macros.your_bottom_trinket.3e2650"), ["15"] = ns.Locale:Get("macros.macros.your_cloak.fc2d0e"),
  ["16"] = ns.Locale:Get("macros.macros.your_main_hand_item.a60d69"), ["17"] = ns.Locale:Get("macros.macros.your_off_hand_item.73a091") }, { ["1"] = "macros.macros.your_head_item.73acb8", ["2"] = "macros.macros.your_neck_item.274683", ["3"] = "macros.macros.your_shoulder_item.04e87b", ["5"] = "macros.macros.your_chest_item.31fda0", ["6"] = "macros.macros.your_belt.21073a", ["7"] = "macros.macros.your_legs_item.0c328c", ["8"] = "macros.macros.your_boots.9c338f", ["9"] = "macros.macros.your_wrist_item.dbb14a", ["10"] = "macros.macros.your_gloves.186eda", ["11"] = "macros.macros.your_first_ring.cb0a83", ["12"] = "macros.macros.your_second_ring.c8c559", ["13"] = "macros.macros.your_top_trinket.ce319e", ["14"] = "macros.macros.your_bottom_trinket.3e2650", ["15"] = "macros.macros.your_cloak.fc2d0e", ["16"] = "macros.macros.your_main_hand_item.a60d69", ["17"] = "macros.macros.your_off_hand_item.73a091" })

-- Macro language (macros/Compiler.lua) -----------------------------------
-- How a command reads its argument: "cond" takes [conditions] and an
-- action, "seq" is /castsequence, "plain" takes text as is.
Config.COMMANDS = {
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
  hg = "plain", highground = "plain",
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
-- Every other command, from warcraft.wiki.gg "Macro commands" (with the
-- game's aliases such as /roll and /rnd for /random): they take their text
-- as is.
Config.MORE_COMMANDS = {
  "1", "2", "3", "4", "5", "achievements", "afk", "announce", "api", "assist", "ban", "battleground",
  "calendar", "camp", "cancelaura", "cancelform", "cancelqueuedspell", "cast", "castrandom", "castsequence",
  "changeactionbar", "chathelp", "chatinvite", "chatlist", "chatlog", "ckick", "clearfocus", "cleartarget",
  "clearworldmarker", "click", "combatlog", "console", "csay", "disableaddons", "dismisspet", "dismount",
  "dnd", "duel", "dump", "dungeonfinder", "e", "emote", "enableaddons", "equip", "equipset", "equipslot",
  "eventtrace", "ffa", "focus", "follow", "forfeit", "framestack", "friend", "g", "group", "guild",
  "guilddemote", "guilddisband", "guildfinder", "guildinfo", "guildinvite", "guildleader", "guildmotd",
  "guildpromote", "guildquit", "guildremove", "guildroster", "help", "i", "ignore", "inspect", "inv",
  "invite", "join", "leave", "leavevehicle", "lfr", "logout", "loot", "macro", "macrohelp", "mainassist",
  "mainassistoff", "maintank", "maintankoff", "master", "me", "moderator", "mute", "o", "officer", "owner",
  "p", "party", "password", "petaggressive", "petassist", "petattack", "petautocastoff", "petautocaston",
  "petautocasttoggle", "petdefensive", "petdismiss", "petfollow", "petmoveto", "petpassive", "petstay",
  "played", "promote", "pvp", "quit", "r", "ra", "raid", "raidfinder", "raidinfo", "random",
  "randomfavoritepet", "randompet", "readycheck", "reload", "removefriend", "reply", "requestinvite",
  "resetchat", "rnd", "roll", "rw", "s", "say", "script", "settitle", "share", "sit", "stand", "startattack",
  "stopattack", "stopcasting", "stopmacro", "stopspelltarget", "stopwatch", "summonpet", "swapactionbar",
  "t", "tableinspect", "target", "targetenemy", "targetenemyplayer", "targetexact", "targetfriend",
  "targetfriendplayer", "targetlastenemy", "targetlastfriend", "targetlasttarget", "targetmarker",
  "targetparty", "targetraid", "tell", "threshold", "time", "timetest", "trade", "unban", "unignore",
  "uninvite", "unmoderator", "unmute", "use", "userandom", "usetalents", "usetoy", "w", "wargame", "whisper",
  "who", "worldmarker", "y", "yell",
}
-- Emotes, from the same page.
Config.EMOTES = {
  "absent", "agree", "amaze", "angry", "apologize", "applaud", "applause", "arm", "attacktarget", "awe",
  "backpack", "bad", "badfeeling", "bark", "bashful", "beckon", "beg", "belch", "bite", "blame", "blank",
  "bleed", "blink", "blood", "blow", "blush", "boggle", "bonk", "bored", "bounce", "bow", "brandish",
  "bravo", "brb", "breath", "brow", "burp", "bye", "cackle", "calm", "cat", "catty", "challenge", "charge",
  "charm", "cheer", "chew", "chicken", "chuckle", "chug", "clap", "cold", "comfort", "commend", "confused",
  "congrats", "congratulate", "cough", "coverears", "cower", "crack", "cringe", "crossarms", "cry", "cuddle",
  "curious", "curtsey", "dance", "ding", "disagree", "disappointed", "disappointment", "doh", "doom",
  "doubt", "drink", "drool", "duck", "eat", "embarrass", "encourage", "enemy", "excited", "eye", "eyebrow",
  "eyeroll", "facepalm", "faint", "farewell", "fart", "fear", "feast", "fidget", "fist", "flap", "flee",
  "flex", "flirt", "flop", "followme", "food", "frown", "gasp", "gaze", "giggle", "glad", "glare", "gloat",
  "glower", "go", "going", "golfclap", "goodbye", "grats", "greet", "greetings", "grin", "groan", "grovel",
  "growl", "guffaw", "hail", "happy", "headache", "healme", "hello", "helpme", "hi", "hiccup", "highfive",
  "hiss", "holdhand", "holdit", "holler", "hug", "hungry", "hurry", "idea", "impatient", "inc", "incoming",
  "insult", "introduce", "jealous", "jk", "kiss", "kneel", "knuckles", "laugh", "lavish", "lay", "laydown",
  "lean", "lick", "lie", "liedown", "listen", "lol", "look", "lost", "love", "luck", "mad", "map", "massage",
  "mercy", "moan", "mock", "moo", "moon", "mountspecial", "mourn", "mutter", "nervous", "no", "nod",
  "nosepick", "object", "objection", "offer", "oom", "openfire", "pack", "palm", "panic", "pat", "peer",
  "peon", "pest", "pet", "pick", "pinch", "pity", "pizza", "plead", "point", "poke", "ponder", "pounce",
  "pout", "praise", "pray", "promise", "proud", "pulse", "punch", "purr", "puzzled", "question", "raise",
  "rasp", "rawr", "rdy", "read", "ready", "rear", "regret", "retreat", "revenge", "roar", "rofl", "rolleyes",
  "rude", "ruffle", "sad", "salute", "scared", "scoff", "scold", "scowl", "scratch", "search", "sexy",
  "shake", "shakefist", "shifty", "shimmy", "shindig", "shiver", "shoo", "shout", "shrug", "shudder",
  "shush", "shy", "sigh", "signal", "silence", "silly", "sing", "sit", "slap", "sleep", "smack", "smell",
  "smile", "smirk", "snap", "snarl", "sneak", "sneeze", "snicker", "sniff", "snort", "snub", "sob", "soothe",
  "sorry", "spit", "spoon", "squeal", "stand", "stare", "stink", "strong", "strut", "surprised", "surrender",
  "suspicious", "sweat", "talk", "talkex", "talkq", "tap", "taunt", "tease", "thank", "thanks", "think",
  "thirsty", "threaten", "tickle", "tired", "train", "truce", "twiddle", "ty", "veto", "victory", "violin",
  "volunteer", "wait", "warn", "wave", "weep", "welcome", "whine", "whistle", "wicked", "wickedly", "wink",
  "woot", "work", "wrath", "yawn", "yay", "yes",
}
-- Commands only some games have (the others exist everywhere).
-- Commands a game has exactly when it has a capability (config/Client.lua).
Config.COMMAND_CAPS = { ping = "pings", pingspell = "pings", pingitem = "pings" }
Config.COMMAND_GAMES = {
  usetoy = { retail = true, forever = true },
  petassist = { retail = true, forever = true }, abandon = { retail = true, forever = true },
  rc = { retail = true, forever = true }, makgora = { cata = true, forever = true, classic = true },
}
-- Commands that do nothing useful without an action after the conditions.
Config.NEEDS_ACTION = { cast = true, use = true, castrandom = true, userandom = true, cancelaura = true,
  click = true, targetexact = true, equip = true, equipslot = true }

-- Conditions in [ ]; each also takes a "no" prefix.
Config.CONDITIONS = {
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
Config.CONDITION_GAMES = { advflyable = { retail = true }, petbattle = { retail = true },
  pvpcombat = { retail = true }, house = { retail = true } }
Config.CONDITION_UNSURE = { known = { cata = true, forever = true, classic = true, tbc = true } }
Config.CONDITION_REMOVED = ns.Localization.Define({ talent = ns.Locale:Get("macros.macros.removed_in_dragonflight.9cdc15"), pvptalent = ns.Locale:Get("macros.macros.no_longer_exists.2b5eba") }, { talent = "macros.macros.removed_in_dragonflight.9cdc15", pvptalent = "macros.macros.no_longer_exists.2b5eba" })
-- Conditions about the unit the spell lands on (the rest are about you).
Config.UNIT_CONDITIONS = { harm = true, help = true, exists = true, dead = true, party = true, raid = true }
-- Simple conditions in explanations (macros/Explain.lua); "not: " in
-- front when negated.
Config.CONDITION_WORDS = ns.Localization.Define({ group = "you are in a group", party = ns.Locale:Get("macros.macros.it_is_in_your_party.8ffde2"),
  raid = ns.Locale:Get("macros.macros.it_is_in_your_raid.c94360"), indoors = ns.Locale:Get("macros.macros.you_are_indoors.a5612e"), outdoors = ns.Locale:Get("macros.macros.you_are_outdoors.9364a5"),
  mounted = ns.Locale:Get("macros.macros.you_are_mounted.d1b4d5"), swimming = ns.Locale:Get("macros.macros.you_are_swimming.1a8bfa"), flying = ns.Locale:Get("macros.macros.you_are_flying.a559f3"),
  resting = ns.Locale:Get("macros.macros.you_are_resting.759a5b") }, { party = "macros.macros.it_is_in_your_party.8ffde2", raid = "macros.macros.it_is_in_your_raid.c94360", indoors = "macros.macros.you_are_indoors.a5612e", outdoors = "macros.macros.you_are_outdoors.9364a5", mounted = "macros.macros.you_are_mounted.d1b4d5", swimming = "macros.macros.you_are_swimming.1a8bfa", flying = "macros.macros.you_are_flying.a559f3", resting = "macros.macros.you_are_resting.759a5b" })

-- Unit tokens after @ or target= (each may end in "target": focustarget).
Config.UNIT_TOKENS = { target = true, player = true, focus = true, mouseover = true, pet = true, vehicle = true,
  cursor = true, none = true, softenemy = true, softfriend = true, softinteract = true, anyenemy = true,
  anyfriend = true, anyinteract = true }
Config.UNIT_PATTERNS = { "^party[1-4]$", "^partypet[1-4]$", "^raid%d+$", "^raidpet%d+$", "^arena[1-5]$",
  "^arenapet[1-5]$", "^boss[1-8]$", "^nameplate%d+$" }

-- Autocomplete (macros/Suggest.lua) ----------------------------------------
Config.COMMAND_HINTS = ns.Localization.Define({ cast = ns.Locale:Get("macros.macros.cast_a_spell.f7b965"), use = ns.Locale:Get("macros.macros.use_an_item_or_slot.7cafb5"), stopcasting = ns.Locale:Get("macros.macros.stop_your_current_cast_or_channel.7bd35f"),
  startattack = ns.Locale:Get("macros.macros.start_auto_attack.9c5a6f"), cancelaura = ns.Locale:Get("macros.macros.remove_a_buff.523014"), focus = ns.Locale:Get("macros.macros.set_focus.17c472"), target = "target",
  castsequence = ns.Locale:Get("macros.macros.spells_in_turn.768ef4"), petattack = ns.Locale:Get("macros.macros.pet_attacks.881f8c"), tm = ns.Locale:Get("macros.macros.raid_marker.ccc49c"), click = ns.Locale:Get("macros.macros.click_a_button.7893da") }, { cast = "macros.macros.cast_a_spell.f7b965", use = "macros.macros.use_an_item_or_slot.7cafb5", stopcasting = "macros.macros.stop_your_current_cast_or_channel.7bd35f", startattack = "macros.macros.start_auto_attack.9c5a6f", cancelaura = "macros.macros.remove_a_buff.523014", focus = "macros.macros.set_focus.17c472", castsequence = "macros.macros.spells_in_turn.768ef4", petattack = "macros.macros.pet_attacks.881f8c", tm = "macros.macros.raid_marker.ccc49c", click = "macros.macros.click_a_button.7893da" })
-- Units offered after @ and target=, in this order.
Config.SUGGEST_UNITS = { "target", "focus", "mouseover", "player", "cursor", "pet", "arena1", "arena2", "arena3",
  "party1", "party2", "targettarget", "focustarget", "none" }
-- Values after "name:" in [ ]; aliases share their condition's list.
Config.CONDITION_VALUES = {
  mod = { { text = "shift" }, { text = "ctrl" }, { text = "alt" } },
  btn = { ns.Localization.Define({ text = "1", hint = ns.Locale:Get("macros.macros.left.12c0f1") }, { hint = "macros.macros.left.12c0f1" }), ns.Localization.Define({ text = "2", hint = ns.Locale:Get("macros.macros.right.d27a1f") }, { hint = "macros.macros.right.d27a1f" }), ns.Localization.Define({ text = "3", hint = ns.Locale:Get("macros.macros.middle.85c274") }, { hint = "macros.macros.middle.85c274" }),
    { text = "4" }, { text = "5" } },
  stance = { ns.Localization.Define({ text = "0", hint = ns.Locale:Get("macros.macros.no_stance_or_form.a7a010") }, { hint = "macros.macros.no_stance_or_form.a7a010" }), { text = "1" }, { text = "2" }, { text = "3" }, { text = "4" },
    { text = "5" }, { text = "6" } },
  spec = { { text = "1" }, { text = "2" }, { text = "3" }, { text = "4" } },
  group = { { text = "party" }, { text = "raid" } },
}
Config.CONDITION_VALUES.modifier = Config.CONDITION_VALUES.mod
Config.CONDITION_VALUES.button = Config.CONDITION_VALUES.btn
Config.CONDITION_VALUES.form = Config.CONDITION_VALUES.stance
Config.DIRECTIVES = { ns.Localization.Define({ text = "showtooltip", hint = ns.Locale:Get("macros.macros.icon_and_tooltip_of_a_spell.7ae673") }, { hint = "macros.macros.icon_and_tooltip_of_a_spell.7ae673" }),
  ns.Localization.Define({ text = "show", hint = ns.Locale:Get("macros.macros.icon_of_a_spell.0124ba") }, { hint = "macros.macros.icon_of_a_spell.0124ba" }) }

-- Buffs to /cancelaura (macros/Sources.lua) ---------------------------------
-- Buffs worth removing before a cast because they block or waste it:
-- { name, why } per class, then ones other players can put on you
-- (known = only if it is in your spellbook). Names may differ per game:
-- G(cata, retail, forever[, tbc[, classic]]), as Macros.G in
-- macros/General.lua.
local function G(cata, retail, forever, tbc, classic)
  return { cata = cata, retail = retail, forever = forever, tbc = tbc, classic = classic }
end
-- Common columns: Cataclysm and Retail only; every game but Retail.
local function CataRetail(v) return G(v, v) end
local function NotRetail(v) return G(v, nil, v) end
Config.G, Config.CataRetail, Config.NotRetail = G, CataRetail, NotRetail -- also on Macros (macros/General.lua)
Config.CLASS_BUFFS = {
  WARRIOR = { ns.Localization.Define({ "Bladestorm", ns.Locale:Get("macros.macros.stops_your_other_abilities.d01ad8") }, { [2] = "macros.macros.stops_your_other_abilities.d01ad8" }), ns.Localization.Define({ "Recklessness", ns.Locale:Get("macros.macros.drop_it.d35d04") }, { [2] = "macros.macros.drop_it.d35d04" }) },
  PALADIN = { ns.Localization.Define({ ns.Locale:Get("macros.macros.divine_shield.56751d"), ns.Locale:Get("macros.macros.you_can_t_attack_under_it.641c6d") }, { [1] = "macros.macros.divine_shield.56751d", [2] = "macros.macros.you_can_t_attack_under_it.641c6d" }),
    ns.Localization.Define({ G("Hand of Protection", "Blessing of Protection", "Blessing of Protection"), ns.Locale:Get("macros.macros.you_can_t_attack_under_it.641c6d") }, { [2] = "macros.macros.you_can_t_attack_under_it.641c6d" }),
    ns.Localization.Define({ G(nil, "Blessing of Spellwarding"), ns.Locale:Get("macros.macros.drop_it.d35d04") }, { [2] = "macros.macros.drop_it.d35d04" }), ns.Localization.Define({ G("Divine Plea"), ns.Locale:Get("macros.macros.halves_your_healing.a1c87c") }, { [2] = "macros.macros.halves_your_healing.a1c87c" }) },
  MAGE = { ns.Localization.Define({ ns.Locale:Get("macros.macros.ice_block.0a3402"), ns.Locale:Get("macros.macros.blocks_every_action.a917a5") }, { [1] = "macros.macros.ice_block.0a3402", [2] = "macros.macros.blocks_every_action.a917a5" }), ns.Localization.Define({ G(nil, "Alter Time"), ns.Locale:Get("macros.macros.would_snap_you_back.3d3a9b") }, { [2] = "macros.macros.would_snap_you_back.3d3a9b" }),
    ns.Localization.Define({ "Invisibility", ns.Locale:Get("macros.macros.end_it_now.9fadae") }, { [2] = "macros.macros.end_it_now.9fadae" }), ns.Localization.Define({ G(nil, "Greater Invisibility"), ns.Locale:Get("macros.macros.end_it_now.9fadae") }, { [2] = "macros.macros.end_it_now.9fadae" }), ns.Localization.Define({ G("Mage Ward", nil), ns.Locale:Get("macros.macros.drop_it.d35d04") }, { [2] = "macros.macros.drop_it.d35d04" }) },
  PRIEST = { ns.Localization.Define({ CataRetail("Dispersion"), ns.Locale:Get("macros.macros.blocks_most_spells.71def5") }, { [2] = "macros.macros.blocks_most_spells.71def5" }), ns.Localization.Define({ "Shadowform", ns.Locale:Get("macros.macros.lets_you_heal.44f1d7") }, { [2] = "macros.macros.lets_you_heal.44f1d7" }),
    ns.Localization.Define({ G(nil, "Spirit of Redemption"), ns.Locale:Get("macros.macros.end_it.d9a299") }, { [2] = "macros.macros.end_it.d9a299" }) },
  HUNTER = { ns.Localization.Define({ G("Deterrence", nil), ns.Locale:Get("macros.macros.blocks_attacking.568d88") }, { [2] = "macros.macros.blocks_attacking.568d88" }), ns.Localization.Define({ G(nil, "Aspect of the Turtle"), ns.Locale:Get("macros.macros.blocks_attacking.568d88") }, { [2] = "macros.macros.blocks_attacking.568d88" }),
    ns.Localization.Define({ G(nil, "Camouflage"), ns.Locale:Get("macros.macros.leave_camouflage.cd6271") }, { [2] = "macros.macros.leave_camouflage.cd6271" }), ns.Localization.Define({ G("Aspect of the Pack", nil, "Aspect of the Cheetah"), ns.Locale:Get("macros.macros.dazed_when_hit.4e3c29") }, { [2] = "macros.macros.dazed_when_hit.4e3c29" }),
    ns.Localization.Define({ ns.Locale:Get("macros.macros.feign_death.4794e4"), ns.Locale:Get("macros.macros.stand_up.7da7e8") }, { [1] = "macros.macros.feign_death.4794e4", [2] = "macros.macros.stand_up.7da7e8" }) },
  DEATHKNIGHT = { ns.Localization.Define({ "Lichborne", ns.Locale:Get("macros.macros.turns_heals_into_damage.f4d04b") }, { [2] = "macros.macros.turns_heals_into_damage.f4d04b" }), ns.Localization.Define({ G(nil, "Death's Advance"), ns.Locale:Get("macros.macros.drop_it.d35d04") }, { [2] = "macros.macros.drop_it.d35d04" }) },
  DRUID = { ns.Localization.Define({ ns.Locale:Get("macros.macros.cat_form.e097e3"), ns.Locale:Get("macros.macros.leave_the_form.8b8d0b") }, { [1] = "macros.macros.cat_form.e097e3", [2] = "macros.macros.leave_the_form.8b8d0b" }), ns.Localization.Define({ G("Bear Form", "Bear Form", "Dire Bear Form"), ns.Locale:Get("macros.macros.leave_the_form.8b8d0b") }, { [2] = "macros.macros.leave_the_form.8b8d0b" }),
    ns.Localization.Define({ ns.Locale:Get("macros.macros.travel_form.45fcc2"), ns.Locale:Get("macros.macros.leave_the_form.8b8d0b") }, { [1] = "macros.macros.travel_form.45fcc2", [2] = "macros.macros.leave_the_form.8b8d0b" }), ns.Localization.Define({ "Moonkin Form", ns.Locale:Get("macros.macros.leave_the_form.8b8d0b") }, { [2] = "macros.macros.leave_the_form.8b8d0b" }),
    ns.Localization.Define({ G("Tree of Life", nil), ns.Locale:Get("macros.macros.leave_the_form.8b8d0b") }, { [2] = "macros.macros.leave_the_form.8b8d0b" }), ns.Localization.Define({ "Prowl", ns.Locale:Get("macros.macros.leave_stealth.94dcb7") }, { [2] = "macros.macros.leave_stealth.94dcb7" }) },
  SHAMAN = { ns.Localization.Define({ ns.Locale:Get("macros.macros.ghost_wolf.43a4be"), ns.Locale:Get("macros.macros.leave_the_form.8b8d0b") }, { [1] = "macros.macros.ghost_wolf.43a4be", [2] = "macros.macros.leave_the_form.8b8d0b" }), ns.Localization.Define({ G(nil, "Spirit Walk"), ns.Locale:Get("macros.macros.drop_it.d35d04") }, { [2] = "macros.macros.drop_it.d35d04" }) },
  ROGUE = { ns.Localization.Define({ "Stealth", ns.Locale:Get("macros.macros.leave_stealth.94dcb7") }, { [2] = "macros.macros.leave_stealth.94dcb7" }), ns.Localization.Define({ G(nil, "Shadow Dance"), ns.Locale:Get("macros.macros.leave_it_out_of_combat.322c2c") }, { [2] = "macros.macros.leave_it_out_of_combat.322c2c" }), ns.Localization.Define({ "Vanish", ns.Locale:Get("macros.macros.leave_stealth.94dcb7") }, { [2] = "macros.macros.leave_stealth.94dcb7" }) },
  WARLOCK = { ns.Localization.Define({ G("Soulburn", nil), ns.Locale:Get("macros.macros.drop_an_unused_soulburn.1f1f7d") }, { [2] = "macros.macros.drop_an_unused_soulburn.1f1f7d" }), ns.Localization.Define({ G(nil, "Burning Rush"), ns.Locale:Get("macros.macros.it_drains_your_health.7097ec") }, { [2] = "macros.macros.it_drains_your_health.7097ec" }),
    ns.Localization.Define({ G("Metamorphosis", nil), ns.Locale:Get("macros.macros.leave_the_form.8b8d0b") }, { [2] = "macros.macros.leave_the_form.8b8d0b" }) },
  MONK = { ns.Localization.Define({ ns.Locale:Get("macros.macros.zen_meditation.70c1ba"), ns.Locale:Get("macros.macros.would_cancel_itself.5d822d") }, { [1] = "macros.macros.zen_meditation.70c1ba", [2] = "macros.macros.would_cancel_itself.5d822d" }), ns.Localization.Define({ ns.Locale:Get("macros.macros.fortifying_brew.a8809e"), ns.Locale:Get("macros.macros.drop_it.d35d04") }, { [1] = "macros.macros.fortifying_brew.a8809e", [2] = "macros.macros.drop_it.d35d04" }) },
  DEMONHUNTER = { ns.Localization.Define({ "Netherwalk", ns.Locale:Get("macros.macros.blocks_attacking.568d88") }, { [2] = "macros.macros.blocks_attacking.568d88" }), ns.Localization.Define({ "Metamorphosis", ns.Locale:Get("macros.macros.leave_it.b922c2") }, { [2] = "macros.macros.leave_it.b922c2" }) },
  EVOKER = { ns.Localization.Define({ "Hover", ns.Locale:Get("macros.macros.stop_hovering.8ecb7f") }, { [2] = "macros.macros.stop_hovering.8ecb7f" }), ns.Localization.Define({ ns.Locale:Get("macros.macros.obsidian_scales.d2d81a"), ns.Locale:Get("macros.macros.drop_it.d35d04") }, { [1] = "macros.macros.obsidian_scales.d2d81a", [2] = "macros.macros.drop_it.d35d04" }) },
}
Config.OTHERS_BUFFS = {
  ns.Localization.Define({ G("Hand of Protection", "Blessing of Protection", "Blessing of Protection"), ns.Locale:Get("macros.macros.a_paladin_s_you_can_t_attack.270393") }, { [2] = "macros.macros.a_paladin_s_you_can_t_attack.270393" }),
  ns.Localization.Define({ G(nil, "Blessing of Spellwarding"), ns.Locale:Get("macros.macros.a_paladin_s_drop_it.32624f") }, { [2] = "macros.macros.a_paladin_s_drop_it.32624f" }),
  ns.Localization.Define({ G(nil, nil, "Divine Intervention"), ns.Locale:Get("macros.macros.a_paladin_s_you_can_t_act.19e3fc") }, { [2] = "macros.macros.a_paladin_s_you_can_t_act.19e3fc" }),
  ns.Localization.Define({ G("Hand of Salvation", nil, false, "Blessing of Salvation", "Blessing of Salvation"), ns.Locale:Get("macros.macros.a_paladin_s_no_threat.ab4f39") }, { [2] = "macros.macros.a_paladin_s_no_threat.ab4f39" }),
  ns.Localization.Define({ G(nil, "Power Infusion"), ns.Locale:Get("macros.macros.a_priest_s_drop_it.fa6f67") }, { [2] = "macros.macros.a_priest_s_drop_it.fa6f67" }),
  ns.Localization.Define({ "Shadowmeld", ns.Locale:Get("macros.macros.racial_leave_it.45d023"), known = true }, { [2] = "macros.macros.racial_leave_it.45d023" }), -- Night Elves only
}
-- Icon files by buff name: the game only finds icons by name for spells you
-- know, and these file names are the same in every game.
Config.BUFF_ICONS = {
  ["Bladestorm"] = "Ability_Warrior_Bladestorm", ["Recklessness"] = "Ability_CriticalStrike",
  ["Divine Shield"] = "Spell_Holy_DivineIntervention", ["Hand of Protection"] = "Spell_Holy_SealOfProtection",
  ["Blessing of Protection"] = "Spell_Holy_SealOfProtection", ["Blessing of Spellwarding"] = "Spell_Holy_BlessingOfProtection",
  ["Divine Plea"] = "Spell_Holy_Aspiration", ["Divine Intervention"] = "Spell_Nature_TimeStop",
  ["Hand of Salvation"] = "Spell_Holy_SealOfSalvation", ["Blessing of Salvation"] = "Spell_Holy_SealOfSalvation",
  ["Ice Block"] = "Spell_Frost_Frost", ["Alter Time"] = "Spell_Mage_AlterTime", ["Invisibility"] = "Ability_Mage_Invisibility",
  ["Greater Invisibility"] = "Ability_Mage_GreaterInvisibility", ["Mage Ward"] = "Spell_Fire_TwilightFireward",
  ["Dispersion"] = "Spell_Shadow_Dispersion", ["Shadowform"] = "Spell_Shadow_Shadowform",
  ["Spirit of Redemption"] = "Inv_Enchant_EssenceEternalLarge", ["Power Infusion"] = "Spell_Holy_PowerInfusion",
  ["Deterrence"] = "Ability_Whirlwind", ["Aspect of the Turtle"] = "Ability_Hunter_Pet_Turtle",
  ["Camouflage"] = "Ability_Hunter_Camouflage", ["Aspect of the Pack"] = "Ability_Mount_WhiteTiger",
  ["Aspect of the Cheetah"] = "Ability_Mount_JungleTiger", ["Feign Death"] = "Ability_Rogue_FeignDeath",
  ["Lichborne"] = "Spell_Shadow_RaiseDead", ["Death's Advance"] = "Spell_Shadow_DemonicEmpathy",
  ["Cat Form"] = "Ability_Druid_CatForm", ["Bear Form"] = "Ability_Racial_BearForm",
  ["Dire Bear Form"] = "Ability_Racial_BearForm", ["Travel Form"] = "Ability_Druid_TravelForm",
  ["Moonkin Form"] = "Spell_Nature_ForceOfNature", ["Tree of Life"] = "Ability_Druid_TreeofLife",
  ["Prowl"] = "Ability_Ambush", ["Ghost Wolf"] = "Spell_Nature_SpiritWolf", ["Spirit Walk"] = "Ability_Tracking",
  ["Stealth"] = "Ability_Stealth", ["Shadow Dance"] = "Ability_Rogue_ShadowDance", ["Vanish"] = "Ability_Vanish",
  ["Soulburn"] = "Spell_Warlock_Soulburn", ["Burning Rush"] = "Ability_Deathwing_FierySpeed",
  ["Metamorphosis"] = "Spell_Shadow_DemonForm", ["Zen Meditation"] = "Ability_Monk_ZenMeditation",
  ["Fortifying Brew"] = "Ability_Monk_FortifyingAle_New", ["Netherwalk"] = "Spell_Warlock_DemonSoul",
  ["Hover"] = "Ability_Evoker_Hover", ["Obsidian Scales"] = "Inv_Artifact_DragonScales",
  ["Shadowmeld"] = "Ability_Ambush",
}
