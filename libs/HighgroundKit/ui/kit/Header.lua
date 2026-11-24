local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local S, Z = Theme.Space, Theme.Size

-- Both header texts are single lines. Reserve their line boxes from the
-- configured font; hidden or newly assigned text can measure as zero until
-- rendered, which otherwise changes the subtitle layout on the next open.
-- Layout runs on every show, resize, font and theme change: native writes
-- happen only when a value actually changes.
local function Near(a, b) return math.abs(a - b) < 0.001 end
local function SetWidth(region, width) if not Near(region:GetWidth(), width) then region:SetWidth(width) end end

local function LineHeight(text)
  local _, size = text:GetFont()
  local height = math.ceil((size or text.wbRoleSize) * 1.2)
  if not Near(text:GetHeight(), height) then text:SetHeight(height) end
  return height
end

local function SameText(text, value) return (text:GetText() or "") == tostring(value or "") end

-- Shared title row for dialogs and other surfaces. Callers supply actions
-- in reading order; the header owns their anchors, not their size, parent,
-- visibility or click handlers. Removing an action releases its anchors.
-- Title, actions and close share one vertical center. A subtitle stacks
-- below that row when it fits, or sits beside the title at larger sizes.
-- A stage badge (Kit.StageBadge) follows the title text.
-- opts: title, sub, titleRole, padding, crest, height, close, stage.
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
      Kit.Place(control, "RIGHT", self, "TOPRIGHT", -right, center)
      right = right + control:GetWidth() + gap
    end
    if self.crest then
      Kit.Place(self.crest, "LEFT", self, "LEFT", padding, 0)
      left = left + self.crest:GetWidth() + gap
    end
    local width = math.max(1, self:GetWidth() - left - right)
    local stage = self.stage and self.stage:IsShown() and self.stage
    -- Refit the badge too: text size changes reach its label, not its frame.
    local badge = stage and stage:Layout() + S("md") or 0
    Kit.Place(self.title, "LEFT", self, "TOPLEFT", left, center)
    local natural, titleWidth = self.title:GetStringWidth(), width
    -- The stage badge follows the title text; unmeasured text keeps the row.
    if stage then titleWidth = math.max(1, natural > 0 and math.min(width - badge, natural) or width - badge)
    elseif hasSub and not stacked then titleWidth = math.min(width, natural) end
    SetWidth(self.title, titleWidth)
    if stage then Kit.Place(stage, "LEFT", self.title, "RIGHT", S("md"), 0) end
    local subWidth = stacked and width or width - self.title:GetWidth() - badge - gap
    if stacked then
      Kit.Place(self.sub, "TOPLEFT", self.title, "BOTTOMLEFT", 0, -subGap)
    else
      Kit.Place(self.sub, "LEFT", stage or self.title, "RIGHT", gap, 0)
    end
    SetWidth(self.sub, math.max(1, subWidth))
    local showSub = hasSub and subWidth > 0
    if self.sub:IsShown() ~= showSub then self.sub:SetShown(showSub) end
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
    local same = #actions == #self.actions
    for i = 1, same and #actions or 0 do same = same and actions[i] == self.actions[i] end
    if same then self.actions = actions; return end
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
  -- Refreshes often repeat the same text; only a real change reflows.
  function h:SetTitle(text)
    if SameText(self.title, text) then return end
    self.title:SetText(text or ""); self:Layout()
  end
  function h:SetSub(text)
    if SameText(self.sub, text) then return end
    self.sub:SetText(text or ""); self:Layout()
  end
  -- stage: a release stage such as "alpha", or nil to hide the badge.
  function h:SetStage(stage)
    if not self.stage and not stage then return end
    if not self.stage then
      self.stage = Kit.StageBadge(self, stage)
      watch(self.stage)
      -- Translated titles change width without a header event.
      Kit.OnLocale(self, function(header) header:Layout() end)
    else
      self.stage:SetStage(stage)
    end
    self:Layout()
  end
  if h.close then watch(h.close) end
  if opts.stage then h:SetStage(opts.stage) end
  h:SetScript("OnShow", function() h:Layout() end)
  h:SetScript("OnSizeChanged", function() h:Layout() end)
  Core.OnFontScaleChange(function() h:Layout() end, true)
  Theme.OnChange(function() h:Layout() end)
  return h
end
