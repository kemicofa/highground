local _, ns = ...

---------------------------------------------------------------------------
-- What the client exposes: every function in _G and the C_* namespaces,
-- common widget methods, and Blizzard's API documentation with its secrecy
-- and restriction flags. Developer tool only; never shipped with Highground.
---------------------------------------------------------------------------
local Catalog = {}
ns.Catalog = Catalog

function ns.Secret(v)
  return issecretvalue ~= nil and issecretvalue(v) == true
end

function ns.Build()
  local ok, version, build, _, interface = pcall(GetBuildInfo)
  if not ok then return "?" end
  return tostring(version) .. " (" .. tostring(build) .. ") " .. tostring(interface)
end

-- Documentation values worth saving: strings, numbers and booleans as they
-- are, anything else by type.
local function Scalar(v)
  local t = type(v)
  if t == "string" or t == "number" or t == "boolean" then return v end
  return t
end

-- Keys about secrecy and restrictions (SecretArguments, ConditionalSecret,
-- RequiresNonSecret..., HasRestrictions...), kept verbatim.
local FLAG_WORDS = { "Secret", "Restrict", "Protected" }
local function Flags(doc)
  local out
  for key, value in pairs(doc) do
    if type(key) == "string" then
      for _, word in ipairs(FLAG_WORDS) do
        if key:find(word, 1, true) then
          out = out or {}
          out[key] = Scalar(value)
          break
        end
      end
    end
  end
  return out
end

-- Per argument or return: its name and flags, only for those that have any.
local function ParamFlags(list)
  local out
  for i, param in ipairs(type(list) == "table" and list or {}) do
    local flags = type(param) == "table" and Flags(param)
    if flags then
      out = out or {}
      flags.name = Scalar(param.Name)
      out[tostring(i)] = flags
    end
  end
  return out
end

local UNIT_NAMES = { unit = true, unitToken = true, unitID = true, unitId = true }
local function UnitArgument(args)
  for i, arg in ipairs(type(args) == "table" and args or {}) do
    if type(arg) == "table" and (arg.Type == "UnitToken" or UNIT_NAMES[arg.Name]) then return i end
  end
end

local function LoadDocs()
  local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
  if not load then return false, "no LoadAddOn" end
  pcall(load, "Blizzard_APIDocumentation")
  local ok, loaded, reason = pcall(load, "Blizzard_APIDocumentationGenerated")
  if not ok then return false, tostring(loaded) end
  if type(APIDocumentation) ~= "table" or type(APIDocumentation.systems) ~= "table" then
    return false, "APIDocumentation.systems missing (" .. tostring(loaded) .. ", " .. tostring(reason) .. ")"
  end
  return true
end

-- Documented functions by full name ("UnitHealth", "C_PvP.GetScoreInfo"):
-- { unit = index of the unit-token argument, flags, args, returns, system }.
-- Widget (ScriptObject) methods are kept apart by method name.
function Catalog.Docs()
  if Catalog.docs then return Catalog.docs end
  local ok, err = LoadDocs()
  local docs = { functions = {}, widgets = {}, systems = 0, count = 0, loaded = ok, err = err }
  for _, system in ipairs(ok and APIDocumentation.systems or {}) do
    docs.systems = docs.systems + 1
    local namespace = type(system.Namespace) == "string" and system.Namespace ~= "" and system.Namespace
    for _, fn in ipairs(type(system.Functions) == "table" and system.Functions or {}) do
      if type(fn) == "table" and type(fn.Name) == "string" then
        docs.count = docs.count + 1
        if system.Type == "ScriptObject" then
          docs.widgets[fn.Name] = true
        else
          docs.functions[namespace and (namespace .. "." .. fn.Name) or fn.Name] = {
            unit = UnitArgument(fn.Arguments), flags = Flags(fn), args = ParamFlags(fn.Arguments),
            returns = ParamFlags(fn.Returns), system = Scalar(system.Name) }
        end
      end
    end
  end
  Catalog.docs = docs
  return docs
end

-- Every function the client exposes: globals and C_* members by full name.
function Catalog.Present()
  local present, count = {}, 0
  for key, value in pairs(_G) do
    if type(key) == "string" then
      if type(value) == "function" then
        present[key], count = value, count + 1
      elseif type(value) == "table" and key:sub(1, 2) == "C_" and (canaccesstable == nil or canaccesstable(value)) then
        for name, fn in pairs(value) do
          if type(name) == "string" and type(fn) == "function" then
            present[key .. "." .. name], count = fn, count + 1
          end
        end
      end
    end
  end
  return present, count
end

local function Methods(object)
  local meta = getmetatable(object)
  local index = meta and meta.__index
  local names = {}
  if type(index) == "table" then
    for name, fn in pairs(index) do
      if type(name) == "string" and type(fn) == "function" then names[#names + 1] = name end
    end
  end
  table.sort(names)
  return names
end

function Catalog.Widgets()
  if not Catalog.frame then
    Catalog.frame = CreateFrame("Frame")
    Catalog.frame:Hide()
  end
  local f = Catalog.frame
  return { Frame = Methods(f), Button = Methods(CreateFrame("Button", nil, f)), StatusBar = Methods(CreateFrame("StatusBar", nil, f)),
    FontString = Methods(f:CreateFontString()), Texture = Methods(f:CreateTexture()) }
end

-- Read-only by name. A query verb (Get, Is, ...) followed by a capital, and
-- none of the irreversible words; or a Unit* reader with no action word.
-- FrameXML helpers (names with "_") are Lua UI code, never called.
local VERBS = { "Get", "Is", "Has", "Can", "Should", "Does", "Find", "Check", "Calculate" }
local IRREVERSIBLE = { "Logout", "Quit", "Delete", "Buy", "Sell", "Repair", "Leave", "Accept", "Decline",
  "Release", "Invite", "Kick", "Report", "Send" }
local ACTIONS = { "Set", "Send", "Request", "Accept", "Decline", "Leave", "Join", "Clear", "Reset", "Release",
  "Use", "Cast", "Target", "Focus", "Assist", "Follow", "Invite", "Kick", "Report", "Logout", "Quit", "Delete",
  "Buy", "Sell", "Repair", "Ping", "Mark", "Start", "Stop", "Cancel", "Popup", "Update", "Show", "Hide",
  "Toggle", "Open", "Close", "Add", "Remove", "Enable", "Disable", "Apply", "Register" }
local UNIT_READS = { UnitCastingInfo = true, UnitChannelInfo = true, UnitCastingDuration = true, UnitChannelDuration = true }

local function Contains(name, words)
  for _, word in ipairs(words) do
    if name:find(word, 1, true) then return true end
  end
  return false
end

function Catalog.ReadOnly(full)
  local short = full:match("%.([^.]+)$") or full
  if short:find("_", 1, true) then return false end
  if UNIT_READS[short] then return true end
  for _, verb in ipairs(VERBS) do
    if short:sub(1, #verb) == verb and short:sub(#verb + 1, #verb + 1):match("^[A-Z]") then
      return not Contains(short, IRREVERSIBLE)
    end
  end
  return short:sub(1, 4) == "Unit" and not Contains(short, ACTIONS)
end

local function Protected(flags)
  for key, value in pairs(flags or {}) do
    if key:find("Protected", 1, true) and value == true then return true end
  end
  return false
end

-- Functions to call with a unit: documented ones taking a unit token, and
-- undocumented ones with "Unit" in the name (unit as the first argument).
function Catalog.Candidates()
  local docs, present = Catalog.Docs(), Catalog.Present()
  local list = {}
  for name, fn in pairs(present) do
    local doc = docs.functions[name]
    local unit = doc and doc.unit or not doc and name:find("Unit", 1, true) and 1
    if unit and Catalog.ReadOnly(name) and not (doc and Protected(doc.flags)) then
      list[#list + 1] = { name = name, fn = fn, unit = unit, documented = doc ~= nil }
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

-- /hgprobe list: present vs documented, saved in HighgroundApiProbeDB.list.
function Catalog.List()
  local docs = Catalog.Docs()
  local present, count = Catalog.Present()
  local undocumented, missing = {}, {}
  for name in pairs(present) do
    if not docs.functions[name] then undocumented[#undocumented + 1] = name end
  end
  for name in pairs(docs.functions) do
    if not present[name] then missing[#missing + 1] = name end
  end
  table.sort(undocumented)
  table.sort(missing)
  local widgets, widgetUndocumented = Catalog.Widgets(), {}
  for kind, names in pairs(widgets) do
    local list = {}
    for _, name in ipairs(names) do
      if not docs.widgets[name] then list[#list + 1] = name end
    end
    widgetUndocumented[kind] = list
  end
  local list = { date = date("%Y-%m-%d %H:%M:%S"), build = ns.Build(), docsLoaded = docs.loaded, docsError = docs.err,
    systems = docs.systems, documentedCount = docs.count, presentCount = count, documented = docs.functions,
    undocumented = undocumented, missing = missing, widgets = widgets, widgetUndocumented = widgetUndocumented }
  HighgroundApiProbeDB.list = list
  return list
end
