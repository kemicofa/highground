local test, new, equal = ...
local URL = "https://www.worldofwarcraft.com/invite/BJbgaAEIn27?region=EU&faction=Horde"
local ALLIANCE_URL = "https://www.worldofwarcraft.com/invite/nr7D3Plcndq?region=EU&faction=Alliance"
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
test("Forever community offer survives " .. way .. ", reloads and profile changes", function()
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
  local profiles = sim.ns.Options.Profiles
  profiles.SaveProfile("Saved")
  profiles.LoadProfile("Saved")
  local again = create(sim.env.HighgroundDB, function(_, env) env.HighgroundCharDB = sim.env.HighgroundCharDB end)
  again:advance(3)
  assert(not again.ns.Community.win, "the same character gets no repeat")
  again:event("PLAYER_ENTERING_WORLD"); again:setCombat(true); again:setCombat(false); again:advance(3)
  assert(not again.ns.Community.win, "world and combat events cannot repeat the offer")
  again.ns.Hub.Open("home")
  click(again.ns.Hub.home.community)
  assert(again.ns.Community.win:IsVisible(), "Home can always reopen the invitation")
  click(again.ns.Community.win.later)
  assert(again.ns.Hub.home:IsVisible(), "dismissing the manual invitation returns Home")
end)
end

for _, faction in ipairs({ 0, 1 }) do
test("each alt gets its own community offer, faction " .. faction, function()
  local main = create({})
  main:advance(3); click(main.ns.Community.win.later)
  local alt = create(main.env.HighgroundDB, function(s, env)
    s.faction = faction
    env.HighgroundCharDB = {}
  end)
  alt:advance(3)
  local C = alt.ns.Community
  assert(C.win:IsVisible(), "another character on the same account receives its own offer")
  local expected = faction == 1 and ALLIANCE_URL or URL
  equal(C.win.sub.text, "WoW Forever · EU · " .. (faction == 1 and "Alliance" or "Horde"), "popup names this faction")
  click(C.win.join)
  equal(C.copy:GetText(), expected, "the alt receives its faction's full invite URL")
  click(C.copy.done); click(C.win.later)
  local again = create(alt.env.HighgroundDB, function(s, env)
    s.faction = faction
    env.HighgroundCharDB = alt.env.HighgroundCharDB
  end)
  again:advance(3)
  assert(not again.ns.Community.win, "this alt is not prompted twice")
  again.ns.Hub.Open("home"); click(again.ns.Hub.home.community); click(again.ns.Community.win.join)
  equal(again.ns.Community.copy:GetText(), expected, "Home keeps using the current character's faction")
end)
end

for _, faction in ipairs({ 0, 1 }) do
test("community invitations span rulesets for faction " .. faction, function()
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
    equal(sim.ns.Community.copy:GetText(), faction == 1 and ALLIANCE_URL or URL,
      "the faction's invite does not change with the ruleset")
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
test(client .. " never offers or exposes the Forever community invitation", function()
  local sim = new(client, {}, function(_, env) env.GetCurrentRegion = function() return 3 end end)
  sim:advance(3)
  local C = sim.ns.Community
  assert(not C.Available() and not C.win)
  sim.ns.Hub.Open("home")
  assert(not sim.ns.Hub.home.community)
  equal(C.Open(), false, "manual entry is also gated")
  equal(C.Join(), false, "join instructions are also gated")
  equal(C.OpenJoinWindow(), false, "the native opener is also gated")
  equal(C.CopyInvite(), false, "the link is also gated")
  equal(sim.ns.Core.pos.highgroundCommunityOffered, nil, "another client does not consume the offer")
end)
end

for _, region in ipairs({ 1, 2, 4, 5, 0, 99, "missing", "unavailable", "error" }) do
test("Forever community invitation is unavailable outside EU, region " .. region, function()
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
    assert(not C.win and not C.copy, "login must not build an EU invitation")
    assert(O.win:IsVisible(), "the first-install feature guide opens without an invitation")
    O.Dismiss()
    sim.ns.Hub.Open("home")
    assert(not sim.ns.Hub.home.community, "Home hides Join community outside EU")
    equal(C.Open(), false, "manual entry cannot open an EU invitation")
    equal(C.Join(), false, "join instructions cannot expose an EU invitation")
    equal(C.CopyInvite(), false, "the EU invite cannot be copied")
    equal(C.OpenJoinWindow(), false, "the native join window cannot open")
    sim.ns.Hub.win:Hide()
    sim:event("PLAYER_ENTERING_WORLD"); sim:event("UNIT_FACTION", "player")
    sim:setCombat(true); sim:setCombat(false); sim:advance(3)
    assert(not C.win and not C.copy, "world, faction, window and combat events keep the invitation unavailable")
    equal(sim.ns.Core.pos.highgroundCommunityOffered, nil, "an unavailable invitation is never marked offered")
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

for _, faction in ipairs({ 0, 1 }) do
test("community join opens the paste dialog without restricted actions, faction " .. faction, function()
  local loads, blocked, forbidden, shown = 0, 0, 0, false
  local function restricted() blocked = blocked + 1 end -- Blizzard can report a block without raising a Lua error.
  local sim = create(nil, function(s, env)
    s.faction = faction
    env.C_Club = { RequestTicket = restricted, RedeemTicket = restricted }
    env.CommunitiesHyperlink = { OnClickLink = restricted }
    env.C_AddOns.LoadAddOn = function(name)
      equal(name, "Blizzard_Communities", "loads the native community UI")
      loads = loads + 1
      env.CommunitiesFrame = env.CreateFrame("Frame", nil, env.UIParent)
      env.CommunitiesFrame:Hide()
      -- The real secure dialog exposes attributes, not its invite field or buttons.
      env.CommunitiesAddDialog = setmetatable({
        SetAttribute = function(_, key, value)
          equal(key, "setshown", "only the supported show/hide attribute is written")
          shown = value
        end,
        GetAttribute = function(_, key)
          equal(key, "shown", "visibility is read through the supported attribute")
          return shown
        end,
      }, { __index = function(_, key) forbidden = forbidden + 1; error("Forbidden frame access: " .. key) end })
      return true
    end
    env.ShowUIPanel = function(frame) frame:Show() end
  end)
  sim:advance(3)
  equal(loads, 0, "login does not load or request an invitation")
  click(sim.ns.Community.win.join)
  local copy = sim.ns.Community.copy
  assert(copy:IsVisible(), "Join first selects the link for copying")
  equal(copy:GetText(), faction == 1 and ALLIANCE_URL or URL, "uses this faction's invitation URL")
  equal(loads, 0, "the native window waits until the player has a chance to copy")
  click(copy.actions.open)
  equal(loads, 1, "Open join window loads the native UI")
  equal(shown, true, "the native join dialog opens")
  equal(blocked, 0, "neither ticket lookup, hyperlink preview nor redemption is attempted")
  equal(forbidden, 0, "no native text field, Join button or other forbidden frame member is accessed")
  assert(sim.env.CommunitiesFrame:IsVisible() and not copy:IsVisible() and not sim.ns.Community.win:IsVisible())
  sim:advance(3)
  assert(not sim.ns.Onboarding.win, "the feature guide waits while the player pastes and joins")
  sim.env.CommunitiesAddDialog:SetAttribute("setshown", false)
  sim.env.CommunitiesFrame:Hide(); sim:advance(3)
  assert(sim.ns.Onboarding.win:IsVisible(), "closing the native UI offers the guide")
end)
end

test("unknown factions wait without consuming a character's invitation", function()
  local faction = "Neutral"
  local sim = create({}, function(_, env) env.UnitFactionGroup = function() return faction end end)
  sim:advance(3)
  local C = sim.ns.Community
  assert(not C.win and not sim.env.HighgroundCharDB.highgroundCommunityOffered)
  equal(C.Join(), false, "unknown faction cannot use the wrong invitation")
  equal(C.CopyInvite(), false, "unknown faction cannot copy the wrong link")
  faction = "Alliance"
  sim:event("UNIT_FACTION", "player"); sim:advance(3)
  assert(C.win:IsVisible(), "choosing a faction schedules the pending offer")
  click(C.win.join)
  equal(C.copy:GetText(), ALLIANCE_URL, "the selected faction determines the invitation")
end)

for _, failure in ipairs({ "missing", "throws", "declines", "does nothing" }) do
test("community join keeps a copyable invitation when the dialog opener " .. failure, function()
  local sim = create({}, function(_, env)
    if failure == "missing" then env.C_AddOns.LoadAddOn = function() return false end; return end
    env.CommunitiesFrame = env.CreateFrame("Frame", nil, env.UIParent)
    env.CommunitiesFrame:Hide()
    env.ShowUIPanel = function(frame) frame:Show() end
    env.CommunitiesAddDialog = {
      GetAttribute = function() return false end,
      SetAttribute = function()
        if failure == "throws" then error("unavailable") end
        if failure == "does nothing" then return end
        return false
      end,
    }
  end)
  sim:advance(3)
  click(sim.ns.Community.win.join)
  local copy = sim.ns.Community.copy
  click(copy.actions.open)
  assert(copy:IsVisible())
  equal(copy:GetText(), URL, "the full URL preserves region and faction")
  assert(copy.status.text:find("WoW's menu", 1, true), "manual navigation is explained when opening fails")
  click(copy.done)
  assert(sim.ns.Community.win:IsVisible(), "closing the link returns to the invitation")
end)
end

test("community copy remains available and native dialog cannot open in combat", function()
  local sim = create({})
  sim:advance(3)
  local C = sim.ns.Community
  click(C.win.join)
  equal(C.copy:GetText(), URL, "copy provides the exact permanent invite")
  click(C.copy.done)
  sim.combat = true
  equal(C.Join(), true, "copy instructions remain usable in combat")
  equal(C.OpenJoinWindow(), false, "no native UI work in combat")
  assert(C.copy.status.text:find("after combat", 1, true))
end)

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
    assert(window.sub:IsVisible(), "the faction subtitle remains visible")
    assert(sub[2] >= title[2] + title[4], "the subtitle stays below the title")
    equal(sub[1], title[1], "both header lines share a left edge")
    for _, text in ipairs({ window.title, window.sub }) do
      local b = sim.bounds(text)
      assert(b[2] >= band[2] and b[2] + b[4] <= band[2] + band[4], "both lines fit within the header")
      assert(text:GetStringWidth() <= text:GetWidth(), "the full title and faction label fit")
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
    click(h.community); click(w.join)
    local copy = sim.ns.Community.copy
    local well, instructions, open = sim.bounds(copy.well), sim.bounds(copy.status), sim.bounds(copy.actions.open)
    assert(well[2] + well[4] <= instructions[2], "the link and paste instructions do not overlap")
    assert(instructions[2] + instructions[4] <= open[2], "instructions stay above the native opener")
    assert(copy.actions.open.label:GetStringWidth() <= copy.actions.open:GetWidth() - 12, "the opener label fits")
    click(copy.done); click(w.later)
  end
end)
