local _, ns = ...

-- Arena/duel panel settings: Highground and Highground Arena. See config/Options.lua.
ns.OptionsAdd({
  module = "arena",
  features = {
    {
      ns.Localization.Define({ group = "Arena", order = 6 }, { groupLabel = "highground.modules.arena.1a4ba8" }),
      ns.Localization.Define({ key = "arena", label = ns.Locale:Get("highground.toursteps.arena_duels.53e5be"), desc = ns.Locale:Get("shared.arena.opens_automatically_left_click_target_right_click.f80b6e") }, { label = "highground.toursteps.arena_duels.53e5be", desc = "shared.arena.opens_automatically_left_click_target_right_click.f80b6e" }),
    },
  },
})
