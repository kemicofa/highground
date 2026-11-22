local _, ns = ...

-- WoW's eleven canonical locales. Alias clients share their base catalog.
-- Labels use English so the picker remains readable before language fonts load.
ns.LocaleDefinitions = {
  { key = "enUS", label = "English" },
  { key = "deDE", label = "German" },
  { key = "esES", label = "Spanish (Spain)" },
  { key = "esMX", label = "Spanish (Latin America)" },
  { key = "frFR", label = "French" },
  { key = "itIT", label = "Italian" },
  { key = "koKR", label = "Korean", font = "Fonts\\2002.TTF" },
  { key = "ptBR", label = "Portuguese (Brazil)" },
  { key = "ruRU", label = "Russian", font = "Fonts\\FRIZQT___CYR.TTF" },
  { key = "zhCN", label = "Chinese (Simplified)", font = "Fonts\\ARKai_T.TTF" },
  { key = "zhTW", label = "Chinese (Traditional)", font = "Fonts\\ARHei.TTF" },
}
ns.Locale = ns.LocaleLibrary.New("enUS", { enGB = "enUS", ptPT = "ptBR" })
