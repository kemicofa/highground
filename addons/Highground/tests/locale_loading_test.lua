-- Only English and the language in use are loaded. Each other language is a
-- load-on-demand addon beside Highground (../HighgroundLocale*), loaded at
-- login or when chosen; a missing or disabled one leaves English with a notice.
-- Run from addons/Highground.
local t = dofile("../../tools/harness.lua")("locale loading")
local check = t.equal
t.equal = function(a, b, why) return check(a, b, why or "values match") end
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local GERMAN = "HighgroundLocaleDeDE"

local function start(client, saved, locale, configure)
  return new(client == "cata" and "cata" or "retail", saved, function(s, env)
    env.GetLocale = function() return locale or "enUS" end
    if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "", "", 16001 end end
    local load = env.C_AddOns.LoadAddOn
    s.loads = {}
    env.C_AddOns.LoadAddOn = function(name)
      s.loads[#s.loads + 1] = name
      return load(name)
    end
    if configure then configure(s, env) end
  end)
end

local function registered(s)
  local codes = {}
  for _, def in ipairs(s.ns.LocaleDefinitions) do
    if s.ns.Locale:Has(def.key) then codes[#codes + 1] = def.key end
  end
  return table.concat(codes, " ")
end

for _, client in ipairs({ "cata", "retail", "forever" }) do
  t.test(client .. ": a login without a language preference registers only English", function()
    for _, locale in ipairs({ "enUS", "deDE" }) do
      local s = start(client, {}, locale)
      t.equal(registered(s), "enUS", locale .. " client")
      t.equal(#s.loads, 0, "no language addon loads")
      t.equal(s.ns.Locale:GetLocale(), "enUS", "English is the default")
      t.equal(s.ns.Localization.Status(), s.ns.Locale:Format("locale.coverage",
        { language = "English", translated = s.ns.LocaleIndex.coverage.enUS, total = s.ns.LocaleIndex.coverage.enUS }), "status")
      s:assertHealthy()
    end
  end)

  t.test(client .. ": a saved language or the game's language loads only that addon at login", function()
    local saved = start(client, { locale = "frFR" }, "enUS")
    t.equal(registered(saved), "enUS frFR", "saved French")
    t.equal(table.concat(saved.loads, " "), "HighgroundLocaleFrFR", "one load")
    t.equal(saved.ns.Options.general.language.sample:GetText(), saved.ns.Locale:Get("locale.sample"), "early labels follow")
    assert(saved.ns.Locale:Get("locale.title") ~= "Language", "French text")
    local auto = start(client, { locale = "auto" }, "deDE")
    t.equal(registered(auto), "enUS deDE", "game language")
    t.equal(auto.ns.Locale:GetLocale(), "deDE")
    local alias = start(client, { locale = "auto" }, "enGB")
    t.equal(registered(alias), "enUS", "an English client loads nothing")
    t.equal(#alias.loads, 0)
  end)

  t.test(client .. ": choosing a language loads it once and switches at once", function()
    local s = start(client, {}, "enUS")
    local ns, L, picker = s.ns, s.ns.Locale, s.ns.Options.general.language
    s:command("config general")
    assert(picker.select:SetValue("deDE"))
    t.equal(L:GetLocale(), "deDE", "switched")
    t.equal(table.concat(s.loads, " "), GERMAN, "loaded on demand")
    t.equal(picker.sample:GetText(), L:Get("locale.sample"), "the picker's sample changed")
    assert(picker.sample:GetText() ~= L:Source("locale.sample"), "German sample")
    assert(picker.status:GetText():find(L:Get("locale.name.deDE"), 1, true), "coverage names the language")
    assert(picker.select:SetValue("enUS"))
    assert(picker.select:SetValue("deDE"))
    t.equal(#s.loads, 1, "a language never loads twice")
    assert(picker.select:SetValue("ruRU"))
    t.equal(registered(s), "enUS deDE ruRU", "only the chosen languages")
    t.equal(ns.Core.db.locale, "ruRU")
    s:assertHealthy()
  end)

  t.test(client .. ": a missing or disabled language keeps English and says why in the picker", function()
    for _, field in ipairs({ "missingAddons", "disabledAddons" }) do
      local s = start(client, { locale = "deDE" }, "enUS", function(sim) sim[field] = { [GERMAN] = true } end)
      local ns, L, picker = s.ns, s.ns.Locale, s.ns.Options.general.language
      t.equal(L:GetLocale(), "enUS", field .. ": English at login")
      t.equal(ns.Core.db.locale, "deDE", "the saved choice is kept for a complete installation")
      local notice = L:Format("locale.unavailable", { language = "German" })
      t.equal(ns.Localization.Status(), notice, field .. ": notice")
      s:command("config general")
      t.equal(picker.status:GetText(), notice, "the picker shows it")
      t.equal(picker.select:GetValue(), "deDE", "the picker keeps the choice")
      assert(picker.select:SetValue("frFR"))
      t.equal(L:GetLocale(), "frFR", "another installed language still loads")
      assert(picker.select:SetValue("deDE"))
      t.equal(L:GetLocale(), "enUS", "choosing it again falls back again")
      t.equal(picker.status:GetText(), notice)
      s[field] = nil
      assert(picker.select:SetValue("enUS") and picker.select:SetValue("deDE"))
      t.equal(L:GetLocale(), "deDE", "loads once it is available")
      s:assertHealthy()
    end
  end)

  t.test(client .. ": other clients' text is recognized without their catalogs", function()
    local s = start(client, {}, "enUS")
    local variants = s.ns.Locale:Variants("battlegrounds.graveyards.graveyard.2b11fa")
    t.equal(variants[1], "graveyard", "English first")
    local seen = {}
    for _, text in ipairs(variants) do seen[text] = true end
    assert(seen.Friedhof and seen["кладбище"] and seen["墓地"], "every language's word")
    local learned = { { label = "Friedhof", x = 0.3, y = 0.4 }, { label = "Stables", x = 0.3, y = 0.4 } }
    s.ns.Timers.DropPlaceholders(learned)
    t.equal(#learned, 1, "a German placeholder is dropped")
    local W = s.ns.Reputation
    assert(W.IsReply("[Highground Reputation] hidden") and W.IsReply("[Highground Репутация] hidden"), "reply markers")
  end)

  t.test(client .. ": battleground chat keeps only the client's announcement rows", function()
    local english = start(client, {}, "enUS")
    for _, locale in ipairs({ "deDE", "frFR", "zhTW" }) do
      t.equal(#english.ns.ChatLocaleData[locale], 0, "no " .. locale .. " rows on an English client")
    end
    local german = start(client, {}, "deDE")
    assert(#german.ns.ChatLocaleData.deDE > 50, "German rows on a German client")
    t.equal(#german.ns.ChatLocaleData.frFR, 0, "no French rows")
    t.equal(german.ns.LocalizedChat("Spieler hat die Flagge der Horde errungen!"), "Spieler captured the Horde Flag!",
      "German broadcasts still parse")
  end)
end

t.finish("Locale loading: " .. t.tests .. " tests")
