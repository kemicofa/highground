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

### Loss of control

`C_LossOfControl.GetActiveLossOfControlDataCountByUnit(unit)` is readable for enemies on `target`, `nameplateN` and `raidNtarget`: 1 while the enemy is controlled, 0 within 0.1 s after the effect ends. In `GetActiveLossOfControlDataByUnit(unit, 1)` only `priority` and `displayType` are readable, and they don't separate kinds: Gouge, Cheap Shot and Kidney Shot all read 5 and 2. The type, duration, spell and icon are secret.

### Flag positions

Blizzard's map reads `C_PvP.GetBattlefieldFlagPosition(index, mapID)`; the old global `GetBattlefieldFlagPosition` no longer exists, while `GetNumBattlefieldFlagPositions` does. In Warsong Gulch, with both flags carried, the count read 2: your team's carrier had a readable position (`0.50, 0.14`), the enemy carrier had `nil` even when targeted 30 yards away. Textures are file IDs: 137200 is the Alliance flag, 137218 the Horde flag.

## Used in Highground

| Finding | Change |
| --- | --- |
| Secret health draws, formats and colours | Health bar style, percentages on every client, Green to red, last seen health (#317) |
| Teammates' targets are tokens | Live health for enemies only a teammate targets (#317) |
| Enemy marks refused | Raid-icon mark mode and marker scoring hidden on WoW Forever (#318) |
| Enemy auras refused | Aura-based scoring settings hidden on WoW Forever (#319) |
| Loss-of-control count readable | Generic **CC** chip on WoW Forever (#322) |
| Flag positions moved to `C_PvP` | Map flag positions read through the current API and file IDs; your own carrying teaches your area's map spot |

## Leads to try

Each needs a match, an enemy player as target and `/console scriptErrors 1`. Every line fits the 255-character chat limit.

**Enemy's target.** If readable, Highground could alert "targeting you" or "on our healer" on WoW Forever.

```
/run local a=UnitIsUnit("targettarget","player") local n=UnitName("targettarget") print("ToT",n,issecretvalue(n),"me",a,issecretvalue(a))
```

**Interaction distance.** `CheckInteractDistance(unit, 1-5)` gives fixed distance bands (about 10, 11 and 28 yards). Readable bands would refine range when spells don't cover them.

```
/run for i=1,5 do local v=CheckInteractDistance("target",i) print(i,v,issecretvalue(v)) end
```

**In combat.** `UnitAffectingCombat` read `false` right after the gates opened. Check that it stays readable while the enemy fights; "not in combat" could mark someone arriving or drinking.

```
/run print(UnitAffectingCombat("target"),issecretvalue(UnitAffectingCombat("target")))
```

**Druid forms.** `UnitPowerType` is readable: mana for caster or healer form, energy for cat, rage for bear. A spec clue where specs are estimated. Check on a druid in each form.

```
/run print(UnitPowerType("target"))
```

**Arena crowd-control duration.** `C_PvP.GetArenaCrowdControlDuration(unit)` returned a duration object for an enemy in a battleground. It may be the PvP trinket cooldown in a form a cooldown widget can draw without Highground reading it. List its methods first:

```
/run local d=C_PvP.GetArenaCrowdControlDuration("target") print(d,type(d)) local m=d and getmetatable(d) if type(m)=="table" and type(m.__index)=="table" then for k in pairs(m.__index) do print(k) end end
```

**Tooltip lines.** `C_TooltipInfo.GetUnit(unit)` returned readable fields with secret GUIDs; the probe didn't open its `lines`. Some may hold text the direct reads hide.

```
/run for i,l in ipairs(C_TooltipInfo.GetUnit("target").lines) do print(i,l.leftText,issecretvalue(l.leftText)) end
```

**Ask the game what is secret.** The two-argument `C_Secrets` checks (`ShouldUnitComparisonBeSecret`, `CanCompareUnitTokens`, `ShouldUnitAuraIndexBeSecret`...) weren't called. Capability checks through `C_Secrets` could replace hard-coded per-client flags (`libs/HighgroundKit/config/Client.lua`).

```
/run print(C_Secrets.CanCompareUnitTokens("target","player"),C_Secrets.ShouldUnitComparisonBeSecret("target","player"))
```

Record results here with the date and build.
