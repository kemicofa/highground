local _, ns = ...
local B, Kit, T = ns.Bounty, ns.Kit, ns.Theme
local Demo = B.Preview

local function Text(parent, role, color)
  local fs = T.Text(parent, role, color)
  fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP"); fs:SetWordWrap(true)
  return fs
end

local function Examples(w)
  local host = CreateFrame("Frame", nil, w.body)
  w.examples = host
  host.nearbyLabel = Text(host, "caption", "textMuted"); host.nearbyLabel:SetPoint("TOPLEFT")
  host.nearbyLabel:SetText("NEARBY ROW")
  host.row = CreateFrame("Frame", nil, host)
  T.Fill(host.row, "BACKGROUND", "surface"):SetAllPoints()
  host.row.icon = host.row:CreateTexture(nil, "OVERLAY"); host.row.icon:SetSize(20, 20); host.row.icon:SetPoint("LEFT", 7, 0)
  Kit.ClassIcon(host.row.icon, "ROGUE")
  host.row.name = Text(host.row, "rowNameLarge", "text"); host.row.name:SetPoint("TOPLEFT", 34, -4)
  host.row.name:SetText("WantedPreview")
  T.PaintClass(host.row.name, ns.Util.ClassColor("ROGUE"))
  host.row.sub = Text(host.row, "label", "textMuted"); host.row.sub:SetPoint("BOTTOMLEFT", 34, 4)
  host.row.sub:SetText("85 · Tarren Mill · now")
  host.plateLabel = Text(host, "caption", "textMuted"); host.plateLabel:SetText("NAMEPLATE MARKER")
  host.plate = CreateFrame("Frame", nil, host)
  T.Fill(host.plate, "BACKGROUND", "danger"):SetAllPoints(); Kit.Outline(host.plate, "border")
  host.plate.name = T.Text(host.plate, "body", "onAccent"); host.plate.name:SetPoint("CENTER")
  host.plate.name:SetText("WantedPreview")
  host.marker = B.NewPlateMark(host)
  host.marker:SetPoint("RIGHT", host.plate, "LEFT", -10, 0)
  host.marker:Show()
end

function Demo.Refresh()
  local w, scene = Demo.win, Demo.scene
  if not (w and scene) then return end
  local extra = math.max(0, ns.Core.FontScale() - 1)
  -- Leave room above the window for the actual center-screen sighting alert.
  local screen = UIParent:GetHeight()
  w:SetSize(780 + extra * 160, math.min(540 + extra * 80, screen > 0 and math.max(380, screen - 220) or 580))
  w.body:SetWidth(w:GetWidth() - 68)
  for i, def in ipairs(Demo.scenes) do
    local button = w.scenes[def.key]
    local width = (w:GetWidth() - 72) / 4
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", 24 + (i - 1) * (width + 8), -130)
    button:SetSize(width, 30 + extra * 14); button:Select(def == scene)
  end
  w.scroll:ClearAllPoints(); w.scroll:SetPoint("TOPLEFT", 24, -178 - extra * 18)
  w.scroll:SetPoint("BOTTOMRIGHT", -44, 74)
  local y, width = 0, w.body:GetWidth()
  local function Place(fs, value, gap)
    fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 0, -y); fs:SetWidth(width); fs:SetText(value)
    local height = fs:GetStringHeight(); fs:SetHeight(height); y = y + height + gap
  end
  Place(w.titleText, scene.title, 10)
  Place(w.description, scene.description, 16)
  local row = w.row
  B.BoardRow.Layout(row); row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetWidth(width)
  B.BoardRow.Fill(row, Demo.row)
  row.primary:Hide(); row.more:Hide(); row.details:Hide()
  row:SetHeight(82 + extra * 36) -- actions stay visible in the preview footer
  y = y + row:GetHeight() + 18
  local host = w.examples
  host:SetShown(scene.key == "nearby")
  if scene.key == "nearby" then
    host:ClearAllPoints(); host:SetPoint("TOPLEFT", 0, -y); host:SetSize(width, 110 + extra * 28)
    host.row:ClearAllPoints(); host.row:SetPoint("TOPLEFT", 0, -28); host.row:SetSize(350 + extra * 60, 44 + extra * 20)
    host.plateLabel:ClearAllPoints(); host.plateLabel:SetPoint("TOPLEFT", width - 230 - extra * 50, 0)
    host.plate:ClearAllPoints(); host.plate:SetPoint("TOPRIGHT", -12, -32)
    host.plate:SetSize(200 + extra * 80, 26 + extra * 12)
    B.PaintRowMark(host.row, Demo.bounty); host.marker.gold:SetText(B.GoldText(Demo.bounty))
    y = y + host:GetHeight()
  end
  Place(w.detail, scene.detail, 12)
  w.body:SetHeight(y)
  w.replay:SetWidth(150 + extra * 70); w.details:SetWidth(140 + extra * 70); w.claims:SetWidth(156 + extra * 70)
  w.claims:SetShown(scene.key == "kill"); w.done:SetWidth(100 + extra * 40)
end

function Demo.Build()
  if Demo.win then return Demo.win end
  local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyPreview", {
    title = "BOUNTY PREVIEW", width = 780, height = 540, header = 64, accent = "gold", alpha = 1,
    strata = "FULLSCREEN_DIALOG", point = { "BOTTOM", "BOTTOM", 0, 16 } })
  Demo.win = w
  w.hint = Text(w, "body", "textMuted"); w.hint:SetPoint("TOPLEFT", 24, -82)
  w.hint:SetPoint("RIGHT", -24, 0); w.hint:SetHeight(42)
  w.hint:SetText("Sample rewards and claims are never sent or saved.\nChoose a scene to replay it. Sound follows your settings.")
  w.scenes = {}
  for _, scene in ipairs(Demo.scenes) do
    local button = Kit.Tab(w, scene.label, function() Demo.Select(scene.key) end)
    w.scenes[scene.key] = button
    Kit.Tooltip(button, { scene.title, scene.description })
  end
  w.scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
  w.body = CreateFrame("Frame", nil, w.scroll); w.body:SetSize(712, 400); w.scroll:SetScrollChild(w.body)
  w.scroll:EnableMouseWheel(true)
  w.scroll:SetScript("OnMouseWheel", function(self, delta)
    self:SetVerticalScroll(math.max(0, math.min(math.max(0, w.body:GetHeight() - self:GetHeight()), self:GetVerticalScroll() - delta * 45)))
  end)
  w.titleText, w.description = Text(w.body, "heading", "text"), Text(w.body, "body", "text")
  w.row = B.BoardRow.Build(w.body)
  -- Preview rows never expose their normal publishing/claim handlers.
  w.row.primary:SetScript("OnClick", function() end); w.row.more:SetScript("OnClick", function() end)
  w.row.details:SetScript("OnClick", function() B.Details.Open(Demo.row, true) end)
  Kit.Tooltip(w.row.details, { "Sample bounty details", "Open the real overview with sample rewards, notes, funding and expiry. Sample rewards cannot be edited or claimed." })
  Examples(w)
  w.detail = Text(w.body, "body", "textMuted")
  w.replay = Kit.Button(w, "Replay alert", 150, 32, { onClick = function() Demo.Replay() end })
  w.replay:SetPoint("BOTTOMLEFT", 24, 22)
  Kit.Tooltip(w.replay, { "Replay this scene", "Repeat its local chat or center-screen notification. No messages go to other players." })
  w.details = Kit.Button(w, "View bounty", 140, 32, { onClick = function() B.Details.Open(Demo.row, true) end })
  w.details:SetPoint("LEFT", w.replay, "RIGHT", 10, 0)
  Kit.Tooltip(w.details, { "Sample bounty details", "View the sample reward, contributors, funding and expiry. No extra selection is needed." })
  w.done = Kit.Button(w, "Close", 100, 32, { onClick = function() Demo.Stop() end })
  w.done:SetPoint("BOTTOMRIGHT", -24, 22)
  w.close:SetScript("OnClick", function() Demo.Stop() end)
  Kit.Tooltip(w.done, { "Close the preview", "Remove sample windows. Your real bounties and claims are unchanged." })
  w.claims = Kit.Button(w, "Sample claims", 156, 32, { onClick = function() Demo.OpenClaims() end })
  w.claims:SetPoint("RIGHT", w.done, "LEFT", -10, 0)
  Kit.Tooltip(w.claims, { "Sample kill reports", "See a report awaiting its poster's review, plus examples you can approve, reject and mark paid inside this preview." })
  ns.Core.OnFontScaleChange(Demo.Refresh)
  return w
end

function Demo.Replay()
  local key, b = Demo.scene.key, Demo.bounty
  if key == "nearby" then
    local pulse = Demo.win.examples.marker.pulse
    if pulse then pulse:Play() end
    B.Announce(b, "Tarren Mill", true)
  elseif key == "guild" then B.OnChanged(b, b.by, nil, true)
  elseif key == "shared" then B.AnnounceShared(b, true)
  else B.OnKilled(b, B.Public.ClaimMessage(2), true) end
end

function Demo.Select(key)
  for _, scene in ipairs(Demo.scenes) do if scene.key == key then Demo.scene = scene end end
  Demo.row, Demo.bounty = Demo.Sample(key)
  Demo.claims = Demo.Claims()
  local w = Demo.Build()
  w.scroll:SetVerticalScroll(0); Demo.Refresh(); B.Widgets.ShowWindow(w); Demo.Replay()
  return w
end

function Demo.Resume()
  if Demo.scene then Demo.Refresh(); B.Widgets.ShowWindow(Demo.win) end
end

function Demo.Stop()
  if Demo.win then
    Demo.win:Hide()
    local pulse = Demo.win.examples.marker.pulse
    if pulse then pulse:Stop() end
  end
  if Demo.claimsWin then Demo.claimsWin:Hide() end
  if B.Details.preview then B.Details.win:Hide(); B.Details.preview = nil end
  Demo.scene, Demo.row, Demo.bounty, Demo.claims = nil, nil, nil, nil
end

function Demo.OpenClaims()
  if not Demo.claimsWin then
    local actions = {}
    for _, choice in ipairs({ { "Approve", "approved" }, { "Mark paid", "paid" }, { "Reject", "rejected" } }) do
      actions[#actions + 1] = { label = choice[1], enabled = function(e)
        return e.claim.previewManage and (choice[2] == "paid" and e.claim.state == "approved"
          or choice[2] ~= "paid" and e.claim.state == "claimed")
      end, run = function(e)
        local c = e.claim
        if not c.previewManage then return false, "This report awaits the poster's review." end
        c.state, c.reviewedBy = choice[2], B.Me()
        if c.state == "paid" then c.paidAt = B.Public.Now() end
        return true, "Preview only: claim " .. c.state .. ". No gold or messages sent."
      end }
    end
    local w = Kit.Browser((ns.FRAME_PREFIX or "Highground") .. "BountyClaimsPreview", {
      title = "CLAIMS PREVIEW", hint = "Sample data only", alpha = 1, strata = "FULLSCREEN_DIALOG", actions = actions,
      data = function()
        local out = {}; for _, c in ipairs(Demo.claims or {}) do
          local e = B.Ledger.Entry(c)
          e.detail = "PREVIEW ONLY\n" .. (c.previewManage and "You are the poster. Try the review buttons below." or "You are the hunter. This report awaits the poster's review.")
            .. "\n\n" .. e.detail
          out[#out + 1] = e
        end
        return out
      end })
    Demo.claimsWin = w
    B.Widgets.BrowserHelp(w, { "Approve this sample report; only preview data changes.",
      "Show a manually recorded payment on the sample. No gold changes hands.", "Reject this sample report; real claims are unchanged." })
    w.back = Kit.Button(w, "Back to preview", 154, 26, { onClick = Demo.Resume })
    w.back:SetPoint("LEFT", w.next, "RIGHT", 8, 0)
    local function FitBack() w.back:SetWidth(w.back.label:GetStringWidth() + 24) end
    FitBack(); ns.Core.OnFontScaleChange(FitBack)
    Kit.Tooltip(w.back, { "Back to the preview", "Return to the scene selector without replaying the alert." })
  end
  local w = Demo.claimsWin
  w.selected, w.offset = nil, 0; w.search:SetText("")
  w:Open(); B.Widgets.ShowWindow(w)
  return w
end

function Demo.Command(text)
  local key = ns.Util.Trim(text or ""):lower()
  if key == "stop" or key == "off" then Demo.Stop(); return end
  if key == "" then
    if Demo.win and Demo.win:IsShown() then Demo.Stop(); return end
    key = "nearby"
  end
  if key == "world" then key = "shared" elseif key == "claims" then key = "kill" end
  for _, scene in ipairs(Demo.scenes) do if scene.key == key then return Demo.Select(key) end end
  B.Say("Use " .. B.CMD .. " test [nearby|guild|world|kill|stop].")
end
