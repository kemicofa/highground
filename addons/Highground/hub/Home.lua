local _, ns = ...
local Core, Theme, Kit, Hub = ns.Core, ns.Theme, ns.Kit, ns.Hub
local shortcuts = {
  { "general", "Features", "Choose what shows during play" },
  { "alerts", "Alerts", "Choose your text and sound" },
  { "profiles", "Profiles", "Save or load a named setup" },
  { "macros", "Macros", "Find macros for your class" },
}

function Hub.BuildHome(content)
  local h = CreateFrame("Frame", nil, content)
  h:SetAllPoints(); Hub.home = h
  h.card = Kit.Card(h, 96, { titleRole = "heading" })
  h.card:SetPoint("TOPLEFT"); h.card:SetPoint("RIGHT")
  h.card:EnableMouse(false)
  h.where = h.card.title
  h.state = Theme.Text(h.card, "body", "textMuted")
  h.state:SetPoint("TOPLEFT", 16, -42); h.state:SetPoint("RIGHT", -16, 0)
  h.state:SetHeight(44); h.state:SetJustifyH("LEFT"); h.state:SetWordWrap(true)

  h.guide = Kit.Card(h, 140, { titleRole = "heading" })
  h.guide:SetPoint("TOPLEFT", 0, -112); h.guide:SetPoint("RIGHT")
  h.guide:EnableMouse(false)
  h.guideHint = Theme.Text(h.guide, "body", "textMuted")
  h.guideHint:SetPoint("TOPLEFT", 16, -46); h.guideHint:SetPoint("RIGHT", -16, 0)
  h.guideHint:SetHeight(40); h.guideHint:SetJustifyH("LEFT"); h.guideHint:SetWordWrap(true)
  h.start = Kit.Button(h.guide, "Start setup", 220, 32, { tone = "accent", onClick = function()
    Hub.Show("checklist")
  end })
  h.start:SetPoint("BOTTOMLEFT", 16, 16)
  h.arrange = Kit.Button(h.guide, "Arrange panels", 190, 32, { onClick = function()
    ns.Setup.Open(true)
    local ok, problem = ns.Setup.BeginPlacement()
    if not ok then ns.Util.Say(problem) end
  end })
  h.arrange:SetPoint("BOTTOMRIGHT", -16, 16)

  local title = Kit.Section(h, "Make it yours")
  title:SetPoint("TOPLEFT", 4, -274)
  h.shortcuts = {}
  for i, def in ipairs(shortcuts) do
    local key, y = def[1], -308 - math.floor((i - 1) / 2) * 82
    local b = Kit.Button(h, def[2], 330, 72, { onClick = function() Hub.Show(key) end })
    if i % 2 == 1 then
      b:SetPoint("TOPLEFT", h, "TOPLEFT", 0, y); b:SetPoint("TOPRIGHT", h, "TOP", -8, y)
    else
      b:SetPoint("TOPLEFT", h, "TOP", 8, y); b:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, y)
    end
    b.label:ClearAllPoints(); b.label:SetPoint("TOPLEFT", 16, -12)
    b.label:SetPoint("RIGHT", -16, 0); b.label:SetJustifyH("LEFT")
    b.hint = Theme.Text(b, "body", "textMuted")
    b.hint:SetPoint("TOPLEFT", 16, -40); b.hint:SetPoint("RIGHT", -16, 0)
    b.hint:SetJustifyH("LEFT"); b.hint:SetText(def[3])
    b.key = key; h.shortcuts[i] = b
  end
  h.tools = Kit.Button(h, "Previews and commands", 250, 30, { onClick = function() Hub.Show("tools") end })
  h.tools:SetPoint("TOPLEFT", 0, -488)
  h.help = Theme.Text(h, "body", "textMuted")
  h.help:SetPoint("TOPLEFT", 0, -534)
  h.help:SetText("Your settings save automatically.")
  h:Hide()
end

function Hub.RefreshHome()
  local h = Hub.home
  if not h then return end
  local _, kind = IsInInstance()
  local bg = ns.GetBG and ns.GetBG()
  local active = ns.IsActive and ns.IsActive()
  if kind == "pvp" then
    h.where:SetText((bg and bg.name or "Battleground"):upper())
    h.state:SetText(active and "Your enabled battleground panels are running."
      or "Highground is off here. Review battleground choices under Features.")
  elseif kind == "arena" then
    h.where:SetText("ARENA")
    h.state:SetText(Core.On("arena") and "Your arena enemy panel is on." or "Your arena enemy panel is off. You can enable it under Features.")
  else
    h.where:SetText("OPEN WORLD")
    h.state:SetText("Battleground and arena panels appear when you join a match. Nearby enemies and bounties follow your feature choices.")
  end
  h.card:SetStrip(active and "accent" or "textMuted")
  local done = 0
  if ns.Onboarding then
    for _, key in ipairs({ "panels", "features", "alerts" }) do if ns.Onboarding.Done(key) then done = done + 1 end end
  end
  local complete = Core.db.onboarding and Core.db.onboarding.complete
  h.guide.title:SetText(complete and "You're ready to play" or "Set up Highground for your playstyle")
  h.guideHint:SetText(complete and "You can revisit setup or move your panels whenever you want."
    or string.format("%d of 3 essentials complete. Follow the checklist at your own pace.", done))
  h.start:SetText(complete and "Review checklist" or (done > 0 and "Continue setup" or "Start setup"))
  h.arrange:SetEnabled(not InCombatLockdown() and kind ~= "pvp" and kind ~= "arena")
end
