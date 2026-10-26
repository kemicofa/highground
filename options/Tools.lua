local _, ns = ...
local Options = ns.Options

-- Test and commands page: preview buttons that run the same /wb commands,
-- and the slash-command reference, so nobody has to guess that /wb exists.
-- Each preview toggles: click again to stop it.
Options.PREVIEWS = {
  { cmd = "test", label = "Main panel", desc = "Enemy list and kill-target card with sample enemies" },
  { cmd = "sniper test", label = "Target marker", desc = "Crosshair on any target with a visible nameplate" },
  { cmd = "go", label = "Kill window", desc = "GO look and sound (with Main panel or Target marker on)" },
  { cmd = "arena test", label = "Arena panel", desc = "Arena enemy team with trinkets" },
  { cmd = "nearby test", label = "Nearby enemies", desc = "Open-world enemy list" },
  { cmd = "intel test", label = "Map pin", desc = "Sample enemy pin on the world map" },
  { cmd = "burst test", label = "Burst marker", desc = "Marker beside your target's nameplate", cata = true },
  { cmd = "pressure test", label = "Pressure shields", desc = "Shield badge on a targeted teammate or yourself", cata = true },
  { cmd = "bounty test", label = "Bounty alert", desc = "Bounty sound and center-screen message" },
  { cmd = "bounty", label = "Bounty board", desc = "Open or close the bounty board" },
}

-- { command, what it does }; group rows have only a title.
Options.COMMANDS = {
  { "General" },
  { "/wb", "This list in chat, with your detected spec" },
  { "/wb config", "Open these settings" },
  { "/wb lock  |  unlock", "Keep panels in place, or drag them by their headers" },
  { "/wb reset  |  timers reset", "Move the main panel back; restore battleground panel spacing" },
  { "/wb scale 0.8  |  opacity 45  |  rows 8", "Panel scale, background opacity, enemy rows shown" },
  { "/wb compact [on|off]", "Slim one-line layout" },
  { "/wb sound", "Mute or unmute every Warboard sound" },
  { "Targets" },
  { "/wb priority on|off", "Target recommendations" },
  { "/wb call [s|i|raid|party|y]", "Call the kill target in chat, or pick the channel" },
  { "/wb mark icon 1-8  |  mark ping TYPE", "What the mark key does: a raid icon or a ping" },
  { "/wb why", "Why the kill target was chosen" },
  { "/wb live", "Reorder rows by live priority" },
  { "/wb all", "Also turn on in unrated battlegrounds" },
  { "/wb kit", "Tracked cooldowns of your target", cata = true },
  { "/wb exec PCT", "Execute health threshold", cata = true },
  { "Panels and previews" },
  { "/wb test", "Main panel preview" },
  { "/wb arena on|off|test", "Arena enemy panel" },
  { "/wb nearby on|off|test|clear", "Open-world nearby enemies" },
  { "/wb intel on|off|test  |  intel share on|off", "Enemy map positions and sharing" },
  { "/wb sniper test  |  go", "Target marker and kill-window previews" },
  { "/wb burst [test]", "Burst marker preview and recent burst buffs", cata = true },
  { "/wb pressure on|off|test|count N", "Teammate pressure shields", cata = true },
  { "Bounties" },
  { "/wb bounty", "Open the bounty board" },
  { "/wb bounty add [GOLD] NAME [; note]", "Personal bounty; NAME can be \"target\"" },
  { "/wb bounty submit|remove|claim NAME", "Send to your guild, take down, or report a kill" },
  { "/wb bounty approve|reject NAME", "Officers: review submissions" },
  { "/wb bounty list|sync|test|on|off", "Print, ask the guild, preview, switch alerts" },
  { "Tuning and profiles" },
  { "/wb profile save|load|delete NAME", "Named settings profiles" },
  { "/wb export [NAME]  |  import", "Share settings or a saved profile as a base64 string" },
  { "/wb points [NAME VALUE]", "Show or set a scoring value" },
  { "/wb weights  |  weight NAME X", "Score multipliers" },
  { "Troubleshooting" },
  { "/wb err  |  clearerr", "Show or clear recorded errors" },
  { "/wb probe  |  map", "What the addon reads from your target and this map" },
  { "/wb cap why|probe|clear", "Capture tracking diagnostics" },
}

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
