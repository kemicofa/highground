local _, ns = ...
local Commands = ns.Commands

SLASH_WARBOARD1 = "/wb"
SLASH_WARBOARD2 = "/warboard"
SLASH_WARBOARD3 = "/ko" -- pre-rename aliases
SLASH_WARBOARD4 = "/killorder"

SlashCmdList.WARBOARD = function(msg)
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  local function say(text)
    print("|cffff5533Warboard|r " .. text)
  end
  local handler = Commands[cmd] or Commands.help
  handler(arg, msg or "", say)
end
