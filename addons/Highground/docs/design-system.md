# Design system

[Documentation](README.md) · [Development](development.md)

Every colour, font, spacing and size in Highground's UI is a named **token**. Code asks for a token by name and never writes a number for a colour. A theme is a set of token values, so switching themes repaints everything.

## Tokens

The base theme `highground` in [libs/config/Theme.lua](../../../libs/HighgroundKit/config/Theme.lua) defines every token:

| Group | Value | Examples |
| --- | --- | --- |
| `color` | `{ r, g, b[, a] }` | `bg`, `surface`, `border`, `text`, `textMuted`, `accent`, `gold`, `danger`, `factionA`, `chipDef`, `capPlate` |
| `type` | `{ face, size[, flags] }` | `body`, `heading`, `title`, `timer`, `rowName`, `badgeCount` |
| `space` | pixels | `xs` 2, `sm` 4, `md` 8, `lg` 12, `xl` 16 |
| `size` | pixels | `control`, `input`, `header`, `tab`, `row`, `icon` |
| `alpha` | 0–1 | `button`, `card`, `dialog`, `disabled`, `page` |

Faces are `bold`, `semi`, `medium` (Barlow Condensed), `mono` (JetBrains Mono) and `friz` (Friz Quadrata, the game's font).

`ns.ThemeTokens` holds the live values. Its tables are updated in place on a theme switch, so a colour table kept at load time follows the switch. [libs/config/UI.lua](../../../libs/HighgroundKit/config/UI.lua) keeps a few older colour names (`ns.UIConfig.colors`) that point at the same tables, plus panel sizes.

## Themes

| Theme | File | Look |
| --- | --- | --- |
| Highground | [libs/config/Theme.lua](../../../libs/HighgroundKit/config/Theme.lua) | Cool slate, soft teal and neutral text (default) |
| Ember | [libs/config/themes/Ember.lua](../../../libs/HighgroundKit/config/themes/Ember.lua) | Smoked charcoal and copper; red is reserved for danger |
| Parchment | [libs/config/themes/Parchment.lua](../../../libs/HighgroundKit/config/themes/Parchment.lua) | Muted linen, charcoal ink and pine accents |
| Azeroth | [libs/config/themes/Azeroth.lua](../../../libs/HighgroundKit/config/themes/Azeroth.lua) | Obsidian, bronze trim and antique gold; Friz Quadrata window titles |

The choice is saved in each addon's `Core.db.theme` (nil for the default). Highground has the Appearance page; every standalone addon has a theme picker, text-size control and Reduced motion toggle in its settings. Existing theme names and saved opacity, font and layout preferences remain valid.

### Add a theme

1. Create `libs/HighgroundKit/config/themes/Name.lua`, calling `ns.DefineTheme("name", { label = "Name", description = "Short description", color = {...}, type = {...}, alpha = {...} })`. `ns.ThemeColor("rrggbb"[, alpha])` converts an sRGB hex colour to a token.
2. Override the palette's differences. `DefineTheme` resolves a complete, independent copy of the base tokens at load time, so shared typography and semantic colours cannot drift. `tests/simulation/scenarios/themes.lua` checks the resolved themes for missing tokens and valid values.
3. Keep the base spacing, dimensions, type sizes and outline flags. A switch never moves or resizes frames, including secure frames in combat. Reserve decorative faces for window titles; body text and numbers share the same faces across themes.
4. For a light theme, set `darkFrames = "highground"`: tooltips and chat stay dark and take their colours from that theme.
5. List the file after `libs/config/Theme.lua` in both TOCs of **every** addon. Run the full test suite and the contrast scenarios.

`Theme.Register(name, tokens)` adds a theme at runtime. Missing or invalid tokens fall back to the base theme.

### Accessibility and visual hierarchy

The palette checks use the W3C contrast calculations: at least [4.5:1 for normal text](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) and [3:1 for meaningful control boundaries and indicators](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html). They include hover and selection overlays, inverse text on filled buttons, macro variants, class names, world badges, and health fills with zebra and target tints. These are contrast targets for the authored surfaces, not a claim that the entire WoW interface meets WCAG.

- `border` and `borderAccent` are quiet decorative seams. `controlBorder` identifies fields and unchecked toggles; `focus` supplies a two-pixel input underline. `titleText` separates window titles from body copy.
- Actions and selection use `accent`. Gold identifies rewards. Selected navigation has a side marker; tabs have a raised face and underline; recipe choices have diamonds and independent options have ticks; status chips include text. [Colour is not the only cue](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html).
- `chipBg` is opaque, keeping small status text readable over health bars. Class-coloured text adjusts toward the theme's ink when necessary; class strips, icons and bars retain the game's colours.
- All text roles are at least 10 logical pixels before user text/UI scaling. Body copy uses Barlow, data uses JetBrains Mono, and Azeroth uses Friz only for titles. Standard buttons and list rows are 24 logical pixels high. Compact combat layouts retain their density and can be enlarged through Appearance.
- Settings, menus and dialogs use opaque reading surfaces. HUD opacity now defaults to 100%; an explicitly saved opacity still wins. Frameless mode, custom fonts, reduced scaling and transparency can change readability over game scenery.
- `Core.db.reducedMotion` makes ongoing cues steady and suppresses rank flashes and target zoom, including animations already playing. The preference persists separately from appearance resets. `Core.MotionGroup` and `Core.Bounce` are the shared animation entry points.
- Blizzard chat/tooltips and world overlays keep their dark-surface palette when Parchment is selected. Text on trinket icons uses `hudGold`, not Parchment's dark reward ink.

For a portable visual comparison, run `python3 tools/theme_preview.py` from the repository root and open `dist/theme-preview.html`. It reads the Lua palettes and embeds the bundled fonts; its layout is a specimen rather than an in-game rendering, and the game-supplied Friz font uses a system serif fallback there.

## Theme API

`ns.Theme` ([libs/ui/Theme.lua](../../../libs/HighgroundKit/ui/Theme.lua)):

| Call | Use |
| --- | --- |
| `Theme.Color(name[, alpha])` | r, g, b, a of a colour |
| `Theme.Rgb(name)` | The live colour table (read only) |
| `Theme.Hex(name)` | `\|cffRRGGBB` for text in Highground frames |
| `Theme.Font(role)` | face, size, flags of a type role |
| `Theme.Space(name)`, `Theme.Size(name)`, `Theme.Alpha(name)` | Number tokens |
| `Theme.Text(parent, role[, color])` | New FontString in a role and colour |
| `Theme.SetRole(fs, role)` | Change a text's role |
| `Theme.Paint(region, color[, alpha, mode])` | Colour a texture, status bar or text |
| `Theme.PaintClass(text, color)`, `Theme.ClassColor(color)` | Contrast-adjusted class ink; repaints idle text on theme changes |
| `Theme.Tint(region, color[, alpha])` | Vertex colour on a textured region |
| `Theme.Fill(parent, layer, color[, alpha])` | New solid texture |
| `Theme.Shadow(fs, color)` | Text shadow in a colour |
| `Theme.Backdrop(frame[, opts])` | Panel fill and border; `opts.alpha` accepts a number or live alpha token name |
| `Theme.Unpaint(region)` | Stop repainting a region |
| `Theme.TipLine(tt, text[, color, wrap])` | Tooltip line |
| `Theme.TipColor(name)`, `Theme.TipHex(name)` | Colours for Blizzard's dark frames (tooltips, chat) |
| `Theme.OnChange(fn)` | Run `fn` after every repaint, for state kept outside regions |
| `Theme.Use(name)` | Switch and save; false if the theme does not exist |
| `Theme.Sync([deferFonts])` | Load the saved theme and repaint; an addon calls it once its saved variables are loaded |
| `Theme.Names()`, `Theme.Label(name)`, `Theme.Description([name])`, `Theme.Current()`, `Theme.Register(name, tokens)` | The theme list and descriptions |

Regions made or painted through the API are remembered and repainted on a switch. To colour a painted region another way, call `Theme.Unpaint` first. Sizes and spacing are read when a widget is built.

## Kit

`ns.Kit` ([ui/kit/](../ui/kit/)) builds the shared controls from tokens. They are plain frames, so they work in combat.

| File | Controls |
| --- | --- |
| [Controls.lua](../../../libs/HighgroundKit/ui/kit/Controls.lua) | `Kit.Button` (tones, disabled state), `Kit.Choice` (radio/check indicators), `Kit.Outline` (optional inset), `Kit.Bevel` (theme-controlled edge relief), `Kit.Paint`, `Kit.Input`, `Kit.Tab`, `Kit.Tooltip`, `Kit.ClassIcon`, `Kit.Caption`, `Kit.Section`, `Kit.Chip`, `Kit.Card` |
| [Fields.lua](../../../libs/HighgroundKit/ui/kit/Fields.lua) | `Kit.Toggle`, `Kit.Stepper`, `Kit.Select` |
| [Lists.lua](../../../libs/HighgroundKit/ui/kit/Lists.lua) | `Kit.Dropdown`: autocomplete (`Attach`) and choice lists (`Open`) |
| [Workspace.lua](../../../libs/HighgroundKit/ui/kit/Workspace.lua) | `Kit.ScrollArea`, `Kit.Editor`: independent scroll areas, themed draggable thumbs, caret visibility and focus boundaries |
| [Ornament.lua](../../../libs/HighgroundKit/ui/kit/Ornament.lua) | `Kit.Inlay`: static logarithmic corner curves; Azeroth adds an inset rim and symmetric sine-curve flourish in the bottom margin, with no input interception |
| [Dialog.lua](../../../libs/HighgroundKit/ui/kit/Dialog.lua) | `Kit.Dialog` (header, accent bar, close button, drag, saved position), `Kit.CopyBox`, `Kit.SavedPoint` / `Kit.SavePoint` / `Kit.PlaceWindow` |

Dialog positions are saved in `Core.db.windows[key]` (`HighgroundDB`, or `HighgroundMacrosDB` in Highground Macros). A dialog's close button is `frame.close`; the Highground window hides it while it shows the dialog.

HUD panels (timers, flags, arena, nearby) use `Timers.MakeWindow` ([libs/ui/Windows.lua](../../../libs/HighgroundKit/ui/Windows.lua)) for the windows and [libs/ui/Hud.lua](../../../libs/HighgroundKit/ui/Hud.lua) for their rows (`Hud.UnitRow`, `Hud.Surface`, `Hud.PaintClass`). Both are in the HighgroundKit library next to the kit; addons that need no HUD window, like Highground Macros, don't load them.

[features/bounties/bounty/Widgets.lua](../../HighgroundBounties/src/bounty/Widgets.lua) keeps the old `ns.Widgets` names over the kit. New code uses `ns.Kit`.

## Rules

- No numeric colours or `|cff` codes outside `config/Theme.lua` and `config/themes/`. `tests/validate.py` fails on them. Class colours come from the game.
- Use type roles, not font paths and sizes. Use `Theme.PaintClass` for class-coloured text; raw game colours remain appropriate for class strips and icons.
- Use `Theme.TipLine`, `Theme.TipColor` or `Theme.TipHex` for tooltips and chat, so a light theme stays readable on Blizzard's dark frames.
- Overlays over the game world (capture bars, map pins, target marker) use their own `hud*`, `capPlate*` and `mapMark` tokens, which light themes keep bright.

Macro completion uses the edit box's native `OnCursorChanged` rectangle, accounting for its scroll offset. The popup chooses available space above or below the line, fits its row count to the viewport, and closes when scrolled away from the caret. The explanation and save area remain outside that viewport. `Core.OnFontScaleChange` lets the builder and dropdown reflow when text size changes. Large dialog headers place metadata beside the title instead of spilling into the content.

A local geometry preview can be generated with `python3 tools/macro_preview.py --theme azeroth --state completion` from the repository root (also `--state empty`, `expanded`, or `hub`, and `--scale 1.5`). It renders the running simulated frame tree to `dist/`; font metrics and native game rendering remain approximate.
