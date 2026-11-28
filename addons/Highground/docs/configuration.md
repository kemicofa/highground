# Configuration map

[Documentation](README.md) · [User guide](user-guide.md) · [Commands](commands.md)

Open `/hg` to configure Highground. Each addon's sidebar section owns its
settings. The same pages are also available through Blizzard's addon settings.
Ordinary changes save immediately; enabling or disabling an entire addon needs
a reload. Profiles do not change which addons are loaded.

| What you want to change | Where to look |
| --- | --- |
| Minimap button, master sound, master HUD scale, language | Shared preferences → General |
| Theme, fonts, accessibility, common HUD styling | Shared preferences → Shared appearance |
| Overall alert preset | Shared preferences → Alerts |
| One addon's features and alert text/sounds | That addon's Settings |
| Battleground, Arena, Nearby or Bounty panel appearance | That addon's Appearance |
| Enemy targeting rules and scoring | Battlegrounds → Target behavior and its tuning pages |
| Which enemy cooldowns are tracked | Battlegrounds → Cooldown tracking |
| Panel placement | Home → Preview and move panels, or a panel's cogwheel |
| Another character's or a friend's settings | Saved setups → Profiles |
| A starting configuration for a battleground role | Saved setups → Playstyle presets |
| Examples with your current settings | That addon's Previews and guide |

Shared appearance supplies common styling. Individual panel controls can
override it, so inspect the panel's own Appearance page when a shared change
does not seem to affect that panel. Master HUD scale multiplies individual panel
scales. A feature's child switches may be unavailable until its parent is on;
unsupported client features are omitted.

Some controls depend on what they can affect:

- Target lock and GO alerts are sound cues, so they have a Sound switch only.
- Nearby map visibility controls drawing. Map marks can still be shared while
  the map overlay is off; use the Map marks switch to stop that feature.
- Languages requiring a script-compatible font use that font automatically.
  The decorative font selector is unavailable while this fallback is active;
  its saved choice returns when the fallback is no longer needed.

Settings are kept per character and per addon (`options/SettingsParts.lua` says
which setting belongs to which addon); Battlegrounds settings are kept per size
(10v10, 15v15, epic, open world). Every way of changing a battleground setting
edits the one size shown by the size bar: pages, commands, guide switches,
presets and panel menus. Only Copy to other sizes changes several at once.

The Macros and Reputation sections open their full tools for editing macros,
reports and organizations. Their settings pages configure preferences; they do
not replace those workspaces. Data addons hold records rather than presenting
another set of appearance controls.

## Reviewing a setting

Configuration review follows a control through its definition, saved value and
runtime consumer. A saved value alone does not establish that the feature uses
it. Check both the visible control and the command where one exists, including
reset, inherited defaults, profile apply, disabled modules, client availability
and combat restrictions. For appearance, inspect the resulting panel as well as
the selector and preview.

Use the real addon simulations for repeatable behavior checks. Live-client
checks remain necessary for native rendering, glyphs and protected interactions;
simulation success does not establish those results.
