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
