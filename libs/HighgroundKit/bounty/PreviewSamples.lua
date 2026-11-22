local _, ns = ...
local B, P = ns.Bounty, ns.Bounty.Public
local Demo = {}
B.Preview = Demo

-- Session-local examples. Never insert these records into stores, allocate
-- real IDs, emit model events, or pass them to the publishing/claim services.
function Demo.Ensure()
  Demo.state = Demo.state or { accountGold = true, requireGold = false, receive = true,
    publish = true, minGold = 500, capture = "pending", kills = 1, visited = {}, samples = {}, messages = {} }
  return Demo.state
end

function Demo.Sample(kind)
  local realm, now = ns.Core.myRealm or "Realm", P.Now()
  local U = ns.Util
  local unit = U.read(UnitIsPlayer, "target") and U.read(UnitIsVisible, "target")
    and ns.Core.CanonUnit("target") and "target" or "player"
  local name, poster = ns.Core.CanonUnit(unit) or ("WantedPreview-" .. realm), "PosterPreview-" .. realm
  local _, class = U.call(UnitClass, unit)
  class = U.value(class)
  local portraitLabel = U.read(UnitIsUnit, unit, "player") and "YOUR CHARACTER · SAMPLE" or "SELECTED CHARACTER · SAMPLE"
  local b = { name = name, by = poster, gold = 500, state = "approved", at = now,
    approver = "OfficerPreview-" .. realm, class = class, note = "Camps the road near Tarren Mill.", previewPortraitLabel = portraitLabel }
  local row = { name = name, by = poster, gold = 500, state = "approved", scope = "guild",
    owner = "Posted by PosterPreview", visibility = "Guild", status = b.note, note = b.note, guild = b,
    class = class, previewPortraitLabel = portraitLabel }
  if kind == "nearby" or kind == "create" or kind == "gold" or kind == "suggestions" then
    b.by, b.state = B.Me(), "personal"
    row.by, row.state, row.scope = b.by, b.state, "mine"
    row.guild, row.personal, row.owner, row.visibility = nil, b, "Your bounty", "Only me"
    row.status = "Seen now · Tarren Mill"
    if kind == "create" then b.killsRequired, b.killMethods = 1, "" end
  elseif kind ~= "guild" then
    local contributions = {}
    for i, gold in ipairs({ 500, 250 }) do
      contributions[i] = { id = "preview-offer-" .. i, contributor = "preview-account-" .. i,
        name = name, by = (i == 1 and "PosterPreview-" or "ScoutPreview-") .. realm, gold = gold,
        note = b.note, state = "active", createdAt = now, expiresAt = now + (i == 1 and 7200 or 86400),
        funds = "available", checkedAt = now, killsRequired = 3, killMethods = "execute" }
    end
    b = { name = name, gold = 750, pledgedGold = 750, state = "public", contributions = contributions,
      by = poster, note = b.note, expiresAt = now + 7200, class = class, previewPortraitLabel = portraitLabel,
      killsRequired = 3, killMethods = "execute" }
    if kind == "pot" then
      b.mega = true
      contributions[2].contract = B.Pot.Contract(contributions[1])
      contributions[2].expiresAt = contributions[1].expiresAt
    end
    row.guild, row.shared, row.gold, row.state, row.scope = nil, b, 750, "public", "public"
    row.owner, row.visibility = "2 contributions · from other players", "Shared"
    row.status = "750g funds reported available · each contribution has its own terms"
  end
  row.preview = true
  return row, b
end

function Demo.BoardSamples()
  local out, realm = {}, ns.Core.myRealm or "Realm"
  local examples = {
    { "nearby", "RoguePreview", "ROGUE", 250, "Southshore" },
    { "nearby", "MagePreview", "MAGE", 750, "Arathi Highlands" },
    { "guild", "RaiderPreview", "WARRIOR", 1000, "Stranglethorn Vale" },
    { "guild", "ScoutPreview", "HUNTER", 300, "Ashenvale", "pending" },
    { "shared", "WarlockPreview", "WARLOCK", 900, "The Hinterlands" },
    { "shared", "PaladinPreview", "PALADIN", 1500, "Eastern Plaguelands" },
  }
  for i, def in ipairs(examples) do
    local row, b = Demo.Sample(def[1])
    b.name, b.class, b.gold = def[2] .. "-" .. realm, def[3], def[4]
    b.note, b.previewPortraitLabel = "Sample target last seen in " .. def[5] .. ".", "SAMPLE TARGET"
    row.name, row.class, row.gold, row.note = b.name, b.class, b.gold, b.note
    row.status, row.location, row.previewPortraitLabel = b.note, "Last seen · " .. def[5], b.previewPortraitLabel
    if def[6] then
      b.state, b.approver, row.state = def[6], nil, def[6]
      row.status = "Awaiting officer approval"
    end
    if b.contributions then
      b.pledgedGold = b.gold
      for j, contribution in ipairs(b.contributions) do
        contribution.id, contribution.name = "preview-board-" .. i .. "-" .. j, b.name
        contribution.gold, contribution.note = b.gold * (j == 1 and 2 or 1) / 3, b.note
      end
      row.status = ns.Util.Gold(b.gold) .. " funds reported available · each contribution has its own terms"
    end
    out[#out + 1] = { row, b }
  end
  return out
end

function Demo.Claims()
  local realm, now = ns.Core.myRealm or "Realm", P.Now()
  local out = {}
  for i, state in ipairs({ "claimed", "claimed", "claimed", "approved", "paid", "rejected" }) do
    local mine = i > 2
    out[i] = { id = "preview-claim-" .. i, pledge = "preview-offer-" .. i,
      name = i <= 2 and Demo.bounty and Demo.bounty.name
        or ({ "WantedPreview-", "WantedPreview-", "RaiderPreview-", "RoguePreview-", "MagePreview-", "ScoutPreview-" })[i] .. realm,
      gold = i == 1 and 500 or 250, by = mine and B.Me() or ((i == 1 and "PosterPreview-" or "ScoutPreview-") .. realm),
      claimant = mine and ("HunterPreview-" .. realm) or B.Me(),
      public = true, previewManage = mine, received = true, state = state, claimedAt = now, killedAt = now,
      evidence = ns.Caps.combatLog and "observed killing blow" or "honor credit",
      cause = ns.Caps.combatLog and { event = "SPELL_DAMAGE", spellID = 5308, spellName = "Execute" } or nil,
      killsRequired = 3, killMethods = "execute",
      reviewedBy = state ~= "claimed" and B.Me() or nil, paidAt = state == "paid" and now or nil }
  end
  return out
end

function Demo.Wallet()
  local state, realm, now = Demo.state or {}, ns.Core.myRealm or "Realm", P.Now()
  local rows = {
    { name = B.Me(), current = true, balance = 1253742, seenAt = now },
    { name = "BankerPreview-" .. realm, balance = 17506218, seenAt = now - 3600 },
    { name = "ScoutPreview-" .. realm, balance = 3249925, seenAt = now - 86400 },
  }
  local enabled, total = state.accountGold ~= false, 0
  for _, row in ipairs(rows) do if enabled or row.current then total = total + row.balance end end
  local reserved = 7500000
  return { rows = rows, enabled = enabled, required = state.requireGold == true,
    total = total, reserved = reserved, available = math.max(0, total - reserved) }
end

function Demo.Reports()
  local name, now, realm = Demo.bounty.name, P.Now(), ns.Core.myRealm or "Realm"
  return { name = name, total = 5, personal = 2, guildDeaths = 3, guildVictimCount = 2,
    status = "5 reported deaths · Tarren Mill", victims = { [B.Me()] = 2, ["ScoutPreview-" .. realm] = 3 },
    reports = { { at = now - 60, victim = ns.Core.DisplayName(B.Me()), zone = "Tarren Mill", source = "recap" },
      { at = now - 300, victim = "ScoutPreview", zone = "Hillsbrad Foothills", source = "combat" } } }
end

Demo.scenes = {
  { key = "nearby", label = "Nearby alerts", title = "Spot a wanted player",
    description = "See the wanted popup, portrait, Nearby highlight and nameplate coin. Replay uses your sound preferences.",
    detail = "Portraits use your selected player, or your character, as a labelled example. This never places a bounty on them. Live alerts come from sightings, including targets, mouseovers and nameplates." },
  { key = "board", label = "Wanted board", title = "Wanted cards and full posters",
    description = "Click the wanted card or View bounty to inspect each contributor, their terms, funding and expiry.",
    detail = "Start tracking adds a target to My bounties. After a detected kill, View report opens its status. Posters put the target and reward first, use the parchment width for details and scroll when needed. Unavailable portraits are labelled." },
  { key = "create", label = "Create & terms", title = "Build a sample bounty",
    description = "Three steps: Target, Reward, Review. Nothing is saved until the final confirmation. One kill with any finish is the default.",
    detail = "Save returns to the tour. Sharing is optional. Private tracking can use zero gold; shared rewards need a positive amount and an expiry. Preferred finishes require the poster's review. No live reward is created." },
  { key = "gold", label = "Account gold", title = "Use gold across your characters",
    description = "See a sample wallet and the bag gold tooltip. Try both switches, then enter a reward greater than the available amount in Create & terms.",
    detail = "Account tracking is on by default. Requiring enough gold is off by default: an over-budget reward warns but can be created. Balances are scoped to this realm or Forever realmset. Alt balances update when you log in; payment and transfers remain manual." },
  { key = "guild", label = "Guild approval", title = "Submit and approve a guild bounty",
    description = "Try awaiting approval, officer approval and rejection, then inspect the resulting wanted card. These roles are available in the tour even without a guild.",
    detail = "Approved guild rewards can show a NEW BOUNTY poster. This announces a reward, not a sighting. Sharing one reward with both guild and global boards does not create a second payment obligation. On Forever, community rewards synchronize only with members of your ruleset." },
  { key = "shared", label = "Shared arrivals", title = "A bounty matches your filters",
    description = "Use Start tracking or Ignore on the incoming poster. Try sample alert settings and funding states. This target has not been spotted.",
    detail = "The notification minimum counts rewards with current available-funds reports. Imported, stale or unfunded offers remain distinguishable. Tracking pledges no gold; ignoring silences the target's bounty and sighting alerts." },
  { key = "pot", label = "Add gold", title = "Grow a bounty's pot",
    description = "Add a sample contribution, review the original poster's conditions and see the combined reward update.",
    detail = "Accepting the terms means the original poster decides whether a claim qualifies. Contributors owe their amounts to the same accepted hunter. Gold is not held or transferred by the addon." },
  { key = "exchange", label = "Share & import", title = "Copy a bounty link and review an import",
    description = "Sharing outside the addon is optional. Copy a global, guild or private bounty link, then review a sample import.",
    detail = "Choose Select link to copy, press Ctrl+C and send the bounty link. The recipient chooses Import bounty. Share in chat is available for private and group bounties. Discord channel opens the shared board destination separately. Tour links are deliberately invalid outside the tour." },
  { key = "kill", label = "Kills & reports", title = "Detected kills create reports automatically",
    description = "Use View sample report to follow review. Try repeated kills and screenshot success, failure or retry. Copying proof is optional.",
    detail = "Readable killing blows are confirmed locally. Named honor credit may include assists. A screenshot checkmark confirms only the image was saved. Reward approval and payment remain separate; manual reporting is for missed detections. This tour takes no screenshots." },
  { key = "claims", label = "Claims & payments", title = "Follow reports through review and payment",
    description = "Browse hunter and poster examples: awaiting review, approved, paid and rejected. Try Approve, Reject and Mark paid as the sample poster.",
    detail = "Hunters cannot approve their own reports. The poster reviews evidence and manually pays through the game, then records that payment. Repeated kills can count toward a multi-kill goal, without paying twice for the same reward." },
  { key = "suggestions", label = "Suggestions", title = "Review enemies suggested by death reports",
    description = "Inspect sample reports, review a prefilled bounty, dismiss the suggestion or ignore the enemy.",
    detail = "Suggestions combine your deaths and participating guild reports within the configured window. They are leads to review, not server-verified kill proof. Nothing is posted until you choose an audience and save." },
}
