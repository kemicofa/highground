# Highground theme redesign plan

Status: implemented, 18 November 2026. Automated validation and packaging are recorded below; the initial look was approved after a WoW Forever test.

The implemented direction follows the crest in `~/Downloads/Highground Fantasy Battlefield Crest.png`: dark blue armour, illuminated gold, ivory lettering, and precise red battlefield markers. The redesigned Highground theme combines that identity with persistent class colours wherever players need to recognise another player. It is the default across the addon family.

The visual concept accompanying this plan uses sample data. It demonstrates the proposed appearance and hierarchy; it is not an in-game rendering.

## Design direction

Build a command interface inspired by the crest's elevated viewpoint, pointed gold rim, blue banners and marked targets. Keep the fantasy character in the silhouette, title treatment and edges. Keep the centre of each panel calm enough to read during a fight.

- **Silhouette:** squared panels, narrow inset rims, pointed corner accents, and a small central diamond or summit motif. Replace the current generic accent stripe and curled ornament with a recognisable Highground treatment.
- **Materials:** midnight foundations, blue steel raised surfaces, dark inset fields, and gold edges with a restrained highlight and shadow. Relief stays around the perimeter.
- **Brand presence:** use the existing crest in the hub and welcome surface. Use a small shared geometric mark and gold title rule in combat headers, where the detailed logo would become noise.
- **Hierarchy:** the current recommendation is the strongest content element. Player identity, state, health and timers remain distinct at a glance. Window trim is quieter than an active target cue.
- **Typography:** Friz Quadrata for major window titles; bundled Barlow Condensed for names, navigation and controls; JetBrains Mono for timers, ranks, health and rewards. Avoid decorative body text. Respect the player's font override.
- **Motion:** short state transitions using the existing motion system. A combat opportunity may pulse at the edge of a row. Gold trim and logos remain still. Reduced motion retains a steady, visible cue.

The blue and gold identify Highground. Faction identity continues to use explicit faction icons and labels; the crest's Alliance imagery does not make every blue surface an Alliance state.

## Proposed palette

These are UI-adapted colours inspired by the supplied crest, not a claim of exact pixel samples. Final values must pass the existing composited contrast checks.

| Role | Starting colour | Use |
| --- | --- | --- |
| Midnight | `#07111F` | Main panel background and text on gold buttons |
| Deep inset | `#050C16` | Input wells, chip backing and recessed data |
| Blue steel | `#101F33` | Cards and enemy row foundations |
| Raised blue | `#192F4A` | Hoverable controls and selected navigation backing |
| Steel seam | `#32455F` | Quiet decorative separators |
| Forged gold | `#F4BB48` | Brand, primary actions, recommendation markers |
| Gold highlight | `#FFE3A0` | Title highlights and small metal highlights |
| Dark gold | `#84622E` | Decorative inset rim; never small text or a required control boundary |
| Ivory | `#F4EBD8` | Primary text |
| Pale steel | `#BBC9DD` | Secondary text |
| Muted steel | `#A8B8CD` | Tertiary text |
| Control boundary | `#7C91B0` | Input and toggle boundaries |
| Signal blue | `#82B8F4` | Information and focus indicators with an explicit shape |
| Signal red | `#FF626A` | Urgent edges and attack marks |
| Readable red | `#FF9A9F` | Danger and execute labels on dark surfaces |
| Signal amber | `#FFC47F` | Warnings and approaching deadlines |
| Signal green | `#9DD9AB` | Confirmed success and spent defences |
| Reward gold | `#FFD978` | Currency and reward amounts, paired with a coin or reward label |

Gold has two related roles: brand/action and reward. Distinguish them through position, shape and wording. A gold recommendation rank, a gold action button and a labelled gold reward must not be interchangeable signals.

## Class colour integration

Class colour becomes part of Highground's player identity system. Use the existing `Util.ClassColor`, `Theme.ClassColor`, `Theme.EnemyRowColor` and `Hud.PaintEnemy` paths so custom class colours, contrast correction and live repaint continue working.

| Surface | Class treatment |
| --- | --- |
| Battleground enemy rows | Persistent dark class surface and saturated class edge; ivory names in the dense priority list; explicit class/spec icon or label |
| Arena opponents | Persistent class surface, class name ink where readable, and an independent health layer; target and focus remain labelled |
| Nearby enemies | Persistent class surface and class-coloured name; bounty and threat indicators retain their own semantics |
| Suggested target | Class identity in its edge, name and a restrained inset surface; gold recommendation label; red attack state |
| Flag carriers | Class identity on the player portion when known; faction and carrier status remain separate |
| Enemy journal and match history | Class-coloured player names or small identity edges where the record actually contains class data |
| Macro presets and builder | Class icon and accent on class-specific recipes or selection; code syntax and primary actions retain their own colours |
| Bounties | Class cues only when trustworthy class data already exists; rewards and approval states keep their own colours |
| Settings, navigation, forms and objective timers | Brand and semantic colours; class colour appears only on a control that actually represents a class |

Start the Highground row tint at a maximum `alpha.classRow` of `0.40`; retain per-colour contrast clamping. The existing Class Colors preset can retain its stronger `0.55` maximum. These values are ceilings, not equal opacity for every class: Priest white and Rogue yellow need darker resulting surfaces than some other classes.

Health is a separate layer. Start filled health at `0.08` opacity over the class surface and use a clear lower health line in the proposed combat layout. Class identity persists at zero health, with hidden health, and in the existing Line health style. Respect saved health-style choices.

Use opaque dark backing for tactical chips. Class colour must never stand in for immunity, crowd control, attack opportunity, target, focus or bounty status. Keep icons, words and shape cues alongside semantic colours. Keep the current dimming for dead or unseen players; clear stale class colours when rows are recycled for unknown players.

## Component redesign

| Area | Proposed result |
| --- | --- |
| Hub header and navigation | Crest, gold title, blue steel sidebar, compact section labels, and a gold selected marker with a raised background |
| Hub home | A strong branded welcome area, readable current-context summary, and prominent existing actions for arranging panels and returning to play |
| Combat board | A narrow gold header, a clearly separated recommended target, dense class-tinted rows, stable numeric columns and compact opaque state chips |
| Target hierarchy | Gold rank and edge for the recommendation; steady ivory arrow and `TGT` for the player's target; blue bracket and `FOC` for focus; red edge and `ATTACK` for a live opening |
| Arena and Nearby | The same header, class surface, row spacing and target vocabulary as the main board |
| Timers and flags | Strong numeric clocks on quiet blue surfaces; labelled semantic state; class cues confined to carrier identity |
| Bounty board and details | Ledger-like rows, prominent reward amounts, quiet metadata, and a clear gold primary action |
| Macro browser and editor | Blue inset code wells, more distinct recipe selection, class-specific identity cues and the existing syntax information |
| Journal windows | Consistent branded shell and form controls; encounter details remain easy to distinguish |
| Shared controls | Gold filled primary buttons with dark text; raised blue secondary buttons; consistent hover, press, focus, disabled and selected states |
| Menus, dialogs and tooltips | Opaque navy reading surfaces, restrained rims, clear titles and the same text hierarchy |
| Alerts and world overlays | Small bright signals on dark backing; no large ornamental frame; maintain readability over varied game scenery |

Define two chrome densities within the same theme: **full** for hub, browser and dialog windows, and **compact** for combat panels. Compact headers use a single small motif and fine rule. Frameless mode continues to suppress the corresponding frame decoration.

Retain the present compact row sizes initially. The redesign can change nonsecure window composition and spacing, but new typography must fit at the supported font scales. Any intended secure layout change must happen out of combat through the existing deferred layout path.

## Theme architecture and defaults

Before this redesign, `highground` was the inheritance base with slate/teal colours and `classRow = 0`, while `classcolors` was the default. The implementation below changes the default and consumers together.

1. Keep `highground` as the complete token base and redesign its palette. Set it as `ns.DEFAULT_THEME` once class surfaces and shared chrome are integrated.
2. Keep `classcolors` registered and selectable as a stronger class-emphasis variant with the new Highground brand. Existing commands, profiles and explicitly saved names continue to resolve.
3. Give Ember, Azeroth and Parchment explicit overrides for class tint, title faces and new chrome tokens. Changing the inheritance base must not accidentally enable gold Highground ornament or full-row class tint in every preset.
4. Keep missing/invalid runtime token fallback and stable live token tables. Any new token must be defined in the complete base, validated and included in repaint handling.
5. Introduce separate decorative metal tokens, for example `metalEdge`, `metalHighlight` and `metalShadow`, plus a small numeric ornament-strength token. Do not use a low-contrast decorative rim as an input boundary or focus indicator.
6. Separate the brightest decorative red from readable danger ink. Audit callers before adding a dedicated edge token; compatibility themes need explicit semantic defaults.
7. Record the default transition in release notes. A nil saved theme will now mean the new Highground default. Preserve explicit theme names and saved opacity, fonts, positions, motion and health-style preferences.

Prefer reusable procedural textures for rims, corner points and diamonds. The full crest belongs in the shared media directory in a game-supported format if it ships inside the addon; declare it in every applicable package manifest. Do not add a new font dependency. Prepare final bitmap assets as a separate implementation step only if the original crest needs conversion or a simplified raster mark is chosen.

## Implementation sequence

Each phase ends in a reviewable result and keeps the shared kit as the source of truth.

| Phase | Work and primary files | Completion evidence |
| --- | --- | --- |
| 1. Palette and state specification | `libs/HighgroundKit/config/Theme.lua`, `config/themes/*.lua`; map each new colour and state before editing consumers | Palette, type specimens, class rows and hover/selection compositions pass contrast checks |
| 2. Shared frame and controls | `libs/HighgroundKit/ui/kit/Ornament.lua`, `Controls.lua`, `Fields.lua`, `Lists.lua`, `Dialog.lua`, `Feedback.lua`; `ui/Style.lua`, `Windows.lua`, `PanelControls.lua`, `PanelMenu.lua` | One full window and one compact HUD demonstrate consistent default, hover, pressed, focused, disabled and selected states |
| 3. Combat identity and hierarchy | `libs/HighgroundKit/ui/Hud.lua`, `Contrast.lua`; `addons/Highground/ui/{Panel,Rows,Render,Hero,Health,Layout}.lua`; Arena `src/arena/Window.lua`, shared `world/Nearby.lua`, Battlegrounds flags/timers/compact views | Battleground, Arena and Nearby previews share class treatment; recommendation, target, focus and attack remain distinguishable |
| 4. Hub and feature windows | `addons/Highground/hub/{Hub,Home,Navigation}.lua`, `options/Appearance.lua`; shared bounty and journal views; Macros windows | Every primary window and its menus/dialogs uses the new system; identity colour appears only where supporting data exists |
| 5. Defaults and compatibility | Shared theme loading, standalone settings, saved-settings/profile paths and every relevant TOC | Fresh installs, existing nil theme values and explicit theme names reload correctly in every public addon |
| 6. Validation and documentation | Existing simulation scenarios, cross-addon integration, preview generators, design-system docs and changelog | Passing automated checks, inspected visual specimens and recorded in-client results |

Recommended implementation order within a phase: shared primitives first, the main combat board second, Arena/Nearby third, then feature windows. Use the actual existing working-tree state as the integration baseline; several related files already contain ongoing changes.

## Validation and acceptance

Extend the existing meaningful scenarios rather than duplicating their implementation. Update assumptions that currently assert Highground has no class surfaces and Class Colors is always the default.

- **Palette:** check normal text at 4.5:1 and meaningful controls/indicators at 3:1 on their actual composed backgrounds, including hover, selection, health and class tint. Decorative metal is assessed separately from required indicators.
- **Identity:** inspect every supported class, particularly Priest/Rogue, Shaman/Mage and Death Knight/danger red. Test custom black, white and saturated class colours, unknown classes, dead/unseen states and row reuse.
- **Health:** exercise zero/full/hidden health, Fill/Line styles and changing health without losing class identity. Keep Retail secret health values on the existing direct-to-status-bar path.
- **Targeting:** switch themes during combat without changing secure bindings, dimensions or row order. Preserve left-click target, right-click focus and the distinction between a recommendation and the currently bound hero click.
- **Refresh:** repaint open and hidden windows, idle rows, menus, tooltips and custom class changes. Cache class calculations; avoid new per-row allocations on each update.
- **Preferences:** test opacity, frameless mode, custom border, saved font, increased text size, compact layouts, docking, panel cogs and reduced motion. New ornaments must not intercept clicks or obstruct labels.
- **Packages:** cover Highground, Macros, Battlegrounds, Arena, Bounties and Nearby using their actual manifests. Exercise Retail, Cataclysm and Forever where supported; include Macros' additional supported clients in applicable checks.

Existing entry points include `tests/test_theme_integration.py` and Highground simulation scenarios `theme.lua`, `themes.lua`, `classrows.lua`, `accessibility.lua`, `hero.lua`, `panelcontrols.lua`, `motion.lua`, `layout.lua` and `compatibility.lua`.

During implementation, run focused scenarios for the touched behaviour. Before completion, run `bash tests/run.sh`, regenerate `tools/theme_preview.py` and `tools/motion_preview.py` specimens, and build packages with `python3 scripts/build.py`. Update the theme preview to show the new default and its stronger class variant rather than implying class colour only exists in the separate preset.

Final visual acceptance requires in-client inspection at normal and enlarged text sizes, over both bright and dark scenery, before and during combat. Simulator checks and the HTML concept do not certify game rendering or secure behaviour.

The finished theme should be recognisable as Highground from its header and frame alone. At a glance, the player should still be able to identify class, recommendation, current target, focus and urgent state without relying on colour alone.

## Implementation record

- Shipped the complete blue/gold token system, Friz titles, two ornament densities, button bevels and a game-ready copy of the supplied crest. The hub header and welcome card use the crest.
- Integrated persistent class identity across combat rows, the bound suggested target, known carriers, the enemy journal, class macro recipes and bounty records with class data. Target/focus labels and urgent red cues are independent.
- Added native-fill health lines with contrast-adjusted ink and explicit fading for unknown health. Theme repaint preserves that distinction without inspecting secret values.
- Made Highground the default in all six public addons. Explicit themes, custom class colours, fonts, opacity, health style, positions and reduced motion remain supported.
- Regenerated the runtime palette and motion specimens. Browser checks cover every class, zero-health persistence and reduced motion; the packaged crest was decoded and visually inspected. These specimens approximate the UI and are not WoW screenshots.
- Package checks require the crest and source notice in all six installable ZIPs.

The development build passed the full automated suite, both preview generators, browser interaction checks and package builds. The user approved the appearance after testing in WoW Forever. The isolated feature and release branches repeat the full suite against current main before publication. Extended client coverage still includes normal/enlarged text, bright/dark scenery, health styles and targeting during combat.
