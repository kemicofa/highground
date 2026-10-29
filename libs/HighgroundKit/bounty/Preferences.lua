local _, ns = ...
local B, P, Kit, T = ns.Bounty, ns.Bounty.Public, ns.Kit, ns.Theme
local Pref = {}
B.Preferences = Pref

function Pref.Build()
  if Pref.win then return Pref.win end
  local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyPreferences", {
    title = "SHARED BOUNTY ALERTS", width = 570, height = 450, header = 64, accent = "gold", alpha = 1, strata = "FULLSCREEN_DIALOG" })
  Pref.win = w
  w.receive = Kit.Toggle(w, "Browse shared bounties", { width = 510, onChange = function(_, on)
    ns.Core.SetOption("bountyReceive", on); P.TransportTick(); B.Board.Refresh()
  end })
  w.receive:SetPoint("TOPLEFT", 24, -90)
  Kit.Tooltip(w.receive, { "Join the shared board", "Receive contributions from participating players on your realm and faction. This does not publish a bounty." })
  w.threshold = Kit.Input(w, 230, "NOTIFY ME FROM (GOLD)"); w.threshold:SetPoint("TOPLEFT", 24, -170)
  local function Save(self)
    local value = tonumber(self:GetText())
    if P.Integer(value, 0, 999999999) then
      ns.Core.SetOption("bountyMinGold", value); w.status:SetText(""); B.Board.Refresh()
    else w.status:SetText("Enter a whole gold amount from 0 to 999999999.") end
  end
  w.threshold:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  w.threshold:HookScript("OnEditFocusGained", function(self) self.editing = true end)
  w.threshold:HookScript("OnEditFocusLost", function(self) self.editing = nil; Save(self) end)
  Kit.Tooltip(w.threshold, { "Notification minimum", "Only the combined reward with recent available-funds reports counts toward alerts. Smaller bounties stay in the list below matching rewards, slightly muted. 0 includes any positive funded reward." })
  w.hint = T.Text(w, "body", "textMuted")
  w.hint:SetPoint("TOPLEFT", 24, -212); w.hint:SetPoint("RIGHT", -24, 0); w.hint:SetHeight(72)
  w.hint:SetJustifyH("LEFT"); w.hint:SetJustifyV("TOP")
  w.hint:SetText("This only changes notifications. Smaller rewards remain visible below matching bounties.\n0 = notify for any funded reward.")
  w.publishOptIn = Kit.Toggle(w, "Advertise my shared bounties", { width = 510, onChange = function(_, on)
    ns.Core.SetOption("bountyPublish", on); P.TransportTick(); B.Form.Refresh(); B.Board.Refresh()
  end })
  w.publishOptIn:SetPoint("TOPLEFT", 24, -300)
  Kit.Tooltip(w.publishOptIn, { "Advertise your contributions", "Publishing a bounty enables this automatically with your consent. Turning it off pauses advertising; it does not cancel existing rewards or claims. Use More > Withdraw on a contribution to stop future hunts." })
  w.status = T.Text(w, "body", "warning")
  w.status:SetPoint("BOTTOMLEFT", 24, 64); w.status:SetPoint("RIGHT", -24, 0); w.status:SetJustifyH("LEFT")
  w.done = Kit.Button(w, "Done", 100, 32, { onClick = function() Save(w.threshold); if w.status:GetText() == "" then w:Hide() end end })
  w.done:SetPoint("BOTTOMRIGHT", -24, 22)
  Kit.Tooltip(w.done, { "Save alert preferences", "Save your notification minimum and return to the board." })
  return w
end

function Pref.Open()
  local w = Pref.Build()
  w.receive:SetChecked(P.Receiving(), true); w.publishOptIn:SetChecked(P.Publishing(), true)
  w.threshold:SetText(tostring(ns.Core.O("bountyMinGold") or 0)); w.status:SetText("")
  B.Widgets.ShowWindow(w)
  return w
end
