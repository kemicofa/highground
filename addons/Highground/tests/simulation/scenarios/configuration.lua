local test, new, check = ...
local function equal(a, b, why)
  if type(a) == "number" and type(b) == "number" then return check(math.abs(a - b) < 0.000001, true, why or "numbers match") end
  return check(a, b, why or "values match")
end
local F = dofile("tests/modules/fixture.lua")
local function click(button)
  assert(button and button:IsVisible() and button.enabled ~= false, "control is available")
  button.scripts.OnClick(button)
end
for _, client in ipairs({ "cata", "retail", "forever" }) do
  local function make(saved, disabled, network)
    return new(client == "cata" and "cata" or "retail", saved, function(s, env)
      F.configure(disabled)(s, env)
      if network then env.HighgroundReputationNetworkDB = network end
      if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
      dofile("../../tools/wowsim/geometry.lua")(s)
    end)
  end
  test(client .. " unavailable Reputation preferences explain incompatible saved data", function()
    local network = { version = 999, settings = { filter = false } }
    local s = make(nil, nil, network)
    s.ns.Hub.Open("reputation-settings")
    local page = s.ns.Options.byKey["reputation-settings"]
    assert(page.problem:IsVisible() and page.problem:GetText():find("newer addon", 1, true), "the real load error is visible")
    assert(not page.preferences.settingsBody:IsVisible(), "unavailable controls cannot pretend to save")
    equal(s.env.HighgroundReputationNetworkDB, network, "future-version data remains intact")
    equal(network.settings.filter, false)
    s:assertHealthy()
  end)
  test(client .. " addon preferences follow the saved language and later changes", function()
    local s = make({ locale = "frFR" })
    local O, L = s.ns.Options, s.ns.Locale
    local nearbyKey = "shared.nearby.tell_me_when_a_nearby_enemy_stealths.8861ca"
    local bountyKey = "shared.bounties.track_and_use_gold_across_account_characters.31f96e"
    local reputationKey = "reputation.window.hide_chat_from_blacklisted_players.549198"
    s.ns.Hub.Open("reputation-settings")
    O.BuildPage("nearby"); O.BuildPage("bounty") -- hidden pages keep following the language
    local reputation = O.byKey["reputation-settings"].preferences
    for _, locale in ipairs({ "frFR", "deDE", "enUS" }) do
      s.ns.Localization.SetPreference(locale)
      equal(O.byKey.nearby.behaviorToggles.nearbyStealth.label:GetText(), L:Get(nearbyKey))
      equal(O.byKey.bounty.behaviorToggles.bountyAccountGold.label:GetText(), L:Get(bountyKey))
      equal(reputation.toggles.filter.label:GetText(), L:Get(reputationKey))
      equal(reputation.replyInterval.caption:GetText(), L:Get("reputation.window.automatic_reply_frequency.1db7de"))
      for _, row in ipairs(O.byKey.nearby.rows) do
        equal(row.label:GetText(), s.ns.Core.SettingDefs.option[row.key].desc, "numeric labels follow their catalog")
      end
    end
    s:assertHealthy()
  end)

  test(client .. " alert controls expose only channels that the alert emits", function()
    local s = make()
    local A, O = s.ns.Alerts, s.ns.Options
    s.ns.Hub.Open("battlegrounds-settings")
    local soundOnly = 0
    for _, row in ipairs(O.featurePages.battlegrounds.alertRows) do
      if row.key == "go" or row.key == "lockon" then
        soundOnly = soundOnly + 1
        equal(row.text, nil, "no inert Text toggle for " .. row.key)
        click(row.sound)
        equal(A.Allowed(row.key, "sound"), false, "Sound control mutes the cue")
        click(row.sound)
        local before = #s.sounds
        click(row.play)
        equal(#s.sounds, before + 1, "the cue still auditions")
      else assert(row.text and row.text:IsVisible(), "written alerts retain Text controls") end
    end
    equal(soundOnly, 2)
    s:assertHealthy()
  end)

end
