local addon, ns = ...
local Macros, Util, Theme = ns.Macros, ns.Util, ns.Theme
local Host = Macros.Host

-- Saved settings, chat label and /wbm.
Util.SAY_KINDS.default.label = "Warboard Macros"
for _, kind in ipairs({ "error", "warning" }) do Util.SAY_KINDS[kind].label = "Warboard Macros" end

local HELP = {
  "/wbm [pvp, pve, build or mine]: open the macros window",
  "/wbm export, /wbm import: share macros as a base64 string",
  "/wbm presets: a preset for every ranked spell you know (games with ranks)",
  "/wbm ranks: move every action button and macro up to your highest spell ranks (games with ranks)",
  "/wbm autorank on or off: move them up when you learn a new rank (games with ranks)",
  "/wbm theme NAME: " .. table.concat(Theme.Names(), ", "),
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

SLASH_WARBOARDMACROS1, SLASH_WARBOARDMACROS2 = "/wbm", "/wbmacros"
SlashCmdList.WARBOARDMACROS = function(msg) Util.Guard("slash", Command, msg) end

Util.Events({
  ADDON_LOADED = function(_, name)
    if name ~= addon then return end
    WarboardMacrosDB = type(WarboardMacrosDB) == "table" and WarboardMacrosDB or {}
    ns.Core.db = WarboardMacrosDB
    Theme.Sync()
  end,
}, "load")
