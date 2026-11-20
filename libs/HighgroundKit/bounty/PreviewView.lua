local _, ns = ...
local B, Kit, T = ns.Bounty, ns.Kit, ns.Theme
local Demo = B.Preview

local Text = Kit.Paragraph

local function Examples(w)
  local host = CreateFrame("Frame", nil, w.body)
  w.examples = host
  host.nearbyLabel = Text(host, "caption", "textMuted"); host.nearbyLabel:SetPoint("TOPLEFT"); host.nearbyLabel:SetText("NEARBY ROW")
  host.row = CreateFrame("Frame", nil, host)
  T.Fill(host.row, "BACKGROUND", "surface"):SetAllPoints()
  host.row.icon = host.row:CreateTexture(nil, "OVERLAY"); host.row.icon:SetSize(20, 20); host.row.icon:SetPoint("LEFT", 7, 0)
  host.row.name = Text(host.row, "rowNameLarge", "text"); host.row.name:SetPoint("TOPLEFT", 34, -4)
  host.row.sub = Text(host.row, "label", "textMuted"); host.row.sub:SetPoint("BOTTOMLEFT", 34, 4)
  host.row.sub:SetText("85 · Tarren Mill · now")
  host.plateLabel = Text(host, "caption", "textMuted"); host.plateLabel:SetText("NAMEPLATE MARKER")
  host.plate = CreateFrame("Frame", nil, host)
  T.Fill(host.plate, "BACKGROUND", "danger"):SetAllPoints(); Kit.Outline(host.plate, "border")
  host.plate.name = T.Text(host.plate, "body", "onAccent"); host.plate.name:SetPoint("CENTER")
  host.marker = B.NewPlateMark(host); host.marker:SetPoint("RIGHT", host.plate, "LEFT", -10, 0); host.marker:Show()
end

function Demo.Refresh()
  if Demo.guided then return end
  local w, scene = Demo.win, Demo.scene
  if not (w and scene) then return end
  local scale, state = math.max(1, ns.Core.FontScale()), Demo.Ensure()
  local extra = scale - 1
  w:SetSize(math.min(960 + extra * 300, UIParent:GetWidth() - 32), math.min(790 + extra * 160, UIParent:GetHeight() - 48))
  local side, top = 214 + extra * 90, 140 + extra * 28
  w.hint:SetWidth(w:GetWidth() - 48); w.hint:SetHeight(0); w.hint:SetHeight(w.hint:GetStringHeight() + 2)
  w.menu:ClearAllPoints(); w.menu:SetPoint("TOPLEFT", 20, -top); w.menu:SetPoint("BOTTOMLEFT", 20, 112)
  w.menu:SetWidth(side); w.menu.body:SetWidth(side - 24)
  local menuY, visited = 0, 0
  for _, def in ipairs(Demo.scenes) do
    local button = w.scenes[def.key]
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", 0, -menuY)
    button:SetSize(side - 24, 32 * scale); button:Select(def == scene)
    button.check:SetShown(state.visited[def.key]); if state.visited[def.key] then visited = visited + 1 end
    menuY = menuY + button:GetHeight() + 6
  end
  w.menu.body:SetHeight(menuY); w.menu:Refresh()
  w.contentArea:ClearAllPoints(); w.contentArea:SetPoint("TOPLEFT", side + 40, -top); w.contentArea:SetPoint("BOTTOMRIGHT", -24, 112)
  local width = w:GetWidth() - side - 82
  w.body:SetWidth(width)
  local y = 0
  local function Place(fs, value, gap)
    fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 0, -y); fs:SetWidth(width); fs:SetText(value)
    fs:SetHeight(0)
    local height = value ~= "" and math.ceil(fs:GetStringHeight()) + 2 or 0
    fs:SetHeight(math.max(1, height)); fs:SetShown(value ~= ""); y = y + height + (height > 0 and gap or 0)
  end
  Place(w.titleText, scene.title, 12); Place(w.description, scene.description, 14)
  local defs = Demo.Actions(scene.key)
  local columns = width >= 500 * scale and 2 or 1
  w.claims = nil
  for i, def in ipairs(defs) do
    local button = w.actions[i]
    if not button then
      button = Kit.Button(w.body, "", 200, 30, { onClick = function(self) if self.run then self.run() end end })
      w.actions[i] = button
    end
    button.run = def[2]; button:SetText(def[1]); button:Show()
    if def[1] == "Sample claims" then w.claims = button end
  end
  for i = #defs + 1, #w.actions do w.actions[i]:Hide() end
  local actionsHeight = Kit.LayoutGrid(w.actions, { width = width, columns = columns,
    height = 32 * scale, gap = 10, rowGap = 8, y = -y })
  y = y + actionsHeight + (#defs > 0 and 12 or 4)
  w.details:ClearAllPoints(); w.details:SetPoint("TOPLEFT", 0, -y); w.details:SetSize(width, 32 * scale)
  y = y + w.details:GetHeight() + 14
  Place(w.feedback, state.messages[scene.key] or "", 14)
  w.money:SetShown(scene.key == "gold")
  if scene.key == "gold" then
    w.money:ClearAllPoints(); w.money:SetPoint("TOPLEFT", 0, -y); w.money:SetSize(width, 38 * scale)
    w.money:SetText(B.Gold.Format(Demo.Wallet().rows[1].balance) .. " · Hover for all characters")
    y = y + w.money:GetHeight() + 16
  end
  Demo.row.tracking = state.interest == "tracking"
  B.BoardRow.Fill(w.row, Demo.row)
  w.row.primary:Hide(); w.row.details:Hide()
  B.BoardRow.Layout(w.row, math.min(width, 340 * scale))
  w.row:ClearAllPoints(); w.row:SetPoint("TOPLEFT", 0, -y)
  local alert = Demo.alert and Demo.alert:IsShown() and Demo.alert
  w.row:SetShown(not alert)
  if alert then
    B.Wanted.Layout(alert, width)
    alert:ClearAllPoints(); alert:SetPoint("TOPLEFT", 0, -y)
  end
  y = y + (alert or w.row):GetHeight() + 18
  local host = w.examples
  host:SetShown(scene.key == "nearby")
  if scene.key == "nearby" then
    local name = ns.Core.DisplayName(Demo.bounty.name)
    host.row.name:SetText(name); host.plate.name:SetText(name)
    Kit.ClassIcon(host.row.icon, Demo.bounty.class); T.PaintClass(host.row.name, ns.Util.ClassColor(Demo.bounty.class))
    host:ClearAllPoints(); host:SetPoint("TOPLEFT", 0, -y); host:SetSize(width, 176 * scale)
    host.row:ClearAllPoints(); host.row:SetPoint("TOPLEFT", 0, -28 * scale); host.row:SetSize(width, 44 * scale)
    host.row.name:SetWidth(width - 42)
    host.plateLabel:ClearAllPoints(); host.plateLabel:SetPoint("TOPLEFT", 0, -92 * scale)
    host.plate:ClearAllPoints(); host.plate:SetPoint("TOPLEFT", 40, -122 * scale); host.plate:SetSize(width - 40, 26 * scale)
    B.PaintRowMark(host.row, Demo.bounty); host.marker.gold:SetText(B.GoldText(Demo.bounty))
    y = y + host:GetHeight()
  end
  Place(w.detail, scene.detail, 12); w.body:SetHeight(math.max(1, y)); w.contentArea:Refresh()
  w.progress:SetText(visited .. "/" .. #Demo.scenes .. " features visited · scroll each example to see its details")
  w.progress:SetWidth(w:GetWidth() - 48)
  w.prev:SetEnabled(Demo.index > 1); w.next:SetText(Demo.index == #Demo.scenes and "Finish tour" or "Next feature")
  for _, button in ipairs({ w.prev, w.next, w.done }) do button:SetSize(button.label:GetStringWidth() + 32, 32 * scale) end
end

function Demo.Build()
  if Demo.win then return Demo.win end
  local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyPreview", {
    title = "BOUNTY FEATURE TOUR", width = 960, height = 790, header = 64, accent = "gold", alpha = 1,
    strata = "FULLSCREEN_DIALOG", onResume = function() Demo.Resume() end })
  Demo.win = w
  w.hint = Text(w, "body", "textMuted"); w.hint:SetPoint("TOPLEFT", 24, -82)
  w.hint:SetText("Try every feature with sample data. Nothing is saved, sent or charged.\nChoose a feature on the left, or follow Next feature. Sound follows your settings.")
  w.menu = Kit.ScrollArea(w); w.scenes = {}
  for _, scene in ipairs(Demo.scenes) do
    local button = Kit.Tab(w.menu.body, scene.label, function() Demo.Select(scene.key) end)
    w.scenes[scene.key] = button
    button.check = T.Fill(button, "OVERLAY", "gold"); button.check:SetSize(3, 18); button.check:SetPoint("RIGHT", -4, 0)
    Kit.Tooltip(button, { scene.title, scene.description })
  end
  w.contentArea = Kit.ScrollArea(w); w.scroll, w.body = w.contentArea.view, w.contentArea.body
  w.titleText, w.description = Text(w.body, "heading", "text"), Text(w.body, "body", "text")
  w.feedback = Text(w.body, "body", "gold"); w.actions = {}
  w.row = B.BoardRow.Build(w.body)
  w.row:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then B.Details.Open(Demo.row, true) end end)
  w.row.primary:SetScript("OnClick", function() end)
  w.row.details:SetScript("OnClick", function() B.Details.Open(Demo.row, true) end)
  w.details = Kit.Button(w.body, "View bounty", 200, 32, { tone = "gold", onClick = function() B.Details.Open(Demo.row, true) end })
  w.money = Kit.Button(w.body, "", 400, 38)
  w.money:HookScript("OnEnter", function() B.GoldTooltip.Show(w.money, true) end)
  w.money:HookScript("OnLeave", function() B.GoldTooltip.Hide(w.money) end)
  w.money:HookScript("OnHide", function() B.GoldTooltip.Hide(w.money) end)
  Examples(w); w.detail = Text(w.body, "body", "textMuted")
  w.progress = Text(w, "bodySmall", "textMuted"); w.progress:SetPoint("BOTTOMLEFT", 24, 74)
  w.prev = Kit.Button(w, "Previous", 140, 32, { onClick = function() Demo.Step(-1) end }); w.prev:SetPoint("BOTTOMLEFT", 24, 22)
  w.next = Kit.Button(w, "Next feature", 150, 32, { tone = "gold", onClick = function() Demo.Step(1) end })
  w.next:SetPoint("LEFT", w.prev, "RIGHT", 12, 0)
  w.done = Kit.Button(w, "Close tour", 120, 32, { onClick = function() Demo.Stop() end }); w.done:SetPoint("BOTTOMRIGHT", -24, 22)
  w.close:SetScript("OnClick", function() Demo.Stop() end)
  w:HookScript("OnHide", function()
    if not Kit.Windows.switching and not Demo.stopping and not Demo.changing then Demo.Stop() end
  end)
  ns.Core.OnFontScaleChange(Demo.Refresh)
  Kit.AttachNavigation(w, Demo.GetRouter())
  return w
end
