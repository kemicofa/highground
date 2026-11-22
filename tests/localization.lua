-- Real manifest integration, invoked by test_localization.py for every host.
local addon, client, build = arg[1], arg[2], tonumber(arg[3])
local bg = addon == "Highground" or addon == "HighgroundBattlegrounds"
local new = dofile(bg and "../../tools/wowsim/battleground/runtime.lua" or "../../tools/wowsim/runtime.lua")
local function start(saved, locale, inject)
  return new(client, saved, function(s, env)
    s.addon = addon
    env.GetLocale = function() return locale or "frFR" end
    env.GetBuildInfo = function() return "1", "1", "date", build end
    env.STANDARD_TEXT_FONT = "NativeFont.ttf"
    if addon == "Highground" then dofile("../../tools/wowsim/geometry.lua")(s) end
    local load = s.load
    function s:load(path)
      -- Substitute a test translation file without constraining future real
      -- French translations to match this fixture's wording.
      if path ~= "libs/locale/frFR.lua" or not inject then load(self, path) end
      if path == "libs/locale/Highground.lua" and inject then
        assert(self.ns.Locale:Register("frFR", {
          ["locale.title"] = "Langue", ["locale.sample"] = "Exemple : les préférences de langue s'appliquent à Highground.",
          ["preferences.title"] = "Highground : Préférences partagées",
          ["locale.name.frFR"] = "Français",
        }))
      end
    end
  end)
end
local function control(s)
  return addon == "Highground" and s.ns.Options.general.language or s.ns.StandaloneSettings.frame.language
end
local saved = {}
local s = start(saved, "frFR", true)
local ns, l, p = s.ns, s.ns.Locale, control(s)
assert(saved.locale == "enUS" and l:GetLocale() == "enUS", "English is the default even on a French client")
assert(p.select:GetValue() == "enUS" and #p.select.choices == 12)
if addon == "Highground" then s:command("config general") else ns.StandaloneSettings.Open() end
local sent = #s.sent
p.select.scripts.OnClick(p.select, "LeftButton")
local menu = ns.Kit.Dropdown.Frame()
assert(menu and menu:IsShown(), "the real picker opens")
-- Select via the widget's public action (also used by its menu).
assert(p.select:SetValue("frFR"))
assert(saved.locale == "frFR" and l:GetLocale() == "frFR")
assert(p.select:GetText() == "Français (frFR)" and p.status:GetText():find("Français", 1, true), "language names use the catalog")
assert(p.sample:GetText():find("Exemple", 1, true), "display changes through the actual binding")
if addon == "Highground" then assert(ns.Options.general.title:GetText() == "Highground : Préférences partagées") end
assert(#s.sent == sent, "language selection never broadcasts")
for _, def in ipairs(ns.LocaleDefinitions) do
  assert(p.select:SetValue(def.key))
  assert(saved.locale == def.key and l:GetLocale() == def.key)
  assert(p.sample:GetText() == l:Get("locale.sample"))
end
assert(p.select:SetValue("auto"))
assert(saved.locale == "auto" and l:GetLocale() == "frFR")
assert(not ns.Localization.SetPreference("invalid"))
assert(saved.locale == "auto")
assert(not p.select:SetValue("invalid"))
ns.Kit.Dropdown.Hide()
s:assertHealthy()

-- SavedVariables are applied after module load: already created labels update.
local restored = start({ locale = "frFR" }, "enUS", true)
assert(control(restored).sample:GetText():find("Exemple", 1, true), "saved locale updates early-created widgets")
local auto = start({ locale = "auto" }, "koKR")
assert(auto.ns.Locale:GetLocale() == "koKR" and auto.ns.Localization.Font() == "NativeFont.ttf")
assert(control(auto).sample:GetFont() == "NativeFont.ttf", "native script face reaches the renderer")
assert(auto.ns.Localization.SetPreference("enUS"))
assert(auto.ns.Localization.Font() == "NativeFont.ttf", "English UI retains native name glyphs")
local sample = control(auto).sample
local setFont = sample.SetFont
sample.SetFont = function(self, file, ...)
  if file ~= "NativeFont.ttf" then return false end
  return setFont(self, file, ...)
end
assert(auto.ns.Localization.SetPreference("zhTW"))
assert(sample:GetFont() == "NativeFont.ttf", "missing script font falls back to the native face")
local alias = start({ locale = "ptPT" }, "enUS")
assert(alias.ns.Locale:GetLocale() == "ptBR" and alias.ns.Core.db.locale == "ptBR")
local corrupt = start({ locale = {} }, "deDE")
assert(corrupt.ns.Locale:GetLocale() == "enUS" and corrupt.ns.Core.db.locale == "enUS")
local unsupported = start({ locale = "auto" }, "unsupported")
assert(unsupported.ns.Locale:GetLocale() == "enUS" and unsupported.ns.Core.db.locale == "auto")

if addon == "Highground" then
  local profiles = ns.Options.Profiles
  local snapshot = profiles.Snapshot()
  assert(snapshot.locale == nil and snapshot.options.locale == nil
    and snapshot.setup.preferences.locale == nil, "language is not shared in profiles")
  snapshot.options.locale = "deDE"
  snapshot.setup.preferences.locale = "deDE"
  profiles.Apply(assert(profiles.Prepare(snapshot)))
  assert(saved.locale == "auto" and ns.Locale:GetLocale() == "frFR", "import cannot replace the language preference")
  local o, c = ns.Onboarding, ns.Onboarding.Coach
  s.env.UIParent:SetSize(1280, 720)
  ns.Core.SetFontScale(1.5)
  o.Start("features")
  local language
  for i, step in ipairs(c.steps) do if step.id == "language" then language = i end end
  assert(language, "Appearance guide includes the real language control")
  c.Go(language); c.Update()
  assert(c.target == p.select and c.target:IsVisible())
  local target, scroll = s.bounds(p.select), s.bounds(ns.Options.general.scroll)
  assert(target[2] >= scroll[2] - 1 and target[2] + target[4] <= scroll[2] + scroll[4] + 1,
    "guide scrolls the language control inside its viewport at large text size")
  local before = saved.locale
  o.Return(); assert(not c.running and saved.locale == before, "closing the guide never selects a language")
  o.Start("features"); o.Return(); assert(not c.running)
  s:command("bg test"); s:advance(0.2)
  assert(ns.PreviewTests.Active("bg test"), "owned battleground preview starts with localization enabled")
  s:command("bg test stop"); assert(not ns.PreviewTests.AnyActive())
  s:command("test"); s:advance(0.2)
  assert(ns.PreviewTests.AllActive(), "shared addon previews start with localization enabled")
  s:command("test stop")
  assert(not ns.PreviewTests.AnyActive() and not ns.Nearby.test and not ns.Bounty.Preview.state,
    "shared previews release all sample providers")
  assert(saved.locale == before, "previews preserve the language preference")
end
for _, sim in ipairs({ s, restored, auto, alias, corrupt, unsupported }) do sim:assertHealthy() end
print(addon .. " " .. build .. ": locale selection, fallback, restoration, fonts and preview passed")
