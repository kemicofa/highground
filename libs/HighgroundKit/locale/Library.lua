-- Reusable Lua 5.1 message catalogs. No game APIs, UI, globals or saved state.
-- Load with require/dofile, or embed in a WoW TOC (exports ns.LocaleLibrary).
local _, namespace = ...
local Library, Instance = {}, {}
Instance.__index = Instance
local TOKEN = "{([%a_][%w_]*)}"
local EMPTY = {}

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
    catalogs = {}, aliases = {}, tokens = {}, counts = {}, total = 0 }, Instance)
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

-- Registration is atomic and copies the input. Load English before its
-- translations; duplicate keys may agree but cannot silently overwrite copy.
-- Empty catalogs are valid. Empty translations, unknown keys and mismatched
-- named arguments are errors, rather than broken text displayed to a player.
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
      if not base[key] then return nil, "unknown English message: " .. key end
      if not SameTokens(self.tokens[key], tokens) then return nil, "placeholder mismatch: " .. key end
    end
    parsed[key] = tokens
  end
  if not catalog then catalog = {}; self.catalogs[locale], self.counts[locale] = catalog, 0 end
  for key, value in pairs(messages) do
    if not catalog[key] then self.counts[locale] = self.counts[locale] + 1 end
    catalog[key] = value
    if locale == self.defaultLocale then self.tokens[key] = parsed[key] end
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
-- No printf or implicit plural rules: use complete messages for each form.
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

function Instance:Coverage(locale)
  return self.counts[self:Canonical(locale) or self.defaultLocale] or 0, self.total
end

if type(namespace) == "table" then namespace.LocaleLibrary = Library end
return Library
