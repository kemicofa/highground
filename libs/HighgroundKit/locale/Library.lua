-- Reusable Lua 5.1 message catalogs. No game APIs, UI, globals or saved state.
-- Load with require/dofile, or embed in a WoW TOC (exports ns.LocaleLibrary).
local _, namespace = ...
local Library, Instance = {}, {}
Instance.__index = Instance
local TOKEN = "{([%a_][%w_]*)}"
local EMPTY = {}

-- CLDR plural categories for whole numbers, by language (the locale's first
-- two letters). Messages are families: <base>.one, <base>.other and, where a
-- language needs them, <base>.few / <base>.many. Fractions use "other".
local CATEGORIES = { zero = true, one = true, two = true, few = true, many = true, other = true }
local function OneOther(n) return n == 1 and "one" or "other" end
local function ZeroOneOther(n) return n >= 0 and n < 2 and "one" or "other" end -- French, Portuguese
local function Slavic(n) -- Russian
  if n % 1 ~= 0 then return "other" end
  local ten, hundred = n % 10, n % 100
  if ten == 1 and hundred ~= 11 then return "one" end
  if ten >= 2 and ten <= 4 and (hundred < 12 or hundred > 14) then return "few" end
  return "many"
end
local function OtherOnly() return "other" end
Library.PLURAL_RULES = {
  en = OneOther, de = OneOther, es = OneOther, it = OneOther, fr = ZeroOneOther, pt = ZeroOneOther,
  ru = Slavic, ko = OtherOnly, zh = OtherOnly, ja = OtherOnly,
}
-- Categories a language uses beyond one/other (catalog tooling checks these).
Library.PLURAL_EXTRA = { ru = { "few", "many" } }

-- English's list joiners, used when a catalog does not supply its own.
local LIST_DEFAULT = { pair = "{first} and {second}", middle = "{first}, {second}" }

local function Tokens(text)
  local result = {}
  for name in text:gmatch(TOKEN) do result[name] = true end
  return result
end

local function SameTokens(a, b)
  for key in pairs(a) do if not b[key] then return false end end
  for key in pairs(b) do if not a[key] then return false end end
  return true
end

function Library.New(defaultLocale, aliases)
  assert(type(defaultLocale) == "string" and defaultLocale ~= "", "a default locale is required")
  local self = setmetatable({ defaultLocale = defaultLocale, locale = defaultLocale,
    catalogs = {}, aliases = {}, tokens = {}, counts = {}, total = 0,
    pluralKeys = {}, count = {}, pair = {}, listKeys = {} }, Instance)
  for alias, target in pairs(aliases or {}) do
    assert(type(alias) == "string" and alias ~= "" and type(target) == "string" and target ~= "",
      "locale aliases must be nonempty strings")
    assert(alias ~= defaultLocale and not aliases[target], "aliases must point directly to a canonical locale")
    self.aliases[alias] = target
  end
  self.catalogs[defaultLocale], self.counts[defaultLocale] = {}, 0
  return self
end

function Instance:Canonical(locale)
  if type(locale) ~= "string" then return nil end
  return self.aliases[locale] or locale
end

-- The source message a translation key is checked against: itself, or for
-- an extra plural form (<base>.few where English has <base>.other) the
-- family's other form.
local function Source(base, key)
  if base[key] then return key end
  local stem, category = key:match("^(.+)%.(%a+)$")
  if stem and CATEGORIES[category] and base[stem .. ".other"] then return stem .. ".other" end
end

-- Registration is atomic and copies the input. Load English before its
-- translations; duplicate keys may agree but cannot silently overwrite copy.
-- Empty catalogs are valid. Empty translations, unknown keys and mismatched
-- named arguments are errors, rather than broken text displayed to a player.
-- A translation may add the plural forms its language needs (<base>.few,
-- <base>.many) to an English family; they take the other form's arguments.
function Instance:Register(locale, messages)
  locale = self:Canonical(locale)
  if not locale or locale == "" or type(messages) ~= "table" then return nil, "invalid catalog" end
  local base, catalog = self.catalogs[self.defaultLocale], self.catalogs[locale]
  local parsed = {}
  for key, value in pairs(messages) do
    if type(key) ~= "string" or key == "" or type(value) ~= "string" or value == "" then
      return nil, "message keys and values must be nonempty strings"
    end
    if catalog and catalog[key] and catalog[key] ~= value then return nil, "duplicate message: " .. key end
    local tokens = Tokens(value)
    if locale ~= self.defaultLocale then
      local source = Source(base, key)
      if not source then return nil, "unknown English message: " .. key end
      if not SameTokens(self.tokens[source], tokens) then return nil, "placeholder mismatch: " .. key end
    end
    parsed[key] = tokens
  end
  if not catalog then catalog = {}; self.catalogs[locale], self.counts[locale] = catalog, 0 end
  for key, value in pairs(messages) do
    -- Coverage counts source messages; extra plural forms are not among them.
    if not catalog[key] and (locale == self.defaultLocale or base[key]) then self.counts[locale] = self.counts[locale] + 1 end
    catalog[key] = value
    -- Extra plural forms reuse their family's (equal) argument set.
    if locale == self.defaultLocale or not self.tokens[key] then self.tokens[key] = parsed[key] end
  end
  self.total = self.counts[self.defaultLocale]
  return true
end

-- Unknown locales safely select English. The boolean reports recognition.
function Instance:SetLocale(locale)
  locale = self:Canonical(locale)
  local known = locale ~= nil and self.catalogs[locale] ~= nil
  self.locale = known and locale or self.defaultLocale
  return self.locale, known
end

function Instance:GetLocale() return self.locale end

-- Two table reads; missing keys never populate a cache or grow a catalog.
function Instance:Get(key)
  local text = self.catalogs[self.locale][key]
  if text then return text end
  return self.catalogs[self.defaultLocale][key] or key
end

-- Named placeholders can move or repeat in translations. Replacement values
-- are literal (including percent signs/braces); they are never reinterpreted.
-- No printf; for counts use Plural with a complete message per form.
function Instance:Format(key, values)
  local text = self:Get(key)
  -- gsub accepts a replacement table and inserts its values literally. Validate
  -- first, without allocating a callback on frequently refreshed HUD labels.
  for name in pairs(self.tokens[key] or Tokens(text)) do
    local value = values and values[name]
    assert(type(value) == "string" or type(value) == "number", "missing or invalid argument: " .. name)
  end
  return (text:gsub(TOKEN, values or EMPTY))
end

-- The CLDR plural category of a whole number n in the selected locale (or
-- the given one): "one", "few", "many" or "other".
function Instance:PluralCategory(n, locale)
  assert(type(n) == "number", "a plural count must be a number")
  local rule = Library.PLURAL_RULES[(locale or self.locale):sub(1, 2):lower()] or OneOther
  return rule(n < 0 and -n or n)
end

local function FormKey(self, base, category)
  local forms = self.pluralKeys[base]
  if not forms then forms = {}; self.pluralKeys[base] = forms end
  local key = forms[category]
  if not key then key = base .. "." .. category; forms[category] = key end
  return key
end

-- The family member for n: Plural("errors", 3) formats "errors.other" in
-- English and "errors.few" in Russian. values default to { count = n }. A
-- form the selected catalog lacks falls back to its other form, then to the
-- source language's form. Keys are built once per family and category.
function Instance:Plural(base, n, values)
  if not values then values = self.count; values.count = n end
  local catalog = self.catalogs[self.locale]
  local key = FormKey(self, base, self:PluralCategory(n))
  if not catalog[key] then
    key = FormKey(self, base, "other")
    if not catalog[key] then key = FormKey(self, base, self:PluralCategory(n, self.defaultLocale)) end
  end
  return self:Format(key, values)
end

-- Message keys for list joiners: pair = "{first} and {second}" (two items,
-- and the last two of longer lists), middle = "{first}, {second}".
function Instance:SetListKeys(pair, middle)
  self.listKeys.pair, self.listKeys.middle = pair, middle
end

local function Join(self, which, first, second)
  local pair = self.pair
  pair.first, pair.second = first, second
  local key = self.listKeys[which]
  if key and (self.catalogs[self.locale][key] or self.catalogs[self.defaultLocale][key]) then
    return self:Format(key, pair)
  end
  return (LIST_DEFAULT[which]:gsub(TOKEN, pair))
end

-- "a", "a and b", "a, b and c" in the selected language. Items are strings
-- or numbers, already translated.
function Instance:List(items)
  local n = #items
  if n == 0 then return "" end
  if n == 1 then return tostring(items[1]) end
  local text = Join(self, "pair", items[n - 1], items[n])
  for i = n - 2, 1, -1 do text = Join(self, "middle", items[i], text) end
  return text
end

function Instance:Coverage(locale)
  return self.counts[self:Canonical(locale) or self.defaultLocale] or 0, self.total
end

if type(namespace) == "table" then namespace.LocaleLibrary = Library end
return Library
