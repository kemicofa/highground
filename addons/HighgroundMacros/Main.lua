local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host

-- /hgm and the settings page (start-up: libs/standalone/Main.lua).
ns.Standalone.Start({
  command = "HIGHGROUNDMACROS",
  slash = { "/hgm", "/hgmacros" },
  help = {
    "/hgm [pvp, pve, build or mine]: open the macros window",
    "/hgm export, /hgm import: share macros as a base64 string",
    "/hgm presets: a preset for every ranked spell you know (games with ranks)",
    "/hgm ranks: move every action button and macro up to your highest spell ranks (games with ranks)",
    "/hgm autorank on or off: move them up when you learn a new rank (games with ranks)",
  },
  commands = {
    autorank = function(rest)
      Host.Set("highestRank", rest:lower() ~= "off")
      ns.Util.Say("highest spell rank " .. (Host.On("highestRank") and "on" or "off"))
    end,
  },
  default = function(cmd) Host.commands.macros(cmd ~= "" and cmd or nil) end,
  settings = {
    hint = "Macro presets and the builder open with /hgm. Script presets (vendor, quest and utility) can be hidden. On games with spell ranks, buttons and macros can move up to a new rank when you learn it.",
    keys = { "highestRank", "highestRankMacros", "scriptMacros" },
    buttons = { { "Open macros", function() Host.commands.macros() end } },
  },
})
