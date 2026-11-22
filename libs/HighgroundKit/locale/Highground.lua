local _, ns = ...
local L = ns.Locale
local Localization = { preference = "enUS" }
ns.Localization = Localization
local definitions, bindings = {}, setmetatable({}, { __mode = "k" })
for _, def in ipairs(ns.LocaleDefinitions) do definitions[def.key] = def end
local database

local function Preference(value)
  if value == "auto" then return value end
  value = L:Canonical(value)
  return definitions[value] and value or "enUS"
end

local function ClientLocale()
  return L:Canonical(GetLocale and GetLocale() or "enUS")
end

-- Latin faces cannot display every script. Cache this choice at startup or
-- language changes; drawing text does not need to query the game locale.
local function Font()
  local client = ClientLocale()
  local def = definitions[L:GetLocale()]
  if not def.font then def = definitions[client] end
  if not def or not def.font then return nil end
  return def.key == client and STANDARD_TEXT_FONT or def.font
end
local font = Font()
function Localization.Font() return font end

function Localization.Bind(target, key, values)
  bindings[target] = { key = key, values = values }
  target:SetText(values and L:Format(key, values) or L:Get(key))
  return target
end

function Localization.Unbind(target) bindings[target] = nil end

local function Apply()
  L:SetLocale(Localization.preference == "auto" and ClientLocale() or Localization.preference)
  local previous = font
  font = Font()
  for target, message in pairs(bindings) do
    target:SetText(message.values and L:Format(message.key, message.values) or L:Get(message.key))
  end
  if font ~= previous and ns.Core and ns.Core.RefreshFonts then ns.Core.RefreshFonts() end
end

-- Called by the host after its SavedVariables become available. Languages
-- are account preferences, independent of imported/shared playstyle profiles.
function Localization.Initialize(db)
  database = db
  Localization.preference = Preference(db.locale)
  db.locale = Localization.preference
  Apply()
end

function Localization.SetPreference(value)
  if not database then return false end
  local canonical = value == "auto" and value or L:Canonical(value)
  if canonical ~= "auto" and not definitions[canonical] then return false end
  if Localization.preference == canonical then return true end
  database.locale, Localization.preference = canonical, canonical
  Apply()
  return true
end

function Localization.Choices()
  local choices = { { key = "auto", label = L:Get("locale.client") } }
  for _, def in ipairs(ns.LocaleDefinitions) do
    choices[#choices + 1] = { key = def.key, label = L:Get("locale.name." .. def.key) .. " (" .. def.key .. ")" }
  end
  return choices
end

function Localization.Status()
  local locale = L:GetLocale()
  local translated, total = L:Coverage(locale)
  return L:Format("locale.coverage", { language = L:Get("locale.name." .. locale), translated = translated, total = total })
end
