local _, ns = ...
local O, Kit, Core = ns.Options, ns.Kit, ns.Core

-- One owner for each settings page. Hub routing and Blizzard settings use
-- these same identities; the feature catalogs already identify switch owners.
O.addonPages = {}
local settings = { nearby = "nearby", bounties = "bounty", reputation = "reputation-settings" }
for i, module in ipairs(ns.Modules.list) do
  local owner = module.key
  local pages = { settings = settings[owner] or owner .. "-settings", previews = owner .. "-previews", commands = owner .. "-commands" }
  if owner ~= "macros" and owner ~= "reputation" then pages.appearance = owner .. "-appearance" end
  O.addonPages[owner] = pages
  for kind, key in pairs(pages) do
    if not ns.OptionsConfig.pages[key] then
      local nameKey = ({ commands = "highground.hub.commands.45e5f3", previews = "highground.hub.previews_and_guide.e53405", appearance = "highground.hub.appearance.41def7", settings = "highground.hub.settings.c7f73b" })[kind]
      local hintKey = ({ commands = "highground.addonpages.one_row_per_command_hover_for_full.c71835",
        previews = "highground.addonpages.try_sample_panels_or_follow_the_guide.f1f143",
        appearance = "highground.addonpages.adjust_this_addon_s_panels_shared_theme.44a6f1",
        settings = "highground.addonpages.choose_this_addon_s_features_and_preferences.c0f52a" })[kind]
      local moduleKey = ns.Localization.Key(module, "name")
      ns.OptionsConfig.pages[key] = ns.Localization.Define({ module = owner,
        order = 10 + i + (kind == "commands" and 0.3 or kind == "previews" and 0.2 or kind == "appearance" and 0.1 or 0),
        stepper = false }, { name = { key = "preferences.page.title", values = function()
          return { module = moduleKey and ns.Locale:Get(moduleKey) or module.name, section = ns.Locale:Get(nameKey) }
        end }, hint = hintKey })
    end
  end
end

function O.Link(page, text, action)
  local button = Kit.Button(page.child, text, 300, 32, { onClick = action })
  button:SetPoint("TOPLEFT", 24, page.y)
  button:SetPoint("TOPRIGHT", -24, page.y)
  page.y = page.y - 44
  page.child:SetHeight(-page.y + 12)
  return button
end

local tools = {
  history = { label = "tools.open.history", open = function() ns.MatchHistory.Open() end },
  journal = { label = "tools.open.journal", open = function() ns.EnemyJournal.Open() end },
  activity = { label = "tools.open.activity", open = function() ns.WorldActivity.Open() end },
  bountyboard = { label = "tools.open.bountyboard", open = function() ns.Bounty.Board.Open() end },
  reputation = { label = "tools.open.reputation", open = function() ns.Reputation.Open() end },
  macros = { label = "tools.open.macros", open = function() ns.Macros.Window.Open() end },
  healers = { label = "tools.open.healers", open = function() ns.TeamHealers.Open() end },
}
function O.ToolLabel(key) return ns.Locale:Get(tools[key].label) end
function O.BindToolLabel(button, key) ns.Localization.Bind(button, tools[key].label) end
function O.ToolOwner(key)
  local catalog = ns.CommandCatalog
  return catalog and catalog.owners[key == "bountyboard" and "bounty" or key]
end
function O.ToolAvailable(key) return ns.Modules.Active(O.ToolOwner(key)) end
function O.OpenTool(key)
  if not ns.Modules.Require(O.ToolOwner(key)) then return end
  return tools[key].open()
end
function O.ToolLink(page, key)
  local button = O.Link(page, O.ToolLabel(key), function() O.OpenTool(key) end)
  O.BindToolLabel(button, key)
  page.openTool = button
  local available = O.ToolAvailable(key)
  button:SetEnabled(available)
  Kit.Tooltip(button, function()
    local text = available and ns.Locale:Get("tools.window.help") or ns.Locale:Format("tools.window.unavailable",
      { addon = ns.Modules.byKey[O.ToolOwner(key)].name })
    return { { O.ToolLabel(key), "text" }, { text, "textMuted", true } }
  end, { anchor = "ANCHOR_RIGHT" })
  return button
end

-- Reuse Reputation's preference controls without creating its report browser.
local reputation = O.MakePage(O.addonPages.reputation.settings)
reputation.build = function()
  local W = ns.Reputation
  O.ToolLink(reputation, "reputation")
  local top = reputation.y
  local controls = { settingsBody = CreateFrame("Frame", nil, reputation.child) }
  reputation.preferences = controls
  controls.settingsBody:SetPoint("TOPLEFT", 24, top)
  W.UI.BuildSettings(controls)
  function reputation.RefreshBehavior()
    if reputation.refreshing or not W.ready then return end
    reputation.refreshing = true
    W.UI.RefreshSettings(controls, math.max(352, reputation.child:GetWidth() - 48))
    reputation.child:SetHeight(-top + controls.settingsBody:GetHeight() + 12)
    reputation.refreshing = nil
  end
  reputation.child:HookScript("OnSizeChanged", reputation.RefreshBehavior)
  Core.OnFontScaleChange(function() if reputation.frame:IsVisible() then reputation.RefreshBehavior() end end)
  W.Listen(function() if reputation.frame:IsVisible() then reputation.RefreshBehavior() end end)
end

-- Which teammates get the green healer cross: the Team healers window.
function O.AddTeamHealerControls(page)
  local K = { title = "highground.addonpages.team_healers.68a1c6",
    hint = "highground.addonpages.wow_forever_gives_every_teammate_the_damage.ed7763" }
  O.Section(page, ns.Locale:Get(K.title), ns.Locale:Get(K.hint), K.title, K.hint)
  local main = page.openTool
  page.teamHealers = O.ToolLink(page, "healers")
  page.openTool = main
end

-- The game's nameplate settings that markers depend on (ns.Nameplates). The
-- controls show the game's current values and lock in combat.
function O.AddNameplateControls(page)
  local N, S = ns.Nameplates, ns.Theme.Space
  if not N then return end
  local K = { title = "highground.addonpages.nameplates.24d6bb", hint = "highground.addonpages.healer_marks_and_target_markers_appear_only.66de4c",
    range = "highground.addonpages.nameplate_range.7faba9", limits = "highground.addonpages.min_to_max_yards_the_game_may.2934d3",
    combat = "highground.healermarks.leave_combat_to_change_nameplate_settings.8ac511" }
  O.Section(page, ns.Locale:Get(K.title), ns.Locale:Get(K.hint), K.title, K.hint)
  local R = N.RANGE
  local limits = { key = K.limits, values = { min = R.min, max = R.max } }
  local label = ns.Theme.Text(page.child, "body", "text")
  label:SetPoint("TOPLEFT", 24, page.y - 4); label:SetPoint("TOPRIGHT", -200, page.y - 4)
  label:SetJustifyH("LEFT"); label:SetWordWrap(false); ns.Localization.Bind(label, K.range)
  local range = O.Stepper(page.child, 60)
  range:SetPoint("TOPRIGHT", -24, page.y)
  page.nameplateRange = range
  page.y = page.y - 36
  local note = ns.Theme.Text(page.child, "body", "textMuted")
  note:SetPoint("TOPLEFT", 24, page.y); note:SetPoint("RIGHT", -24, 0); note:SetJustifyH("LEFT")
  page.nameplateNote = note
  page.y = page.y - 28
  local function Refresh()
    local combat = InCombatLockdown()
    local yards = N.Get("range")
    range.box:SetText(yards and string.format("%d", yards) or "")
    range.minus:SetEnabled(not combat and yards ~= nil and yards > R.min)
    range.plus:SetEnabled(not combat and yards ~= nil and yards < R.max)
    range.box:EnableMouse(not combat and yards ~= nil)
    ns.Localization.Bind(note, combat and K.combat or limits)
    for _, cb in ipairs(page.nameplateToggles) do
      local on = N.Get(cb.nameplate)
      cb:SetChecked(on == true, true)
      cb:SetEnabled(not combat and on ~= nil)
    end
  end
  local function Step(dir)
    local yards = N.Get("range")
    if yards then N.Set("range", yards + dir * (IsShiftKeyDown() and 5 or 1)) end
    Refresh()
  end
  range.minus:SetScript("OnClick", function() Step(-1) end)
  range.plus:SetScript("OnClick", function() Step(1) end)
  range.box:SetScript("OnEnterPressed", function(self)
    local yards = tonumber(self:GetText())
    if yards then N.Set("range", yards) end
    Refresh(); self:ClearFocus()
  end)
  range.box:SetScript("OnEscapePressed", function(self) Refresh(); self:ClearFocus() end)
  range.box:HookScript("OnEditFocusLost", Refresh)
  page.nameplateToggles = {}
  for _, def in ipairs({
    { "all", "highground.addonpages.always_show_nameplates.1bf017", "highground.addonpages.all_units_in_range_not_only_your.a5e1c3" },
    { "friends", "highground.addonpages.friendly_player_nameplates.2232c9", "highground.addonpages.green_healer_marks_need_them.c6bb04" },
  }) do
    local key, text, desc = def[1], def[2], def[3]
    local cb = O.Toggle(page.child, ns.Locale:Get(text), ns.Locale:Get(desc), function(_, on) N.Set(key, on); Refresh() end)
    ns.Localization.Bind(cb.label, text); ns.Localization.Bind(cb.note, desc)
    Kit.Tooltip(cb, function() return { ns.Locale:Get(text), ns.Locale:Get(desc) } end)
    cb:ClearAllPoints()
    cb:SetPoint("TOPLEFT", 24, page.y); cb:SetPoint("TOPRIGHT", -S("md"), page.y)
    cb.nameplate = key
    page.nameplateToggles[#page.nameplateToggles + 1] = cb
    page.y = page.y - 36
  end
  page.child:SetHeight(-page.y + 12)
  local refresh = page.RefreshBehavior
  page.RefreshBehavior = function()
    if refresh then refresh() end
    Refresh()
  end
  -- Combat, Highground commands and the game's own options change these.
  local function Visible() if page.frame:IsVisible() then Refresh() end end
  N.OnChange = Visible
  ns.Util.Events({ PLAYER_REGEN_ENABLED = Visible, PLAYER_REGEN_DISABLED = Visible, CVAR_UPDATE = Visible },
    "nameplate settings", "battlegrounds")
end

function O.AddAlertControls(page, owner)
  local definitions = {}
  for _, def in ipairs(ns.Alerts.categories) do
    if def.module == owner then definitions[#definitions + 1] = def end
  end
  if #definitions == 0 then return end
  local alertOffset = -page.y
  function page.ScrollToAlerts()
    -- Feature switches above this body grow with text size.
    local _, contentY = page.content:GetCenter()
    local _, bodyY = page.child:GetCenter()
    if not contentY or not bodyY then return end
    local offset = contentY + page.content:GetHeight() / 2 - bodyY - page.child:GetHeight() / 2 + alertOffset
    page.scroll:SetVerticalScroll(math.max(0, math.min(offset, page.content:GetHeight() - page.scroll:GetHeight())))
  end
  local titleY = page.y
  O.Section(page, ns.Locale:Get("highground.hub.alerts.d0efe0"), ns.Locale:Get("alerts.addon_hint"), "highground.hub.alerts.d0efe0", "alerts.addon_hint")
  -- Master sound mutes every Sound switch below; say so beside the title.
  page.alertNote = ns.Theme.Text(page.child, "body", "warning")
  page.alertNote:SetPoint("TOPLEFT", 160, titleY - 12); page.alertNote:SetPoint("TOPRIGHT", -24, titleY - 12)
  page.alertNote:SetJustifyH("RIGHT"); page.alertNote:SetWordWrap(false)
  page.alertRows = {}
  for _, def in ipairs(definitions) do
    local row = { key = def.key, def = def }
    local label = ns.Theme.Text(page.child, "body", "text")
    label:SetPoint("TOPLEFT", 24, page.y - 4); label:SetPoint("TOPRIGHT", -404, page.y - 4)
    label:SetJustifyH("LEFT"); label:SetWordWrap(true); ns.Localization.BindField(label, def, "label")
    for _, channel in ipairs({ "text", "sound" }) do
      row[channel] = Kit.Toggle(page.child, channel == "text" and ns.Locale:Get("highground.addonpages.text.c3328c") or ns.Locale:Get("highground.addonpages.sound.b4e3ef"), { width = channel == "text" and 90 or 104,
        onChange = function(_, on) ns.Alerts.SetChannel(def.key, channel, on) end })
      row[channel]:SetPoint("TOPRIGHT", channel == "text" and -294 or -174, page.y)
    end
    row.play = ns.Alerts.SoundButton(page.child, def)
    row.play:SetPoint("TOPRIGHT", -24, page.y)
    page.alertRows[#page.alertRows + 1] = row
    page.y = page.y - 44
  end
  -- Sound choices follow the switches, so a shortcut still lands on all of them.
  local heading
  for _, row in ipairs(page.alertRows) do
    if row.key == "lockon" or ns.Alerts.Choosable(row.key) then
      if not heading then
        heading = ns.Theme.Text(page.child, "body", "textMuted")
        heading:SetPoint("TOPLEFT", 24, page.y - 4); ns.Localization.Bind(heading, "alerts.sound.heading")
        page.y = page.y - 32
      end
      local key = row.key
      local title = ns.Theme.Text(page.child, "body", "text")
      title:SetPoint("TOPLEFT", 24, page.y - 4); title:SetPoint("TOPRIGHT", -294, page.y - 4)
      title:SetJustifyH("LEFT"); title:SetWordWrap(true)
      ns.Localization.BindField(title, row.def, "label")
      -- Choosing plays the new sound once, like /hg alerts sound.
      row.cue = Kit.Select(page.child, { width = 260, menu = true, choices = ns.Alerts.SoundChoices(key),
        onChange = function(_, value) if ns.Alerts.SetSound(key, value) then ns.Alerts.Play(key) end end })
      row.cue:SetPoint("TOPRIGHT", -24, page.y)
      page.y = page.y - 44
    end
  end
  O.Link(page, ns.Locale:Get("alerts.presets_link"), function() ns.Hub.Open("alerts") end)
  local refresh = page.RefreshBehavior
  page.RefreshBehavior = function()
    if refresh then refresh() end
    local sounds = Core.On("sound")
    page.alertNote:SetText(sounds and "" or ns.Locale:Get("alerts.master_off"))
    for _, row in ipairs(page.alertRows) do
      row.text:SetChecked(ns.Alerts.ChannelOn(row.key, "text"), true)
      row.sound:SetChecked(ns.Alerts.ChannelOn(row.key, "sound"), true)
      row.sound:SetEnabled(sounds)
      if row.cue then
        row.cue:SetChoices(ns.Alerts.SoundChoices(row.key)); row.cue:SetValue(ns.Alerts.Sound(row.key), true)
      end
    end
  end
end
