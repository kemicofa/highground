local _, ns = ...
local B, Kit = ns.Bounty, ns.Kit
local E = B.Exchange

local function LayoutShare(w)
  local scale = math.max(1, ns.Core.FontScale())
  w:SetSize(math.min(720 + (scale - 1) * 240, UIParent:GetWidth() - 40), math.min(560 + (scale - 1) * 160, UIParent:GetHeight() - 40))
  w.hint:SetHeight(0); w.hint:SetHeight(math.ceil(w.hint:GetStringHeight()) + 2)
  w.copyLabel:ClearAllPoints(); w.copyLabel:SetPoint("TOPLEFT", w.hint, "BOTTOMLEFT", 8, -22)
  w.copyLabel:SetWidth(w:GetWidth() - 40); w.copyLabel:SetHeight(0); w.copyLabel:SetHeight(w.copyLabel:GetStringHeight() + 2)
  w.instructions:ClearAllPoints(); w.instructions:SetPoint("BOTTOMLEFT", 20, 104 * scale)
  w.instructions:SetWidth(w:GetWidth() - 40); w.instructions:SetHeight(0); w.instructions:SetHeight(w.instructions:GetStringHeight() + 2)
  w.destination:ClearAllPoints(); w.destination:SetPoint("BOTTOMLEFT", w.instructions, "TOPLEFT", 0, 10)
  w.destination:SetWidth(w:GetWidth() - 40); w.destination:SetHeight(0); w.destination:SetHeight(w.destination:GetStringHeight() + 2)
  w.well:ClearAllPoints(); w.well:SetPoint("TOPLEFT", w.copyLabel, "BOTTOMLEFT", -2, -12)
  w.well:SetPoint("BOTTOMRIGHT", -18, 104 * scale + w.instructions:GetHeight() + w.destination:GetHeight() + 34)
  w.status:ClearAllPoints(); w.status:SetPoint("BOTTOMLEFT", 20, 32 * scale + 30)
  w.status:SetPoint("RIGHT", -20, 0); w.status:SetHeight(44 * scale)
  for _, button in ipairs({ w.actions.link, w.actions.options, w.done }) do
    button:SetSize(button.label:GetStringWidth() + 30, 30 * scale)
  end
  w.done:ClearAllPoints(); w.done:SetPoint("BOTTOMLEFT", 20, 18)
  w.actions.link:ClearAllPoints(); w.actions.link:SetPoint("BOTTOMRIGHT", -20, 18)
  w.actions.options:ClearAllPoints(); w.actions.options:SetPoint("LEFT", w.done, "RIGHT", 12, 0)
  w.box:SetWidth(w:GetWidth() - 84)
end

local function Copy(title, text, code, preview)
  local field = preview and "previewProofWin" or "proofWin"
  if not E[field] then E[field] = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "BountyExport" .. (preview and "Preview" or ""), {
    title = title, width = 700, height = 550, strata = "FULLSCREEN_DIALOG", alpha = 1,
    buttons = { { key = "code", label = "Select import code", width = 190, onClick = function(w)
      if w.code then w.box:SetFocus(); w.box:HighlightText(#w:GetText() - #w.code, #w:GetText()) end
    end } } }) end
  local w = E[field]
  if not preview then E.copyWin = w end
  w.code = code; w.actions.code:SetShown(code ~= nil)
  w:Open(title, "Ctrl+A, Ctrl+C to copy. Paste in the destination shown below.", text, true)
  B.Widgets.ShowWindow(w)
  return w
end

local function Discord(w, invite)
  if not E.destinationWin then E.destinationWin = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "BountyDiscord", {
    title = "OPEN DISCORD", width = 620, height = 280, strata = "FULLSCREEN_DIALOG", alpha = 1 }) end
  local d = E.destinationWin
  d.preview = w.preview
  d.done:SetText("Back to sharing"); d.done:SetWidth(160)
  d:Open(invite and "JOIN THE DISCORD" or "OPEN THE BOUNTY CHANNEL",
    "Press Ctrl+C, then paste this web address into your browser.", invite and E.INVITE or w.channelURL, true)
  d:SetStatus("Return to sharing to copy your bounty. This address only opens Discord.")
  B.Widgets.ShowWindow(d)
end

local function Share(b, audience, code, preview)
  local field = preview and "previewShareWin" or "shareWin"
  local w = E[field]
  if not w then
    w = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "BountyShare" .. (preview and "Preview" or ""), {
      title = "SHARE BOUNTY", width = 720, height = 560, header = 64, alpha = 1,
      buttons = {
        { key = "link", label = "Select to copy", tone = "gold", onClick = function(self) self:SelectPayload(self.payloadMode or "link") end },
        { key = "options", label = "Sharing options", onClick = function(self)
          local items = {
            { text = "Bounty link", run = function() self:SelectPayload("link") end },
            { text = "Include a readable description", run = function() self:SelectPayload("post") end },
            { text = "Raw import code (advanced)", run = function() self:SelectPayload("code") end },
          }
          if self.audience == "global" then
            items[#items + 1] = { text = "Open Discord channel instructions", run = function() Discord(self) end }
            items[#items + 1] = { text = "Join Discord instructions", run = function() Discord(self, true) end }
          end
          Kit.Dropdown.Open(self.actions.options, items, function(item) item.run() end, { width = 330 * math.max(1, ns.Core.FontScale()) })
        end },
      } })
    E[field], w.preview = w, preview
    w.LayoutShare, w.bountyLink = LayoutShare, w.actions.link
    local T = ns.Theme
    w.copyLabel, w.destination = T.Text(w, "heading", "gold"), T.Text(w, "heading", "gold")
    w.instructions = T.Text(w, "body", "textMuted")
    for _, text in ipairs({ w.copyLabel, w.destination, w.instructions }) do text:SetJustifyH("LEFT"); text:SetJustifyV("TOP"); text:SetWordWrap(true) end
    w.status:SetJustifyV("TOP")
    function w:SelectPayload(mode)
      mode = mode == true and "code" or mode == false and "post" or mode or "link"
      self.payloadMode = mode
      self.box:SetText(mode == "code" and self.code or mode == "post" and self.post or self.bountyURL)
      self.copyLabel:SetText(mode == "code" and "1. Copy the raw code · advanced" or mode == "post" and "1. Copy the bounty and description" or "1. Copy your bounty link")
      self.box:SetFocus(); self.box:HighlightText(); self.scroll:SetVerticalScroll(0)
      self:SetStatus("Text selected. Press Ctrl+C, then send it to another player.")
      if self.preview then self:SetStatus("Press Ctrl+C to practice. This sample works only in the tour's Import sample window.") end
      LayoutShare(self)
    end
    ns.Core.OnFontScaleChange(function() if w:IsShown() then LayoutShare(w) end end)
  end
  w.code, w.audience, w.channelURL = code, audience, E.URL("board") or E.INVITE
  w.bountyURL = (E.LINK or "highground://bounty/") .. code:gsub("%+", "-"):gsub("/", "_")
  w.post = "WANTED: " .. ns.Core.DisplayName(b.name) .. "\n" .. B.Terms.Summary(b)
    .. "\nPosted by: " .. ns.Core.DisplayName(b.by) .. "\nRealmset/realm: " .. B.Scope.Label()
    .. (b.note and b.note ~= "" and ("\nNote: " .. b.note) or "")
    .. "\n\nPaste this link in Highground > Bounties > Import bounty:\n" .. w.bountyURL
  if preview then w.post = "SAMPLE ONLY · Nothing published.\n\n" .. w.post end
  w.destination:SetText("2. Send it; the recipient imports it")
  w.instructions:SetText(preview and "Nothing is sent or published. Return to the tour and choose Import sample to practice pasting this link."
    or "Send it in a message or Discord. The recipient opens Bounties → Import bounty, pastes it, then chooses Review import. This is an addon link, not a web page.")
  w.hint:SetWordWrap(true)
  w:Open(preview and "PREVIEW · SHARE BOUNTY" or "SHARE BOUNTY", ns.Core.DisplayName(b.name) .. " · " .. ns.Util.Gold(b.gold)
    .. " per approved kill\n" .. (preview and "Practice sharing this sample bounty."
      or audience == "global" and "Already published in game. Sending a link is optional."
      or audience == "community" and "Share with your community." or audience == "guild" and "Share with your guild." or "Share in a private message."), w.bountyURL, true)
  w:SelectPayload("link")
  if not preview then E.copyWin = w end
  return w
end

function E.PreviewShare(b, audience)
  return Share(b, audience, B.Preview.CODE, true)
end

function E.Show(b, audience)
  local code, err = E.Encode(b, audience)
  if not code then B.Say(err); return end
  return Share(b, audience, code)
end

function E.Proof(item)
  local b = item.bounty
  local text = "Target: " .. ns.Core.DisplayName(b.name) .. "\nHunter: " .. ns.Core.DisplayName(B.Me())
    .. "\nRuleset/realm: " .. (item.ruleset or B.Scope.Label()) .. "\nDate: " .. date("%Y-%m-%d %H:%M:%S", item.at) .. " (local time)"
    .. "\nLocation: " .. (item.zone or "Unknown") .. "\nEvidence: " .. item.evidence
    .. "\nKilling blow: " .. B.Kills.CauseText(item.cause) .. "\n" .. (item.preview and B.Preview.Progress(b) or B.Terms.Progress(b))
    .. "\nScreenshot: " .. (item.preview and "Simulated only; no file created"
      or item.screenshot and "Saved successfully in WoW/Screenshots" or "Not confirmed; attach a screenshot or video manually")
  if item.global then
    text = "Join Discord: " .. E.INVITE .. "\nPost proof: " .. (E.URL("proof", item.ruleset) or "Choose your ruleset's proof channel.")
      .. "\nLink the original global bounty post. Attach the screenshot and a clip for a preferred finish.\n\n" .. text
    for _, p in ipairs(b.contributions or {}) do
      text = text .. "\n\nContribution: " .. p.id .. "\nPoster: " .. ns.Core.DisplayName(p.by) .. "\n" .. B.Terms.Summary(p)
    end
  else text = text .. "\n\n" .. B.Terms.Summary(b) .. "\nKeep proof within this bounty's private/guild audience." end
  if item.preview then text = "SAMPLE PROOF · No kill recorded or screenshot taken.\n\n" .. text end
  return Copy(item.preview and "PREVIEW · BOUNTY PROOF" or item.global and "POST GLOBAL BOUNTY PROOF" or "BOUNTY PROOF", text, nil, item.preview)
end

function E.OpenImport(text, preview)
  local field = preview and "previewImportWin" or "importWin"
  if not E[field] then
    E[field] = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "BountyCodeImport" .. (preview and "Preview" or ""), {
      title = "IMPORT BOUNTY", width = 700, height = 550, strata = "FULLSCREEN_DIALOG", alpha = 1,
      onText = function(w)
        if w.renderingReview then return end
        w.reviewed, w.existing, w.reviewText = nil, nil, nil; w:SetStatus("")
        if w.actions.review then w.actions.review:SetText("Review import") end
      end,
      buttons = { { key = "review", label = "Review import", width = 200, onClick = function(w)
        local code = w.reviewed and w:GetText() == w.reviewText and w.reviewed or w:GetText()
        local value, err
        if preview then value, err = B.Preview.DecodeSample(code) else value, err = E.Decode(code) end
        if not value then w:SetStatus(err, "warning"); return end
        local existing = not preview and value.audience ~= "global" and B.Personal()[B.Key(value.bounty.name)] or nil
        if not w.reviewed or w.existing ~= existing then
          w.reviewed, w.existing = code, existing
          w.actions.review:SetText(existing and "Replace private bounty" or "Confirm import")
          local notice = value.audience == "global" and "Enable receiving; import an unverified global offer."
            or (value.audience == "guild" or value.audience == "community") and "Save as a private draft; organization approval is separate." or "Save for private alerts."
          local b = value.bounty
          local review = (preview and "SAMPLE IMPORT · Nothing will be saved or received.\n\n" or "")
            .. "Audience: " .. value.audience:upper() .. "\nTarget: " .. ns.Core.DisplayName(b.name)
            .. "\nPoster: " .. ns.Core.DisplayName(b.by) .. "\nRealm/ruleset: " .. B.Scope.Label()
            .. "\n\n" .. B.Terms.Summary(b) .. "\nNote: " .. (b.note ~= "" and b.note or "None")
            .. (b.expiresAt and ("\nExpires: " .. date("%Y-%m-%d %H:%M", b.expiresAt) .. " (local time)") or "")
            .. (existing and ("\n\nREPLACES YOUR PRIVATE BOUNTY:\n" .. B.Terms.Summary(existing) .. "\nNote: " .. (existing.note or "None")) or "")
            .. "\n\n" .. notice .. "\n\nOriginal import code:\n" .. code
          if value.contributions then
            local total, details = 0, ""
            for _, p in ipairs(value.contributions) do
              total = total + p.gold
              details = details .. "\n\n" .. ns.Core.DisplayName(p.by) .. ": " .. B.Terms.Summary(p)
                .. (p.contract and ("\nCompletion decided by " .. ns.Core.DisplayName(p.contract.by)) or "")
            end
            review = "MEGA BOUNTY · " .. ns.Util.Gold(total) .. " per approved kill · " .. #value.contributions .. " contributors"
              .. details .. "\n\n" .. review
          end
          w.renderingReview = true; w.box:SetText(review); w.renderingReview = nil
          w.reviewText = w:GetText(); w.box:ClearFocus(); w.scroll:SetVerticalScroll(0)
          w:SetStatus("Review the details above, then confirm or close without importing.", "text")
          return
        end
        if preview then
          B.Preview.Notice("Sample import confirmed. No real bounty or receiving setting changed.")
          w:Hide(); return
        end
        local b, message = E.Import(value, w.existing)
        if not b then w:SetStatus(message, "warning"); return end
        w:Hide(); B.Board.Open(); B.Board.SetTab(value.audience == "global" and "public" or "mine"); B.Say(message)
      end } },
    })
    E[field].box:SetMaxLetters((E.POT_MAX or E.MAX) + 8192)
    E[field].status:SetHeight(70); E[field].status:SetJustifyV("BOTTOM")
    E[field].well:ClearAllPoints(); E[field].well:SetPoint("TOPLEFT", 18, -90); E[field].well:SetPoint("BOTTOMRIGHT", -18, 140)
  end
  local w = E[field]
  w.reviewed = nil
  w:Open(preview and "PREVIEW · IMPORT BOUNTY" or "IMPORT BOUNTY", "Paste the bounty link you received, then choose Review import. Older codes and complete posts also work.", text or "", false)
  w.actions.review:SetText("Review import"); B.Widgets.ShowWindow(w)
  return w
end

B.Listen("scope", function()
  if E.destinationWin then E.destinationWin:Hide() end
  if E.copyWin then E.copyWin:Hide() end
  if E.shareWin then E.shareWin:Hide() end
  if E.proofWin then E.proofWin:Hide() end
  if E.importWin then E.importWin.reviewed = nil; E.importWin:Hide() end
end)
