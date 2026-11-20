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
function Kit.Paragraph(parent, role, color)
  local text = Theme.Text(parent, role or "body", color or "text")
  text:SetJustifyH("LEFT"); text:SetJustifyV("TOP"); text:SetWordWrap(true)
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
