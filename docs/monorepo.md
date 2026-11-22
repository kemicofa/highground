# Monorepo

[Documentation](README.md) · [Repository overview](../README.md) · [Builds and releases](releases.md)

## What's here

| Location | What it holds |
| --- | --- |
| `libs/HighgroundKit/` | Shared library with no TOC: standalone start-up, themes, UI kit, HUD windows, utilities, settings, nearby enemies, bounties, journals and fonts |
| `addons/Highground/` | Kill order, settings, profiles, setup, the Highground window and `/hg`; embeds the library and imports feature files |
| `addons/HighgroundMacros/`, `HighgroundBattlegrounds/`, `HighgroundArena/`, `HighgroundBounties/`, `HighgroundNearby/`, `HighgroundReputation/` | Standalone addons: TOCs, entry points, tests and docs; feature code lives in `src/` or the shared library |
| `addons/HighgroundBountyData/` | Internal dependency owning the shared bounty SavedVariables file; bundled with all three bounty clients, never released separately |
| `addons/HighgroundReputationData/` | Internal dependency owning reputation SavedVariables; bundled with Highground and Highground Reputation, never released separately |
| `scripts/` | `addons.py` (every addon's facts, from its TOCs), `build.py` (ZIPs), `publish.py` (GitHub release, CurseForge and Wago uploads), `curseforge.py` and `wago.py` (upload APIs), `release_check.py` (shared-files release check), `release_plan.py` (publisher selection) |
| `tests/` | `run.sh` (every test; `run.sh ADDON` for one), packaging, release and layout tests (`test_*.py`) |
| `tools/` | `wowsim/` (WoW simulator and battleground extension), `lint/` (validators), `harness.lua` (test helpers), macro/theme previews and `sounds/` (sound generators) |
| `.github/` | `workflows/ci.yml` (shared checks, addon matrix, CI gate, publication and announcement), `workflows/addon.yml` (one addon: test and package); `actions/setup-luajit/`; Dependabot |

## Source installation

For WoW Forever testing across feature worktrees, use the [single-worktree link manager](worktree-testing.md). It keeps Highground and its dependencies on one selected source, coordinates concurrent agents, and stores the game location only in local Git configuration.

Keep the repository intact: each public addon uses a `libs/` symlink, and Highground also uses `features/` symlinks. Copying only an addon folder can break those links. Link the source folders into the game instead, or [build a ZIP](releases.md#local-build) to get ordinary files.

For Highground, run from the repository root, replacing `/path/to/game` with your game folder:

```sh
ln -s "$PWD/addons/Highground" "/path/to/game/Interface/AddOns/Highground"
ln -s "$PWD/addons/HighgroundBountyData" "/path/to/game/Interface/AddOns/HighgroundBountyData"
ln -s "$PWD/addons/HighgroundReputationData" "/path/to/game/Interface/AddOns/HighgroundReputationData"
for module in "$PWD"/addons/HighgroundModule*; do
  ln -s "$module" "/path/to/game/Interface/AddOns/$(basename "$module")"
done
```

Highground also requires HighgroundReputationData for its embedded reputation feature. Standalone Highground Reputation needs only that data addon.

The destination folders must not already exist. Use the standalone addon's folder name to install it instead. Highground Nearby and Highground Bounties also need HighgroundBountyData; Macros, Arena and Battlegrounds have no data-addon dependency. Restart the game after installation.

## Who owns what

Highground also bundles six `HighgroundModule*` folders. Each is a native addon-list switch for an embedded module, grouped under Highground with its own icon. They depend on Highground; Highground does not require them. Their enable states are read once at startup, and the main Addons page changes the same per-character states through the native addon API. A reload applies changes without overwriting panel preferences or profiles. Module-owned events, timers and message subscriptions are not registered when disabled; common definitions remain loaded in Highground. Shared services remain available to enabled modules, such as death observations used by both Nearby and Bounties.

These internal folders contain no duplicate standalone runtime or SavedVariables. They are packaged through `X-Bundled-Addons` with `X-Highground-Module` metadata and are never published separately. Keep every bundled folder when installing Highground. An old source installation with none of the switch folders retains its previous behavior and explains that the full bundle is needed for native controls; an incomplete new bundle leaves missing modules unavailable. The separately released `HighgroundBounties`, `HighgroundMacros`, etc. remain independent alternatives and still stand by when Highground is loaded.

WoW loads only files inside an addon's own folder, so code reaches other folders through links. `scripts/build.py` puts real copies in each ZIP.

- **The library** (`libs/HighgroundKit/`): code two or more addons need. Every public addon has `libs -> ../../libs/HighgroundKit`; its TOCs select the `libs/...` files it uses. The storage-only HighgroundBountyData and HighgroundReputationData addons have no library links.
- **A standalone addon** owns its feature's code in `src/`:
  - macros: Highground Macros;
  - the battleground engine, timers, flag carriers and map intel: Highground Battlegrounds;
  - the arena and duel panel: Highground Arena;
  - player reports and moderation: Highground Reputation (`src/reputation/`).

  The bounty engine lives in `libs/HighgroundKit/bounty/`, since Highground Nearby and Highground Bounties both load it. The bounty sound lives in Highground Bounties' `src/sounds/`; Nearby uses the game alert sound for bounties. Shared stealth cues live in `libs/HighgroundKit/sounds/`, with their source attribution in `stealth.txt`. Highground Nearby wraps the library's nearby list and bounty engine.
- **Highground** owns the kill order, settings, profiles, setup, the Highground window, `/hg` and its half of `Macros.Host`. It imports Macros, Battlegrounds, Arena and Reputation through `features/<name> -> ../../<Addon>/src`, and the bounty sound through `features/bounties/`. Bounty and nearby runtime code come from the library.

The rule, checked by `tests/test_layout.py`:

- A standalone addon loads only `libs/`, its own `src/` and its own files. It never uses another addon's code.
- Only Highground imports other addons, and only their `src/`.
- Storage and module addons may link their declared icon to the shared brand texture; no other runtime links.

New code goes to the addon whose feature it is, or into the library when a second standalone addon needs it.

The three bounty clients declare `HighgroundBountyData` under `Dependencies` and `X-Bundled-Addons`. That small addon has no runtime code or UI: it owns `HighgroundBountyNetworkDB` in one SavedVariables file. A variable declared separately by each client would be saved in different files and could lose identity or commitments when switching enabled clients. Source installs must link the data addon alongside the client; ZIP builds bundle it automatically. `X-Internal: true` excludes it from standalone release discovery, while shared-file release checks include its packaged files.

A library file is shared only by the addons whose TOCs load it, so keep feature code in files only those addons load. Settings follow the same rule: `libs/config/Options.lua` holds what every addon shares (General, Appearance, layout and sound), and each feature's pages, settings and switches are in `libs/config/catalog/<Feature>.lua`, loaded only by the addons that ship it. A new nearby setting then releases Highground, Highground Nearby and Highground Bounties, not every addon.

## Inside the code

- All seven UI addons load `ns.Router` and share `Kit.Windows` for foreground dialogs. Feature routers own tabs and draft history; `Kit.AttachNavigation` exposes them to the header and hub. Macros accesses the service through `Macros.Host.Router`. See [UI routing](../addons/Highground/docs/router.md).
- The macro tools reach the addon only through `Macros.Host`: `ns.Macros` and `Macros.Host`, never `ns.Core` or other `ns` fields. Highground's `tests/simulation/scenarios/macroranks.lua` fails on any other use.
- Names that differ per addon come from `ns`: the font folder (`ns.MEDIA`, `libs/ui/Style.lua`), sounds (`ns.SOUNDS`), the chat label (`ns.LABEL`), global frame names (`ns.FRAME_PREFIX`) and the saved variable (`ns.SAVED_VARIABLE`).
- `libs/standalone/Bootstrap.lua` sets these for a standalone addon:
  - the game: `ns.CLIENT` and `ns.GAME`;
  - `ns.LABEL` from the TOC title, `ns.FRAME_PREFIX` from the folder name, and the saved variable `<Folder>DB`;
  - `Core`, initialized with an empty player-state table.
- `libs/standalone/Main.lua` (`ns.Standalone.Start`) loads the saved variable and registers the slash command, help, theme and settings page.
- Global frame names start with `ns.FRAME_PREFIX`, so a standalone addon never overwrites Highground's.

## Next to Highground

Each standalone addon lists `## OptionalDeps: Highground`, so Highground loads first when enabled. The standalone then stays inactive (`ns.STANDBY`):

- `Util.Events`, `Util.Every` and `Comms.Listen` register nothing, and `Comms.Send` sends nothing.
- Its slash command only says to use `/hg`, and one chat line at login says so.

Each standalone addon's `tests/addon_test.lua` loads it from its TOCs in the simulator on every game, both on its own and next to Highground.

Highground Nearby also lists Highground Bounties as an optional dependency. If Bounties is loaded, Nearby stays inactive and directs its commands to `/hgb`.

## Releases

Each public addon has its own version and changelog. One workflow tests every addon and coordinates publication. Shared-file checks compare the source files actually included in each ZIP, including bundled dependencies. A changed shared file requires new versions of the affected addons; changes confined to one package do not. Standalone entry points and library files that Highground does not load can change independently. See [builds and releases](releases.md#shared-files).

## Add an addon

These steps are for a public standalone addon. Internal dependencies use `X-Internal: true` and are bundled by their clients instead.

1. Make `addons/<Name>/` with its TOCs (`<Name>.toc` and `<Name>_Cata.toc` for the current client layout), `Main.lua`, `CHANGELOG.md`, `README.md` and a copy of the repository `LICENSE`. A TOC with `## X-Curse-Project-ID` also needs `docs/curseforge.md`; the build checks its version line and summary. List non-runtime files to ship under `X-Package-Files`.
2. Add the `libs` link (`ln -s ../../libs/HighgroundKit addons/<Name>/libs`) and put its own code in `src/`. Its TOCs:
   - start with `libs/standalone/Bootstrap.lua`;
   - list `## OptionalDeps: Highground` and `## SavedVariables: <Name>DB`;
   - end with its `Main.lua`, which calls `ns.Standalone.Start`.
3. To bring it into Highground, add the link `addons/Highground/features/<name> -> ../../<Name>/src` and load its files from Highground's TOCs.
4. Put its tests in `addons/<Name>/tests/`, including `validate.py`; `tests/run.sh` runs them from that folder.
5. Add the addon to the matrix in `.github/workflows/ci.yml` and list it in this repository's [README](../README.md).
6. Each public addon gets a GitHub release; add `## X-Curse-Project-ID` (and `## X-Wago-ID`) to its TOCs to upload it to CurseForge (and Wago).

## Organizations

`libs/HighgroundKit/social/` is the shared guild/community layer, independent of bounties and reputation. Load `core/Util.lua`, `core/Names.lua`, `core/Scope.lua`, `social/Guild.lua`, then `social/Organizations.lua` after client capabilities and the host's `Core` table exist.

- `ns.Organizations.List()` returns the current guild and native WoW character communities, with `{ id, name, kind, clubId }`. Native club IDs distinguish duplicate names and survive renames; older guild clients use a guild/realm fallback. Battle.net communities are excluded because their members are not character identities.
- `Get(id)`, `Members(id)`, `Member(id, who)`, `IsMember(id, who)`, `Role(id, who)` and `CanModerate(id, who)` resolve live native membership. Unknown or unreadable permissions grant no moderator access. `RequestRoster(id)` requests asynchronous native roster data; `Listen(fn)` observes guild/club changes.
- `List()` and `Members(id)` also return readiness as their second result (`ready`, `loading`, or `unavailable` for an inaccessible roster). Views use it to distinguish pending native data from a confirmed empty list; existing membership callers can continue using the first result. Shared UI state and async attempt helpers are documented in [development](../addons/Highground/docs/development.md#async-attempts-and-state-transitions).
- `Open(id)` opens Blizzard's Guild & Communities UI from a user action. Creation, invitations, joining, leaving and role assignment belong there. The shared layer has no saved roster or community-management protocol.
- `ns.Guild` owns the classic guild roster and rank flags. Bounties delegate to it while retaining their existing guild keys and explicit `bountyOfficerRank` fallback. Reputation uses only native permissions.
- `ns.Scope.Region()` identifies game/region; `Key()` identifies the economy (realm or Forever ruleset); `Social()` permits cross-realm native communities while separating Forever rulesets. Features own their saved data and opt-ins.

Personal and realm-wide sharing are feature audiences, not organizations. New addon features can consume the organization service without loading the bounty engine.

Bounties use `bounty/Organizations.lua` to adapt feature storage and permissions to `ns.Organizations`. `Bounty.Guild(id)`, `Submit(name, source, id)`, `Approve(name, id)`, `Remove(name, "guild", id)` and `RequestSync(id)` accept a native community ID; omitting it preserves the existing guild API, saved keys and wire format. Entries and claims retain their organization ID independently of the selected board. Community owners, leaders and moderators can approve; members submit for review.

`bounty/OrganizationSync.lua` sends community data through bounded addon whispers addressed from the native roster. Envelopes carry the community ID and `ns.Scope.Social()` so members on different realms can exchange data without joining the realm-wide public board. Membership is checked again at queue flush and receipt; pending entries and their attachments go only to their author and current moderators. Each native community has its own board, including identically named communities. Community export codes import as private drafts and confer no native membership or approval.

Highground Reputation owns `src/reputation/`; Highground imports it through `features/reputation/`. Both bundle the storage-only `HighgroundReputationData` addon. Its database stores organization references and feature records; every action rechecks current membership and permissions. Custom groups from the unreleased Watch implementation are not mapped to native communities by name.

Reputation separates the saved organization activation (`activated`) from this installation's participation (`enabled`) and session-only receiver readiness. Native moderators activate; members can follow an organization and queue reports before activation is confirmed. `Availability.lua` probes online native moderators, correlates and orders their replies, and supplies the same status to the list and report form. Confirmation is shared across alts; presence is never persisted. An explicit personal pause is respected by discovery. Pending proposals retain their original reporting character and revision and are removed only on that revision's receipt from an actual recipient. A verified legacy snapshot also establishes receiver readiness.
