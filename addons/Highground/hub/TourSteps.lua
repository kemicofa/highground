local _, ns = ...
local O = ns.Onboarding
local function page(label, key, group, review)
  return ns.Localization.Define({ page = key, group = group, review = review }, { label = label })
end
local function native(key) return ns.Localization.Define({ label = ns.Locale:Get("highground.toursteps.open_guide.f84fe7"), native = key }, { label = "highground.toursteps.open_guide.f84fe7" }) end
local function tool(label, key) return ns.Localization.Define({ tool = key }, { label = label }) end
local function loaded(key) return function() return ns[key] ~= nil end end

function O.Text(step, field)
  local key = step.messages and step.messages[field]
  return key and ns.Locale:Get(key) or step[field]
end

-- Independent entry points, not a course that must be completed in order.
-- Highground bundles these modules; standalone folder names are not required.
O.aliases = { targeting = "enemies" }
O.directory = ns.Localization.Define({ key = "welcome", label = ns.Locale:Get("highground.hub.addons.f32c2d") }, { label = "highground.hub.addons.f32c2d" })
O.steps = {
  ns.Localization.Define({ key = "battlegrounds", module = "battlegrounds", label = ns.Locale:Get("highground.modules.battlegrounds.2de13e"), logo = "Battlegrounds", available = loaded("Timers"),
    paths = { "enemies", "objectives" }, messages = { summary = "guide.battlegrounds.summary", pathTitle = "guide.battlegrounds.title", pathHint = "guide.choose_hint" },
    actions = { { messages = { label = "guide.choose" }, paths = true }, page("highground.toursteps.battleground_previews.208a7c", "battlegrounds-previews"), page("highground.toursteps.battleground_settings.08240b", "battlegrounds-settings", "Battleground", "features") } }, { label = "highground.modules.battlegrounds.2de13e" }),
  { key = "enemies", module = "battlegrounds", parent = "battlegrounds", feature = "killorder",
    messages = { label = "guide.enemies.label", caption = "guide.enemies.caption", summary = "guide.enemies.summary" },
    actions = { native("enemies"), page("highground.toursteps.enemy_appearance.4fdfbc", "battlegrounds-appearance") } },
  { key = "objectives", module = "battlegrounds", parent = "battlegrounds", available = loaded("Timers"),
    messages = { label = "guide.objectives.label", caption = "guide.objectives.caption", summary = "guide.objectives.summary" },
    actions = { ns.Localization.Define({ label = ns.Locale:Get("highground.toursteps.try_it.7ddd66"), preview = "objectives" }, { label = "highground.toursteps.try_it.7ddd66" }) } },
  ns.Localization.Define({ key = "macros", module = "macros", label = ns.Locale:Get("highground.modules.macros.899bd6"), logo = "Macros", summary = ns.Locale:Get("highground.toursteps.try_a_macro_then_put_it_on.c922f4"), available = loaded("Macros"),
    actions = { native("macros"), tool("tools.open.macros", "macros") } }, { label = "highground.modules.macros.899bd6", summary = "highground.toursteps.try_a_macro_then_put_it_on.c922f4" }),
  ns.Localization.Define({ key = "bounties", module = "bounties", label = ns.Locale:Get("highground.modules.bounties.eba0bf"), logo = "Bounties", summary = ns.Locale:Get("highground.toursteps.post_a_reward_or_hunt_a_target.53f95b"), available = loaded("Bounty"),
    paths = { "bounty_post", "bounty_hunt" }, messages = { pathTitle = "guide.bounties.title", pathHint = "guide.bounties.hint" },
    actions = { { messages = { label = "guide.bounties.choose" }, paths = true }, tool("tools.open.bountyboard", "bountyboard") } }, { label = "highground.modules.bounties.eba0bf", summary = "highground.toursteps.post_a_reward_or_hunt_a_target.53f95b" }),
  ns.Localization.Define({ key = "bounty_post", module = "bounties", parent = "bounties", label = ns.Locale:Get("highground.toursteps.post_a_bounty.f67d15"), caption = ns.Locale:Get("highground.toursteps.bounties_post.699158"),
    summary = ns.Locale:Get("highground.toursteps.create_a_reward_review_claims_and_record.605c47"), available = loaded("Bounty"),
    actions = { ns.Localization.Define({ label = ns.Locale:Get("highground.toursteps.start_posting_guide.4cedfa"), bounties = "post" }, { label = "highground.toursteps.start_posting_guide.4cedfa" }) } }, { label = "highground.toursteps.post_a_bounty.f67d15", caption = "highground.toursteps.bounties_post.699158", summary = "highground.toursteps.create_a_reward_review_claims_and_record.605c47" }),
  ns.Localization.Define({ key = "bounty_hunt", module = "bounties", parent = "bounties", label = ns.Locale:Get("highground.toursteps.hunt_a_bounty.113007"), caption = ns.Locale:Get("highground.toursteps.bounties_hunt.0ebb53"),
    summary = ns.Locale:Get("highground.toursteps.track_a_target_and_follow_its_automatic.508455"), available = loaded("Bounty"),
    actions = { ns.Localization.Define({ label = ns.Locale:Get("highground.toursteps.start_hunting_guide.46a876"), bounties = "hunt" }, { label = "highground.toursteps.start_hunting_guide.46a876" }) } }, { label = "highground.toursteps.hunt_a_bounty.113007", caption = "highground.toursteps.bounties_hunt.0ebb53", summary = "highground.toursteps.track_a_target_and_follow_its_automatic.508455" }),
  ns.Localization.Define({ key = "nearby", module = "nearby", label = ns.Locale:Get("highground.modules.nearby.f1536c"), logo = "Nearby", summary = ns.Locale:Get("highground.toursteps.fresh_sightings_faded_sightings_and_enemy_history.b46e63"), available = loaded("Nearby"), feature = "nearby",
    actions = { native("nearby"), tool("highground.toursteps.open_enemy_history.6ee9a0", "journal") } }, { label = "highground.modules.nearby.f1536c", summary = "highground.toursteps.fresh_sightings_faded_sightings_and_enemy_history.b46e63" }),
  ns.Localization.Define({ key = "arena", module = "arena", label = ns.Locale:Get("profiles.panel.arena"), logo = "Arena", summary = ns.Locale:Get("highground.toursteps.target_focus_and_keep_track_of_your.941678"), available = loaded("Arena"), feature = "arena",
    actions = { ns.Localization.Define({ label = ns.Locale:Get("highground.toursteps.try_it.7ddd66"), preview = "arena" }, { label = "highground.toursteps.try_it.7ddd66" }) } }, { label = "profiles.panel.arena", summary = "highground.toursteps.target_focus_and_keep_track_of_your.941678" }),
  ns.Localization.Define({ key = "reputation", module = "reputation", label = ns.Locale:Get("highground.modules.reputation.5f2160"), logo = "Reputation", summary = ns.Locale:Get("highground.toursteps.report_a_player_and_review_a_guild.a8b7c0"), available = loaded("Reputation"),
    actions = { native("reputation"), tool("highground.toursteps.open_player_reputation.37164b", "reputation") } }, { label = "highground.modules.reputation.5f2160", summary = "highground.toursteps.report_a_player_and_review_a_guild.a8b7c0" }),
  ns.Localization.Define({ key = "map", module = "battlegrounds", label = ns.Locale:Get("highground.toursteps.enemy_map.34c638"), summary = ns.Locale:Get("highground.toursteps.try_enemy_sightings_on_warsong_gulch.0f429b"), extra = true, available = loaded("Intel"), feature = "intel",
    actions = { ns.Localization.Define({ label = ns.Locale:Get("highground.toursteps.try_warsong_gulch.8bf2b8"), map = true }, { label = "highground.toursteps.try_warsong_gulch.8bf2b8" }), page("highground.toursteps.map_settings.e45ed1", "battlegrounds-settings", "Map and sharing", "features") } }, { label = "highground.toursteps.enemy_map.34c638", summary = "highground.toursteps.try_enemy_sightings_on_warsong_gulch.0f429b" }),
  ns.Localization.Define({ key = "callouts", module = "battlegrounds", label = ns.Locale:Get("profiles.panel.callouts"), summary = ns.Locale:Get("highground.toursteps.try_the_buttons_used_during_battlegrounds.0de9a9"), extra = true, feature = "quickCalls",
    actions = { ns.Localization.Define({ label = ns.Locale:Get("highground.toursteps.try_it.7ddd66"), quickCalls = true }, { label = "highground.toursteps.try_it.7ddd66" }), page("highground.toursteps.battleground_settings.08240b", "battlegrounds-settings", "Battleground", "features") } }, { label = "profiles.panel.callouts", summary = "highground.toursteps.try_the_buttons_used_during_battlegrounds.0de9a9" }),
  ns.Localization.Define({ key = "records", label = ns.Locale:Get("highground.toursteps.history_notes.83ccc2"), summary = ns.Locale:Get("highground.toursteps.find_an_encounter_and_leave_yourself_a.fb2a0a"), extra = true,
    actions = { native("records"), tool("tools.open.history", "history"), tool("tools.open.journal", "journal") } }, { label = "highground.toursteps.history_notes.83ccc2", summary = "highground.toursteps.find_an_encounter_and_leave_yourself_a.fb2a0a" }),
  ns.Localization.Define({ key = "features", label = ns.Locale:Get("highground.hub.appearance.41def7"), messages = { summary = "appearance.preview.guide_summary" }, extra = true,
    actions = { native("features"), page("highground.toursteps.choose_panels.994479", "battlegrounds-settings", nil, "features"), page("highground.hub.shared_appearance.78b3c9", "appearance") } }, { label = "highground.hub.appearance.41def7" }),
  ns.Localization.Define({ key = "alerts", label = ns.Locale:Get("highground.toursteps.alerts_sounds.891c2b"), messages = { summary = "alerts.sample.guide_summary" }, extra = true,
    actions = { native("alerts"), page("highground.toursteps.choose_alerts.10b67e", "alerts", nil, "alerts") } }, { label = "highground.toursteps.alerts_sounds.891c2b" }),
  ns.Localization.Define({ key = "profile", label = ns.Locale:Get("highground.toursteps.saved_setups.427978"), summary = ns.Locale:Get("highground.toursteps.review_settings_save_a_setup_and_choose.88bd37"), extra = true,
    actions = { native("profile"), page("highground.toursteps.open_profiles.2873f6", "profiles", nil, "profile") } }, { label = "highground.toursteps.saved_setups.427978", summary = "highground.toursteps.review_settings_save_a_setup_and_choose.88bd37" }),
  ns.Localization.Define({ key = "panels", module = "battlegrounds", label = ns.Locale:Get("highground.toursteps.move_panels.bc0132"), summary = ns.Locale:Get("highground.toursteps.drag_sample_panels_into_position.41a9de"), extra = true,
    actions = { ns.Localization.Define({ label = ns.Locale:Get("highground.toursteps.move_panels.bc0132"), preview = "bg" }, { label = "highground.toursteps.move_panels.bc0132" }), page("highground.hub.playstyle_presets.469bdc", "setup", nil, "panels") } }, { label = "highground.toursteps.move_panels.bc0132", summary = "highground.toursteps.drag_sample_panels_into_position.41a9de" }),
  ns.Localization.Define({ key = "addons", label = ns.Locale:Get("highground.toursteps.addon_controls.8441da"), summary = ns.Locale:Get("highground.toursteps.choose_which_addons_run_find_their_commands.8e2f2b"), extra = true,
    actions = { native("addons"), page("highground.toursteps.all_commands_and_controls.7676ca", "tools") } }, { label = "highground.toursteps.addon_controls.8441da", summary = "highground.toursteps.choose_which_addons_run_find_their_commands.8e2f2b" }),
  ns.Localization.Define({ key = "users", label = ns.Locale:Get("highground.hub.addon_users.1e4e6f"), summary = ns.Locale:Get("highground.toursteps.read_channel_membership_version_reports_and_discovery.acd1fd"), extra = true,
    actions = { native("users"), page("highground.commands.open_addon_users.1c5288", "users") } }, { label = "highground.hub.addon_users.1e4e6f", summary = "highground.toursteps.read_channel_membership_version_reports_and_discovery.acd1fd" }),
}

function O.Available(step)
  if step.module and not ns.Modules.byKey[step.module] then return false end -- not in this game
  return not step.available or step.available()
end
function O.Guides(extra)
  local result = {}
  for _, step in ipairs(O.steps) do
    if not step.parent and not not step.extra == not not extra and O.Available(step) then result[#result + 1] = step end
  end
  return result
end

function O.PathGroup()
  local step = O.Current()
  return step.paths and step or step.parent and O.Find(step.parent)
end

function O.Paths(group)
  local result = {}
  for _, key in ipairs(group.paths) do
    local step = O.Find(key)
    if step and O.Available(step) then result[#result + 1] = step end
  end
  return result
end
