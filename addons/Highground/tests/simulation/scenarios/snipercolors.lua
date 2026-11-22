local test, new, equal = ...

local function picker(sim, modern)
  local f = sim.env.CreateFrame("ColorSelect", nil, sim.env.UIParent)
  f:Hide()
  function f:GetColorRGB() return self.r, self.g, self.b end
  function f:SetColorRGB(r, g, b)
    self.r, self.g, self.b = r, g, b
    local callback = self.swatchFunc or self.func
    if callback then callback() end
  end
  if modern then
    function f:SetupColorPickerAndShow(info)
      self.swatchFunc, self.cancelFunc = info.swatchFunc, info.cancelFunc
      self.hasOpacity = info.hasOpacity
      self.previousValues = { r = info.r, g = info.g, b = info.b }
      self:SetColorRGB(info.r, info.g, info.b); self:Show()
    end
  end
  sim.env.ColorPickerFrame = f
  return f
end

for _, client in ipairs({ "cata", "retail", "forever" }) do
  local function make(saved)
    local sim = new(client == "cata" and "cata" or "retail", saved or {}, function(_, env)
      if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
    end)
    local enemy = sim:enemy("ColourTarget", { health = 30 })
    sim.units.target = enemy
    sim:command("sniper test"); sim:advance(0.2)
    sim.ns.Hub.Open("battlegrounds-appearance")
    return sim
  end

  for _, modern in ipairs({ false, true }) do
    test(client .. (modern and " modern" or " legacy") .. " colour picker applies each layer live and cancels exactly", function()
      local sim = make()
      local C, page = sim.ns.Core, sim.ns.Options.byKey["battlegrounds-appearance"]
      local f = picker(sim, modern)
      local anchor = C.sniper.points[1]
      local function Hex(texture) return C.SniperHex(texture.vertexColor) end
      for _, layer in ipairs({ "ring", "skull", "aim" }) do
        local texture = layer == "ring" and "reticle" or layer
        local key = C.SNIPER_COLOR_LAYERS[layer].key
        local before = Hex(C.sniper[texture])
        local others = {}
        for _, part in ipairs({ "reticle", "skull", "aim" }) do others[part] = Hex(C.sniper[part]) end
        page.sniperColors[layer].button:Click()
        equal(C.db[key], "", "opening the picker does not create a custom override")
        equal(f.hasOpacity, false, "texture alpha stays transparent")
        f:SetColorRGB(0.2, 0.4, 0.6)
        equal(C.db[key], "336699", "full RGB choice is saved")
        equal(Hex(C.sniper[texture]), "336699", "live target recolours immediately")
        equal(Hex(page.sniperPreview[texture]), "336699", "mini preview recolours immediately")
        for part, color in pairs(others) do if part ~= texture then equal(Hex(C.sniper[part]), color, "other layers stay intact") end end
        equal(C.sniper.points[1], anchor, "colour changes do not move the target marker")
        local staleCancel = f.cancelFunc
        f.cancelFunc(f.previousValues); f:Hide()
        equal(C.db[key], "", "Cancel restores the default sentinel")
        equal(Hex(C.sniper[texture]), before, "Cancel restores the exact original appearance")
        page.sniperColors[layer].button:Click(); f:SetColorRGB(0.8, 0.2, 0.4); f:Hide()
        staleCancel()
        equal(C.db[key], "cc3366", "old callbacks cannot undo an accepted new choice")
        page.sniperColors[layer].reset:Click()
        equal(C.db[key], "", "Default resets just this component")
      end
      page.sniperColors.ring.button:Click(); f:SetColorRGB(0.2, 0.4, 0.6)
      sim.ns.Hub.Open("battlegrounds-settings")
      -- Native WoW propagates ancestor visibility; the mock needs its callback.
      for _, callback in ipairs(page.sniperColors.ring.button.hooks.OnHide or {}) do callback(page.sniperColors.ring.button) end
      assert(not f:IsShown(), "closing settings closes its active picker")
      equal(C.db.sniperRingColor, "", "closing settings cancels unconfirmed picker edits")
    end)
  end

  test(client .. " custom component colours survive GO, style switches, profiles, themes and reloads", function()
    local sim = make({ sniperColor = "cyan" })
    local C, page = sim.ns.Core, sim.ns.Options.byKey["battlegrounds-appearance"]
    sim:command("sniper color ring #A040FF")
    sim:command("sniper color skull 33BB77")
    sim:command("sniper color aim FF8800")
    local function AssertColors()
      equal(C.SniperHex(C.sniper.reticle.vertexColor), "A040FF", "custom ring")
      equal(C.SniperHex(C.sniper.skull.vertexColor), "33BB77", "custom skull")
      equal(C.SniperHex(C.sniper.aim.vertexColor), "FF8800", "custom aiming point")
    end
    sim:command("go"); sim:advance(0.2); AssertColors()
    equal(C.sniper.pulseAnimation.duration, 0.4, "custom colours retain kill-window pulse")
    sim:command("sniper style legacy")
    equal(C.SniperHex(C.sniper.legacyParts[1].vertexColor), "A040FF", "legacy arms use ring colour")
    equal(C.SniperHex(C.sniper.legacyParts[5].vertexColor), "FF8800", "legacy center dot has its own colour")
    assert(not page.sniperColors.skull.button:IsEnabled(), "legacy has no skull to colour")
    sim:command("sniper style layered"); AssertColors()
    sim.ns.Theme.Use("parchment"); AssertColors()
    sim:command("profile save My colours")
    sim:command("sniper color skull default")
    sim:command("profile load My colours"); sim:advance(0.2); AssertColors()
    local again = make(sim.env.HighgroundDB)
    equal(again.ns.Core.db.sniperRingColor, "a040ff", "ring persists on reload")
    equal(again.ns.Core.db.sniperSkullColor, "33bb77", "skull persists on reload")
    equal(again.ns.Core.db.sniperAimColor, "ff8800", "aim persists on reload")
    sim:command("go"); sim:advance(0.2)
    page.sniperColors.ring.reset:Click()
    equal(C.SniperHex(C.sniper.reticle.vertexColor), C.SniperHex(C.SNIPER_COLORS.cyan), "ring Default restores old named colour")
    sim:command("sniper color magenta")
    equal(C.db.sniperRingColor, "", "old named commands still select the ring")
    equal(C.db.sniperSkullColor, "33bb77", "old named commands leave other components alone")
  end)

  test(client .. " the default ring follows colour themes and explicit choices override it", function()
    local sim = make()
    local C, T, themes = sim.ns.Core, sim.ns.Theme, sim.ns.Themes
    local page = sim.ns.Options.byKey["battlegrounds-appearance"]
    local function Ring() return C.SniperHex(C.sniper.reticle.vertexColor) end
    local gold = C.SniperHex(themes.highground.color.sniperGold)
    equal(C.db.sniperColor, "theme", "new settings follow the theme")
    equal(Ring(), gold, "Highground keeps the gold ring")
    for _, name in ipairs({ "dark", "ember", "azeroth" }) do
      T.Use(name); sim:advance(0.2)
      local hex = C.SniperHex(themes[name].color.sniperTheme)
      assert(hex ~= gold, name .. " has its own ring colour")
      equal(Ring(), hex, name .. " colours the ring")
      equal(page.sniperColors.ring.button:GetText(), "#" .. hex, name .. " swatch follows the switch")
      equal(C.SniperHex(page.sniperPreview.reticle.vertexColor), hex, name .. " mini preview follows")
    end
    for _, name in ipairs({ "classcolors", "parchment" }) do
      T.Use(name); sim:advance(0.2)
      equal(Ring(), gold, name .. " keeps the gold ring")
    end
    T.Use("dark")
    sim:command("sniper color gold"); sim:advance(0.2)
    equal(Ring(), gold, "a named preset overrides the theme")
    sim:command("sniper color ring 33bb77"); T.Use("ember"); sim:advance(0.2)
    equal(Ring(), "33BB77", "a custom colour overrides the theme")
    sim:command("sniper color ring default"); sim:command("sniper color theme"); sim:advance(0.2)
    equal(Ring(), C.SniperHex(themes.ember.color.sniperTheme), "the theme preset follows the theme again")
    sim:command("go"); sim:advance(0.2)
    equal(Ring(), C.SniperHex(T.Rgb("kill")), "kill windows keep their own colour")
  end)

  test(client .. " the old gold default upgrades once to the theme ring", function()
    local sim = make({ sniperColor = "gold", profiles = {
      Old = { setup = { preferences = { sniperColor = "gold" } } },
      Cyan = { setup = { preferences = { sniperColor = "cyan" } } } } })
    local db = sim.ns.Core.db
    equal(db.sniperColor, "theme", "untouched gold default follows the theme")
    equal(db.profiles.Old.setup.preferences.sniperColor, "theme", "saved profiles upgrade too")
    equal(db.profiles.Cyan.setup.preferences.sniperColor, "cyan", "other presets stay")
    sim:command("sniper color gold")
    equal(make(sim.env.HighgroundDB).ns.Core.db.sniperColor, "gold", "gold chosen later survives reloads")
    equal(make({ sniperColor = "magenta" }).ns.Core.db.sniperColor, "magenta", "other saved presets stay")
  end)

  test(client .. " malformed colours are rejected and steady rendering reuses decoded RGB values", function()
    local sim = make({ sniperRingColor = "not-a-colour", sniperSkullColor = {}, sniperAimColor = "12345678" })
    local C = sim.ns.Core
    equal(C.db.sniperRingColor, "", "invalid ring falls back")
    equal(C.db.sniperSkullColor, "", "invalid skull type falls back")
    equal(C.db.sniperAimColor, "", "alpha-containing colours are rejected")
    assert(not C.SetSniperLayerColor("ring", "123") and not C.SetSniperLayerColor("unknown", "123456"))
    local P = sim.ns.Options.Profiles
    local setup = P.SnapshotSetup(); setup.preferences.sniperAimColor = "gggggg"
    assert(not P.PrepareSetup(setup), "profile validation rejects bad colours atomically")
    C.SetSniperLayerColor("ring", "123456"); C.SetSniperLayerColor("skull", "abcdef"); C.SetSniperLayerColor("aim", "8899aa")
    local decode, calls = sim.ns.ThemeColor, 0
    sim.ns.ThemeColor = function(...) calls = calls + 1; return decode(...) end
    local frames, rgb = #sim.frames, C.SniperLayerColor("ring")
    for _ = 1, 100 do C.PaintScope(C.sniper, false) end
    equal(calls, 0, "periodic rendering never reparses unchanged colours")
    equal(C.SniperLayerColor("ring"), rgb, "colour table is reused")
    equal(#sim.frames, frames, "repainting allocates no widgets")
  end)
end
