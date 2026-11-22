local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
local M = ns.Macros
local H = M.Host
local B = {}
M.Backups = B

local function Character() return H.Scope.Character() end
local function Store(perCharacter)
  return H.Scope.Saved("macroBackups", perCharacter and "character" or "account")
end
function B.All()
  local list = {}
  for _, source in ipairs({ Store(false), Store(true) }) do
    for _, e in ipairs(source) do list[#list + 1] = e end
  end
  table.sort(list, function(a, b) return a.at > b.at or a.at == b.at and a.sequence > b.sequence end)
  while #list > 40 do table.remove(list) end
  return list
end
function B.Record(before, after, reason)
  local shared = H.Scope.Store("account")
  shared.macroSequence = (shared.macroSequence or 0) + 1
  local e = { before = before, after = after, reason = reason or Locale:Get("macros.backups.edit.530164"), at = time(),
    character = Character(), sequence = shared.macroSequence,
    author = H.DisplayName(H.value(H.call(GetUnitName, "player", true)) or H.value(H.call(UnitName, "player"))) }
  local list = Store(after.perCharacter)
  table.insert(list, 1, e)
  while #list > 40 do table.remove(list) end
  return e
end
function B.Discard(entry)
  local list = Store(entry.after.perCharacter)
  for i, e in ipairs(list) do if e == entry then table.remove(list, i); return end end
end
-- Why a backup cannot be restored now, or nil and the macro it changes.
function B.Check(e)
  if InCombatLockdown() then return Locale:Get("macros.backups.leave_combat_before_restoring_a_macro.661f7a") end
  if e.undone then return Locale:Get("macros.backups.already_restored.71b4c5") end
  local after = e.after
  if after.perCharacter and e.character ~= Character() then return Locale:Get("macros.backups.restore_this_macro_on_its_original_character.b72fac") end
  local current = M.Find(after.name, after.perCharacter)
  if not current or current.body ~= after.body then return Locale:Get("macros.backups.the_macro_changed_again_restore_its_newest.becc21") end
  return nil, current
end

function B.Undo(e)
  local why, current = B.Check(e)
  if why then return false, why end
  local ok
  if e.before then
    ok = pcall(EditMacro, current.index, e.before.name, e.before.icon or M.ICON, e.before.body)
  elseif DeleteMacro then ok = pcall(DeleteMacro, current.index) end
  if not ok then return false, Locale:Get("macros.backups.could_not_restore_the_macro.833691") end
  e.undone = true
  if M.Window.Refresh then M.Window.Refresh() end
  return true, e.before and Locale:Get("macros.backups.previous_macro_restored.6ec721") or Locale:Get("macros.backups.created_macro_removed.4a6fe7")
end
function B.Open()
  if not B.win then
    B.win = H.Kit.Browser(H.PREFIX .. "MacroBackups", { title = Locale:Get("macros.backups.macro_history.5e12f2"),
      hint = Locale:Get("macros.backups.this_character_s_macro_changes_and_shared.10ef5c"),
      data = function()
        local list = {}
        for i, e in ipairs(B.All()) do
          list[#list + 1] = { key = i, backup = e, title = e.after.name,
            summary = e.reason .. "  ·  " .. (e.undone and "restored" or date("%m-%d %H:%M", e.at)),
            detail = Locale:Format("macros.backups.value1_macro_value3_before_value5_after_e.2ac14a", { value1 = (e.after.perCharacter and Locale:Get("macros.backups.character.ee9946") or Locale:Get("highground.hub.general.9239ee")), value3 = (e.author and ("\n" .. e.author) or ""), value5 = (e.before and e.before.body or Locale:Get("macros.backups.did_not_exist.2c9e7b")), e_after_body = e.after.body }) }
        end
        return list
      end,
      -- A restore cannot itself be undone: the second click on the same
      -- backup confirms (Kit.Confirmation); another backup or hiding resets.
      actions = { { label = Locale:Get("macros.backups.undo_change.4fb8fe"), enabled = function(e) return not e.backup.undone end,
        run = function(e)
          local backup = e.backup
          local why = B.Check(backup)
          if why then B.confirm:Reset(); return false, why end
          if not B.confirm:Request(backup) then
            return nil, Locale:Format(backup.before and "macros.history.confirm.restore" or "macros.history.confirm.delete",
              { name = backup.after.name })
          end
          return B.Undo(backup)
        end } },
    })
    B.confirm = H.Kit.Confirmation(B.win)
  end
  B.win:Open(); return B.win
end

H.Scope.Listen(function() H.Scope.Close(B.win) end)
