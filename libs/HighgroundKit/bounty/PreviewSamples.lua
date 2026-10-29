local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public
local Demo = {}
B.Preview = Demo

-- These records belong only to the preview windows. Never insert them in
-- a bounty store, emit model events, or send them through the wire service.
function Demo.Sample(kind)
  local realm, now = ns.Core.myRealm or "Realm", P.Now()
  local name, poster = "WantedPreview-" .. realm, "PosterPreview-" .. realm
  local b = { name = name, by = poster, gold = 500, state = "approved", at = now,
    approver = "OfficerPreview-" .. realm, note = "Camps the road near Tarren Mill." }
  local row = { name = name, by = poster, gold = 500, state = "approved", scope = "guild",
    owner = "Posted by PosterPreview", visibility = "Guild", status = b.note, note = b.note, guild = b }
  if kind == "nearby" then
    b.by, b.state = B.Me(), "personal"
    row.by, row.state, row.scope = b.by, b.state, "mine"
    row.guild, row.personal, row.owner, row.visibility = nil, b, "Your bounty", "Only me"
    row.status = "Seen now · Tarren Mill"
  elseif kind == "shared" or kind == "kill" then
    local contributions = {}
    for i, gold in ipairs({ 500, 250 }) do
      contributions[i] = { id = "preview-offer-" .. i, contributor = "preview-account-" .. i,
        name = name, by = (i == 1 and "PosterPreview-" or "ScoutPreview-") .. realm, gold = gold,
        note = b.note, state = "active", createdAt = now, expiresAt = now + (i == 1 and 7200 or 86400),
        funds = "available", checkedAt = now }
    end
    b = { name = name, gold = 750, pledgedGold = 750, state = "public", contributions = contributions,
      by = poster, note = b.note, expiresAt = now + 7200 }
    row.guild, row.shared, row.gold, row.state, row.scope = nil, b, 750, "public", "public"
    row.owner, row.visibility = "2 contributions · from other players", "Shared"
    row.status = "750g funds reported available · each contribution expires separately"
  end
  return row, b
end

function Demo.Claims()
  local realm, now = ns.Core.myRealm or "Realm", P.Now()
  local out = {}
  for i, state in ipairs({ "claimed", "claimed", "claimed", "approved", "paid" }) do
    local mine = i > 2
    out[i] = { id = "preview-claim-" .. i, pledge = "preview-offer-" .. i,
      name = ({ "WantedPreview-", "WantedPreview-", "RaiderPreview-", "RoguePreview-", "MagePreview-" })[i] .. realm,
      gold = i == 1 and 500 or 250, by = mine and B.Me() or ((i == 1 and "PosterPreview-" or "ScoutPreview-") .. realm),
      claimant = mine and ("HunterPreview-" .. realm) or B.Me(),
      public = true, previewManage = mine, state = state, claimedAt = now, killedAt = now,
      evidence = ns.GAME == "cata" and "observed killing blow" or "manual report",
      reviewedBy = (state == "approved" or state == "paid") and B.Me() or nil,
      paidAt = state == "paid" and now or nil }
  end
  return out
end

Demo.scenes = {
  { key = "nearby", label = "Nearby", title = "A bounty target is nearby",
    description = "The sighting plays the bounty sound and a center-screen message. The target gets a gold frame in Nearby and a coin beside its nameplate.",
    detail = "This is a private target from My bounties. Guild and shared targets use the same markers. A sighting means the addon observed the player, not that it can scan the whole zone." },
  { key = "guild", label = "Guild", title = "A guild bounty arrives",
    description = "An approved guild reward appears on the Guild board, with the poster, amount, note and green approval badge. The arrival message appears in chat.",
    detail = "Guild submissions show AWAITING APPROVAL before an officer approves them. A reward also shared globally keeps one contribution and one payment obligation." },
  { key = "shared", label = "Shared / world", title = "A shared bounty arrives",
    description = "Two contributors offer 500g + 250g on the same target. The Shared board shows 750g; View bounty shows each poster's funding and expiry. The arrival alert appears in chat.",
    detail = "Live shared alerts require receiving to be enabled and the funded total to meet your notification minimum. Smaller rewards remain in the list, muted. This preview does not change those preferences." },
  { key = "kill", label = "Kill / claims", title = "You kill a bounty target",
    description = "A claim is sent for each eligible contribution. The reward remains awaiting review until its poster approves it. Open Sample claims to see your report and try reviewing another sample hunter's report.",
    detail = "Cataclysm can observe your killing blow. Other clients use manual reports. Every reward still needs manual review and payment; an observed kill does not prove a gold transfer." },
}
