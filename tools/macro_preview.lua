-- Export running player-facing windows for the HTML preview tool.
-- Run from addons/Highground: luajit ../../tools/macro_preview.lua [theme] [scale] [state]
local sim = dofile("../../tools/wowsim/battleground/runtime.lua")("cata", nil, function(s, env)
  dofile("../../tools/wowsim/geometry.lua")(s)
  if arg[3] == "reputation" and arg[5] == "hub" then
    s.units.player.realm = "Realm"
    env.GetNormalizedRealmName = function() return "Realm" end
    env.GetGuildInfo = function() return "Silverwing Scouts", "Guild Master", 0 end
    s.guildRoster = { { s.units.player.name .. "-Realm", 0 }, { "SampleMember-Realm", 5 } }
    env.GetNumGuildMembers = function() return #s.guildRoster end
    env.GetGuildRosterInfo = function(i)
      local r = s.guildRoster[i]; return r[1], "Rank", r[2], nil, nil, nil, nil, nil, true
    end
  end
  if arg[3] == "addons" or arg[3] == "module" or arg[3] == "commands" or arg[3] == "guide" or arg[3] == "guide-window"
    or arg[3] == "guide-sample" and arg[4] == "addons" or arg[7] == "standalones" then
    local fixture, copies = dofile("tests/modules/fixture.lua"), {}
    if arg[7] == "standalones" then
      for _, name in ipairs(fixture.names) do copies["Highground" .. name] = true end
    end
    fixture.configure(nil, false, nil, copies)(s, env)
  end
  local methods = getmetatable(s.env.UIParent).__index
  methods.SetBackdropColor = function(f, ...) f.backdropColor = { ... } end
  methods.SetBackdropBorderColor = function(f, ...) f.backdropBorder = { ... } end
  methods.SetTexCoord = function(f, ...) f.texCoord = { ... } end
  methods.SetFrameStrata = function(f, value) f.strata = value end
  if arg[6] and arg[6] ~= "" then
    env.C_Map.GetMapArtLayers = function() return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end
    env.C_Map.GetMapArtLayerTextures = function()
      local tiles = {}; for i = 1, 12 do tiles[i] = "map-preview-tile:" .. i end; return tiles
    end
  end
end)
sim.ns.Theme.Use(arg[1] or "azeroth")
-- Use representative client class colours and names instead of the test defaults.
for class, hex in pairs({ WARRIOR = "c69b6d", PALADIN = "f48cba", HUNTER = "aad372", ROGUE = "fff468",
  PRIEST = "ffffff", DEATHKNIGHT = "c41e3a", SHAMAN = "0070dd", MAGE = "3fc7eb", WARLOCK = "8788ee",
  MONK = "00ff98", DRUID = "ff7c0a", DEMONHUNTER = "a330c9", EVOKER = "33937f" }) do
  local c = sim.ns.ThemeColor(hex)
  sim.env.RAID_CLASS_COLORS[class] = { r = c[1], g = c[2], b = c[3] }
  sim.env.LOCALIZED_CLASS_NAMES_MALE[class] = class:sub(1, 1) .. class:sub(2):lower()
end
sim.ns.Core.SetFontScale(tonumber(arg[2]) or 1)
sim:command("macros build")
local P, w = sim.ns.Macros.BuildPanel, sim.ns.Macros.Window.win
local p = P.frame
sim.known.Kick = true
if arg[3] ~= "empty" then
  p.spell:SetText("Kick")
  p.target:SetValue("focus")
  p.kind:SetValue("harm")
  for _, b in ipairs(p.toggles) do
    if b.value == "fallback" or b.value == "stopcast" then b.scripts.OnClick(b) end
  end
  p.name:SetText("Focus Kick")
end
if arg[3] == "presets" or arg[3] == "presets-code" or arg[3] == "hub-presets-code" then
  sim.ns.Macros.Window.SetTab("all"); w.search:SetText("Kick")
  if arg[3] ~= "presets" then w.showCode.scripts.OnClick(w.showCode) end
  if arg[3] == "hub-presets-code" then sim.ns.Hub.Open("macros"); sim.ns.Macros.Window.Refresh() end
end
if arg[3] == "expanded" then p.conditionsGroup.open = true end
if arg[3] == "target" then p.of.scripts.OnClick(p.of) end
if arg[3] == "manual" then
  P.Load({ name = "Focus Kick", body = "#showtooltip\n/cast [@focus] Kick", perCharacter = true })
end
if arg[3] == "hub" then sim.ns.Hub.Open("macros"); sim.ns.Macros.Window.Refresh() end
if arg[3] == "home" then w:Hide(); sim.ns.Hub.Open("home") end
if arg[3] == "addons" or arg[3] == "module" then
  w:Hide(); sim.ns.Hub.Open(arg[3] == "addons" and "addons" or "module-" .. (arg[4] ~= "" and arg[4] or "battlegrounds"))
end
if arg[3] == "commands" then
  w:Hide(); sim.ns.Hub.Open(arg[4] and arg[4] ~= "" and arg[4] .. "-commands" or "tools")
end
if arg[3] == "journal" or arg[3] == "journal-window" then
  local now = sim.env.time()
  for i, enemy in ipairs({
    { "Nightshade-Whitemane", "ROGUE", "Hillsbrad Foothills", "The Unseen", 12, 3, 2 },
    { "Ironclaw-Realm", "WARRIOR", "Arathi Highlands", "Red Horizon", 8, 4, 1 },
    { "Ashveil-Realm", "MAGE", "Hillsbrad Foothills", "", 5, 1, 1 },
    { "Moonfall-MoonGuard", "DRUID", "Ashenvale", "Wild Hunt", 3, 0, 1 },
    { "Grimspike-Realm", "WARLOCK", "Stranglethorn Vale", "", 2, 1, 0 },
    { "Thorn-Realm", "HUNTER", "Arathi Highlands", "Wayfarers", 1, 0, 0 },
    { "Sunbreaker-Realm", "PALADIN", "Hillsbrad Foothills", "", 2, 1, 1 },
  }) do
    sim.ns.NearbyHistory.All()[enemy[1]] = { class = enemy[2], zone = enemy[3], guild = enemy[4], level = 60,
      times = enemy[5], killedThem = enemy[6], killedMe = enemy[7], last = now - i * 120, first = now - i * 86400,
      muted = i == 3, note = i == 1 and "Waits near the bridge north of Tarren Mill.\nUsually opens from stealth; keep a trinket ready." or nil }
  end
end
local pages = { features = "general", alerts = "alerts", guide = "addons", setup = "setup",
  journal = "journal", bounties = "bountyboard" }
if pages[arg[3]] then w:Hide(); sim.ns.Hub.Open(pages[arg[3]]) end
if arg[3] == "guide-window" then w:Hide(); sim.ns.Onboarding.Open() end
if arg[3] == "addons" or arg[3] == "guide" or arg[3] == "guide-window" then
  sim.ns.Onboarding.Go(arg[4])
  if arg[5] == "pending" then
    local toggle = sim.ns.Onboarding.win.cards.bounties.addon
    toggle.scripts.OnClick(toggle)
  end
end
local extraWindow
if arg[3] == "reputation" then
  w:Hide()
  local R = sim.ns.Onboarding.Coach.ReputationSample
  local P, target
  if arg[5] == "hub" then
    P = sim.ns.Reputation
    P.Enable(sim.ns.Organizations.Guild().id); target = assert(P.Target("PracticePlayer-Example"))
  else
    R.Ensure(); P = R.provider
    R.data.moderator = true; P.Enable(); target = R.data.target
  end
  if arg[4] == "proposals" then P.Submit(P.Get(), target, { other = true }, "Example report awaiting review.")
  else P.Decide(P.Get(), target, "ban", { other = true }, "Reviewed example encounter.") end
  if R.data then R.data.moderator = arg[5] ~= "member" end
  if arg[5] == "off" then P.Disable() end
  extraWindow = P.Open()
  P.UI.SetMode(arg[4] ~= "" and arg[4] or "overview", P.Get().id)
  if arg[5] == "hub" then
    sim.ns.Hub.Open("reputation")
  end
end
local coach = arg[3] == "guide-sample"
if coach then
  w:Hide(); sim.ns.Onboarding.Start(arg[4] ~= "" and arg[4] or "map")
  if tonumber(arg[5]) then sim.ns.Onboarding.Coach.Go(tonumber(arg[5])) end
end
if arg[3] == "journal-window" then w:Hide(); extraWindow = sim.ns.EnemyJournal.Open() end
if arg[3] == "journal-bounty" or arg[3] == "journal-note" then
  w:Hide()
  sim.ns.NearbyHistory.All()["Nightshade-Whitemane"] = {
    class = "ROGUE", last = 10, first = 1, times = 3, killedMe = 0, killedThem = 0, note = "Seen near Tarren Mill" }
  sim.ns.Bounty.Add("Nightshade-Whitemane", 250, "Seen near Tarren Mill")
  local journal = sim.ns.EnemyJournal.Open()
  local action = journal.actions[arg[3] == "journal-bounty" and 3 or 1]
  action.scripts.OnClick(action)
end
local hud = arg[3] == "battleground" or arg[3] == "battleground-hero" or coach
if arg[3] == "battleground-hero" then sim.ns.Core.SetElement("hero", true) end
if hud and not coach then w:Hide(); sim.ns.Setup.BeginPlacement(); sim:advance(0.5) end
if arg[3] == "bounty-form" then
  w:Hide(); sim.ns.Bounty.Board.Open()
  extraWindow = sim.ns.Bounty.Form.Open("Nightshade-Whitemane", "public")
  extraWindow.gold:SetText("50")
  sim.ns.Bounty.Form.Step(extraWindow, tonumber(arg[5]) or 1)
end
if arg[3] == "bounty-gold" or arg[3] == "bounty-funding" then
  w:Hide()
  local B = sim.ns.Bounty
  sim.env.GetMoney = function() return 1256789 end
  B.Gold.Record()
  B.Public.db.gold.characters.sample = { name = "Coinkeeper-Realm", scope = B.Scope.Key(), balance = 8700012,
    seenAt = B.Public.Now() - 60, obligations = {} }
  if arg[3] == "bounty-gold" then extraWindow = B.GoldView.Open()
  else extraWindow = B.Form.Open("WantedPlayer-Realm", "public"); extraWindow.gold:SetText("1500") end
end
if arg[3] == "bounty-killed" or arg[3] == "bounty-hunt" or arg[3] == "bounty-export" then
  w:Hide()
  local B = sim.ns.Bounty
  local terms = { killsRequired = 3, killMethods = "fall.control.wand" }
  if arg[3] == "bounty-hunt" then
    extraWindow = B.Form.Open("Nightshade-Whitemane", "public")
    extraWindow.gold:SetText("1g"); B.TermsEditor.Set(extraWindow, terms)
    B.Form.Layout(extraWindow); extraWindow.fields:Scroll(extraWindow.fieldY[extraWindow.kills] - 38)
  elseif arg[3] == "bounty-export" then
    local offer = assert(B.Public.Post("Nightshade-Whitemane", 1, "2h", "Cliffside challenge", true, terms))
    extraWindow = B.Exchange.Show(offer, "global")
  else
    local _, b = B.Preview.Sample("kill")
    b.name = "Nightshade-Whitemane"
    sim.env.Screenshot = function() end -- preview renderer, never the game
    B.Proof.Show(b, "honor credit", B.Public.Now())
    sim:advance(0.3); sim:event("SCREENSHOT_SUCCEEDED")
    extraWindow = B.Proof.win
    extraWindow:ClearAllPoints(); extraWindow:SetPoint("CENTER", sim.env.UIParent, "CENTER", 0, 0)
  end
end
if arg[3] == "bounty-match" then
  w:Hide()
  local _, sample = sim.ns.Bounty.Preview.Sample("shared")
  sim.ns.Bounty.Matches.Show(sample, true)
  extraWindow = sim.ns.Bounty.Matches.previewWin
end
if arg[3] == "bounty-poster" then
  w:Hide()
  local B = sim.ns.Bounty
  B.Preview.row, B.Preview.bounty = B.Preview.Sample("nearby")
  B.Announce(B.Preview.bounty, "Tarren Mill", true)
  extraWindow = B.Poster.previewWin
  sim.ns.Motion.Stop(extraWindow, 1)
end
if arg[3]:match("^bounty%-tour") then
  w:Hide()
  local B, D = sim.ns.Bounty, sim.ns.Bounty.Preview
  extraWindow = D.Start(nil, arg[3] == "bounty-tour-kill" and "kill" or "nearby")
  if arg[3] == "bounty-tour-kill" then D.Capture("saved")
  elseif arg[3] == "bounty-tour-create" then D.Select("create"); extraWindow = D.OpenCreate()
  elseif arg[3] == "bounty-tour-gold" then D.Select("gold"); extraWindow = B.GoldView.Open(true)
  elseif arg[3] == "bounty-tour-share" then D.Select("exchange"); extraWindow = B.Exchange.PreviewShare(D.bounty, "global")
  elseif arg[3] == "bounty-tour-pot" then D.Select("pot"); extraWindow = B.Pot.Open(D.bounty.contributions[1], true) end
end
if arg[3] == "bounty-test" or arg[3] == "bounty-test-details" then
  w:Hide()
  local B = sim.ns.Bounty
  extraWindow = B.Preview.Command("board")
  if arg[3] == "bounty-test-details" then B.Preview.TestDetails(extraWindow.rows[1].entry) end
end
if ({ ["bounty-list"] = true, ["bounty-shared"] = true, ["bounty-details"] = true, ["bounty-claims"] = true })[arg[3]] then
  w:Hide(); sim.ns.Hub.Open("bountyboard")
  local B = sim.ns.Bounty
  if arg[3] == "bounty-list" then
    B.Add("Nightshade-Whitemane", 0, "Watch for this rogue near Tarren Mill")
    B.Add("Ironclaw-Realm", 250, "Seen at the crossroads")
    B.Add("Ashveil-Realm", 100, "")
  elseif arg[3] == "bounty-shared" then B.Board.SetTab("public")
  elseif arg[3] == "bounty-details" then
    sim.env.GetMoney = function() return 100000000 end
    sim.ns.Core.SetOption("bountyReceive", true)
    local offer = assert(B.Public.Post("Nightshade-Whitemane", 500, "2h", "Hunting near Tarren Mill", true))
    local other = B.Public.Copy(offer)
    other.id, other.contributor, other.by = "preview-other", "preview-account", "Huntmaster-Realm"
    other.gold, other.note = 250, "Report your killing blow for review"
    assert(B.Public.Merge(other, other.by))
    B.Board.SetTab("public"); B.Details.Open(B.BoardModel.Rows("public")[1])
  else B.Preview.claims = B.Preview.Claims(); extraWindow = B.Preview.OpenClaims() end
  B.Board.Refresh()
end
P.Layout()
if arg[3] == "completion" then
  p.code:SetFocus()
  p.code:SetText("#showtooltip\n/cast [@fo")
  local x, y, h = 62, -14, 14
  p.code.scripts.OnCursorChanged(p.code, x, y, 1, h)
  for _, hook in ipairs(p.code.hooks.OnCursorChanged) do hook(p.code, x, y, 1, h) end
end
local function quote(v)
  return '"' .. v:gsub('[%z\1-\31\\"]', function(c)
    return c == '"' and '\\"' or c == '\\' and '\\\\' or string.format('\\u%04x', c:byte())
  end) .. '"'
end
local function json(v)
  if type(v) == "string" then return quote(v) end
  if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
  if type(v) ~= "table" then return "null" end
  local out = {}
  if #v > 0 then for _, item in ipairs(v) do out[#out + 1] = json(item) end; return "[" .. table.concat(out, ",") .. "]" end
  for key, item in pairs(v) do out[#out + 1] = quote(key) .. ":" .. json(item) end
  return "{" .. table.concat(out, ",") .. "}"
end
local rows = {}
sim:advance(1) -- capture settled surfaces rather than a half-faded entrance
for _, f in ipairs(sim.frames) do
  local crest = f.texture == sim.ns.Core.CREST
  local guideLogo = type(f.texture) == "string" and f.texture:match("assets\\logos\\([%w]+)%.tga$")
  local check = f.texture == "Interface\\RaidFrame\\ReadyCheck-Ready"
  local sampleTile = type(f.texture) == "string" and f.texture:match("^map%-preview%-tile:(%d+)$")
  local samplePin = coach and f.parent and f.parent.item and f.parent.Refresh and f.parent.item.key
  local circle = samplePin and f.texture == "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
    or f.texture == sim.ns.Core.PROGRESS_CIRCLE
  local class = samplePin and f.atlas and f.atlas:match("^classicon%-(.+)$")
  local solid = f.texture == sim.ns.Core.WHITE
  if f:IsVisible() and (f.text or f.colorTexture or f.backdropColor or crest or guideLogo or check or sampleTile or circle or class or solid) then
    local ancestor, depth, clip, include, popup, alpha, coached, strata = f, 0, nil, false, false, 1, false, nil
    while ancestor do
      if sim.ns.Kit.Windows.entries[ancestor] then include = true end
      if ancestor == w or ancestor == sim.ns.Hub.win or ancestor == extraWindow then include = true end
      if coach and ancestor == sim.ns.Onboarding.Coach.root then include, coached = true, true end
      if coach and (ancestor == sim.ns.Bounty.Poster.previewWin or ancestor == sim.ns.Bounty.Matches.previewWin
        or ancestor == sim.ns.Bounty.Proof.previewWin) then include = true end
      if hud and (ancestor == sim.ns.Core.frame or ancestor == sim.ns.Setup.layoutBar
        or ancestor == sim.ns.Flags.flagWin or ancestor == sim.ns.Nearby.win or ancestor == sim.ns.Arena.win) then include = true end
      if hud then for _, timer in ipairs(sim.ns.Timers.timerWindows) do if ancestor == timer then include = true end end end
      if ancestor == sim.ns.Kit.Dropdown.Frame() then include, popup = true, true end
      strata = strata or ancestor.strata
      if ancestor.kind == "ScrollFrame" then clip = sim.bounds(ancestor) end
      alpha = alpha * (ancestor.alpha or 1)
      depth, ancestor = depth + 1, ancestor.parent
    end
    if include then
      local r = { kind = f.kind, bounds = sim.bounds(f), text = f.kind == "FontString" or f.kind == "EditBox" and f.text and f.text or nil,
        color = f.colorTexture or f.backdropColor or solid and f.vertexColor, ink = f.textColor, border = f.backdropBorder, rotation = f.rotation,
        font = f.font, align = f.justifyH, wrap = f.wordWrap, valign = f.justifyV, depth = depth, layer = f.layer, clip = clip, popup = popup, alpha = alpha,
        gradient = f.gradient, crest = crest, guideLogo = guideLogo, check = check, coached = coached,
        sampleTile = sampleTile, texCoord = f.texCoord, circle = circle, vertex = f.vertexColor, class = class,
        scale = sim.geometryScale(f), strata = strata }
      if f.kind == "FontString" then r.text = f.text end
      rows[#rows + 1] = r
    end
  end
end
print(json({ frames = rows, window = sim.bounds(w), theme = sim.ns.Theme.Current() }))
