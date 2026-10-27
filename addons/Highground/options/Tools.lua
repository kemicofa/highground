local _, ns = ...
local Theme, Kit = ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Test and commands page: preview buttons that run the same /hg commands,
-- and the slash-command reference, so nobody has to guess that /hg exists.
-- Each preview toggles: click again to stop it. Both lists come from
-- config/Commands.lua (one catalog for /hg help, this page and the docs).
---------------------------------------------------------------------------
local PREVIEWS = ns.CommandCatalog.previews
local COMMANDS = ns.CommandCatalog.commands

local page = Options.MakePage("tools")
local P = page.child
Options.tools = page

local function Run(cmd)
  SlashCmdList.HIGHGROUND(cmd)
end

local function Label(text, role, color, x, y)
  local fs = Theme.Text(P, role, color)
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  return fs
end

Kit.Section(P, "Previews"):SetPoint("TOPLEFT", S("xl"), page.y - S("md"))
page.y = page.y - 30
page.previews = {}
local col = 0
for _, def in ipairs(PREVIEWS) do
  if ns.OptionAvailable(def) then
    local x = S("xl") + col * 270
    local b = Kit.Button(P, def.label, 120, Z("control"))
    b:SetPoint("TOPLEFT", x, page.y)
    b.cmd = def.cmd
    b:SetScript("OnClick", function() Run(def.cmd) end)
    Kit.Tooltip(b, { "/hg " .. def.cmd, { "Click again to stop the preview.", "textMuted", false } },
      { anchor = "ANCHOR_RIGHT" })
    local d = Label(def.desc, "body", "textMuted", x + 126, page.y - 5)
    d:SetWidth(138)
    page.previews[#page.previews + 1] = b
    col = (col + 1) % 2
    if col == 0 then page.y = page.y - 30 end
  end
end
if col == 1 then page.y = page.y - 30 end

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
