local t = dofile("../../tools/harness.lua")("locale library")
local check = t.equal
t.equal = function(a, b, why) return check(a, b, why or "values match") end
-- The library must run without WoW or Highground. No ambient APIs in this env.
local environment = { assert = assert, type = type, pairs = pairs, setmetatable = setmetatable, tostring = tostring }
local Library = setfenv(assert(loadfile("libs/locale/Library.lua")), environment)()
local function catalog()
  local l = Library.New("enUS", { enGB = "enUS", ptPT = "ptBR" })
  assert(l:Register("enUS", { title = "Title", hello = "Hello {name}, {count} left.", percent = "100%" }))
  assert(l:Register("frFR", { hello = "Encore {count}, {name}. Bonjour {name}." }))
  assert(l:Register("ptBR", {}))
  return l
end

t.test("independent instances, aliases and unknown languages fall back to English", function()
  local a, b = catalog(), catalog()
  t.equal(a:GetLocale(), "enUS")
  a:SetLocale("frFR")
  t.equal(a:Get("title"), "Title")
  t.equal(b:GetLocale(), "enUS")
  t.equal(b:Get("hello"), "Hello {name}, {count} left.")
  t.equal(a:SetLocale("enGB"), "enUS")
  t.equal(a:SetLocale("ptPT"), "ptBR")
  local selected, known = a:SetLocale("unknown")
  t.equal(selected, "enUS"); t.equal(known, false)
  t.equal(a:SetLocale(false), "enUS")
  t.equal(a:SetLocale({}), "enUS")
end)

t.test("named arguments reorder, repeat, preserve UTF-8 and treat values literally", function()
  local l = catalog(); l:SetLocale("frFR")
  local name = "Жан 中文 100% {count}"
  t.equal(l:Format("hello", { count = 2, name = name }), "Encore 2, " .. name .. ". Bonjour " .. name .. ".")
  t.equal(l:Format("percent"), "100%")
  assert(not pcall(function() l:Format("hello", { count = 1 }) end))
  assert(not pcall(function() l:Format("hello", { count = {}, name = "Name" }) end))
end)

t.test("bad translations fail atomically and cannot break the English fallback", function()
  local l = catalog()
  local invalid = {
    { hello = "Hello {name}" }, { hello = "Hello {name}, {count}, {extra}" },
    { unknown = "Unknown" }, { title = false }, { title = "" }, { title = {} }, { [1] = "One" },
  }
  for _, messages in ipairs(invalid) do
    messages.percent = "Valid member of rejected catalog"
    local ok, reason = l:Register("deDE", messages)
    assert(not ok and type(reason) == "string")
    t.equal(l.catalogs.deDE, nil)
  end
  assert(not l:Register("enUS", { title = "Changed" }))
  t.equal(l:Get("title"), "Title")
  assert(not l:Register(nil, {})); assert(not l:Register("deDE", false))
  assert(not pcall(function() Library.New("enUS", { enGB = "enUS", enUK = "enGB" }) end))
end)

t.test("registration copies data and missing lookups never grow retained state", function()
  local l = catalog()
  local messages = { title = "Titel" }
  assert(l:Register("deDE", messages)); messages.title = "Mutated"
  l:SetLocale("deDE"); t.equal(l:Get("title"), "Titel")
  local count, total = l:Coverage("deDE")
  t.equal(count, 1); t.equal(total, 3)
  for i = 1, 10000 do l:Get("missing" .. i) end
  t.equal(l:Coverage("deDE"), 1)
  local entries = 0
  for _ in pairs(l.catalogs.deDE) do entries = entries + 1 end
  t.equal(entries, 1)
  assert(l:Register("deDE", { title = "Titel" }))
  t.equal(l:Coverage("deDE"), 1)
  assert(l:Register("enUS", { added = "Added later" }))
  t.equal(l:Get("added"), "Added later")
  t.equal(select(2, l:Coverage("deDE")), 4)
end)

t.test("plural categories follow CLDR and missing forms fall back", function()
  local l = Library.New("enUS")
  assert(l:Register("enUS", { ["err.one"] = "{count} error", ["err.other"] = "{count} errors" }))
  assert(l:Register("ruRU", { ["err.one"] = "{count} ошибка", ["err.few"] = "{count} ошибки",
    ["err.many"] = "{count} ошибок", ["err.other"] = "{count} ошибки" }))
  assert(l:Register("frFR", { ["err.one"] = "{count} erreur", ["err.other"] = "{count} erreurs" }))
  assert(l:Register("zhCN", { ["err.one"] = "{count} 个错误", ["err.other"] = "{count} 个错误" }))
  assert(l:Register("deDE", { ["err.other"] = "{count} Fehler" }))
  t.equal(l:Plural("err", 1), "1 error")
  t.equal(l:Plural("err", 0), "0 errors")
  t.equal(l:Plural("err", 2), "2 errors")
  l:SetLocale("ruRU")
  local ru = { [1] = "one", [2] = "few", [5] = "many", [11] = "many", [21] = "one", [22] = "few", [25] = "many",
    [12] = "many", [14] = "many", [111] = "many", [101] = "one", [0] = "many" }
  for n, category in pairs(ru) do t.equal(l:PluralCategory(n), category, "ru " .. n) end
  t.equal(l:PluralCategory(1.5), "other", "fractions")
  t.equal(l:Plural("err", 1), "1 ошибка")
  t.equal(l:Plural("err", 2), "2 ошибки")
  t.equal(l:Plural("err", 5), "5 ошибок")
  t.equal(l:Plural("err", 11), "11 ошибок")
  t.equal(l:Plural("err", 21), "21 ошибка")
  t.equal(l:Plural("err", 22), "22 ошибки")
  t.equal(l:Plural("err", 25), "25 ошибок")
  l:SetLocale("frFR")
  t.equal(l:Plural("err", 0), "0 erreur", "French: 0 and 1 are singular")
  t.equal(l:Plural("err", 2), "2 erreurs")
  l:SetLocale("zhCN")
  t.equal(l:PluralCategory(1), "other")
  t.equal(l:Plural("err", 1), "1 个错误", "a language without one uses other")
  l:SetLocale("deDE")
  t.equal(l:Plural("err", 1), "1 Fehler", "a missing form falls back to the catalog's other")
  t.equal(l:Plural("err", 3, { count = "three" }), "three Fehler", "explicit values")
  l:SetLocale("koKR")
  t.equal(l:Plural("err", 1), "1 error", "an unregistered locale uses English")
  local nl = Library.New("enUS")
  assert(nl:Register("enUS", { ["n.one"] = "{count} item", ["n.other"] = "{count} items" }))
  t.equal(select(2, nl:Register("ruRU", { ["n.few"] = "{amount} штуки" })), "placeholder mismatch: n.few")
  t.equal(select(2, nl:Register("ruRU", { ["n.extra"] = "x" })), "unknown English message: n.extra")
  t.equal(select(2, nl:Register("ruRU", { ["missing.few"] = "{count}" })), "unknown English message: missing.few")
  assert(nl:Register("ruRU", { ["n.one"] = "{count} штука", ["n.few"] = "{count} штуки", ["n.many"] = "{count} штук" }))
  t.equal(nl:Coverage("ruRU"), 1, "extra forms do not count as source messages")
end)

t.test("lists join translated items with the selected language's words", function()
  local l = Library.New("enUS")
  t.equal(l:List({}), "")
  t.equal(l:List({ "a" }), "a")
  t.equal(l:List({ "a", "b", "c" }), "a, b and c", "English defaults without keys")
  assert(l:Register("enUS", { pair = "{first} and {second}", middle = "{first}, {second}" }))
  assert(l:Register("frFR", { pair = "{first} et {second}" }))
  assert(l:Register("zhCN", { pair = "{first}和{second}", middle = "{first}、{second}" }))
  l:SetListKeys("pair", "middle")
  t.equal(l:List({ "a", "b" }), "a and b")
  t.equal(l:List({ "a", "b", "c", "d" }), "a, b, c and d")
  l:SetLocale("frFR")
  t.equal(l:List({ "a", "b", "c" }), "a, b et c", "a missing joiner falls back to English")
  l:SetLocale("zhCN")
  t.equal(l:List({ "甲", "乙", "丙" }), "甲、乙和丙")
  t.equal(l:List({ 1, 2 }), "1和2", "numbers")
end)

t.test("all shipped catalogs validate and share one English fallback", function()
  local ns = { LocaleLibrary = Library }
  assert(loadfile("libs/locale/Locales.lua"))("Fixture", ns)
  assert(loadfile("libs/locale/enUS.lua"))("Fixture", ns)
  for _, def in ipairs(ns.LocaleDefinitions) do
    assert(ns.Locale.catalogs.enUS["locale.name." .. def.key], "every dynamic language-name key has an English message")
    if def.key ~= "enUS" then assert(loadfile("libs/locale/" .. def.key .. ".lua"))("Fixture", ns) end
    ns.Locale:SetLocale(def.key)
    t.equal(ns.Locale:GetLocale(), def.key)
    assert(type(ns.Locale:Get("locale.title")) == "string" and ns.Locale:Get("locale.title") ~= "")
    local count, total = ns.Locale:Coverage(def.key)
    assert(total > 0 and count >= 0 and count <= total)
    t.equal(count, total, "each shipped catalog covers every English message")
  end
  t.equal(#ns.LocaleDefinitions, 11)
end)
t.finish()
