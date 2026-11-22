local _, ns = ...
local C, Kit, Theme, Core = ns.Onboarding.Coach, ns.Kit, ns.Theme, ns.Core
local E = { definitions = {}, pages = {} }
C.Examples = E

-- Nameplate markers need units in the world, so their guide owns an isolated
-- scene. Features with windows use those windows directly, never this host.
function E.Register(key, definition) E.definitions[key] = definition end

local function Build()
  if E.win then return E.win end
  local w = ns.Localization.BindWidget(Kit.Dialog("HighgroundPractice", { title = ns.Locale:Get("highground.coachexamples.practice.9d8822"), titleRole = "title",
    sub = ns.Locale:Get("highground.coachexamples.sample_data_try_every_control.1d071d"), width = 720, height = 650, noClose = true,
    onClose = function() if E.key and not E.closing then ns.Onboarding.Return() end end }), { title = "highground.coachexamples.practice.9d8822", sub = "highground.coachexamples.sample_data_try_every_control.1d071d" })
  E.win = w; w:SetMovable(false)
  w.area = Kit.ScrollArea(w); w.area:SetPoint("TOPLEFT", 24, -82); w.area:SetPoint("BOTTOMRIGHT", -20, 62)
  w.note = Theme.Text(w, "body", "textMuted"); w.note:SetPoint("BOTTOMLEFT", 24, 18)
  w.note:SetPoint("RIGHT", -24, 0); w.note:SetJustifyH("LEFT"); w.note:SetWordWrap(true)
  ns.Localization.Bind(w.note, "highground.coachexamples.sample_data_only_enable_in_game_saves.c60890")
  Core.OnFontScaleChange(function() if E.key then E.Refresh(true) end end)
  return w
end

function E.Page(key, title, build)
  Build()
  if not E.pages[key] then
    local p = CreateFrame("Frame", nil, E.win.area.body)
    p:SetPoint("TOPLEFT"); p.nodes, p.title = {}, title
    E.pages[key] = p; build(p); p:Hide()
  end
  return E.pages[key]
end

local function Add(page, key, widget, kind, caption)
  widget.sampleKind, widget.sampleKey = kind, key
  if caption then
    widget.sampleCaption = Theme.Text(page, "label", "textMuted")
    widget.sampleCaption:SetText(caption); widget.sampleCaption:SetJustifyH("LEFT")
  end
  page[key] = widget; page.nodes[#page.nodes + 1] = widget
  return widget
end

local function ClearFocus()
  if not E.page then return end
  for _, node in ipairs(E.page.nodes) do
    if node:GetObjectType() == "EditBox" then node:ClearFocus() end
  end
end

function E.Text(p, key, text, role, color)
  local t = Theme.Text(p, role or "bodyLarge", color or "text")
  t:SetJustifyH("LEFT"); t:SetJustifyV("TOP"); t:SetWordWrap(true); t:SetText(text)
  return Add(p, key, t, "text")
end

function E.Toggle(p, key, label, run)
  return Add(p, key, Kit.Toggle(p, label, { width = 300, onChange = function(_, value)
    if E.key and not E.rendering then E.data[key] = value; if run then run(E.data, p) end; E.Refresh() end
  end }), "toggle")
end

function E.Panel(p, key, height, build)
  local frame = CreateFrame("Frame", nil, p, "BackdropTemplate")
  Theme.Backdrop(frame)
  frame.sampleHeight = height; build(frame)
  return Add(p, key, frame, "panel")
end

function E.Layout()
  local w, p = E.win, E.page
  if not p then return end
  local scale = math.max(1, Core.FontScale())
  w:SetSize(math.min(720, math.max(400, UIParent:GetWidth() - 500)), math.min(700, UIParent:GetHeight() - 48))
  w:ClearAllPoints(); w:SetPoint("LEFT", UIParent, "LEFT", 24, 0)
  w.area:Refresh()
  local width, y = w.area.view:GetWidth(), 4
  p:SetWidth(width)
  for _, node in ipairs(p.nodes) do
    if node:IsShown() then
      if node.sampleCaption then
        node.sampleCaption:ClearAllPoints(); node.sampleCaption:SetPoint("TOPLEFT", 0, -y)
        node.sampleCaption:SetWidth(width); y = y + node.sampleCaption:GetStringHeight() + 8
      end
      node:ClearAllPoints(); node:SetPoint("TOPLEFT", 0, -y); node:SetWidth(width)
      if node.sampleKind == "text" then node:SetHeight(0) end
      local h = node.sampleKind == "text" and math.ceil(node:GetStringHeight()) + 2
        or node.sampleKind == "panel" and node.sampleHeight * scale
        or node.sampleKind == "toggle" and math.max(32 * scale, node.label:GetStringHeight() + 8)
        or 36 * math.min(scale, 1.3)
      if node.sampleKind == "toggle" then node.label:SetWordWrap(true) end
      node:SetHeight(h); node.sampleY = y; y = y + h + 18
      if node.Layout then node:Layout() end
    end
    if node.sampleCaption then node.sampleCaption:SetShown(node:IsShown()) end
  end
  p:SetHeight(y); w.area.body:SetHeight(y); w.area:Refresh()
  w.note:SetHeight(0); w.note:SetHeight(math.ceil(w.note:GetStringHeight()) + 2)
end

function E.Refresh(focus)
  if not E.page or not E.key then return end
  E.rendering = true
  if E.page.Refresh then E.page:Refresh(E.data) end
  E.Layout(); E.rendering = nil
  if focus and E.focus then E.Focus(E.focus) end
end

function E.Focus(key)
  E.focus = key
  local target = E.page and (type(key) == "function" and key() or E.page[key])
  if not target then return end
  target = target.sampleOwner or target
  local area, y = E.win.area, target.sampleY or 0
  if y < area.offset or y + target:GetHeight() > area.offset + area.view:GetHeight() then
    area:Scroll(math.max(0, y - 20))
  end
end

function E.Show(page, focus)
  if E.page ~= page then
    ClearFocus(); Kit.Dropdown.Hide()
    if E.page then E.page:Hide() end
    E.page = page; E.win.area:Scroll(0)
  end
  E.win:SetTitle(page.title); E.win:SetSub("")
  page:Show(); E.Refresh(); E.Focus(focus)
  Kit.Windows.Show(E.win)
  return page
end

function E.Step(id, title, text, page, target, hint, complete)
  return { id = id, title = title, text = text, hint = hint, complete = complete,
    capture = function() return { scroll = E.win and E.win.area.offset or 0 } end,
    enter = function(state)
      E.Show(page(), target)
      if state then E.win.area:Scroll(state.scroll or 0); E.Focus(target) end
    end,
    context = function() return E.win end,
    missing = ns.Locale:Get("highground.coachexamples.use_replay_to_bring_this_control_back.83c8a3"),
    target = function() return E.page and (type(target) == "function" and target() or E.page[target]) end }
end

function E.Start(key)
  E.Stop()
  local definition = assert(E.definitions[key], "Unknown guide sample: " .. key)
  E.key, E.data = key, definition.initial()
  return definition.steps()
end

function E.Hide()
  ClearFocus()
  if E.win then
    E.closing = true; Kit.Dropdown.Hide(); Kit.Windows.Close(E.win); E.closing = nil
  end
end

function E.Stop()
  E.Hide()
  E.key, E.data, E.focus = nil, nil, nil
end
