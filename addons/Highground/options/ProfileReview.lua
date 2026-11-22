local _, ns = ...
local P, Kit, Theme = ns.Options.Profiles, ns.Kit, ns.Theme
local Share = P.Chat

function Share.Progress(message, failed)
  if not Share.win then return end
  Share.win.status:SetText(message or "")
  Theme.Paint(Share.win.status, failed and "danger" or "textMuted")
end
local function Build()
  if Share.win then return Share.win end
  local w = Kit.Dialog("HighgroundProfileReview", { title = "SHARED PROFILE", titleRole = "title", child = true,
    sub = "Review before applying", width = 720, height = 690 + P.CONTEXT_HEIGHT, onClose = function() Share.Cancel() end })
  Share.win = w
  w.summary = Theme.Text(w, "body", "text")
  w.summary:SetPoint("TOPLEFT", 24, -84); w.summary:SetPoint("TOPRIGHT", -24, -84)
  w.summary:SetJustifyH("LEFT"); w.summary:SetJustifyV("TOP"); w.summary:SetWordWrap(true)
  w.reviewTitle = Theme.Text(w, "heading", "accent")
  w.reviewTitle:SetJustifyH("LEFT")
  w.review = Kit.ScrollText(w, { role = "body", bottomPadding = 8 })
  w.review:SetPoint("BOTTOMRIGHT", -24, 202)
  w.name = Kit.Input(w, 380, "Save a copy as")
  w.name:SetPoint("BOTTOMLEFT", 24, 138)
  w.status = Theme.Text(w, "body", "textMuted")
  w.status:SetPoint("BOTTOMLEFT", 24, 78); w.status:SetPoint("BOTTOMRIGHT", -24, 78)
  w.status:SetHeight(48); w.status:SetJustifyH("LEFT"); w.status:SetJustifyV("BOTTOM"); w.status:SetWordWrap(true)
  function w:LayoutReview()
    self.summary:SetHeight(self.summary:GetStringHeight())
    self.reviewTitle:SetPoint("TOPLEFT", self.summary, "BOTTOMLEFT", 0, -16)
    self.reviewTitle:SetPoint("RIGHT", self.details, "LEFT", -12, 0)
    self.details:SetPoint("TOPRIGHT", self.summary, "BOTTOMRIGHT", 0, -12)
    self.review:SetPoint("TOPLEFT", self.reviewTitle, "BOTTOMLEFT", 0, -16)
    self.review:Refresh()
  end
  function w:RefreshReview()
    if not self.snap then self.review:SetText(""); return end
    self.rows = self.receipt or P.Review(self.snap, self.showChanges and P.Snapshot() or nil)
    self.reviewTitle:SetText(self.receiptTitle or (self.showChanges and (#self.rows .. " changes when applied") or "Everything included"))
    self.review:SetText(P.ReviewText(self.rows))
    self.details:SetText(self.showChanges and "All settings" or "Changes when applied")
    self:LayoutReview()
  end
  w.details = Kit.Button(w, "Changes when applied", 230, 32, { onClick = function()
    w.showChanges = not w.showChanges; w.receipt, w.receiptTitle = nil, nil
    w:RefreshReview(); w.review:Scroll(0)
  end })
  w.cancel = Kit.Button(w, "Close", 90, 34, { onClick = function() w:Hide() end })
  w.cancel:SetPoint("BOTTOMLEFT", 24, 24)
  w.apply = Kit.Button(w, "Use this setup", 210, 34, { tone = "accent", onClick = function()
    if not w.text then return end
    local rows = P.Review(w.snap, P.Snapshot())
    local ok, message = P.ImportText(w.text)
    Share.Progress(message, not ok)
    if ok then
      w.receipt, w.receiptTitle = rows, (P.pending and "After combat" or "Applied") .. " · " .. #rows .. " changes"
      w:RefreshReview(); w.apply:SetEnabled(false)
    end
  end })
  w.apply:SetPoint("BOTTOMRIGHT", -24, 24)
  w.save = Kit.Button(w, "Save a copy", 200, 34, { onClick = function()
    if not w.text then return end
    local name = P.CleanName(w.name:GetText())
    if not name then return Share.Progress("Enter a name for this profile.", true) end
    if ns.Core.db.profiles and ns.Core.db.profiles[name] then
      return Share.Progress("That name is already saved. Choose a new name for this copy.", true)
    end
    local ok, message = P.SaveImported(w.text, name)
    Share.Progress(message, not ok)
    if ok then
      w.receipt, w.receiptTitle = P.Review(w.snap), "Saved · Everything included"
      w:RefreshReview()
    end
  end })
  w.save:SetPoint("RIGHT", w.apply, "LEFT", -12, 0)
  P.AttachContext(w, { w.cancel, w.apply, w.status, w.name, w.review })
  w:HookScript("OnSizeChanged", function() if w.details then w:LayoutReview() end end)
  ns.Core.OnFontScaleChange(function() if w:IsVisible() then w:LayoutReview() end end)
  return w
end

-- Shared transfers use the same validated, complete review as local profiles.
function Share.Review(text, source, label)
  local w = Build()
  w.text, w.snap, w.receipt, w.receiptTitle, w.showChanges = nil, nil, nil, nil, false
  w.save:SetEnabled(false); w.apply:SetEnabled(false); w.details:SetEnabled(false)
  w.name:SetText(label or "Shared setup")
  local from = "Shared by " .. ns.Core.DisplayName(source, true)
  w.summary:SetText(from .. "\nWaiting for the profile. Keep this window open to receive it.")
  w.reviewTitle:SetText("Profile contents"); w.review:SetText("")
  Share.Progress("Requesting profile…"); w:Show(); w:LayoutReview()
  if not text then return end
  local snap, err = P.ParseString(text)
  if not snap then return Share.Progress("Cannot import this profile: " .. err, true) end
  local prepared, problem, _, skipped = P.Prepare(snap)
  if not prepared then return Share.Progress("Cannot import this profile: " .. problem, true) end
  w.text, w.snap = text, snap
  local name = P.CleanName(snap.name or label) or "Shared setup"
  local base, suffix = name, 2
  while ns.Core.db.profiles and ns.Core.db.profiles[name] do
    name = base:sub(1, 33) .. " (" .. suffix .. ")"; suffix = suffix + 1
  end
  w.name:SetText(name)
  w.summary:SetText(from .. "\n" .. (prepared.setup and ns.Options.PROFILE_CONTENTS or "This older profile includes targeting settings only.")
    .. "\n" .. ns.Options.PROFILE_EXCLUSIONS)
  w:RefreshReview(); w.review:Scroll(0)
  Share.Progress(skipped > 0 and "Unsupported or retired values are skipped. Save a copy keeps your current settings."
    or "Save a copy keeps current settings. Use this setup applies the included settings.")
  w.save:SetEnabled(true); w.apply:SetEnabled(true); w.details:SetEnabled(true)
end
