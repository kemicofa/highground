local _, ns = ...
local Commands = ns.Commands

SLASH_HIGHGROUND1 = "/hg"
SLASH_HIGHGROUND2 = "/highground"

-- Handlers get (arg, msg, say): arg is lowercased, msg is the raw text,
-- say is ns.Util.Say.
SlashCmdList.HIGHGROUND = function(msg)
  local cmd, arg = (msg or ""):lower():match("^(%S*)%s*(.-)$")
  -- /hg alone opens the Highground window; /hg help lists the commands.
  if cmd == "" and ns.Hub then return ns.Hub.Toggle() end
  local handler = Commands[cmd] or Commands.help
  handler(arg, msg or "", ns.Util.Say)
end
