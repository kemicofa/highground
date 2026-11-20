local _, ns = ...
local B, Kit = ns.Bounty, ns.Kit
local Demo = B.Preview

function Demo.OpenClaims()
  Demo.claims = Demo.claims or Demo.Claims()
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
      title = "CLAIMS PREVIEW", child = true, transient = true, hint = "Sample data only", alpha = 1, strata = "FULLSCREEN_DIALOG", actions = actions,
      width = 820, height = 680, listRatio = 0.36, rowHeight = 62, footerHeight = 36,
      renderDetail = B.ClaimView.Render, renderRow = B.ClaimView.Row,
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
    w.back = Kit.Button(w, "Back to preview", 154, 26, { onClick = function() w:Hide() end })
    w.back:SetPoint("BOTTOMLEFT", 18, 18)
    local function FitBack() w.back:SetWidth(w.back.label:GetStringWidth() + 24) end
    FitBack(); ns.Core.OnFontScaleChange(FitBack)
    Kit.Tooltip(w.back, { "Back to the preview", "Return to the scene selector without replaying the alert." })
  end
  local w = Demo.claimsWin
  w:ResetNavigation()
  w:Open(); B.Widgets.ShowWindow(w)
  return w
end

