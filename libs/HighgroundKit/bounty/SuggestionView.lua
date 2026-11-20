local _, ns = ...
local B, Kit, T = ns.Bounty, ns.Kit, ns.Theme
local S, P = B.Suggestions, B.Public
local V = {}
S.View = V
local PREFIX = ns.FRAME_PREFIX or "Highground"

function V.Hide(name)
  local w = V.toast
  if w and (not name or w.entry and B.Key(w.entry.name) == B.Key(name)) then w:Hide(); w.entry = nil end
end

function V.Review(name)
  V.Hide(name)
  local scope = S.Existing(name)
  if scope then
    B.Board.SetTab(scope); B.Board.Open()
    for _, row in ipairs(B.BoardModel.Rows(scope)) do
      if B.Key(row.name) == B.Key(name) then B.Details.Open(row); return end
    end
    return
  end
  for _, row in ipairs(S.Rows()) do
    if B.Key(row.name) == B.Key(name) then
      local w = B.Form.Open(row.name, row.mode)
      w:SetTitle("REVIEW BOUNTY")
      w.gold:SetText(""); w.note:SetText(S.Reason(row))
      w.suggestionTarget = row.name
      return
    end
  end
  B.Say("These reports have expired or the suggestion was dismissed. Open Suggestions for current reports.")
end

function V.Tooltip(r)
  local lines = { { ns.Core.DisplayName(r.name), "gold" }, { r.status, "text", true },
    { "Your deaths: " .. r.personal .. ". Guild: " .. r.guildDeaths .. " deaths across " .. r.guildVictimCount .. " characters.", "text", true },
    { "Reports from participating players; not server-verified kill proof. Review the target, audience and reward before submitting.", "textMuted", true } }
  if r.existing then lines[#lines + 1] = { "A bounty already exists. Review opens that listing.", "gold", true } end
  return lines
end

local function Evidence(r)
  local lines = { ns.Core.DisplayName(r.name), "", r.total .. " reported deaths in the last " .. (S.Window() / 60) .. " minutes.",
    "You: " .. r.personal .. ". Guild: " .. r.guildDeaths .. " deaths across " .. r.guildVictimCount .. " characters.",
    "Reports from participating players, not server-verified proof. Characters are counted separately, including alts.", "" }
  local victims = {}
  for name, count in pairs(r.victims) do victims[#victims + 1] = ns.Core.DisplayName(name) .. ": " .. count end
  table.sort(victims)
  for _, line in ipairs(victims) do lines[#lines + 1] = line end
  lines[#lines + 1] = ""
  table.sort(r.reports, function(a, b) return a.at > b.at end)
  for _, e in ipairs(r.reports) do
    lines[#lines + 1] = B.Widgets.Ago(P.Now() - e.at) .. " · " .. e.victim .. " · " .. e.zone
      .. " (" .. (e.source == "recap" and "death recap" or "fatal combat damage") .. ")"
  end
  return table.concat(lines, "\n")
end

function V.Render(r, preview, state)
  local field = preview and "previewWin" or "details"
  if not V[field] then
    local w = Kit.Dialog(PREFIX .. "BountySuggestionReports" .. (preview and "Preview" or ""), {
      title = preview and "PREVIEW · DEATH REPORTS" or "DEATH REPORTS", width = 640, height = 500,
      header = 60, accent = "gold", alpha = 1, strata = "FULLSCREEN_DIALOG", child = preview })
    V[field] = w
    w.reports = Kit.ScrollText(w)
    w.reports:SetPoint("TOPLEFT", 24, -78); w.reports:SetPoint("BOTTOMRIGHT", -26, 116)
    w.scroll, w.body, w.text = w.reports.view, w.reports.body, w.reports.text
    w.review = Kit.Button(w, "Review bounty", 176, 30, { onClick = function()
      if preview then return B.Preview.OpenCreate("personal", "Suggested after 5 sample death reports near Tarren Mill.") end
      if w.entry then V.Review(w.entry.name) end
    end })
    w.dismiss = Kit.Button(w, "Dismiss 24h", 130, 30, { onClick = function()
      if preview then B.Preview.Notice("Sample suggestion dismissed for 24 hours. Real reports are unchanged."); w:Hide(); return end
      if w.entry then S.Change(w.entry.name, "dismiss"); w:Hide() end
    end })
    w.ignore = Kit.Button(w, "Ignore enemy", 130, 30, { onClick = function()
      if preview then B.Preview.Notice("Sample enemy ignored. Real suggestions are unchanged."); w:Hide(); return end
      if w.entry then S.Change(w.entry.name, w.entry.ignored and "allow" or "ignore"); w:Hide() end
    end })
    w.back = Kit.Button(w, preview and "Return" or "Back to board", 150, 28, { onClick = function() w:Hide() end })
    w.back:SetPoint("BOTTOMLEFT", 24, 18)
    Kit.Tooltip(w.back, { "Back to the bounty board", "Return to your suggestions without dismissing reports or creating a bounty." })
    function w:Layout()
      local scale = math.max(1, ns.Core.FontScale())
      if not self.bountyPage then self:SetSize(640 * scale, 500 + (scale - 1) * 180) end
      self.back:SetWidth(150 * scale)
      Kit.LayoutGrid({ self.review, self.dismiss, self.ignore }, { width = self:GetWidth() - 48,
        columns = 3, height = 30 * scale, x = 24, y = 62, anchor = "BOTTOMLEFT" })
      self.reports:Refresh()
    end
    w.LayoutPage = w.Layout
    Kit.Tooltip(w.review, { "Review bounty", "Open the existing bounty, or review a new draft. You choose the audience and reward before saving." })
    Kit.Tooltip(w.dismiss, { "Dismiss for 24 hours", "Hide this target's suggestions for one day. New reports do not shorten the dismissal." })
    Kit.Tooltip(w.ignore, { "Ignore or allow this enemy", "Ignored enemies stay hidden until you choose Show ignored on Suggestions and allow them again." })
    ns.Core.OnFontScaleChange(function() if w:IsShown() then w:Layout() end end)
  end
  local w = V[field]
  w.entry = r; w.reports:SetText(Evidence(r)); w:Layout(); w.reports:Scroll(0)
  w.review:SetEnabled(not r.ignored); w.dismiss:SetEnabled(not r.ignored)
  w.ignore:SetText(r.ignored and "Allow again" or "Ignore enemy")
  if preview then B.Widgets.ShowWindow(w) else B.Navigation.Mount(w) end
  if state then w.reports:Scroll(state.scroll or 0) end
  return w
end

function V.Details(r, preview)
  if preview then return V.Render(r, true) end
  return B.Navigation.Open("suggestion", { name = r.name })
end

local function Toast()
  if V.toast then return V.toast end
  local w = Kit.Dialog(PREFIX .. "BountySuggestion", { title = "BOUNTY SUGGESTION", width = 560, height = 248,
    header = 54, accent = "gold", savedKey = "bountySuggestion", point = { "TOPRIGHT", "TOPRIGHT", -36, -180 } })
  V.toast = w
  w.body = T.Text(w, "body", "text"); w.body:SetJustifyH("LEFT"); w.body:SetJustifyV("TOP"); w.body:SetWordWrap(true)
  w.body:SetPoint("TOPLEFT", 22, -70); w.body:SetPoint("RIGHT", -22, 0)
  w.review = Kit.Button(w, "Review bounty", 160, 30, { onClick = function() if w.entry then V.Review(w.entry.name) end end })
  w.dismiss = Kit.Button(w, "Dismiss 24h", 140, 30, { onClick = function() if w.entry then S.Change(w.entry.name, "dismiss") end end })
  w.ignore = Kit.Button(w, "Ignore enemy", 140, 30, { onClick = function() if w.entry then S.Change(w.entry.name, "ignore") end end })
  Kit.Tooltip(w.review, { "Review bounty", "Review a prefilled draft with an optional reward. This button does not publish a bounty." })
  Kit.Tooltip(w.dismiss, { "Dismiss for 24 hours", "Hide suggestions for this enemy for one day." })
  Kit.Tooltip(w.ignore, { "Ignore this enemy", "Stop suggestions for this enemy. Use Show ignored on the Suggestions board to allow them again." })
  function w:Layout()
    local scale = math.max(1, ns.Core.FontScale())
    self:SetSize(560 * scale, 248 + (scale - 1) * 170); self.body:SetHeight(122 * scale)
    Kit.LayoutGrid({ self.review, self.dismiss, self.ignore }, { width = self:GetWidth() - 44,
      columns = 3, height = 30 * scale, x = 22, y = 20, anchor = "BOTTOMLEFT" })
  end
  w:Layout(); ns.Core.OnFontScaleChange(function() w:Layout() end)
  return w
end

local function Fill(w, r)
  w.entry = r
  w.body:SetText(ns.Core.DisplayName(r.name) .. "\n" .. r.total .. " reported deaths in " .. (S.Window() / 60) .. " minutes. You: " .. r.personal
    .. ".\nGuild: " .. r.guildDeaths .. " deaths across " .. r.guildVictimCount .. " characters.\nLast report: " .. (r.zone or "Unknown location"))
end

function V.Notify(r)
  if V.toast and V.toast:IsShown() or B.Widgets.HasOpenWindow() then return false end
  local w = Toast()
  Fill(w, r); w.untilTime = GetTime() + 20; w:Show()
  return true
end

function V.Update(rows)
  local w = V.toast
  if not w or not w:IsShown() then return end
  if ns.Util.read(InCombatLockdown) or not ns.Nearby.InWorld() or GetTime() >= w.untilTime then V.Hide(); return end
  for _, r in ipairs(rows) do
    if w.entry and B.Key(r.name) == B.Key(w.entry.name) and not r.existing then Fill(w, r); return end
  end
  V.Hide()
end
