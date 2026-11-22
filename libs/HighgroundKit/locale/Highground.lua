local _, ns = ...
local L = ns.Locale
local Localization = { preference = "enUS" }
ns.Localization = Localization
local definitions, bindings = {}, setmetatable({}, { __mode = "k" })
local displayTables = setmetatable({}, { __mode = "k" })
local views = setmetatable({}, { __mode = "k" })
local writing
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
  if type(key) == "table" then values, key = key.values, key.key end
  local previousTarget = writing
  writing = target
  target:SetText(values and L:Format(key, type(values) == "function" and values() or values) or L:Get(key))
  writing = previousTarget
  local previous = bindings[target]
  if not previous or previous.key ~= key or previous.values ~= values then
    bindings[target] = { key = key, values = values }
  end
  return target
end

function Localization.Unbind(target) bindings[target] = nil end

-- Reused controls must release an old label binding when showing live data.
function Localization.Written(target)
  if writing ~= target then bindings[target] = nil end
end

function Localization.BindWidget(target, fields)
  for field, key in pairs(fields) do
    Localization.Bind(field == 0 and target or target[field], key)
  end
  return target
end

-- Only explicitly declared display fields participate. Keys, player-authored
-- values, macro bodies and wire data are never inspected or translated.
local function Message(key)
  return type(key) == "table" and L:Format(key.key, type(key.values) == "function" and key.values() or key.values) or L:Get(key)
end

function Localization.Define(target, fields)
  local previous = displayTables[target]
  if previous then
    for field, key in pairs(fields) do previous[field] = key end
  else
    displayTables[target] = fields
  end
  for field, key in pairs(fields) do target[field] = Message(key) end
  return target
end

function Localization.Watch(target, refresh)
  target.RefreshLocale = refresh
  views[target] = true
end

function Localization.BindField(target, source, field)
  local fields = displayTables[source]
  if fields and fields[field] then return Localization.Bind(target, fields[field]) end
  target:SetText(source[field])
  return target
end

function Localization.Key(source, field)
  local fields = displayTables[source]
  return fields and fields[field]
end

local function Apply()
  L:SetLocale(Localization.preference == "auto" and ClientLocale() or Localization.preference)
  local previous = font
  font = Font()
  for target, fields in pairs(displayTables) do
    for field, key in pairs(fields) do target[field] = Message(key) end
  end
  -- A button can rewrite its child label and release that child's binding.
  -- Snapshot before invoking setters so registry changes cannot skip a later
  -- entry in Lua 5.1's table traversal. This allocates only on language changes.
  local pending = {}
  for target, message in pairs(bindings) do
    pending[#pending + 1] = target; pending[#pending + 1] = message
  end
  for i = 1, #pending, 2 do
    local target, message = pending[i], pending[i + 1]
    if bindings[target] == message then Localization.Bind(target, message.key, message.values) end
  end
  if font ~= previous and ns.Core and ns.Core.RefreshFonts then ns.Core.RefreshFonts() end
  for view in pairs(views) do view:RefreshLocale() end
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
