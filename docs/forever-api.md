# WoW Forever API findings

What addons can and can't read in a WoW Forever battleground, measured on a live client, and leads still to test. WoW Forever runs the Midnight client (interface 16001), so most findings likely apply to Retail too; Retail has not been checked live.

Measured on 2026-11-23/24, build `1.60.1 (71037) 16001`, in Darkspear Islands and Warsong Gulch, with three tools:

- `/hg bg profiler start` (Highground): records a match into `HighgroundDB.bgProfiles`.
- One-line `/run` probes typed in chat. Chat input stops at 255 characters; a longer line fails silently unless `/console scriptErrors 1` is on.
- The [API probe](../tools/apiprobe/README.md), a developer-only addon in this repository.

Blizzard can change any of this in a hotfix. Re-check before relying on a gap, and degrade quietly when a value turns secret or nil.

## Secret values

Enemy health, power, auras and casts come back as *secret values*. Addon code can hold one, store it in a table field and pass it to display widgets, but not compare it, do arithmetic on it or save it. `issecretvalue(v)` tells them apart.

| Operation on a secret | Result |
| --- | --- |
| `type(v)` | `"number"` (the underlying type) |
| `v .. "%"` | works (a secret string) |
| `v < 0.5` | error |
| `print(v)` | shows the real value in chat |
| `StatusBar:SetValue(v)` | draws it |
| `FontString:SetFormattedText("%d%%", v)` | draws it (`73%`) |
| `UnitHealthPercent(unit, true, colorCurve)` → `SetStatusBarColor` | draws the curve's colour |

`UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)` returns 0-100. One profiled match drew enemy health 42,163 times without a failure.

## Sharing between players

There is no addon-readable channel between players in a match.

- `C_ChatInfo.InChatMessagingLockdown()` turns true about one second after entering and stays true until the match ends (three profiled matches). Addon messages and addon-sent chat are dropped silently.
- `CHAT_MSG_INSTANCE_CHAT` and `CHAT_MSG_PING` reach addons, but their text is secret. Ping text names the pinged unit ("Threatening alert: <name>"). No other ping event reached addons.
- Players can raid-mark teammates but not enemy players.

What the game shares by itself still works: teammates' targets (`raidNtarget`) are unit tokens on your client while it can see the enemy.

## Enemy unit reads

The API probe called 273 read-only functions on an enemy player in Warsong Gulch: 122 returned readable values, 87 secret ones, 69 errors (mostly a missing second argument). The client exposes 11,038 functions; Blizzard's documentation lists 6,624 (410 systems). The undocumented ones that mention units are FrameXML helpers and older globals, nothing useful.

**Secret:** `UnitHealth`, `UnitHealthMax`, `UnitHealthPercent`, `UnitHealthMissing`, `UnitPower*`, `UnitGetTotalAbsorbs`, `UnitClass`, `UnitClassBase`, `UnitRace`, `UnitSex`, `UnitGUID`, `UnitFullName`, `UnitPVPName`, `UnitInRange`, `GetUnitSpeed`, `UnitIsPVP`, `UnitHonorLevel`, `UnitGroupRolesAssigned`, `UnitArmor` and the other stats, `C_SpecializationInfo.GetInspectSpecialization`.

**Refused with an error:** every `C_UnitAuras` and `C_TooltipInfo` aura read ("Auras cannot be accessed when secret while tainted").

**Readable:** `UnitName`, `UnitExists`, `UnitIsVisible`, `UnitIsDead`, `UnitIsDeadOrGhost`, `UnitIsGhost`, `UnitIsFeignDeath`, `UnitIsPlayer`, `UnitAffectingCombat`, `UnitPowerType`, `UnitClassification`, `UnitSelectionColor`, vehicle state. `UnitPosition` returns only the instance ID; `UnitDistanceSquared` returns `0, false`. Spell range (`C_Spell.IsSpellInRange`) is readable: 64,002 plain readings in profiled matches.

`C_Secrets` reports per unit what is secret: `ShouldUnitHealthMaxBeSecret`, `ShouldUnitPowerBeSecret`, `ShouldUnitPowerMaxBeSecret`, `ShouldUnitSpellCastingBeSecret` and `ShouldUnitIdentityBeSecret` return true; `ShouldUnitThreatStateBeSecret` returns false.

The two-argument checks agree with the reads they guard, so they can replace hard-coded per-client flags (`libs/HighgroundKit/config/Client.lua`). With an enemy as target: `HasSecretRestrictions()` and `CanCompareUnitTokens("target", "player")` return true, and `ShouldUnitAuraIndexBeSecret("target", 1)` returns true, matching the refused auras. `ShouldUnitComparisonBeSecret("targettarget", "player")` matched `UnitIsUnit("targettarget", "player")` in every paired read: true with a secret result, false with a plain one. With a teammate as target, `ShouldUnitIdentityBeSecret` returns false (true for enemies), while `ShouldUnitAuraIndexBeSecret` still returns true, so teammates' auras are likely secret too (no aura read made). Read live in Arathi Basin, build 71037, 2026-11-24.

### Loss of control

`C_LossOfControl.GetActiveLossOfControlDataCountByUnit(unit)` is readable for enemies on `target`, `nameplateN` and `raidNtarget`: 1 while the enemy is controlled, 0 within 0.1 s after the effect ends. In `GetActiveLossOfControlDataByUnit(unit, 1)` only `priority` and `displayType` are readable, and they don't separate kinds: Gouge, Cheap Shot and Kidney Shot all read 5 and 2. The type, duration, spell and icon are secret.

### Flag positions

Blizzard's map reads `C_PvP.GetBattlefieldFlagPosition(index, mapID)`; the old global `GetBattlefieldFlagPosition` no longer exists, while `GetNumBattlefieldFlagPositions` does. In Warsong Gulch, with both flags carried, the count read 2: your team's carrier had a readable position (`0.50, 0.14`), the enemy carrier had `nil` even when targeted 30 yards away. Textures are file IDs: 137200 is the Alliance flag, 137218 the Horde flag.

### Enemy's target

With an enemy player as `target`, `targettarget` reads plainly: `UnitExists` returns true and `UnitName` returns the name of the player the enemy targets, your own or a teammate's, neither secret. `UnitIsUnit("targettarget", "player")` is secret (true when the enemy targets you, false otherwise). To tell who an enemy targets, compare names with yours and your group's. The same works for every visible nameplate: `UnitName("nameplateNtarget")` read plainly for enemies and teammates alike, with the surname as the second return, and one read showed three enemies targeting you. So Highground can count the visible enemies on you or on a healer, not only your target's. Read live in Arathi Basin, build 71037, 2026-11-24.

### Interaction distance

`CheckInteractDistance(unit, i)` is readable for an enemy player, in and out of combat. Indexes 1 and 4 give the 28-yard band: true near the enemy, false farther away. Indexes 2, 3 and 5 turned true only in melee range, so they mark a melee band rather than 10 or 11 yards. Read live in Arathi Basin, build 71037, 2026-11-24.

### In combat

`UnitAffectingCombat(unit)` stays readable for an enemy player during a match: it read true for an enemy in a fight and false for one out of it, neither secret. "Not in combat" can mark an enemy arriving or drinking. Read live in Arathi Basin, build 71037, 2026-11-24.

### Tooltip lines

Every `leftText` in `C_TooltipInfo.GetUnit(unit).lines` is secret for an enemy player, the name line included: name, guild, "Level 32 Night Elf (Player)", class, faction and "PvP". `rightText` is nil. The lines can be displayed but not read, so they reveal nothing the direct reads hide. Read live in Arathi Basin, build 71037, 2026-11-24.

### PvP trinket

`C_PvP.GetArenaCrowdControlDuration(unit)` returns a `LuaDurationObject` for the PvP trinket cooldown that `C_PvP.RequestCrowdControlSpell(unit)` asks the server for, and `GetArenaCrowdControlInfo(unit)` its spell, start and duration. For enemy targets in a battleground the object stays empty: every read after a request, including right after the target used its PvP trinket, was `IsZero` true, `HasSecretValues` true, 0 remaining, and the info call returned nothing. The calls likely serve arena opponents (`arenaN`) only; arenas weren't checked. Read live in Arathi Basin, build 71037, 2026-11-24.

## Teammate reads

- `UnitGroupRolesAssigned` is readable for teammates but returns `"DAMAGER"` for you and every raid member in a match. Players can't set or request a role.
- An inspect works on a teammate in a match: after `NotifyInspect(unit)`, `C_Traits.GetConfigInfo(-1)` (the inspect config) names the trait tree and `C_Traits.GetGroupCurrencyInfo(-1, groupIDs)` gives the points per talent tree, as for your own config. Trees without points are left out. Read live on an Enhancement shaman in Warsong Gulch's start room (`Enhancement 23`).
- Enemies can't be inspected: `CanInspect` returns `false` for an enemy player and the inspect config stays empty (`GetConfigInfo(-1)` is nil), live 2026-11-24. Enemy specs stay hand-tagged.

## Used in Highground

| Finding | Change |
| --- | --- |
| Secret health draws, formats and colours | Health bar style, percentages on every client, Green to red, last seen health (#317) |
| Teammates' targets are tokens | Live health for enemies only a teammate targets (#317) |
| Enemy marks refused | Raid-icon mark mode and marker scoring hidden on WoW Forever (#318) |
| Enemy auras refused | Aura-based scoring settings hidden on WoW Forever (#319) |
| Loss-of-control count readable | Generic **CC** chip on WoW Forever (#322) |
| No sharing in matches | **Share observations** hidden on WoW Forever; nothing prepared for sending |
| Flag positions moved to `C_PvP` | Map flag positions read through the current API and file IDs; your own carrying teaches your area's map spot |
| Teammate roles are all DAMAGER; inspected talent points are readable | Team healers: inspected and hand-marked green healer crosses (#324) |
| Enemy power type readable; a Moonkin's model file ID readable outside a match | Druid form estimates on WoW Forever: ~Restoration, ~Feral, ~Balance from a Moonkin model (#326) |
| Enemies' target names readable | On you, on your healer and the header's ON YOU count on WoW Forever (#339) |

## Open world

Midnight's restrictions are lighter outside instances. Blizzard's API notes (warcraft.wiki.gg, *Patch 12.0.0 API changes*, *Secret Values*) say:

- Chat lockdown applies only in a PvP match, a Mythic+ run, an encounter or a restricted map such as a dungeon or raid, not in open-world combat. Addon messages to party, raid, guild and custom channels work there; Highground's shared sightings (`HighgroundW`, `world/Share.lua`) and bounty sightings rely on it.
- An enemy player's identity (name, class, GUID) is secret only for units that aren't player-controlled, or inside a match. Nearby already reads enemy class, level and guild in the world.
- Auras and cooldowns of other units are secret whenever you are in combat, anywhere. Other units' casts are always secret. The combat log is gone everywhere; `PARTY_KILL` and `UNIT_DEATH` replace part of it, with readable GUIDs when the identity is readable.
- Unit comparisons are secret only on addon-restricted maps.

None of this has been measured on WoW Forever in the open world yet. The [API probe](../tools/apiprobe/README.md)'s `/hgprobe world` records it in one snapshot: each `C_RestrictedActions.IsAddOnRestrictionActive` type and the chat restrictions; identity, health, auras and raid icon of the target, `party1` and enemy players' nameplates; whether each enemy targets you; group map positions; and whether you are in combat and in an instance. While loaded, the probe also counts `PARTY_KILL` and `UNIT_DEATH` and whether their GUIDs were secret.

In a party, with an enemy player as target, run `/hgprobe world` out of combat, again in combat with them, and once in a battleground for contrast. Kill someone, then `/reload` and run the [report](../tools/apiprobe/README.md#report): section (d) lines the snapshots up, (e) lists the kill events. Record results here with the date and build.

Also still to check: whether a character of the other faction can read addon messages in a custom channel (two accounts needed).

## Leads to try

Each needs a match, an enemy player as target and `/console scriptErrors 1`. Every line fits the 255-character chat limit.

**Moonkin form.** `UnitPowerType` can't tell Moonkin from caster form (both mana), so Balance druids read as Restoration. If an enemy's model is readable, Moonkin would name Balance. Outside a battleground a friendly Tauren druid in Moonkin form read `Humanoid 7581785 false`: the model file ID is plain there, and `UnitCreatureType` doesn't change with form (live, 2026-11-24). Highground uses it (#326) where readable; Tauren and Night Elf are thought to share this model, and a later druid race may bring its own (IDs seen are counted in `liveStats.druidModels`). Still to check: an enemy inside a match (identity reads are secret there) and that caster form reads a different ID. Needs a level bracket where druids have Moonkin Form; a level 33 match had none. Target the druid and run:

```
/run local m=CreateFrame("PlayerModel",nil,UIParent)m:SetSize(9,9)m:SetPoint("CENTER")m:SetUnit("target")C_Timer.After(1,function()local f=m:GetModelFileID()print(UnitCreatureType("target"),f,issecretvalue(f))m:Hide()end)
```

Record results here with the date and build.
