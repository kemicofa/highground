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
  local w = ns.Localization.BindWidget(Kit.Dialog("HighgroundProfileReview", { title = ns.Locale:Get("highground.profilereview.shared_profile.1deaa4"), titleRole = "title", child = true,
    sub = ns.Locale:Get("highground.profilereview.review_before_applying.a1d4a8"), width = 720, height = 690 + P.CONTEXT_HEIGHT, onClose = function() Share.Cancel() end }), { title = "highground.profilereview.shared_profile.1deaa4", sub = "highground.profilereview.review_before_applying.a1d4a8" })
  Share.win = w
  w.summary = Theme.Text(w, "body", "text")
  w.summary:SetPoint("TOPLEFT", 24, -84); w.summary:SetPoint("TOPRIGHT", -24, -84)
  w.summary:SetJustifyH("LEFT"); w.summary:SetJustifyV("TOP"); w.summary:SetWordWrap(true)
  w.reviewTitle = Theme.Text(w, "heading", "accent")
  w.reviewTitle:SetJustifyH("LEFT")
  w.review = Kit.ScrollText(w, { role = "body", bottomPadding = 8 })
  w.review:SetPoint("BOTTOMRIGHT", -24, 202)
  w.name = ns.Localization.BindWidget(Kit.Input(w, 380, ns.Locale:Get("highground.profilereview.save_a_copy_as.8f5b90")), { caption = "highground.profilereview.save_a_copy_as.8f5b90" })
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
    self.reviewTitle:SetText(self.receiptTitle or (self.showChanges and (ns.Locale:Format("highground.profilereview.value1_changes_when_applied.e1b3cc", { value1 = #self.rows })) or ns.Locale:Get("highground.profilereview.everything_included.6adb07")))
    self.review:SetText(P.ReviewText(self.rows))
    self.details:SetText(self.showChanges and ns.Locale:Get("highground.profilereview.all_settings.0f803e") or ns.Locale:Get("highground.profilereview.changes_when_applied.315ff2"))
    self:LayoutReview()
  end
  w.details = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.profilereview.changes_when_applied.315ff2"), 230, 32, { onClick = function()
    w.showChanges = not w.showChanges; w.receipt, w.receiptTitle = nil, nil
    w:RefreshReview(); w.review:Scroll(0)
  end }), "highground.profilereview.changes_when_applied.315ff2")
  w.cancel = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.profilereview.close.bbfa77"), 90, 34, { onClick = function() w:Hide() end }), "highground.profilereview.close.bbfa77")
  w.cancel:SetPoint("BOTTOMLEFT", 24, 24)
  w.apply = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.profilereview.use_this_setup.83b357"), 210, 34, { tone = "accent", onClick = function()
    if not w.text then return end
    local rows = P.Review(w.snap, P.Snapshot())
    local ok, message = P.ImportText(w.text)
    Share.Progress(message, not ok)
    if ok then
      w.receipt, w.receiptTitle = rows, ns.Locale:Format("highground.profilereview.value1_value3_changes.fbba38", { value1 = (P.pending and ns.Locale:Get("highground.profilecontext.after_combat.09bba6") or ns.Locale:Get("highground.profiles.applied.a3e4a5")), value3 = #rows })
      w:RefreshReview(); w.apply:SetEnabled(false)
    end
  end }), "highground.profilereview.use_this_setup.83b357")
  w.apply:SetPoint("BOTTOMRIGHT", -24, 24)
  w.save = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.profilereview.save_a_copy.9056f9"), 200, 34, { onClick = function()
    if not w.text then return end
    local name = P.CleanName(w.name:GetText())
    if not name then return Share.Progress(ns.Locale:Get("highground.profilereview.enter_a_name_for_this_profile.b95770"), true) end
    if ns.Core.db.profiles and ns.Core.db.profiles[name] then
      return Share.Progress(ns.Locale:Get("highground.profilereview.that_name_is_already_saved_choose_a.070d37"), true)
    end
    local ok, message = P.SaveImported(w.text, name)
    Share.Progress(message, not ok)
    if ok then
      w.receipt, w.receiptTitle = P.Review(w.snap), ns.Locale:Get("highground.profilereview.saved_everything_included.e9d774")
      w:RefreshReview()
    end
  end }), "highground.profilereview.save_a_copy.9056f9")
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
  w.name:SetText(label or ns.Locale:Get("highground.profilereview.shared_setup.cbfeaa"))
  local from = ns.Locale:Format("highground.profilereview.shared_by_value2.e02e44", { value2 = ns.Core.DisplayName(source, true) })
  w.summary:SetText(ns.Locale:Format("highground.profilereview.from_waiting_for_the_profile_keep_this.4a512c", { from = from }))
  ns.Localization.Bind(w.reviewTitle, "highground.profilereview.profile_contents.8fe675"); w.review:SetText("")
  Share.Progress(ns.Locale:Get("highground.profilereview.requesting_profile.868ad7")); w:Show(); w:LayoutReview()
  if not text then return end
  local snap, err = P.ParseString(text)
  if not snap then return Share.Progress(ns.Locale:Format("highground.profilereview.cannot_import_this_profile_err.e9aa58", { err = err }), true) end
  local prepared, problem, _, skipped = P.Prepare(snap)
  if not prepared then return Share.Progress(ns.Locale:Format("highground.profilereview.cannot_import_this_profile_problem.682235", { problem = problem }), true) end
  w.text, w.snap = text, snap
  local name = P.CleanName(snap.name or label) or ns.Locale:Get("highground.profilereview.shared_setup.cbfeaa")
  local base, suffix = name, 2
  while ns.Core.db.profiles and ns.Core.db.profiles[name] do
    name = base:sub(1, 33) .. " (" .. suffix .. ")"; suffix = suffix + 1
  end
  w.name:SetText(name)
  w.summary:SetText(from .. "\n" .. (prepared.setup and ns.Options.PROFILE_CONTENTS or ns.Locale:Get("highground.profilereview.this_older_profile_includes_targeting_settings_only.c89c5e"))
    .. "\n" .. ns.Options.PROFILE_EXCLUSIONS)
  w:RefreshReview(); w.review:Scroll(0)
  Share.Progress(skipped > 0 and ns.Locale:Get("highground.profilereview.unsupported_or_retired_values_are_skipped_save.aaf2c2")
    or ns.Locale:Get("highground.profilereview.save_a_copy_keeps_current_settings_use.40bf73"))
  w.save:SetEnabled(true); w.apply:SetEnabled(true); w.details:SetEnabled(true)
end
