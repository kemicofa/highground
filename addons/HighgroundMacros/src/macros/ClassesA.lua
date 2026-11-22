local _, ns = ...
local Macros = ns.Macros
local G, Enemy, Ally, Self, Cursor, Raw = Macros.G, Macros.Enemy, Macros.Ally, Macros.Self, Macros.Cursor, Macros.Raw
local CataRetail, NotRetail = Macros.CataRetail, Macros.NotRetail
local FOREVER = Macros.FOREVER

-- Class macros, part one. Spell names per game:
-- G(cata, retail, forever[, tbc[, classic]]), CataRetail(x) or NotRetail(x)
-- (macros/General.lua). Retail follows
-- Skill-Capped's Midnight PvP macro pages; Forever uses vanilla spells,
-- Cataclysm its 4.4 spells, stances included where a game requires them.
local BLADESTORM = CataRetail("Bladestorm")
local BATTLE = NotRetail({ 1, "Battle Stance" })
local BERSERKER = NotRetail({ 3, "Berserker Stance" })

Macros.Add("WARRIOR", {
  Enemy("Pummel", "Interrupt your focus or target", "Pummel",
    { cancel = BLADESTORM, stance = G(nil, nil, { 3, "Berserker Stance" }) }),
  Enemy("Shield Bash", "Interrupt with a shield on", G(nil, nil, "Shield Bash"),
    { stance = G(nil, nil, { "1/2", "Defensive Stance" }) }),
  Enemy("Charge", "Charge and start attacking", "Charge", { cancel = BLADESTORM, startattack = true, stance = BATTLE }),
  Enemy("Intercept", "Intercept from any stance", NotRetail("Intercept"), { startattack = true, stance = BERSERKER }),
  Enemy("Storm Bolt", "Stun", G(nil, "Storm Bolt"), { cancel = BLADESTORM }),
  Enemy("Intim Shout", "Fear around your focus or target", "Intimidating Shout", { cancel = BLADESTORM, stopattack = true }),
  Enemy("Disarm", "Disarm a melee", NotRetail("Disarm"), { stance = NotRetail({ 2, "Defensive Stance" }) }),
  Enemy("Shattering", "Break an immunity or shield", CataRetail("Shattering Throw"),
    { stance = G({ 1, "Battle Stance" }) }),
  Raw("Gap Closer", "Charge out of combat, Intercept in combat",
    NotRetail("#showtooltip [nocombat] Charge; Intercept\n"
      .. "/cast [nocombat,nostance:1] Battle Stance; [combat,nostance:3] Berserker Stance\n/cast [nocombat] Charge; Intercept"),
    { needs = { "Charge", NotRetail("Intercept") } }),
  Ally("Intervene", "Jump to an ally and protect them", CataRetail("Intervene"),
    { self = false, stance = G({ 2, "Defensive Stance" }) }),
  Cursor("Heroic Leap", "Leap to your cursor", CataRetail("Heroic Leap")),
  Self("Spell Reflect", "Reflect the next spell", CataRetail("Spell Reflection")),
  Self("Berserker Rage", "Break or prevent fear", "Berserker Rage", { stance = G(nil, nil, { 3, "Berserker Stance" }) }),
  Self("Mortal Strike", "Mortal Strike, keep auto attacking", "Mortal Strike", { startattack = true }),
  Self("Hamstring", "Snare, keep auto attacking", "Hamstring", { startattack = true }),
  Self("Overpower", "Overpower from any stance", NotRetail("Overpower"), { startattack = true, stance = BATTLE }),
  Self("Victory Rush", "Heal after a kill, keep auto attacking", G(nil, nil, "Victory Rush", nil, false), { startattack = true }),
  Enemy("Spearing Strike", "Dismount a rider", "Spearing Strike", { startattack = true, games = FOREVER }),
  Enemy("Concussion", "Concussion Blow: stun", G(nil, nil, "Concussion Blow")),
  Self("Death Wish", "Trinkets, then Death Wish", G(nil, nil, "Death Wish"), { uses = { "13", "14" }, mode = "both" }),
})

Macros.Add("PALADIN", {
  Enemy("HoJ", "Hammer of Justice: stun", "Hammer of Justice"),
  Enemy("Rebuke", "Interrupt", CataRetail("Rebuke")),
  Enemy("Repentance", "Incapacitate; stops auto attack so it holds", "Repentance", { stopattack = true }),
  Ally("Freedom", "Remove roots and snares", G("Hand of Freedom", "Blessing of Freedom", "Blessing of Freedom")),
  Ally("BoP", "Physical immunity on an ally", G("Hand of Protection", "Blessing of Protection", "Blessing of Protection")),
  Ally("Sacrifice", "Take damage for an ally, break their CC", G("Hand of Sacrifice", "Blessing of Sacrifice", "Blessing of Sacrifice"),
    { self = false }),
  Ally("Spellwarding", "Magic immunity on an ally", G(nil, "Blessing of Spellwarding")),
  Ally("Sanctuary", "Free an ally from crowd control", G(nil, "Blessing of Sanctuary")),
  Ally("Cleanse", "Dispel an ally", "Cleanse"),
  Ally("Cleanse Toxins", "Retribution: remove poison and disease", G(nil, "Cleanse Toxins")),
  Ally("Lay on Hands", "Emergency heal", "Lay on Hands"),
  Ally("Word of Glory", "Instant heal", CataRetail("Word of Glory")),
  Ally("Flash of Light", "Quick heal", "Flash of Light"),
  Self("Holy Shock", "Heal an ally or hit an enemy under your mouse", "Holy Shock",
    { target = "mouseover", kind = "any", fallback = true }),
  Self("Divine Shield", "Bubble; press again to cancel it", "Divine Shield", { toggle = true, stopcast = true }),
  Self("Crusader Strike", "Crusader Strike, keep auto attacking", CataRetail("Crusader Strike"), { startattack = true }),
  Self("Holy Strike", "Holy Strike, keep auto attacking", "Holy Strike", { startattack = true, games = FOREVER, mode = "both" }),
  Raw("Favor Shock", "Divine Favor, then a critical Holy Shock",
    G(nil, nil, "#showtooltip Divine Favor\n/cast Divine Favor\n/cast [@mouseover,help,nodead][@target,help,nodead][@player] Holy Shock"),
    { needs = { "Divine Favor", "Holy Shock" }, mode = "both" }),
  Self("Bulwark", "Templar's Bulwark: absorb shield; stops casting first", "Templar's Bulwark",
    { stopcast = true, games = FOREVER, mode = "both" }),
  Ally("Oath of Light", "Oath of Light on an ally", "Oath of Light", { games = FOREVER, mode = "both" }),
  Ally("Light's Vigil", "Next Holy Shock on them: no cooldown, party heal", "Light's Vigil", { games = FOREVER, mode = "both" }),
})

local FREEZE = G("#showtooltip Freezing Trap\n/cast Trap Launcher\n/cast [@cursor] Freezing Trap",
  "#showtooltip\n/cast [@cursor] Freezing Trap", "#showtooltip\n/cast Freezing Trap")
local PET = "#showtooltip\n/cast [@pet,dead] Revive Pet; [nopet] %s; Mend Pet"
Macros.Add("HUNTER", {
  Enemy("Interrupt", "Silencing Shot / Counter Shot", G("Silencing Shot", "Counter Shot")),
  Enemy("Muzzle", "Survival: melee interrupt", G(nil, "Muzzle")),
  Enemy("Scatter Shot", "Disorient; stops auto attack so it holds", "Scatter Shot", { stopattack = true }),
  -- Forever removed Wyvern Sting (Resourcefulness); Classic Era and TBC keep it.
  Enemy("Wyvern Sting", "Sleep; stops auto attack so it holds", G("Wyvern Sting", nil, false, "Wyvern Sting", "Wyvern Sting"),
    { stopattack = true }),
  Enemy("Viper Sting", "Drain a caster's mana", G(nil, nil, "Viper Sting")),
  Enemy("Concussive", "Slow", "Concussive Shot"),
  Enemy("Tranq Shot", "Remove a buff or enrage", "Tranquilizing Shot"),
  -- Retail stuns your target; earlier games buff the pet, whose next hit stuns.
  Enemy("Intimidation", "Pet stun on your focus or target", G(nil, "Intimidation")),
  Self("Intimidation", "Your pet's next attack stuns", NotRetail("Intimidation")),
  Raw("Freezing Trap", "Trap: launched on Cata, at your cursor on Retail", FREEZE,
    { needs = { "Freezing Trap", G("Trap Launcher") } }),
  -- Forever: traps work in combat and share one cooldown.
  Raw("Trap Peel", "Freezing Trap; Shift: Frost Trap", "#showtooltip\n/stopattack\n/cast [mod:shift] Frost Trap; Freezing Trap",
    { needs = { "Freezing Trap", "Frost Trap" }, games = FOREVER }),
  Cursor("Ench. Flare", "Enchanted Flare: reveal stealth at your cursor", "Enchanted Flare", { games = FOREVER }),
  Enemy("Summon Hawk", "Hawks attack your focus or target", "Summon Hawk", { games = FOREVER, mode = "both" }),
  Self("Lacerate", "Lacerate; you and your pet attack", "Lacerate", { startattack = true, petDo = "attack", games = FOREVER }),
  Self("Strider Kick", "Strider Kick; you and your pet attack", "Strider Kick",
    { startattack = true, petDo = "attack", games = FOREVER }),
  Raw("SV Melee", "Counterattack or Mongoose Bite, else Raptor Strike",
    G(nil, nil, "#showtooltip\n/startattack\n/cast Counterattack\n/cast Mongoose Bite\n/cast Raptor Strike"),
    { needs = { "Mongoose Bite", "Raptor Strike" }, mode = "both" }),
  Raw("Lone Wolf", "Dismiss your pet, or call it back", "#showtooltip\n/cast [pet] Dismiss Pet; Call Pet",
    { needs = { "Dismiss Pet", "Call Pet" }, games = FOREVER, mode = "both" }),
  Cursor("Binding Shot", "Root zone at your cursor", G(nil, "Binding Shot")),
  Cursor("Tar Trap", "Slow zone at your cursor", G(nil, "Tar Trap")),
  Cursor("Flare", "Reveal stealth at your cursor", "Flare"),
  Ally("Master's Call", "Free an ally from roots and snares", CataRetail("Master's Call"), { pet = true }),
  Ally("Roar of Sac", "Pet: protect an ally from crits", G(nil, "Roar of Sacrifice"), { pet = true }),
  Raw("Kill Command", "Send your pet and Kill Command", "#showtooltip Kill Command\n/petattack\n/cast Kill Command",
    { games = { cata = true, retail = true }, needs = { "Kill Command" } }),
  Raw("Feign Death", "Drop combat: stop attacking, pet follows", "#showtooltip Feign Death\n/stopattack\n/petfollow\n/cast Feign Death",
    { needs = { "Feign Death" }, mode = "both" }),
  Self("Disengage", "Leap back", CataRetail("Disengage")),
  Ally("Misdirection", "Redirect threat to an ally or your pet", G("Misdirection", "Misdirection", nil, "Misdirection"), { self = false }),
  Raw("Pet", "Revive, call or mend your pet", G(PET:format("Call Pet 1"), PET:format("Call Pet 1"), PET:format("Call Pet")),
    { needs = { "Mend Pet" } }),
})

Macros.Add("ROGUE", {
  Enemy("Kick", "Interrupt", "Kick"),
  Enemy("Sap", "Sap your focus or target", "Sap", { stopattack = true }),
  Enemy("Blind", "Blind; stops auto attack so it holds", "Blind", { stopattack = true }),
  Enemy("Gouge", "Incapacitate; stops auto attack so it holds", "Gouge", { stopattack = true }),
  -- No /startattack: without the energy, the first swing breaks stealth.
  Enemy("Cheap Shot", "Stealth stun opener", "Cheap Shot"),
  Enemy("Kidney Shot", "Stun", "Kidney Shot", { startattack = true }),
  Enemy("Shadowstep", "Teleport behind", G("Shadowstep", "Shadowstep", nil, "Shadowstep")),
  Enemy("Dismantle", "Disarm", CataRetail("Dismantle")),
  Ally("Tricks", "Tricks of the Trade on an ally", CataRetail("Tricks of the Trade"), { self = false }),
  Raw("Vanish", "Stop attacking, then Vanish", "#showtooltip Vanish\n/stopattack\n/cast Vanish", { needs = { "Vanish" } }),
  Self("Stealth", "Stealth without toggling it off", "Stealth", { force = true }),
  Raw("Cold Blood", "Guaranteed critical Eviscerate", NotRetail("#showtooltip Cold Blood\n/cast Cold Blood\n/cast Eviscerate"),
    { needs = { "Cold Blood", "Eviscerate" } }),
  Raw("Premed Opener", "Premeditation, then Cheap Shot",
    G(nil, nil, "#showtooltip Premeditation\n/cast Premeditation\n/cast Cheap Shot"), { needs = { "Premeditation", "Cheap Shot" } }),
  -- Forever: Ghostly Strike lets the next Ambush skip Stealth.
  Raw("Ghostly Ambush", "Ghostly Strike; Ctrl or in Stealth: Ambush", "#showtooltip\n/cast [stealth][mod:ctrl] Ambush; Ghostly Strike",
    { needs = { "Ghostly Strike", "Ambush" }, games = FOREVER }),
  Self("Shank", "Off-hand strike that refunds Energy", "Shank", { startattack = true, games = FOREVER }),
  Self("Mutilate", "Mutilate, keep auto attacking", G(nil, nil, "Mutilate", "Mutilate", false), { startattack = true }),
  Self("Death Mark", "Finisher: stored damage bursts after 6 sec", "Death Mark", { startattack = true, games = FOREVER }),
  Cursor("Distract", "Distract at your cursor; lowers stealth detection", G(nil, nil, "Distract"), { games = FOREVER }),
})

Macros.Add("PRIEST", {
  Enemy("Silence", "Silence: stops casting first", "Silence", { stopcast = true }),
  Enemy("Chastise", "Holy Word: Chastise / Dwarf: root a humanoid", G(nil, "Holy Word: Chastise", "Chastise", nil, false)),
  Enemy("Mind Control", "Mind Control", "Mind Control"),
  Enemy("Psychic Horror", "Horrify", CataRetail("Psychic Horror")),
  Enemy("Mana Burn", "Burn a healer's mana", G(nil, nil, "Mana Burn")),
  Enemy("SW:Death", "Shadow Word: Death; stops casting first",
    G("Shadow Word: Death", "Shadow Word: Death", "Shadow Word: Death", nil, false), { stopcast = true }),
  Raw("IF Mana Burn", "Inner Focus, then a free Mana Burn on your focus",
    G(nil, nil, "#showtooltip Inner Focus\n/cast Inner Focus\n/cast [@focus,harm,nodead][] Mana Burn"),
    { needs = { "Inner Focus", "Mana Burn" } }),
  -- Retail Dispel Magic only purges enemies (Purge preset); Cata dispels friends with Absolution (Discipline, Holy).
  Self("Dispel MO", "Dispel an ally or purge an enemy under your mouse", NotRetail("Dispel Magic"),
    { target = "mouseover", kind = "any", fallback = true }),
  Self("Penance", "Heal an ally or hit an enemy under your mouse", "Penance",
    { target = "mouseover", kind = "any", fallback = true, games = FOREVER }),
  Enemy("Purge", "Purge your focus or target", G(nil, "Dispel Magic")),
  Ally("Purify", "Dispel an ally", G(nil, "Purify")),
  Self("Psychic Scream", "Fear around you; stops casting first", "Psychic Scream", { stopcast = true }),
  Cursor("Mass Dispel", "Mass Dispel at your cursor", G("Mass Dispel", "Mass Dispel", nil, "Mass Dispel")),
  Ally("Leap of Faith", "Pull an ally to you", CataRetail("Leap of Faith"), { self = false }),
  Ally("Pain Supp", "Pain Suppression", G("Pain Suppression", "Pain Suppression", nil, "Pain Suppression")),
  Ally("Guardian Spirit", "Guardian Spirit", CataRetail("Guardian Spirit")),
  Ally("PW:S", "Power Word: Shield", "Power Word: Shield"),
  Ally("Power Infusion", "Power Infusion", "Power Infusion"),
  Ally("Fear Ward", "Fear immunity on an ally", NotRetail("Fear Ward")),
  Ally("Flash Heal", "Quick heal", "Flash Heal"),
  Ally("Divine Grace", "Human: big heal on an ally", "Divine Grace", { self = false, games = FOREVER }),
  Self("Confounding", "Gnome: Confounding Flash; stops casting first", "Confounding Flash",
    { stopcast = true, games = FOREVER }),
})

Macros.Add("DEATHKNIGHT", {
  Enemy("Mind Freeze", "Interrupt", "Mind Freeze"),
  Enemy("Strangulate", "Silence", "Strangulate"),
  Enemy("Asphyxiate", "Stun", G(nil, "Asphyxiate")),
  Enemy("Death Grip", "Pull your focus or target", "Death Grip"),
  Enemy("Chains of Ice", "Slow", "Chains of Ice"),
  Enemy("Dark Sim", "Steal a spell", "Dark Simulacrum"),
  Enemy("Gnaw", "Pet stun", "Gnaw", { pet = true }),
  Self("AMS", "Anti-Magic Shell", "Anti-Magic Shell"),
  Cursor("Death and Decay", "Death and Decay at your cursor", "Death and Decay"),
})
