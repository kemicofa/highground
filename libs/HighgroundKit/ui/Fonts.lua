local addon, ns = ...

-- Player names can use any alphabet. A font family keeps the theme face for
-- Latin text and lets the game's own fonts draw Cyrillic, Korean and
-- Chinese. One family per file, size and flags; clients without
-- CreateFontFamily keep the single face.
local ALPHABETS = { koKR = "korean", ruRU = "russian", zhCN = "simplifiedchinese", zhTW = "traditionalchinese" }
local SCRIPTS = {}
for _, def in ipairs(ns.LocaleDefinitions or {}) do
  if ALPHABETS[def.key] and def.font then SCRIPTS[ALPHABETS[def.key]] = def.font end
end
local families, familyCount = {}, 0
function ns.FontFamily(file, size, flags)
  if not CreateFontFamily then return nil end
  local key = file .. "|" .. size .. "|" .. flags
  local family = families[key]
  if family == nil then
    local members = { { alphabet = "roman", file = file, height = size, flags = flags } }
    for alphabet, other in pairs(SCRIPTS) do
      members[#members + 1] = { alphabet = alphabet, file = other, height = size, flags = flags }
    end
    familyCount = familyCount + 1
    local ok, made = pcall(CreateFontFamily, addon .. "Font" .. familyCount, members)
    family = ok and made or false
    families[key] = family
  end
  return family or nil
end
