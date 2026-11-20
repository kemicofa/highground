local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public
local Model = {}
B.BoardModel = Model

function Model.Rows(scope, query, pending, organization)
  organization = organization or B.Board and B.Board.organization or "guild"
  if scope == "suggestions" then return B.Suggestions.Rows(query, pending) end
  local rows, groups = {}, {}
  local pots = {}
  for _, pot in ipairs(B.Pot.All()) do pots[B.Key(pot.name)] = pot end
  local function Row(name)
    local key = B.Key(name)
    if not groups[key] then
      groups[key] = { name = name, gold = 0, scope = scope, organization = scope == "guild" and organization or nil }
      rows[#rows + 1] = groups[key]
    end
    return groups[key]
  end
  if scope == "mine" then
    for _, b in pairs(B.Pot.Originals()) do if B.Pot.Live(b) then Row(b.name).personal = b end end
    for _, b in ipairs(P.All()) do
      if B.Matches.State(b.name) == "tracking" then local r = Row(b.name); r.shared, r.tracking = b, true end
    end
    for _, b in pairs(B.Personal()) do if B.Pot.Expires(b) > P.Now() then Row(b.name).personal = b end end
    for _, b in ipairs(B.Organizations.Entries()) do
      if b.by == B.Me() or B.Matches.State(b.name) == "tracking" then Row(b.name).guild = b end
    end
    for _, p in pairs(P.Data().offers) do
      if B.Pot.Live(p) and (P.Mine(p) or p.imported and p.importAudience) then
        local r = Row(p.name)
        if not r.offer or P.Mine(p) then r.offer = p end
      end
    end
  elseif scope == "guild" then
    for _, b in ipairs(B.GuildEntries(organization)) do
      if not pending or b.state == "pending" then
        local r = Row(b.name); r.guild, r.offer = b, B.LinkedOffer(b)
      end
    end
    for _, p in pairs(P.Data().offers) do
      if (p.audience == "guild" and B.Organizations.ID(organization) == nil and P.GuildOffer(p)
        or p.audience == "community" and p.organization == organization and B.Pot.Visible(p) and B.Pot.Live(p))
        and P.Active(p) and not pending then Row(p.name).offer = P.Own(p.name) or p end
    end
  else
    for _, b in ipairs(P.All()) do
      local r = Row(b.name); r.shared, r.offer = b, P.Own(b.name)
      local guild = B.Guild(r.offer and r.offer.organization)[B.Key(b.name)]
      if guild and guild.state ~= "removed" and B.Visible(guild) and B.LinkedOffer(guild) then r.guild = guild end
    end
  end
  local out, min = {}, ns.Core.O("bountyMinGold") or 0
  query = (query or ""):lower()
  for _, r in ipairs(rows) do
    local b, p = r.guild or r.personal, r.offer
    r.pot = pots[B.Key(r.name)]
    r.gold = r.pot and r.pot.pledgedGold or r.shared and r.shared.pledgedGold or p and p.gold or b.gold
    r.by = p and p.by or b and b.by
    r.state = r.shared and "public" or r.guild and r.guild.state or p and "public" or "personal"
    r.class, r.note = b and b.class, p and p.note or b and b.note
    r.seenAt, r.seenZone, r.seenBy = b and b.seenAt, b and b.seenZone, b and b.seenBy
    local group = B.Organizations.Label(r.guild or p)
    r.visibility = p and p.audience == "community" and group or (r.shared or p) and (r.guild and (group .. " + Shared") or "Shared") or r.guild and group or "Only me"
    if r.guild and r.guild.state == "pending" then r.visibility = r.visibility .. " · awaiting moderator approval" end
    if r.pot and #r.pot.contributions > 1 then r.visibility = r.pot.visibility end
    if r.shared then
      r.eligible = r.shared.gold > 0 and r.shared.gold >= min
      r.muted = not r.eligible
      r.owner = #r.shared.contributions .. " contribution" .. (#r.shared.contributions == 1 and "" or "s")
        .. (p and (" · you offer " .. ns.Util.Gold(p.gold)) or " · from other players")
      r.status = r.shared.gold == 0 and "Funds need confirmation · no alert"
        or not r.eligible and ("Below your " .. ns.Util.Gold(min) .. " alert minimum")
        or (r.shared.gold == r.shared.pledgedGold and "Funds reported available · matches alerts"
          or ns.Util.Gold(r.shared.gold) .. " funds reported available · matches alerts")
    else
      r.owner = scope == "mine" and (r.personal or p and P.Mine(p) or r.guild and r.guild.by == B.Me())
        and (p and not P.CanManage(p) and ("Your account · posted by " .. ns.Core.DisplayName(p.by, true)) or "Your bounty")
        or ("Posted by " .. ns.Core.DisplayName(r.by or "?"))
      r.status = p and (P.FUND_LABELS[P.Funds(p)] .. " · " .. P.Remaining(p.expiresAt) .. " left")
        or r.guild and r.guild.publicID and "Waiting for contribution details · refresh board"
        or r.note and r.note ~= "" and r.note or (r.personal and "Private target for your alerts" or "Manual reward · organization listing")
      if not p and r.seenAt then r.status = "Seen " .. B.Widgets.Ago(time() - r.seenAt):lower() .. " · " .. (r.seenZone or "unknown location") end
    end
    if r.pot and #r.pot.contributions > 1 then
      r.owner = "Mega bounty · " .. #r.pot.contributions .. " contributors"
      r.status = r.status .. " · " .. #r.pot.contributions .. " rewards"
    end
    local interest = B.Matches.State(r.name)
    local intel = B.Sightings.Combined(r)
    r.location = B.Sightings.Location(r, true)
    r.nearby = interest ~= "ignored" and B.Sightings.Near(intel.latest)
    if interest == "tracking" then r.status = "Tracking · " .. r.status
    elseif interest == "ignored" then r.status = "Ignored · alerts off"; r.muted = true end
    if query == "" or (r.name .. " " .. (r.by or "") .. " " .. r.visibility):lower():find(query, 1, true) then out[#out + 1] = r end
  end
  table.sort(out, function(a, b)
    if a.nearby ~= b.nearby then return a.nearby == true end
    if a.eligible ~= b.eligible then return a.eligible == true end
    return a.gold > b.gold or a.gold == b.gold and a.name < b.name
  end)
  return out
end
