local _, ns = ...
local M = ns.Macros
local H = M.Host
local B = {}
M.Backups = B

local function Character() return (H.value(H.call(UnitName, "player")) or "?") .. "-" .. (H.value(H.call(GetRealmName)) or "?") end
function B.All()
  local list = H.Get("macroBackups") or {}
  H.Set("macroBackups", list)
  return list
end
function B.Record(before, after, reason)
  local e = { before = before, after = after, reason = reason or "Edit", at = time(), character = Character() }
  table.insert(B.All(), 1, e)
  while #B.All() > 40 do table.remove(B.All()) end
  return e
end
function B.Discard(entry)
  for i, e in ipairs(B.All()) do if e == entry then table.remove(B.All(), i); return end end
end
function B.Undo(e)
  if InCombatLockdown() then return false, "Leave combat before restoring a macro." end
  if e.undone then return false, "Already restored." end
  local after = e.after
  if after.perCharacter and e.character ~= Character() then return false, "Restore this character macro on " .. e.character .. "." end
  local current = M.Find(after.name, after.perCharacter)
  if not current or current.body ~= after.body then return false, "The macro changed again. Restore its newest backup first." end
  local ok
  if e.before then
    ok = pcall(EditMacro, current.index, e.before.name, e.before.icon or M.ICON, e.before.body)
  elseif DeleteMacro then ok = pcall(DeleteMacro, current.index) end
  if not ok then return false, "Could not restore the macro." end
  e.undone = true
  if M.Window.Refresh then M.Window.Refresh() end
  return true, e.before and "Previous macro restored." or "Created macro removed."
end
function B.Open()
  if not B.win then
    B.win = H.Kit.Browser(H.PREFIX .. "MacroBackups", { title = "MACRO HISTORY",
      hint = "Last 40 writes, including imports and automatic rank updates. Restore newest changes first.",
      data = function()
        local list = {}
        for i, e in ipairs(B.All()) do
          list[#list + 1] = { key = i, backup = e, title = e.after.name,
            summary = e.reason .. "  ·  " .. (e.undone and "restored" or date("%m-%d %H:%M", e.at)),
            detail = (e.after.perCharacter and "Character" or "General") .. " macro\n" .. e.character
              .. "\n\nBefore:\n" .. (e.before and e.before.body or "Did not exist") .. "\n\nAfter:\n" .. e.after.body }
        end
        return list
      end,
      actions = { { label = "Undo change", enabled = function(e) return not e.backup.undone end,
        run = function(e) return B.Undo(e.backup) end } },
    })
  end
  B.win:Open(); return B.win
end
