return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " shared sightings")
  local F = dofile("tests/bounties/public/fixture.lua")
  local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function new(name, build, options)
    options = options or {}
    options.addon, options.build, options.client = addon, build, build == 40402 and "cata" or "retail"
    options.runtime = runtime
    local s = F.new(name, options)
    s.mapName, s.area, s.sightingMap = "Hillsbrad", "Southshore", 267
    s.env.C_Map = s.env.C_Map or {}
    s.env.C_Map.GetBestMapForUnit = function() return s.sightingMap end
    return s
  end
  local function target(s)
    s.units.target = { name = "Enemy", realm = "Other", guid = "Player-2-ABC", classID = 4, enemy = true }
  end
  local function packets(s)
    local start = #s.sent
    while #s.ns.Bounty.queue > 0 do s.ns.Bounty.Flush() end
    F.flush(s)
    local out = {}
    for i = start + 1, #s.sent do out[#out + 1] = s.sent[i] end
    return out
  end
  local function deliver(a, b) F.deliver(a, b, packets(a)) end
  -- The first card's sighting rows as "LABEL: value" lines.
  local function sightings(s, scope)
    local card, out = s.ns.Bounty.Details.Open(assert(s.ns.Bounty.BoardModel.Rows(scope or "public")[1])).cards[1], {}
    for _, row in ipairs(card.factRows) do
      if row.value:IsShown() and row.label:GetText():find("SEEN", 1, true) then out[#out + 1] = row.label:GetText() .. ": " .. row.value:GetText() end
    end
    return table.concat(out, "\n")
  end
  local function has(text, value) assert(text:find(value, 1, true), text .. " missing " .. value) end

  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(build .. ": original detection travels with the bounty and survives reload and imports", function()
      local a, h = new("Poster", build), new("Hunter", build)
      target(a)
      local B, P = a.ns.Bounty, a.ns.Bounty.Public
      local p = assert(P.Post("Enemy-Other", 500, "2h"))
      t.equal(p.intel.origin.zone, "Hillsbrad", "first observed zone saved")
      P.QueueOffer(p, "Hunter-Realm"); deliver(a, h)
      h.mapName, h.area, h.sightingMap = "Elwynn", "Goldshire", 12
      has(sightings(h), "LAST SEEN: Southshore · Hillsbrad\nPoster · ")
      local text = sightings(h)
      assert(not text:find("Goldshire", 1, true), "recipient's current area is not assigned to the enemy")
      assert(not h.ns.Bounty.Public.Data().offers[p.id].localSighting, "report is not a personal sighting")
      local again = new("Hunter", build, { saved = P.Copy(h.ns.Core.db), network = P.Copy(h.ns.Bounty.Public.db) })
      has(sightings(again), "LAST SEEN: Southshore · Hillsbrad")
      for _, link in ipairs({ assert(B.Exchange.Encode(p, "global")), assert(B.Exchange.Link(p, "global")) }) do
        local offline = new("Offline", build)
        local packet = assert(offline.ns.Bounty.Exchange.Decode(link))
        assert(offline.ns.Bounty.Exchange.Import(packet))
        has(sightings(offline), "LAST SEEN: Southshore · Hillsbrad")
        offline:assertHealthy()
      end
      a:assertHealthy(); h:assertHealthy(); again:assertHealthy()
    end)

    t.test(build .. ": trackers share sightings; nearby hunters get priority and distant hunters get reports", function()
      local a, scout = new("Poster", build), new("Scout", build, { saved = { bountyReceive = true } })
      local near, far = new("Near", build), new("Far", build)
      target(a)
      local p = assert(a.ns.Bounty.Public.Post("Enemy-Other", 500, "2h"))
      local clients = { scout, near, far }
      for _, h in ipairs(clients) do
        a.ns.Bounty.Public.QueueOffer(p, h.ns.Bounty.Me()); deliver(a, h)
        h.ns.Bounty.Matches.Set(p.name, "tracking")
      end
      far.mapName, far.area, far.sightingMap = "Elwynn", "Goldshire", 12
      scout.area, scout.now = "Tarren Mill", scout.now + 2
      target(scout)
      scout.units.nameplate1, scout.units.target = scout.units.target, nil
      for _, h in ipairs({ near, far }) do scout.ns.Bounty.Public.peers[h.ns.Bounty.Me()] = scout.now end
      scout.ns.Bounty.UpdatePlates()
      local updates = packets(scout)
      assert(#updates > 0, "automatic nameplate detection shares without targeting or advertising own pledges")
      for _, h in ipairs({ near, far }) do F.deliver(scout, h, updates) end
      local n = near.ns.Bounty
      local record = n.Public.Data().offers[p.id]
      t.equal(record.intel.latest.by, "Scout-Realm", "reporter attributed")
      t.equal(record.intel.latest.area, "Tarren Mill", "new area propagated")
      t.equal(record.intel.origin.area, "Southshore", "original detection retained")
      assert(not n.seen[n.Key(p.name)] and not record.localSighting, "remote report is never a direct sighting")
      t.equal(n.Poster.win.status:GetText(), "REPORTED IN YOUR ZONE", "nearby alert is clearly reported")
      has(n.Poster.win.location:GetText(), "Tarren Mill"); has(n.Poster.win.location:GetText(), "Scout")
      assert(not far.ns.Bounty.Poster.win, "distant report does not create a nearby poster")
      assert(F.said(far, "Bounty sighting:") > 0, "distant tracker gets the update")
      assert(n.BoardModel.Rows("mine")[1].nearby, "board prioritizes a recent report in this zone")
      local shown = F.said(near, "Bounty reported in your zone:")
      F.deliver(scout, near, updates)
      t.equal(F.said(near, "Bounty reported in your zone:"), shown, "duplicate report does not alert again")
      t.equal(#n.Public.outbox, 0, "received sightings are never rebroadcast")
      scout.now = scout.now + 1; scout.ns.Bounty.UpdatePlates()
      t.equal(#scout.ns.Bounty.Public.outbox, 0, "continuous visibility is throttled")
      near.now = near.now + n.Sightings.FRESH + 3
      assert(not n.BoardModel.Rows("mine")[1].nearby, "old report loses nearby priority")
      for _, h in ipairs(clients) do h:assertHealthy() end
      a:assertHealthy()
    end)
  end

  t.test("guild metadata and sightings stay in their audience; private bounty locations stay local", function()
    local a = new("Officer", 16001, { guild = "Watch", rank = 0, saved = {} })
    local h = new("Hunter", 16001, { guild = "Watch", saved = {}, roster = { { "Officer-Realm", 0 } } })
    target(a)
    assert(a.ns.Bounty.Add("Enemy-Other", 500))
    t.equal(#a.ns.Bounty.Public.outbox, 0, "private sighting sends nothing")
    assert(a.ns.Bounty.Submit("Enemy-Other")); deliver(a, h)
    has(sightings(h, "guild"), "LAST SEEN: Southshore · Hillsbrad")
    a.area, a.now = "Tarren Mill", a.now + 2
    a:event("PLAYER_TARGET_CHANGED")
    local updates = packets(a)
    for _, packet in ipairs(updates) do t.equal(packet.channel, "GUILD", "guild sighting never enters public channel") end
    F.deliver(a, h, updates)
    has(sightings(h, "guild"), "LAST SEEN: Tarren Mill · Hillsbrad")
    has(sightings(h, "guild"), "FIRST SEEN: Southshore · Hillsbrad")
    a:assertHealthy(); h:assertHealthy()
  end)

  t.test("unseen named targets have no invented origin; private exports preserve genuine observations", function()
    local a, h = new("Poster", 16001, { saved = {} }), new("Hunter", 16001, { saved = {} })
    local B = a.ns.Bounty
    local b = assert(B.Add("Enemy-Other", 500))
    assert(not b.intel, "typing a name does not locate the enemy in the poster's zone")
    target(a); a:event("PLAYER_TARGET_CHANGED")
    local code = assert(B.Exchange.Link(b, "private"))
    assert(h.ns.Bounty.Exchange.Import(assert(h.ns.Bounty.Exchange.Decode(code))))
    has(sightings(h, "mine"), "SEEN: Southshore · Hillsbrad")
    t.equal(#h.ns.Bounty.Public.outbox, 0, "private import does not broadcast locations")
    local chat = new("Chat", 16001, { saved = {} })
    local payload = assert(B.Share.Encode(b))
    chat.ns.Bounty.Share.ShowImport(payload); chat.ns.Bounty.Share.Import()
    has(sightings(chat, "mine"), "SEEN: Southshore · Hillsbrad")
    chat:assertHealthy()
    a:assertHealthy(); h:assertHealthy()
  end)

  t.test("zone changes can be shared promptly, and an older heartbeat cannot roll back a newer report", function()
    local a, h = new("Poster", 16001), new("Hunter", 16001)
    target(a)
    local p = assert(a.ns.Bounty.Public.Post("Enemy-Other", 500, "2h"))
    a.ns.Bounty.Public.QueueOffer(p, "Hunter-Realm"); deliver(a, h)
    local old = a.ns.Bounty.Public.Copy(p)
    a.now = a.now + a.ns.Bounty.Sightings.MOVE_GAP
    a.mapName, a.area, a.sightingMap = "Arathi", "Refuge Pointe", 14
    a:event("PLAYER_TARGET_CHANGED"); deliver(a, h)
    local P = h.ns.Bounty.Public
    t.equal(P.Data().offers[p.id].intel.latest.zone, "Arathi", "new zone bypasses the normal one-minute gap")
    old.fundsRevision = old.fundsRevision + 1
    P.Merge(old, old.by, "CHANNEL")
    t.equal(P.Data().offers[p.id].intel.latest.zone, "Arathi", "older metadata cannot roll back the last report")
    t.equal(P.Data().offers[p.id].intel.origin.zone, "Hillsbrad", "heartbeat preserves original detection")
    P.Data().offers[p.id].imported = true
    assert(P.Merge(old, old.by, "CHANNEL"))
    t.equal(P.Data().offers[p.id].intel.latest.zone, "Arathi", "authenticating an imported bounty also preserves newer reports")
    h:assertHealthy()
  end)

  t.test("guild queued sightings cannot follow the player into another guild", function()
    local s = new("Officer", 16001, { guild = "Watch", rank = 0, saved = {} })
    target(s); assert(s.ns.Bounty.Add("Enemy-Other", 500)); assert(s.ns.Bounty.Submit("Enemy-Other"))
    s.now = s.now + 1; s:event("PLAYER_TARGET_CHANGED")
    assert(#s.ns.Bounty.Public.outbox > 0, "guild metadata and sighting queued")
    s.guild = "Different"
    local sent = F.flush(s)
    t.equal(#sent, 0, "queued data is discarded after guild membership changes")
    s:assertHealthy()
  end)

  t.test("hidden or dead targets and previews do not send live sightings", function()
    local s = new("Scout", 16001)
    local B = s.ns.Bounty
    local p = assert(B.Public.Post("Enemy-Other", 500, "2h"))
    packets(s); B.Matches.Set(p.name, "tracking")
    target(s); s.units.target.dead = true; s:event("PLAYER_TARGET_CHANGED")
    assert(not p.intel and #B.Public.outbox == 0, "a corpse does not produce a live report")
    s.units.target.dead, s.units.target.visible = false, false; s:event("PLAYER_TARGET_CHANGED")
    assert(not p.intel and #B.Public.outbox == 0, "out-of-view identity does not locate the target")
    s.units.target.visible = true; B.Preview.Select("nearby"); B.Preview.Stop()
    assert(not p.intel and #B.Public.outbox == 0, "preview does not create a real sighting")
    s:assertHealthy()
  end)

  t.test("sighting reports reject stale, spoofed, unrelated and conflicting data and respect ignores", function()
    local a, h = new("Poster", 16001), new("Hunter", 16001)
    target(a)
    local p = assert(a.ns.Bounty.Public.Post("Enemy-Other", 500, "2h"))
    a.ns.Bounty.Public.QueueOffer(p, "Hunter-Realm"); deliver(a, h)
    local B, P = h.ns.Bounty, h.ns.Bounty.Public
    local good = P.Copy(p.intel.latest); good.by, good.at, good.area = "Scout-Realm", good.at + 2, "Tarren Mill"
    local function receive(report, id, name)
      B.Sightings.Receive({ id = id or p.id, name = name or p.name, report = report }, "Scout-Realm", "CHANNEL")
    end
    for _, change in ipairs({ { "by", "Someone-Realm" }, { "at", P.Now() - 500 }, { "at", P.Now() + 500 },
      { "zone", "|Hbad|h" }, { "mapID", -1 }, { "guid", "Player-9-OTHER" }, { "world", false } }) do
      local bad = P.Copy(good); bad[change[1]] = change[2]; receive(bad)
      t.equal(P.Data().offers[p.id].intel.latest.area, "Southshore", "invalid report cannot overwrite location")
    end
    receive(good, "unknown-offer"); receive(good, p.id, "Unrelated-Other")
    t.equal(P.Data().offers[p.id].intel.latest.area, "Southshore", "report must identify a known bounty")
    B.Matches.Set(p.name, "ignored"); receive(good)
    t.equal(P.Data().offers[p.id].intel.latest.area, "Tarren Mill", "ignored target can retain updated board information")
    assert(not B.Poster.win, "ignored sightings never alert")
    t.equal(#P.outbox, 0, "remote update creates no network loop")
    h:assertHealthy()
  end)
  t.finish("Shared sightings: " .. t.tests .. " scenarios")
end
