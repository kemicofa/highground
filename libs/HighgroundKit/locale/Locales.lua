local _, ns = ...

-- WoW's eleven canonical locales. Alias clients share their base catalog.
-- Language display names live in the English catalog, under locale.name.*.
-- English loads with Highground; each other catalog is its own load-on-demand
-- addon (addon), loaded when that language is selected.
ns.LocaleDefinitions = {
  { key = "enUS" },
  { key = "deDE", addon = "HighgroundLocaleDeDE" },
  { key = "esES", addon = "HighgroundLocaleEsES" },
  { key = "esMX", addon = "HighgroundLocaleEsMX" },
  { key = "frFR", addon = "HighgroundLocaleFrFR" },
  { key = "itIT", addon = "HighgroundLocaleItIT" },
  { key = "koKR", addon = "HighgroundLocaleKoKR", font = "Fonts\\2002.TTF" },
  { key = "ptBR", addon = "HighgroundLocalePtBR" },
  { key = "ruRU", addon = "HighgroundLocaleRuRU", font = "Fonts\\FRIZQT___CYR.TTF" },
  { key = "zhCN", addon = "HighgroundLocaleZhCN", font = "Fonts\\ARKai_T.TTF" },
  { key = "zhTW", addon = "HighgroundLocaleZhTW", font = "Fonts\\ARHei.TTF" },
}
ns.Locale = ns.LocaleLibrary.New("enUS", { enGB = "enUS", ptPT = "ptBR" })
-- Locale:List joiners: "a and b", "a, b".
ns.Locale:SetListKeys("shared.list.first_and_second.956630", "shared.list.first_second.cba723")
