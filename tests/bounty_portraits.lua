-- Retained native images, portable model data, and real guild/public wire paths.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " portrait sharing")
  local F = dofile("tests/bounties/public/fixture.lua")
  local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function setup(name, build, options)
    options = options or {}
    options.addon, options.client, options.build = addon, build == 40402 and "cata" or "retail", build
    options.runtime = runtime
    local s = F.new(name, options)
    local e, methods = s.env, getmetatable(s.env.UIParent).__index
    methods.GetTexture = function(f) return f.texture end
    methods.SetTexture = function(f, value)
      if s.noNativeCopy and type(value) == "string" and value:find("portrait:", 1, true) then return false end
      f.texture = value; return true
    end
    methods.ClearModel = function(f) f.displayID = nil end
    methods.SetUnit = function(f, unit)
      f.displayID = s.units[unit] and s.units[unit].displayID
      return f.displayID ~= nil
    end
    methods.GetDisplayInfo = function(f) return f.displayID end
    methods.SetDisplayInfo = function(f, id) f.displayID = id end
    -- Native portrait rendering does not use the file-texture setter.
    e.SetPortraitTexture = function(texture, unit) texture.texture = "portrait:" .. e.GetUnitName(unit, true) end
    e.SetPortraitTextureFromCreatureDisplayID = function(texture, id) texture.texture = "model:" .. id end
    e.UnitRace = function(unit) return "Human", "Human", s.units[unit] and s.units[unit].race or 1 end
    e.UnitSex = function(unit) return s.units[unit] and s.units[unit].sex or 2 end
    e.C_CreatureInfo = e.C_CreatureInfo or {}
    e.C_CreatureInfo.GetRaceInfo = function(id)
      local races = { [1] = "Human", [5] = "Scourge" }
      return races[id] and { clientFileString = races[id] }
    end
    e.GetRaceAtlas = function(race, gender, hiRes)
      if race == "scourge" then race = "undead" end
      return (hiRes and "raceicon128-" or "raceicon-") .. race .. "-" .. gender
    end
    e.C_Texture = e.C_Texture or {}
    e.C_Texture.GetAtlasInfo = function(atlas)
      if atlas:match("^raceicon128%-human%-") or atlas:match("^raceicon128%-undead%-") then return {} end
    end
    return s
  end
  local function target(s)
    s.units.target = { name = "Enemy", realm = "Other", guid = "Player-2-ABC", classID = 4,
      race = 1, sex = 2, displayID = 19723, enemy = true }
  end
  local function click(button) button.scripts.OnClick(button) end
  local function open(s, scope)
    local B = s.ns.Bounty
    local row = assert(B.BoardModel.Rows(scope)[1])
    return B.Details.Open(row).cards[1]
  end
  local function deliverGuild(a, b)
    local start = #a.sent
    while #a.ns.Bounty.queue > 0 do a.ns.Bounty.Flush() end
    for i = start + 1, #a.sent do
      local packet = a.sent[i]
      b:event("CHAT_MSG_ADDON", packet.prefix, packet.text or packet.message, "GUILD", a.ns.Bounty.Me())
    end
  end

  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(build .. ": View bounty retains the face after the observed unit disappears", function()
      for _, noCopy in ipairs({ false, true }) do
        local s = setup("Alice", build, { saved = {} })
        s.noNativeCopy = noCopy
        local B, R = s.ns.Bounty, s.ns.Bounty.Portraits
        assert(B.Add("Enemy-Other", 500)); target(s); s:event("PLAYER_TARGET_CHANGED")
        local popup = B.Poster.win
        t.equal(popup.portrait.texture, "portrait:Enemy-Other", "popup captures the real enemy")
        s.units.target = nil
        click(popup.details)
        local card = B.Details.win.cards[1]
        t.equal(card.portrait.texture, "portrait:Enemy-Other", "details reuse the native image without a unit")
        assert(card.portrait:IsVisible() and not card.fallback:IsShown(), "retained portrait is visible")
        t.equal(card.likeness:GetText(), "LAST SEEN", "native likeness stays distinguished from model fallback")
        B.Details.win:Hide(); open(s, "mine")
        t.equal(card.portrait.texture, "portrait:Enemy-Other", "reopening keeps the captured image")
        local a = assert(R.Record("Enemy-Other"))
        t.equal(a.displayID, 19723, "portable model saved alongside the local capture")
        assert(a.texture == nil and a.unit == nil, "runtime references never enter saved data")
        local again = setup("Alice", build, { saved = B.Public.Copy(s.ns.Core.db), network = B.Public.Copy(B.Public.db) })
        local restored = open(again, "mine")
        t.equal(restored.portrait.texture, "model:19723", "reload reconstructs the saved model without an enemy unit")
        t.equal(restored.likeness:GetText(), "MODEL LIKENESS", "reconstruction is labelled honestly")
        target(again); again:event("PLAYER_TARGET_CHANGED")
        t.equal(restored.portrait.texture, "portrait:Enemy-Other", "a new sighting upgrades to the actual character")
        s:assertHealthy(); again:assertHealthy()
      end
    end)

    t.test(build .. ": guild sync includes model data for a member who has never seen the player", function()
      local a = setup("Alice", build, { guild = "Watch", rank = 0, saved = {} })
      local h = setup("Hunter", build, { guild = "Watch", saved = {}, roster = { { "Alice-Realm", 0 } } })
      target(a)
      assert(a.ns.Bounty.Add("Enemy-Other", 500)); assert(a.ns.Bounty.Submit("Enemy-Other"))
      deliverGuild(a, h)
      local card = open(h, "guild")
      t.equal(card.portrait.texture, "model:19723", "guild recipient renders the shared model")
      t.equal(card.likeness:GetText(), "MODEL LIKENESS", "shared model is not presented as an exact face")
      t.equal(h.ns.Bounty.Portraits.Record("Enemy-Other").guid, "Player-2-ABC", "exact observed identity retained")
      local again = setup("Hunter", build, { guild = "Watch", saved = h.ns.Bounty.Public.Copy(h.ns.Core.db),
        network = h.ns.Bounty.Public.Copy(h.ns.Bounty.Public.db), roster = { { "Alice-Realm", 0 } } })
      t.equal(open(again, "guild").portrait.texture, "model:19723", "received model survives reload")
      a:assertHealthy(); h:assertHealthy(); again:assertHealthy()
    end)

    t.test(build .. ": player portraits persist without a creature display ID", function()
      for _, look in ipairs({ { 1, 2, "human-male" }, { 5, 3, "undead-female" } }) do
        local s = setup("Alice", build, { saved = {} })
        local B = s.ns.Bounty
        target(s)
        s.units.target.displayID, s.units.target.race, s.units.target.sex = 0, look[1], look[2]
        assert(B.Add("Enemy-Other", 500))
        local record = assert(B.Portraits.Record("Enemy-Other"), "race and body type saved without a model ID")
        t.equal(record.displayID, 0, "unknown creature display ID stays unknown")
        local again = setup("Alice", build, { saved = B.Public.Copy(s.ns.Core.db), network = B.Public.Copy(B.Public.db) })
        local card = open(again, "mine")
        t.equal(card.portrait.atlas, "raceicon128-" .. look[3], "reload uses the observed race and body type")
        assert(card.portrait:IsVisible() and not card.fallback:IsShown(), "saved race portrait is visible")
        t.equal(card.likeness:GetText(), "RACE PORTRAIT", "generic race art is labelled explicitly")
        target(again); again:event("PLAYER_TARGET_CHANGED")
        t.equal(card.portrait.texture, "portrait:Enemy-Other", "new sighting replaces the generic portrait")
        t.equal(card.likeness:GetText(), "LAST SEEN", "live capture restores the exact likeness label")
        s:assertHealthy(); again:assertHealthy()
      end
    end)

    t.test(build .. ": public offer packets and later sightings share portable portraits", function()
      local a, h = setup("Alice", build), setup("Hunter", build)
      local P, R = a.ns.Bounty.Public, a.ns.Bounty.Portraits
      target(a)
      local offer = assert(P.Post("Enemy-Other", 500, "2h"))
      P.QueueOffer(offer, "Hunter-Realm")
      local packets = F.flush(a)
      for _, packet in ipairs(packets) do
        assert(not packet.message:find("RTPortrait", 1, true), "no client-local render target sent")
        assert(#packet.message <= 255, "portrait respects the transport packet limit")
      end
      F.deliver(a, h, packets)
      local card = open(h, "public")
      t.equal(card.portrait.texture, "model:19723", "world recipient needs no enemy unit")
      t.equal(card.class:GetText(), h.ns.Util.ClassName("ROGUE"), "class travels with the appearance")
      local changed = R.Record("Enemy-Other"); changed.displayID = 20582; changed.at = changed.at + 1
      assert(R.Save(changed)); R.Queue(changed, "Hunter-Realm"); F.deliver(a, h)
      t.equal(card.portrait.texture, "model:20582", "later observation refreshes already-open cards")
      t.equal(h.ns.Bounty.Public.Find("Enemy-Other").gold, 500, "portrait updates never change a reward")
      local stopped = setup("Quiet", build, { saved = {} })
      F.deliver(a, stopped, packets)
      t.equal(stopped.ns.Bounty.Portraits.Record("Enemy-Other"), nil, "shared receiving opt-out respected")
      a:assertHealthy(); h:assertHealthy(); stopped:assertHealthy()
    end)
  end

  t.test("race portraits survive unavailable model APIs and travel through guild and public sync", function()
    for _, channel in ipairs({ "guild", "public" }) do
      local a = setup("Alice", 16001, { guild = "Watch", rank = 0 })
      local h = setup("Hunter", 16001, { guild = "Watch", roster = { { "Alice-Realm", 0 } } })
      local methods = getmetatable(a.env.UIParent).__index
      methods.GetDisplayInfo = nil
      target(a)
      local B = a.ns.Bounty
      if channel == "guild" then
        assert(B.Add("Enemy-Other", 500)); assert(B.Submit("Enemy-Other")); deliverGuild(a, h)
      else
        local offer = assert(B.Public.Post("Enemy-Other", 500, "2h"))
        B.Public.QueueOffer(offer, "Hunter-Realm"); F.deliver(a, h)
      end
      local card = open(h, channel)
      t.equal(card.portrait.atlas, "raceicon128-human-male", "recipient can display the saved race portrait")
      t.equal(h.ns.Bounty.Portraits.Record("Enemy-Other").displayID, 0, "wire preserves missing model ID")
      a:assertHealthy(); h:assertHealthy()
    end
  end)

  t.test("race fallback validates metadata and keeps the class icon when no race atlas is available", function()
    local s = setup("Alice", 16001, { saved = {} })
    local B, R = s.ns.Bounty, s.ns.Bounty.Portraits
    target(s); s.units.target.displayID = 0
    assert(B.Add("Enemy-Other", 500))
    local record = assert(R.Record("Enemy-Other"))
    for _, change in ipairs({ { "race", 0 }, { "race", -1 }, { "sex", 0 }, { "sex", 1 }, { "sex", 4 } }) do
      local bad = B.Public.Copy(record); bad[change[1]] = change[2]
      assert(not R.Validate(bad), "race-only records need valid race and body type")
    end
    local again = setup("Alice", 16001, { saved = B.Public.Copy(s.ns.Core.db), network = B.Public.Copy(B.Public.db) })
    again.env.C_Texture.GetAtlasInfo = function() return nil end
    local card = open(again, "mine")
    assert(card.fallback:IsShown() and not card.portrait:IsShown(), "unavailable race art never becomes a blank portrait")
    again.env.C_Texture.GetAtlasInfo = function() return {} end
    again:advance(0.6)
    t.equal(card.portrait.atlas, "raceicon128-human-male", "race portrait can recover when assets become available")
    s:assertHealthy(); again:assertHealthy()
  end)

  t.test("invalid, stale, unrelated or conflicting portrait records cannot replace a bounty likeness", function()
    local a, h = setup("Alice", 120100), setup("Hunter", 120100)
    target(a)
    local P, R = a.ns.Bounty.Public, a.ns.Bounty.Portraits
    local offer = assert(P.Post("Enemy-Other", 500, "2h"))
    P.QueueOffer(offer, "Hunter-Realm"); F.deliver(a, h)
    local original = assert(R.Record("Enemy-Other"))
    local nan = P.Copy(original); nan.displayID = 0 / 0
    assert(not R.Validate(nan), "non-finite display IDs rejected before serialization")
    for _, change in ipairs({ { "displayID", -1 }, { "displayID", "RTPortrait1" },
      { "at", P.Now() + 86400 }, { "at", 1 }, { "name", "Other-Other" }, { "guid", "Player-9-XYZ" }, { "guid", "" } }) do
      local bad = P.Copy(original); bad.displayID = 99999; bad[change[1]] = change[2]
      P.Enqueue("portrait", bad, "Hunter-Realm"); F.deliver(a, h)
      t.equal(h.ns.Bounty.Portraits.Record("Enemy-Other").displayID, original.displayID, "valid model kept")
      t.equal(h.ns.Bounty.Portraits.Record("Other-Other"), nil, "no unsolicited target record")
    end
    local rogue = setup("Rogue", 120100)
    P.QueueOffer(assert(P.Post("Rogue-Realm", 500, "2h")), "Hunter-Realm"); F.deliver(a, h)
    local own = { name = "Rogue-Realm", guid = "Player-1-Rogue", displayID = 99999, class = "MAGE", race = 1, sex = 2, at = P.Now() }
    rogue.ns.Bounty.Public.Enqueue("portrait", own, "Hunter-Realm"); F.deliver(rogue, h)
    t.equal(h.ns.Bounty.Portraits.Record("Rogue-Realm"), nil, "a target cannot describe itself")
    P.Enqueue("portrait", own, "Hunter-Realm"); F.deliver(a, h)
    t.equal(h.ns.Bounty.Portraits.Record("Rogue-Realm").displayID, 99999, "a hunter's report is kept")
    h:assertHealthy()
  end)

  t.test("model fallback supports older clients and previews never persist or share appearance", function()
    local s = setup("Alice", 40402, { saved = {} })
    local B, R = s.ns.Bounty, s.ns.Bounty.Portraits
    local sent = #s.sent
    target(s); B.Preview.Select("nearby"); B.Preview.Stop()
    t.equal(R.Record("Enemy-Other"), nil, "preview observation is not saved")
    t.equal(#s.sent, sent, "preview never transmits an appearance")
    assert(B.Add("Enemy-Other", 500))
    local saved, network = B.Public.Copy(s.ns.Core.db), B.Public.Copy(B.Public.db)
    local again = setup("Alice", 40402, { saved = saved, network = network })
    again.env.SetPortraitTextureFromCreatureDisplayID = nil
    local card = open(again, "mine")
    assert(card.portraitModel:IsVisible() and not card.portrait:IsShown(), "PlayerModel renders when portrait-by-display API is absent")
    t.equal(card.portraitModel.displayID, 19723, "older model API uses the saved ID")
    s:assertHealthy(); again:assertHealthy()
  end)

  t.test("delayed model loading saves the requested identity and rejects a reused unit", function()
    for _, reuse in ipairs({ false, true }) do
      local s = setup("Alice", 120100, { saved = {} })
      local B, R = s.ns.Bounty, s.ns.Bounty.Portraits
      local methods = getmetatable(s.env.UIParent).__index
      methods.SetUnit = function(f, unit) f.pendingID = s.units[unit].displayID; return true end
      target(s); assert(B.Add("Enemy-Other", 500))
      t.equal(R.Record("Enemy-Other").displayID, 0, "race data is saved before the model loads")
      s.units.target = reuse and { name = "Replacement", enemy = true } or nil
      for _, f in ipairs(s.frames) do
        if f.kind == "PlayerModel" and f.pendingID then
          f.displayID = f.pendingID; f.scripts.OnModelLoaded(f)
        end
      end
      if reuse then t.equal(R.Record("Enemy-Other").displayID, 0, "reused token cannot attach another player's model")
      else t.equal(R.Record("Enemy-Other").displayID, 19723, "late model retains the originally observed identity") end
      s:assertHealthy()
    end
  end)

  t.test("a delayed model upgrades a shared race portrait without waiting for the sighting throttle", function()
    local a, h = setup("Alice", 16001), setup("Hunter", 16001)
    local B = a.ns.Bounty
    local methods = getmetatable(a.env.UIParent).__index
    methods.SetUnit = function(f, unit) f.pendingID = a.units[unit].displayID; return true end
    target(a)
    local offer = assert(B.Public.Post("Enemy-Other", 500, "2h"))
    B.Public.QueueOffer(offer, "Hunter-Realm"); F.deliver(a, h)
    local card = open(h, "public")
    t.equal(card.likeness:GetText(), "RACE PORTRAIT", "recipient starts with race metadata")
    for _, f in ipairs(a.frames) do
      if f.kind == "PlayerModel" and f.pendingID then
        f.displayID = f.pendingID; f.scripts.OnModelLoaded(f)
      end
    end
    F.deliver(a, h)
    t.equal(card.portrait.texture, "model:19723", "late model replaces the race portrait immediately")
    t.equal(card.likeness:GetText(), "MODEL LIKENESS", "upgraded artwork has the right label")
    a:assertHealthy(); h:assertHealthy()
  end)

  t.test("evicted native captures recover from saved models and old records are bounded", function()
    local s = setup("Alice", 120100, { saved = {}, noNativeCopy = true })
    s.noNativeCopy = true
    local B, R = s.ns.Bounty, s.ns.Bounty.Portraits
    target(s); assert(B.Add("Enemy-Other", 500)); s.units.target = nil
    local card = open(s, "mine")
    assert(card.borrowedPortrait, "client uses retained native texture")
    B.Details.win:Hide()
    for i = 1, R.MAX_NATIVE + 2 do
      local name = "Seen" .. string.char(65 + math.floor(i / 26)) .. string.char(65 + i % 26)
      s.units.target = { name = name, displayID = 20582, enemy = true }
      R.Capture(name .. "-Realm", "target")
      s.now = s.now + 1
    end
    s.units.target = nil; open(s, "mine")
    t.equal(card.portrait.texture, "model:19723", "reopening an evicted card restores the right model")
    local a = assert(R.Record("Enemy-Other"))
    for i = 1, R.MAX_SAVED + 4 do
      a.name = "Stored" .. string.char(65 + math.floor(i / 26)) .. string.char(65 + i % 26) .. "-Realm"
      a.at = B.Public.Now(); assert(R.Save(a))
    end
    t.equal(F.count(B.Public.Data().portraits), R.MAX_SAVED, "persistent portraits have a fixed bound")
    assert(R.Record(a.name), "latest observation retained even with tied timestamps")
    s.now = s.now + R.MAX_AGE + 1
    t.equal(R.Record(a.name), nil, "expired model is not displayed or forwarded")
    a.at = B.Public.Now(); assert(R.Save(a))
    t.equal(F.count(B.Public.Data().portraits), 1, "saving a fresh observation prunes expired data")
    s:assertHealthy()
  end)
  t.finish("Portrait sharing: " .. t.tests .. " scenarios")
end
