# Localization

Highground embeds a reusable Lua 5.1 library with English (`enUS`) as the default
and fallback. [Library.lua](../libs/HighgroundKit/locale/Library.lua) has no WoW,
Highground, UI, chat or SavedVariables dependencies. Consumers create independent
instances and supply their own catalogs and aliases. The remaining files in
`libs/HighgroundKit/locale/` are Highground's catalogs and game adapter.

## Player behavior and scope

Open **Shared preferences → General → Language** (`/hg config general`). English
is selected on both new and existing installations. Choose another language or
**Use game language** to follow the client. Selection saves account-wide in
`HighgroundDB.locale`, independently of exported/imported playstyle profiles.
Bound controls, declared display tables and the sample update immediately. The Appearance guide
(`/hg guide features`) includes this real control; changing it intentionally
saves the preference. Opening or closing the guide never selects a language.

All ten non-English catalogs include the migrated display messages for navigation,
settings, HUD labels, tooltips, command help and feedback, Feature guides, and
interactive previews. English remains the default and fallback. The selector
reports catalog coverage; it does not measure unregistered text or linguistic
quality. Commands and their arguments, player-authored text, macro names/bodies,
wire formats, saved identifiers, and client-provided spell/map names remain data.

The bulk translations were prepared offline with
[MADLAD-400](https://huggingface.co/google/madlad400-3b-mt) and
[M2M100](https://huggingface.co/facebook/m2m100_1.2B), followed by terminology,
placeholder, command-syntax and display-path review. Neutral Spanish is shared
by `esES` and `esMX`; Traditional Chinese uses the Simplified Chinese translation
with Taiwan terminology conversion and the shared UI corrections. No model,
translation service or network dependency is shipped in the addon. These are
machine-assisted translations, not native-speaker certification; idiomatic game
terminology and actual Cyrillic/CJK rendering still need live-client review.

| Catalog | Language |
| --- | --- |
| `enUS` | English (also `enGB`) |
| `deDE` | German |
| `esES` | Spanish (Spain) |
| `esMX` | Spanish (Latin America) |
| `frFR` | French |
| `itIT` | Italian |
| `koKR` | Korean |
| `ptBR` | Portuguese (Brazil; also `ptPT`) |
| `ruRU` | Russian |
| `zhCN` | Chinese (Simplified) |
| `zhTW` | Chinese (Traditional) |

This list follows the [extracted Blizzard locale catalogs](https://github.com/tekkub/wow-globalstrings).
The adapter uses Blizzard's [GetLocale API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/LocaleDocumentation.lua)
only for the optional client-language selection and native font choice. Unknown
client locales and corrupt saved preferences fall back to English. No Battle.net
launcher-only languages are added as WoW locales.

All seven runtime hosts and both TOC variants embed the same library and
catalogs. Deprecated standalone hosts use their own `*DB.locale` and existing
`config` settings page; they remain compatibility targets, not installation
recommendations. Storage-only and generated module addons need no UI catalogs.

## Reuse outside Highground

Copy `Library.lua` with the repository's MIT license. It can be loaded through
`require`, `dofile`, or an addon's TOC; a TOC load exports `ns.LocaleLibrary` on
the supplied private namespace, without creating a global singleton.

```lua
local Library = dofile("Library.lua") -- outside WoW; use ns.LocaleLibrary in an addon
local messages = Library.New("enUS", { enGB = "enUS" })
assert(messages:Register("enUS", {
  welcome = "Hello {name}, {count} entries remain.",
  close = "Close",
}))
assert(messages:Register("frFR", {
  welcome = "Il reste {count} entrées, {name}.",
}))
messages:SetLocale("frFR")
print(messages:Format("welcome", { name = "Alice", count = 3 }))
print(messages:Get("close")) -- English fallback
```

| API | Contract |
| --- | --- |
| `New(defaultLocale, aliases?)` | Independent catalogs and selected locale. Alias values must be canonical, without chains. |
| `Register(locale, messages)` | Copies and merges messages atomically; returns `true` or `nil, error`. Load source messages first. Empty catalogs are valid; values must be nonempty strings. |
| `Canonical(locale)` | Resolves a direct alias; non-string input returns nil. |
| `SetLocale(locale)` | Returns effective locale and recognition boolean. An unregistered locale selects the default. |
| `GetLocale()` | Current canonical locale. |
| `Get(key)` | Selected translation, then source message, then the key itself for an unknown key. No missing-key cache. |
| `Format(key, values)` | Substitutes named `{arguments}` as literal strings/numbers. Arguments can move and repeat. Missing/invalid arguments raise a programming error. |
| `Plural(base, n, values?)` | Formats the family member `<base>.<category>` for the whole number `n` (CLDR categories, below). `values` defaults to `{ count = n }`. A form the selected catalog lacks falls back to its `other` form, then to English. |
| `PluralCategory(n, locale?)` | `"one"`, `"few"`, `"many"` or `"other"` for `n` in the selected (or given) locale. |
| `SetListKeys(pair, middle)` | Message keys for list joiners: `pair` = `"{first} and {second}"` (two items, and the last two of a longer list), `middle` = `"{first}, {second}"`. |
| `List(items)` | Joins already-translated strings or numbers: `"a"`, `"a and b"`, `"a, b and c"`; `"a, b et c"` in French, `"a、b和c"` in Chinese. Without keys, English joiners. |
| `Coverage(locale)` | Returns registered message count and source catalog count. Extra plural forms are not counted. |

Registration rejects unknown translation keys, conflicting duplicates, blank
translations and changed placeholder sets before modifying an existing catalog.
Duplicate identical messages are harmless. Named placeholders are ASCII
identifiers; surrounding text and argument values preserve UTF-8 bytes. `%`,
braces and text inside an argument are not parsed again. No code is evaluated.
The library does not format numbers or dates; pass them already formatted.

### Plurals and lists

A count selects a complete message from a family: English registers
`<base>.one` and `<base>.other`, and a language that needs more forms adds
them to its own catalog. Registration accepts `<base>.few` / `<base>.many`
only when English has `<base>.other`, with the same named arguments. Every
form keeps the count argument, because Russian uses `one` for 21 as well.

| Language | Categories (whole numbers) |
| --- | --- |
| English, German, Spanish, Italian | `one` (1), `other` |
| French, Portuguese | `one` (0, 1), `other` |
| Russian | `one` (1, 21, 31…, not 11), `few` (2–4, 22–24…, not 12–14), `many` (0, 5–20, 25–30…), `other` (fractions) |
| Chinese, Korean | `other` only (the catalog's `one` repeats it) |

```lua
messages:Register("enUS", { ["err.one"] = "{count} error", ["err.other"] = "{count} errors" })
messages:Register("ruRU", { ["err.one"] = "{count} ошибка", ["err.few"] = "{count} ошибки",
  ["err.many"] = "{count} ошибок", ["err.other"] = "{count} ошибки" })
messages:SetLocale("ruRU")
print(messages:Plural("err", 22)) -- 22 ошибки
print(messages:List({ "a", "b", "c" })) -- English joiners unless SetListKeys names catalog messages
```

Write whole sentences: a message for each state (`on`/`off`, "now" or
"after combat") and a plural family for each counted sentence, not a
translated fragment such as `" (on)"` or `"Panels locked. "` placed before
other text. Word order, agreement and punctuation differ by language. A
counted noun phrase ("3 macros") may fill a placeholder; join several with
`List`, not with `" and "`.

## Adding Highground translations and migrating text

The complete-translation pass covers addon-owned display text in all seven
runtime hosts: shared navigation and preferences, feature settings, command
descriptions and feedback, tooltips, guides and interactive previews. Each of
the ten non-English catalogs must cover the migrated English messages, with
named arguments and the same command syntax. Player-authored names, notes,
protocol fields, saved-data identifiers and executable macro text remain data.
Game spell names and incoming chat parsing continue to follow the client.

Completion requires a source audit in addition to catalog coverage: a full
catalog cannot account for text that has never been registered. The checks must
also exercise saved language selection, switching languages in already-open
controls, guide and preview cleanup, and all retained host manifests. Script
font and layout checks in the simulator do not replace live-client glyph review.

1. Add the complete source message to `enUS.lua` under a namespaced key.
   Migrated strings use `<area>.<file>.<slug>.<hash>`, where the hash is the
   first six hex digits of the SHA-1 of the English text: reuse a key while its
   English is unchanged, and give changed English a new key. Hand-named keys
   such as `guide.choose` keep their name, so when their English changes,
   update or re-translate all ten catalogs; `l10n_sync.py` cannot detect a
   stale translation under an existing key.
2. Add a reviewed translation to all ten other catalogs. Shipped catalogs must
   have exactly the English key set (`tests/test_localization.py`), with the
   same named arguments, inline controls (`|c…`, `|r`, `|H`, `|T`), slash
   commands and `#showtooltip` text. `scripts/l10n_sync.py` does the
   bookkeeping:

   ```sh
   python3 scripts/l10n_sync.py missing              # missing or stale keys per catalog; exit 1 if any
   python3 scripts/l10n_sync.py template -o todo.json # {key: {"_en": English, "deDE": "", ...}}
   python3 scripts/l10n_sync.py apply todo.json       # insert the filled entries in enUS order
   ```

   `apply` refuses entries whose controls, `{placeholders}` or command syntax
   differ from English, ignores empty strings (apply a partly filled file again
   later), keeps existing translations unless `--overwrite`, and removes keys
   English no longer has with `--prune-stale`. `--dry-run` writes nothing.
   For plural families, `missing` and `template` also list the extra forms
   each language needs (`ruRU`: `.few` and `.many`, checked against the
   English `.other`); the key-set test requires them too. A family's key is
   `<area>.<file>.<slug>.<hash>` of its English `other` form, plus the category.
3. At a dynamic display boundary, use `ns.Locale:Get(key)`,
   `ns.Locale:Format(key, arguments)`, `ns.Locale:Plural(base, count, arguments?)`
   or `ns.Locale:List(items)`; `Util.Plural(n, word)` covers the shared count
   labels (error, warning, button, macro, character). For labels created during file loading,
   use `ns.Localization.Bind(labelOrButton, key, arguments?)`; SavedVariables
   load later, and bindings update those labels after initialization and when
   the player selects a language. `Unbind(target)` releases an explicit binding.
   Bound argument tables are read at refresh time; keep them free of frame
   references and player secrets. Bind only labels owned by the addon.
   Bindings, defined tables and watched views are weak keys: binding a frame
   never keeps it alive, so keep your own reference to anything that must stay.
4. Declare static display fields with `ns.Localization.Define(table, fields)`.
   Fields map to message keys, or `{ key = key, values = arguments }` descriptors.
   `values` may be a function for a composite label whose arguments need a fresh
   lookup. `BindField(label, table, field)` follows this explicit metadata;
   `BindWidget(widget, fields)` binds named widget labels (`0` means the widget).
   Ordinary writes to an owned label release its old binding, so recycled rows
   never overwrite player data when the language changes. Do not reverse-lookup
   arbitrary visible text or localize dispatch keys.
5. For a view whose computed content must refresh on selection, use
   `ns.Localization.Watch(view, refresh)`. It runs only during initialization or
   an explicit language change, not every frame. Read persistent error/status
   messages at their display boundary rather than caching English at file load.
6. Measure longer/wrapped text in the real control. Reuse paragraph layout and
   avoid fixed widths that assume English. Add a focused behavior test for the
   migrated interaction, then check its guide and preview.
7. Shared kit components supply only generic copy. `Kit.ResolveState` defaults
   come from the `shared.state.*` messages; building blocks (`Kit.Toolbar`,
   `Kit.SectionCard`, `Kit.EmptyState`, …) take caller-supplied text, and
   `Kit.Toolbar { fitHeight = true }` grows buttons whose translated labels wrap.

Commands, protocol fields, saved-data keys, player names, map/spell IDs, macro
syntax and user-authored text are never translated by interception. Existing
Blizzard chat parsers and localized macro spell names continue to use the game
locale independently of the addon preference. There is no global `SetText` hook.

The adapter chooses native game fonts for Russian, Korean and Chinese scripts
instead of bundled Latin faces. Font selection is cached until language changes;
missing font files fall back to the client's standard font. Choosing a different
script from the client's may require that game's language font assets. Simulator
tests verify selection/fallback paths, not glyph coverage; visual checks in each
language's actual client remain necessary before shipping translations.

## Cost and verification

The repository's `highground-localization-review` skill and `AGENTS.md` require
localization review of changed player-facing copy and shared code. Complete the
Localization item in the PR template, including a specific no-update reason for
unaffected changes. Existing unmigrated text is not an exemption for new copy.

Install or upgrade the shared pre-commit hook with
`python3 scripts/check_localization.py --install-hook`. It runs localization,
command/UI and performance checks from the current worktree and preserves custom
hooks. The localization check exports the exact Git index, including its checker
and tests, so an unstaged fix cannot mask a staged regression. CI exercises the
same library and host suites through its standard runners. The shipped catalogs
are required to have matching key coverage; independent library consumers may
still register partial catalogs. The check validates
catalogs and known references; it cannot identify every hardcoded display string
or prove the correctness of dynamic key construction. Manual diff review remains
required.

Catalogs are registered once and shared by that host's feature modules. `Get`
performs at most two expected constant-time table lookups, with no cache growth
on misses. `Format` is proportional to template and output bytes. Retained
storage is proportional to registered catalog text; all eleven catalogs remain
available for immediate switching. Language changes update declared display tables, visit bound labels and watched
views, and refresh fonts only when the script face changes. There are no timers, polling,
network messages or per-frame localization scans. Bindings hold weak target
keys; their values do not retain the target.

Run from the repository root:

```sh
python3 scripts/check_localization.py            # working tree
python3 scripts/l10n_sync.py missing             # every catalog has every key
python3 scripts/check_localization.py --staged   # exact staged content
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p test_localization.py -v
bash tests/run.sh --jobs 4
python3 scripts/check_performance.py --staged # after staging runtime changes
```

The library suite loads only Lua primitives, proving it needs no WoW APIs. Host
integration loads real manifests on Cataclysm, Retail and Forever and checks
selection, persistence, aliases, malformed data, bindings, font routing, guide
start/stop and the main preview. Packaging checks require every host's catalog
files and reject unknown literal message references. Existing command catalog,
guide, preview, profile and performance suites provide regression coverage.

The full-catalog integration scenario also compares executable macro bodies,
command syntax, protocol advertisements, kill evidence and layout keys across
all eleven selections. It checks recycled labels and edit boxes, selected menu
values, generated page names, guide continuation and preview cleanup. This
protects the boundary between translated display copy and gameplay/user data.

For a browser layout review of the actual simulated controls, use, for example,
`python3 tools/macro_preview.py --state config --chapter profiles --locale deDE --scale 1.5`.
The generated HTML includes the locale in its filename. This preview uses browser
font metrics and fallback glyphs; it does not establish native WoW rendering.
The all-locale regressions also exercise game-location matching, callout
destination deduplication, retained profile groups, and executable preview hints.
