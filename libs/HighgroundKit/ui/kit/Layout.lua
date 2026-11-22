local _, ns = ...
local Kit, Theme = ns.Kit, ns.Theme

-- Native coordinates use floats; subpixel roundoff is not a layout change.
local function Near(a, b) return type(a) == "number" and math.abs(a - b) < 0.001 end

-- Own one anchor and optionally a size. Compare native state rather than
-- retaining another geometry cache on every widget. External changes and
-- reparenting are reconciled on the next call; callers own combat safety.
function Kit.Place(region, point, relative, relativePoint, x, y, width, height)
  relative, relativePoint, x, y = relative or region:GetParent(), relativePoint or point, x or 0, y or 0
  local p, r, rp, px, py
  if region.GetNumPoints and region:GetNumPoints() == 1 then p, r, rp, px, py = region:GetPoint() end
  if p ~= point or r ~= relative or rp ~= relativePoint or not Near(px, x) or not Near(py, y) then
    region:ClearAllPoints(); region:SetPoint(point, relative, relativePoint, x, y)
  end
  if width and height and (not Near(region:GetWidth(), width) or not Near(region:GetHeight(), height)) then region:SetSize(width, height) end
end

-- Wrapping copy with natural height. Callers own its text, width and anchors.
-- opts.nonSpaceWrap also breaks long unspaced words (names, codes, links).
function Kit.Paragraph(parent, role, color, opts)
  local text = Theme.Text(parent, role or "body", color or "text")
  text:SetJustifyH("LEFT"); text:SetJustifyV("TOP"); text:SetWordWrap(true)
  if opts and opts.nonSpaceWrap and text.SetNonSpaceWrap then text:SetNonSpaceWrap(true) end
  return text
end

-- Equal-width controls in reading order. Hidden items do not leave holes;
-- IsShown keeps layout stable when the containing page is hidden.
-- opts: parent, width, height, x/y (anchor offsets), anchor (TOPLEFT or
-- BOTTOMLEFT), columns (fixed), minWidth, padding (label allowance), gap,
-- rowGap. Without columns, labels and minWidth determine how many fit.
-- Returns occupied height and column count. Owns only anchors and sizes.
function Kit.LayoutGrid(items, opts)
  local count, needed = 0, opts.minWidth or 0
  for _, item in ipairs(items) do
    if item:IsShown() then
      count = count + 1
      local width = item.label and item.label:GetStringWidth() + (opts.padding or 24) or item:GetWidth()
      needed = math.max(needed, width)
    end
  end
  if count == 0 then return 0, 0 end
  local gap, rowGap = opts.gap or 8, opts.rowGap or opts.gap or 8
  local available = math.max(1, opts.width)
  local columns = math.max(1, math.floor(opts.columns or math.min(count, (available + gap) / math.max(1, needed + gap))))
  local width = math.max(1, (available - (columns - 1) * gap) / columns)
  local rows, height = math.ceil(count / columns), opts.height or Theme.Size("control")
  local anchor = opts.anchor or "TOPLEFT"
  local i = 0
  for _, item in ipairs(items) do
    if item:IsShown() then
      local row, column = math.floor(i / columns), i % columns
      local y = anchor == "BOTTOMLEFT" and (rows - 1 - row) * (height + rowGap) or -row * (height + rowGap)
      Kit.Place(item, anchor, opts.parent or item:GetParent(), anchor,
        (opts.x or 0) + column * (width + gap), (opts.y or 0) + y, width, height)
      i = i + 1
    end
  end
  return rows * height + (rows - 1) * rowGap, columns
end

-- Grow a control dimension with enlarged text; smaller text keeps the token.
function Kit.Scale(value)
  return value * math.max(1, ns.Core.FontScale())
end

-- Width that fits a button's label plus its inner margins (default lg on
-- each side), never below minimum. FitButton also applies it.
function Kit.LabelWidth(button, minimum, padding)
  return math.max(minimum or 0, math.ceil(button.label:GetStringWidth() + (padding or Theme.Space("lg") * 2)))
end

function Kit.FitButton(button, minimum, padding)
  local width = Kit.LabelWidth(button, minimum, padding)
  if not Near(button:GetWidth(), width) then button:SetWidth(width) end
  return width
end

-- Display text from a literal, a function returning text, or a message
-- descriptor { key = messageKey, values = table or function }. Kit blocks
-- resolve their labels through it again after a language change.
function Kit.Text(spec)
  if type(spec) == "function" then return spec() or "" end
  if type(spec) == "table" and type(spec.key) == "string" then
    local values = spec.values
    if type(values) == "function" then values = values() end
    return values and ns.Locale:Format(spec.key, values) or ns.Locale:Get(spec.key)
  end
  return spec == nil and "" or tostring(spec)
end

-- Run refresh(frame) after a language change. The frame is the registered
-- target: the registry keeps weak keys, and a frame stays referenced while it
-- exists (an anonymous table would be collected). An existing refresh runs first.
function Kit.OnLocale(frame, refresh)
  local Localization = ns.Localization
  if not (Localization and Localization.Watch) then return end
  local previous = frame.RefreshLocale
  Localization.Watch(frame, previous and function(self) previous(self); refresh(self) end or refresh)
end
