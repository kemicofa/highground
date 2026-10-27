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
  target = { label = "Target", phrase = "your target", tip = "Target", about = "Your current target" },
  focus = { label = "Focus", short = "F", phrase = "your focus", tip = "Focus", about = "Your focus target" },
  mouseover = { label = "Mouseover", short = "MO", phrase = "the unit under your mouse", tip = "Mouseover",
    about = "The unit under your mouse, on a nameplate, frame or in the world" },
  cursor = { label = "Cursor", phrase = "the ground at your cursor", tip = "Cursor",
    about = "The ground at your cursor, no targeting circle" },
  player = { label = "Self", short = "Me", phrase = "yourself", tip = "Me", about = "Yourself" },
  pet = { label = "Pet", phrase = "your pet" },
  none = { label = "None", phrase = "nothing (you pick)" },
}
for i = 1, 5 do
  Config.UNITS["arena" .. i] = { label = "Arena " .. i, short = "A" .. i, phrase = "arena enemy " .. i,
    tip = "Arena " .. i, about = "Arena enemy " .. i
      .. (i == 1 and " (the first enemy on the arena frames)" or i > 3 and " (5v5 only)" or "") }
end
for i = 1, 4 do
  Config.UNITS["party" .. i] = { label = "Party " .. i, short = "P" .. i, phrase = "party member " .. i,
    tip = "Party " .. i, about = "Party member " .. i .. (i == 1 and " (the first under you on the party frames)" or "") }
end

-- Raid markers by number (/tm 1-8; 0 clears).
Config.MARKERS = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
-- Modifier keys ([mod:shift], reset=shift).
Config.MODS = { shift = "Shift", ctrl = "Ctrl", alt = "Alt" }
-- /castsequence reset= words: button label, phrase in explanations and
-- autocomplete hint.
Config.RESETS = {
  { key = "target", button = "New target", phrase = "a new target", hint = "new target" },
  { key = "combat", button = "Combat ends", phrase = "leaving combat", hint = "leaving combat" },
  { key = "shift", button = "Shift", phrase = "pressing it with Shift" },
  { key = "ctrl", button = "Ctrl", phrase = "pressing it with Ctrl" },
  { key = "alt", button = "Alt", phrase = "pressing it with Alt" },
}
-- Equipment slots by number (/use 13), as said in explanations.
Config.SLOTS = { ["1"] = "your head item", ["2"] = "your neck item", ["3"] = "your shoulder item",
  ["5"] = "your chest item", ["6"] = "your belt", ["7"] = "your legs item", ["8"] = "your boots",
  ["9"] = "your wrist item", ["10"] = "your gloves", ["11"] = "your first ring", ["12"] = "your second ring",
  ["13"] = "your top trinket", ["14"] = "your bottom trinket", ["15"] = "your cloak",
  ["16"] = "your main-hand item", ["17"] = "your off-hand item" }

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
Config.COMMAND_GAMES = {
  ping = { retail = true, forever = true }, pingspell = { retail = true, forever = true },
  pingitem = { retail = true, forever = true }, usetoy = { retail = true, forever = true },
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
Config.CONDITION_REMOVED = { talent = "removed in Dragonflight", pvptalent = "no longer exists" }
-- Conditions about the unit the spell lands on (the rest are about you).
Config.UNIT_CONDITIONS = { harm = true, help = true, exists = true, dead = true, party = true, raid = true }
-- Simple conditions in explanations (macros/Explain.lua); "not: " in
-- front when negated.
Config.CONDITION_WORDS = { group = "you are in a group", party = "it is in your party",
  raid = "it is in your raid", indoors = "you are indoors", outdoors = "you are outdoors",
  mounted = "you are mounted", swimming = "you are swimming", flying = "you are flying",
  resting = "you are resting" }

-- Unit tokens after @ or target= (each may end in "target": focustarget).
Config.UNIT_TOKENS = { target = true, player = true, focus = true, mouseover = true, pet = true, vehicle = true,
  cursor = true, none = true, softenemy = true, softfriend = true, softinteract = true, anyenemy = true,
  anyfriend = true, anyinteract = true }
Config.UNIT_PATTERNS = { "^party[1-4]$", "^partypet[1-4]$", "^raid%d+$", "^raidpet%d+$", "^arena[1-5]$",
  "^arenapet[1-5]$", "^boss[1-8]$", "^nameplate%d+$" }

-- Autocomplete (macros/Suggest.lua) ----------------------------------------
Config.COMMAND_HINTS = { cast = "cast a spell", use = "use an item or slot", stopcasting = "stop casting first",
  startattack = "start auto attack", cancelaura = "remove a buff", focus = "set focus", target = "target",
  castsequence = "spells in turn", petattack = "pet attacks", tm = "raid marker", click = "click a button" }
-- Units offered after @ and target=, in this order.
Config.SUGGEST_UNITS = { "target", "focus", "mouseover", "player", "cursor", "pet", "arena1", "arena2", "arena3",
  "party1", "party2", "targettarget", "focustarget", "none" }
-- Values after "name:" in [ ]; aliases share their condition's list.
Config.CONDITION_VALUES = {
  mod = { { text = "shift" }, { text = "ctrl" }, { text = "alt" } },
  btn = { { text = "1", hint = "left" }, { text = "2", hint = "right" }, { text = "3", hint = "middle" },
    { text = "4" }, { text = "5" } },
  stance = { { text = "0", hint = "no stance or form" }, { text = "1" }, { text = "2" }, { text = "3" }, { text = "4" },
    { text = "5" }, { text = "6" } },
  spec = { { text = "1" }, { text = "2" }, { text = "3" }, { text = "4" } },
  group = { { text = "party" }, { text = "raid" } },
}
Config.CONDITION_VALUES.modifier = Config.CONDITION_VALUES.mod
Config.CONDITION_VALUES.button = Config.CONDITION_VALUES.btn
Config.CONDITION_VALUES.form = Config.CONDITION_VALUES.stance
Config.DIRECTIVES = { { text = "showtooltip", hint = "icon and tooltip of a spell" },
  { text = "show", hint = "icon of a spell" } }

-- Buffs to /cancelaura (macros/Sources.lua) ---------------------------------
-- Buffs worth removing before a cast because they block or waste it:
-- { name, why } per class, then ones other players can put on you
-- (known = only if it is in your spellbook). Names may differ per game:
-- G(cata, retail, forever[, tbc]), as Macros.G in macros/General.lua.
local function G(cata, retail, forever, tbc)
  return { cata = cata, retail = retail, forever = forever, tbc = tbc }
end
Config.CLASS_BUFFS = {
  WARRIOR = { { "Bladestorm", "stops your other abilities" }, { G("Recklessness", "Recklessness", "Recklessness"), "drop it" } },
  PALADIN = { { "Divine Shield", "you can't attack under it" },
    { G("Hand of Protection", "Blessing of Protection", "Blessing of Protection"), "you can't attack under it" },
    { G(nil, "Blessing of Spellwarding"), "drop it" }, { G("Divine Plea"), "halves your healing" } },
  MAGE = { { "Ice Block", "blocks every action" }, { G(nil, "Alter Time"), "would snap you back" },
    { "Invisibility", "end it now" }, { G(nil, "Greater Invisibility"), "end it now" }, { G("Mage Ward", nil), "drop it" } },
  PRIEST = { { G("Dispersion", "Dispersion"), "blocks most spells" }, { G("Shadowform", "Shadowform", "Shadowform"), "lets you heal" },
    { G(nil, "Spirit of Redemption"), "end it" } },
  HUNTER = { { G("Deterrence", nil), "blocks attacking" }, { G(nil, "Aspect of the Turtle"), "blocks attacking" },
    { G(nil, "Camouflage"), "leave Camouflage" }, { G("Aspect of the Pack", nil, "Aspect of the Cheetah"), "dazed when hit" },
    { "Feign Death", "stand up" } },
  DEATHKNIGHT = { { "Lichborne", "turns heals into damage" }, { G(nil, "Death's Advance"), "drop it" } },
  DRUID = { { "Cat Form", "leave the form" }, { G("Bear Form", "Bear Form", "Dire Bear Form"), "leave the form" },
    { "Travel Form", "leave the form" }, { G("Moonkin Form", "Moonkin Form", "Moonkin Form"), "leave the form" },
    { G("Tree of Life", nil), "leave the form" }, { "Prowl", "leave stealth" } },
  SHAMAN = { { "Ghost Wolf", "leave the form" }, { G(nil, "Spirit Walk"), "drop it" } },
  ROGUE = { { "Stealth", "leave stealth" }, { G(nil, "Shadow Dance"), "leave it out of combat" }, { "Vanish", "leave stealth" } },
  WARLOCK = { { G("Soulburn", nil), "drop an unused Soulburn" }, { G(nil, "Burning Rush"), "it drains your health" },
    { G("Metamorphosis", nil), "leave the form" } },
  MONK = { { "Zen Meditation", "would cancel itself" }, { "Fortifying Brew", "drop it" } },
  DEMONHUNTER = { { "Netherwalk", "blocks attacking" }, { "Metamorphosis", "leave it" } },
  EVOKER = { { "Hover", "stop hovering" }, { "Obsidian Scales", "drop it" } },
}
Config.OTHERS_BUFFS = {
  { G("Hand of Protection", "Blessing of Protection", "Blessing of Protection"), "a paladin's: you can't attack" },
  { G(nil, "Blessing of Spellwarding"), "a paladin's: drop it" },
  { G(nil, nil, "Divine Intervention"), "a paladin's: you can't act" },
  { G("Hand of Salvation", nil, "Blessing of Salvation"), "a paladin's: no threat" },
  { G(nil, "Power Infusion"), "a priest's: drop it" },
  { "Shadowmeld", "racial: leave it", known = true }, -- Night Elves only
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
