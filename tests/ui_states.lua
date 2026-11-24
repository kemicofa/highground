-- The shared state contracts must work in every packaged UI and client.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " UI states")
  local F = dofile("tests/bounties/public/fixture.lua")
  local battlegrounds = addon == "Highground"
  local runtime = dofile("../../tools/wowsim/" .. (battlegrounds and "battleground/" or "") .. "runtime.lua")
  local function new(client, build, options)
    options = options or {}
    options.addon, options.client, options.build, options.runtime = addon, client, build, runtime
    return F.new("Tester", options)
  end
  local function click(button) button.scripts.OnClick(button, "LeftButton") end

  for _, case in ipairs({ { "retail", 120100 }, { "retail", 16001 }, { "cata", 40402 } }) do
    local label = tostring(case[2])
    t.test(label .. ": unavailable, empty and filtered browsers recover without stale actions or error colors", function()
      local s, entries, facts, reads = new(unpack(case)), {}, { loading = true }, 0
      local K = s.ns.Kit
      local w = K.Browser(nil, { title = "States", empty = "No saved records.", state = function() return facts end,
        data = function() reads = reads + 1; return entries end,
        actions = { { label = "Apply", run = function() return false, "Rejected" end } } })
      w:Open()
      t.equal(w.viewState.kind, "loading", "loading is explicit")
      t.equal(reads, 0, "unready data provider is not called")
      assert(not w.actions[1]:IsEnabled() and not w.rows[1]:IsShown())
      facts = {}; w:Refresh()
      t.equal(w.detail:GetText(), "No saved records.", "empty feature guidance")
      w.search:SetText("missing")
      t.equal(w.viewState.kind, "filtered", "filter mismatch differs from empty store")
      t.equal(w.status:GetText(), "No matches", "matching footer")
      facts = { unavailable = "Membership unavailable", loading = true, error = "Refresh failed" }
      w:Refresh()
      t.equal(w.viewState.kind, "error", "failure wins over loading and filter")
      t.equal(w.detail:GetText(), "Refresh failed", "actual error is visible")
      t.equal(w.status.wbToken, "danger", "error tone")
      facts.error = nil; w:Refresh()
      t.equal(w.viewState.kind, "unavailable", "availability wins over loading")
      facts = { disabled = "Enable this feature" }; w:Refresh()
      t.equal(w.viewState.kind, "disabled", "disabled is explicit")
      facts = {}; entries = { { key = 1, title = "Record", detail = "Live details" } }
      w.search:SetText(""); w:Refresh()
      t.equal(w.viewState.kind, "ready", "recovery")
      assert(w.rows[1]:IsShown() and w.actions[1]:IsEnabled())
      t.equal(w.status.wbToken, "textMuted", "recovery clears error tone")
      click(w.actions[1]); t.equal(w.status.wbToken, "danger", "action failure shown")
      w:Refresh(); t.equal(w.status.wbToken, "textMuted", "normal refresh clears action error tone")
      facts.loading = true; w:Refresh()
      assert(w.entry == nil and w.rows[1].entry == nil and not w.actions[1]:IsEnabled(), "unavailable rows cannot stay selected")
      assert(facts.count == nil, "refresh does not mutate provider facts")
      s:assertHealthy()
    end)

    t.test(label .. ": action invocation checks current selection and permissions even for always actions", function()
      local s, calls, allowed, blocked = new(unpack(case)), 0, true, false
      local entries = { { key = 1, title = "First" }, { key = 2, title = "Second" } }
      local w = s.ns.Kit.Browser(nil, { title = "Actions", data = function() return entries end,
        state = function() return { unavailable = blocked } end,
        actions = {
          { label = "Apply", run = function() calls = calls + 1 end },
          { label = "Import", always = true, enabled = function() return allowed end, run = function() calls = calls + 1 end },
          { label = "Delete", run = function(e)
            entries = {}
            return true, "Removed", function() entries = { e } end
          end },
        } })
      w:Open()
      table.remove(entries, 1)
      click(w.actions[1])
      t.equal(calls, 0, "deleted selection does not apply action to its replacement")
      allowed = false
      click(w.actions[2])
      t.equal(calls, 0, "permissions are checked again on invocation")
      assert(not w.actions[2]:IsEnabled(), "always does not bypass enabled predicate")
      entries = {}; allowed = true; w:Refresh(); click(w.actions[2])
      t.equal(calls, 1, "always still supports actions without a selection")
      entries = { { key = 3, title = "Undoable" } }; w:Refresh(); click(w.actions[3])
      blocked = true; click(w.undo)
      assert(w.undoAction and not w.undo:IsEnabled(), "unavailable data also blocks undo")
      t.equal(#entries, 0, "blocked undo cannot mutate data")
      blocked = false; w:Refresh(); click(w.undo)
      t.equal(entries[1].key, 3, "undo remains available after recovery")
      s:assertHealthy()
    end)

    t.test(label .. ": changing, disabled or hidden dropdown owners cannot accept stale menu values", function()
      local s, changes = new(unpack(case)), 0
      local K = s.ns.Kit
      local selector = K.Select(s.env.UIParent, { menu = true, choices = { { key = "a", label = "Alpha" } },
        onChange = function() changes = changes + 1 end })
      click(selector)
      selector:SetChoices({ { key = "a", label = "Alpha" } })
      assert(K.Dropdown.IsShown(), "unchanged refresh retains open menu")
      selector:SetChoices({ { key = "a", label = "Renamed" }, { key = "b", label = "Beta" } })
      t.equal(selector:GetText(), "Renamed", "selected label refreshes")
      assert(not K.Dropdown.IsShown(), "changed choices retire menu snapshot")
      click(selector); selector.choices[1].label = "Renamed again"
      selector:SetChoices(selector.choices)
      assert(not K.Dropdown.IsShown(), "in-place choice edits also retire the old menu")
      t.equal(selector:GetText(), "Renamed again", "in-place label refreshes")
      click(selector); selector:Disable()
      assert(not K.Dropdown.Accept(2), "disable after opening blocks acceptance")
      t.equal(changes, 0, "disabled menu cannot invoke onChange")
      selector:Enable(); click(selector); selector:Hide()
      assert(not K.Dropdown.Accept(2), "hidden owner cannot accept a choice")
      selector:Show(); click(selector); selector:SetChoices({})
      assert(not K.Dropdown.IsShown() and selector:GetValue() == nil, "empty options retire selection")
      t.equal(selector:GetText(), "No choices available", "empty options are explained")
      selector:SetChoices({ { key = false, label = "Off" }, { key = true, label = "On" } })
      t.equal(selector:GetValue(), false, "false remains a valid choice")
      assert(selector:SetValue(true)); t.equal(changes, 1, "recovered choices work")
      local input = K.Input(s.env.UIParent, 200, "Complete")
      K.Dropdown.Attach(input, function() return "", { { text = "Choice" } } end)
      input:SetFocus(); assert(K.Dropdown.IsShown(), "visible input offers completion")
      input:Hide(); K.Dropdown.Update(input)
      assert(not K.Dropdown.IsShown() and not K.Dropdown.Accept(), "hidden input retires completion")
      s:assertHealthy()
    end)

    t.test(label .. ": toggle native enabled state, feedback and theme dimming stay synchronized", function()
      local s, changes = new(unpack(case)), 0
      local K, T = s.ns.Kit, s.ns.Theme
      local toggle = K.Toggle(s.env.UIParent, "Option", { checked = true, onChange = function() changes = changes + 1 end })
      toggle.scripts.OnEnter(toggle); toggle.scripts.OnMouseDown(toggle)
      toggle:Disable(); click(toggle)
      assert(not toggle:IsEnabled() and not toggle.enabled and toggle:GetChecked(), "direct disable blocks toggling")
      assert(not toggle.hover:IsShown() and not toggle.pressed:IsShown(), "disable clears interaction feedback")
      toggle:SetAlpha(1); T.Repaint()
      t.equal(toggle:GetAlpha(), T.Alpha("disabled"), "disabled opacity follows theme repaint")
      toggle:Enable(); click(toggle)
      assert(toggle:IsEnabled() and not toggle:GetChecked(), "direct enable restores interaction")
      t.equal(changes, 1, "only enabled click changes value")
      s:assertHealthy()
    end)

    do
      t.test(label .. ": unavailable claim storage never presents an empty payment ledger", function()
        local database = { version = 99, futureData = "preserve" }
        local s = new(case[1], case[2], { network = database })
        local B = s.ns.Bounty
        B.Ledger.Open()
        local w = B.Ledger.win
        t.equal(w.viewState.kind, "error", "storage failure exposed")
        assert(w.detail:GetText():find("newer addon version", 1, true), "storage recovery guidance")
        assert(not w.empty:IsShown() and w.detailScroll:IsShown(), "error replaces empty ledger introduction")
        for _, action in ipairs(w.actions) do assert(not action:IsEnabled(), "unloaded claims cannot be changed") end
        w:Hide(); B.Board.Open(); B.Board.SetTab("public")
        local board = B.Board.win
        t.equal(board.guide.title:GetText(), "Shared bounties unavailable", "shared board explains the storage failure")
        assert(board.empty:GetText():find("newer addon version", 1, true), "shared board gives recovery guidance")
        assert(not board.browse:IsShown() and not board.sync:IsShown(), "no browse or refresh action that cannot work")
        t.equal(database.version, 99, "future schema untouched")
        t.equal(database.futureData, "preserve", "future records preserved")
        s:assertHealthy()
      end)
      t.test(label .. ": bounty organization model follows its selector after a membership change", function()
        local s = new(case[1], case[2], { guild = "Current guild", rank = 0 })
        local B = s.ns.Bounty
        B.Board.organization = "club:99" -- a departed community restored from navigation
        B.Board.Open(); B.Board.SetTab("guild")
        t.equal(B.Board.organization, "guild", "board resolves a live organization")
        t.equal(B.Board.win.organization:GetValue(), B.Board.organization, "displayed choice matches the board model")
        local sample = B.Board.Build({ rows = function() return {} end })
        sample:Show(); B.Board.preview.SetTab("guild")
        t.equal(B.Board.preview.win.organization:GetValue(), "guild", "preview uses the same choice contract")
        s:assertHealthy()
      end)
    end
  end
  t.finish("UI states: " .. t.tests .. " scenarios")
end
