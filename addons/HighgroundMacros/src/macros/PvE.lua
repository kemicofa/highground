local _, ns = ...
local Macros = ns.Macros
local G, Focus, Mouseover, Ally, Self, Cursor, Raw = Macros.G, Macros.Focus, Macros.Mouseover, Macros.Ally, Macros.Self,
  Macros.Cursor, Macros.Raw
local CataRetail, NotRetail = Macros.CataRetail, Macros.NotRetail

-- PvE presets: interrupts and crowd control on your focus, taunts and dots
-- on the enemy under your mouse, heals and dispels on mouseover or party.
-- Spell names per game as in macros/ClassesA.lua. Spells without a rank
-- cast your highest rank.
local PVE = "pve"
local FOREVER = Macros.FOREVER
local DEFENSIVE = G(nil, nil, { 2, "Defensive Stance" })
local DROP_TOTEMS = Macros.DROP_TOTEMS

Macros.Add(nil, {
  { name = "Mark Skull MO", desc = "Skull on the enemy under your mouse, or your target",
    lines = "/tm [@mouseover,exists,nodead][] 8" },
  { name = "Mark Cross MO", desc = "Cross on the enemy under your mouse, or your target",
    lines = "/tm [@mouseover,exists,nodead][] 7" },
  { name = "Mark Moon MO", desc = "Moon (crowd control) on your mouseover or target",
    lines = "/tm [@mouseover,exists,nodead][] 5" },
  { name = "Clear Mark", desc = "Remove the raid marker from your target", lines = "/tm 0" },
  { name = "Assist Focus", desc = "Target what your focus (the tank) is attacking", lines = "/assist [@focus,exists,nodead]" },
  { name = "Ready Check", desc = "Start a ready check", lines = "/readycheck" },
  { name = "Pull Timer", desc = "Ten-second pull countdown for the group", lines = "/countdown 10" },
}, PVE)

Macros.Add("WARRIOR", {
  Focus("Pummel", "Interrupt your focus or target", "Pummel", { stance = G(nil, nil, { 3, "Berserker Stance" }) }),
  Focus("Shield Bash", "Interrupt with a shield on", G(nil, nil, "Shield Bash"), { stance = G(nil, nil, { "1/2", "Defensive Stance" }) }),
  Mouseover("Taunt", "Taunt the enemy under your mouse, or your target", "Taunt", { stance = DEFENSIVE }),
  Mouseover("Mocking Blow", "Second taunt, from Battle Stance", G(nil, nil, "Mocking Blow"), { stance = G(nil, nil, { 1, "Battle Stance" }) }),
  Self("Challenging", "Challenging Shout: taunt everything around you", "Challenging Shout"),
  Self("Heroic Strike", "Queue Heroic Strike, keep auto attacking", NotRetail("Heroic Strike"), { startattack = true }),
  Self("Sunder Armor", "Sunder Armor, keep auto attacking", NotRetail("Sunder Armor"), { startattack = true }),
  Ally("Intervene", "Protect the ally under your mouse", CataRetail("Intervene"), { self = false }),
  Self("Shield Wall", "Shield Wall", "Shield Wall", { stance = DEFENSIVE }),
  -- Forever: Vanguard charges and Thunder Clap work in Defensive Stance.
  Self("Tank Charge", "Vanguard: Charge from Defensive Stance", "Charge",
    { startattack = true, stance = { "1/2", "Defensive Stance" }, games = FOREVER }),
  Self("Thunder Clap", "Thunder Clap from Battle or Defensive Stance", "Thunder Clap",
    { stance = { "1/2", "Defensive Stance" }, games = FOREVER }),
  Self("Victory Rush", "Heal after a kill, keep auto attacking", G(nil, nil, "Victory Rush", nil, false), { startattack = true }),
}, PVE)

Macros.Add("PALADIN", {
  Focus("Rebuke", "Interrupt your focus or target", CataRetail("Rebuke")),
  Mouseover("Taunt", "Hand of Reckoning on the enemy under your mouse", CataRetail("Hand of Reckoning")),
  -- Forever: Judgement with Seal of Fury active taunts.
  Mouseover("Fury Taunt", "Seal of Fury: Judgement taunts under your mouse", "Judgement", { games = FOREVER }),
  Ally("Flash of Light", "Quick heal", "Flash of Light"),
  Ally("Holy Light", "Big heal", "Holy Light"),
  Ally("Holy Shock", "Instant heal", "Holy Shock"),
  Ally("Word of Glory", "Instant heal", CataRetail("Word of Glory")),
  Ally("Beacon", "Beacon of Light", CataRetail("Beacon of Light")),
  Ally("Cleanse", "Dispel an ally", "Cleanse"),
  Ally("Lay on Hands", "Emergency heal", "Lay on Hands"),
  Ally("BoP", "Physical immunity on an ally", G("Hand of Protection", "Blessing of Protection", "Blessing of Protection")),
  Focus("Turn Evil", "Fear an undead", G("Turn Evil", "Turn Evil", "Turn Undead")),
}, PVE)

Macros.Add("HUNTER", {
  Focus("Interrupt", "Counter Shot / Silencing Shot", G("Silencing Shot", "Counter Shot")),
  { name = "MD Tank", desc = "Misdirection on your focus (the tank), else your pet",
    lines = "#showtooltip\n/cast [@focus,help,nodead][@pet,exists,nodead] Misdirection", needs = { "Misdirection" },
    games = { cata = true, retail = true, tbc = true } },
  Mouseover("Hunter's Mark", "Mark the enemy under your mouse", "Hunter's Mark"),
  Focus("Tranq Shot", "Remove an enrage", "Tranquilizing Shot"),
  Self("Auto Shot", "Start Auto Shot without toggling it off", NotRetail("Auto Shot"), { force = true }),
  { name = "Pet Growl", desc = "Turn your pet's Growl on or off (off in groups)", lines = "/petautocasttoggle Growl" },
}, PVE)

Macros.Add("ROGUE", {
  Focus("Kick", "Interrupt your focus or target", "Kick"),
  Mouseover("Sap", "Sap the enemy under your mouse before the pull", "Sap", { stopattack = true }),
  { name = "Tricks Tank", desc = "Tricks of the Trade on your focus (the tank)",
    lines = "#showtooltip\n/cast [@focus,help,nodead][@target,help,nodead] Tricks of the Trade",
    needs = { "Tricks of the Trade" }, games = { cata = true, retail = true } },
  Self("Sinister Strike", "Sinister Strike, keep auto attacking", "Sinister Strike", { startattack = true }),
  Self("Feint", "Lower your threat", "Feint"),
  Cursor("Distract", "Distract at your cursor", "Distract"),
  Self("Blade Flurry", "Blade Flurry; press again to cancel it", G(nil, nil, "Blade Flurry"), { toggle = true }),
  Self("Adrenaline", "Trinkets, then Adrenaline Rush", G(nil, nil, "Adrenaline Rush"), { uses = { "13", "14" } }),
}, PVE)

Macros.Add("PRIEST", {
  Ally("Flash Heal", "Quick heal", "Flash Heal"),
  Ally("Big Heal", "Greater Heal", NotRetail("Greater Heal")),
  Ally("Renew", "Heal over time", NotRetail("Renew")),
  Ally("PW:S", "Power Word: Shield", "Power Word: Shield"),
  Ally("Mending", "Prayer of Mending", G("Prayer of Mending", "Prayer of Mending", "Prayer of Mending", "Prayer of Mending", false)),
  Ally("Dispel", "Dispel an ally (Cata: Discipline or Holy)", G("Dispel Magic", "Purify", "Dispel Magic")),
  Ally("Cure Disease", "Remove a disease", NotRetail("Cure Disease")),
  Ally("Power Infusion", "Power Infusion", "Power Infusion", { self = false }),
  Mouseover("SW:Pain", "Shadow Word: Pain on the enemy under your mouse", "Shadow Word: Pain"),
  Mouseover("Plague", "Devouring Plague on the enemy under your mouse", G(nil, nil, "Devouring Plague")),
  Ally("Penance", "Penance: channelled heal", "Penance", { games = FOREVER }),
  Raw("IF Heal", "Inner Focus, then a free Greater Heal",
    "#showtooltip Inner Focus\n/cast Inner Focus\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Greater Heal",
    { needs = { "Inner Focus", "Greater Heal" }, games = FOREVER }),
  Focus("Shackle", "Shackle Undead (Retail: Shackle Horror) on your focus", G("Shackle Undead", "Shackle Horror", "Shackle Undead")),
  Self("Fade", "Drop threat", "Fade"),
}, PVE)

Macros.Add("DEATHKNIGHT", {
  Focus("Mind Freeze", "Interrupt your focus or target", "Mind Freeze"),
  Mouseover("Dark Command", "Taunt the enemy under your mouse", "Dark Command"),
  Mouseover("Death Grip", "Pull the enemy under your mouse", "Death Grip"),
  { name = "Raise Ally", desc = "Battle res the dead ally under your mouse",
    lines = "#showtooltip\n/cast [@mouseover,help,dead][@target,help,dead] Raise Ally", needs = { "Raise Ally" } },
  Cursor("Death and Decay", "Death and Decay at your cursor", "Death and Decay"),
  Self("Icebound", "Icebound Fortitude", "Icebound Fortitude"),
}, PVE)

Macros.Add("SHAMAN", {
  Focus("Interrupt", "Wind Shear / Earth Shock; stops casting first", G("Wind Shear", "Wind Shear", "Earth Shock"),
    { stopcast = true }),
  Ally("Healing Wave", "Healing Wave", "Healing Wave"),
  Ally("Quick Heal", "Healing Surge (not Restoration on Retail) / Lesser Healing Wave", G("Healing Surge", "Healing Surge", "Lesser Healing Wave")),
  Ally("Chain Heal", "Chain Heal", "Chain Heal"),
  Ally("Riptide", "Riptide", G("Riptide", "Riptide", "Riptide", false, false)),
  Ally("Earth Shield", "Earth Shield", G("Earth Shield", "Earth Shield", nil, "Earth Shield"), { self = false }),
  Ally("Dispel", "Dispel an ally (vanilla: a poison)", G("Cleanse Spirit", "Purify Spirit", "Cure Poison")),
  Ally("Cure Disease", "Remove a disease", G(nil, nil, "Cure Disease")),
  Mouseover("Flame Shock", "Flame Shock on the enemy under your mouse", "Flame Shock"),
  Focus("Purge", "Remove a buff from your focus or target", "Purge"),
  Self("Tremor", "Tremor Totem: break fear", "Tremor Totem", { games = DROP_TOTEMS }),
  Self("Totem Set", "Call of the Elements: drop your Totem Bar set", "Call of the Elements", { games = FOREVER }),
}, PVE)

Macros.Add("MAGE", {
  Focus("Counterspell", "Interrupt; stops casting first", "Counterspell", { stopcast = true }),
  Focus("Polymorph", "Polymorph your focus (crowd control)", "Polymorph"),
  Mouseover("Spellsteal", "Steal a buff", G("Spellsteal", "Spellsteal", nil, "Spellsteal")),
  Ally("Remove Curse", "Remove a curse", G("Remove Curse", "Remove Curse", "Remove Lesser Curse")),
  Ally("Focus Magic", "Focus Magic on an ally", G("Focus Magic"), { self = false }),
  Ally("Intellect", "Arcane Intellect (Cata: Arcane Brilliance)", G("Arcane Brilliance", "Arcane Intellect", "Arcane Intellect")),
}, PVE)

Macros.Add("WARLOCK", {
  Focus("Banish", "Banish your focus (crowd control)", "Banish"),
  Focus("Fear", "Fear your focus", "Fear"),
  Mouseover("Corruption", "Corruption on the enemy under your mouse", "Corruption"),
  -- Forever renamed Curse of Agony to Bane of Agony; Classic Era and TBC keep the curse.
  Mouseover("Agony", "Agony on the enemy under your mouse",
    G("Bane of Agony", "Agony", "Bane of Agony", "Curse of Agony", "Curse of Agony")),
  Mouseover("Elements", "Curse of the Elements on the enemy under your mouse", NotRetail("Curse of the Elements")),
  Focus("Spell Lock", "Felhunter interrupt on your focus", NotRetail("Spell Lock"), { pet = true }),
  Ally("Soulstone", "Soulstone on an ally", G(nil, "Soulstone")),
  -- Cataclysm: Soulstone is an item (made by Create Soulstone), used on an ally.
  Ally("Soulstone", "Use your Soulstone on an ally", "Soulstone", { verb = "use", games = { cata = true } }),
  Focus("Subjugate", "Subjugate (Enslave) a demon",
    G("Subjugate Demon", nil, "Subjugate Demon", "Subjugate Demon", "Enslave Demon")),
  Focus("Bane of Havoc", "Havoc on your focus while you hit your target", "Bane of Havoc", { games = FOREVER }),
}, PVE)

local BEAR = Macros.BEAR
Macros.Add("DRUID", {
  Focus("Skull Bash", "Interrupt your focus or target", CataRetail("Skull Bash")),
  Mouseover("Growl", "Taunt the enemy under your mouse", "Growl", { stance = BEAR }),
  Ally("Rejuvenation", "Heal over time", "Rejuvenation"),
  Ally("Regrowth", "Quick heal", "Regrowth"),
  Ally("Healing Touch", "Big heal", NotRetail("Healing Touch")),
  Ally("Lifebloom", "Lifebloom", G("Lifebloom", "Lifebloom", nil, "Lifebloom")),
  Ally("Swiftmend", "Swiftmend", "Swiftmend"),
  Ally("Innervate", "Innervate", "Innervate"),
  Ally("Decurse", "Remove a curse", G("Remove Corruption", "Remove Corruption", "Remove Curse")),
  { name = "Battle Res", desc = "Rebirth the dead ally under your mouse",
    lines = "#showtooltip\n/cast [@mouseover,help,dead][@target,help,dead] Rebirth", needs = { "Rebirth" } },
  Mouseover("Moonfire", "Moonfire on the enemy under your mouse", "Moonfire"),
  Focus("Hibernate", "Sleep a beast or dragonkin", "Hibernate"),
  Self("Primal Bite", "Primal Bite in Bear Form", "Primal Bite", { startattack = true, stance = BEAR, games = FOREVER }),
  Self("Lacerate", "Lacerate in Bear Form", G(nil, nil, "Lacerate", "Lacerate", false), { startattack = true, stance = BEAR }),
  -- Forever: Revive brings allies back out of combat.
  { name = "Druid Res", desc = "Rebirth in combat, else Revive (mouseover)",
    lines = "#showtooltip\n/cancelform [@mouseover,help,dead][help,dead]\n"
      .. "/cast [combat,@mouseover,help,dead][combat,help,dead] Rebirth; [@mouseover,help,dead][help,dead] Revive",
    needs = { "Rebirth", "Revive" }, games = FOREVER },
}, PVE)

Macros.Add("MONK", {
  Focus("Spear Hand", "Interrupt your focus or target", "Spear Hand Strike"),
  Mouseover("Provoke", "Taunt the enemy under your mouse", "Provoke"),
  Ally("Vivify", "Heal", "Vivify"),
  Ally("Enveloping Mist", "Heal over time", "Enveloping Mist"),
  Ally("Renewing Mist", "Heal over time", "Renewing Mist"),
  Ally("Detox", "Dispel an ally", "Detox"),
  Ally("Life Cocoon", "Absorb shield", "Life Cocoon"),
}, PVE)

Macros.Add("DEMONHUNTER", {
  Focus("Disrupt", "Interrupt your focus or target", "Disrupt"),
  Mouseover("Torment", "Taunt the enemy under your mouse", "Torment"),
  Focus("Imprison", "Imprison your focus", "Imprison"),
  Cursor("Sigil of Flame", "Sigil of Flame at your cursor", "Sigil of Flame"),
  Cursor("Infernal Strike", "Infernal Strike to your cursor", "Infernal Strike"),
}, PVE)

Macros.Add("EVOKER", {
  Focus("Quell", "Interrupt your focus or target", "Quell"),
  Ally("Echo", "Echo on an ally", "Echo"),
  Ally("Reversion", "Heal over time", "Reversion"),
  Ally("Naturalize", "Dispel an ally", "Naturalize"),
  Ally("Verdant Embrace", "Fly to an ally and heal, or heal yourself", "Verdant Embrace"),
  Ally("Rescue", "Fly an ally to safety", "Rescue", { self = false }),
}, PVE)
