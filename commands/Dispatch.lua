local _, ns = ...
local Commands = ns.Commands

SLASH_WARBOARD1 = "/wb"
SLASH_WARBOARD2 = "/warboard"
SLASH_WARBOARD3 = "/ko" -- pre-rename aliases
SLASH_WARBOARD4 = "/killorder"

-- Handlers get (arg, msg, say): arg is lowercased, msg is the raw text,
-- say is ns.Util.Say.
SlashCmdList.WARBOARD = function(msg)
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  -- /wb alone opens the Warboard window; /wb help lists the commands.
  if cmd == "" and ns.Hub then return ns.Hub.Toggle() end
  local handler = Commands[cmd] or Commands.help
  handler(arg, msg or "", ns.Util.Say)
end
