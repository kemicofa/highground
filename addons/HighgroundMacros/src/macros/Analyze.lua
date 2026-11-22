local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
local Macros = ns.Macros
local Host = Macros.Host
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
Host.Events({ PLAYER_LOGIN = function() C.InClientReset() end }, "macro commands")

-- Whether a spell is in your spellbook (by name).
function Macros.Known(name)
  return Host.value((Host.call(ns.Api.Fn("C_Spell", "GetSpellInfo"), name))) ~= nil
end

-- Spells you are missing for a macro on this game.
function Macros.Missing(o)
  local missing = {}
  for _, spell in ipairs(Macros.Needs(o)) do
    if not Macros.Known(spell) then missing[#missing + 1] = spell end
  end
  return missing
end

-- A one-word verdict of an Analyze result and its colour token:
-- "2 ERRORS" danger, "1 WARNING" warning, "OK" success.
function Macros.Verdict(result)
  local Plural = Host.Plural
  if result.errors > 0 then return Plural(result.errors, "ERROR"), "danger" end
  if result.warnings > 0 then return Plural(result.warnings, "WARNING"), "warning" end
  return "OK", "success"
end

function Macros.Analyze(text, opts)
  local result = C.Compile(text)
  local cancelled, castSeen = {}, false
  local function warn(line, msg)
    result.problems[#result.problems + 1] = { line = line, level = "warning", text = msg }
    result.warnings = result.warnings + 1
  end
  for _, e in ipairs(result.lines) do
    if e.cmd == "stopcasting" and castSeen then
      warn(e.n, Locale:Get("macros.analyze.stopcasting_after_a_spell_does_not_guarantee.22b324"))
    end
    if e.cmd == "cast" or e.cmd == "castsequence" or e.cmd == "castrandom" then castSeen = true end
    if (e.cmd == "use" or e.cmd == "equip") and e.clauses and ns.Api.Fn("C_Item", "GetItemCount") then
      for _, c in ipairs(e.clauses) do
        local item = c.action:match("^%s*(.-)%s*$")
        if item ~= "" and not tonumber(item) and not item:find("^%d+ %d+$") then
          local owned = ns.Api.ItemCount(item) > 0 or ns.Api.IsEquippedItem(item)
          if not owned then warn(e.n, Locale:Format("macros.analyze.you_don_t_have_item_in_your.e5c676", { item = item })) end
        end
      end
    end
    if e.cmd == "cancelaura" and e.clauses then
      for _, c in ipairs(e.clauses) do cancelled[c.action:lower()] = true end
    end
    if e.cmd == "cast" and e.clauses and not (opts and opts.pet) then
      -- A rank beside the same spell without one is a deliberate downrank
      -- ([mod:shift] Heal(Rank 2); Heal): no "leave out the rank" warning.
      local unranked = {}
      for _, c in ipairs(e.clauses) do
        if not c.action:find("%(.-%)%s*$") then unranked[c.action:gsub("^!", ""):match("^%s*(.-)%s*$")] = true end
      end
      for _, c in ipairs(e.clauses) do
        local spell = c.action:gsub("^!", ""):gsub("%(.-%)$", "")
        spell = spell:match("^%s*(.-)%s*$")
        if spell ~= "" and not tonumber(spell) and not Macros.Known(spell) then
          warn(e.n, Locale:Format("macros.analyze.spell_is_not_in_your_spellbook_other.9f2172", { spell = spell }))
        end
        if cancelled[spell:lower()] then result.toggles = true end
        local pinned = tonumber(c.action:match("%([^%d%(%)]+(%d+)%)%s*$"))
        if pinned and not Macros.Ranks.Supported() then
          warn(e.n, Locale:Get("macros.analyze.this_game_has_no_spell_ranks_leave.d5de73"))
        elseif pinned then
          local _, top = Macros.Ranks.Highest(spell)
          if top and top > pinned and not unranked[spell] then
            warn(e.n, Locale:Format("macros.analyze.spell_stays_on_rank_pinned_you_know.8d7e09", { spell = spell, pinned = pinned, top = top }))
          elseif top and pinned > top then
            warn(e.n, Locale:Format("macros.analyze.you_don_t_know_rank_pinned_of.234974", { pinned = pinned, spell = spell }))
          end
        end
      end
    end
  end
  return result
end
