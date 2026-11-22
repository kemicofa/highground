local _, ns = ...
local B = ns.Bounty
local K = { recent = {}, fatal = {} }
B.Kills = K
local SPELLS = { SPELL_DAMAGE = true, SPELL_PERIODIC_DAMAGE = true, RANGE_DAMAGE = true,
  DAMAGE_SHIELD = true, DAMAGE_SPLIT = true, SPELL_INSTAKILL = true }
local ENVIRONMENT = ns.Localization.Define(ns.Localization.Define({ FALLING = ns.Locale:Get("shared.kills.fall_damage.30d901"), DROWNING = ns.Locale:Get("shared.terms.drowning.1998e4"), FATIGUE = ns.Locale:Get("shared.kills.fatigue.849afd"),
  FIRE = ns.Locale:Get("shared.kills.fire.78baeb"), LAVA = ns.Locale:Get("shared.kills.lava.b9a3fb"), SLIME = ns.Locale:Get("shared.kills.slime.1d4b24") }, { DROWNING = "shared.terms.drowning.1998e4", FATIGUE = "shared.kills.fatigue.849afd", FIRE = "shared.kills.fire.78baeb", LAVA = "shared.kills.lava.b9a3fb", SLIME = "shared.kills.slime.1d4b24" }), { FALLING = "shared.kills.fall_damage.30d901" })
local EVIDENCE = { ["manual report"] = true, ["observed killing blow"] = true, ["honor credit"] = true, ["observed death"] = true }

function K.ValidEvidence(value) return EVIDENCE[value] == true end

function K.EvidenceText(evidence, localLog)
  if evidence == "observed killing blow" then
    return localLog and ns.Locale:Get("shared.kills.killing_blow_confirmed_by_your_combat_log.bf9a3d") or ns.Locale:Get("shared.kills.hunter_s_addon_detected_a_killing_blow.93ad54")
  end
  return ({ ["honor credit"] = ns.Locale:Get("shared.kills.honor_credit_detected_may_include_assists.ed1c78"),
    ["observed death"] = ns.Locale:Get("shared.kills.death_observed_killer_unconfirmed.550d87"),
    ["manual report"] = ns.Locale:Get("shared.kills.manual_report_killing_blow_unconfirmed.55b335") })[evidence] or evidence or ns.Locale:Get("shared.kills.manual_report.cc4c84")
end

function K.Confirmed(c)
  if c.previewManage ~= nil then return false end
  for _, item in ipairs(K.History()) do
    if B.Key(item.name) == B.Key(c.name) and item.hunter == c.claimant and item.killedAt == c.killedAt
      and item.evidence == "observed killing blow" then return true end
  end
  return false
end

function K.Hint()
  return ns.Caps.combatLog and ns.Locale:Get("shared.kills.kills_are_reported_automatically_use_report_kill.6bac93")
    or ns.Locale:Get("shared.kills.named_honor_credit_is_reported_automatically_it.9395c7")
end

function K.ValidCause(cause)
  if cause == nil then return true end -- older reports have no cause
  if type(cause) ~= "table" or type(cause.event) ~= "string" then return false end
  for key in pairs(cause) do
    if not ({ event = true, spellID = true, spellName = true, environment = true, pet = true })[key] then return false end
  end
  if cause.pet ~= nil and type(cause.pet) ~= "boolean" then return false end
  if SPELLS[cause.event] then
    return B.Public.Integer(cause.spellID, 1, 10000000) and type(cause.spellName) == "string"
      and #cause.spellName > 0 and #cause.spellName <= 128 and not cause.spellName:find("[%c|]") and cause.environment == nil
  end
  if cause.spellID ~= nil or cause.spellName ~= nil then return false end
  return cause.event == "SWING_DAMAGE" and cause.environment == nil
    or cause.event == "ENVIRONMENTAL_DAMAGE" and ENVIRONMENT[cause.environment] ~= nil
end

function K.CauseText(cause)
  if not cause or not K.ValidCause(cause) then return ns.Locale:Get("shared.kills.cause_unavailable.e648ef") end
  local text = cause.spellName or ENVIRONMENT[cause.environment] or ns.Locale:Get("shared.kills.melee_attack.6206f3")
  if cause.event == "SPELL_PERIODIC_DAMAGE" then text = ns.Locale:Format("shared.kills.text_damage_over_time.4cef14", { text = text }) end
  if cause.event == "DAMAGE_SHIELD" then text = ns.Locale:Format("shared.kills.text_damage_shield.254d2e", { text = text }) end
  return text .. (cause.pet and ns.Locale:Get("shared.kills.pet.fb5cb1") or "")
end

function K.History() return B.Scope.Saved("bountyKills") end

function K.Record(b, evidence, guid, at, cause)
  local history = K.History()
  local item = { name = b.name, guid = guid, killedAt = at, evidence = evidence,
    cause = cause and B.Public.Copy(cause), hunter = B.Me() }
  table.insert(history, 1, item)
  while #history > 200 do table.remove(history) end
  return item
end

function K.Latest(name)
  for _, item in ipairs(K.History()) do if B.Key(item.name) == B.Key(name) then return item end end
end

function K.Pack(evidence, cause)
  return ns.Codec.Encode64(ns.Codec.Pack({ evidence = evidence or "manual report", cause = cause }))
end

function K.Unpack(text)
  if type(text) ~= "string" or #text > 1024 then return end
  local value = ns.Codec.Unpack(ns.Codec.Decode64(text))
  if type(value) == "table" and K.ValidEvidence(value.evidence) and K.ValidCause(value.cause) then return value end
end

-- A named honor award includes assists. Never call it a verified killing blow.
function K.HonorName(message)
  local name = ns.Honor.Name(message)
  return name and ns.Core.Canon(name) or nil
end

function K.Handle(name, evidence, guid, cause)
  if not B.Enabled() then return end
  local key, now = B.Key(name), GetTime()
  if not key or now - (K.recent[key] or -math.huge) < 5 then return end
  -- Death reports require exact identity. Sighting-only first-name matching
  -- must not claim another Forever character's bounty.
  local shared = B.Public.Find(name)
  local groups, personal = {}, B.Personal()[key]
  for _, entry in ipairs(B.Organizations.Entries()) do
    local linked = B.LinkedOffer(entry)
    if B.Key(entry.name) == key and entry.state == "approved"
      and (not guid or not linked or linked.guid == "" or linked.guid == guid) then groups[#groups + 1] = entry end
  end
  if guid and shared then
    local matches, gold, pledged = {}, 0, 0
    for _, offer in ipairs(shared.contributions) do
      if offer.guid == "" or offer.guid == guid then
        matches[#matches + 1] = offer; pledged = pledged + offer.gold
        if B.Public.Funds(offer) == "available" then gold = gold + offer.gold end
      end
    end
    shared = #matches > 0 and B.Public.Copy(shared) or nil
    if shared then shared.contributions, shared.gold, shared.pledgedGold = matches, gold, pledged end
  end
  local pot = B.Pot.Find(name)
  if personal and guid and personal.guid and personal.guid ~= "" and personal.guid ~= guid then personal = nil end
  local b = shared or groups[1] or personal
  if not b and pot then
    for _, entry in ipairs(pot.contributions) do
      if not guid or not entry.guid or entry.guid == "" or entry.guid == guid then b = entry; break end
    end
  end
  if not b then return end
  K.recent[key] = now
  local killedAt = B.Public.Now()
  local reported, message
  local record = K.Record(b, evidence, guid, killedAt, cause)
  -- An observed environmental death does not establish who caused it.
  if evidence ~= "observed death" then
    if pot then reported, message = B.Pot.Claim(pot, killedAt, evidence, true, cause, guid) end
  end
  record.reported = reported ~= nil
  record.reportText = message or (evidence == "observed death" and ns.Locale:Get("shared.kills.no_report_sent_the_game_did_not.d1e446")
    or ns.Locale:Get("shared.kills.no_eligible_reward_to_report_this_observation.a0ad4c"))
  -- Screenshots and the killed poster do not depend on funding, alert
  -- minimums, or whether a claim could be sent (including one's own offer).
  B.Proof.Show(b, evidence, killedAt, cause, record.reportText)
  B.Say(ns.Core.DisplayName(b.name) .. ": " .. K.EvidenceText(evidence, true) .. ". " .. record.reportText)
  B.Emit("updated")
end

function K.CombatLog()
  if not B.Enabled() then return end
  local _, sub, _, source, _, _, _, guid, name, flags, _, a, b, c, _, e = CombatLogGetCurrentEventInfo()
  if type(guid) ~= "string" or type(name) ~= "string" then return end
  if not guid:match("^Player%-") and not (type(flags) == "number" and bit.band(flags, 0x400) ~= 0) then return end
  local mine, pet = source == UnitGUID("player"), source ~= nil and source == UnitGUID("pet")
  if sub == "PARTY_KILL" and (mine or pet) then
    local hit = K.fatal[guid]
    local cause = hit and GetTime() - hit.at <= 2
      and (hit.source == source or hit.cause.event == "ENVIRONMENTAL_DAMAGE") and hit.cause or nil
    K.Handle(name, "observed killing blow", guid, cause)
    K.fatal[guid] = nil
    return
  end
  local cause, overkill
  if sub == "SWING_DAMAGE" then cause, overkill = { event = sub }, b
  elseif sub == "ENVIRONMENTAL_DAMAGE" then cause, overkill = { event = sub, environment = a }, c
  elseif SPELLS[sub] then cause, overkill = { event = sub, spellID = a, spellName = b }, sub == "SPELL_INSTAKILL" and 0 or e
  else return end
  if type(overkill) ~= "number" or overkill < 0 or not K.ValidCause(cause) then K.fatal[guid] = nil; return end
  local target = B.Pot.Find(name) or B.Organizations.Find(name) or B.Personal()[B.Key(name)]
  if not target then return end
  if pet then cause.pet = true end
  local count = 0
  for key, hit in pairs(K.fatal) do
    if GetTime() - hit.at > 2 then K.fatal[key] = nil else count = count + 1 end
  end
  if count >= 256 then wipe(K.fatal) end
  local hit = { cause = cause, at = GetTime(), source = source }
  K.fatal[guid] = hit
  if mine or pet then K.Handle(name, "observed killing blow", guid, cause)
  elseif sub == "ENVIRONMENTAL_DAMAGE" then
    -- Give PARTY_KILL credit arriving with this death priority over observation.
    C_Timer.After(0.1, function()
      if K.fatal[guid] == hit then K.Handle(name, "observed death", guid, cause); K.fatal[guid] = nil end
    end)
  end
end

function K.Honor(_, message)
  local name = K.HonorName(message)
  if name then K.Handle(name, "honor credit") end
end

B.Listen("scope", function() wipe(K.recent); wipe(K.fatal) end)
