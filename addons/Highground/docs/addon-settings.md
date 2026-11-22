# Addon settings organization

Each addon section in the Highground window owns its settings, appearance,
previews and guide entry points. Shared preferences identify settings that
affect every addon. Profiles continue to save the complete setup.

## Destinations

| Addon | Settings and tools |
| --- | --- |
| Battlegrounds | Enemy targeting, markers, timers, carriers, map intel, callouts, panel appearance, alerts and sample panels |
| Arena | Arena and duel preferences, panel appearance, placement and opponent samples |
| Nearby | Sightings, history, list appearance, alerts, journal and sample enemies |
| Bounties | Board, reward preferences, markers, notifications and existing sample scenarios |
| Reputation | Reports, organization settings, filtering and guided examples |
| Macros | Builder, presets, spell-rank and script preferences and guided examples |

Common destinations are Overview and enable, Settings, Appearance, and
Previews and guide. A section only exposes destinations with useful content.
Shared preferences contain theme, text, accessibility, master sound and alert
level, and shared HUD styling. Panel cogwheels open the owning addon's page.

## Compatibility

Keep existing commands and saved setups usable. Addon enable switches still
apply after reload and remain separate from saved feature preferences.
Settings pages and previews must respect disabled addons and client capabilities.
Controls for an individual panel must not silently resize another addon.
Where existing layout values are shared, preserve their effective values when
introducing independent settings, including imported profiles and both layouts.
Reset actions explicitly name their scope.

## Implementation review

- Feature guide: pending. Update the feature/appearance walkthrough, addon
  destinations, highlighted controls, saved resume targets and help text.
- Test/preview: pending. Move launchers into their addon sections, distinguish
  real tools from samples, and retain preview start/interaction/stop isolation.
- Validation: pending. Exercise navigation, module switches, cogwheels,
  profiles, appearance and sample lifecycles on supported clients and affected
  standalone hosts; run staged performance budgets before runtime commits.
