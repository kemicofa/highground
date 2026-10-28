local _, ns = ...

-- Arena panel settings: Highground and Highground Arena. See config/Options.lua.
ns.OptionsAdd({
  features = {
    {
      { group = "Arena", order = 6 },
      { key = "arena", label = "Arena enemy panel", desc = "Clickable enemy team: left-click target, right-click focus" },
    },
  },
})
