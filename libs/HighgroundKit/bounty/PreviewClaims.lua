local _, ns = ...
local B, Kit = ns.Bounty, ns.Kit
local Demo = B.Preview

function Demo.OpenClaims()
  Demo.claims = Demo.claims or Demo.Claims()
  if not Demo.claimsWin then
    local actions = {}
    for _, choice in ipairs({ { ns.Locale:Get("shared.boardactions.approve.7b2c7f"), "approved" }, { ns.Locale:Get("shared.ledger.mark_paid.938e0a"), "paid" }, { ns.Locale:Get("shared.ledger.reject.2b03b5"), "rejected" } }) do
      actions[#actions + 1] = { label = choice[1], enabled = function(e)
        return e.claim.previewManage and (choice[2] == "paid" and e.claim.state == "approved"
          or choice[2] ~= "paid" and e.claim.state == "claimed")
      end, run = function(e)
        local c = e.claim
        if not c.previewManage then return false, ns.Locale:Get("shared.previewclaims.this_report_awaits_the_poster_s_review.fdc500") end
        c.state, c.reviewedBy = choice[2], B.Me()
        if c.state == "paid" then c.paidAt = B.Public.Now() end
        return true, ns.Locale:Format("shared.previewclaims.preview_only_claim_c_state_no_gold.d5682e", { c_state = c.state })
      end }
    end
    local w = Kit.Browser((ns.FRAME_PREFIX or "Highground") .. "BountyClaimsPreview", {
      title = ns.Locale:Get("shared.previewclaims.claims_preview.de3abb"), child = true, transient = true, hint = ns.Locale:Get("shared.previewclaims.sample_data_only.67c115"), alpha = 1, strata = "FULLSCREEN_DIALOG", actions = actions,
      width = 820, height = 680, listRatio = 0.36, rowHeight = 62, footerHeight = 36,
      renderDetail = B.ClaimView.Render, renderRow = B.ClaimView.Row,
      data = function()
        local out = {}; for _, c in ipairs(Demo.claims or {}) do
          local e = B.Ledger.Entry(c)
          e.detail = ns.Locale:Format("shared.previewclaims.preview_only_value2_e_detail.912281", { value2 = (c.previewManage and ns.Locale:Get("shared.previewclaims.you_are_the_poster_try_the_review.84238f") or ns.Locale:Get("shared.previewclaims.you_are_the_hunter_this_report_awaits.4398dd")), e_detail = e.detail })
          out[#out + 1] = e
        end
        return out
      end })
    Demo.claimsWin = w
    B.Widgets.BrowserHelp(w, { ns.Locale:Get("shared.previewclaims.approve_this_sample_report_only_preview_data.43f305"),
      ns.Locale:Get("shared.previewclaims.show_a_manually_recorded_payment_on_the.cb8698"), ns.Locale:Get("shared.previewclaims.reject_this_sample_report_real_claims_are.edb1c9") })
    w.back = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.details.back_to_preview.0df1a4"), 154, 26, { onClick = function() w:Hide() end }), "shared.details.back_to_preview.0df1a4")
    w.back:SetPoint("BOTTOMLEFT", 18, 18)
    local function FitBack() w.back:SetWidth(w.back.label:GetStringWidth() + 24) end
    FitBack(); ns.Core.OnFontScaleChange(FitBack)
    Kit.Tooltip(w.back, function() return { ns.Locale:Get("shared.previewclaims.back_to_the_preview.3e42b3"), ns.Locale:Get("shared.previewclaims.return_to_the_scene_selector_without_replaying.10388a") } end)
  end
  local w = Demo.claimsWin
  w:ResetNavigation()
  w:Open(); B.Widgets.ShowWindow(w)
  return w
end
