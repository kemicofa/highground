local test, new, equal = ...

-- Hover a frame (its script and hooks) and return the tooltip lines as
-- { text, r, g, b, wrap } plus the anchor it asked for.
local function hover(sim, f)
  local tt, lines, anchor = sim.env.GameTooltip, {}, nil
  local add, owner = tt.AddLine, tt.SetOwner
  tt.AddLine = function(self, text, r, g, b, wrap)
    lines[#lines + 1] = { text, r, g, b, wrap }
    return add(self, text)
  end
  tt.SetOwner = function(self, o, a) anchor = a; return owner(self, o, a) end
  if f.scripts.OnEnter then f.scripts.OnEnter(f) end
  for _, h in ipairs(f.hooks.OnEnter or {}) do h(f) end
  tt.AddLine, tt.SetOwner = add, owner
  return lines, anchor
end

-- Lines match { text, token[, wrap] } in order, in the token's tooltip colour.
local function expect(sim, lines, want, why)
  equal(#lines, #want, why .. ": line count")
  for i, w in ipairs(want) do
    local got = lines[i]
    equal(got[1], w[1], why .. ": line " .. i)
    local r, g, b = sim.ns.Theme.TipColor(w[2])
    assert(math.abs(got[2] - r) + math.abs(got[3] - g) + math.abs(got[4] - b) < 1e-6,
      why .. ": line " .. i .. " in " .. w[2])
    equal(got[5] and true or false, w[3] or false, why .. ": line " .. i .. " wrap")
  end
end

local function menuRows(sim)
  local out = {}
  for _, row in ipairs(sim.env.HighgroundDropdown.rows) do
    if row:IsShown() then out[#out + 1] = row end
  end
  return out
end

test("minimap quick menu keeps its entries, order, actions and toggle", function()
  local sim = new("retail")
  local b = sim.env.HighgroundMinimapButton
  local names = { "Lock panels", "Macros", "Bounty board", "Test and commands", "Preview main panel", "Highground",
    "Blizzard settings" }
  b.scripts.OnClick(b, "RightButton")
  local menu = sim.env.HighgroundDropdown
  assert(menu:IsShown(), "right-click opens it")
  local rows = menuRows(sim)
  equal(#rows, #names, "entry count")
  for i, name in ipairs(names) do equal(rows[i].label:GetText(), name, "entry " .. i) end
  equal(rows[1].bg.colorTexture[4], 0, "no entry highlighted until hovered")
  local point = menu.points[1]
  equal(point[1], "TOPRIGHT", "hangs left of the button")
  equal(point[2], b, "anchored to the button")
  b.scripts.OnClick(b, "RightButton")
  assert(not menu:IsShown(), "right-click again closes it")

  local function pick(name)
    b.scripts.OnClick(b, "RightButton")
    for _, row in ipairs(menuRows(sim)) do
      if row.label:GetText() == name then row.scripts.OnClick(row) end
    end
    assert(not menu:IsShown(), name .. ": picking closes the menu")
  end
  pick("Bounty board")
  equal(sim.ns.Hub.current, "bountyboard", "bounty board entry")
  pick("Test and commands")
  equal(sim.ns.Hub.current, "tools", "tools entry")
  pick("Highground")
  equal(sim.ns.Hub.current, "home", "home entry")
  local ran
  local slash = sim.env.SlashCmdList.HIGHGROUND
  sim.env.SlashCmdList.HIGHGROUND = function(cmd) ran = cmd end
  pick("Preview main panel")
  sim.env.SlashCmdList.HIGHGROUND = slash
  equal(ran, "test", "preview entry runs /hg test")
  local opened
  local open = sim.ns.Options.Open
  sim.ns.Options.Open = function() opened = true end
  pick("Blizzard settings")
  sim.ns.Options.Open = open
  assert(opened, "Blizzard settings entry")
  local special = false
  for _, name in ipairs(sim.env.UISpecialFrames or {}) do
    if name == "HighgroundDropdown" then special = true end
  end
  assert(special, "Escape closes the menu")
end)

test("tooltips keep their text and colours", function()
  local sim = new("retail")
  local lines, anchor = hover(sim, sim.env.HighgroundMinimapButton)
  equal(anchor, "ANCHOR_LEFT", "minimap tooltip anchor")
  expect(sim, lines, { { "Highground", "gold" }, { "Left-click: open Highground", "text" },
    { "Right-click: panel lock, macros and more", "text" }, { "Drag: move around the minimap", "textMuted" } },
    "minimap button")

  local O = sim.ns.Options
  for _, p in ipairs(O.pages) do p.frame:Show() end
  lines, anchor = hover(sim, O.tools.previews[1])
  equal(anchor, "ANCHOR_RIGHT", "preview tooltip anchor")
  expect(sim, lines, { { "/hg test", "gold" }, { "Click again to stop the preview.", "textMuted" } }, "preview")

  for _, row in ipairs(O.rows) do
    if row.key == "killPer" then
      lines = hover(sim, row.label:GetParent())
      expect(sim, lines, { { "Points per killability rating", "text", true }, { "Default: 6", "textMuted" },
        { "Allowed: 0–500 points", "textMuted", true },
        { "6 × tuning 1 × battleground 1 = 6 effective points", "success", true } }, "scoring row")
    end
  end
  for _, cb in ipairs(O.featureBoxes) do
    if cb.key == "minimap" then
      lines = hover(sim, cb)
      equal(#lines, 2, "feature switch: title and description")
      expect(sim, { lines[1] }, { { "Minimap button", "text" } }, "feature switch title")
      equal(lines[2][5], true, "feature description wraps")
    end
  end

  sim:command("bounty add 300 Rogue")
  sim:command("bounty")
  local card = sim.env.HighgroundBountyFrame.rows[1]
  lines, anchor = hover(sim, card)
  equal(anchor, "ANCHOR_RIGHT", "bounty card anchor")
  expect(sim, lines, { { "Rogue-Realm", "gold" }, { "300g reward", "text", true }, { "Your bounty · Only me", "text", true },
    { "Private target for your alerts", "textMuted", true } }, "bounty card")
  local empty = sim.env.HighgroundBountyFrame.rows[2]
  equal(#hover(sim, empty), 0, "empty card: no tooltip")
end)
