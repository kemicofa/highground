local test, new, equal = ...
local URL = "https://discord.gg/xu3VsxRjca"
local function click(button) button.scripts.OnClick(button) end
local function forever(sim, env)
  sim.faction = 0
  env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  env.GetCurrentRegion = function() return 3 end -- Europe
end
local function create(saved, configure)
  return new("retail", saved, function(sim, env)
    forever(sim, env)
    if configure then configure(sim, env) end
  end)
end

for _, way in ipairs({ "later", "close", "escape" }) do
test("Forever Discord offer survives " .. way .. ", reloads and profile changes", function()
  local sim = create(nil)
  sim:advance(3)
  local C, O = sim.ns.Community, sim.ns.Onboarding
  assert(C.win:IsVisible() and not O.win, "only the invitation opens first")
  equal(sim.env.HighgroundCharDB.highgroundCommunityOffered, true, "offer saved for this character when actually shown")
  equal(sim.env.HighgroundDB.highgroundCommunityOffered, nil, "the account does not own dismissal")
  if way == "escape" then C.win:Hide() else click(C.win[way]) end
  sim:advance(3)
  assert(O.win:IsVisible(), "the first-install feature guide is still offered")
  O.Dismiss()
  local CS = sim.ns.CharacterSettings
  for _, addon in ipairs({ "shared", "battlegrounds" }) do
    local ok, _, index = CS.Import(CS.Export(addon), "Saved")
    assert(ok and CS.Copy({ import = index }, addon), "copying " .. addon .. " settings back")
  end
  local again = create(sim.env.HighgroundDB, function(_, env) env.HighgroundCharDB = sim.env.HighgroundCharDB end)
  again:advance(3)
  assert(not again.ns.Community.win, "the same character gets no repeat")
  again:event("PLAYER_ENTERING_WORLD"); again:setCombat(true); again:setCombat(false); again:advance(3)
  assert(not again.ns.Community.win, "world and combat events cannot repeat the offer")
  again.ns.Hub.Open("home")
  click(again.ns.Hub.home.community)
  assert(again.ns.Community.copy:IsVisible(), "Home opens the invite directly")
  equal(again.ns.Community.copy:GetText(), URL, "a dismissed character can still join Discord")
  click(again.ns.Community.copy.done)
  assert(again.ns.Hub.home:IsVisible(), "closing the manual invitation returns Home")
end)
end

for _, faction in ipairs({ 0, 1 }) do
test("each alt gets its own Discord offer, faction " .. faction, function()
  local main = create({})
  main:advance(3); click(main.ns.Community.win.later)
  local alt = create(main.env.HighgroundDB, function(s, env)
    s.faction = faction
    env.HighgroundCharDB = {}
  end)
  alt:advance(3)
  local C = alt.ns.Community
  assert(C.win:IsVisible(), "another character on the same account receives its own offer")
  click(C.win.join)
  equal(C.copy:GetText(), URL, "both factions use the same Discord invite")
  click(C.copy.done); click(C.win.later)
  local again = create(alt.env.HighgroundDB, function(s, env)
    s.faction = faction
    env.HighgroundCharDB = alt.env.HighgroundCharDB
  end)
  again:advance(3)
  assert(not again.ns.Community.win, "this alt is not prompted twice")
  again.ns.Hub.Open("home"); click(again.ns.Hub.home.community)
  equal(again.ns.Community.copy:GetText(), URL, "Home uses the same Discord invite")
end)
end

for _, faction in ipairs({ 0, 1 }) do
test("Discord invitations span rulesets for faction " .. faction, function()
  for _, ruleset in ipairs({ "PvE", "PvP", "RP", "RP-PvP" }) do
    local sim = create({}, function(s, env)
      s.faction = faction
      env.Enum.GameRule = { HardcoreRuleset = 1, RPRuleset = 2, PvPRuleset = 3 }
      env.C_GameRules = { IsGameRuleActive = function(rule)
        if rule == 2 then return ruleset == "RP" or ruleset == "RP-PvP" end
        if rule == 3 then return ruleset == "PvP" or ruleset == "RP-PvP" end
        return false
      end }
    end)
    equal(sim.ns.Scope.Ruleset(), ruleset, "the game exposes the requested ruleset")
    sim:advance(3)
    assert(sim.ns.Community.win:IsVisible(), "every ruleset receives the offer")
    click(sim.ns.Community.win.join)
    equal(sim.ns.Community.copy:GetText(), URL, "the invite does not change with the ruleset")
  end
end)
end

test("existing Forever installations receive the new invitation once", function()
  local sim = create({ sniper = false, nearby = false, onboarding = { version = 2, dismissed = true } })
  sim:advance(3)
  assert(not sim.ns.Core.firstInstall and sim.ns.Community.win:IsVisible())
  click(sim.ns.Community.win.later); sim:advance(3)
  assert(not sim.ns.Onboarding.win, "an upgrade does not start the feature guide")
  equal(sim.ns.Core.On("sniper"), false, "existing preferences survive")
  equal(sim.ns.Core.On("nearby"), false, "existing preferences survive")
end)

for _, client in ipairs({ "retail", "cata" }) do
test(client .. " exposes Discord on Home without an automatic invitation", function()
  local sim = new(client, {}, function(_, env) env.GetCurrentRegion = function() return 3 end end)
  sim:advance(3)
  local C = sim.ns.Community
  assert(not C.win and not C.copy)
  equal(sim.ns.Core.pos.highgroundCommunityOffered, nil, "login does not consume the offer")
  sim.ns.Hub.Open("home")
  click(sim.ns.Hub.home.community)
  assert(C.copy:IsVisible(), "Home opens a copyable invite")
  equal(C.copy:GetText(), URL, "Home uses Bounty's permanent Discord invite")
  click(C.copy.done)
  assert(sim.ns.Hub.home:IsVisible(), "Close returns to Home")
  sim:assertHealthy()
end)
end

for _, region in ipairs({ 1, 2, 4, 5, 0, 99, "missing", "unavailable", "error" }) do
test("Discord invitation works outside EU and without region information, region " .. region, function()
  for _, faction in ipairs({ 0, 1 }) do
    local sim = create(nil, function(s, env)
      s.faction = faction
      if region == "missing" then
        env.GetCurrentRegion = nil
      else
        env.GetCurrentRegion = function()
          if region == "error" then error("region unavailable") end
          if region ~= "unavailable" then return region end
        end
      end
    end)
    sim:advance(3)
    local C, O = sim.ns.Community, sim.ns.Onboarding
    assert(C.win:IsVisible(), "Discord has no game-region restriction")
    click(C.win.join)
    equal(C.copy:GetText(), URL, "all regions use the same Discord invite")
    click(C.copy.done); click(C.win.later); sim:advance(3)
    assert(O.win:IsVisible(), "closing the invitation still offers the feature guide")
    O.Dismiss()
    sim.ns.Hub.Open("home")
    click(sim.ns.Hub.home.community)
    equal(C.copy:GetText(), URL, "Home keeps the Discord invite available")
    click(C.copy.done)
    sim.ns.Hub.win:Hide()
    sim:event("PLAYER_ENTERING_WORLD"); sim:event("UNIT_FACTION", "player")
    sim:setCombat(true); sim:setCombat(false); sim:advance(3)
    assert(not C.win:IsVisible() and not C.copy:IsVisible(), "events do not repeat a dismissed invitation")
    equal(sim.ns.Core.pos.highgroundCommunityOffered, true, "the offer is recorded per character")
    sim:assertHealthy()
  end
end)
end

test("community invitation waits through combat, instances and busy tools", function()
  local sim = create({})
  sim:setCombat(true)
  sim:advance(3)
  assert(not sim.ns.Community.win and not sim.ns.Core.pos.highgroundCommunityOffered)
  sim.inBG = true; sim:setCombat(false); sim:advance(3)
  assert(not sim.ns.Community.win and not sim.ns.Core.pos.highgroundCommunityOffered)
  sim.ns.Hub.Open("home"); sim:leave(); sim:advance(3)
  assert(not sim.ns.Community.win, "an active tool keeps the offer pending")
  sim.ns.Hub.win:Hide(); sim:advance(3)
  assert(sim.ns.Community.win:IsVisible(), "closing the tool retries the pending invitation")
  sim:setCombat(true)
  assert(not sim.ns.Community.win:IsVisible(), "combat clears the displayed prompt")
  sim:setCombat(false); sim:advance(3)
  assert(not sim.ns.Community.win:IsVisible(), "an already displayed prompt stays dismissed")
end)

test("community invitation stays pending across reloads before it can be shown", function()
  local sim = create({}, function(s) s.inBG = true end)
  sim:advance(3)
  equal(sim.ns.Core.pos.highgroundCommunityOffered, nil, "instances cannot consume an unseen offer")
  local again = create(sim.env.HighgroundDB, function(_, env) env.HighgroundCharDB = sim.env.HighgroundCharDB end)
  again:advance(3)
  assert(again.ns.Community.win:IsVisible())
end)

test("Discord joining never opens or redeems a native community invitation", function()
  local calls = 0
  local function native() calls = calls + 1 end
  local sim = create(nil, function(s, env)
    env.C_Club = { RequestTicket = native, RedeemTicket = native }
    env.CommunitiesHyperlink = { OnClickLink = native }
    env.C_AddOns.LoadAddOn = native
    env.CommunitiesAddDialog = { SetAttribute = native, GetAttribute = native }
  end)
  sim:advance(3)
  local C = sim.ns.Community
  click(C.win.join)
  local copy = C.copy
  assert(copy:IsVisible(), "Join first selects the link for copying")
  equal(copy:GetText(), sim.ns.Bounty.Exchange.INVITE, "reuses the bounty destination")
  assert(not copy.actions.open, "there is no native join action")
  sim:advance(3)
  assert(not sim.ns.Onboarding.win, "the feature guide waits while copying")
  click(copy.done)
  assert(C.win:IsVisible(), "closing the link returns to the invitation")
  click(C.win.later); sim:advance(3)
  assert(sim.ns.Onboarding.win:IsVisible(), "closing the invitation offers the guide")
  equal(calls, 0, "login and joining never access native invitations")
  sim:assertHealthy()
end)

test("neutral characters can join Discord without choosing a faction", function()
  local sim = create({}, function(_, env) env.UnitFactionGroup = function() return "Neutral" end end)
  sim:advance(3)
  local C = sim.ns.Community
  assert(C.win:IsVisible())
  click(C.win.join)
  equal(C.copy:GetText(), URL, "the Discord invite needs no faction")
end)

test("opening Discord from Home consumes the pending offer and reuses the copy dialog", function()
  local sim = create({})
  sim.ns.Hub.Open("home"); click(sim.ns.Hub.home.community)
  local C = sim.ns.Community
  equal(C.copy:GetText(), URL, "Home provides the Discord invite")
  local frames, selections, focuses = #sim.frames, 0, 0
  C.copy.box.HighlightText = function() selections = selections + 1 end
  C.copy.box.SetFocus = function() focuses = focuses + 1 end
  for _ = 1, 3 do
    C.copy.box.scripts.OnEscapePressed(C.copy.box)
    assert(sim.ns.Hub.home:IsVisible(), "Escape returns to Home")
    C.copy.box:SetText("edited text")
    click(sim.ns.Hub.home.community)
    equal(C.copy:GetText(), URL, "reopening restores the permanent invite")
    equal(#sim.frames, frames, "reopening reuses the dialog")
  end
  equal(selections, 3, "each reopen selects the link for copying")
  equal(focuses, 3, "each reopen focuses the copy box")
  click(C.copy.done); sim.ns.Hub.win:Hide(); sim:advance(3)
  assert(not C.win, "copying from Home prevents a redundant automatic offer")
  sim:assertHealthy()
end)

test("Discord copy closes on combat and instance entry and remains available manually", function()
  local sim = create({})
  sim:advance(3)
  local C = sim.ns.Community
  click(C.win.join)
  equal(C.copy:GetText(), URL, "copy provides the exact permanent invite")
  sim:setCombat(true)
  assert(not C.copy:IsVisible() and not C.win:IsVisible(), "combat closes the invitation and copy dialog")
  equal(C.Join(), true, "copy instructions remain usable in combat")
  equal(C.copy:GetText(), URL, "manual copying retains the Discord invite in combat")
  sim:join()
  assert(not C.copy:IsVisible(), "instance entry closes the copy dialog")
  sim:assertHealthy()
end)

for _, client in ipairs({ "cata", "retail", "forever" }) do
test(client .. " Discord link stays available with Bounties and Nearby disabled", function()
  local configure = dofile("tests/modules/fixture.lua").configure({ bounties = true, nearby = true })
  local sim = client == "forever" and create({}, configure) or new(client, {}, configure)
  assert(not sim.ns.Modules.Active("bounties") and not sim.ns.Modules.Active("nearby"))
  sim.ns.Hub.Open("home"); click(sim.ns.Hub.home.community)
  local C = sim.ns.Community
  assert(C.copy:IsVisible())
  equal(C.copy:GetText(), URL, "copying uses the shared constant without enabling a feature")
  assert(not sim.ns.Bounty.Public.ready, "joining Discord does not initialize Bounty networking")
  equal(#sim.moduleWrites, 0, "no module enable state changes")
  click(C.copy.done); sim.ns.Hub.win:Hide(); sim:advance(3)
  assert(not C.win, "manual copying satisfies the automatic offer")
  sim:assertHealthy()
end)
end

for _, faction in ipairs({ 0, 1 }) do
test("community headers stay stacked on first open and reopen, faction " .. faction, function()
  local sim = create({}, function(s)
    s.faction = faction
    dofile("../../tools/wowsim/geometry.lua")(s)
    local methods = getmetatable(s.env.UIParent).__index
    local height = methods.GetStringHeight
    methods.GetStringHeight = function(text)
      return text:IsVisible() and height(text) or 0 -- hidden text has no rendered measurement yet
    end
  end)
  local C = sim.ns.Community
  local function header(window, nextText)
    local title, sub, band = sim.bounds(window.title), sim.bounds(window.sub), sim.bounds(window.head)
    assert(window.sub:IsVisible(), "the community subtitle remains visible")
    assert(sub[2] >= title[2] + title[4], "the subtitle stays below the title")
    equal(sub[1], title[1], "both header lines share a left edge")
    for _, text in ipairs({ window.title, window.sub }) do
      local b = sim.bounds(text)
      assert(b[2] >= band[2] and b[2] + b[4] <= band[2] + band[4], "both lines fit within the header")
      assert(text:GetStringWidth() <= text:GetWidth(), "the full title and community label fit")
    end
    assert(sub[2] + sub[4] < sim.bounds(nextText)[2], "the subtitle clears the dialog instructions")
    return table.concat({ title[1], title[2], title[3], title[4], sub[1], sub[2], sub[3], sub[4] }, ",")
  end
  for _, scale in ipairs({ 1, 1.5 }) do
    sim.ns.Core.SetFontScale(scale)
    local first, copied
    for attempt = 1, 3 do
      C.Open()
      local layout = header(C.win, C.win.description)
      if first then equal(layout, first, "reopening keeps the invitation header in place") else first = layout end
      click(C.win.join)
      layout = header(C.copy, C.copy.hint)
      if copied then equal(layout, copied, "reopening keeps the copy header in place") else copied = layout end
      local hint, well = sim.bounds(C.copy.hint), sim.bounds(C.copy.well)
      assert(hint[2] + hint[4] < well[2], "copy instructions stay above the link")
      click(C.copy.done); click(C.win.later)
    end
  end
end)
end

test("Forever community controls fit the popup and Home", function()
  local sim = create({}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local function beside(a, b)
    local left, right = sim.bounds(a), sim.bounds(b)
    assert(left[1] + left[3] < right[1], "adjacent controls have a gap")
  end
  for _, scale in ipairs({ 1, 1.5 }) do
    sim.ns.Core.SetFontScale(scale)
    sim.ns.Community.Open()
    local w = sim.ns.Community.win
    beside(w.later, w.join)
    local description, status, buttons = sim.bounds(w.description), sim.bounds(w.status), sim.bounds(w.join)
    assert(description[2] + description[4] <= status[2], "copy and status do not overlap")
    assert(status[2] + status[4] <= buttons[2], "status stays above the actions")
    click(w.later)
    sim.ns.Hub.Open("home")
    local h = sim.ns.Hub.home
    beside(h.tools, h.community); beside(h.community, h.panelLock)
    for _, button in ipairs({ w.later, w.join, h.community }) do
      assert(button.label:GetStringWidth() <= button:GetWidth() - 12, "button labels fit")
    end
    click(h.community)
    local copy = sim.ns.Community.copy
    local well, instructions, close = sim.bounds(copy.well), sim.bounds(copy.status), sim.bounds(copy.done)
    assert(well[2] + well[4] <= instructions[2], "the link and paste instructions do not overlap")
    assert(instructions[2] + instructions[4] <= close[2], "instructions stay above Close")
    click(copy.done)
  end
end)
