local test, new, equal = ...

local function oneRoot(sim)
  local count = 0
  for frame in pairs(sim.ns.Kit.Windows.entries) do
    local parent, hosted = frame:GetParent(), false
    while parent do
      if sim.ns.Kit.Windows.entries[parent] then hosted = true end
      parent = parent.GetParent and parent:GetParent()
    end
    if not hosted and frame:IsVisible() then count = count + 1 end
  end
  assert(count <= 1, "only one foreground tool can draw or receive input")
end

local function journal(sim)
  sim.ns.NearbyHistory.All()["Rival-Realm"] = {
    class = "ROGUE", last = 10, first = 1, times = 2, killedMe = 0, killedThem = 0, note = "Remember" }
  return sim.ns.EnemyJournal.Open()
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " journal Add bounty replaces its window instead of interleaving panels", function()
  local sim = new(client)
  local w = journal(sim)
  w.search:SetText("Rival")
  w:ClearAllPoints(); w:SetPoint("CENTER", 120, 20)
  sim:setCombat(true)
  w.actions[3].scripts.OnClick(w.actions[3])
  assert(sim.ns.Bounty.Board.win:IsVisible(), "bounty board opened from journal")
  assert(not w:IsShown(), "journal is hidden immediately, including all of its controls")
  oneRoot(sim)
  sim.ns.EnemyJournal.Open()
  assert(not sim.ns.Bounty.Board.win:IsShown(), "returning to journal replaces the board")
  equal(w.search:GetText(), "Rival", "search state retained")
  local _, x, y = w:GetPoint()
  equal(x, 120, "position retained"); equal(y, 20, "position retained")
  oneRoot(sim); sim:assertHealthy()
end)

test(client .. " note editors return to the correct standalone or hosted journal", function()
  local sim = new(client)
  local w = journal(sim)
  for _, hosted in ipairs({ false, true }) do
    if hosted then sim.ns.Hub.Open("journal") end
    w.search:SetText("Rival")
    w.actions[1].scripts.OnClick(w.actions[1])
    local note = sim.ns.EnemyJournal.noteWindow
    assert(note:IsVisible() and not w:IsVisible(), "only the editor is visible")
    oneRoot(sim)
    note.box:SetText("Updated note")
    note.actions.save.scripts.OnClick(note.actions.save)
    assert(w:IsVisible() and not note:IsShown(), "saving returns to the journal")
    if hosted then
      assert(sim.ns.Hub.win:IsVisible() and w:GetParent() == sim.ns.Hub.content, "journal returns inside the hub")
    end
    equal(w.search:GetText(), "Rival", "filter survives editor")
    equal(w.entry.record.note, "Updated note", "edit saved once")
    oneRoot(sim)
  end
  sim:assertHealthy()
end)
end

test("switching primary tools abandons old popup return paths", function()
  local sim = new("cata")
  local w = journal(sim)
  w.actions[1].scripts.OnClick(w.actions[1])
  local note = sim.ns.EnemyJournal.noteWindow
  note.box:SetText("Unfinished note")
  sim.ns.Bounty.Board.Open()
  assert(not note:IsShown() and not w:IsShown(), "new tool replaces the entire editor flow")
  sim.ns.Bounty.Board.win:Hide()
  assert(not note:IsShown() and not w:IsShown(), "closing cannot resurrect an unrelated old window")
  equal(note.box:GetText(), "Unfinished note", "switching does not erase local draft text")
  oneRoot(sim)
end)

test("nested child dialogs return one step at a time", function()
  local sim = new("cata")
  local K = sim.ns.Kit
  local parent = K.Dialog(nil, { title = "Parent" })
  local child = K.CopyBox(nil, { title = "Edit" })
  local nested = K.CopyBox(nil, { title = "Rename" })
  parent:Show(); child:Open(); nested:Open()
  assert(nested:IsVisible() and not child:IsShown() and not parent:IsShown())
  oneRoot(sim)
  nested:Hide()
  assert(child:IsVisible() and not parent:IsShown(), "first close returns to editor")
  child:Hide()
  assert(parent:IsVisible(), "next close returns to original tool")
  oneRoot(sim)
end)

test("hosted bounty pages and returning borrowed pages never reopen extra windows", function()
  local sim = new("cata")
  local B, H = sim.ns.Bounty, sim.ns.Hub
  B.Board.Open(); H.Open("bountyboard")
  B.Form.Open("Rival-Realm")
  assert(H.win:IsVisible() and B.Form.win:IsVisible(), "owned form stays inside the active host")
  oneRoot(sim)
  B.Form.win:Hide()
  local editor = sim.ns.Kit.CopyBox(nil, { title = "Share" })
  editor:Open(); editor:Hide()
  assert(H.win:IsVisible() and B.Board.win:IsVisible(), "closing a page keeps its host available as the next editor's owner")
  B.Form.Open("Rival-Realm")
  H.Open("home")
  assert(not B.Board.win:IsVisible() and not B.Form.win:IsVisible(), "navigation hides the whole borrowed page")
  H.win:Hide()
  assert(not B.Board.win:IsVisible(), "closing a host never resurfaces an old standalone window")
  oneRoot(sim)
end)

test("completing a review retires its hidden editor and returns to the original tool", function()
  local sim = new("cata")
  local K = sim.ns.Kit
  local parent = K.Dialog(nil, { title = "Parent" })
  local editor = K.CopyBox(nil, { title = "Import" })
  local review = K.Dialog(nil, { title = "Review", child = true })
  parent:Show(); editor:Open(); review:Show()
  K.Windows.Close(editor); review:Hide()
  assert(parent:IsVisible() and not editor:IsShown(), "finished editor does not reopen")
  oneRoot(sim)
end)

test("standalone kit instances coordinate while gameplay HUDs remain independent", function()
  local sim = new("cata")
  local other = { Kit = {} }
  setfenv(assert(loadfile("libs/ui/kit/Windows.lua")), sim.env)("OtherHighgroundAddon", other)
  equal(other.Kit.Windows, sim.ns.Kit.Windows, "embedded libraries share one coordinator")
  local external = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  external:Hide(); other.Kit.Windows.Register(external)
  sim.ns.NearbyPreview()
  local hud = sim.ns.Nearby.win
  journal(sim); external:Show()
  assert(not sim.ns.EnemyJournal.win:IsShown(), "another addon replaces the active tool")
  assert(hud:IsVisible(), "gameplay HUD remains available")
  oneRoot(sim); sim:assertHealthy()
end)
