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

-- Your existing macros, read live: { name, body, icon, index, perCharacter, existing = true }.
function Macros.Existing()
  local general, character, maxGeneral = Macros.Limits()
  local out = {}
  local function read(index, perCharacter)
    local name, icon, body = Call(GetMacroInfo, index)
    name, body = Plain(name), Plain(body)
    if type(name) == "string" then
      out[#out + 1] = { name = name, icon = Plain(icon), body = body or "", index = index,
        perCharacter = perCharacter, existing = true }
    end
  end
  for i = 1, general do read(i, false) end
  for i = maxGeneral + 1, maxGeneral + character do read(i, true) end
  return out
end

-- Find a macro in the selected scope; the same name can exist in both tabs.
function Macros.Find(name, perCharacter)
  for _, m in ipairs(Macros.Existing()) do
    if m.name == name and m.perCharacter == (perCharacter == true) then return m end
  end
end

-- Returns ok, message.
function Macros.Save(name, body, perCharacter)
  if InCombatLockdown() then return false, "leave combat first: macros can't change in combat" end
  name = (name or ""):match("^%s*(.-)%s*$")
  if name == "" or #name > Macros.NAME_MAX then return false, "name must be 1 to 16 characters" end
  if type(body) ~= "string" or #body > Macros.BODY_MAX then return false, "macro must be 255 characters or fewer" end
  local tab = perCharacter and "character" or "general"
  local old = Macros.Find(name, perCharacter)
  if old then
    local ok = pcall(EditMacro, old.index, name, old.icon or Macros.ICON, body)
    return ok, ok and ("updated " .. name .. " in your " .. tab .. " macros") or "could not update the macro"
  end
  local general, character, maxGeneral, maxCharacter = Macros.Limits()
  if (perCharacter and character >= maxCharacter) or (not perCharacter and general >= maxGeneral) then
    return false, "your " .. tab .. " macro tab is full"
  end
  local ok, created = pcall(CreateMacro, name, Macros.ICON, body, perCharacter and true or false)
  if not ok or not created then return false, "could not create the macro" end
  return true, "added " .. name .. " to your " .. tab .. " macros"
end

-- New text for an existing macro, keeping its name and icon. Returns ok.
function Macros.Rewrite(m, body)
  if InCombatLockdown() or #body > Macros.BODY_MAX then return false end
  return (pcall(EditMacro, m.index, m.name, m.icon or Macros.ICON, body))
end
