local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public
local Model = {}
B.BoardModel = Model

function Model.Rows(scope, query, pending)
  if scope == "suggestions" then return B.Suggestions.Rows(query, pending) end
  local rows, groups = {}, {}
  local function Row(name)
    local key = B.Key(name)
    if not groups[key] then groups[key] = { name = name, gold = 0, scope = scope }; rows[#rows + 1] = groups[key] end
    return groups[key]
  end
  if scope == "mine" then
    for _, b in pairs(B.Personal()) do Row(b.name).personal = b end
    for _, b in ipairs(B.GuildEntries()) do if b.by == B.Me() then Row(b.name).guild = b end end
    for _, p in pairs(P.Data().offers) do if P.Mine(p) and P.Active(p) then Row(p.name).offer = p end end
  elseif scope == "guild" then
    for _, b in ipairs(B.GuildEntries()) do
      if not pending or b.state == "pending" then
        local r = Row(b.name); r.guild, r.offer = b, B.LinkedOffer(b)
      end
    end
  else
    for _, b in ipairs(P.All()) do
      local r = Row(b.name); r.shared, r.offer = b, P.Own(b.name)
      local guild = B.Guild()[B.Key(b.name)]
      if guild and guild.state ~= "removed" and B.Visible(guild) and B.LinkedOffer(guild) then r.guild = guild end
    end
  end
  local out, min = {}, ns.Core.O("bountyMinGold") or 0
  query = (query or ""):lower()
  for _, r in ipairs(rows) do
    local b, p = r.guild or r.personal, r.offer
    r.gold = r.shared and r.shared.pledgedGold or p and p.gold or b.gold
    r.by = p and p.by or b and b.by
    r.state = r.shared and "public" or r.guild and r.guild.state or p and "public" or "personal"
    r.class, r.note = b and b.class, p and p.note or b and b.note
    r.seenAt, r.seenZone, r.seenBy = b and b.seenAt, b and b.seenZone, b and b.seenBy
    r.visibility = (r.shared or p) and (r.guild and "Guild + Shared" or "Shared") or r.guild and "Guild" or "Only me"
    if r.guild and r.guild.state == "pending" then r.visibility = r.visibility .. " · awaiting officer approval" end
    if r.shared then
      r.eligible = r.shared.gold > 0 and r.shared.gold >= min
      r.muted = not r.eligible
      r.owner = #r.shared.contributions .. " contribution" .. (#r.shared.contributions == 1 and "" or "s")
        .. (p and (" · you offer " .. ns.Util.Gold(p.gold)) or " · from other players")
      r.status = r.shared.gold == 0 and "Funds need confirmation · no alert"
        or not r.eligible and ("Below your " .. ns.Util.Gold(min) .. " alert minimum")
        or (ns.Util.Gold(r.shared.gold) .. " funds reported available · matches alerts")
    else
      r.owner = scope == "mine" and (p and not P.CanManage(p) and ("Your account · posted by " .. p.by) or "Your bounty")
        or ("Posted by " .. ns.Core.DisplayName(r.by or "?"))
      r.status = p and (P.FUND_LABELS[P.Funds(p)] .. " · " .. P.Remaining(p.expiresAt) .. " left")
        or r.guild and r.guild.publicID and "Waiting for contribution details · sync guild"
        or r.note and r.note ~= "" and r.note or (r.personal and "Private target for your alerts" or "Manual reward · guild listing")
      if not p and r.seenAt then r.status = "Seen " .. B.Widgets.Ago(time() - r.seenAt):lower() .. " · " .. (r.seenZone or "unknown location") end
    end
    if query == "" or (r.name .. " " .. (r.by or "") .. " " .. r.visibility):lower():find(query, 1, true) then out[#out + 1] = r end
  end
  table.sort(out, function(a, b)
    if a.eligible ~= b.eligible then return a.eligible == true end
    return a.gold > b.gold or a.gold == b.gold and a.name < b.name
  end)
  return out
end
