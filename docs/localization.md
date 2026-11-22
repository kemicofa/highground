# Localization

Highground's localization work prepares a reusable Lua 5.1 library with English
(`enUS`) as the default and fallback. The library will not depend on WoW globals,
saved variables, UI frames, chat or Highground feature modules. Each host owns its
language selection and catalogs; translations must never change commands,
protocol fields, saved-data keys, player names or macro syntax.

The supported WoW locale catalogs are `enUS`, `deDE`, `esES`, `esMX`, `frFR`,
`itIT`, `koKR`, `ptBR`, `ruRU`, `zhCN` and `zhTW`. English `enGB` shares `enUS`;
Portuguese `ptPT` shares `ptBR`. The client-language setting is opt-in; missing
translations and unknown client locales fall back to English.

Implementation in progress: library, host integration, English messages,
translation validation and contributor examples. Non-English catalogs start
empty, so this preparation does not claim completed translations. Existing
feature text will be migrated explicitly at its display boundary rather than
by intercepting arbitrary player or network strings.

Guide review: the Shared preferences language control needs an explanation in
the Appearance guide once implemented. Preview review: the guide will exercise
the actual preference control; preview sample identities and wire data stay
locale independent. Command/UI review: the setting will be available through
the existing preferences page, with no new slash grammar. Runtime and packaging
validation remain pending while this tracking PR is a draft.
