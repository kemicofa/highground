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
-- Locale:List joiners: "a and b", "a, b".
ns.Locale:SetListKeys("shared.list.first_and_second.956630", "shared.list.first_second.cba723")
