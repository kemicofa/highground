local t = dofile("../../tools/harness.lua")("command catalog")
local compare = t.equal
function t.equal(a, b, why) return compare(a, b, why or "values match") end
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local F = dofile("tests/modules/fixture.lua")
local function make(client, disabled)
  return new(client == "cata" and "cata" or "retail", {}, function(s, env)
    F.configure(disabled)(s, env)
    if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
  end)
end
local function click(button) assert(button:IsEnabled(), "enabled control"); button.scripts.OnClick(button) end
local function fire(frame, event)
  if frame.scripts[event] then frame.scripts[event](frame) end
  for _, hook in ipairs(frame.hooks[event] or {}) do hook(frame) end
end
local function control(s, id, owner)
  local key = owner and owner .. "-commands" or "tools"
  s.ns.Hub.Open(key)
  for _, item in ipairs(s.ns.Options.byKey[key].commandRows) do if item.definition.id == id then return item.button end end
  error("No UI for " .. id)
end
local function surface(C, command)
  if C.byCommand[command] then return true end
  for _, row in ipairs(C.commands) do
    if row.command and command:sub(1, #row.command + 1) == row.command .. " " then
      local words, all = {}, true
      for word in (row.usage or ""):gmatch("[a-z]+") do words[word] = true end
      for word in command:sub(#row.command + 2):gmatch("%S+") do if not words[word] then all = false end end
      if all then return true end
    end
  end
  return false
end
-- Inspect loaded functions rather than assuming where their implementation lives.
local function literals(C, handler, prefix, variables)
  local info = debug.getinfo(handler, "S")
  local file = assert(io.open(info.source:sub(2)))
  local body, index = {}, 0
  for line in file:lines() do
    index = index + 1
    if index >= info.linedefined and index <= info.lastlinedefined then body[#body + 1] = line end
  end
  file:close()
  for variable, value in table.concat(body, "\n"):gmatch('(%w+)%s*==%s*"([^"\n]+)"') do
    if variables[variable] then assert(surface(C, prefix .. " " .. value), "Missing command/UI variant: " .. prefix .. " " .. value) end
  end
end
for _, client in ipairs({ "cata", "retail", "forever" }) do
  t.test(client .. " loaded handlers and subcommands have owned catalog entries and UI", function()
    local s, heads = make(client), {}
    local C = s.ns.CommandCatalog
    for _, row in ipairs(C.commands) do
      if row.command then
        local head = row.command:match("^%S+")
        if head then heads[head] = true; assert(s.ns.Commands[head], "Removed handler: " .. head) end
        for _, alias in ipairs(row.aliases or {}) do
          local verb = alias:match("^%S+"); heads[verb] = true; assert(s.ns.Commands[verb], "Removed alias: " .. alias)
        end
        assert(row.ui and row.ui.label and (row.ui.page or row.ui.tool or row.ui.command ~= nil), "Missing UI: " .. row.command)
        if row.owner ~= "shared" then t.equal(C.Owner(row.command), row.owner, "dispatch owner") end
      end
    end
    for verb, handler in pairs(s.ns.Commands) do
      assert(heads[verb], "Undocumented handler: " .. verb)
      literals(C, handler, verb == "options" and "config" or verb == "checklist" and "guide" or verb, { arg = true, sub = true })
    end
    literals(C, s.ns.Reputation.Command, "reputation", { command = true })
    literals(C, s.ns.Bounty.Public.Command, "bounty shared", { action = true })
    literals(C, s.ns.PressureCommand, "pressure", { sub = true })
    literals(C, s.ns.Commands.enemy, "enemy", { key = true })
    for verb in pairs(s.ns.Bounty.Messages.done) do assert(surface(C, "bounty " .. verb), "Missing bounty action: " .. verb) end
    for mode in pairs(s.ns.Macros.Window.MODES) do assert(surface(C, "macros " .. mode), "Missing macro mode: " .. mode) end
    t.equal(C.Owner("guide users"), nil, "shared guide remains shared")
    t.equal(C.Owner("guide bounty_hunt"), "bounties", "specific guide owner")
    t.equal(C.Owner("cap invalid"), "battlegrounds", "invalid args cannot bypass owner")
    s:assertHealthy()
  end)
  t.test(client .. " battleground guide commands and controls reach the same grouped walkthroughs", function()
    local s = make(client)
    local O, C, catalog = s.ns.Onboarding, s.ns.Onboarding.Coach, s.ns.CommandCatalog
    for _, owner in ipairs({ "battlegrounds", false }) do
      click(control(s, "guide battlegrounds", owner))
      assert(O.PathGroup().key == "battlegrounds" and not C.running)
      for _, key in ipairs({ "enemies", "objectives" }) do
        click(control(s, "guide " .. key, owner))
        t.equal(C.key, key); C.Go(2); O.Return()
        for _, command in ipairs(catalog.byId["guide " .. key].aliases) do
          t.equal(catalog.Owner(command), "battlegrounds")
          s:command(command); t.equal(C.key, key); t.equal(C.index, 2); O.Return()
        end
      end
    end
    s:command("checklist battlegrounds")
    assert(O.PathGroup().key == "battlegrounds" and not C.running)
    s:setCombat(true); s:command("guide objectives")
    assert(not C.running and not s.ns.Setup.placement, "commands keep the guide's combat guard")
    s:assertHealthy()
    local off = make(client, { battlegrounds = true })
    for _, command in ipairs({ "guide battlegrounds", "checklist battlegrounds", "guide enemies", "guide targeting", "checklist enemies", "checklist targeting", "guide objectives", "checklist objectives" }) do
      off:command(command)
      t.equal(off.ns.Hub.current, "module-battlegrounds", "every route directs disabled modules to their settings")
      assert(not off.ns.Onboarding.Coach.running and not off.ns.Core.testMode)
    end
    off:assertHealthy()
  end)
  t.test(client .. " local and global pages share definitions, controls and destinations", function()
    local s = make(client)
    local C, O, H = s.ns.CommandCatalog, s.ns.Options, s.ns.Hub
    assert(O.tools.build and not O.tools.commandRows, "controls are lazy")
    H.Open("tools")
    local combined = {}
    for _, item in ipairs(O.tools.commandRows) do combined[item.definition] = true end
    for i, module in ipairs(s.ns.Modules.list) do
      H.Open(module.key .. "-commands")
      t.equal(module.commands, C.groups[i + 1].commands, "module exposes definitions")
      for _, item in ipairs(O.byKey[module.key .. "-commands"].commandRows) do
        assert(combined[item.definition], "global includes local row")
        t.equal(item.definition.owner, module.key, "local ownership")
      end
    end
    local dispatch, recorded = s.env.SlashCmdList.HIGHGROUND, {}
    local windows = {
      macros = function() return s.ns.Macros.Window.win end,
      reputation = function() return s.ns.Reputation.UI.window end,
      bountyboard = function() return s.ns.Bounty.Board.win end,
      journal = function() return s.ns.EnemyJournal.win end,
      activity = function() return s.ns.WorldActivity.win end,
      history = function() return s.ns.MatchHistory.win end,
      healers = function() return s.ns.TeamHealers.win end,
    }
    s.env.SlashCmdList.HIGHGROUND = function(message) recorded[#recorded + 1] = message end
    H.Open("tools"); t.equal(#recorded, 0, "browsing cannot execute an action")
    for _, item in ipairs(O.tools.commandRows) do
      local row, values = item.definition, {}
      H.Open("tools")
      local count = #recorded
      for _, target in ipairs({ item.frame, item.button }) do
        fire(target, "OnEnter")
        local tip = table.concat(s.env.GameTooltip.lines, "\n")
        -- Pipes are doubled so the tooltip shows them instead of reading escapes.
        assert(tip:find((row[1]:gsub("|", "||")), 1, true) and tip:find(row[2], 1, true), "hover retains full syntax and description")
        assert(tip:find(row.ui.label, 1, true), "short action label has its full purpose on hover")
        for _, alias in ipairs(row.aliases or {}) do assert(tip:find("/hg " .. alias, 1, true), "aliases remain discoverable") end
        fire(target, "OnLeave"); assert(not s.env.GameTooltip:IsShown(), "tooltip closes on leave")
      end
      t.equal(#recorded, count, "hover does not execute commands")
      click(item.button)
      if row.ui.tool then
        local window = assert(windows[row.ui.tool]())
        assert(window:IsVisible() and not H.win:IsVisible(), "command control opens the separate tool")
        t.equal(window:GetParent(), s.env.UIParent, "command control never embeds the tool")
        t.equal(H.current, "tools", "tool launch preserves configuration navigation")
      elseif row.ui.page then
        t.equal(H.current, row.ui.page, "actual UI destination: " .. row.command)
        assert(H.activeFrame:IsVisible(), "destination renders")
      else
        for i, field in ipairs(row.fields or {}) do
          local choices = C.Choices(field)
          values[i] = field.default or choices and choices[1].key or ""
          local widget = choices and O.commandForm.fields[i].select or O.commandForm.fields[i].input
          assert(widget:IsVisible(), "labeled argument control renders")
        end
        if row.fields or row.confirm then assert(O.commandForm:IsVisible()); click(O.commandForm.apply) end
        t.equal(recorded[#recorded], assert(C.Format(row, values)), "exact dispatch: " .. row.command)
      end
    end
    s.env.SlashCmdList.HIGHGROUND = dispatch
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale); H.Open("tools")
      for _, page in pairs(O.byKey) do
        if page.commandRows then
          H.Open(page.key)
          local previous
          for _, item in ipairs(page.commandRows) do
            local code, desc, button, frame = s.bounds(item.code), s.bounds(item.description), s.bounds(item.button), s.bounds(item.frame)
            assert(frame[4] <= (scale == 1 and 32 or 40), "each command occupies one compact row")
            t.close(code[2] + code[4] / 2, button[2] + button[4] / 2, "syntax and action share one line")
            assert(code[1] + code[3] <= button[1] - 4, "syntax leaves room for the action")
            if item.description:IsShown() then
              t.close(desc[2] + desc[4] / 2, button[2] + button[4] / 2, "description stays on the same line")
              assert(code[1] + code[3] <= desc[1] - 4 and desc[1] + desc[3] <= button[1] - 4, "columns do not overlap")
            end
            assert(button[1] + button[3] <= frame[1] + frame[3] + 1, "action stays inside the row")
            assert(item.button.label:GetStringWidth() <= button[3] - 20, "compact action label fits")
            assert(not previous or frame[2] >= previous, "command rows do not overlap")
            previous = frame[2] + frame[4]
          end
          assert(page.child:GetHeight() < #page.commandRows * (scale == 1 and 36 or 44) + 350, "reference stays compact across all addons")
        end
      end
    end
    local frames = #s.frames
    for _ = 1, 3 do for _, module in ipairs(s.ns.Modules.list) do H.Open(module.key .. "-commands") end; H.Open("tools") end
    t.equal(#s.frames, frames, "widgets reused")
    s:assertHealthy()
  end)
end

t.test("real forms preserve validation, case and confirmation", function()
  local s = make("cata")
  local O, C, db = s.ns.Options, s.ns.CommandCatalog, s.ns.Core.db
  click(control(s, "pressure count", "battlegrounds")); local f = O.commandForm
  f.fields[1].input:SetText("2.5"); click(f.apply); assert(f:IsShown() and f.status:GetText() ~= "")
  f.fields[1].input:SetText("2"); click(f.apply); t.equal(db.pressureCount, 2)
  click(control(s, "call-channel", "battlegrounds")); f.fields[1].select:SetValue("party", true); click(f.apply); t.equal(db.callChannel, "party")
  click(control(s, "mark icon", "battlegrounds")); f.fields[1].select:SetValue("4", true); click(f.apply); t.equal(db.markIcon, 4)
  click(control(s, "points-value", "battlegrounds")); f.fields[1].select:SetValue("killPer", true); f.fields[2].input:SetText("7"); click(f.apply); t.equal(db.points.killPer, 7)
  click(control(s, "sniper sound", "battlegrounds")); f.fields[1].select:SetValue("1", true); click(f.apply); t.equal(db.sniperSound, 1)
  s:command("profile save Mixed Case")
  click(control(s, "export")); f.fields[1].input:SetText("Mixed Case"); click(f.apply); assert(not f:IsShown())
  local saved = O.Profiles.ParseString(O.Profiles.share:GetText())
  s.ns.Core.SetFeature("sniper", not saved.setup.features.sniper)
  click(control(s, "export")); f.fields[1].input:SetText(""); click(f.apply)
  local current = O.Profiles.ParseString(O.Profiles.share:GetText())
  t.equal(current.setup.features.sniper, db.sniper, "blank export uses current settings, including unsaved edits")
  db.errors = { example = { count = 1, first = "today" } }
  click(control(s, "clearerr")); assert(db.errors.example); click(f.cancel); assert(db.errors.example)
  click(control(s, "clearerr")); click(f.apply); assert(not db.errors or not db.errors.example)
  t.equal(C.Format(C.byId["points-value"], { "killPer", "4\nweight range 5" }), nil, "reject multiple lines")
  s:assertHealthy()
end)

t.test("diagnostic and bounty-tour controls start, stop and preserve live state", function()
  local s = make("cata")
  local O, B, db = s.ns.Options, s.ns.Bounty, s.ns.Core.db
  local guarded = s.ns.Util.RunGuarded
  click(control(s, "perf start")); assert(db.lastPerformance and db.lastPerformance.running)
  s:advance(2)
  click(control(s, "perf stop")); assert(not db.lastPerformance.running)
  t.equal(s.ns.Util.RunGuarded, guarded, "capture restores callbacks")
  click(control(s, "perf start")); s:advance(61)
  assert(not db.lastPerformance.running, "capture stops automatically")
  t.equal(s.ns.Util.RunGuarded, guarded, "automatic stop restores callbacks")
  click(control(s, "cap probe", "battlegrounds")); assert(db.capProbeOn)
  click(control(s, "cap probe", "battlegrounds")); assert(not db.capProbeOn)
  click(control(s, "bg profiler start", "battlegrounds")); assert(db.bgProfilerOn, "profiler waits for a battleground")
  click(control(s, "bg profiler stop", "battlegrounds")); assert(not db.bgProfilerOn and not db.bgProfiles, "nothing recorded")
  s:join()
  click(control(s, "bg profiler start", "battlegrounds")); assert(s.ns.Profiler.Recording(), "records inside")
  t.equal(#db.bgProfiles, 1, "one recording")
  click(control(s, "bg profiler stop", "battlegrounds")); assert(not s.ns.Profiler.Recording(), "stopped")
  t.equal(s.ns.Util.RunGuarded, guarded, "profiler restores callbacks")
  local offer = s.ns.Profiler.win
  assert(offer and offer:IsShown(), "reload offered")
  click(offer.reload); t.equal(s.reloads, 1, "the offer reloads")
  s:leave()
  local count, sent = #B.All(), #s.sent
  click(control(s, "bounty guide", "bounties"))
  O.commandForm.fields[1].select:SetValue("board", true); click(O.commandForm.apply)
  assert(B.Preview.scene and B.Preview.scene.key == "board", "named sample opens")
  click(control(s, "bounty guide", "bounties"))
  O.commandForm.fields[1].select:SetValue("stop", true); click(O.commandForm.apply)
  assert(not B.Preview.scene and not B.Preview.testing, "stop clears sample state")
  t.equal(#B.All(), count, "sample controls preserve live bounties")
  t.equal(#s.sent, sent, "sample controls send no messages")
  s:assertHealthy()
end)

t.test("disabled addons and client capabilities guard controls and dispatch", function()
  local s = make("retail", { battlegrounds = true, arena = true, nearby = true, bounties = true, reputation = true, macros = true })
  s.ns.Hub.Open("tools")
  for _, item in ipairs(s.ns.Options.tools.commandRows) do
    local row = item.definition
    assert(not row.cata and (not row.caps or s.ns.Caps[row.caps]), "client filtering")
    t.equal(item.button:IsEnabled(), row.owner == "shared", "module filtering")
    if row.owner ~= "shared" then
      s:command(row.command)
      t.equal(s.ns.Hub.activeFrame, s.ns.Hub.BuildModules(row.owner), "dispatch owner guard")
    end
  end
  assert(not s.ns.Core.testMode and not s.ns.Nearby.preview and not s.ns.Bounty.Preview.testing)
  s:assertHealthy()
end)
t.finish("Command catalog: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
