local _, ns = ...
local Macros = ns.Macros
local C = Macros.Compiler

---------------------------------------------------------------------------
-- Macros.Analyze(text[, opts]): Compile (macros/Compiler.lua) plus checks
-- that need the game: items you don't have, spells missing from your
-- spellbook (Macros.Known), pinned spell ranks (macros/Ranks.lua) and
-- toggles (cancelaura of the spell it casts).
-- opts.pet: pet macro, skip the spellbook check.
---------------------------------------------------------------------------
-- Addons register their slash commands while loading: read the client's
-- list again once they all have (macros/Compiler.lua C.InClient).
Macros.Host.Events({ PLAYER_LOGIN = function() C.InClientReset() end }, "macro commands")

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
        local pinned = tonumber(c.action:match("%([^%d%(%)]+(%d+)%)%s*$"))
        if pinned and not Macros.Ranks.Supported() then
          warn(e.n, "this game has no spell ranks: leave out the rank")
        elseif pinned then
          local _, top = Macros.Ranks.Highest(spell)
          if top and top > pinned then
            warn(e.n, spell .. " stays on rank " .. pinned .. " (you know rank " .. top
              .. "): leave out the rank to always cast your highest")
          elseif top and pinned > top then
            warn(e.n, "you don't know rank " .. pinned .. " of " .. spell .. " yet")
          end
        end
      end
    end
  end
  return result
end
