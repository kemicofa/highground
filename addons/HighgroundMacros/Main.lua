local addon, ns = ...
local Macros, Util, Theme = ns.Macros, ns.Util, ns.Theme
local Host = Macros.Host

-- Saved settings and /hgm (the chat label comes from ns.LABEL, Bootstrap.lua).

local HELP = {
  "/hgm [pvp, pve, build or mine]: open the macros window",
  "/hgm export, /hgm import: share macros as a base64 string",
  "/hgm presets: a preset for every ranked spell you know (games with ranks)",
  "/hgm ranks: move every action button and macro up to your highest spell ranks (games with ranks)",
  "/hgm autorank on or off: move them up when you learn a new rank (games with ranks)",
  "/hgm theme NAME: " .. table.concat(Theme.Names(), ", "),
}

local function Command(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "help" or cmd == "?" then
    for _, line in ipairs(HELP) do Util.Say(line) end
  elseif cmd == "theme" then
    Util.Say(Theme.Use(rest:lower()) and ("theme: " .. rest:lower()) or "no such theme")
  elseif cmd == "autorank" then
    Host.Set("highestRank", rest:lower() ~= "off")
    Util.Say("highest spell rank " .. (Host.On("highestRank") and "on" or "off"))
  else
    Host.commands.macros(cmd ~= "" and cmd or nil)
  end
end

SLASH_HIGHGROUNDMACROS1, SLASH_HIGHGROUNDMACROS2 = "/hgm", "/hgmacros"
SlashCmdList.HIGHGROUNDMACROS = function(msg) Util.Guard("slash", Command, msg) end

Util.Events({
  ADDON_LOADED = function(_, name)
    if name ~= addon then return end
    HighgroundMacrosDB = type(HighgroundMacrosDB) == "table" and HighgroundMacrosDB or {}
    ns.Core.db = HighgroundMacrosDB
    Theme.Sync()
  end,
}, "load")
