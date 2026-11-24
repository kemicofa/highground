# Highground API probe (developer tool)

`HighgroundApiProbe` is a separate addon for development only. It is never packaged, released or loaded by Highground. It answers three questions on a live client, such as WoW Forever:

- Which functions does the client expose that Blizzard's API documentation doesn't list?
- Which unit reads still return readable values for an enemy, and which return secret ones?
- How do those reads change between the open world, in and out of combat, and a battleground?

It only enumerates what the game hands to addons and calls read-only functions. It does not inspect, modify or decompile the game client.

What it found so far, and leads still to test: [WoW Forever API findings](../../docs/forever-api.md).

## Install (manual)

Highground's packages, releases and game links never include this addon. Link it yourself:

1. Find the game's AddOns folder for your client: `<World of Warcraft>/_forever_/Interface/AddOns` for WoW Forever (`_retail_` or `_classic_` for the others). Under Wine or Proton it is inside the prefix's `drive_c`.
2. Link the folder from the repository root, replacing `<AddOns>` with that path:

   ```sh
   # macOS, Linux
   ln -s "$PWD/tools/apiprobe/HighgroundApiProbe" "<AddOns>/HighgroundApiProbe"
   ```

   ```bat
   :: Windows (Command Prompt as administrator, or with Developer Mode on)
   mklink /D "<AddOns>\HighgroundApiProbe" "%CD%\tools\apiprobe\HighgroundApiProbe"
   ```

   Copying the folder works too, but won't follow repository updates.
3. Restart the game fully: a new addon doesn't load on `/reload`.

Delete the link (not its target) when you are done.

## Use

| Command | What it does |
| --- | --- |
| `/hgprobe list` | Every function in `_G` and the `C_*` namespaces, widget methods (Frame, Button, StatusBar, FontString, Texture), and Blizzard's documentation (`Blizzard_APIDocumentationGenerated`) with every `Secret*`, `Restrict*` and `Protected*` flag. Saves documented, undocumented and documented-but-missing names. |
| `/hgprobe unit [token]` | Calls each read-only candidate with the unit (`target` by default; also `focus`, `nameplate3`, `raid2target`...). Candidates: documented functions with a unit-token argument and undocumented ones with `Unit` in the name. Only names starting with a query verb (`Get`, `Is`, `Has`, `Can`, `Should`, `Does`, `Find`, `Check`, `Calculate`) or `Unit` without an action word are called; FrameXML helpers (names with `_`) never are. Records per return its type, whether it is secret and, when readable, its value; secrets are never saved. Runs over several frames. |
| `/hgprobe world` | One snapshot, taken at once, of the reads in [Open world](../../docs/forever-api.md#open-world), with whether you are in combat (`InCombatLockdown`, `UnitAffectingCombat("player")`) and in an instance (`IsInInstance`). Restriction state: `C_ChatInfo.InChatMessagingLockdown`, `C_ChatInfo.AreOutgoingAddonChatMessagesRestricted` and `C_RestrictedActions.IsAddOnRestrictionActive` for each `Enum.AddOnRestrictionType`. For `target`, `party1` and up to three enemy players' nameplates (`nameplate#1`... in the results): `UnitGUID`, `UnitClass`, `UnitRace`, `UnitLevel`, `GetGuildInfo`, `UnitHealth`, `UnitHealthMax`, `UnitHealthPercent` and `C_UnitAuras.GetAuraDataByIndex(unit, 1, "HELPFUL"/"HARMFUL")`; for the enemies also `GetRaidTargetIndex` and `UnitIsUnit(<unit>target, "player")`. Positions: `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition(map, unit)` for `player`, `party1` and `raid1`, `UnitPosition` for `player` and `party1`. Missing functions and errors are recorded too. |
| `/hgprobe summary` | Counts for the saved list, runs, world snapshots and kill events. |
| `/hgprobe clear` | Deletes the saved list, runs, world snapshots and kill counts. |

While the addon is loaded it also counts `PARTY_KILL` and `UNIT_DEATH` per place (`world`, `pvp`...): how many, how many had a secret argument (the GUIDs), how many came in combat, and the last one's arguments. An event the client doesn't know is skipped; each world snapshot records which ones registered.

Type `/reload` after a run to write `WTF/Account/<account>/SavedVariables/HighgroundApiProbe.lua`.

A useful session: `/hgprobe list` once; in a battleground, target an enemy player and run `/hgprobe unit`, then `/hgprobe unit nameplate1` and a teammate's target (`/hgprobe unit raid1target`); outside instances, target a hostile player and run `/hgprobe unit` again for contrast; `/reload`.

For the open world, in a party, with an enemy player as target: `/hgprobe world` out of combat, again in combat with them (a macro button with `/hgprobe world` works mid-fight), and once with an enemy targeted in a battleground for contrast. Kill someone, or watch a party member do it, for the kill events. Then `/reload`.

## Report

```sh
python3 -I tools/apiprobe/report.py "<World of Warcraft>/_forever_/WTF/Account/<account>/SavedVariables/HighgroundApiProbe.lua"
```

It prints (a) functions that returned readable values for an enemy unit inside a PvP instance, by namespace, marking undocumented ones; (b) the same functions in runs outside instances; (c) undocumented functions about units, health, auras, casts, range or position; (d) each `/hgprobe world` read side by side across snapshots, with each snapshot's place and combat state; (e) the kill event counts.

## Limits

- Lua-defined FrameXML functions also appear as undocumented; compare names with Blizzard's UI source (`wow-ui-source`) to tell them apart.
- In `/hgprobe unit`, arguments other than the unit are left `nil`, so functions that need them report errors instead of values.
- `/hgprobe world` reads `party1` and `raid1` even without a group; they then read nil.
- Readable values may be ordinary (class, level) rather than a gap in Blizzard's restrictions, and any gap can close in a hotfix.
- Tests: `python3 -m unittest test_apiprobe` from `tests/`, or `luajit tools/apiprobe/tests/probe_test.lua` from the repository root.
