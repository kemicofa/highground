-- Run from an addon folder so its real manifests supply every dependency.
local addon, client, build = arg[1], arg[2], tonumber(arg[3])
local t = dofile("../../tools/harness.lua")(addon .. " components")
local battlegrounds = addon == "Highground"
local new = dofile("../../tools/wowsim/" .. (battlegrounds and "battleground/" or "") .. "runtime.lua")
local geometry = dofile("../../tools/wowsim/geometry.lua")
local s = new(client, nil, function(sim)
  sim.addon, sim.build = addon, build
  geometry(sim)
end)
local K, env = s.ns.Kit, s.env
local function fire(frame, event, ...)
  if frame.scripts[event] then frame.scripts[event](frame, ...) end
  for _, hook in ipairs(frame.hooks[event] or {}) do hook(frame, ...) end
end

dofile("../../tests/ui_tabs.lua")(s, t, fire)
dofile("../../tests/ui_action_rows.lua")(s, t, fire)
dofile("../../tests/ui_blocks.lua")(s, t, fire)
dofile("../../tests/ui_locale.lua")(s, t, fire)
dofile("../../tests/ui_lists.lua")(s, t)

t.test("rounded buttons share corner artwork within a fixed widget budget", function()
  local originalTheme = s.ns.Theme.Current()
  local before = #s.frames
  local button = K.Button(env.UIParent, "Apply", 120, 24)
  assert(#s.frames - before <= 64, "a button must not allocate a texture for every corner pixel")
  local methods = getmetatable(env.UIParent).__index
  local colorTexture = methods.SetColorTexture
  methods.SetColorTexture = function(self, ...)
    assert(not self.wbCorner, "repainting must preserve the corner alpha mask")
    return colorTexture(self, ...)
  end
  K.Paint(button, "accent")
  fire(button, "OnEnter"); fire(button, "OnMouseDown"); fire(button, "OnMouseUp"); fire(button, "OnLeave")
  s:advance(1)
  local count = #s.frames
  for _, name in ipairs({ "ember", "parchment", "highground" }) do
    s.ns.Theme.Use(name)
    fire(button, "OnSizeChanged")
    for _, layer in ipairs({ button.bg, button.hover, button.pressed, button.sheen }) do
      for _, part in ipairs(layer.parts) do
        if part.wbCorner then
          t.equal(part.texture, s.ns.Core.CONTROL_CORNERS, "corner keeps the shared texture")
        end
      end
    end
  end
  t.equal(#s.frames, count, "theme changes and resizing allocate no new widgets")
  s.ns.Theme.Use(originalTheme)
  methods.SetColorTexture = colorTexture
end)

t.test("unchanged enabled states preserve feedback without repainting", function()
  local button = K.Button(env.UIParent, "Apply", 120, 24)
  local paints, finish = 0, button.RefreshFinish
  button.RefreshFinish = function(...) paints = paints + 1; return finish(...) end
  button:SetEnabled(true)
  fire(button, "OnEnter"); fire(button, "OnMouseDown")
  paints = 0
  for _ = 1, 20 do button:SetEnabled(true) end
  t.equal(paints, 0, "repeated enable does not repaint")
  assert(button.wbPressed, "polling must not reset an in-flight press")
  button:Disable()
  assert(not button:IsEnabled() and not button.wbPressed and paints > 0, "disabling still clears feedback")
  paints = 0
  button:Disable(); button:SetEnabled(false)
  t.equal(paints, 0, "repeated disable does not repaint")
  button:Enable()
  assert(button:IsEnabled() and paints > 0, "reenabling still repaints")
end)

t.test("shared painting skips identical updates and invalidates on real changes", function()
  local T, writes = s.ns.Theme, 0
  local theme = T.Current()
  local button, tab = K.Button(env.UIParent, "Apply"), K.Tab(env.UIParent, "General")
  local toggle = K.Toggle(env.UIParent, "Enabled", { checked = true })
  local card = K.Card(env.UIParent, 100)
  local gradient = T.Gradient(env.UIParent, "BACKGROUND", "accent", "glow", "VERTICAL", 0, 1)
  local regions = { button.bg, button.label, button.edge[1], tab.bg, tab.label, toggle.edge[1], card.strip, gradient }
  for _, region in ipairs(regions) do
    for _, key in ipairs({ "SetColorTexture", "SetVertexColor", "SetTextColor", "SetGradient", "SetGradientAlpha" }) do
      local write = region[key]
      if write then region[key] = function(...) writes = writes + 1; return write(...) end end
    end
  end
  local function Refresh()
    K.Paint(button, "accent"); tab:Select(true); toggle:SetChecked(true, true); card:SetStrip("gold")
    T.Paint(gradient, "accent", "glow", "gradient")
  end
  Refresh(); s:advance(1)
  writes = 0
  for _ = 1, 30 do Refresh() end
  t.equal(writes, 0, "buttons, tabs, toggles, cards and gradients share paint deduplication")
  local storage = gradient.wbGradient
  gradient.wbGradient[2] = 0.25
  T.Paint(gradient, "accent", "glow", "gradient")
  assert(writes > 0 and gradient.wbGradient == storage, "gradient changes repaint using existing storage")
  writes = 0; Refresh()
  t.equal(writes, 0, "changed gradient becomes the new baseline")
  T.Paint(button.bg, "accent", 0.4)
  assert(writes > 0, "alpha changes repaint")
  writes = 0; T.Tint(button.bg, "accent", 0.4)
  assert(writes > 0, "painting mode changes repaint")
  T.Unpaint(card.strip); writes = 0; card:SetStrip("gold")
  assert(writes > 0, "unpainting invalidates previous output")
  local custom = { 0.1, 0.2, 0.3 }
  T.Paint(card.strip, custom); writes = 0; custom[1] = 0.6; T.Paint(card.strip, custom)
  assert(writes > 0, "mutable non-token colours are never mistaken for unchanged values")
  writes = 0; T.Paint(card.strip, custom)
  t.equal(writes, 0, "unchanged custom colours also skip native writes")
  T.Unpaint(card.strip); T.Paint(card.strip, custom)
  assert(writes > 0, "unpainting invalidates custom colours too")
  Refresh(); card:Hide(); writes = 0
  T.Use(theme == "ember" and "highground" or "ember")
  assert(writes > 0, "theme changes repaint registered regions, including hidden ones")
  writes = 0; Refresh()
  t.equal(writes, 0, "the new palette is cached after repaint")
  T.Use(theme)
end)

if s.ns.Hud then t.test("shared HUD class colours skip unchanged writes and follow edits and themes", function()
  local C, T, H = s.ns.Core, s.ns.Theme, s.ns.Hud
  local theme = T.Current()
  local surface, text = H.EnemySurface(env.UIParent), T.Text(env.UIParent, "body")
  surface.classStrip = T.Fill(env.UIParent, "OVERLAY", "border")
  surface.healthLine = T.Fill(env.UIParent, "OVERLAY", "textMuted")
  local writes, color = 0, { r = 0.3, g = 0.8, b = 0.9 }
  for _, region in ipairs({ surface, surface.classStrip, surface.healthLine, text }) do
    for _, name in ipairs({ "SetTextColor", "SetColorTexture" }) do
      local write = region[name]
      region[name] = function(...) writes = writes + 1; return write(...) end
    end
  end
  local function Refresh() H.PaintEnemy(surface, color); C.ClassPaint(text, color) end
  Refresh(); writes = 0
  for _ = 1, 30 do Refresh() end
  t.equal(writes, 0, "HUD colours use the same component cache")
  color.r = 0.7; Refresh()
  assert(writes > 0, "in-place class colour edits repaint")
  T.Use(theme == "ember" and "parchment" or "ember")
  writes = 0; Refresh()
  t.equal(writes, 0, "theme change refreshed idle class surfaces and text")
  T.Paint(text, "text"); T.Use(theme)
  t.equal(text.wbClass, nil, "switching to a token removes class repaint ownership")
end) end

t.test("shared font strings skip identical text without caching restricted values", function()
  local text = s.ns.Theme.Text(env.UIParent, "body")
  local writes, native = 0, text.wbSetText
  text.wbSetText = function(...) writes = writes + 1; return native(...) end
  text:SetText("Ready"); writes = 0
  for _ = 1, 30 do text:SetText("Ready") end
  t.equal(writes, 0, "repeated labels do not call the native setter")
  text:SetText(42); writes = 0; text:SetText(42)
  t.equal(writes, 0, "repeated numeric labels are unchanged")
  local convert, conversions = s.env.tostring, 0
  s.env.tostring = function(...) conversions = conversions + 1; return convert(...) end
  for _ = 1, 30 do text:SetText(42) end
  s.env.tostring = convert
  t.equal(conversions, 0, "repeated numbers skip string conversion")
  native(text, "Changed externally"); text:SetText(42)
  t.equal(text:GetText(), "42", "native text changes are reconciled")
  local read, secret = text.GetText, { secret = true }
  text.GetText = function() error("restricted incoming text must bypass the getter") end
  text:SetText(secret)
  text.GetText = function() return secret end
  writes = 0; text:SetText("Ready")
  t.equal(writes, 1, "restricted existing text never enters equality checks")
  text.GetText = read; text:SetText(nil)
  t.equal(text:GetText(), "", "nil still clears text")
end)

t.test("font roles avoid resetting unchanged fonts and follow actual native state", function()
  local C, T = s.ns.Core, s.ns.Theme
  local text = T.Text(env.UIParent, "body")
  -- A font family (when the client has them) or the text's own font.
  local writes, set, setObject = 0, text.SetFont, text.SetFontObject
  text.SetFont = function(...) writes = writes + 1; return set(...) end
  text.SetFontObject = function(...) writes = writes + 1; return setObject(...) end
  for _ = 1, 30 do T.SetRole(text, "body") end
  t.equal(writes, 0, "unchanged text role never resets the font")
  C.SetFontScale(1.2)
  assert(writes > 0, "text size changes still apply")
  local get = text.GetFont
  text.GetFont = function(self)
    local file, size, flags = get(self)
    return file, size + 0.00001, flags
  end
  writes = 0; T.SetRole(text, "body")
  t.equal(writes, 0, "native floating-point roundoff does not reset the scaled font")
  text:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
  writes = 0; T.SetRole(text, "body")
  t.equal(writes, 1, "external font changes are reconciled")
  C.SetFontScale(1)
end)

t.test("input placeholders follow typed and programmatic changes without swallowing callbacks", function()
  local seen = {}
  local input = K.Input(env.UIParent, 180, "Search", { placeholder = "Find a player", onChange = function(self, text, user)
    seen[#seen + 1] = { text, user }
    t.equal(self.hint:IsShown(), text == "", "placeholder updates before the callback")
  end })
  assert(input.hint:IsShown())
  input:SetText("Player")
  input.text = "Playe"; fire(input, "OnTextChanged", true) -- typed: the game edits, then reports
  fire(input, "OnTextChanged", false) -- a resize reflow reports unchanged text
  input:SetText("")
  t.equal(#seen, 3, "each change is delivered once and a reflow is not a change")
  t.equal(seen[1][1], "Player", "programmatic content is delivered")
  t.equal(seen[2][2], true, "user-input flag survives")
  local hooked = 0
  input:HookScript("OnTextChanged", function() hooked = hooked + 1 end)
  input:SetText("Again")
  assert(not input.hint:IsShown() and hooked == 1)
end)

t.test("grids reflow labels, skip hidden controls and retain reading order at either edge", function()
  local host = env.CreateFrame("Frame", nil, env.UIParent)
  host:SetPoint("TOPLEFT"); host:SetSize(400, 300)
  local items = {}
  for i = 1, 4 do items[i] = K.Button(host, "Action " .. i) end
  local height, columns = K.LayoutGrid(items, { width = 300, minWidth = 130, height = 30, gap = 10 })
  t.equal(columns, 2, "two columns fit")
  t.equal(height, 70, "two rows include one gap")
  t.close(items[1]:GetWidth(), 145, "columns share available width")
  local first, second, third = s.bounds(items[1]), s.bounds(items[2]), s.bounds(items[3])
  assert(first[1] < second[1] and first[2] == second[2] and third[2] > first[2], "left to right, then top to bottom")
  local writes = 0
  for _, item in ipairs(items) do
    for _, key in ipairs({ "ClearAllPoints", "SetPoint", "SetSize" }) do
      local write = item[key]
      item[key] = function(...) writes = writes + 1; return write(...) end
    end
  end
  for _ = 1, 30 do K.LayoutGrid(items, { width = 300, minWidth = 130, height = 30, gap = 10 }) end
  t.equal(writes, 0, "unchanged grids never rewrite geometry")
  local item = items[1]
  local point, width = item.GetPoint, item.GetWidth
  item.GetPoint = function(self)
    local p, r, rp, x, y = point(self)
    return p, r, rp, x + 0.00001, y - 0.00001
  end
  item.GetWidth = function(self) return width(self) + 0.00001 end
  K.LayoutGrid(items, { width = 300, minWidth = 130, height = 30, gap = 10 })
  t.equal(writes, 0, "native floating-point roundoff does not relayout the grid")
  item.GetPoint, item.GetWidth = point, width
  items[1]:ClearAllPoints(); items[1]:SetPoint("CENTER", host, "CENTER", 0, 0)
  items[1]:SetSize(20, 20); writes = 0
  K.LayoutGrid(items, { width = 300, minWidth = 130, height = 30, gap = 10 })
  assert(writes > 0 and items[1]:GetWidth() == 145, "external geometry changes are reconciled")
  items[2]:Hide(); host:Hide()
  height, columns = K.LayoutGrid(items, { width = 300, minWidth = 130, height = 30, gap = 10, anchor = "BOTTOMLEFT", y = 12 })
  t.equal(columns, 2, "hidden ancestors do not empty the grid")
  first, third = s.bounds(items[1]), s.bounds(items[3])
  assert(third[1] > first[1] and third[2] == first[2], "hidden child leaves no hole")
  assert(s.bounds(items[4])[2] > first[2], "bottom anchor preserves reading order")
  writes = 0
  items[1]:SetText("A much longer translated action label")
  height, columns = K.LayoutGrid(items, { width = 300, height = 30 })
  t.equal(columns, 1, "longer labels wrap the controls to more rows")
  assert(writes > 0, "content changes reflow the grid")
  for _, item in ipairs(items) do item:Hide() end
  height, columns = K.LayoutGrid(items, { width = 300 })
  t.equal(height, 0, "empty grid occupies no space")
  t.equal(columns, 0, "empty grid has no columns")
end)

t.test("scroll areas clamp on content changes and ignore retired bodies", function()
  local area = K.ScrollArea(env.UIParent, { wheelStep = 25 })
  area:SetPoint("TOPLEFT"); area:SetSize(200, 100)
  area.body:SetHeight(400); fire(area.body, "OnSizeChanged")
  area:Scroll(10000)
  t.close(area.offset, 300, "scroll clamps to content end")
  fire(area.view, "OnMouseWheel", 1)
  t.close(area.offset, 275, "custom wheel step")
  fire(area.bar, "OnValueChanged", 50)
  t.close(area.view:GetVerticalScroll(), 50, "dragging and viewport agree")
  local old = area.body
  local replacement = env.CreateFrame("EditBox", nil, area.view)
  replacement:SetSize(1, 250)
  area:SetBody(replacement); area:SetBody(replacement)
  t.equal(#replacement.hooks.OnSizeChanged, 1, "reattaching a body does not duplicate listeners")
  assert(not old:IsShown() and area.view.scrollChild == replacement, "old body is retired")
  area:Scroll(150)
  old:SetHeight(1); fire(old, "OnSizeChanged")
  t.close(area.offset, 150, "retired body cannot move current content")
  replacement:SetHeight(60); fire(replacement, "OnSizeChanged")
  t.close(area.offset, 0, "shrinking content clears stale offset")
  t.close(area.bar.value, 0, "thumb position also clears")
  assert(not area.bar:IsShown(), "no scrollbar for content that fits")
  area:SetHeight(20); fire(area.view, "OnSizeChanged")
  assert(area.bar:IsShown() and area.thumb:GetHeight() <= 16, "thumb fits even a very short viewport")
  local fail = true
  area.onLayout = function() if fail then fail = false; error("layout broke") end end
  area:Refresh()
  local stats = s.ns.Util.GuardStats["scroll area"]
  assert(stats and stats.lastError:find("layout broke", 1, true), "a failing layout is recorded")
  s.ns.Util.ClearErrors()
  replacement:SetHeight(400); fire(replacement, "OnSizeChanged")
  t.close(area.range, 380, "the next change measures again")
  area.onLayout = nil
end)

t.test("scroll text grows after short text, reflows with width and fonts, and clears old scroll", function()
  local area = K.ScrollText(env.UIParent, { bottomPadding = 8 })
  area:SetPoint("TOPLEFT"); area:SetSize(280, 100)
  area:SetText("Short")
  t.equal(area.range, 0, "short text fits")
  area:SetText(string.rep("Long report with several words. ", 70))
  local initialHeight = area.body:GetHeight()
  assert(area.range > 0 and area.bar:IsShown(), "long replacement is reachable")
  assert(not area.text.heightSet, "text retains natural height")
  area:SetWidth(180); fire(area.view, "OnSizeChanged")
  assert(area.body:GetHeight() > initialHeight, "narrower viewport rewraps text")
  local beforeScale = area.body:GetHeight()
  s.ns.Core.SetFontScale(1.5)
  assert(area.body:GetHeight() > beforeScale, "larger fonts reflow without reopening")
  local theme, beforeTheme = s.ns.Theme.Current(), area.body:GetHeight()
  assert(s.ns.Theme.Register("component_large", { type = { body = { "medium", 28 } } }))
  s.ns.Theme.Use("component_large")
  assert(area.body:GetHeight() > beforeTheme, "theme type roles reflow after their new fonts apply")
  s.ns.Theme.Use(theme)
  area:Scroll(100000)
  area:SetText("Short again")
  t.equal(area.offset, 0, "short replacement clears overscroll")
  assert(not area.bar:IsShown())
  s.ns.Core.SetFontScale(1)
end)

dofile("../../tests/ui_progress.lua")(s, t, fire)
dofile("../../tests/ui_busy.lua")(s, t, fire)

t.test("rounded native alpha does not restart settled transitions", function()
  local M, region = s.ns.Motion, env.CreateFrame("Frame", nil, env.UIParent)
  local native = region.GetAlpha
  region.GetAlpha = function(self) return native(self) + 0.00000001 end
  region:SetAlpha(0.35)
  local frames = #s.frames
  for _ = 1, 600 do
    M.Alpha(region, 0.35)
    assert(not M.IsPlaying(region), "settled alpha never starts a no-op fade")
  end
  t.equal(#s.frames, frames, "settled alpha needs no driver frame")
  M.Alpha(region, 0.7)
  assert(M.IsPlaying(region), "meaningful opacity changes still animate")
  s:advance(0.3); M.Alpha(region, 0.7)
  assert(not M.IsPlaying(region), "the new rounded endpoint stays settled")
  M.Show(region, false); s:advance(0.3)
  assert(not region:IsShown(), "fade completion still hides decorations")
end)
s:assertHealthy()
t.finish("Reusable UI: " .. t.tests .. " scenarios")
