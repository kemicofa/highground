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
Prepared labels and the sample update immediately. The Appearance guide
(`/hg guide features`) includes this real control; changing it intentionally
saves the preference. Opening or closing the guide never selects a language.

This is the **localization foundation**, not a translated release. Messages in
Shared preferences, the language names/sample, addon launcher labels and tooltips,
configuration command descriptions, grouped Battlegrounds guide labels and commands,
profile workspace controls, comparisons, position descriptions, and related guide/preference help
are registered in English. Profile reviews
redraw the prepared labels when the language changes, preserving the reviewed
values. Other feature strings remain at their existing call
sites. Non-English catalogs deliberately start empty; missing translations use
English. The control reports translated messages out of the prepared catalog,
not a percentage of the entire addon. Do not advertise a language as fully
translated until its feature text has been migrated and reviewed.

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
| `Coverage(locale)` | Returns registered message count and source catalog count. |

Registration rejects unknown translation keys, conflicting duplicates, blank
translations and changed placeholder sets before modifying an existing catalog.
Duplicate identical messages are harmless. Named placeholders are ASCII
identifiers; surrounding text and argument values preserve UTF-8 bytes. `%`,
braces and text inside an argument are not parsed again. No code is evaluated.
The library does not guess grammatical plurals or format numbers/dates: select
complete messages using the consumer's locale-aware rules and pass already
formatted numbers as arguments. Avoid constructing sentences from translated
fragments or assuming every language has English's two plural forms.

## Adding Highground translations and migrating text

1. Add a stable, namespaced key and the complete source message to `enUS.lua`.
2. Add reviewed values to the matching locale file; omit untranslated entries.
   Keep the same named arguments. Do not copy English to inflate coverage.
3. At a dynamic display boundary, use `ns.Locale:Get(key)` or
   `ns.Locale:Format(key, arguments)`. For labels created during file loading,
   use `ns.Localization.Bind(labelOrButton, key, arguments?)`; SavedVariables
   load later, and bindings update those labels after initialization and when
   the player selects a language. `Unbind(target)` releases an explicit binding.
   Bound argument tables are read at refresh time; keep them free of frame
   references and player secrets. Bind only labels owned by the addon.
4. Measure longer/wrapped text in the real control. Reuse paragraph layout and
   avoid fixed widths that assume English. Add a focused behavior test for the
   migrated interaction, then check its guide and preview.

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
same library and host suites through its standard runners. The check validates
catalogs and known references; it cannot identify every hardcoded display string
or prove the correctness of dynamic key construction. Manual diff review remains
required.

Catalogs are registered once and shared by that host's feature modules. `Get`
performs at most two expected constant-time table lookups, with no cache growth
on misses. `Format` is proportional to template and output bytes. Retained
storage is proportional to registered catalog text; all eleven catalogs remain
available for immediate switching. Language changes visit bound labels and
refresh fonts only when the script face changes. There are no timers, polling,
network messages or per-frame localization scans. Bindings hold weak target
keys; their values do not retain the target.

Run from the repository root:

```sh
python3 scripts/check_localization.py            # working tree
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
