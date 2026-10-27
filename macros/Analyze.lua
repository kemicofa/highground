local _, ns = ...
local Macros = ns.Macros
local C = Macros.Compiler

---------------------------------------------------------------------------
-- Macros.Analyze(text[, opts]): Compile (macros/Compiler.lua) plus checks
-- that need the game: items you don't have, spells missing from your
-- spellbook (Macros.Known) and toggles (cancelaura of the spell it casts).
-- opts.pet: pet macro, skip the spellbook check.
---------------------------------------------------------------------------
function Macros.Analyze(text, opts)
  local result = C.Compile(text)
  local cancelled = {}
  local function warn(line, msg)
    result.problems[#result.problems + 1] = { line = line, level = "warning", text = msg }
    result.warnings = result.warnings + 1
  end
  for _, e in ipairs(result.lines) do
    if e.cmd == "use" and e.clauses and GetItemCount then
      for _, c in ipairs(e.clauses) do
        local item = c.action:match("^%s*(.-)%s*$")
        if item ~= "" and not tonumber(item) and not item:find("^%d+ %d+$") then
          local owned = (tonumber(GetItemCount(item)) or 0) > 0 or (IsEquippedItem and IsEquippedItem(item))
          if not owned then warn(e.n, "you don't have " .. item .. " in your bags or equipped") end
        end
      end
    end
    if e.cmd == "cancelaura" and e.clauses then
      for _, c in ipairs(e.clauses) do cancelled[c.action:lower()] = true end
    end
    if e.cmd == "cast" and e.clauses and not (opts and opts.pet) then
      for _, c in ipairs(e.clauses) do
        local spell = c.action:gsub("^!", ""):gsub("%(.-%)$", "")
        spell = spell:match("^%s*(.-)%s*$")
        if spell ~= "" and not tonumber(spell) and not Macros.Known(spell) then
          warn(e.n, spell .. " is not in your spellbook (other spec, pet ability, typo or another language)")
        end
        if cancelled[spell:lower()] then result.toggles = true end
      end
    end
  end
  return result
end
