local _, ns = ...
local P, Kit, Theme, Core, L = ns.Options.Profiles, ns.Kit, ns.Theme, ns.Core, ns.Locale

-- A measured table with a bounded pool of visible rows. Long profiles retain
-- data, not hundreds of native frames; scrolling only repaints this pool.
function P.CreateComparison(parent)
  local area = Kit.ScrollArea(parent)
  area.rows, area.layout, area.pool = {}, {}, {}
  local function Text(owner, role, color)
    local text = Kit.Paragraph(owner, role or "body", color or "text")
    text:SetJustifyH("LEFT"); text:SetJustifyV("TOP")
    return text
  end
  area.columns = { Text(area, "label", "textMuted"), Text(area, "label", "danger"), Text(area, "label", "success") }
  area.measure = Text(area.body); area.measure:Hide()
  area.empty = Text(area.body, "bodyLarge", "textMuted")
  local function Cell(width, value)
    area.measure:SetWidth(math.max(1, width)); area.measure:SetText(value or "")
    return area.measure:GetStringHeight()
  end
  function area:PaintRows()
    local bottom, index = self.offset + self.view:GetHeight(), 0
    for _, entry in ipairs(self.layout) do
      if entry.y + entry.height >= self.offset and entry.y <= bottom then
        index = index + 1
        local row = self.pool[index]
        if not row then
          row = CreateFrame("Frame", nil, self.body)
          row.fill = Theme.Fill(row, "BACKGROUND", "surface"); row.fill:SetAllPoints()
          row.label, row.before, row.value = Text(row), Text(row, "body", "danger"), Text(row, "body", "success")
          row.line = Theme.Fill(row, "ARTWORK", "border")
          row.line:SetPoint("BOTTOMLEFT"); row.line:SetPoint("BOTTOMRIGHT"); row.line:SetHeight(1)
          self.pool[index] = row
        end
        row:Show(); row:SetHeight(entry.height)
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -entry.y); row:SetWidth(self.contentWidth)
        row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT", 10, -10)
        row.label:SetWidth(entry.group and self.contentWidth - 20 or self.labelWidth - 20)
        row.label:SetText(entry.label); Theme.Paint(row.label, entry.group and "accent" or "text")
        row.fill:SetShown(entry.group == true); row.line:SetShown(not entry.group)
        row.before:SetShown(not entry.group and not self.full)
        row.value:SetShown(not entry.group)
        if not entry.group then
          row.before:ClearAllPoints(); row.before:SetPoint("TOPLEFT", self.labelWidth + 10, -10)
          row.before:SetWidth(self.valueWidth - 20); row.before:SetText(entry.before)
          row.value:ClearAllPoints(); row.value:SetPoint("TOPLEFT", self.labelWidth + (self.full and 0 or self.valueWidth) + 10, -10)
          row.value:SetWidth((self.full and self.contentWidth - self.labelWidth or self.valueWidth) - 20)
          row.value:SetText(entry.value); Theme.Paint(row.value, self.full and "text" or "success")
        end
      end
    end
    for i = index + 1, #self.pool do self.pool[i]:Hide() end
  end
  area.onScroll = function() area:PaintRows() end
  function area:onLayout(width)
    self.contentWidth, self.labelWidth = width, width * 0.4
    self.valueWidth = (width - self.labelWidth) / 2
    local headerHeight = 30 * math.max(1, Core.FontScale())
    self.view:SetPoint("TOPLEFT", 0, -headerHeight)
    self.bar:SetPoint("TOPRIGHT", -2, -headerHeight)
    local labels = { L:Get("profiles.compare.setting"), L:Get("profiles.compare.default"),
      L:Get(self.full and "profiles.compare.value" or "profiles.compare.profile") }
    for i, column in ipairs(self.columns) do
      column:ClearAllPoints()
      column:SetPoint("TOPLEFT", i == 1 and 10 or self.labelWidth + (i == 3 and not self.full and self.valueWidth or 0) + 10, -4)
      column:SetWidth((i == 1 and self.labelWidth or self.full and width - self.labelWidth or self.valueWidth) - 20)
      column:SetText(labels[i]); column:SetShown(i ~= 2 or not self.full)
    end
    Theme.Paint(self.columns[3], self.full and "textMuted" or "success")
    self.layout = {}
    local y, group = 0, nil
    for _, data in ipairs(self.rows) do
      local label, before, value, title = P.ReviewFields(data)
      if title ~= group then
        local height = Cell(width - 20, title) + 20
        self.layout[#self.layout + 1] = { group = true, label = title, y = y, height = height }
        y, group = y + height, title
      end
      local height = math.max(Cell(self.labelWidth - 20, label),
        self.full and 0 or Cell(self.valueWidth - 20, before),
        Cell((self.full and width - self.labelWidth or self.valueWidth) - 20, value)) + 20
      self.layout[#self.layout + 1] = { label = label, before = before or L:Get("profiles.compare.not_included"),
        value = value, y = y, height = height }
      y = y + height
    end
    self.empty:SetShown(#self.rows == 0)
    self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT", 16, -24); self.empty:SetWidth(width - 32)
    self.empty:SetText(self.problem or L:Get("profiles.compare.same"))
    self.body:SetHeight(math.max(y + 8, #self.rows == 0 and self.empty:GetStringHeight() + 48 or 1))
  end
  function area:SetRows(rows, full, problem)
    self.rows, self.full, self.problem = rows or {}, full, problem
    self:Refresh()
  end
  local function Refresh() if area:IsVisible() then area:Refresh() end end
  Core.OnFontScaleChange(Refresh); Theme.OnChange(Refresh)
  area.locale = { SetText = Refresh }; ns.Localization.Bind(area.locale, "profiles.compare.setting")
  return area
end
