local _, ns = ...

-- WoW's eleven canonical locales. Alias clients share their base catalog.
-- Language display names live in the English catalog, under locale.name.*.
ns.LocaleDefinitions = {
  { key = "enUS" },
  { key = "deDE" },
  { key = "esES" },
  { key = "esMX" },
  { key = "frFR" },
  { key = "itIT" },
  { key = "koKR", font = "Fonts\\2002.TTF" },
  { key = "ptBR" },
  { key = "ruRU", font = "Fonts\\FRIZQT___CYR.TTF" },
  { key = "zhCN", font = "Fonts\\ARKai_T.TTF" },
  { key = "zhTW", font = "Fonts\\ARHei.TTF" },
}
ns.Locale = ns.LocaleLibrary.New("enUS", { enGB = "enUS", ptPT = "ptBR" })
