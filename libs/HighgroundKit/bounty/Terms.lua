local _, ns = ...
local B = ns.Bounty
local T = { MAX_KILLS = 20 }
B.Terms = T

-- Preferences are reviewed against proof; they never establish a killing blow.
-- These use the classic class toolkit available in Forever.
T.methods = {
  ns.Localization.Define({ id = "fall", label = ns.Locale:Get("shared.kills.fall_damage.30d901"), hint = ns.Locale:Get("shared.terms.a_lethal_fall_a_priest_s_mind.c6bcce") }, { label = "shared.kills.fall_damage.30d901", hint = "shared.terms.a_lethal_fall_a_priest_s_mind.c6bcce" }),
  ns.Localization.Define({ id = "drown", label = ns.Locale:Get("shared.terms.drowning.1998e4"), hint = ns.Locale:Get("shared.terms.the_target_dies_from_drowning_include_a.d62248") }, { label = "shared.terms.drowning.1998e4", hint = "shared.terms.the_target_dies_from_drowning_include_a.d62248" }),
  ns.Localization.Define({ id = "control", label = ns.Locale:Get("macros.classesa.mind_control.9ef43a"), hint = ns.Locale:Get("shared.terms.use_priest_mind_control_to_set_up.43815e") }, { label = "macros.classesa.mind_control.9ef43a", hint = "shared.terms.use_priest_mind_control_to_set_up.43815e" }),
  ns.Localization.Define({ id = "fear", label = ns.Locale:Get("shared.terms.fear_into_danger.2dc077"), hint = ns.Locale:Get("shared.terms.use_fear_or_psychic_scream_to_send.6c34c0") }, { label = "shared.terms.fear_into_danger.2dc077", hint = "shared.terms.use_fear_or_psychic_scream_to_send.6c34c0" }),
  ns.Localization.Define({ id = "execute", label = ns.Locale:Get("shared.terms.execute_finish.265d8a"), hint = ns.Locale:Get("shared.terms.land_the_killing_blow_with_warrior_execute.d18629") }, { label = "shared.terms.execute_finish.265d8a", hint = "shared.terms.land_the_killing_blow_with_warrior_execute.d18629" }),
  ns.Localization.Define({ id = "ambush", label = ns.Locale:Get("shared.terms.ambush_finish.a014b3"), hint = ns.Locale:Get("shared.terms.land_the_killing_blow_with_rogue_ambush.fecafc") }, { label = "shared.terms.ambush_finish.a014b3", hint = "shared.terms.land_the_killing_blow_with_rogue_ambush.fecafc" }),
  ns.Localization.Define({ id = "dot", label = ns.Locale:Get("shared.terms.damage_over_time.c481a5"), hint = ns.Locale:Get("shared.terms.a_bleed_poison_corruption_or_shadow_word.775c37") }, { label = "shared.terms.damage_over_time.c481a5", hint = "shared.terms.a_bleed_poison_corruption_or_shadow_word.775c37" }),
  ns.Localization.Define({ id = "pet", label = ns.Locale:Get("shared.terms.pet_killing_blow.2356bc"), hint = ns.Locale:Get("shared.terms.a_hunter_pet_or_warlock_demon_delivers.b0187a") }, { label = "shared.terms.pet_killing_blow.2356bc", hint = "shared.terms.a_hunter_pet_or_warlock_demon_delivers.b0187a" }),
  ns.Localization.Define({ id = "wand", label = ns.Locale:Get("shared.terms.wand_finish.cfa8d3"), hint = ns.Locale:Get("shared.terms.finish_the_target_with_a_wand_shot.18d326") }, { label = "shared.terms.wand_finish.cfa8d3", hint = "shared.terms.finish_the_target_with_a_wand_shot.18d326" }),
  ns.Localization.Define({ id = "reflect", label = ns.Locale:Get("shared.terms.reflected_damage.8d95ef"), hint = ns.Locale:Get("shared.terms.thorns_retribution_aura_or_another_damage_shield.db3626") }, { label = "shared.terms.reflected_damage.8d95ef", hint = "shared.terms.thorns_retribution_aura_or_another_damage_shield.db3626" }),
  ns.Localization.Define({ id = "trap", label = ns.Locale:Get("shared.terms.trap_finish.a808d1"), hint = ns.Locale:Get("shared.terms.a_hunter_s_damaging_trap_delivers_the.e12045") }, { label = "shared.terms.trap_finish.a808d1", hint = "shared.terms.a_hunter_s_damaging_trap_delivers_the.e12045" }),
  ns.Localization.Define({ id = "unarmed", label = ns.Locale:Get("shared.terms.unarmed_finish.5dd713"), hint = ns.Locale:Get("shared.terms.unequip_your_weapons_and_land_the_final.168d55") }, { label = "shared.terms.unarmed_finish.5dd713", hint = "shared.terms.unequip_your_weapons_and_land_the_final.168d55" }),
}

function T.Gold(value)
  if value == nil or value == "" then return 0 end
  if type(value) == "string" then value = value:lower():match("^%s*(%d+)%s*g?%s*$") end
  local n = tonumber(value)
  return n and n == math.floor(n) and n >= 0 and n <= B.MAX_GOLD and n or nil
end

function T.Count(b) return b and b.killsRequired or 1 end
function T.Custom(b) return T.Count(b) > 1 or b and b.killMethods and b.killMethods ~= "" end
function T.Budget(b) return b.gold * (T.Count(b) - (b.killsStarted or 0)) end

function T.Validate(count, methods)
  count, methods = count == nil and 1 or tonumber(count), methods or ""
  if not count or count ~= math.floor(count) or count < 1 or count > T.MAX_KILLS then
    return nil, ns.Locale:Format("shared.terms.choose_a_whole_kill_count_from_1.5bc523", { T_MAX_KILLS = T.MAX_KILLS })
  end
  if type(methods) ~= "string" or #methods > 120 then return nil, ns.Locale:Get("shared.terms.invalid_kill_preferences.fafbd1") end
  local known, selected, ordered = {}, {}, {}
  for _, method in ipairs(T.methods) do known[method.id] = true end
  for id in methods:gmatch("[^.]+") do
    if not known[id] or selected[id] then return nil, ns.Locale:Get("shared.terms.invalid_kill_preferences.fafbd1") end
    selected[id] = true
  end
  for _, method in ipairs(T.methods) do if selected[method.id] then ordered[#ordered + 1] = method.id end end
  if table.concat(ordered, ".") ~= methods then return nil, ns.Locale:Get("shared.terms.invalid_kill_preferences.fafbd1") end
  return { killsRequired = count, killMethods = methods }
end

function T.Copy(to, from)
  to.killsRequired, to.killMethods = T.Count(from), from and from.killMethods or ""
  return to
end

function T.Same(a, b)
  return T.Count(a) == T.Count(b) and (a.killMethods or "") == (b.killMethods or "")
end

function T.Methods(b)
  local labels, selected = {}, "." .. (b.killMethods or "") .. "."
  for _, method in ipairs(T.methods) do
    if selected:find("." .. method.id .. ".", 1, true) then labels[#labels + 1] = method.label end
  end
  return table.concat(labels, ", ")
end

function T.Summary(b)
  local count = T.Count(b)
  local text = ns.Locale:Format("shared.terms.count_value2_requested.c4675d", { count = count, value2 = (count == 1 and ns.Locale:Get("shared.termseditor.kill.fab24c") or ns.Locale:Get("shared.termseditor.kills.e2a521")) })
  if b.gold > 0 then text = ns.Locale:Format("shared.terms.text_value3_per_approved_kill_value5.bf7354", { text = text, value3 = ns.Util.Gold(b.gold), value5 = (count > 1 and (ns.Locale:Format("shared.terms.up_to_value2.d3e589", { value2 = ns.Util.Gold(T.Budget(b)) })) or "") }) end
  local methods = T.Methods(b)
  return text .. (methods ~= "" and (ns.Locale:Format("shared.terms.preferred_finish_any_methods_proof_reviewed_manually.d4ee50", { methods = methods })) or "")
end

local function Progress(b)
  local done, pending, personal = 0, 0, b.state == "personal"
  local tracking = personal and b.by == B.Me() and not b.potID
  if b.id then
    b = B.Public.Data().offers[b.id] or b
    done = b.killsAwarded or (b.winner and b.winner ~= "" and 1 or 0)
    local accepted = 0
    for _, c in pairs(B.Public.Data().claims) do
      if c.pledge == b.id then
        if c.state == "claimed" then pending = pending + 1
        elseif c.state == "approved" or c.state == "paid" then accepted = accepted + 1 end
      end
    end
    done = math.max(done, accepted)
  else
    for _, c in ipairs(B.Ledger.All()) do
      if B.Pot.MatchesClaim(c, b) and (personal and c.personal or not personal and B.Organizations.SameClaim(c, b)) then
        if c.state == "approved" or c.state == "paid" or tracking and c.state == "claimed" then done = done + 1
        elseif c.state == "claimed" then pending = pending + 1 end
      end
    end
  end
  done = math.max(done, b.killsAwarded or 0)
  local count = T.Count(b)
  return ns.Locale:Format("shared.terms.progress_done_count_value5_value6_value7.d15742", { done = done, count = count, value5 = (tracking and ns.Locale:Get("shared.terms.kills_recorded.bbfdd4") or ns.Locale:Get("shared.terms.kills_approved.8c44fb")), value6 = (pending > 0 and (ns.Locale:Format("shared.previewflows.pending_pending_review.5d459c", { pending = pending })) or ""), value7 = (done >= count and ns.Locale:Get("shared.previewflows.complete.938ad0") or "") })
end

function T.Progress(b)
  local lines = {}
  if b.contributions then
    for _, p in ipairs(b.contributions) do
      lines[#lines + 1] = (#b.contributions > 1 and (ns.Core.DisplayName(p.by) .. " · ") or "") .. Progress(p)
    end
  else lines[1] = Progress(b) end
  return table.concat(lines, "\n")
end
