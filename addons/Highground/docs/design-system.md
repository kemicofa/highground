# Design system

[Documentation](README.md) · [Development](development.md)

HighgroundKit provides named **tokens** for colours, typography, spacing, control sizes and motion across the addon family. Runtime code reads colour tokens; client-provided class colours are handled separately. A theme changes those values and repaints registered regions.

## Tokens

The base theme `highground` in [libs/config/Theme.lua](../../../libs/HighgroundKit/config/Theme.lua) defines every token:

| Group | Value | Examples |
| --- | --- | --- |
| `color` | `{ r, g, b[, a] }` | `bg`, `surface`, `border`, `text`, `textMuted`, `accent`, `gold`, `danger`, `factionA`, `chipDef`, `capPlate` |
| `type` | `{ face, size[, flags] }` | `body`, `heading`, `title`, `timer`, `rowName`, `badgeCount` |
| `space` | pixels | `xs` 2, `sm` 4, `md` 8, `lg` 12, `xl` 16 |
| `size` | pixels | `control`, `input`, `header`, `tab`, `row`, `icon` |
| `alpha` | 0–1 | `button`, `card`, `dialog`, `disabled`, `page` |
| `motion` | seconds | `press` .06, `hover` .12, `focus` .14, `select` .16, `enter` .18, `menu` .20, `page` .20, `expand` .24, `exit` .10 |

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
5. List the file after `libs/config/Theme.lua` in every TOC that loads the theme system (all six public addons; HighgroundBountyData has no UI). Run the full test suite and the contrast scenarios.

`Theme.Register(name, tokens)` adds a theme at runtime. Missing or invalid tokens fall back to the base theme.

### Accessibility and visual hierarchy

The palette checks use the W3C contrast calculations: at least [4.5:1 for normal text](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) and [3:1 for meaningful control boundaries and indicators](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html). They include hover and selection overlays, inverse text on filled buttons, macro variants, class names, world badges, and health fills with zebra and target tints. These are contrast targets for the authored surfaces, not a claim that the entire WoW interface meets WCAG.

- `border` and `borderAccent` are quiet decorative seams. `controlBorder` identifies fields and unchecked toggles; `focus` supplies a two-pixel input underline. `titleText` separates window titles from body copy.
- Actions and selection use `accent`. Gold identifies rewards. Selected navigation has a side marker; tabs have a raised face and underline; recipe choices have diamonds and independent options have ticks; status chips include text. [Colour is not the only cue](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html).
- `chipBg` is opaque, keeping small status text readable over health bars. Class-coloured text adjusts toward the theme's ink when necessary; class strips, icons and bars retain the game's colours.
- All text roles are at least 10 logical pixels before user text/UI scaling. Body copy uses Barlow, data uses JetBrains Mono, and Azeroth uses Friz only for titles. Standard buttons and list rows are 24 logical pixels high. Compact combat layouts retain their density and can be enlarged through Appearance.
- Settings, menus and dialogs use opaque reading surfaces at rest. Dialog entrances start at 88% opacity; page content starts at 94%. Popup menus fade from transparent to opaque over 200 ms. HUD opacity defaults to 100%; an explicitly saved opacity still wins. Frameless mode, custom fonts, reduced scaling and transparency can change readability over game scenery.
- `Core.db.reducedMotion` makes ongoing cues steady, makes interface transitions instant, and suppresses rank flashes and target zoom, including animations already playing. The preference persists separately from appearance resets. `ns.Motion` handles interface transitions; `Core.MotionGroup` and `Core.Bounce` handle tactical cues.
- Blizzard chat/tooltips and world overlays keep their dark-surface palette when Parchment is selected. Text on trinket icons uses `hudGold`, not Parchment's dark reward ink.

For a portable visual comparison, run `python3 tools/theme_preview.py` from the repository root and open `dist/theme-preview.html`. It reads the Lua palettes and embeds the bundled fonts; its layout is a specimen rather than an in-game rendering, and the game-supplied Friz font uses a system serif fallback there. For interactive hover, press, focus, page and entrance examples, run `python3 tools/motion_preview.py` and open `dist/motion-preview.html`. Its timing and opacity come from the same Lua tokens, with a reduced-motion switch and system-preference support.

## Motion

[libs/ui/Motion.lua](../../../libs/HighgroundKit/ui/Motion.lua) uses cubic ease-out without overshoot. One shared update frame runs only while transitions are active. A new target reverses from the current value; repeated refreshes of the same target do not restart it. Alpha effects keep geometry fixed; plain sidebar accordions also animate their layout. Secure frames and attributes are never moved by these effects.

- Hover fades in and out. Press feedback crossfades a stronger tint without moving the label or hit area. Disabling or hiding a control clears both states.
- Focus, checked state and selected markers update immediately. Their entrance starts visibly; losing focus or selection removes the marker immediately. Silent settings refreshes do not animate checks.
- Dialog entrances and hub page changes use shallow fades. Nested windows share the parent's entrance. Popup menus have a full fade-in; autocomplete updates in place while typing without restarting that entrance.
- The hub's Targeting and World & PvP groups expand and collapse over 240 ms. A clipped viewport reveals their rows, the chevron turns, and following sections move with the current height. Only fully revealed rows accept mouse input; collapsing disables their input immediately. Closing the hub settles unfinished expansion, and text-size changes reflow at the current progress.
- Close, Escape, click-away and page borrowing keep their synchronous lifecycle. No outgoing window remains visible or intercepts input while a closing animation plays.
- Reduced motion immediately settles every active transition and retains the final state. Turning motion back on never replays old interactions.

| Call | Use |
| --- | --- |
| `Theme.Motion(name)` | Duration in seconds; invalid registered values fall back to the base theme |
| `Motion.Alpha(region, target[, duration])` | Animate alpha only; duration is a token name or seconds, with `0` immediate |
| `Motion.Value(owner, from, target, duration, apply)` | Animate a scalar on a plain frame; a stable `apply(owner, value)` callback draws each step |
| `Motion.Show(texture, on[, duration])` | Fade a decorative texture; hide it when its fade-out completes |
| `Motion.Mark(texture, on[, immediate, duration])` | Reveal a semantic mark, or remove it immediately |
| `Motion.Reveal(region[, duration, from])` | Shallow entrance, skipping nested or repeated entrances; owns alpha through the endpoint `1` |
| `Motion.Stop(region[, alpha])`, `Motion.IsPlaying(region)` | Cancel or inspect a transition |
| `Motion.Finish(region)` | Settle the requested endpoint, including a layout callback |
| `Kit.Feedback(frame[, opts])` | Shared hover and optional press layers; supplies `frame:ResetFeedback()` |
| `Kit.Focus(box, edge, line)` | Input/editor focus boundary and underline |
| `Kit.Entrance(frame[, duration, from])` | Attach a cancellable entrance to normal Show/Hide events; `from` is an optional alpha token |

Use fades on decorative layers or plain windows. Keep live health, timers, combat target changes and combat layout updates immediate. Use `Motion.Value` for plain layout owners such as sidebar accordions, and `Motion.Alpha` when visibility belongs to another owner; never pass a secure frame to `Motion.Show` or `Motion.Mark`.

## Theme API

`ns.Theme` ([libs/ui/Theme.lua](../../../libs/HighgroundKit/ui/Theme.lua)):

| Call | Use |
| --- | --- |
| `Theme.Color(name[, alpha])` | r, g, b, a of a colour |
| `Theme.Rgb(name)` | The live colour table (read only) |
| `Theme.Hex(name)` | `\|cffRRGGBB` for text in Highground frames |
| `Theme.Font(role)` | face, size, flags of a type role |
| `Theme.Space(name)`, `Theme.Size(name)`, `Theme.Alpha(name)` | Number tokens |
| `Theme.Motion(name)` | Motion duration tokens |
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

`ns.Kit` ([libs/ui/kit/](../../../libs/HighgroundKit/ui/kit/)) builds shared controls from tokens. They are plain frames, so they work in combat.

| File | Controls |
| --- | --- |
| [Controls.lua](../../../libs/HighgroundKit/ui/kit/Controls.lua) | `Kit.Button` (tones, disabled state), `Kit.Choice` (radio/check indicators), `Kit.Outline` (optional inset), `Kit.Bevel` (theme-controlled edge relief), `Kit.Paint`, `Kit.Input`, `Kit.Tab`, `Kit.Tooltip`, `Kit.ClassIcon`, `Kit.Caption`, `Kit.Section`, `Kit.Chip`, `Kit.Card` |
| [Feedback.lua](../../../libs/HighgroundKit/ui/kit/Feedback.lua) | `Kit.Feedback`, `Kit.Focus`, `Kit.Entrance`: shared interaction and lifecycle effects |
| [Fields.lua](../../../libs/HighgroundKit/ui/kit/Fields.lua) | `Kit.Toggle`, `Kit.Stepper`, `Kit.Select` |
| [Lists.lua](../../../libs/HighgroundKit/ui/kit/Lists.lua) | `Kit.Dropdown`: autocomplete (`Attach`) and choice lists (`Open`) |
| [Workspace.lua](../../../libs/HighgroundKit/ui/kit/Workspace.lua) | `Kit.ScrollArea`, `Kit.Editor`: independent scroll areas, themed draggable thumbs, caret visibility and focus boundaries |
| [Ornament.lua](../../../libs/HighgroundKit/ui/kit/Ornament.lua) | `Kit.Inlay`: static logarithmic corner curves; Azeroth adds an inset rim and symmetric sine-curve flourish in the bottom margin, with no input interception |
| [Dialog.lua](../../../libs/HighgroundKit/ui/kit/Dialog.lua) | `Kit.Dialog` (header, accent bar, close button, drag, saved position), `Kit.CopyBox`, `Kit.SavedPoint` / `Kit.SavePoint` / `Kit.PlaceWindow` |

Dialog positions are saved in `Core.db.windows[key]` (`HighgroundDB`, or `HighgroundMacrosDB` in Highground Macros). A dialog's close button is `frame.close`; the Highground window hides it while it shows the dialog.

[libs/ui/Browser.lua](../../../libs/HighgroundKit/ui/Browser.lua) adds `Kit.Browser` for searchable journals and claim lists.

HUD panels (timers, flags, arena, nearby) use `Timers.MakeWindow` ([libs/ui/Windows.lua](../../../libs/HighgroundKit/ui/Windows.lua)) for the windows and [libs/ui/Hud.lua](../../../libs/HighgroundKit/ui/Hud.lua) for their rows (`Hud.UnitRow`, `Hud.Surface`, `Hud.PaintClass`). Both are in the HighgroundKit library next to the kit; addons that need no HUD window, like Highground Macros, don't load them.

[libs/bounty/Widgets.lua](../../../libs/HighgroundKit/bounty/Widgets.lua) keeps the old `ns.Widgets` names over the kit. New code uses `ns.Kit`.

Bounty navigation starts at the board: an empty personal board explains choosing a player, choosing an audience and reporting a kill. Keep My bounties, Guild board and Shared board primary; suggestions and settings belong under More tools. Common tasks take at most two actions, and less frequent tasks at most three, including their final save or publish action. Keep **View bounty** one click away and row-specific secondary actions in **More**, without nested menus. The overview shows the selected target and all relevant contributions together. Guild review status uses a labelled, coloured badge.

Forms, details, claims, preferences and suggestion reports use `Bounty.Widgets.ShowPage` to replace the board contents at the same position and size, including inside the hub. Each has a labelled way back; returning preserves the board's filters and page, while a successful save returns to My bounties with feedback. Scroll long forms instead of moving their save controls out of reach. Only previews and chat imports use independent `Bounty.Widgets.ShowWindow` popups. Both paths keep an opaque backdrop and `FULLSCREEN_DIALOG` strata during entrance effects.

## Rules

- No numeric colours or `|cff` codes outside `config/Theme.lua` and `config/themes/`. `tests/validate.py` fails on them. Class colours come from the game.
- Use type roles, not font paths and sizes. Use `Theme.PaintClass` for class-coloured text; raw game colours remain appropriate for class strips and icons.
- Use `Theme.TipLine`, `Theme.TipColor` or `Theme.TipHex` for tooltips and chat, so a light theme stays readable on Blizzard's dark frames.
- Overlays over the game world (capture bars, map pins, target marker) use their own `hud*`, `capPlate*` and `mapMark` tokens, which light themes keep bright.

Macro completion uses the edit box's native `OnCursorChanged` rectangle, accounting for its scroll offset. The popup chooses available space above or below the line, fits its row count to the viewport, and closes when scrolled away from the caret. The explanation and save area remain outside that viewport. `Core.OnFontScaleChange` lets the builder and dropdown reflow when text size changes. Large dialog headers place metadata beside the title instead of spilling into the content.

A local geometry preview can be generated with `python3 tools/macro_preview.py --theme azeroth --state completion` from the repository root (also `--state empty`, `expanded`, or `hub`, and `--scale 1.5`). It renders the running simulated frame tree to `dist/`; font metrics and native game rendering remain approximate.

## Keep the game first

- Open no configuration window on first login. Explain the next useful action in context; make help available from Home.
- Show primary controls first. Extra markers, tuning and sharing belong in clearly named menus or folded sections. Folding a section never changes its values.
- Prefer one primary action per item. Macro presets use **Use macro**, saved ones use **Edit macro**, and advanced actions live under **More**.
- Write out targets and destinations. Introduce a focus as a second target; explain the action-bar step after saving a macro. Offer remembered, optional highlighted code on preset cards for readers who prefer it; keep editing in the editor and technical history in hover details.
- An empty state should explain how to get content. Distinguish no search matches, a disabled feature, missing guild membership and unobserved game state.
- Preserve explicit panel positions and existing feature choices. Default layouts must leave space for other panels. Cover both ordinary and enlarged text in the simulator, then verify native rendering in the game.

The [UI audit](ui-audit.md) records the changes and validation limits for this pass.
