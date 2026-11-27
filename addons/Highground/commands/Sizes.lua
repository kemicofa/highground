local _, ns = ...
local Core, Options, Commands, L = ns.Core, ns.Options, ns.Commands, ns.Locale

-- /hg sizes [10|15|40] [on|off]: the battleground sizes Highground runs in
-- for this character (Battlegrounds settings, Battleground sizes card).
-- A size alone toggles it; no arguments prints the current choices.
local SIZES = { ["10"] = "bg10", ["15"] = "bg15", ["40"] = "bg40" }

function Commands.sizes(arg, msg, say)
  if arg ~= "" then
    local size, state = arg:match("^(%d+)%s*(%a*)$")
    local key = SIZES[size or ""]
    if not key or (state ~= "" and state ~= "on" and state ~= "off") then
      local row = ns.CommandCatalog.byId.sizes
      return say((row[1]:gsub("|", "||")) .. "  " .. ns.CommandCatalog.Description(row))
    end
    local on = state == "on" or (state == "" and not Core.SizeEnabled(key))
    Core.SetSizeEnabled(key, on)
    Options.Profiles.Automatic()
  end
  local names = {}
  for _, def in ipairs(Options.BATTLEGROUND_SIZES) do
    if Core.SizeEnabled(def.key) then names[#names + 1] = L:Get(def.label) end
  end
  local character = Options.CharacterName()
  if #names == 0 then
    say(L:Format("battlegrounds.sizes.status_none", { character = character }))
  else
    say(L:Format("battlegrounds.sizes.status", { character = character, sizes = L:List(names) }))
  end
  if not Core.On("allBGs") and (Core.SizeEnabled("bg15") or Core.SizeEnabled("bg40")) then
    say(L:Get("battlegrounds.sizes.status_unrated"))
  end
end

-- /hg layout copy 10|15|40|all NAME or copy 10|15|40 profile NAME: another
-- character's layout (all: every size it has) or a saved profile. Names
-- keep their case and spaces (two-part names), so they come from msg.
local function Copy(msg, say)
  local Layouts = Options.Profiles.Layouts
  local size, rest = ((msg or ""):match("^%S+%s+%S+%s+(.+)$") or ""):match("^(%S+)%s+(.+)$")
  size = size and size:lower()
  local key = size == "all" and "bg10" or SIZES[size or ""]
  if not (key and rest) then say(L:Get("battlegrounds.layouts.usage")); return false end
  local profile = rest:match("^[Pp][Rr][Oo][Ff][Ii][Ll][Ee]%s+(.+)$")
  local source
  if profile and size ~= "all" then
    if Core.db.profiles and Core.db.profiles[profile] then source = { profile = profile } end
  else
    for _, entry in ipairs(Layouts.Characters()) do
      if entry.name:lower() == rest:lower() then source = { character = entry.key, all = size == "all" } end
    end
  end
  if not source or Layouts.Copy(key, source) == 0 then say(L:Get("battlegrounds.layouts.copy_missing")); return false end
  return true
end

-- /hg layout [create|remove|edit 10|15|40] [copy …] [remember on|off]:
-- battleground layouts for this character (the card's Create layout,
-- Remove layout, Edit, Copy from… and Remember changes). No arguments
-- prints which sizes have one.
function Commands.layout(arg, msg, say)
  local Layouts = Options.Profiles.Layouts
  local action, value = arg:match("^(%a*)%s*(.-)$")
  if action == "copy" then
    if not Copy(msg, say) then return end
  elseif action == "edit" then
    local key = SIZES[value or ""]
    if not key then return say(L:Get("battlegrounds.layouts.usage")) end
    if not Layouts.Get(key) then return say(L:Get("battlegrounds.layouts.missing")) end
    local ok, problem = Layouts.Edit(key)
    if not ok and problem then say(problem) end
    return
  elseif action == "create" or action == "remove" then
    local key = SIZES[value or ""]
    if not key then return say(L:Get("battlegrounds.layouts.usage")) end
    if action == "create" then Layouts.Create(key) elseif not Layouts.Remove(key) then
      return say(L:Get("battlegrounds.layouts.missing"))
    end
  elseif action == "remember" and (value == "on" or value == "off") then
    Layouts.SetRemember(value == "on")
  elseif arg ~= "" then
    return say(L:Get("battlegrounds.layouts.usage"))
  end
  if Options.RefreshFeatures then Options.RefreshFeatures() end
  local names, active = {}, Layouts.Active()
  for _, def in ipairs(Options.BATTLEGROUND_SIZES) do
    if Layouts.Get(def.key) then
      names[#names + 1] = def.key == active and L:Format("battlegrounds.layouts.in_use", { size = L:Get(def.label) }) or L:Get(def.label)
    end
  end
  local character = Options.CharacterName()
  say(#names == 0 and L:Format("battlegrounds.layouts.status_none", { character = character })
    or L:Format("battlegrounds.layouts.status", { character = character, sizes = L:List(names) }))
  say(L:Get(Layouts.Remember() and "battlegrounds.layouts.remember_on" or "battlegrounds.layouts.remember_off"))
end
