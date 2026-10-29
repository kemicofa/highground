local test, new, equal = ...

-- The themes shipped with Highground (config/Theme.lua, config/themes/).
local function near(actual, expected, why)
  assert(type(actual) == "number" and math.abs(actual - expected) < 0.0001,
    why .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function same(c, token, why)
  for i = 1, 3 do near(c[i], token[i], why) end
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " every theme sets every token with a valid value", function()
  local sim = new(client)
  local T, Core = sim.ns.Theme, sim.ns.Core
  local themes, base = sim.ns.Themes, sim.ns.Themes.highground
  local names = T.Names()
  equal(names[1], "highground", "base first")
  local listed = {}
  for _, n in ipairs(names) do listed[n] = true end
  assert(listed.ember and listed.parchment and listed.azeroth, "all shipped palettes registered")
  for _, name in ipairs(names) do
    local t = themes[name]
    assert(type(t.label) == "string" and t.label ~= "", name .. " has a label")
    assert(t.darkFrames == nil or themes[t.darkFrames], name .. " darkFrames names a theme")
    for key in pairs(base.color) do
      local c = t.color[key]
      assert(type(c) == "table" and (#c == 3 or #c == 4), name .. " colour " .. key)
      for i = 1, #c do
        assert(type(c[i]) == "number" and c[i] >= 0 and c[i] <= 1, name .. " colour " .. key .. " in 0-1")
      end
    end
    for key in pairs(base.type) do
      local r = t.type[key]
      assert(type(r) == "table" and Core.FACES[r[1]], name .. " type " .. key .. " face")
      assert(type(r[2]) == "number" and r[2] >= 10 and r[2] <= 40, name .. " type " .. key .. " size")
      equal(r[2], base.type[key][2], name .. " keeps type size for " .. key)
      assert(r[3] == nil or r[3] == "OUTLINE" or r[3] == "THICKOUTLINE", name .. " type " .. key .. " flags")
      equal(r[3], base.type[key][3], name .. " type " .. key .. " keeps the base outline")
    end
    for key, v in pairs(base.alpha) do
      local a = t.alpha[key]
      assert(type(a) == "number" and a >= 0 and a <= 1, name .. " alpha " .. key)
      if key == "page" then assert(a == 0 or a == 1, name .. " page fill is off or on") end
      assert(v ~= nil)
    end
    -- Geometry is shared: a switch never resizes frames (secure ones included).
    for _, group in ipairs({ "space", "size", "motion" }) do
      for key, v in pairs(base[group]) do equal(t[group][key], v, name .. " " .. group .. " " .. key) end
    end
    for _, group in ipairs({ "color", "type", "alpha", "motion" }) do
      for key in pairs(t[group]) do assert(base[group][key] ~= nil, name .. " has no stray " .. group .. " " .. key) end
    end
  end
  -- The player's sniper colours are the same in every theme.
  for _, name in ipairs(names) do
    for _, key in ipairs({ "sniperMagenta", "sniperCyan", "sniperYellow", "sniperLime", "sniperOrange" }) do
      same(themes[name].color[key], base.color[key], name .. " " .. key)
    end
  end
end)
end

-- Open every themed window, switch, and read back colours and faces.
local function openAll(sim)
  sim:enemy("Alpha")
  sim:enemy("Beta")
  sim:join(1460, 489, "Warsong Gulch")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Alliance flag was picked up by Alpha!")
  sim:advance(0.5)
  sim:command("")
  sim:command("macros")
  sim:command("bounty")
  sim.env.HighgroundMinimapButton.scripts.OnClick(sim.env.HighgroundMinimapButton, "RightButton")
  sim.ns.Options.appearance.frame:Show()
end

local function checkAll(sim, name, why)
  local T, Core, env = sim.ns.Theme, sim.ns.Core, sim.env
  local c = sim.ns.Themes[name].color
  local face = Core.FACES[sim.ns.Themes[name].type.title[1]]
  equal(T.Current(), name, why .. ": active")
  same(Core.rows[2].name.textColor, c.text, why .. ": row name")
  same(Core.rows[2].tile.colorTexture, c.surface, why .. ": row tile")
  same(Core.hero.label.textColor, c.accent, why .. ": hero label")
  same(Core.hero.sub.textColor, c.textMuted, why .. ": hero summary")
  for _, surface in ipairs(Core.surfaces) do
    assert(surface.wbToken, why .. ": registered surface has a live palette token")
    same(surface.colorTexture, c[surface.wbToken], why .. ": HUD surface repainted")
  end
  equal(Core.head.title.font[1], face, why .. ": header title face")
  local timerRow = env.HighgroundTimersFrame.rows[1]
  same(timerRow.place.textColor, c.text, why .. ": timer place")
  same(env.HighgroundHub.head.colorTexture, c.accent, why .. ": hub band")
  same(env.HighgroundHub.title.textColor, c.titleText, why .. ": hub title")
  same(env.HighgroundMacroFrame.bar.colorTexture, c.accent, why .. ": macros bar")
  same(env.HighgroundBountyFrame.bar.colorTexture, c.gold, why .. ": bounty bar in gold")
  same(env.HighgroundBountyFrame.rows[1].gold.textColor, c.gold, why .. ": bounty reward")
  same(sim.ns.Options.appearance.title.textColor, c.titleText, why .. ": options page title")
  same(env.HighgroundDropdown.rows[1].bg.colorTexture, c.overlaySelected, why .. ": minimap menu row")
  equal(sim.ns.Options.appearance.themeSelect:GetValue(), name, why .. ": picker shows it")
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " every palette re-skins open windows, also in combat", function()
  local sim = new(client)
  local T, Core = sim.ns.Theme, sim.ns.Core
  openAll(sim)
  checkAll(sim, "highground", "base")
  local size = {}
  for i, r in ipairs(Core.rows) do size[i] = { r.width, r.height } end
  local frame = { Core.frame.width, Core.frame.height }
  for _, name in ipairs({ "ember", "parchment", "azeroth" }) do
    assert(T.Use(name), name)
    checkAll(sim, name, name)
    assert(T.Use("highground"))
    sim:setCombat(true) -- secure rows shown: a protected change would raise
    assert(T.Use(name), name .. " in combat")
    checkAll(sim, name, name .. " in combat")
    sim:advance(0.5)
    same(Core.rows[2].name.textColor, sim.ns.Themes[name].color.text, name .. ": renders keep it")
    for i, r in ipairs(Core.rows) do
      equal(r.width, size[i][1], name .. ": row width kept"); equal(r.height, size[i][2], name .. ": row height kept")
    end
    equal(Core.frame.width, frame[1], name .. ": panel width kept")
    equal(Core.frame.height, frame[2], name .. ": panel height kept")
    sim:setCombat(false)
  end
  assert(T.Use("highground"))
  checkAll(sim, "highground", "back to the base")
end)
end

test("parchment keeps Blizzard's dark tooltips and chat readable", function()
  local sim = new("retail")
  local T, base = sim.ns.Theme, sim.ns.Themes.highground.color
  assert(T.Use("parchment"))
  same({ T.TipColor("text") }, base.text, "tooltip text from the base theme")
  equal(T.TipHex("textMuted"), "|cffbac6d0", "chat colour from the base theme")
  same({ T.Color("text") }, sim.ns.Themes.parchment.color.text, "own frames use the ink colour")
  near(sim.ns.Options.appearance.frame.children[1].colorTexture[4], 1, "settings pages filled")
  assert(T.Use("ember"))
  same({ T.TipColor("text") }, sim.ns.Themes.ember.color.text, "a dark theme uses its own")
  near(sim.ns.Options.appearance.frame.children[1].colorTexture[4], 1, "all pages have a stable reading surface")
end)

test("/hg theme lists, switches, rejects and persists across a reload", function()
  local sim = new("cata")
  local before = #sim.messages
  sim:command("theme")
  local out = table.concat(sim.messages, "\n", before + 1)
  assert(out:find("highground (on)", 1, true) and out:find("ember", 1, true) and out:find("parchment", 1, true),
    "lists the themes: " .. out)
  sim:command("theme ember")
  equal(sim.ns.Theme.Current(), "ember", "switched")
  equal(sim.env.HighgroundDB.theme, "ember", "saved")
  assert(sim.messages[#sim.messages]:find("theme: Ember", 1, true), "confirmed")
  equal(sim.ns.Options.appearance.themeSelect:GetValue(), "ember", "picker follows the command")
  sim:command("theme nope")
  equal(sim.ns.Theme.Current(), "ember", "unknown name changes nothing")
  assert(sim.messages[#sim.messages]:find("no theme named nope", 1, true), "and says so")
  sim:command("THEME PARCHMENT")
  equal(sim.ns.Theme.Current(), "parchment", "command is case-insensitive")

  local again = new("cata", sim.env.HighgroundDB)
  equal(again.ns.Theme.Current(), "parchment", "restored after a reload")
  same(again.ns.Core.head.title.textColor, again.ns.Themes.parchment.color.text, "panel drawn in it")
  equal(again.ns.Options.appearance.themeSelect:GetValue(), "parchment", "picker shows it")
  again:command("theme highground")
  equal(again.env.HighgroundDB.theme, nil, "base theme saves as the default")
end)

test("the Appearance picker switches theme", function()
  local sim = new("retail")
  local select = sim.ns.Options.appearance.themeSelect
  sim.ns.Options.appearance.frame:Show()
  equal(select:GetValue(), "highground", "starts on the base")
  equal(select.text, "Highground", "shows its label")
  select.scripts.OnClick(select, "LeftButton")
  local list = sim.env.HighgroundDropdown
  assert(list:IsShown(), "opens the list")
  local pick
  for _, r in ipairs(list.rows) do if r:IsShown() and r.label.text == "Parchment" then pick = r end end
  assert(pick, "lists Parchment")
  pick.scripts.OnClick(pick)
  equal(sim.ns.Theme.Current(), "parchment", "picked")
  equal(sim.env.HighgroundDB.theme, "parchment", "saved")
  equal(select.text, "Parchment", "picker label")
end)

test("Kit buttons disable: dimmed, no hover, native click off", function()
  local sim = new("cata")
  local Kit, T = sim.ns.Kit, sim.ns.Theme
  local b = Kit.Button(sim.env.UIParent, "Go", 40, 20)
  b:SetEnabled(false)
  assert(not b:IsEnabled(), "disabled")
  equal(b.enabled, false, "native button disabled")
  equal(b.alpha, T.Alpha("disabled"), "dimmed")
  b.scripts.OnEnter(b)
  assert(not b.hover:IsShown(), "no hover")
  assert(T.Use("ember"))
  equal(b.alpha, T.Alpha("disabled"), "dim follows the theme")
  assert(T.Use("highground"))
  b:Enable()
  assert(b:IsEnabled() and b.enabled, "enabled again")
  equal(b.alpha, 1, "full alpha")
  b.scripts.OnEnter(b)
  assert(b.hover:IsShown(), "hover back")
end)

test("a pinned Kit.Dialog does not save its position", function()
  local sim = new("cata")
  local d = sim.ns.Kit.Dialog("HighgroundPinTest", { savedKey = "pintest" })
  d:Show()
  d:SetMovable(false)
  d.scripts.OnDragStop(d)
  equal((sim.env.HighgroundDB.windows or {}).pintest, nil, "not saved while pinned")
  d:SetMovable(true)
  d.scripts.OnDragStop(d)
  assert(sim.env.HighgroundDB.windows.pintest, "saved when movable")
end)
