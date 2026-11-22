local _, ns = ...
local B, P, E, C = ns.Bounty, ns.Bounty.Public, ns.Bounty.Exchange, ns.Codec
local M = B.Pot
local encode, decode, import, show = E.Encode, E.Decode, E.Import, E.Show
E.LINK = "highground://bounty/"
E.POT_MAX = 32768
local FIELDS = { "id", "contributor", "name", "guid", "gold", "by", "createdAt", "expiresAt", "revision", "state",
  "changedAt", "note", "funds", "checkedAt", "fundsRevision", "closedAt", "winner", "killsRequired", "killMethods",
  "killsAwarded", "killsPaid", "contract", "audience", "killsStarted", "intel", "organization" }

local function Export(b)
  local out = {}
  if b.id then
    for _, key in ipairs(FIELDS) do out[key] = P.Copy(b[key]) end
    -- Funding is deliberately unverified in an offline snapshot.
    out.funds, out.checkedAt, out.fundsRevision = "unknown", 0, 0
  else
    b.potID, b.potAt, b.expiresAt = M.ID(b), b.potAt or b.at, M.Expires(b)
    out = B.Terms.Copy({ name = b.name, by = b.by, gold = b.gold, note = b.note or "", at = b.at,
      potID = b.potID, potAt = b.potAt, expiresAt = b.expiresAt, state = b.state,
      killsAwarded = math.max(b.killsAwarded or 0, B.Ledger.Progress(b), M.DecisionProgress(b.potID)) }, b)
  end
  out.intel = B.Sightings.Pack(b)
  return out
end

function E.PotEntries(b, audience)
  if audience == "community" then return { b } end -- Export a private draft; native approval stays in game.
  local pot, out = M.Find(b.name), {}
  for _, p in ipairs(pot and pot.contributions or {}) do
    if M.Audience(p) == audience or audience == "guild" and p.id and P.GuildOffer(p) then out[#out + 1] = p end
  end
  return out
end

function E.Encode(b, audience)
  if not b then return nil, ns.Locale:Get("shared.potexchange.bounty_unavailable.3d389d") end
  local current = M.Source(M.ID(b)) or b
  if audience == "community" then return encode(current, audience) end
  local entries = E.PotEntries(current, audience)
  if #entries <= 1 and current.id and not current.contract and not current.potID and current.revision <= 1 then
    return encode(b, audience)
  end
  if not M.Live(current) then return nil, ns.Locale:Get("shared.potexchange.only_live_bounties_can_be_shared.e71e97") end
  if not ({ private = true, guild = true, community = true, global = true })[audience] then return nil, ns.Locale:Get("shared.exchangedata.choose_the_bounty_audience.b7e348") end
  local values = {}
  for _, p in ipairs(entries) do values[#values + 1] = Export(p) end
  if #values == 0 or #values > 40 then return nil, ns.Locale:Get("shared.potexchange.this_pot_cannot_fit_in_one_bounty.51deb1") end
  local packet = { version = 3, scope = P.Scope(), audience = audience, bounty = Export(current), contributions = values }
  local code = "HGB3-" .. audience:upper() .. ":" .. C.Encode64(C.Pack(packet))
  if #code > E.POT_MAX then return nil, ns.Locale:Get("shared.potexchange.this_pot_is_too_large_for_one.836203") end
  return code
end

function E.Link(b, audience)
  if not b.id then Export(b) end
  local code, err = E.Encode(b, audience)
  return code and (E.LINK .. code:gsub("%+", "-"):gsub("/", "_")) or nil, err
end

local function Validate(b, audience)
  if type(b) ~= "table" then return nil end
  if b.id then
    local out = {}; for _, key in ipairs(FIELDS) do out[key] = P.Copy(b[key]) end
    out.intel = B.Sightings.Pack(b)
    if not P.Valid(out) or not P.Active(out) or M.Audience(out) ~= audience
      and not (audience == "guild" and M.Audience(out) == "global") then return nil end
    return out
  end
  if audience == "global" or P.Name(b.name) ~= b.name or P.Name(b.by) ~= b.by or not P.ID(b.potID)
    or not P.Integer(b.gold, 0, B.MAX_GOLD) or not P.Integer(b.at, 1, P.Now() + 30)
    or not P.Integer(b.potAt, 1, b.at) or not P.Integer(b.expiresAt, b.potAt + 1, b.potAt + M.MAX_DURATION)
    or b.expiresAt <= P.Now() or type(b.note) ~= "string" or #b.note > B.NOTE_MAX or B.Clean(b.note) ~= b.note
    or not B.Terms.Validate(b.killsRequired, b.killMethods)
    or not P.Integer(b.killsAwarded or 0, 0, B.Terms.Count(b) - 1) then return nil end
  return B.Terms.Copy({ name = b.name, by = b.by, gold = b.gold, note = b.note, at = b.at,
    potID = b.potID, potAt = b.potAt, expiresAt = b.expiresAt, killsAwarded = b.killsAwarded or 0,
    state = "personal", audience = audience, importAudience = audience, intel = B.Sightings.Pack(b) }, b)
end

function E.Decode(text)
  if type(text) ~= "string" or ns.Core.issecret(text) or #text > E.POT_MAX + 8192 then return nil, ns.Locale:Get("shared.potexchange.invalid_bounty_link.6ad0f2") end
  if text:match("^%s*HGB[23]%-%u+:[%w+/=%s]+%s*$") then text = text:gsub("%s+", "") end
  local selected, ambiguous
  local function Choose(code)
    if selected and selected ~= code then ambiguous = true end
    selected = code
  end
  local plain = text:gsub("highground://bounty/([%w:=%-_]+)", function(uri)
    Choose((uri:gsub("%-", "+"):gsub("_", "/"):gsub("^(HGB[23])%+", "%1-")))
    return ""
  end)
  for code in plain:gmatch("HGB[23]%-%u+:[%w+/=]+") do Choose(code) end
  if ambiguous then return nil, ns.Locale:Get("shared.exchangedata.paste_one_bounty_at_a_time.f72bd2") end
  local code = selected and selected:match("^HGB3%-%u+:[%w+/=]+$")
  if not code then return decode(selected or text) end
  local audience, body = code:match("^HGB3%-(%u+):([%w+/=]+)$")
  audience = audience and audience:lower()
  if not ({ private = true, guild = true, community = true, global = true })[audience] or #code > E.POT_MAX then return nil, ns.Locale:Get("shared.potexchange.invalid_pot_code.3fb6a8") end
  local raw = C.Decode64(body)
  local packet = raw and C.Unpack(raw)
  if type(packet) ~= "table" or packet.version ~= 3 or packet.scope ~= P.Scope() or packet.audience ~= audience
    or type(packet.contributions) ~= "table" or #packet.contributions < 1 or #packet.contributions > 40 then return nil, ns.Locale:Get("shared.potexchange.invalid_pot_or_different_realm_faction.32483b") end
  local root, entries, ids, authors, accounts = Validate(packet.bounty, audience), {}, {}, {}, {}
  if not root then return nil, ns.Locale:Get("shared.potexchange.the_original_bounty_is_invalid_or_expired.a9b173") end
  for _, value in ipairs(packet.contributions) do
    local b = Validate(value, audience)
    if not b or b.name ~= root.name or ids[M.ID(b)] or authors[B.Key(b.by)]
      or b.contributor and accounts[b.contributor] then return nil, ns.Locale:Get("shared.potexchange.invalid_or_duplicate_pot_contribution.8fef70") end
    if M.ID(b) == M.ID(root) and C.Pack(b) ~= C.Pack(root) then return nil, ns.Locale:Get("shared.potexchange.the_original_reward_does_not_match_the.cf4d97") end
    ids[M.ID(b)], authors[B.Key(b.by)] = true, true
    if b.contributor then accounts[b.contributor] = true end
    entries[#entries + 1] = b
  end
  if not ids[M.ID(root)] then return nil, ns.Locale:Get("shared.potexchange.the_original_reward_is_missing_from_this.dfa9b3") end
  return { version = 3, audience = audience, scope = packet.scope, bounty = root, contributions = entries }
end

function E.Import(packet, replace)
  if packet.version ~= 3 then return import(packet) end
  -- Revalidate every entry before making any change, including when the
  -- review window has been left open across expiry or a realm switch.
  local code = "HGB3-" .. tostring(packet.audience):upper() .. ":" .. C.Encode64(C.Pack(packet))
  local current, err = E.Decode(code)
  if not current then return nil, err end
  local offers, originals, count, changes = P.Data().offers, M.Originals(), 0, {}
  for _ in pairs(offers) do count = count + 1 end
  for _ in pairs(originals) do count = count + 1 end
  for _, b in ipairs(current.contributions) do
    if b.id then
      local old = offers[b.id]
      if not P.Mine(b) and b.by ~= B.Me() and (not old or old.imported and b.revision > old.revision) then
        if old and (old.by ~= b.by or old.contributor ~= b.contributor or old.name ~= b.name
          or not M.SameContract(old.contract, b.contract) or not B.Terms.Same(old, b) or b.gold < old.gold) then return nil, ns.Locale:Get("shared.potexchange.the_update_changes_the_original_contribution.eeb6c5") end
        for id, other in pairs(offers) do
          if id ~= b.id and P.Active(other) and B.Key(other.name) == B.Key(b.name)
            and (other.by == b.by or other.contributor == b.contributor) then return nil, ns.Locale:Get("shared.potexchange.this_player_already_has_a_live_reward.d1b748") end
        end
        if not old then count = count + 1 end
        b.imported, b.funds, b.checkedAt, b.fundsRevision = true, "unknown", 0, 0
        b.importAudience = current.audience ~= "global" and current.audience or nil
        b.importers = old and P.Copy(old.importers) or {}
        b.importers[ns.Scope.Character()] = true
        changes[#changes + 1] = b
      elseif old and old.imported then
        if old.by ~= b.by or old.contributor ~= b.contributor or old.name ~= b.name
          or not M.SameContract(old.contract, b.contract) or not B.Terms.Same(old, b) then
          return nil, ns.Locale:Get("shared.potexchange.the_import_changes_the_original_contribution.2f055b")
        end
        local known = P.Copy(old)
        known.importers = known.importers or {}
        known.importers[ns.Scope.Character()] = true
        changes[#changes + 1] = known
      end
    else
      local own = M.Own(b.name)
      local replacing = own == replace and own and own.state == "personal" and not own.potID and own.by == B.Me()
      if own and not replacing and M.ID(own) ~= M.ID(b) and not (own.contract and own.contract.id == M.ID(b) and own.contract.by == b.by) then
        return nil, ns.Locale:Get("shared.potexchange.you_already_have_a_live_bounty_on.025256")
      end
      local old = M.Source(M.ID(b))
      if b.by ~= B.Me() then
        if old and not old.id and old.importAudience then
          if old.by ~= b.by or not B.Terms.Same(old, b) or (old.note or "") ~= b.note then return nil, ns.Locale:Get("shared.potexchange.the_original_completion_terms_cannot_change.6b751f") end
          if b.at >= old.at and b.gold >= old.gold and b.killsAwarded >= (old.killsAwarded or 0) then changes[#changes + 1] = b end
        elseif not old then
          for _, other in pairs(originals) do
            if other.by == b.by and other.name == b.name and M.Live(other) then return nil, ns.Locale:Get("shared.potexchange.this_player_already_has_a_live_reward.d1b748") end
          end
          count = count + 1; changes[#changes + 1] = b
        end
      end
    end
  end
  if count > P.MAX_OFFERS then return nil, ns.Locale:Get("shared.potexchange.the_bounty_board_is_full.4990b7") end
  for _, b in ipairs(changes) do
    B.Sightings.Copy(b, M.Source(M.ID(b)), true)
    if b.id then offers[b.id] = b
    else
      originals[M.ID(b)] = b
      local old = B.Personal()[B.Key(b.name)]
      if not old or old.by ~= B.Me() or old == replace and not old.potID then B.Personal()[B.Key(b.name)] = b end
    end
  end
  if current.audience == "global" then ns.Core.SetOption("bountyReceive", true); P.TransportTick() end
  P.cache = nil; B.Emit("updated")
  return current.bounty, ns.Locale:Get("shared.potexchange.pot_imported_offline_offers_are_unverified_the.b5688a")
end

function E.Show(b, audience)
  if b and not b.id then Export(b) end
  local w = show(b, audience)
  if not w then return end
  w.bountySource, w.bountyAudience = M.ID(b), audience
  w.bountyURL = E.Link(b, audience)
  local entries, total = E.PotEntries(b, audience), 0
  for _, p in ipairs(entries) do total = total + p.gold end
  w.post = ns.Locale:Format("shared.potexchange.live_pot_value2_per_approved_kill_value4.6e7642", { value2 = ns.Util.Gold(total), value4 = #entries, w_post = w.post })
  if b.contract then w.post = M.Explain(b) .. "\n\n" .. w.post end
  w:SelectPayload("link")
  if w.LayoutShare then w:LayoutShare() end
  return w
end

function E.RefreshShare()
  local w = E.shareWin
  if not w or not w:IsShown() or not w.bountySource then return end
  local b = M.Source(w.bountySource)
  if not b or not M.Live(b) then w:Hide(); return end
  local code = E.Encode(b, w.bountyAudience)
  if code and code ~= w.code then
    E.Show(b, w.bountyAudience)
    w:SetStatus(ns.Locale:Get("shared.potexchange.pot_updated_press_ctrl_c_to_copy.9d49dd"))
  end
end
B.Listen("updated", E.RefreshShare)
ns.Util.Every(1, E.RefreshShare, "bounty share updates", "bounties")
