local _, ns = ...
ns.STANDBY_COMMAND = "/hg reputation"
ns.Standalone.Start({
  command = "HIGHGROUNDREPUTATION", slash = { "/hgrep", "/hgreputation" },
  help = { "/hgrep: communities, blacklists, proposals and moderation", "/hgrep report target: report your target",
    "/hgrep communities | report target | sync | status | on | off" },
  default = function(command, rest) ns.Reputation.Command(command .. (rest ~= "" and (" " .. rest) or "")) end,
  settings = { hint = "Player reports and moderation for your guild and WoW communities. Right-click a player's chat name or portrait to report them.",
    keys = {}, buttons = { { "Open Highground Reputation", function() ns.Reputation.Open() end } } },
})
