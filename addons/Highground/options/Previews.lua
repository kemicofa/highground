local _, ns = ...
local O, Core, Kit, Theme = ns.Options, ns.Core, ns.Kit, ns.Theme
local pages = {}
local guides = { battlegrounds = { "enemies", "battlegrounds", "map", "callouts" }, arena = { "arena" },
  nearby = { "nearby" }, bounties = { "bounty_post", "bounty_hunt" }, reputation = { "reputation" }, macros = { "macros" } }
local contexts = { battlegrounds = "bg", arena = "arena", nearby = "world" }
local function Allowed()
  return ns.Setup.CanArrange()
end

local function Build(page, owner)
  O.Section(page, "Learn this addon")
  page.guides = {}
  for _, key in ipairs(guides[owner]) do
    local step = ns.Onboarding.Find(key)
    if step and ns.Onboarding.Available(step) then
      page.guides[#page.guides + 1] = O.Link(page, step.label .. " guide", function() ns.Onboarding.Start(key) end)
    end
  end
  if contexts[owner] then
    page.arrange = O.Link(page, "Preview and move panels", function() ns.PanelControls.Arrange(contexts[owner]) end)
  end
  O.Section(page, "Previews and tools")
  page.previews = {}
  local function Add(def)
    local row = CreateFrame("Frame", nil, page.child)
    local button = Kit.Button(row, "", 330, 32)
    button:SetPoint("TOPLEFT"); button:SetPoint("TOPRIGHT")
    button.cmd, button.definition = def.cmd, def
    local description = Theme.Text(row, "body", "textMuted")
    description:SetPoint("TOPLEFT", 0, -40); description:SetPoint("TOPRIGHT", -12, -40)
    description:SetJustifyH("LEFT"); description:SetWordWrap(true); description:SetText(def.desc)
    button.row, button.description = row, description
    button:SetScript("OnClick", function()
      if not ns.Modules.Require(owner) then return end
      if def.kind ~= "open" and not (def.cmd == "bg test" and ns.PreviewTests.Active(def.cmd)) then
        local allowed, problem = Allowed()
        if not allowed then ns.Util.Say(problem); return end
      end
      if def.run then def.run()
      else SlashCmdList.HIGHGROUND(def.cmd) end
      O.RefreshPreviews()
    end)
    Kit.Tooltip(button, { def.cmd and ("/hg " .. def.cmd) or def.label,
      { def.kind == "open" and "Opens the real tool." or def.kind == "action" and "Requires an active sample."
        or "Click Start to preview, then Stop to finish. Sample data follows your current settings.", "textMuted", true } },
      { anchor = "ANCHOR_RIGHT" })
    page.previews[#page.previews + 1] = button
  end
  for _, def in ipairs(ns.CommandCatalog.previews) do
    if def.module == owner and ns.OptionAvailable(def) and def.cmd ~= "bounty test" then Add(def) end
  end
  if owner == "battlegrounds" then
    Add({ label = "Objectives and flags", desc = "Resurrection waves, objectives, flag carriers and quick call panels.",
      active = function() return ns.Timers.previewing end,
      run = function()
        if ns.Timers.previewing then ns.BattlegroundsPreview.Stop() else ns.BattlegroundsPreview.Start() end
      end })
  elseif owner == "bounties" then
    for _, scene in ipairs(ns.Bounty.Preview.scenes) do
      Add({ label = scene.label, desc = scene.description, cmd = "bounty test " .. scene.key,
        active = function() return ns.Bounty.Preview.testing and ns.Bounty.Preview.scene and ns.Bounty.Preview.scene.key == scene.key end,
        run = function()
          local D = ns.Bounty.Preview
          D.Command(D.testing and D.scene and D.scene.key == scene.key and "stop" or scene.key)
        end })
    end
    page.stop = O.Link(page, "Stop bounty previews", function() ns.Bounty.Preview.Command("stop"); O.RefreshPreviews() end)
  elseif owner == "reputation" then
    Add({ label = "Player reputation", desc = "Open your real reports, organizations and moderation tools.", kind = "open", cmd = "reputation" })
  end
  local top = page.y
  function page.RefreshPreviews()
    local allowed = Allowed()
    local y = top
    for _, button in ipairs(page.previews) do
      local def = button.definition
      local isActive = def.active and def.active() or ns.PreviewTests.Active(def.cmd)
      local label = def.kind == "open" and "Open " or def.kind == "action" and "Try " or isActive and "Stop " or "Start "
      button:SetText(label .. def.label)
      button:SetEnabled(ns.Modules.Active(owner) and (def.kind == "open" or allowed or def.cmd == "bg test" and isActive)
        and (def.kind ~= "action" or Core.testMode or Core.sniperTest.on))
      button.row:SetPoint("TOPLEFT", 24, y); button.row:SetPoint("TOPRIGHT", -24, y)
      local height = 52 + math.max(32, button.description:GetStringHeight())
      button.row:SetHeight(height); y = y - height - 12
    end
    if page.arrange then page.arrange:SetEnabled(allowed) end
    if page.stop then page.stop:SetEnabled(ns.Bounty.Preview.testing == true) end
    page.child:SetHeight(-y + 16)
  end
  page.frame:HookScript("OnShow", page.RefreshPreviews)
  page.child:HookScript("OnSizeChanged", function()
    if not page.layingOut then page.layingOut = true; page.RefreshPreviews(); page.layingOut = nil end
  end)
  Core.OnFontScaleChange(function() if page.frame:IsVisible() then page.RefreshPreviews() end end)
  page.RefreshPreviews()
end

for _, module in ipairs(ns.Modules.list) do
  local page = O.MakePage(O.addonPages[module.key].previews)
  page.build = function() Build(page, module.key) end
  pages[#pages + 1] = page
end
function O.RefreshPreviews()
  if O.AppearancePreview then O.AppearancePreview.Refresh() end
  for _, page in ipairs(pages) do
    if page.frame:IsVisible() and page.RefreshPreviews then page.RefreshPreviews() end
  end
end
ns.Util.Events({ PLAYER_REGEN_DISABLED = O.RefreshPreviews, PLAYER_REGEN_ENABLED = O.RefreshPreviews,
  PLAYER_ENTERING_WORLD = O.RefreshPreviews }, "preview controls")
