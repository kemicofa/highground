local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local S, Z = Theme.Space, Theme.Size

-- Both header texts are single lines. Reserve their line boxes from the
-- configured font; hidden or newly assigned text can measure as zero until
-- rendered, which otherwise changes the subtitle layout on the next open.
local function LineHeight(text)
  local _, size = text:GetFont()
  local height = math.ceil((size or text.wbRoleSize) * 1.2)
  text:SetHeight(height)
  return height
end

-- Shared title row for dialogs and other surfaces. Callers supply actions
-- in reading order; the header owns their anchors, not their size, parent,
-- visibility or click handlers. Removing an action releases its anchors.
-- Title, actions and close share one vertical center. A subtitle stacks
-- below that row when it fits, or sits beside the title at larger sizes.
-- opts: title, sub, titleRole, padding, crest, height, close.
function Kit.Header(parent, opts)
  opts = opts or {}
  local h = CreateFrame("Frame", nil, parent)
  h:SetHeight(opts.height or Z("header"))
  h:EnableMouse(false)
  h.actions, h.navigation, h.close, h.visibleControls = {}, {}, opts.close, {}
  h.padding = opts.padding or S("xl") + S("xs")
  h.title = Theme.Text(h, opts.titleRole or "display", "titleText")
  h.title:SetText(opts.title or "")
  h.title:SetJustifyH("LEFT"); h.title:SetJustifyV("MIDDLE"); h.title:SetWordWrap(false)
  h.sub = Theme.Text(h, "label", "textMuted")
  h.sub:SetText(opts.sub or "")
  h.sub:SetJustifyH("LEFT"); h.sub:SetJustifyV("MIDDLE"); h.sub:SetWordWrap(false)
  if opts.crest then h.crest = Kit.Crest(h, (opts.height or Z("header")) - S("lg")) end

  function h:Layout()
    if self.layingOut then return end
    self.layingOut = true
    local padding, gap = self.padding, S("lg")
    local left, right, rowHeight = padding, padding, LineHeight(self.title)
    -- Reused between layouts: headers reflow on every show, size and font change.
    local controls = self.visibleControls
    for i = #controls, 1, -1 do controls[i] = nil end
    for _, action in ipairs(self.navigation) do
      if action:IsShown() then controls[#controls + 1] = action end
    end
    for _, action in ipairs(self.actions) do
      if action:IsShown() then controls[#controls + 1] = action end
    end
    if self.close and self.close:IsShown() then controls[#controls + 1] = self.close end
    for _, control in ipairs(controls) do rowHeight = math.max(rowHeight, control:GetHeight()) end
    local hasSub = (self.sub:GetText() or "") ~= ""
    local subHeight, subGap = hasSub and LineHeight(self.sub) or 0, S("xs") + 1
    local stacked = hasSub and rowHeight + subGap + subHeight <= self:GetHeight() - S("sm") * 2
    local center = -(self:GetHeight() - (stacked and subHeight + subGap or 0)) / 2
    for i = #controls, 1, -1 do
      local control = controls[i]
      control:ClearAllPoints()
      control:SetPoint("RIGHT", self, "TOPRIGHT", -right, center)
      right = right + control:GetWidth() + gap
    end
    if self.crest then
      self.crest:ClearAllPoints(); self.crest:SetPoint("LEFT", self, "LEFT", padding, 0)
      left = left + self.crest:GetWidth() + gap
    end
    local width = math.max(1, self:GetWidth() - left - right)
    self.title:ClearAllPoints()
    self.title:SetPoint("LEFT", self, "TOPLEFT", left, center)
    self.title:SetWidth(hasSub and not stacked and math.min(width, self.title:GetStringWidth()) or width)
    local subWidth = stacked and width or width - self.title:GetWidth() - gap
    self.sub:ClearAllPoints()
    if stacked then
      self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -subGap)
    else
      self.sub:SetPoint("LEFT", self.title, "RIGHT", gap, 0)
    end
    self.sub:SetWidth(math.max(1, subWidth))
    self.sub:SetShown(hasSub and subWidth > 0)
    self.layingOut = nil
  end

  local watched = {}
  local function watch(control)
    if watched[control] or not control.HookScript or not control.HasScript then return end
    watched[control] = true
    -- Text actions expose HookScript, but cannot accept frame-only events
    -- such as OnSizeChanged. Query the native capability for each hook.
    for _, event in ipairs({ "OnShow", "OnHide", "OnSizeChanged" }) do
      if control:HasScript(event) then control:HookScript(event, function() h:Layout() end) end
    end
  end
  function h:SetActions(actions)
    actions = actions or {}
    for _, old in ipairs(self.actions) do
      local retained = false
      for _, action in ipairs(actions) do if action == old then retained = true end end
      if not retained then old:ClearAllPoints() end
    end
    self.actions = actions
    for _, action in ipairs(actions) do watch(action) end
    self:Layout()
  end
  function h:SetNavigation(actions)
    self.navigation = actions or {}
    for _, action in ipairs(self.navigation) do watch(action) end
    self:Layout()
  end
  function h:SetTitle(text) self.title:SetText(text or ""); self:Layout() end
  function h:SetSub(text) self.sub:SetText(text or ""); self:Layout() end
  if h.close then watch(h.close) end
  h:SetScript("OnShow", function() h:Layout() end)
  h:SetScript("OnSizeChanged", function() h:Layout() end)
  Core.OnFontScaleChange(function() h:Layout() end, true)
  Theme.OnChange(function() h:Layout() end)
  return h
end
