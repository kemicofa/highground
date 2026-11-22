local _, ns = ...
local Theme, Kit = ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Shared command reference and shortcuts to each addon's previews.
-- config/Commands.lua also supplies /hg help and the command documentation.
---------------------------------------------------------------------------
local COMMANDS = ns.CommandCatalog.commands

local page = Options.MakePage("tools")
local P = page.child
Options.tools = page

local function Label(text, role, color, x, y)
  local fs = Theme.Text(P, role, color)
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  return fs
end

Options.Section(page, "Addon previews and guides")
for _, module in ipairs(ns.Modules.list) do
  Options.Link(page, module.name, function() ns.Hub.Open(Options.addonPages[module.key].previews) end)
end

local commands = Kit.Section(P, "Slash commands")
commands:SetPoint("TOPLEFT", S("xl"), page.y - S("lg"))
local note = Theme.Text(P, "body", "textMuted")
note:SetText("Type these in chat. /highground works too.")
note:SetPoint("LEFT", commands, "RIGHT", S("md"), 0)
commands.rule:SetPoint("LEFT", note, "RIGHT", S("md"), 0)
page.y = page.y - 34
page.commands = {}
for _, row in ipairs(COMMANDS) do
  if ns.OptionAvailable(row) then
    if not row[2] then
      Kit.Caption(P, row[1], "accent"):SetPoint("TOPLEFT", S("xl"), page.y - S("sm"))
      page.y = page.y - 20
    else
      local c = Label(row[1], "code", "gold", 24, page.y)
      c:SetWidth(250)
      local d = Label(row[2], "body", "text", 280, page.y)
      d:SetPoint("RIGHT", -S("xl"), 0)
      page.commands[#page.commands + 1] = row[1]
      page.y = page.y - 18
    end
  end
end
P:SetHeight(-page.y + 20)
