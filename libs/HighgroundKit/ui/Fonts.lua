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
local families, familyCount, usable, probe = {}, 0, {}, nil
-- A text's own SetFont would override the family given to it later, so
-- fonts are tested on a hidden probe. Bundled fonts load only after a full
-- client restart; each file is tested once.
function ns.FontUsable(file)
  local ok = usable[file]
  if ok == nil then
    probe = probe or (UIParent and UIParent:CreateFontString(nil, "OVERLAY"))
    local called, set = false, false
    if probe then called, set = pcall(probe.SetFont, probe, file, 12, "") end
    ok = called and set and true or false
    usable[file] = ok
  end
  return ok
end
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

-- Gives fs the family for file (fallback when the file can't load); false
-- when the client has no families. The text's own font is never set: it
-- would override the family. Reapplied only when the family or the drawn
-- font changed (from outside).
function ns.SetFontFamily(fs, file, size, flags, fallback)
  if not fs.SetFontObject then return false end
  local family = ns.FontFamily(ns.FontUsable(file) and file or fallback, size, flags)
  if not family then return false end
  local current, currentSize
  if fs.GetFont then current, currentSize = fs:GetFont() end
  local seen = fs.wbFamilyFont
  if fs.wbFamily == family and seen and current == seen[1] and currentSize and math.abs(currentSize - seen[2]) < 0.001 then return true end
  fs:SetFontObject(family)
  fs.wbFamily = family
  if fs.GetFont then current, currentSize = fs:GetFont() end
  fs.wbFamilyFont = current and currentSize and { current, currentSize } or nil
  return true
end
