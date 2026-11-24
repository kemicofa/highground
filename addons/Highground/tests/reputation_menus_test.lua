-- Player right-click menus (reputation/Menus.lua): the modern Menu API
-- and the legacy UnitPopup dropdown, through Highground.
-- Run from addons/Highground: luajit tests/reputation_menus_test.lua
local t = dofile("../../tools/harness.lua")("reputation menus")
local F = dofile("tests/reputation/fixture.lua")
local bg = dofile("../../tools/wowsim/battleground/runtime.lua")
local test, equal = t.test, t.equal

-- The modern menu: nodes record dividers, titles and (nested) buttons.
local function node(text, run)
  local n = { text = text, run = run, buttons = {} }
  function n:CreateDivider() self.buttons[#self.buttons + 1] = { divider = true } end
  function n:CreateTitle(title) self.buttons[#self.buttons + 1] = { title = title } end
  function n:CreateButton(label, fn)
    local button = node(label, fn)
    self.buttons[#self.buttons + 1] = button
    return button
  end
  return n
end

-- Returns Reputation's entries (those under its title; nil when it adds
-- none) and the root.
local function open(s, tag, context)
  local root = node()
  for _, callback in ipairs(assert(s.menus[tag], "menu hooked: " .. tag)) do callback(nil, root, context) end
  for i, button in ipairs(root.buttons) do
    if button.title == "Highground Reputation" then
      assert(root.buttons[i - 1] and root.buttons[i - 1].divider, "separated from Blizzard's entries")
      local menu = { buttons = {} }
      for j = i + 1, #root.buttons do
        local entry = root.buttons[j]
        if entry.divider or entry.title then break end -- another addon's entries
        menu.buttons[#menu.buttons + 1] = entry
      end
      return menu, root
    end
  end
  return nil, root
end

local function labels(menu)
  local out = {}
  for _, button in ipairs(menu.buttons) do out[#out + 1] = button.divider and "-" or button.text end
  return table.concat(out, ", ")
end

for _, addon in ipairs({ "Highground" }) do
  test(addon .. ": unit menus add players and open their blacklist entries", function()
    local s = F.new("Owner", { addon = addon, runtime = addon == "Highground" and bg or nil })
    local W, c = F.W(s), F.community(s)
    for _, tag in ipairs({ "PLAYER", "ENEMY_PLAYER", "PARTY", "RAID_PLAYER", "FRIEND", "FRIEND_OFFLINE", "GUILD", "CHAT_ROSTER" }) do
      assert(s.menus["MENU_UNIT_" .. tag], "hooked " .. tag)
    end
    s.units.target = { name = "Enemy", realm = "OtherRealm", guid = "Player-9-Enemy" }
    local menu = assert(open(s, "MENU_UNIT_ENEMY_PLAYER", { unit = "target" }), "own titled section")
    equal(labels(menu), "Add to blacklist...", "moderators add to the blacklist in one click")
    s.units.target = { name = "Someone", realm = "Realm", guid = "Player-9-Someone" } -- target changes before the click
    menu.buttons[1].run()
    local f = W.UI.report
    assert(f:IsVisible(), "report dialog opened")
    equal(f.name:GetText(), "Enemy-OtherRealm", "the player the menu was opened on")
    f.categories.toxic:SetChecked(true)
    F.click(s, f.submit)
    s.units.target = { name = "Enemy", realm = "OtherRealm", guid = "Player-9-Enemy" }
    menu = open(s, "MENU_UNIT_ENEMY_PLAYER", { unit = "target" })
    equal(labels(menu), "Add to blacklist..., View blacklist entry...", "listed player: the entry can be opened")
    menu.buttons[2].run()
    assert(W.UI.details and W.UI.details:IsVisible(), "blacklist entry opened")
    menu = open(s, "MENU_UNIT_CHAT_ROSTER", { name = "Enemy", server = "OtherRealm", guid = "Player-9-Enemy" })
    equal(labels(menu), "Add to blacklist..., View blacklist entry...", "chat roster entries match by name")
    equal(open(s, "MENU_UNIT_PLAYER", {}), nil, "no player: nothing added")
    -- Menus built under addon restrictions can hold secret sizes; an addon
    -- entry taints the build and the menu fails to lay out.
    local restricted = true
    s.env.Enum.AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 }
    s.env.C_RestrictedActions = { IsAddOnRestrictionActive = function(kind) return restricted and kind == 3 end }
    equal(open(s, "MENU_UNIT_ENEMY_PLAYER", { unit = "target" }), nil, "nothing during a PvP match")
    restricted = false
    assert(open(s, "MENU_UNIT_ENEMY_PLAYER", { unit = "target" }), "back once the match ends")
    W.ready = false
    equal(open(s, "MENU_UNIT_PLAYER", { unit = "target" }), nil, "nothing before the addon is ready")
    W.ready = true
    s:assertHealthy()
    equal(c.id, W.Get().id, "organization unchanged")
  end)
end

test("members without moderation rights are offered a report", function()
  local native = F.native("Member")
  native[42].members["Member-Realm"].role = 4
  local s = F.new("Member", { native = native })
  F.community(s)
  s.units.target = { name = "Enemy", realm = "OtherRealm", guid = "Player-9-Enemy" }
  equal(labels(open(s, "MENU_UNIT_PLAYER", { unit = "target" })), "Report player...", "report, not blacklist")
end)

test("several organizations: the menu picks one or all, and the form saves in all", function()
  local s = F.new("Owner")
  local W, c = F.W(s), F.community(s)
  s.native[43] = W.Copy(s.native[42]); s.native[43].name = "Another community"
  s.native[43].members[W.Me()].role = 4 -- a member there: proposals only
  local other = assert(W.Follow("club:43"))
  local target = { name = "Enemy", realm = "OtherRealm", guid = "Player-9-Enemy" }
  s.units.target = target
  local menu = assert(open(s, "MENU_UNIT_ENEMY_PLAYER", { unit = "target" }))
  equal(labels(menu), "Add to blacklist", "one submenu for the organizations")
  local choices = menu.buttons[1]
  equal(labels(choices), "Community: Another community..., Community: Test community..., -, All guilds and communities...",
    "each enabled organization, then all")
  choices.buttons[1].run()
  local f = W.UI.report
  assert(f:IsVisible(), "report dialog opened")
  equal(f.community:GetValue(), other.id, "chosen organization preselected")
  equal(f.title:GetText(), "REPORT PLAYER", "member there: a proposal")
  f:Hide()

  choices.buttons[4].run()
  equal(f.community:GetValue(), W.ALL, "all preselected")
  equal(f.name:GetText(), "Enemy-OtherRealm", "the player the menu was opened on")
  equal(f.title:GetText(), "BLACKLIST PLAYER", "moderator somewhere: blacklist")
  equal(f.submit.label:GetText(), "Save in all", "one save for every organization")
  assert(f.submit:IsEnabled(), "ready")
  s:event("CLUB_MEMBERS_UPDATED", 42, 2)
  equal(f.community:GetValue(), W.ALL, "routine updates keep all selected")
  F.click(s, f.submit)
  assert(f:IsVisible(), "nothing chosen: nothing saved")
  equal(f.status:GetText(), "Choose at least one category.", "one error, not one per organization")
  f.categories.cheating:SetChecked(true); f.note:SetText("Seen in two groups")
  F.click(s, f.submit)
  assert(not f:IsShown(), "saved: the dialog closes")
  local player = W.Unit("target") or W.Target("Enemy", "OtherRealm", "Player-9-Enemy")
  local row = assert(W.FindCase(c, player))
  assert(row.active and row.active.categories.cheating, "blacklisted where you moderate")
  equal(row.active.note, "Seen in two groups", "with the explanation")
  local report = assert(W.OwnReport(other, player), "proposal where you are a member")
  assert(report.categories.cheating and report.note == "Seen in two groups", "same categories and note")
  assert(s.messages[#s.messages]:find("Saved in Another community and Test community.", 1, true), s.messages[#s.messages])

  -- An organization that cannot take it now is named; the rest are saved.
  W.OpenReport(player, W.ALL)
  f.categories.toxic:SetChecked(true)
  c.synced = false
  F.click(s, f.submit)
  assert(not f:IsShown(), "saved where possible")
  assert(W.OwnReport(other, player).categories.toxic, "proposal updated")
  assert(not W.FindCase(c, player).active.categories.toxic, "unsynced moderation unchanged")
  assert(s.messages[#s.messages]:find("Not saved in Test community: ", 1, true), s.messages[#s.messages])
  c.synced = true

  -- The report command reaches the same choice in the form.
  W.Command("report target")
  equal(f.community:GetValue(), other.id, "the last chosen organization by default")
  f.community:SetValue(W.ALL)
  equal(f.submit.label:GetText(), "Save in all", "all from the form's organization menu")
  f:Hide()

  W.Disable(other)
  menu = open(s, "MENU_UNIT_ENEMY_PLAYER", { unit = "target" })
  equal(labels(menu), "Add to blacklist..., View blacklist entry...", "one enabled organization: one click again")
  W.OpenReport(player, c)
  for _, choice in ipairs(f.community.choices) do assert(choice.key ~= W.ALL, "no all with one enabled organization") end
  s:assertHealthy()
end)

test("legacy dropdowns add one entry to player menus only", function()
  local s = F.new("Owner", { legacy = true, client = "cata", guild = "Test Guild" })
  local W = F.W(s)
  F.community(s)
  s.units.target = { name = "Enemy", realm = "OtherRealm", guid = "Player-9-Enemy" }
  s.env.UnitPopup_ShowMenu({}, "SELF", "player")
  equal(s.legacyMenu, nil, "your own menu unchanged")
  s.env.UIDROPDOWNMENU_MENU_LEVEL = 2
  s.env.UnitPopup_ShowMenu({}, "PLAYER", "target")
  equal(s.legacyMenu, nil, "submenus unchanged")
  s.env.UIDROPDOWNMENU_MENU_LEVEL = 1
  s.env.UnitPopup_ShowMenu({}, "PLAYER", "target")
  local info = assert(s.legacyMenu, "entry added")
  equal(info.text, "Highground Reputation...", "entry text")
  assert(info.notCheckable, "a plain action")
  info.func()
  equal(W.UI.report.name:GetText(), "Enemy-OtherRealm", "opens the report for that player")
  W.UI.report:Hide()
  s.legacyMenu = nil
  s.env.UnitPopup_ShowMenu({ name = "Chatter", server = "ThirdRealm" }, "CHAT_ROSTER", nil)
  info = assert(s.legacyMenu, "chat roster entry without a unit")
  info.func()
  equal(W.UI.report.name:GetText(), "Chatter-ThirdRealm", "name and realm from the dropdown")
  s:assertHealthy()
end)

t.finish("Reputation menus: " .. t.tests .. " tests")
