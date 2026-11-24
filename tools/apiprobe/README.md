# Highground API probe (developer tool)

`HighgroundApiProbe` is a separate addon for development only. It is never packaged, released or loaded by Highground. It answers two questions on a live client, such as WoW Forever in a battleground:

- Which functions does the client expose that Blizzard's API documentation doesn't list?
- Which unit reads still return readable values for an enemy, and which return secret ones?

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
| `/hgprobe summary` | Counts for the saved list and runs. |
| `/hgprobe clear` | Deletes the saved list and runs. |

Type `/reload` after a run to write `WTF/Account/<account>/SavedVariables/HighgroundApiProbe.lua`.

A useful session: `/hgprobe list` once; in a battleground, target an enemy player and run `/hgprobe unit`, then `/hgprobe unit nameplate1` and a teammate's target (`/hgprobe unit raid1target`); outside instances, target a hostile player and run `/hgprobe unit` again for contrast; `/reload`.

## Report

```sh
python3 -I tools/apiprobe/report.py "<World of Warcraft>/_forever_/WTF/Account/<account>/SavedVariables/HighgroundApiProbe.lua"
```

It prints (a) functions that returned readable values for an enemy unit inside a PvP instance, by namespace, marking undocumented ones; (b) the same functions in runs outside instances; (c) undocumented functions about units, health, auras, casts, range or position.

## Limits

- Lua-defined FrameXML functions also appear as undocumented; compare names with Blizzard's UI source (`wow-ui-source`) to tell them apart.
- Arguments other than the unit are left `nil`, so functions that need them report errors instead of values.
- Readable values may be ordinary (class, level) rather than a gap in Blizzard's restrictions, and any gap can close in a hotfix.
- Tests: `python3 -m unittest test_apiprobe` from `tests/`, or `luajit tools/apiprobe/tests/probe_test.lua` from the repository root.
