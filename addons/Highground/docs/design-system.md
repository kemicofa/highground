# Design system

[Documentation](README.md) · [Development](development.md)

HighgroundKit provides named **tokens** for colours, typography, spacing, control sizes and motion across the addon family. Runtime code reads colour tokens; client-provided class colours are handled separately. A theme changes those values and repaints registered regions.

The visual direction is an illuminated command console: obsidian steel, warm gold, cut-metal corners, deep wells and solid reading surfaces. Primary actions, selected navigation and featured cards have exterior light; ordinary controls catch light on hover. The suggested target gains a gold halo, an attack opening adds a steady-paced pulse, and urgent timer rows receive a warning rim. These cues accompany the existing labels and never alter the secure click target.

References: [AzeriteUI](https://github.com/GoldpawsStuff/AzeriteUI5) for strong silhouettes and ornamental framing, [Narcissus](https://www.curseforge.com/wow/addons/narcissus) for a prominent focal area, and [Dialogue UI](https://www.curseforge.com/wow/addons/dialogueui) for presentation and hierarchy. These are design interpretations; the implementation uses original procedural textures and the existing Highground crest.

## Tokens

The base theme `highground` in [libs/config/Theme.lua](../../../libs/HighgroundKit/config/Theme.lua) defines every token:

| Group | Value | Examples |
| --- | --- | --- |
| `color` | `{ r, g, b[, a] }` | `bg`, `surface`, `border`, `text`, `textMuted`, `accent`, `gold`, `danger`, `factionA`, `chipDef`, `capPlate` |
| `type` | `{ face, size[, flags] }` | `body`, `heading`, `title`, `timer`, `rowName`, `badgeCount` |
| `space` | pixels | `xs` 2, `sm` 4, `md` 8, `lg` 12, `xl` 16 |
| `size` | pixels | `control`, `input`, `header`, `tab`, `row`, `icon`, `choice`, `scrollGutter`, `scrollThumbMin` |
| `alpha` | 0–1 | `button`, `card`, `dialog`, `disabled`, `page`, `glow`, `elevation`, `sheen`, `headerLight`, `edgeLight`, `chipEdge`, `flash` |
| `motion` | seconds | `press` .06, `hover` .12, `focus` .14, `select` .16, `enter` .24, `menu` .20, `page` .20, `expand` .24, `exit` .10, `sweep` .72, `pulse` 1.4 per half-cycle, `flash` .90, `pop` .30, `slide` .18, `progress` .20 |

Faces are `bold`, `semi`, `medium` (Barlow Condensed), `mono` (JetBrains Mono) and `friz` (Friz Quadrata, the game's font).

`ns.ThemeTokens` holds the live values. Its tables are updated in place on a theme switch, so a colour table kept at load time follows the switch. [libs/config/UI.lua](../../../libs/HighgroundKit/config/UI.lua) keeps a few older colour names (`ns.UIConfig.colors`) that point at the same tables, plus panel sizes.

## Themes

| Theme | File | Look |
| --- | --- | --- |
| Highground | [libs/config/Theme.lua](../../../libs/HighgroundKit/config/Theme.lua) | Default: obsidian steel, luminous gold, sculpted edges and persistent class surfaces; the token inheritance base |
| Ember | [libs/config/themes/Ember.lua](../../../libs/HighgroundKit/config/themes/Ember.lua) | Smoked charcoal, copper light and warm metal edges; red is reserved for danger |
| Parchment | [libs/config/themes/Parchment.lua](../../../libs/HighgroundKit/config/themes/Parchment.lua) | Muted linen, charcoal ink and pine accents |
| Azeroth | [libs/config/themes/Azeroth.lua](../../../libs/HighgroundKit/config/themes/Azeroth.lua) | Obsidian, bronze trim and antique gold; Friz Quadrata window titles |
| Class Colors | [libs/config/themes/ClassColors.lua](../../../libs/HighgroundKit/config/themes/ClassColors.lua) | Highground branding with stronger class-coloured enemy surfaces |
| Dark | [libs/config/themes/Dark.lua](../../../libs/HighgroundKit/config/themes/Dark.lua) | Near-black wells, neutral graphite panels and violet accents, which also replace bounty gold; keeps Highground's class surfaces |

The choice is saved in each addon's `Core.db.theme` (nil for Highground, selected by `ns.DEFAULT_THEME`; choosing Class Colors stores `"classcolors"`). Highground remains the inheritance base for missing or invalid tokens. Highground has Shared appearance and addon-specific Appearance pages; every standalone addon has a theme picker, text-size control and Reduced motion toggle in its settings. Explicit saved theme names and saved opacity, font and layout preferences remain valid.

Highground includes class surfaces by default. Choose **Class Colors** in Appearance, or use `/hg theme classcolors`, for stronger tinting. Both keep class identity across the enemy row independently of health, including the Line health style and hidden health bars. Both use the same client/custom class colours as the class strip. The `alpha.classRow` token controls its maximum tint (0.40 in Highground and Dark, 0.55 in Class Colors, zero in the other presets); `Theme.EnemyRowColor` reduces the tint as needed for readable text over health, zebra, target and hover layers. Unknown classes keep a neutral surface. Dead and unseen rows retain their existing dimming, and target/focus marks and tactical chips keep their meanings.

### Add a theme

1. Create `libs/HighgroundKit/config/themes/Name.lua`, calling `ns.DefineTheme("name", { label = "Name", description = "Short description", color = {...}, type = {...}, alpha = {...} })`. `ns.ThemeColor("rrggbb"[, alpha])` converts an sRGB hex colour to a token.
2. Override the palette's differences. `DefineTheme` resolves a complete, independent copy of the base tokens at load time, so shared typography and semantic colours cannot drift. `tests/simulation/scenarios/themes.lua` checks the resolved themes for missing tokens and valid values.
3. Keep the base spacing, dimensions, type sizes and outline flags. A switch never moves or resizes frames, including secure frames in combat. Reserve decorative faces for window titles; body text and numbers share the same faces across themes.
4. For a light theme, set `darkFrames = "highground"`: tooltips and chat stay dark and take their colours from that theme.
5. List the file after `libs/config/Theme.lua` in every TOC that loads the theme system (Highground and six retained legacy hosts; the two data addons have no UI). Run the full test suite and the contrast scenarios.

`Theme.Register(name, tokens)` adds a theme at runtime. Missing or invalid tokens fall back to the base theme.

### Accessibility and visual hierarchy

The palette checks use the W3C contrast calculations: at least [4.5:1 for normal text](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) and [3:1 for meaningful control boundaries and indicators](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html). They include hover and selection overlays, inverse text on filled buttons, macro variants, class names, world badges, and health fills with zebra and target tints. These are contrast targets for the authored surfaces, not a claim that the entire WoW interface meets WCAG.

- `border` and `borderAccent` are quiet decorative seams. `controlBorder` identifies buttons, tabs, fields and unchecked toggles; `focus` supplies a two-pixel input underline and brighter hovered control rim. `titleText` separates window titles from body copy.
- Actions, recommendations and selection use forged-gold `accent`. Reward amounts use the lighter `gold` token with a currency label. Selected navigation has a side marker; tabs have a raised face and underline; recipe choices have diamonds and independent options have ticks; status chips include text. [Colour is not the only cue](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html).
- `chipBg` is opaque, keeping small status text readable over health bars. `Util.ClassColor` strengthens the saturation of stock class colours while retaining their familiar hues: Rogue yellow stays distinct from Priest white. Custom class colours take precedence. Class-coloured text lightens toward white or darkens toward black for contrast without shifting its hue; strips and bars use the stronger colours, and class icons keep their original artwork.
- All text roles are at least 10 logical pixels before user text/UI scaling. Body copy uses Barlow, data uses JetBrains Mono, and Highground, Class Colors and Azeroth use Friz only for window titles. Standard buttons and list rows are 24 logical pixels high. Compact combat layouts retain their density and can be enlarged through Appearance.
- Settings, menus and dialogs use opaque reading surfaces at rest. Dialog entrances start at 88% opacity; page content starts at 94%. Popup menus fade from transparent to opaque over 200 ms. HUD backgrounds use 65% of their saved opacity while idle by default, restoring the saved level on hover or while the cog menu is open. **Appearance → Panel transparency** disables this fade; **Background opacity** defaults to 100% and keeps explicit saved values. Text and icons do not participate in the background fade. Frameless mode, custom fonts, reduced scaling and transparency can change readability over game scenery.
- `Core.db.reducedMotion` makes ongoing cues steady, makes interface transitions instant, and suppresses rank flashes and target zoom, including animations already playing. The preference persists separately from appearance resets. `ns.Motion` handles interface transitions; `Core.MotionGroup` and `Core.Bounce` handle tactical cues.
- Blizzard chat/tooltips and world overlays keep their dark-surface palette when Parchment is selected. Text on trinket icons uses `hudGold`, not Parchment's dark reward ink.

The crest texture (`media/HighgroundCrest.tga`) ships in every public package as a 256px RGBA image with a transparent exterior. `Kit.Crest` centers it vertically in the hub header and welcome card; other palettes use a procedural summit in the same space. The minimap and addon compartment use `media/HighgroundIcon.tga`, a simplified 64px gold H derived from the wordmark, with its full transparent padding preserved. The minimap supplies a dark circular backing so the mark stays readable over map scenery. Asset provenance and prompts are recorded in `media/HighgroundCrest.txt`. `python3 tools/export_textures.py` exports every game texture from its source art at a budgeted power-of-two size (about twice its draw size); `tests/test_textures.py` keeps new textures on that list.

`Kit.Inlay` draws cut-metal brackets, corner facets, a double rim, exterior shadow and a soft halo. Combat panels use shorter brackets and a narrower light spill. `metalEdge`, `metalHighlight`, `metalShadow`, `alpha.ornament` and `alpha.crest` keep this decoration separate from controls. Frameless mode and a zero border suppress the corresponding HUD ornament and shadow. Parchment keeps its matte reading surfaces with `glow = 0` and `sheen = 0`.

Buttons and tabs have five-pixel rounded corners and a persistent control border, including sidebar navigation. Button and checkbox rims sit one pixel inside their bounds on a noninteractive layer above nearby fills and glows. Inactive tabs keep their filled face; the selected tab adds a raised surface, accent rim, inset underline and soft halo. Hover, press and sheen layers cover the whole rounded face, and the halo joins around its corners. Primary buttons retain their semantic border and halo after hover ends. Disabled buttons clear every hover and press band; focus light clears immediately on blur. Glows leave text on its solid backing. Contrast simulations include the brightest sheen combined with hover and press layers in every palette.

A health line follows the native status-bar fill texture, without reading secret health. Its `alpha.healthLine` is 0.85 in Highground and Class Colors. The line uses contrast-adjusted class ink; the class strip retains the original hue. Unknown health multiplies line opacity by `alpha.healthLineUnseen` (0.28), and repainting preserves that state. `attackEdge` supplies urgent outlines; `kill` remains readable label ink. Target and focus retain independent marks, including `TGT`, `FOC` and `T/F` on expanded board ranks. Class identity also appears on the suggested target, known flag carriers, journal names, macro recipes and known bounty players.

For a portable visual comparison, run `python3 tools/theme_preview.py` from the repository root and open `dist/theme-preview.html`. It reads the Lua palettes and class-surface calculations, embeds the bundled fonts and includes a health slider comparing Highground with Class Colors across all three enemy views. Its layout is a specimen rather than an in-game rendering, and the game-supplied Friz font uses a system serif fallback there. For interactive hover, press, focus, page and entrance examples, run `python3 tools/motion_preview.py` and open `dist/motion-preview.html`. Its timing and opacity come from the same Lua tokens, with a reduced-motion switch and system-preference support.

## Motion

[libs/ui/Motion.lua](../../../libs/HighgroundKit/ui/Motion.lua) uses cubic ease-out without overshoot. One shared update frame runs only while transitions are active. A new target reverses from the current value; repeated refreshes of the same target do not restart it. Alpha effects keep geometry fixed; plain sidebar accordions also animate their layout. Secure frames and attributes are never moved by these effects.

- Hover fades in and out. Press feedback crossfades a stronger tint without moving the label or hit area. Disabling or hiding a control clears both states.
- Focus, checked state and selected markers update immediately. Their entrance starts visibly; losing focus or selection removes the marker immediately. Silent settings refreshes do not animate checks.
- Dialog entrances and hub page changes use shallow fades. Nested windows share the parent's entrance. Popup menus have a full fade-in; autocomplete updates in place while typing without restarting that entrance.
- The hub's module and preference groups expand and collapse over 240 ms. A clipped viewport reveals their rows, the chevron turns, and following sections move with the current height. Only fully revealed rows accept mouse input; collapsing disables their input immediately. Closing the hub settles unfinished expansion, and text-size changes reflow at the current progress.
- Close, Escape, click-away and page borrowing keep their synchronous lifecycle. No outgoing window remains visible or intercepts input while a closing animation plays.
- Reduced motion immediately settles every active transition and retains the final state. Turning motion back on never replays old interactions.
- A single glint travels along the top edge when a window opens, an action is hovered, a selection changes or a new suggested target appears. Repeated refreshes do not restart it. Only decorative textures move; text and hit areas stay fixed. Closing cancels the glint immediately.
- A new kind of HUD timer row (a capture starting, a graveyard changing hands) flashes once. Opening a window, reordering rows or changing their scores does not.
- Featured cards and urgent signals breathe through native alpha animation groups. Hidden owners stop their groups; reduced motion keeps their light steady. Palettes with zero glow suspend these loops. There is no permanent Lua update loop for lighting.

The `ns.Motion` calls are listed under [motion calls](#motion-api-and-lifecycle). Related theme and kit helpers:

| Call | Use |
| --- | --- |
| `Theme.Motion(name)` | Duration in seconds; invalid registered values fall back to the base theme |
| `Motion.Alpha(region, alpha[, duration, ease])` | Alpha only; safe on protected frames in combat |
| `Motion.Show(region, on[, duration])`, alias `Motion.Fade` | Fade in, or fade out and hide at the end |
| `Motion.Reveal(region[, duration, from])`, `Motion.Mark(region, on[, immediate, duration])` | Shallow entrance; semantic marks that leave immediately |
| `Motion.Value(owner, from, to, duration, apply[, ease])` | A scalar drawn by a stable `apply(owner, value)` on a plain frame |
| `Motion.Progress(bar, value[, duration])` | Plain status-bar progress eased from the drawn value; the first and secret values are immediate |
| `Motion.Flash(region[, peak, duration, ease])`, `Motion.FlashCue(...)` | One-shot highlight on a region resting at alpha 0; `FlashCue` builds the handle without playing |
| `Motion.Pop(region[, scaleX, scaleY, duration])`, `Motion.PopCue(...)` | Brief scale up and back for attention |
| `Motion.Slide(region, dx, dy[, duration, ease])` | Entrance offset that settles at the region's own anchor |
| `Motion.Pulse(region, from, to[, duration])` | Looping alpha breath; `duration` is one half-cycle |
| `Motion.Stop(region[, alpha])`, `Motion.Finish(region)`, `Motion.IsPlaying(region)` | Cancel, settle at the endpoint, or inspect the driver transition |
| `Motion.Duration(token)`, `Motion.Smoothing(ease)`, `Motion.Locked(region)` | Resolve a token, a native smoothing name, or whether combat locks a protected frame |
| `Kit.Feedback(frame[, opts])` | Shared hover and optional press layers; supplies `frame:ResetFeedback()` |
| `Kit.Focus(box, edge, line)` | Input/editor focus boundary and underline |
| `Kit.Entrance(frame[, duration, from])` | Attach a cancellable entrance to normal Show/Hide events; `from` is an optional alpha token |

Use fades on decorative layers or plain windows. Keep live health, timers, combat target changes and combat layout updates immediate. Use `Motion.Value` for plain layout owners such as sidebar accordions, and `Motion.Alpha` when visibility belongs to another owner; never pass a secure frame to `Motion.Show` or `Motion.Mark`.

### Motion API and lifecycle

`ns.Motion` ([libs/ui/Motion.lua](../../../libs/HighgroundKit/ui/Motion.lua)) owns interface motion. Durations are `motion` tokens or seconds (`0` is immediate); token values are listed under [tokens](#tokens).

Easing names are `out` (cubic, default), `in`, `inOut` and `linear`; an unknown name is an error. Retargetable transitions run on one Lua driver that sleeps when idle and reuses its records. `Flash`, `Pop`, `Slide` and `Pulse` are native animation groups built once per region and wrapped by `Core.MotionGroup`. Cue handles have `:Play()`, `:Stop()`, `:IsPlaying()` and `.group`.

- Motion never delays state. Clicks, selection, focus, close, Escape and borrowing take effect immediately; windows and toasts close without an exit fade.
- The last request wins. Retargeting starts from the current value; repeating the same target does not restart. A transition started from a completion callback first advances on the next frame.
- A hidden region settles at its endpoint on the next frame. `Motion.Stop` cancels transitions and one-shot cues without running stale completions; loops keep their own handle, so owners stop them on hide.
- Reduced motion settles every transition immediately, shows cues at their resting state and never replays past interactions when turned off.
- Protected frames in combat keep their visibility: `Show`, `Fade` and `Mark` change alpha only, and a hidden frame waits for its owner. A frame faded out this way still receives clicks, because `EnableMouse` is restricted too; it is hidden on `PLAYER_REGEN_ENABLED` if it is still transparent and was not shown again. Owners of secure buttons keep their own combat rules for what those clicks do. `Slide` never runs on a protected frame; `Pop` skips them in combat. Never animate secure geometry with `Value`.
- Use `Motion.Progress` for every update of a bar it drives. Do not mix direct `SetAlpha` writes with an alpha transition on the same region; stop it first.
- Keep live health, timers and combat target changes immediate.

HUD windows ([libs/ui/Windows.lua](../../../libs/HighgroundKit/ui/Windows.lua)) are clamped to the screen and saved per character. `Timers.ValidPoint` rejects damaged saved spots, which fall back to the default. A position reset during combat moves secure windows when combat ends (`Timers.PlaceWhenSafe`); no event is registered otherwise. Only a drag that started moving the window saves it. `Timers.SecureShow` places, shows and reveals a window; `Timers.SecureHide` cancels that entrance, then hides it or, in combat, makes it transparent. Timer rows flash once when a new kind of row appears. Dialogs use `Kit.Dialog`: saved spots in `Core.db.windows`, Escape through `UISpecialFrames`, and one foreground tool through `Kit.Windows`. A dialog shown as a page inside another window (bounty pages on the board, pages the hub borrows) goes through `Kit.MountPage`: it hides its own shadow and glow, so the host's are the only ones, and dragging it runs the drag handlers of the nearest movable window holding it, including that window's lock and saved position; `Kit.UnmountPage` restores both. The `motion`, `motioncues`, `effects` and `windows` simulation groups cover these contracts.

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
| `Theme.EnemyRowColor(color)` | Contrast-bounded class surface for enemy rows; cached per palette and RGB |
| `Theme.Tint(region, color[, alpha])` | Vertex colour on a textured region |
| `Theme.Fill(parent, layer, color[, alpha])` | New solid texture |
| `Theme.Gradient(parent, layer, color, alpha, direction, from, to[, sub])` | Theme-aware linear light wash, using modern or legacy gradient APIs; vertical runs bottom to top |
| `Theme.Shadow(fs, color)` | Text shadow in a colour |
| `Theme.Backdrop(frame[, opts])` | Panel fill and border; `opts.alpha` accepts a number or live alpha token name |
| `Theme.Unpaint(region)` | Stop repainting a region |
| `Theme.TipLine(tt, text[, color, wrap])` | Tooltip line |
| `Theme.TipColor(name)`, `Theme.TipHex(name)` | Colours for Blizzard's dark frames (tooltips, chat) |
| `Theme.OnChange(fn)` | Run `fn` after every repaint, for state kept outside regions |
| `Theme.Use(name)` | Switch and save; false if the theme does not exist |
| `Theme.Sync([deferFonts])` | Load the saved theme and repaint; an addon calls it once its saved variables are loaded |
| `Theme.Names()`, `Theme.Label(name)`, `Theme.Description([name])`, `Theme.Current()`, `Theme.Register(name, tokens)` | The theme list and descriptions |

Regions made or painted through the API are remembered and repainted on a switch. Repeating the same token, alpha and painting mode skips native colour writes, including unchanged gradient endpoints. A palette change repaints registered regions, including hidden ones. Custom colour tables compare their components, so unchanged values skip writes and in-place edits still apply. Class text and HUD surfaces use this same path. To colour a painted region another way, call `Theme.Unpaint` first; this also invalidates the previous paint state. Sizes and spacing are read when a widget is built.

## Kit

### Navigation patterns

Page tabs form one strip attached to the content they select. Keep one page selected; clicking the selected tab preserves its content and never collapses it. The router owns navigation, permission redirects and Back/Forward history. Update the selected marker only after navigation succeeds, and restore the page's search, pagination and scroll when returning. Keep action buttons outside the tab strip.

Reputation separates **Organizations** and account-wide **Preferences** with persistent workspace tabs. An open organization's **Overview**, **Blacklist**, **Proposals**, **Members** and **History** belong to a second strip inside Organizations. Returning from Preferences restores the organization page; All organizations returns to the directory. Preferences remain available without organization membership.

Use a segmented control for a compact mode or filter within one view, such as the macro catalog's PvP/PvE mode. Use a disclosure with a chevron for optional content that opens and closes on repeated clicks, such as the macro builder's optional sections. Folding a section keeps its values. These patterns have different behavior and should remain visually distinct.

Tab labels must fit at the current text size. When a complete strip cannot fit, use a clearly labelled page selector with the same selection and availability rules. Never squeeze labels or silently remove destinations.

`ns.Kit` ([libs/ui/kit/](../../../libs/HighgroundKit/ui/kit/)) builds shared controls from tokens. They are plain frames, so they work in combat.

| File | Controls |
| --- | --- |
| [Controls.lua](../../../libs/HighgroundKit/ui/kit/Controls.lua) | `Kit.Button` (tones, disabled state), `Kit.Choice` (radio/check indicators), `Kit.BorderLayer` (inset control rim above fills), `Kit.Outline` (optional inset), `Kit.Bevel` (theme-controlled edge relief), `Kit.Paint`, `Kit.Input`, `Kit.Tab`, `Kit.Tooltip`, `Kit.ClassIcon`, `Kit.Caption`, `Kit.Section`, `Kit.Chip`, `Kit.Card` |
| [Feedback.lua](../../../libs/HighgroundKit/ui/kit/Feedback.lua) | `Kit.Feedback`, `Kit.Focus`, `Kit.Entrance`: shared interaction and lifecycle effects |
| [State.lua](../../../libs/HighgroundKit/ui/kit/State.lua) | `Kit.ResolveState(facts)` distinguishes blocked, empty, filtered and populated collections; `Kit.StatusText` resets text and its semantic tone together |
| [Effects.lua](../../../libs/HighgroundKit/ui/kit/Effects.lua) | `Kit.RoundedFill` / `Kit.PaintFill`, `Kit.RoundedOutline`; `Kit.Glow` with `SetActive(on, pulsing, immediate)` and `SetColor(token)`, `Kit.Sweep` with `Play()` / `Stop()`, `Kit.ButtonFinish`, `Kit.CardFinish`; noninteractive, theme-aware decoration |
| [Fields.lua](../../../libs/HighgroundKit/ui/kit/Fields.lua) | `Kit.Toggle`, `Kit.Stepper`, `Kit.Select` |
| [Lists.lua](../../../libs/HighgroundKit/ui/kit/Lists.lua) | `Kit.Dropdown`: autocomplete (`Attach`) and choice lists (`Open`) |
| [Layout.lua](../../../libs/HighgroundKit/ui/kit/Layout.lua) | `Kit.Paragraph`: wrapping text with natural height; `Kit.Place`: update a single anchor/size only when changed; `Kit.LayoutGrid`: equal-width controls that wrap to fit their labels; `Kit.Scale`, `Kit.LabelWidth`, `Kit.FitButton`: text-size growth and label-fitted widths |
| [ActionRow.lua](../../../libs/HighgroundKit/ui/kit/ActionRow.lua) | `Kit.ActionRow`: one-line label, optional description and trailing action, with full details on hover |
| [Blocks.lua](../../../libs/HighgroundKit/ui/kit/Blocks.lua) | `Kit.Badge`, `Kit.KeyValue`, `Kit.SectionCard`, `Kit.Hero`, `Kit.EmptyState`, `Kit.Toolbar`, `Kit.Segmented`, `Kit.ConfirmButton`, `Kit.Confirmation`; see [building blocks](#building-blocks) |
| [Tabs.lua](../../../libs/HighgroundKit/ui/kit/Tabs.lua) | `Kit.TabGroup`: connected page tabs, confirmed selection, counts, unavailable destinations and a compact page menu |
| [ProgressStepper.lua](../../../libs/HighgroundKit/ui/kit/ProgressStepper.lua) | `Kit.ProgressStepper`: connected workflow steps with numbered circles, completion checks and a highlighted current stage |
| [Workspace.lua](../../../libs/HighgroundKit/ui/kit/Workspace.lua) | `Kit.ScrollArea`, `Kit.VirtualList`, `Kit.ScrollText`, `Kit.Editor`: independent scroll areas, recycled list rows, themed draggable thumbs, automatic text sizing, caret visibility and focus boundaries |
| [Ornament.lua](../../../libs/HighgroundKit/ui/kit/Ornament.lua) | `Kit.Inlay`: faceted metal corners, double rim and exterior light; `Kit.Crest`: brand art or a procedural summit, with no input interception |
| [Header.lua](../../../libs/HighgroundKit/ui/kit/Header.lua) | `Kit.Header`: title, subtitle, crest and actions with a shared vertical center; `SetActions`, `SetTitle`, `SetSub`, `Layout` |
| [Windows.lua](../../../libs/HighgroundKit/ui/kit/Windows.lua) | `Kit.Windows`: one foreground tool across addon instances, hosted pages and child-dialog return paths |
| [Dialog.lua](../../../libs/HighgroundKit/ui/kit/Dialog.lua) | `Kit.Dialog` (header, accent bar, close button, drag, saved position), `Kit.MountPage` / `Kit.UnmountPage` (a dialog shown as a page of another window), `Kit.CopyBox`, `Kit.SavedPoint` / `Kit.SavePoint` / `Kit.PlaceWindow` |

`Kit.Tooltip(frame, lines, opts)` hooks a frame once; calling it again replaces the content. Leaving only closes a tooltip that frame opened, and hiding the frame closes its open tooltip, so page switches never leave one behind.

`Kit.Input(parent, width, caption, options)` accepts `placeholder` and `onChange(self, text, userInput)`. The placeholder follows typed and programmatic changes. Add extra handlers with `HookScript` so they preserve the built-in behavior. Search filtering and draft state remain with the feature.

`Kit.ActionRow(parent, { label = "Command", detail = "Description", action = "Open", onClick = function(button) ... end })` keeps text and its action on one line. Optional `role`, `color` and `tooltip` customize the label and hover details. The owner anchors the row and calls `row:Layout(width)` after width or font changes; the returned height includes the control. Narrow views hide the inline description while keeping it in the tooltip. Use a short action label, keep parameter forms separate, and set availability through `row.button:SetEnabled(on)`. Hover never invokes the action. Repeated layout reuses controls and skips unchanged native geometry writes.

Command references use this component for both addon pages and the combined list. Preview their actual simulated geometry with `python3 tools/macro_preview.py --state commands --theme highground`, adding `--chapter battlegrounds` for an addon or `--scale 1.5` for enlarged text. The HTML preview approximates native font metrics; in-client rendering remains a separate check.

`Kit.TabGroup(parent, { items = { { key = "organizations", label = "Organizations" }, { key = "settings", label = "Preferences" } }, onSelect = function(group, key) ... end })` creates a navigation strip. Anchor the page body below the group; it owns its height and reflows on width, font and theme changes. Selected tabs share a baseline with the body and have a solid face and accent top edge; inactive tabs remain plain labels with hover feedback. They do not use the raised action-button finish.

With `onSelect`, the owner navigates first and calls `SetSelected(key)` after acceptance, including redirects and Back/Forward. Without a callback, the group selects the requested page itself. `Request(key)` rejects unavailable destinations and skips repeated selection. `SetItemEnabled(key, enabled)` and `SetCount(key, count)` update existing controls. Use `Target(key)` for walkthrough highlights: it returns the native tab or the compact page-menu button. A menu retains unavailable pages as disabled rows; closing the group or changing availability closes stale menus. Selection and layout reuse frames, and unchanged selection performs no repaint. Page state belongs to the feature's bounded router history, not the component.

`Kit.ProgressStepper(parent, { steps = { "Target", "Reward", "Review" }, current = 1, tone = "gold", onSelect = function(self, index) ... end })` presents the entire workflow. Call `SetCurrent(index)` after validation; `#steps + 1` marks every step complete. Only completed steps invoke `onSelect`, so future stages cannot bypass validation. Omit the callback for a read-only indicator. The component owns its height and reflows labels when width, fonts or theme change; anchor the form beneath it. This is separate from `Kit.Stepper`, the numeric input.

Use `Kit.Paragraph(parent, role, color[, { nonSpaceWrap = true }])` for left-aligned, wrapping copy; the caller supplies width and anchors. `nonSpaceWrap` also breaks long unspaced words such as names, codes and links. `Kit.LayoutGrid(buttons, options)` places visible controls in reading order and returns the occupied height and column count. Supply `width`, `height`, `x`/`y`, and optional `gap`, `rowGap`, `padding` or `minWidth`. Labels determine the number of columns unless `columns` is explicit. `anchor = "BOTTOMLEFT"` places a footer grid above its bottom edge. Hidden children leave no gaps; hiding their parent does not change the layout. It owns sizes and anchors, while features own selection, visibility and actions.

Grids reuse existing widgets, allocate no temporary visible-item list, and skip unchanged anchor/size writes. For custom single-anchor layouts use `Kit.Place(region, point, relative, relativePoint, x, y[, width, height])`. It checks native geometry, so reparenting or another layout's changes cannot leave a stale cache. It owns that region's anchors; keep multiple-anchor layouts with their existing owner, and retain combat guards for protected frames.

`Kit.ScrollArea(parent, options)` accepts `wheelStep` and `gutter`. Settings pages (`Options.MakePage`) and `Kit.Browser` details use it, so every scrollbar follows the theme. For code written against Blizzard's scroll frames, `SetVerticalScroll(offset)` (which refreshes the range first), `GetVerticalScroll()` and `UpdateScrollChildRect()` map to `Scroll`, `offset` and `Refresh`. Its `.view` is the viewport, `.body` is the content, and `Scroll(offset)` keeps the thumb and viewport synchronized. Resizing the viewport or body updates the range and clamps the offset. Replace content through `SetBody(frame)` instead of assigning `.body`; it also supports edit boxes and retires the previous body's resize hooks. For custom layout, assign `onLayout(area, width)` and call `Refresh()` after changing the content.

`Kit.ScrollText(parent, options)` adds a `.text` paragraph and `SetText(text)`, with optional `role`, `color` and `bottomPadding`. It reflows on width, font and theme changes. Use `Scroll(0)` when selecting a different record; updating text otherwise preserves the offset within the new range. Only the scroll body has a measured height, so longer replacement text cannot be clipped by an earlier fixed FontString height. Bounty death reports and reputation history share this component; the bounty details page uses `ScrollArea`; standalone wanted popups never contain one.

Dialog positions are saved in `Core.db.windows[key]` (`HighgroundDB`, or `HighgroundMacrosDB` in Highground Macros). A dialog's close button is `frame.close`; the Highground window hides it while it shows the dialog.

`Kit.Dialog` automatically registers with `Kit.Windows`. Opening a main tool immediately hides the previous tool, including its controls, so journals, bounties, macros and the hub cannot interleave. Reparented pages share their host's slot. The coordinator is shared as `HighgroundWindowCoordinator` across standalone addons; gameplay HUDs remain independent.

Use `child = true` for a temporary editor or confirmation. It replaces its owner and returns to it on Close or Escape; `Kit.CopyBox` uses this behavior by default. Nested editors return one step at a time. Call `Kit.Windows.Close(editor)` when a review completes a hidden editor, so it returns to the original tool. Opening a different main tool clears old return paths. Hosts can provide `onResume` to restore their selected page; borrowed pages stay hidden when returned to their original parent. Use the shared coordinator instead of raising competing windows or adding screen-specific hide lists.

Every dialog uses `Kit.Header`. Register buttons or metadata in reading order with `window.header:SetActions({ primary, secondary })`; the component places them beside the title and reserves room for the close button. Title, actions and close share one vertical center, including after font, theme, size and visibility changes. Subtitles sit below the title when they fit within the header and move inline otherwise. Text stays within the available space. Crests remain centered on the whole header.

Use `window.header:SetActions()` to release actions before placing them elsewhere, such as a first-use action in the board body. The header owns anchors while actions are attached, but leaves their parents, size, visibility and click handlers with the caller. Do not assign per-screen title or header-action Y offsets. `Kit.Header(parent, options)` can also be placed on any other surface; dialogs expose its text as `window.title` and `window.sub` for compatibility.

[libs/ui/Browser.lua](../../../libs/HighgroundKit/ui/Browser.lua) adds `Kit.Browser` for searchable journals and claim lists.

The enemy journal uses a narrower list with class icons, last locations and sighting ages. Its selected profile has a class-coloured identity header, a labelled encounter/kill stat strip, and separate location and field-note sections. `renderRow` and `renderDetail` let this feature supply its presentation; other browsers retain their plain-text details. Profile text has automatic height, and only its containing scroll body is sized from the content. Actions stay outside the scroll area; Undo stacks above pagination when the list is narrow. Preview the populated standalone journal with `python3 tools/macro_preview.py --theme highground --state journal-window`, or use `--state journal` for the hub. Native game icons are omitted from the HTML preview.

HUD panels (timers, flags, arena, nearby) use `Timers.MakeWindow` ([libs/ui/Windows.lua](../../../libs/HighgroundKit/ui/Windows.lua)) for the windows and [libs/ui/Hud.lua](../../../libs/HighgroundKit/ui/Hud.lua) for their rows (`Hud.UnitRow`, `Hud.Surface`, `Hud.PaintClass`). Both are in the HighgroundKit library next to the kit; addons that need no HUD window, like Highground Macros, don't load them.

[PanelControls.lua](../../../libs/HighgroundKit/ui/PanelControls.lua) gives each HUD window a plain cog button. Compact battleground columns expose only the first visible member's cog; alpha-zero secure windows cannot own it. Locked cogs use `alpha.panelCog` at rest, brighten over the panel or column, and stay bright while unlocked or their menu is open. They are independent of Frameless header opacity. [PanelMenu.lua](../../../libs/HighgroundKit/ui/PanelMenu.lua) shares locking, context actions and settings routes; Highground supplies its guided placement flow. The shared window factory registers new panels automatically.

[libs/bounty/Widgets.lua](../../../libs/HighgroundKit/bounty/Widgets.lua) keeps the old `ns.Widgets` names over the kit. New code uses `ns.Kit`.

Bounty navigation starts at the board: an empty personal board explains creating or finding a bounty. Creation uses the shared progress stepper for **Target → Reward → Review**, with one primary action per stage. Keep **View bounty** one click away, and show **Share bounty**, **Edit reward** or **Claim reward** directly in its overview. Put other management actions in a visible section instead of a More menu. The overview shows the selected target and relevant contributions together; owners edit their reward, while other players can contribute. Organization review status uses a labelled, coloured badge.

The final creation step embeds `Bounty.Wanted` as a draft poster, with the selected target's portrait, reward and note. Its review follows the enemy journal's profile hierarchy: an accented audience header, one stats strip for kill goal, shared expiry and maximum reward, then labelled hunt conditions and next steps. This sits beside the poster when space allows, then stacks below on narrower surfaces. Draft previews neither publish nor expire like alerts. Standalone alerts use `Wanted.PopupWidth()` (320 at ordinary text size), smaller poster typography and only the target, reward, location and relevant actions. Detail and review cards use a compact inline summary. Multiple contributions share one target header; long notes and terms scroll only within the details page.

Forms, claims, preferences and suggestion reports mount through `Bounty.Navigation.Mount` (`Bounty.Widgets.MountPage`) to replace the board contents at the same position and size, including inside the hub. Back/Forward restores each visit's draft, filters and page; **Back to board** discards a draft, while a successful save returns to My bounties with feedback. Scroll long forms instead of moving their save controls out of reach. Wanted-poster details, previews and chat imports use independent `Bounty.Widgets.ShowWindow` popups that return to the board when closed. Both paths keep an opaque backdrop and `FULLSCREEN_DIALOG` strata during entrance effects.

Poster detail actions stay outside the scroll area: primary actions above it, management actions in the footer. Withdraw and remove actions use `Kit.Confirmation`: the first click relabels the same button (for example **Confirm removal**) and explains the result; another action, a different bounty or closing the details disarms it. Alert and proof posters size to their compact contents without a viewport. Refreshes retain the current scroll offset; only opening another target or report resets it. Measure the full detail body before committing its height, so native resize callbacks cannot clamp the reader to an intermediate layout.

## Building blocks

Use these before hand-rolling the same layout in a page. Labels and texts accept anything `Kit.Text` resolves: a literal, a function, a message descriptor `{ key = messageKey, values = … }` or a field of a table declared with `ns.Localization.Define`. `Kit.TabGroup`, `Kit.Tab`, `Kit.Segmented`, `Kit.ConfirmButton`, `Kit.Badge` and `Kit.EmptyState` resolve them again after a language change (`Kit.OnLocale`); literals stay as given. Each block is a plain frame: the owner anchors it, supplies all player-facing copy and calls `Layout(width)` after width, text or font changes. `Layout` returns the occupied height, grows controls with `Kit.Scale` at enlarged text sizes and skips unchanged geometry writes.

| Block | Use | API |
| --- | --- | --- |
| `Kit.SectionCard(parent, { title, hint, strip, fill })` | A titled surface for one group of related content | `.body` holds children; `SetTitle`, `SetHint`, `Layout(width, bodyHeight)` |
| `Kit.KeyValue(parent, { label, value, tone, role, labelWidth })` | A labelled fact: stats, summaries, review details | `Set(value, tone)`, `SetLabel(text)`, `Layout(width)`; long values wrap |
| `Kit.Badge(parent, text, tone)` | Short status text (Pending, Paid, Muted) sized to its label | `Set(text, tone)`, `Layout()`; shares `Kit.Chip`'s opaque backing |
| `Kit.EmptyState(parent, { title, message, tone, action, onAction })` | Why a list is empty and how to get content | `Set(title, message, tone)`, `SetState(Kit.ResolveState(facts))` keeps the title and applies the state's message and tone |
| `Kit.Toolbar(parent, { items, gap, height, minWidth, align, fitHeight })` | A row of actions sized to their labels; wraps when narrow | `Add(item)`, `SetItems(list)`, `Layout(width)`; hidden items leave no gap; `fitHeight` grows buttons whose labels wrap |
| `Kit.Segmented(parent, { choices, value, onChange })` | One mode or filter inside a view. Use `Kit.TabGroup` for pages | `SetValue(key, silent)`, `GetValue()`, `SetEnabled(key, on)`, `Layout(width)`; selection has an underline |
| `Kit.Hero(parent, tone)` | An accented profile or summary header: a tone wash over the surface and a top strip | `.strip`, `SetTone(token)`; the owner places its content |
| `Kit.ConfirmButton(parent, label, { confirm, onConfirm, onArm, onDisarm, timeout, subject })` | A destructive action without an undo | The first click arms it (confirm label, danger tone); the second runs `onConfirm`. Hiding, disabling, `Disarm()` or the timeout cancel. With `subject(self)`, a click for a different subject (such as another selected record) arms again instead of confirming |
| `Kit.Confirmation(owner)` | One shared handler confirming several actions or records | `Request(key)` returns true when it confirms the armed key, otherwise arms it; `Armed(key)`, `Reset()`; hiding the owner resets |
| `Kit.VirtualList(area, { rowHeight, gap, create, render, max })` | Long lists inside a `Kit.ScrollArea` | `SetItems(list)`, `Refresh()`; only the visible window of rows exists and scrolling reuses them |

Setters that repeat the current value are free: `Header:SetTitle`/`SetSub`/`SetActions` with unchanged values do not reflow, and `ScrollText:SetText` with the same text does not refresh. Header and scroll-area layouts write geometry only when it changes.

Prefer an undo (as in `Kit.Browser`) to a confirmation when an action can be reversed. Owners cancel a pending confirmation when its subject changes, for example selecting another profile. Home and Profiles use these blocks; `tests/ui_blocks.lua` covers them in every retained host.

## Building blocks

Use these before hand-rolling the same layout in a page. Each block is a plain frame: the owner anchors it, supplies all player-facing copy and calls `Layout(width)` after width, text or font changes. `Layout` returns the occupied height, grows controls with `Kit.Scale` at enlarged text sizes and skips unchanged geometry writes.

| Block | Use | API |
| --- | --- | --- |
| `Kit.SectionCard(parent, { title, hint, strip, fill })` | A titled surface for one group of related content | `.body` holds children; `SetTitle`, `SetHint`, `Layout(width, bodyHeight)` |
| `Kit.KeyValue(parent, { label, value, tone, role, labelWidth })` | A labelled fact: stats, summaries, review details | `Set(value, tone)`, `SetLabel(text)`, `Layout(width)`; long values wrap |
| `Kit.Badge(parent, text, tone)` | Short status text (Pending, Paid, Muted) sized to its label | `Set(text, tone)`, `Layout()`; shares `Kit.Chip`'s opaque backing |
| `Kit.EmptyState(parent, { title, message, tone, action, onAction })` | Why a list is empty and how to get content | `Set(title, message, tone)`, `SetState(Kit.ResolveState(facts))` keeps the title and applies the state's message and tone |
| `Kit.Toolbar(parent, { items, gap, height, minWidth, align, fitHeight })` | A row of actions sized to their labels; wraps when narrow | `Add(item)`, `SetItems(list)`, `Layout(width)`; hidden items leave no gap; `fitHeight` grows buttons whose labels wrap |
| `Kit.Segmented(parent, { choices, value, onChange })` | One mode or filter inside a view. Use `Kit.TabGroup` for pages | `SetValue(key, silent)`, `GetValue()`, `SetEnabled(key, on)`, `Layout(width)`; selection has an underline |
| `Kit.Hero(parent, tone)` | An accented profile or summary header: a tone wash over the surface and a top strip | `.strip`, `SetTone(token)`; the owner places its content |
| `Kit.ConfirmButton(parent, label, { confirm, onConfirm, onArm, onDisarm, timeout, subject })` | A destructive action without an undo | The first click arms it (confirm label, danger tone); the second runs `onConfirm`. Hiding, disabling, `Disarm()` or the timeout cancel. With `subject(self)`, a click for a different subject (such as another selected record) arms again instead of confirming |
| `Kit.Confirmation(owner)` | One shared handler confirming several actions or records | `Request(key)` returns true when it confirms the armed key, otherwise arms it; `Armed(key)`, `Reset()`; hiding the owner resets |
| `Kit.VirtualList(area, { rowHeight, gap, create, render, max })` | Long lists inside a `Kit.ScrollArea` | `SetItems(list)`, `Refresh()`; only the visible window of rows exists and scrolling reuses them |

Setters that repeat the current value are free: `Header:SetTitle`/`SetSub`/`SetActions` with unchanged values do not reflow, and `ScrollText:SetText` with the same text does not refresh. Header and scroll-area layouts write geometry only when it changes.

Prefer an undo (as in `Kit.Browser`) to a confirmation when an action can be reversed. Owners cancel a pending confirmation when its subject changes, for example selecting another profile. Home and Profiles use these blocks; `tests/ui_blocks.lua` covers them in every retained host.

## Collection and control states

Use `Kit.ResolveState({ count, filtered, empty, loading, disabled, unavailable, error })` when a collection can be empty for different reasons. It returns `{ kind, message, tone, blocked }`. Error, unavailable, disabled and loading take precedence in that order; pass `true` for default copy (the `shared.state.*` messages in the localization catalog) or a string for feature-specific guidance. Once those conditions clear, a positive count means `ready`; zero means `filtered` when a filter is active, otherwise `empty`. Derive these facts on every refresh so recovery removes earlier error or loading states.

`Kit.Browser` accepts `state(window)` returning those facts. While blocked, it does not call the data provider and clears selection, rows and actions. A later `Refresh()` restores available data. The browser supplies count, search and empty guidance; features retain ownership of fetching and refresh events. Its `always` actions can run without a selection, but still respect their `enabled` predicate. Actions recheck current data before running and never silently substitute a different row for one that disappeared.

Use `Kit.StatusText(region, text, tone)` for changing feedback; omitting tone restores `textMuted` after an error. Buttons and toggles share `Kit.EnableControl`, so `Enable`, `Disable` and `SetEnabled` synchronize native input, feedback and theme opacity. `Select:SetChoices` refreshes renamed labels, closes obsolete menus, and shows an explicit empty label. Dropdown acceptance checks that its owner is still visible and enabled.

## Runtime cost

These defaults live in HighgroundKit and apply to Highground and six retained legacy hosts:

- Standard rounded controls share `media/ControlCorners.tga`, a 2 KiB alpha atlas generated by `python3 tools/control_corners.py`. A default button creates 55 frames/regions instead of 115; custom radii retain their existing shape renderer. Ship the shared media directory with the kit.
- Button and toggle enabled-state setters skip unchanged states. Polling a control must not repaint it, clear an active press or restart a transition. Colours and gradients use the shared `Theme.Paint` cache, with its existing weak region registry and reused gradient storage.
- Typography checks the native font before calling `SetFont`. Repeating a type role skips the write; changed roles, user font choices, text scale and externally changed fonts still apply. Font strings created through `Core.Text` / `Theme.Text` also skip identical `SetText` calls by reading native text, without retaining a string cache; a number remembers only its last value and resulting text, so repeated counters skip `tostring`. Restricted text bypasses comparison. Edit boxes retain their normal callbacks and cursor behavior. Grids and custom `Kit.Place` layouts likewise compare current geometry before writing it.
- Motion uses one driver only during active transitions. Use `Util.Every` for periodic background work: it uses native timers where available and returns cancellable `Start`/`Stop` handles. `Util.RunGuarded(stage, fn)` protects argument-free callbacks that need only success, without packing result tables; use `Util.Guard` when arguments/results matter. Visible-only feature refreshes must check visibility or stop their handle on hide; real data changes should refresh through events.
- Build expensive page content on first use, keep reusable rows, and refresh the affected controls. Reserve full theme/font passes for corresponding global changes. Never force garbage collection during interactions.

`tests/ui_components.lua` exercises the same shared controls through Highground's and retained legacy hosts' real manifests on Cata, Retail and Forever. It enforces the button object budget and verifies that repeated colour, text, font, enabled-state and grid updates perform no native writes, while actual changes still repaint or reflow. `tests/performance_test.lua` covers lazy pages, hidden views, guide cleanup, scoring allocation budgets and cooldown changes. Use the [profilers](../../../docs/performance.md#profilers) to compare allocations; their simulator heap is not WoW's memory meter.

## Rules

- No numeric colours or `|cff` codes outside `config/Theme.lua` and `config/themes/`. `tests/validate.py` fails on them. Class colours come from the game.
- Use type roles, not font paths and sizes. Use `Theme.PaintClass` for class-coloured text; raw game colours remain appropriate for class strips and icons.
- Use `Theme.TipLine`, `Theme.TipColor` or `Theme.TipHex` for tooltips and chat, so a light theme stays readable on Blizzard's dark frames.
- Overlays over the game world (capture bars, map pins, target marker) use their own `hud*`, `capPlate*` and `mapMark` tokens, which light themes keep bright.

Macro completion uses the edit box's native `OnCursorChanged` rectangle, accounting for its scroll offset. The popup chooses available space above or below the line, fits its row count to the viewport, and closes when scrolled away from the caret. The explanation and save area remain outside that viewport. `Core.OnFontScaleChange` lets the builder and dropdown reflow when text size changes. Large dialog headers place metadata beside the title instead of spilling into the content.

A local geometry preview can be generated with `python3 tools/macro_preview.py --theme azeroth --state completion` from the repository root (also `--state empty`, `expanded`, or `hub`, and `--scale 1.5`). It renders the running simulated frame tree to `dist/`; font metrics and native game rendering remain approximate.

Use `--theme highground --state home` to inspect the featured card and navigation, or `--state battleground-hero` to include the optional suggested-target card beside the combat panels. The exporter includes linear gradients and the bundled crest; game-supplied inline icons use a diamond placeholder. The `effects` simulation group covers light-state cleanup, interrupted fades, reduced motion, small-control bounds and both gradient APIs.

## Keep the game first

- Offer the optional feature-guide chooser on first installation outside combat and instances. Save progress per guide, keep **Back to game** available, and require no profile or setup to play. Existing installations open the guide explicitly from Home or `/hg guide`.
- Show all available controls on each addon’s Settings and Appearance pages, grouped under clear headings in a scroll area. Keep dependencies visible with an explanation when a parent is disabled. Profile sharing and item actions can use their own menus or sections.
- Prefer one primary action per item. Macro presets use **Use macro**, saved ones use **Edit macro**, and advanced actions live under **More**.
- Write out targets and destinations. Introduce a focus as a second target; explain the action-bar step after saving a macro. Offer remembered, optional highlighted code on preset cards for readers who prefer it; keep editing in the editor and technical history in hover details.
- An empty state should explain how to get content. Distinguish no search matches, a disabled feature, missing guild membership and unobserved game state.
- Preserve explicit panel positions and existing feature choices. Default layouts must leave space for other panels. Cover both ordinary and enlarged text in the simulator, then verify native rendering in the game.
