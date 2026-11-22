local _, ns = ...

-- Arena/duel panel settings: Highground and Highground Arena. See config/Options.lua.
ns.OptionsAdd({
  module = "arena",
  features = {
    {
      { group = "Arena", order = 6 },
      { key = "arena", label = "Arena & duels", desc = "Opens automatically. Left-click target; right-click focus." },
    },
  },
})
