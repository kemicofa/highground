local _, ns = ...
local Macros = ns.Macros

---------------------------------------------------------------------------
-- Writing macros into WoW's macro tabs: General (account-wide) or
-- Character. Same name in the chosen tab: updated in place. Macros can't be
-- created or edited in combat.
---------------------------------------------------------------------------
Macros.ICON = 134400 -- question mark: #showtooltip shows the spell instead

local Host = Macros.Host
local Call, Plain = Host.call, Host.value

function Macros.Limits()
  local general, character = Call(GetNumMacros)
  return Plain(general) or 0, Plain(character) or 0,
    MAX_ACCOUNT_MACROS or 120, MAX_CHARACTER_MACROS or (Host.Client() ~= "retail" and 18 or 30)
end

-- "general", "character" or nil: where a macro with this name already is.
function Macros.Where(name)
  local index = Plain(Call(GetMacroIndexByName, name)) or 0
  if index <= 0 then return nil end
  local _, _, maxGeneral = Macros.Limits()
  return index > maxGeneral and "character" or "general", index
end

-- fn(index, name, body, icon, perCharacter) for each existing macro, read
-- live without building tables; stops early when fn returns true.
-- perCharacter nil walks both tabs, else only that one.
function Macros.Each(fn, perCharacter)
  local general, character, maxGeneral = Macros.Limits()
  local function walk(from, to, inCharacter)
    for index = from, to do
      local name, icon, body = Call(GetMacroInfo, index)
      name = Plain(name)
      if type(name) == "string" and fn(index, name, Plain(body) or "", Plain(icon), inCharacter) then return true end
    end
  end
  if perCharacter ~= true and walk(1, general, false) then return end
  if perCharacter ~= false then walk(maxGeneral + 1, maxGeneral + character, true) end
end

local function Record(index, name, body, icon, perCharacter)
  return { name = name, icon = icon, body = body, index = index, perCharacter = perCharacter, existing = true }
end

-- Your existing macros, read live: { name, body, icon, index, perCharacter, existing = true }.
function Macros.Existing()
  local out = {}
  Macros.Each(function(...) out[#out + 1] = Record(...) end)
  return out
end

-- The macro with this name in one tab (General unless perCharacter), or nil.
-- A name in neither tab costs one lookup.
function Macros.Find(name, perCharacter)
  if type(name) ~= "string" or (Plain(Call(GetMacroIndexByName, name)) or 0) <= 0 then return nil end
  local found
  Macros.Each(function(index, n, body, icon, inCharacter)
    if n == name then found = Record(index, n, body, icon, inCharacter); return true end
  end, perCharacter == true)
  return found
end

-- Runs change() after recording a backup; the backup is discarded when
-- change fails or returns false. Returns ok.
local function Backed(before, after, reason, change)
  local backup = Macros.Backups and Macros.Backups.Record(before, after, reason)
  local ok, result = pcall(change)
  ok = ok and result ~= false
  if not ok and backup then Macros.Backups.Discard(backup) end
  return ok
end

Macros.COMBAT = "leave combat first: macros can't change in combat"

-- Returns ok, message.
function Macros.Save(name, body, perCharacter)
  if InCombatLockdown() then return false, Macros.COMBAT end
  name = (name or ""):match("^%s*(.-)%s*$")
  if name == "" or #name > Macros.NAME_MAX then return false, "name must be 1 to 16 characters" end
  if type(body) ~= "string" or #body > Macros.BODY_MAX then return false, "macro must be 255 characters or fewer" end
  local tab = perCharacter and "character" or "general"
  local old = Macros.Find(name, perCharacter)
  local after = { name = name, body = body, perCharacter = perCharacter == true }
  if old then
    if old.body == body then return true, "unchanged " .. name end
    local ok = Backed(old, after, "Edit / import", function() EditMacro(old.index, name, old.icon or Macros.ICON, body) end)
    return ok, ok and ("updated " .. name .. " in your " .. tab .. " macros") or "could not update the macro"
  end
  local general, character, maxGeneral, maxCharacter = Macros.Limits()
  if (perCharacter and character >= maxCharacter) or (not perCharacter and general >= maxGeneral) then
    return false, "your " .. tab .. " macro tab is full"
  end
  if not Backed(nil, after, "Create / import", function()
    return CreateMacro(name, Macros.ICON, body, perCharacter and true or false) ~= nil
  end) then
    return false, "could not create the macro"
  end
  return true, "added " .. name .. " to your " .. tab .. " macros"
end

-- New text for an existing macro, keeping its name and icon. Returns ok.
function Macros.Rewrite(m, body)
  if InCombatLockdown() or #body > Macros.BODY_MAX then return false end
  if m.body == body then return true end
  return Backed(m, { name = m.name, body = body, perCharacter = m.perCharacter }, "Rank update",
    function() EditMacro(m.index, m.name, m.icon or Macros.ICON, body) end)
end
