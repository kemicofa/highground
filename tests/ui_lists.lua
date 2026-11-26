-- Edit boxes and lists, exercised through Highground's client manifests by
-- ui_components.lua.
return function(s, t)
  local K, env = s.ns.Kit, s.env

  t.test("colour edit boxes colour each change once", function()
    local calls = 0
    local box = env.CreateFrame("EditBox", nil, env.UIParent)
    K.ColorEditBox(box, function(plain)
      calls = calls + 1
      return "|cff336699" .. plain:gsub("|", "||") .. "|r"
    end)
    box:SetText("/cast Frostbolt")
    t.equal(calls, 1, "a change is coloured once, not again to show it")
    t.equal(box:GetPlainText(), "/cast Frostbolt", "the coloured text reads back as typed")
    box:SetText(box:GetText())
    t.equal(calls, 2, "already coloured text is checked once and kept")
    box:SetPlainText("/say a|b")
    t.equal(calls, 3, "setting plain text colours it once")
    t.equal(box:GetPlainText(), "/say a|b", "a typed bar survives")
    box:Hide()
  end)

  t.test("virtual lists with measured rows show exactly the rows in view and measure only on layout", function()
    local area = K.ScrollArea(env.UIParent)
    area:SetPoint("TOPLEFT"); area:SetSize(200, 100)
    local measured, created, widths, items = 0, 0, {}, {}
    for i = 1, 300 do items[i] = { height = 10 + (i % 5) * 10 } end
    local list = K.VirtualList(area, { gap = 2, max = 16, header = function() return 30 end,
      measure = function(item, _, width) measured = measured + 1; widths[width] = true; return item.height end,
      create = function(body) created = created + 1; return env.CreateFrame("Frame", nil, body) end,
      render = function(row, item) row.item = item end })
    list:SetItems(items)
    local tops, y = {}, 30
    for i, item in ipairs(items) do tops[i] = y; y = y + item.height + 2 end
    t.close(area.body:GetHeight(), y, "the body holds the header and every measured row")
    t.equal(measured, 600, "rows are measured once, then at the width left by the scrollbar")
    assert(widths[200] and widths[200 - area.gutterWidth], "both widths were measured")
    local count, pool = measured, created
    local function Check(offset)
      area:Scroll(offset)
      local shown, view = {}, area.view:GetHeight()
      for _, row in ipairs(list.rows) do
        if row:IsShown() then
          shown[row.item] = true
          local i = 0
          for n, item in ipairs(items) do if item == row.item then i = n end end
          t.close(s.bounds(row)[2] - s.bounds(area.body)[2], tops[i], "row " .. i .. " sits at its measured top")
          t.close(row:GetHeight(), items[i].height, "and has its measured height")
        end
      end
      for i, item in ipairs(items) do
        local inView = tops[i] + item.height > area.offset and tops[i] < area.offset + view
        assert(not shown[item] == not inView, "offset " .. offset .. ": item " .. i .. " is shown exactly while in view")
      end
    end
    for offset = 0, area.range, 37 do Check(offset) end
    Check(area.range)
    t.equal(measured, count, "scrolling measures nothing")
    assert(created <= pool + 4 and created <= 16, "a bounded window of rows is reused, got " .. created)
    area:SetSize(150, 100); area:Refresh()
    t.equal(measured, count + 300, "a new width measures again")
    assert(widths[150 - area.gutterWidth], "at the new width")
    area:Refresh()
    t.equal(measured, count + 300, "an unchanged width keeps the heights")
    list:Refresh()
    t.equal(measured, count + 600, "Refresh measures again, as after a text size change")
    list:SetItems({ items[1] })
    local visible = 0
    for _, row in ipairs(list.rows) do if row:IsShown() then visible = visible + 1 end end
    t.equal(visible, 1, "rows beyond the items hide")
    t.close(area.offset, 0, "a short list clamps the offset")
    area:Hide()
  end)
end
