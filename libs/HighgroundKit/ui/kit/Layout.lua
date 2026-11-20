local _, ns = ...
local Kit, Theme = ns.Kit, ns.Theme

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
  local visible, needed = {}, opts.minWidth or 0
  for _, item in ipairs(items) do
    if item:IsShown() then
      visible[#visible + 1] = item
      local width = item.label and item.label:GetStringWidth() + (opts.padding or 24) or item:GetWidth()
      needed = math.max(needed, width)
    end
  end
  if #visible == 0 then return 0, 0 end
  local gap, rowGap = opts.gap or 8, opts.rowGap or opts.gap or 8
  local available = math.max(1, opts.width)
  local columns = math.max(1, math.floor(opts.columns or math.min(#visible, (available + gap) / math.max(1, needed + gap))))
  local width = math.max(1, (available - (columns - 1) * gap) / columns)
  local rows, height = math.ceil(#visible / columns), opts.height or Theme.Size("control")
  local anchor = opts.anchor or "TOPLEFT"
  for i, item in ipairs(visible) do
    local row, column = math.floor((i - 1) / columns), (i - 1) % columns
    local y = anchor == "BOTTOMLEFT" and (rows - 1 - row) * (height + rowGap) or -row * (height + rowGap)
    item:ClearAllPoints()
    item:SetPoint(anchor, opts.parent or item:GetParent(), anchor,
      (opts.x or 0) + column * (width + gap), (opts.y or 0) + y)
    item:SetSize(width, height)
  end
  return rows * height + (rows - 1) * rowGap, columns
end
