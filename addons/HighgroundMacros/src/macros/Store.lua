local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
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

function Macros.Find(name, perCharacter)
  for _, m in ipairs(Macros.Existing()) do
    if m.name == name and m.perCharacter == (perCharacter == true) then return m end
  end
end

-- Returns ok, message.
function Macros.Save(name, body, perCharacter)
  if InCombatLockdown() then return false, Locale:Get("macros.store.leave_combat_first_macros_can_t_change.6a7314") end
  name = (name or ""):match("^%s*(.-)%s*$")
  if name == "" or #name > Macros.NAME_MAX then return false, Locale:Get("macros.store.name_must_be_1_to_16_characters.2c9301") end
  if type(body) ~= "string" or #body > Macros.BODY_MAX then return false, Locale:Get("macros.store.macro_must_be_255_characters_or_fewer.41c338") end
  local tab = perCharacter and "character" or "general"
  local old = Macros.Find(name, perCharacter)
  local after = { name = name, body = body, perCharacter = perCharacter == true }
  if old then
    if old.body == body then return true, Locale:Format("macros.store.unchanged_name.465c12", { name = name }) end
    local backup = Macros.Backups and Macros.Backups.Record(old, after, Locale:Get("macros.store.edit_import.270fbc"))
    local ok = pcall(EditMacro, old.index, name, old.icon or Macros.ICON, body)
    if not ok and backup then Macros.Backups.Discard(backup) end
    return ok, ok and (Locale:Format("macros.store.updated_name_in_your_tab_macros.7afc0d", { name = name, tab = tab })) or Locale:Get("macros.store.could_not_update_the_macro.133492")
  end
  local general, character, maxGeneral, maxCharacter = Macros.Limits()
  if (perCharacter and character >= maxCharacter) or (not perCharacter and general >= maxGeneral) then
    return false, Locale:Format("macros.store.your_tab_macro_tab_is_full.3dee79", { tab = tab })
  end
  local backup = Macros.Backups and Macros.Backups.Record(nil, after, Locale:Get("macros.store.create_import.922dc7"))
  local ok, created = pcall(CreateMacro, name, Macros.ICON, body, perCharacter and true or false)
  if not ok or not created then
    if backup then Macros.Backups.Discard(backup) end
    return false, Locale:Get("macros.store.could_not_create_the_macro.9007df")
  end
  return true, Locale:Format("macros.store.added_name_to_your_tab_macros.7d3f92", { name = name, tab = tab })
end

-- New text for an existing macro, keeping its name and icon. Returns ok.
function Macros.Rewrite(m, body)
  if InCombatLockdown() or #body > Macros.BODY_MAX then return false end
  if m.body == body then return true end
  local backup = Macros.Backups and Macros.Backups.Record(m, { name = m.name, body = body, perCharacter = m.perCharacter }, Locale:Get("macros.store.rank_update.e0bea8"))
  local ok = pcall(EditMacro, m.index, m.name, m.icon or Macros.ICON, body)
  if not ok and backup then Macros.Backups.Discard(backup) end
  return ok
end
