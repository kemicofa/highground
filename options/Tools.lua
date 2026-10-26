local _, ns = ...
local Options = ns.Options

-- Test and commands page: preview buttons that run the same /wb commands,
-- and the slash-command reference, so nobody has to guess that /wb exists.
-- Each preview toggles: click again to stop it.
-- Both lists live in config/Commands.lua (one catalog for /wb help, this
-- page and the docs).
Options.PREVIEWS = ns.CommandCatalog.previews
Options.COMMANDS = ns.CommandCatalog.commands

local page = Options.MakePage("tools")
local P = page.child
Options.tools = page

local function Run(cmd)
  SlashCmdList.WARBOARD(cmd)
end

local function Label(text, template, x, y)
  local fs = P:CreateFontString(nil, "ARTWORK", template)
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetJustifyH("LEFT")
  fs:SetText(text)
  return fs
end

Label("Previews", "GameFontNormal", 16, page.y - 6)
page.y = page.y - 30
page.previews = {}
local col = 0
for _, def in ipairs(Options.PREVIEWS) do
  if ns.OptionAvailable(def) then
    local x = 16 + col * 270
    local b = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
    b:SetSize(120, 22)
    b:SetPoint("TOPLEFT", x, page.y)
    b:SetText(def.label)
    b.cmd = def.cmd
    b:SetScript("OnClick", function() Run(def.cmd) end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine("/wb " .. def.cmd, 1, 0.82, 0)
      GameTooltip:AddLine("Click again to stop the preview.", 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    local d = Label(def.desc, "GameFontHighlightSmall", x + 126, page.y - 5)
    d:SetWidth(138)
    d:SetTextColor(0.7, 0.7, 0.75)
    page.previews[#page.previews + 1] = b
    col = (col + 1) % 2
    if col == 0 then page.y = page.y - 30 end
  end
end
if col == 1 then page.y = page.y - 30 end

Label("Slash commands", "GameFontNormal", 16, page.y - 10)
local note = Label("Type these in chat. /warboard works too.", "GameFontHighlightSmall", 140, page.y - 12)
note:SetTextColor(0.7, 0.7, 0.75)
page.y = page.y - 34
page.commands = {}
for _, row in ipairs(Options.COMMANDS) do
  if ns.OptionAvailable(row) then
    if not row[2] then
      local g = Label(row[1]:upper(), "GameFontDisableSmall", 16, page.y - 4)
      g:SetTextColor(0.55, 0.8, 0.78)
      page.y = page.y - 20
    else
      local c = Label(row[1], "GameFontNormalSmall", 24, page.y)
      c:SetWidth(250)
      local d = Label(row[2], "GameFontHighlightSmall", 280, page.y)
      d:SetPoint("RIGHT", -16, 0)
      page.commands[#page.commands + 1] = row[1]
      page.y = page.y - 18
    end
  end
end
P:SetHeight(-page.y + 20)
