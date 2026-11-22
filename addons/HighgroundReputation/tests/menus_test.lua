-- Player right-click menus (reputation/Menus.lua): the modern Menu API
-- and the legacy UnitPopup dropdown, in the standalone and Highground hosts.
-- Run from addons/HighgroundReputation: luajit tests/menus_test.lua
local t = dofile("../../tools/harness.lua")("reputation menus")
local F = dofile("tests/fixture.lua")
local bg = dofile("../../tools/wowsim/battleground/runtime.lua")
local test, equal = t.test, t.equal

-- The modern menu: a root that records its divider and submenu buttons.
-- Returns Reputation's submenu (nil when it adds none) and the root.
local function open(s, tag, context)
  local root = { buttons = {} }
  function root:CreateDivider() self.divider = true end
  function root:CreateButton(text)
    local menu = { text = text, buttons = {} }
    function menu:CreateButton(label, run) self.buttons[#self.buttons + 1] = { text = label, run = run } end
    self.buttons[#self.buttons + 1] = menu
    return menu
  end
  for _, callback in ipairs(assert(s.menus[tag], "menu hooked: " .. tag)) do callback(nil, root, context) end
  for _, button in ipairs(root.buttons) do
    if button.text == "Highground Reputation" then return button, root end
  end
  return nil, root
end

local function labels(menu)
  local out = {}
  for _, button in ipairs(menu.buttons) do out[#out + 1] = button.text end
  return table.concat(out, ", ")
end

for _, addon in ipairs({ "HighgroundReputation", "Highground" }) do
  test(addon .. ": unit menus add players and open their blacklist entries", function()
    local s = F.new("Owner", { addon = addon, runtime = addon == "Highground" and bg or nil })
    local W, c = F.W(s), F.community(s)
    for _, tag in ipairs({ "PLAYER", "ENEMY_PLAYER", "PARTY", "RAID_PLAYER", "FRIEND", "FRIEND_OFFLINE", "GUILD", "CHAT_ROSTER" }) do
      assert(s.menus["MENU_UNIT_" .. tag], "hooked " .. tag)
    end
    s.units.target = { name = "Enemy", realm = "OtherRealm", guid = "Player-9-Enemy" }
    local menu, root = open(s, "MENU_UNIT_ENEMY_PLAYER", { unit = "target" })
    assert(menu and root.divider, "own submenu, separated from Blizzard's entries")
    equal(labels(menu), "Add to blacklist...", "moderators add to the blacklist")
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
