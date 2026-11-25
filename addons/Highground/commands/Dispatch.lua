local _, ns = ...
local Commands = ns.Commands

SLASH_HIGHGROUND1 = "/hg"
SLASH_HIGHGROUND2 = "/highground"

-- Handlers get (arg, msg, say): arg is lowercased, msg is the raw text,
-- say is ns.Util.Say.
SlashCmdList.HIGHGROUND = function(msg)
  -- Spaces around the command never matter; spaces inside an argument
  -- (a two-part name) stay.
  msg = (msg or ""):match("^%s*(.-)%s*$")
  local cmd, arg = msg:lower():match("^(%S*)%s*(.-)$")
  -- /hg alone opens the Highground window; /hg help lists the commands.
  if cmd == "" and ns.Hub then return ns.Hub.Toggle() end
  local module = ns.CommandCatalog.Owner(msg)
  if module and not ns.Modules.Require(module) then return end
  local handler = Commands[cmd] or Commands.help
  handler(arg, msg, ns.Util.Say)
  if ns.Options.RefreshVisible then ns.Options.RefreshVisible() end
  if ns.Options.RefreshPreviews then ns.Options.RefreshPreviews() end
end
