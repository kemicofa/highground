local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(b) assert(b:IsVisible() and b:IsEnabled(), "visible enabled action"); b:Click() end
local function open(s, addon) return s.ns.Options.ShowProfiles(addon), s.ns.CharacterSettings, s.ns.Core end
local function row(p, name)
  for _, r in ipairs(p.rows) do if r:IsShown() and r.item.name == name and r.item.kind ~= "self" then return r end end
end
-- Imports named after senders, holding this character's current settings.
local function keep(s, ...)
  local CS = s.ns.CharacterSettings
  local code = CS.Export("battlegrounds")
  for _, name in ipairs({ ... }) do assert(CS.Import(code, name)) end
end
local function imported(s, name, addon)
  for _, item in ipairs(s.ns.CharacterSettings.Profiles(addon or "battlegrounds")) do
    if item.kind == "import" and item.name == name then return item end
  end
end

for _, client in ipairs({ "cata", "retail", "forever" }) do
  local function make(saved, geometry)
    return new(client == "cata" and "cata" or "retail", saved or {}, function(s, env)
      if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
      if geometry then dofile("../../tools/wowsim/geometry.lua")(s) end
    end)
  end

  test(client .. " Profiles controls fit both font scales and themes", function()
    local s = make({}, true)
    keep(s, "Healer with a longer name", "Spare")
    local p, _, C = open(s)
    -- WoW Forever has no arenas, so no Arena choice.
    equal(p.addons.byKey.arena == nil, client == "forever", "Arena only where the game has arenas")
    local function below(a, b) local x, y = s.bounds(a), s.bounds(b); assert(x[2] + x[4] <= y[2] + 1, "vertical controls do not overlap") end
    local function left(a, b) local x, y = s.bounds(a), s.bounds(b); assert(x[1] + x[3] <= y[1] + 1, "columns do not overlap") end
    local function fits(b, why) assert(b.label:GetStringWidth() <= b:GetWidth() - 12, why .. " label fits") end
    for _, scale in ipairs({ 1, 1.5 }) do for _, theme in ipairs({ "highground", "parchment" }) do
      s.ns.Theme.Use(theme); C.SetFontScale(scale); s:advance(1); p.RefreshProfiles()
      below(p.hint, p.addons); below(p.addons, p.list); below(p.list, p.status); below(p.status, p.footer)
      assert(p.list:GetHeight() > 60, "the list remains usable at large text")
      for _, button in ipairs({ p.export, p.import, p.chat }) do fits(button, "footer") end
      local r = row(p, "Healer with a longer name")
      left(r.name, r.copy); left(r.copy, r.delete); fits(r.copy, "copy"); fits(r.delete, "delete")
      click(r.copy)
      assert(r.copy:IsArmed() and r.copy:GetText() == "Replace Battlegrounds settings?", "the first click asks to confirm")
      left(r.name, r.copy); left(r.copy, r.delete); fits(r.copy, "armed copy")
      r.copy:Disarm()
      s:assertHealthy()
    end end
  end)

  test(client .. " deleting a profile needs a second click and never deletes another one", function()
    local s = make()
    keep(s, "Spare", "Other")
    local p = open(s)
    equal(p.items[1].kind, "self"); assert(not p.rows[1].delete:IsShown(), "this character cannot be deleted")
    local delete = row(p, "Spare").delete
    click(delete)
    assert(delete:IsArmed() and delete:GetText() == "Click again to delete", "the first click asks for confirmation")
    assert(imported(s, "Spare"), "nothing is deleted yet")
    s:advance(5.1)
    assert(not delete:IsArmed() and delete:GetText() == "Delete", "an unanswered confirmation times out")
    assert(imported(s, "Spare"), "without deleting")
    click(delete); click(delete)
    assert(not imported(s, "Spare") and imported(s, "Other"), "the second click deletes only that profile")
    assert(p.status:GetText():find("Deleted Spare", 1, true), "deletion is reported")
    -- A command removing the armed profile moves the next one into its row:
    -- the next click must not delete it.
    keep(s, "Spare", "Zed"); p = open(s)
    local armed = row(p, "Spare")
    click(armed.delete); assert(armed.delete:IsArmed(), "armed on Spare")
    s:command("profile delete Spare")
    equal(armed.item.name, "Zed", "the next profile moved into the row")
    assert(not armed.delete:IsArmed(), "losing the armed profile cancels the confirmation")
    click(armed.delete)
    assert(imported(s, "Zed") and not imported(s, "Spare"), "one click never deletes the new occupant")
    s:assertHealthy()
  end)

  test(client .. " export and import windows fit larger text and share this character's settings", function()
    local s = make({}, true)
    local P, CS, C = s.ns.Options.Profiles, s.ns.CharacterSettings, s.ns.Core
    local function left(a, b) local x, y = s.bounds(a), s.bounds(b); assert(x[1] + x[3] <= y[1], "footer controls do not overlap") end
    local function fits(b)
      assert(b.label:GetStringWidth() <= b:GetWidth() - 12, string.format("action label fits: %s %.0f of %.0f",
        b.label:GetText(), b.label:GetStringWidth(), b:GetWidth()))
    end
    for _, scale in ipairs({ 1, 1.5 }) do
      C.SetFontScale(scale)
      local w = P.ShowExport("nearby")
      equal(w:GetText(), CS.Export("nearby"), "the window shows this character's code")
      local status, chat = s.bounds(w.status), s.bounds(w.actions.chat)
      left(w.done, w.actions.chat); fits(w.done); fits(w.actions.chat)
      assert(status[2] + status[4] <= chat[2], "the status stays above the actions")
      s.env.ChatFrame_OpenChat(""); click(w.actions.chat)
      local payload = assert(s.chatDraft:match("%[HGP:(.+)%]"), "Share in chat drafts a link")
      equal(P.Chat.Decode(payload).label, "Me · Nearby", "for the addon being exported")
      equal(#s.chat, 0, "sharing only prepares a draft")
      w:Hide()
      local i = P.ShowImport()
      left(i.done, i.actions.add); fits(i.done); fits(i.actions.add)
      assert(s.bounds(i.scroll)[4] > 32, "the paste box has room")
      i:Hide()
    end
    s:assertHealthy()
  end)
end

test("the Profiles guide walks the real page without copying, exporting or sending anything", function()
  local s = new("cata", {})
  keep(s, "Friend")
  local P, p = s.ns.Options.Profiles, s.ns.Options.panel
  local before = P.ExportString(P.Snapshot())
  local O, coach = s.ns.Onboarding, s.ns.Onboarding.Coach
  O.Start("profile")
  local targets = { own = p.hint, addons = p.addons, share = p.footer }
  for i, step in ipairs(coach.steps) do
    coach.Go(i); coach.Update()
    if step.id == "copy" then targets.copy = row(p, "Friend").copy end
    assert(targets[step.id], "known step " .. step.id)
    equal(coach.target, targets[step.id], step.id .. " points at the real control")
    assert(coach.target:IsVisible(), step.id .. " target is visible")
  end
  equal(P.ExportString(P.Snapshot()), before, "the guide applies nothing")
  equal(#s.chat, 0, "the guide sends nothing")
  assert(not s.chatDraft, "and drafts nothing")
  O.Return()
  equal(P.ExportString(P.Snapshot()), before, "returning keeps the live settings")
  s:assertHealthy()
end)

---------------------------------------------------------------------------
-- Profiles from older versions, kept as imports and copied.
---------------------------------------------------------------------------
local function copy(s, code)
  local CS = s.ns.CharacterSettings
  local ok, problem, index = CS.Import(code)
  assert(ok, problem)
  assert(CS.Copy({ import = index }, "battlegrounds"))
end

test("legacy callout channels are neither restored nor exported by copied profiles", function()
  local s = new("cata", { objectiveChannel = "s" })
  local C, P, CS = s.ns.Core, s.ns.Options.Profiles, s.ns.CharacterSettings
  C.SetFeature("quickCalls", true)
  local legacy = P.Snapshot()
  legacy.setup.preferences.objectiveChannel = "raid"
  C.db.objectiveChannel = "party"
  C.SetFeature("quickCalls", false)
  copy(s, P.ExportString(legacy, "Old battleground setup"))
  equal(C.db.quickCalls, true, "legacy imports retain Quick callouts")
  equal(C.db.objectiveChannel, "party", "retired setting is not restored")
  equal(P.Snapshot().setup.preferences.objectiveChannel, nil, "retired setting is no longer captured")
  equal(CS.Parse(CS.Export("battlegrounds")).addons.battlegrounds.bg10.setup.preferences.objectiveChannel, nil,
    "or exported")
  s:assertHealthy()
end)

test("obsolete alert text fields and tuning-only profiles still import and change only what they hold", function()
  local s = new("cata", {})
  local C, P, A = s.ns.Core, s.ns.Options.Profiles, s.ns.Alerts
  for _, key in ipairs({ "go", "lockon" }) do A.Settings().channels[key] = { text = false } end
  copy(s, P.ExportString(P.Snapshot(), "Unused text"))
  C.SetElement("hero", false)
  copy(s, "WB1;n=Old;o.executePct=0.15")
  equal(C.O("executePct"), 0.15, "the tuning it holds applies")
  equal(C.ShowsElement("hero"), false, "appearance it does not hold is kept")
  s:assertHealthy()
end)

test("older full profiles leave the feature switches they omit alone", function()
  local s = new("cata", {})
  local C, P = s.ns.Core, s.ns.Options.Profiles
  local older = P.Snapshot()
  older.setup.features.sniper = nil
  older.setup.features.flags = false
  C.SetFeature("sniper", false)
  copy(s, P.ExportString(older, "Older setup"))
  equal(C.db.sniper, false, "an omitted switch preserves the current setting")
  equal(C.db.flags, false, "an included switch applies")
  s:assertHealthy()
end)
