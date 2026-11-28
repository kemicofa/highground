local _, ns = ...
local Options, Commands = ns.Options, ns.Commands

-- Addon names in profile commands; general is the shared preferences.
local ADDONS = { battlegrounds = "battlegrounds", arena = "arena", nearby = "nearby", bounties = "bounties",
  macros = "macros", general = "shared" }
local function Addon(word) return ADDONS[word or ""] end

-- /hg export [ADDON]: this character's settings for an addon as a code.
function Commands.export(arg, msg, say)
  local addon = arg == "" and "battlegrounds" or Addon(arg)
  if not addon then return say(ns.Locale:Get("profiles.commands.usage")) end
  Options.Profiles.ShowExport(addon)
end

-- /hg import [CODE]: keep a code in the profile list (opens the window
-- without one). The slash parser lowercases arg: read the raw code.
function Commands.import(arg, msg, say)
  local raw = (msg or ""):match("^%S+%s+(.+)$")
  if not raw then return Options.Profiles.ShowImport() end
  local _, message = ns.CharacterSettings.Import(raw)
  say(message)
end

-- A profile offering addon by name, not this character.
local function Find(addon, name)
  for _, item in ipairs(ns.CharacterSettings.Profiles(addon)) do
    if item.kind ~= "self" and item.name:lower() == name:lower() then return item end
  end
end

-- /hg profile [ADDON] | copy ADDON NAME | delete NAME | share [ADDON]
function Commands.profile(arg, msg, say)
  local CS = ns.CharacterSettings
  local sub, word = arg:match("^(%S*)%s*(%S*)")
  if sub == "copy" then
    local addon, name = Addon(word), (msg or ""):match("^%S+%s+%S+%s+%S+%s+(.+)$") -- keep the name's case
    local item = addon and name and Find(addon, name)
    if not item then return say(ns.Locale:Get(addon and name and "profiles.list.missing" or "profiles.commands.usage")) end
    local ok, problem = CS.Copy(item.source, addon)
    return say(ok and ns.Locale:Format("profiles.list.copied", { name = item.name, addon = Options.Profiles.AddonLabel(addon) }) or problem)
  elseif sub == "delete" then
    local name = (msg or ""):match("^%S+%s+%S+%s+(.+)$")
    for _, addon in ipairs(ns.SettingsParts.ADDONS) do
      local item = name and Find(addon, name)
      if item and CS.Delete(item.source) then return say(ns.Locale:Format("profiles.list.deleted", { name = item.name })) end
    end
    return say(ns.Locale:Get(name and "profiles.list.missing" or "profiles.commands.usage"))
  elseif sub == "share" then
    local addon = word == "" and "battlegrounds" or Addon(word)
    if not addon then return say(ns.Locale:Get("profiles.commands.usage")) end
    local _, message = Options.Profiles.Chat.ToChat(addon)
    return say(message)
  end
  local addon = sub == "" and "battlegrounds" or Addon(sub)
  if not addon then return say(ns.Locale:Get("profiles.commands.usage")) end
  local names = {}
  for _, item in ipairs(CS.Profiles(addon)) do
    if item.kind ~= "self" then names[#names + 1] = item.name end
  end
  say(#names > 0 and ns.Locale:Format("profiles.commands.list", { addon = Options.Profiles.AddonLabel(addon), names = table.concat(names, ", ") })
    or ns.Locale:Format("profiles.commands.none", { addon = Options.Profiles.AddonLabel(addon) }))
  if Options.ShowProfiles then Options.ShowProfiles(addon) end
end
