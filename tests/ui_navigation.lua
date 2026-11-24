-- Shared integration checks use real TOC load order in every UI package.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " navigation")
  local F = dofile("tests/bounties/public/fixture.lua")
  local runtime = dofile("../../tools/wowsim/" .. (addon == "Highground" and "battleground/" or "") .. "runtime.lua")
  local function new(client, build)
    return F.new("Tester", { addon = addon, client = client, build = build, runtime = function(game, saved, configure)
      return runtime(game, saved, function(s, e) configure(s, e); dofile("../../tools/wowsim/geometry.lua")(s) end)
    end })
  end
  local function click(button)
    assert(button and button.enabled ~= false and (not button.IsEnabled or button:IsEnabled()), "navigation control enabled")
    button.scripts.OnClick(button)
  end
  local function current(r, name) t.equal(r:Current().name, name, "current route") end
  local function count(r) local entries = r:History(); return #entries end

  for _, case in ipairs({ { "retail", 120100 }, { "retail", 16001 }, { "cata", 40402 } }) do
    local label = tostring(case[2])
    t.test(label .. ": browser rows and pages use guarded history and restore selection and scroll", function()
      local s, entries, actions = new(unpack(case)), {}, 0
      for i = 1, 24 do entries[i] = { key = i, title = "Entry " .. i, detail = string.rep("Details\n", 80) } end
      local w = s.ns.Kit.Browser(nil, { title = "Browse", data = function() return entries end,
        actions = { { label = "Apply", run = function() actions = actions + 1 end } } })
      w:Open()
      local router = w.navigation
      w.search:SetText("Entry")
      click(w.rows[2]); t.equal(w.selected, 2, "row click navigates")
      w.detailScroll:SetVerticalScroll(64)
      local visits = count(router)
      local stop = router:BeforeEach(function() return false, "Blocked" end)
      click(w.rows[3]); click(w.next)
      t.equal(w.selected, 2, "guard protects selected row")
      t.equal(w.offset, 0, "guard protects current page")
      t.equal(count(router), visits, "blocked list controls cannot push history")
      stop(); click(w.next)
      local offset = w.offset
      t.equal(count(router), visits + 1, "page click adds a visit")
      click(w.routeBack)
      t.equal(w.offset, 0, "Back restores page")
      t.equal(w.selected, 2, "Back restores row")
      t.equal(w.search:GetText(), "Entry", "Back restores search")
      t.equal(w.detailScroll:GetVerticalScroll(), 64, "Back restores detail scroll")
      click(w.rows[2])
      assert(router:CanGo(1), "reselecting current row preserves Forward")
      click(w.routeForward); t.equal(w.offset, offset, "Forward restores next page")
      click(w.routeBack); click(w.rows[3])
      assert(not router:CanGo(1), "different row replaces forward branch")
      local child = s.ns.Kit.CopyBox(nil, { title = "Nested" })
      child:Open(); child:Hide()
      assert(w:IsVisible(), "return resumes browser")
      t.equal(w.selected, 3, "child return keeps current selection")
      visits = count(router)
      w:Hide(); w:Open()
      t.equal(count(router), visits, "reopening does not duplicate visits")
      table.remove(entries, 2)
      click(w.routeBack)
      t.equal(w.selected, 1, "removed selection falls back to a live entry")
      t.equal(actions, 0, "browsing never applies entry actions")
      w:ResetNavigation()
      t.equal(count(router), 1, "new review session retires prior visits")
      t.equal(w.search:GetText(), "", "new review starts unfiltered")
      s:assertHealthy()
    end)

    do
      t.test(label .. ": sample boards keep their own page, help and filter history", function()
        local s = new(unpack(case))
        local B, rows = s.ns.Bounty, {}
        for i = 1, 15 do rows[i] = B.Preview.Sample("create") end
        local w = B.Board.Build({ rows = function(_, query)
          return (not query or query == "" or query == "sample") and rows or {}
        end, create = function() end, tools = function() end })
        B.Widgets.ShowWindow(w)
        local board, router = B.Board.preview, w.navigation
        w.search:SetText("sample"); click(w.next)
        local offset = board.offset
        assert(offset > 0, "sample has a second page")
        click(w.help); assert(board.help, "sample help opens through routing")
        click(w.routeBack)
        assert(not board.help, "Back leaves sample help")
        t.equal(board.offset, offset, "sample help preserves page")
        t.equal(w.search:GetText(), "sample", "sample help preserves query")
        click(w.routeBack); t.equal(board.offset, 0, "Back restores first sample page")
        click(w.routeForward); t.equal(board.offset, offset, "Forward restores second sample page")
        board.SetTab("guild"); click(w.review)
        assert(board.pendingOnly, "sample filter navigates")
        board.SetTab("guild"); assert(not board.pendingOnly, "sample tab clears review filter")
        click(w.routeBack); assert(board.pendingOnly, "Back restores filtered sample visit")
        click(w.routeBack); assert(not board.pendingOnly, "Back restores sample filter")
        local stop = router:BeforeEach(function() return false end)
        click(w.review); assert(not board.pendingOnly, "blocked sample filter preserves state")
        t.equal(w.review:GetChecked(), false, "blocked filter resets checkbox")
        stop()
        t.equal(B.Board.tab, "mine", "sample navigation leaves live board alone")
        s:assertHealthy()
      end)

      t.test(label .. ": board and editor history recover each visit without saving drafts", function()
        local s = new(unpack(case))
        local B = s.ns.Bounty
        if s.ns.Hub then s.ns.Options.OpenTool("bountyboard") else B.Board.Open() end
        for i = 1, 20 do assert(B.Add("Rival" .. string.char(64 + i) .. "-Realm", 0, "")) end
        local w, router = B.Board.win, B.Navigation.GetRouter()
        w.search:SetText("Rival")
        local stop = router:BeforeEach(function() return false end)
        click(w.next); t.equal(B.Board.offset, 0, "board paging obeys guards")
        stop(); click(w.next)
        local offset = B.Board.offset
        assert(offset > 0, "list has a second page")
        click(w.routeBack); t.equal(B.Board.offset, 0, "Back restores previous board page")
        click(w.routeForward); t.equal(B.Board.offset, offset, "Forward restores next board page")
        B.Board.SetTab("public"); current(router, "public")
        w.search:SetText("Shared query")
        click(w.routeBack)
        current(router, "mine"); t.equal(w.search:GetText(), "Rival", "list query restored")
        t.equal(B.Board.offset, offset, "list page restored")
        local visits = count(router)
        for _ = 1, 3 do
          assert(B.Board.SetTab("mine"))
          t.equal(w.search:GetText(), "Rival", "selected board keeps its query")
          t.equal(B.Board.offset, offset, "selected board keeps its page")
          t.equal(count(router), visits, "selected board does not add history")
          assert(router:CanGo(1), "selected board preserves Forward")
        end
        click(w.routeForward); t.equal(w.search:GetText(), "Shared query", "forward query restored")
        local form = assert(B.Form.Open("First-Realm", "personal"))
        form.gold:SetText("125"); form.note:SetText("First unsaved draft")
        B.Form.Open("Second-Realm", "personal")
        form.gold:SetText("750"); form.note:SetText("Second unsaved draft")
        click(form.routeBack)
        t.equal(form.nameIdentity, "First-Realm", "first target identity restored")
        t.equal(form.gold:GetText(), "125", "first amount restored")
        t.equal(form.note:GetText(), "First unsaved draft", "first note restored")
        form.note:SetText("Revised first draft")
        click(form.routeForward)
        t.equal(form.gold:GetText(), "750", "second amount independent")
        click(form.routeBack); t.equal(form.note:GetText(), "Revised first draft", "revised draft retained")
        assert(not B.Personal()[B.Key("First-Realm")] and not B.Personal()[B.Key("Second-Realm")], "navigation never saves")
        click(form.goldDetails)
        local windows = s.ns.Kit.Windows
        current(windows.router, windows.entries[B.GoldView.win].route)
        click(B.GoldView.win.done)
        assert(form:IsVisible(), "child returns to the same editor")
        t.equal(form.note:GetText(), "Revised first draft", "child return preserves draft")
        click(form.cancel); current(router, "public")
        assert(not router:CanGo(1), "discarded drafts cannot be resurrected")
        t.equal(w.search:GetText(), "Shared query", "cancel returns to original query")
        for i = 1, 12 do
          B.Ledger.All()[i] = { id = "claim-" .. i, name = "Rival" .. string.char(64 + i) .. "-Realm", gold = 0,
            by = B.Me(), claimant = "Hunter-Realm", personal = true, state = "claimed", claimedAt = B.Public.Now() - i }
        end
        local ledger = B.Ledger.Open(); ledger.search:SetText("Hunter")
        t.equal(ledger.navigation, router, "claims use the board's router")
        click(ledger.rows[2]); local selected = ledger.selected
        click(ledger.next); assert(ledger.offset > 0, "claims have another page")
        click(ledger.routeBack)
        t.equal(ledger.offset, 0, "Back restores claims page")
        t.equal(ledger.selected, selected, "Back restores selected claim")
        for _, claim in ipairs(B.Ledger.All()) do t.equal(claim.state, "claimed", "browsing does not approve claims") end
        B.Preferences.Open().threshold:SetText("812")
        click(B.Preferences.win.routeBack); current(router, "claims")
        t.equal(ledger.search:GetText(), "Hunter", "claims query restored")
        click(ledger.routeForward); current(router, "preferences")
        t.equal(B.Preferences.win.threshold:GetText(), "812", "settings draft restored")
        B.Emit("scope"); current(router, "mine")
        t.equal(count(router), 1, "scope change removes all old feature visits")
        assert(B.Board.SetTab("pending")); current(router, "guild")
        assert(B.Board.pendingOnly, "pending alias applies its filter")
        assert(B.Board.SetTab("guild"))
        assert(not B.Board.pendingOnly, "normal guild tab clears the pending filter")
        assert(router:Back()); assert(B.Board.pendingOnly, "Back restores the filtered visit")
        local preview = B.Preview
        preview.Start(nil, "claims")
        local claims = preview.OpenClaims()
        click(claims.rows[2]); assert(claims.navigation:CanGo(-1), "sample selections use history")
        claims:Hide(); preview.OpenClaims()
        assert(not claims.navigation:CanGo(-1), "new sample review retires old selections")
        preview.Stop()
        s:assertHealthy()
      end)

      t.test(label .. ": sample chapter history ends with its session", function()
        local s = new(unpack(case))
        local D = s.ns.Bounty.Preview
        D.Start(nil, "nearby"); D.Select("gold"); D.Select("claims")
        click(D.win.routeBack); current(D.router, "gold")
        t.equal(D.scene.key, "gold", "previous example shown")
        click(D.win.routeForward); t.equal(D.scene.key, "claims", "next example shown")
        D.Stop(); current(D.router, "stopped")
        assert(not D.router:CanGo(-1), "closed samples cannot return")
        s:assertHealthy()
      end)
    end

    do
      t.test(label .. ": macro tab and mode clicks keep the active visit and forward history", function()
        local s = new(unpack(case))
        local Win = s.ns.Macros.Window
        if s.ns.Hub then s.ns.Options.OpenTool("macros") else Win.Open() end
        local w, router = Win.win, Win.GetRouter()
        for _, key in ipairs({ "general", "all", "class", "mine", "build" }) do
          click(w.tabs[key]); current(router, key)
          assert(not w.refreshing, "tab layout completes without leaving refresh locked")
          for name, tab in pairs(w.tabs) do t.equal(tab.selected, name == key, "tab selection follows route") end
          local list = Win.List()
          for i, row in ipairs(w.rows) do
            local entry = key ~= "build" and i <= Win.visibleCards and list[i] or nil
            t.equal(row.entry, entry, "cards follow the selected tab")
            t.equal(row:IsVisible(), entry ~= nil, "only current cards are visible")
          end
        end
        if s.ns.Hub then
          s.ns.Hub.Open("macros-settings"); click(s.ns.Options.byKey["macros-settings"].openTool)
          assert(w:IsVisible() and w:GetParent() == s.env.UIParent, "config launches the same independent window")
          click(w.tabs.mine); click(w.tabs.general)
          current(router, "general")
          assert(w.list:IsVisible() and not w.refreshing, "catalog still renders after leaving the hub page")
        end
        Win.Edit({ name = "Draft", body = "/say unsaved", perCharacter = true })
        local editor = router:Current().params
        click(w.tabs.general); click(w.routeBack)
        for _ = 1, 3 do click(w.tabs.build) end
        t.equal(router:Current().params.name, editor.name, "selected Create keeps editor identity")
        assert(router:CanGo(1), "selected Create preserves Forward")
        click(w.routeForward); current(router, "general")
        w.search:SetText("Focus")
        click(w.tabs.all); click(w.routeBack)
        local visits = count(router)
        for _ = 1, 3 do
          click(w.tabs.general); click(w.modes.pvp)
          t.equal(w.search:GetText(), "Focus", "selected tab and mode keep search")
          t.equal(count(router), visits, "reselection does not add history")
          assert(router:CanGo(1), "reselection preserves Forward")
        end
        click(w.routeForward); current(router, "all")
        Win.Scroll(-2)
        local offset = Win.offset
        assert(offset > 0, "catalog is scrolled")
        click(w.tabs.general); click(w.routeBack)
        for _ = 1, 3 do click(w.tabs.all); click(w.modes.pvp) end
        t.equal(Win.offset, offset, "reselection keeps catalog scroll")
        assert(router:CanGo(1), "scrolled visit preserves Forward")
        click(w.modes.pve)
        t.equal(Win.Mode(), "pve", "different mode navigates")
        assert(not router:CanGo(1), "different mode branches history")
        click(w.routeBack); t.equal(Win.Mode(), "pvp", "Back restores mode")
        t.equal(Win.offset, offset, "Back restores scroll")
        t.equal(next(s.macros), nil, "navigation does not save macros")
        s:assertHealthy()
      end)

      t.test(label .. ": macro history retains code, recipes, destinations and search", function()
        local s = new(unpack(case))
        local M = s.ns.Macros
        local Win, panel = M.Window, M.BuildPanel
        if s.ns.Hub then s.ns.Options.OpenTool("macros") else Win.Open() end
        Win.SetTab("general"); Win.win.search:SetText("Focus")
        Win.Edit({ name = "First", body = "/say first", perCharacter = false })
        local p, router = panel.frame, Win.GetRouter()
        p.code:SetPlainText("/say changed first"); p.destination:SetValue("character", true)
        Win.Edit({ name = "Second", body = "/say second", perCharacter = false })
        p.code:SetPlainText("/say changed second")
        assert(router:Back())
        t.equal(p.name:GetText(), "First", "first editor name")
        t.equal(p.code:GetPlainText(), "/say changed first", "first edited code")
        t.equal(p.destination:GetValue(), "character", "save destination restored")
        assert(router:Forward()); t.equal(p.code:GetPlainText(), "/say changed second", "second edited code")
        assert(router:Back()); assert(router:Back()); current(router, "general")
        t.equal(Win.win.search:GetText(), "Focus", "catalog filter restored")
        assert(router:Forward()); current(router, "build")
        Win.SetMode("pve"); assert(router:Back())
        t.equal(Win.Mode(), "pvp", "previous macro mode restored")
        t.equal(p.code:GetPlainText(), "/say changed first", "mode history preserves code")
        t.equal(next(s.macros), nil, "navigation never creates game macros")
        for _, scale in ipairs({ 1, 1.5 }) do
          s.ns.Core.SetFontScale(scale)
          assert(Win.win.routeBack:IsVisible(), "editor owns its navigation in every host")
          local a, b = s.bounds(Win.win.routeBack), s.bounds(Win.win.routeForward)
          assert(a[1] + a[3] < b[1], "history controls remain separate")
        end
        s:assertHealthy()
      end)
    end
  end

  t.test("window guards preserve the visible owner on blocked open and Escape", function()
    local s, locked = new("retail", 120100), true
    local K = s.ns.Kit
    local parent = K.Dialog(nil, { title = "Parent" })
    local child = K.Dialog(nil, { title = "Draft", child = true, beforeLeave = function() return not locked, "Unsaved" end })
    parent:Show(); child:Show()
    child:Hide()
    assert(child:IsVisible() and not parent:IsShown(), "Escape rejection restores active draft")
    t.equal(K.Windows.Active(), child, "blocked closure retains owner")
    local other = K.Dialog(nil, { title = "Other" })
    other:Show()
    assert(not other:IsShown() and child:IsVisible(), "blocked primary switch retains draft")
    locked = false; child:Hide()
    assert(parent:IsVisible(), "accepted close returns to original parent")
    assert(not K.Windows.router:CanGo(1), "closed dialog removed from forward history")
    s:assertHealthy()
  end)
  t.finish("UI navigation: " .. t.tests .. " scenarios")
end
