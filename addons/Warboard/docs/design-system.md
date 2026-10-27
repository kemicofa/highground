# Design system

[Documentation](README.md) · [Development](development.md)

Every colour, font, spacing and size in Warboard's UI is a named **token**. Code asks for a token by name and never writes a number for a colour. A theme is a set of token values, so switching themes repaints everything.

## Tokens

The base theme `warboard` in [config/Theme.lua](../config/Theme.lua) defines every token:

| Group | Value | Examples |
| --- | --- | --- |
| `color` | `{ r, g, b[, a] }` | `bg`, `surface`, `border`, `text`, `textMuted`, `accent`, `gold`, `danger`, `factionA`, `chipDef`, `capPlate` |
| `type` | `{ face, size[, flags] }` | `body`, `heading`, `title`, `timer`, `rowName`, `badgeCount` |
| `space` | pixels | `xs` 2, `sm` 4, `md` 8, `lg` 12, `xl` 16 |
| `size` | pixels | `control`, `input`, `header`, `tab`, `row`, `icon` |
| `alpha` | 0–1 | `button`, `card`, `dialog`, `disabled`, `page` |

Faces are `bold`, `semi`, `medium` (Barlow Condensed), `mono` (JetBrains Mono) and `friz` (Friz Quadrata, the game's font).

`ns.ThemeTokens` holds the live values. Its tables are updated in place on a theme switch, so a colour table kept at load time follows the switch. [config/UI.lua](../config/UI.lua) keeps a few older colour names (`ns.UIConfig.colors`) that point at the same tables, plus panel sizes.

## Themes

| Theme | File | Look |
| --- | --- | --- |
| Warboard | [config/Theme.lua](../config/Theme.lua) | Dark navy and teal (default) |
| Ember | [config/themes/Ember.lua](../config/themes/Ember.lua) | Charcoal, crimson and amber |
| Parchment | [config/themes/Parchment.lua](../config/themes/Parchment.lua) | Light paper and dark ink, Friz Quadrata |

The choice is saved in `WarboardDB.theme` (nil for the default).

### Add a theme

1. Create `config/themes/Name.lua` that sets `ns.Themes.name = { label = "Name", color = {...}, type = {...}, space = base.space, size = base.size, alpha = {...} }`, with `local base = ns.Themes.warboard`.
2. Set every token the base theme has. `tests/simulation/scenarios/themes.lua` checks each shipped theme for missing tokens and valid values.
3. Reuse the base `space` and `size`. A switch must never move or resize frames, because secure frames cannot change in combat. Type faces and sizes may differ; outline flags stay the base's.
4. For a light theme, set `darkFrames = "warboard"`: tooltips and chat stay dark and take their colours from that theme.
5. List the file in both TOCs, after `config/Theme.lua`.

`Theme.Register(name, tokens)` adds a theme at runtime. Missing or invalid tokens fall back to the base theme.

## Theme API

`ns.Theme` ([ui/Theme.lua](../ui/Theme.lua)):

| Call | Use |
| --- | --- |
| `Theme.Color(name[, alpha])` | r, g, b, a of a colour |
| `Theme.Rgb(name)` | The live colour table (read only) |
| `Theme.Hex(name)` | `\|cffRRGGBB` for text in Warboard frames |
| `Theme.Font(role)` | face, size, flags of a type role |
| `Theme.Space(name)`, `Theme.Size(name)`, `Theme.Alpha(name)` | Number tokens |
| `Theme.Text(parent, role[, color])` | New FontString in a role and colour |
| `Theme.SetRole(fs, role)` | Change a text's role |
| `Theme.Paint(region, color[, alpha, mode])` | Colour a texture, status bar or text |
| `Theme.Tint(region, color[, alpha])` | Vertex colour on a textured region |
| `Theme.Fill(parent, layer, color[, alpha])` | New solid texture |
| `Theme.Shadow(fs, color)` | Text shadow in a colour |
| `Theme.Backdrop(frame[, opts])` | Panel fill and border; follows Background opacity, Border and Frameless |
| `Theme.Unpaint(region)` | Stop repainting a region |
| `Theme.TipLine(tt, text[, color, wrap])` | Tooltip line |
| `Theme.TipColor(name)`, `Theme.TipHex(name)` | Colours for Blizzard's dark frames (tooltips, chat) |
| `Theme.OnChange(fn)` | Run `fn` after every repaint, for state kept outside regions |
| `Theme.Use(name)` | Switch and save; false if the theme does not exist |
| `Theme.Names()`, `Theme.Label(name)`, `Theme.Current()`, `Theme.Register(name, tokens)` | The theme list |

Regions made or painted through the API are remembered and repainted on a switch. To colour a painted region another way, call `Theme.Unpaint` first. Sizes and spacing are read when a widget is built.

## Kit

`ns.Kit` ([ui/kit/](../ui/kit/)) builds the shared controls from tokens. They are plain frames, so they work in combat.

| File | Controls |
| --- | --- |
| [Controls.lua](../ui/kit/Controls.lua) | `Kit.Button` (tones, disabled state), `Kit.Paint`, `Kit.Input`, `Kit.Tab`, `Kit.Caption`, `Kit.Section`, `Kit.Chip`, `Kit.Card` |
| [Fields.lua](../ui/kit/Fields.lua) | `Kit.Toggle`, `Kit.Stepper`, `Kit.Select` |
| [Lists.lua](../ui/kit/Lists.lua) | `Kit.Dropdown`: autocomplete (`Attach`) and choice lists (`Open`) |
| [Dialog.lua](../ui/kit/Dialog.lua) | `Kit.Dialog` (header, accent bar, close button, drag, saved position), `Kit.CopyBox`, `Kit.HudWindow` (battleground panels), `Kit.SavedPoint` / `Kit.SavePoint` / `Kit.PlaceWindow` |

Dialog positions are saved in `WarboardDB.windows[key]`. A dialog's close button is `frame.close`; the Warboard window hides it while it shows the dialog.

[bounty/Widgets.lua](../bounty/Widgets.lua) keeps the old `ns.Widgets` names over the kit. New code uses `ns.Kit`.

## Rules

- No numeric colours or `|cff` codes outside `config/Theme.lua` and `config/themes/`. `tests/validate.py` fails on them. Class colours come from the game.
- Use type roles, not font paths and sizes.
- Use `Theme.TipLine`, `Theme.TipColor` or `Theme.TipHex` for tooltips and chat, so a light theme stays readable on Blizzard's dark frames.
- Overlays over the game world (capture bars, map pins, target marker) use their own `hud*`, `capPlate*` and `mapMark` tokens, which light themes keep bright.
