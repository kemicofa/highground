local test, new, equal = ...
local F = dofile("tests/modules/fixture.lua")
local function near(a, b, why) assert(math.abs(a - b) < 0.0001, (why or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function color(actual, expected)
  for i = 1, 3 do near(actual[i], expected[i], "color channel") end
end
local function click(button) assert(button:IsVisible() and button:IsEnabled()); button:Click() end
local function make(client, saved, disabled)
  return new(client == "cata" and "cata" or "retail", saved or {}, function(s, env)
    F.configure(disabled)(s, env)
    if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
    dofile("../../tools/wowsim/geometry.lua")(s)
  end)
end
for _, client in ipairs({ "cata", "retail", "forever" }) do
  test(client .. " enemy appearance controls and commands share themed previews, colors and presets", function()
    local s = make(client)
    local C, O, T = s.ns.Core, s.ns.Options, s.ns.Theme
    s:command("enemy")
    local p = O.byKey["battlegrounds-appearance"]
    click(p.preview); click(p.applyEnemyPreset)
    assert(C.hero:IsShown() and not C.rows[1].rank:IsShown(), "readable preset emphasizes the card and names")
    equal(C.rows[1]:GetHeight(), 44, "readable row")
    equal(C.rows[1].hp:GetHeight(), 16, "readable health")
    equal(C.frame:GetWidth(), 380, "readable width")
    near(C.rows[1].base.colorTexture[4], 0.95, "solid row background")
    equal(C.StyleChoice("barColor").key, "class", "shared color preserved")
    equal(C.StyleChoice("bar").key, "flat", "shared texture preserved")
    local row
    for _, r in ipairs(C.rows) do if r.entry and r.entry.testHp == 0.28 then row = r end end
    assert(row, "low health sample")
    for _, theme in ipairs(T.Names()) do
      s:command("theme " .. theme)
      color(row.hp.statusColor, T.Rgb("danger"))
      p.enemyControls.color:SetValue("theme")
      color(row.hp.statusColor, T.Rgb("accent"))
      s:command("enemy color health")
    end
    p.enemyControls.color:SetValue("custom")
    s:command("enemy custom 336699")
    color(row.hp.statusColor, { 0.2, 0.4, 0.6 })
    s:command("enemy custom BADHEX")
    color(row.hp.statusColor, { 0.2, 0.4, 0.6 })
    for _, theme in ipairs(T.Names()) do
      s:command("theme " .. theme); color(row.hp.statusColor, { 0.2, 0.4, 0.6 })
    end
    for _, texture in ipairs({ "flat", "raid", "blizzard", "shared" }) do
      p.enemyControls.texture:SetValue(texture)
      equal(C.StyleChoice("enemyBar").key, texture, "UI texture")
      s:command("enemy texture " .. texture)
      equal(C.StyleChoice("enemyBar").key, texture, "command texture")
    end
    for _, style in ipairs({ "fill", "line", "bar" }) do
      p.enemyControls.style:SetValue(style); equal(C.HealthStyle(), style, "UI style")
      s:command("enemy style " .. style); equal(C.HealthStyle(), style, "command style")
    end
    click(p.enemyControls.enemyBackground.stepper.minus)
    near(C.EnemyNumber("enemyBackground"), 0.9, "UI opacity")
    s:command("enemy background 75"); near(row.base.colorTexture[4], 0.75, "command opacity")
    s:command("enemy opacity 50"); near(row.hp.statusColor[4], T.Alpha("healthBar") * 0.5, "health opacity")
    s:command("enemy names 90"); near(C.EnemyNumber("enemyNames"), 0.9, "name contrast")
    local frames = #s.frames
    for _ = 1, 3 do
      s:command("enemy preset compact"); assert(C.compact and not C.hero:IsShown())
      s:command("enemy preset readable"); assert(not C.compact and C.hero:IsShown())
    end
    equal(#s.frames, frames, "presets reuse existing rows and controls")
    click(p.preview); assert(not C.testMode and not O.AppearancePreview.session, "preview stops")
    equal(#s.sent, 0, "no sample traffic")
    equal(C.db.style.enemyColor, "health", "intentional appearance saves survive stopping")
    s:assertHealthy()
  end)

  test(client .. " enemy sizes avoid text overlap, defer protected layout and persist in profiles", function()
    local s = make(client)
    s:enemy("Bartholomew Thistlewood", { health = 40, classID = 8 }); s:join()
    local C, P = s.ns.Core, s.ns.Options.Profiles
    s:command("enemy preset readable")
    C.SetFontScale(1.5)
    s:command("enemy width 480"); s:command("enemy row 28"); s:command("enemy height 28")
    local r = C.rows[1]
    equal(r.hp:GetHeight(), 28, "requested thickness")
    local bar, name = s.bounds(r.hp), s.bounds(r.name)
    assert(bar[2] > name[2] + name[4], "thick bar clears the large name")
    local height, width = r:GetHeight(), C.frame:GetWidth()
    s:setCombat(true)
    s:command("enemy row 64"); s:command("enemy width 400"); s:command("enemy height 20")
    equal(r:GetHeight(), height, "row defers"); equal(C.frame:GetWidth(), width, "width defers")
    s:command("enemy color theme"); color(r.hp.statusColor, s.ns.Theme.Rgb("accent"))
    s:setCombat(false); s:advance(0.5)
    equal(r:GetHeight(), 64, "deferred row applies"); equal(C.frame:GetWidth(), 400, "deferred width applies")
    equal(r.hp:GetHeight(), 20, "deferred bar applies")
    s:command("enemy custom 123456"); s:command("enemy background 82")
    s:command("profile save Enemies")
    local saved = P.Snapshot()
    assert(P.Prepare(saved), "new styling exports and imports")
    saved.setup.style.enemyOpacity = 0 / 0
    assert(not P.Prepare(saved), "invalid imported opacity is rejected atomically")
    s:command("enemy preset default")
    equal(C.StyleChoice("enemyColor").key, "shared", "default inherits")
    s:command("profile load Enemies")
    equal(C.db.style.enemyColor, "theme", "profile restores color")
    near(C.EnemyNumber("enemyBackground"), 0.82, "profile restores opacity")
    C.ResetStyle("shared")
    equal(C.db.style.enemyColor, "theme", "shared reset preserves enemy overrides")
    local again = make(client, s.env.HighgroundDB)
    equal(again.ns.Core.db.style.enemyColor, "theme", "reload persists override")
    C.ResetStyle("battlegrounds")
    equal(C.db.style.enemyColor, nil, "owner reset clears override")
    s:assertHealthy(); again:assertHealthy()
  end)
end

test("enemy appearance labels and preset controls fit large text in every locale", function()
  local s = make("retail")
  s:command("enemy"); s.ns.Core.SetFontScale(1.5)
  local p = s.ns.Options.byKey["battlegrounds-appearance"]
  for _, locale in ipairs({ "enUS", "frFR", "deDE", "esES", "esMX", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }) do
    s.ns.Localization.SetPreference(locale)
    assert(p.enemyHint:GetStringHeight() <= p.enemyHint:GetHeight(), locale .. " explanation fits")
    assert(p.applyEnemyPreset.label:GetUnboundedStringWidth() + 16 <= p.applyEnemyPreset:GetWidth(), locale .. " apply label fits")
    for _, key in ipairs({ "enemyNames", "enemyBackground", "enemyOpacity" }) do
      local row = p.enemyControls[key]
      local label, stepper = s.bounds(row.label), s.bounds(row.stepper)
      assert(label[2] + label[4] <= stepper[2], locale .. " label clears its control")
      assert(label[3] <= p.child:GetWidth() - 48, locale .. " label fits the page")
    end
  end
  s:assertHealthy()
end)

test("enemy color overrides ignore a previously sampled secret health tint", function()
  local secret = { secret = true }
  local tint = { GetRGB = function() return 0.9, 0.1, 0.1 end }
  local s = new("forever", {}, function(s, env)
    env.CurveConstants = { ScaleTo100 = "scale100" }
    env.UnitHealthPercent = function(_, _, curve)
      if curve == "scale100" then return secret end
      if curve ~= nil and curve == s.ns.Core.healthCurve then return tint end
      return secret
    end
    env.UnitHealth = function() return secret end
    env.UnitHealthMax = function() return secret end
  end)
  local _, token = s:enemy("Secret")
  s:join()
  local C = s.ns.Core
  C.healthCurve = C.healthCurve or {}
  s:command("enemy color health"); s:advance(1)
  local r = C.rows[1]
  color(r.hp.statusColor, { 0.9, 0.1, 0.1 })
  s.units[token] = nil; s:advance(1)
  equal(r.hp.value, secret, "last-seen secret is passed straight to the native widget")
  s:command("enemy color custom"); s:command("enemy custom 336699")
  color(r.hp.statusColor, { 0.2, 0.4, 0.6 })
  assert(r.hpText:IsShown(), "last-seen text preserved")
  s:advance(C.O("healthMemory"))
  assert(not r.hpText:IsShown(), "unknown health has no percentage")
  assert(r.hp.statusColor[4] < s.ns.Theme.Alpha("healthBarStale"), "unknown remains distinct")
  s:assertHealthy()
end)

test("enemy appearance routes respect the disabled battleground module", function()
  local s = make("cata", nil, { battlegrounds = true })
  s:command("enemy preset readable")
  equal(s.ns.Core.db.style.enemyColor, nil, "disabled module cannot be changed by command")
  equal(s.ns.Hub.current, "module-battlegrounds", "disabled module routes to its settings")
  s:assertHealthy()
end)
