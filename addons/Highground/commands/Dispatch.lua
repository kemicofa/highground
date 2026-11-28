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
  -- A Battlegrounds setting changes the size being edited: replies say which.
  local row, CS = ns.CommandCatalog.Row(msg), ns.CharacterSettings
  local page = row and row.ui and row.ui.page
  local config = page and ns.OptionsConfig.pages[page]
  local say = ns.Util.Say
  if CS and module == "battlegrounds" and config and ns.Options.ScopedPage(page, config) and cmd ~= "sizes" and cmd ~= "all" then
    say = function(text) ns.Util.Say(ns.Locale:Format("sizes.say", { text = text, size = CS.Label(CS.Editing()) })) end
  end
  handler(arg, msg, say)
  if ns.Options.RefreshVisible then ns.Options.RefreshVisible() end
  if ns.Options.RefreshPreviews then ns.Options.RefreshPreviews() end
end
