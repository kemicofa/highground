local _, ns = ...
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
  local e = { before = before, after = after, reason = reason or "Edit", at = time(),
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
function B.Undo(e)
  if InCombatLockdown() then return false, "Leave combat before restoring a macro." end
  if e.undone then return false, "Already restored." end
  local after = e.after
  if after.perCharacter and e.character ~= Character() then return false, "Restore this macro on its original character and ruleset." end
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
      hint = "This character's macro changes and shared General macros. Restore newest changes first.",
      data = function()
        local list = {}
        for i, e in ipairs(B.All()) do
          list[#list + 1] = { key = i, backup = e, title = e.after.name,
            summary = e.reason .. "  ·  " .. (e.undone and "restored" or date("%m-%d %H:%M", e.at)),
            detail = (e.after.perCharacter and "Character" or "General") .. " macro" .. (e.author and ("\n" .. e.author) or "")
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

H.Scope.Listen(function() H.Scope.Close(B.win) end)
