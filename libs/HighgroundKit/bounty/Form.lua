local _, ns = ...
local B, Kit, T = ns.Bounty, ns.Kit, ns.Theme
local P, Form = B.Public, {}
B.Form = Form
local MODES = {
  { key = "personal", label = "Only me", hint = "A private target for your alerts. Nothing is sent to other players." },
  { key = "guild", label = "Guild", hint = "Visible to your guild after officer approval. An existing shared reward stays shared, with one payment." },
  { key = "public", label = "Shared", hint = "Visible to participating players on your realm and faction. Claims and payments are manual." },
}

function Form.Refresh(w)
  w = w or Form.win
  if not w then return end
  local shared, guild = w.formMode == "public", w.formMode == "guild"
  w.action:SetText(shared and (P.Publishing() and "Publish shared bounty" or "Enable sharing & publish")
    or guild and "Submit to guild" or "Save private bounty")
  w.duration:SetShown(shared); w.duration.caption:SetShown(shared)
  w.gold.caption:SetText(shared and "YOUR REWARD (GOLD)" or "REWARD IN GOLD (OPTIONAL)")
  w.action:SetEnabled(not guild or B.InGuild())
  w.terms:SetText(shared and "Your gold is checked against all commitments. Gold is not held by the addon."
    or guild and (B.InGuild() and "Guild submissions need officer approval. A cross-posted reward is paid once." or "Join a guild before submitting a bounty.")
    or "Reward is optional. Save a player with no reward to receive personal sightings.")
end

function Form.SetMode(w, key)
  w.formMode = key
  for _, mode in ipairs(MODES) do
    w.modes[mode.key]:SetSelected(mode.key == key)
    if mode.key == key then w.audienceHint:SetText(mode.hint) end
  end
  w.error:SetText("")
  Form.Refresh(w)
end

function Form.Save(w)
  local name, gold, note = w.name:GetText(), w.gold:GetText(), w.note:GetText()
  w.error:SetText("")
  local b, err
  if w.formMode == "public" then
    b, err = P.Post(name, gold, w.duration:GetText(), note, true)
  elseif w.formMode == "guild" then
    if not B.InGuild() then err = "Join a guild before submitting. You can save a private bounty instead."
    else
      local old = B.Guild()[B.Key(name)]
      local shared = P.Own(name)
      if shared and (tonumber(gold) ~= shared.gold or B.Clean(note) ~= shared.note) then
        w.error:SetText("Guild visibility uses your existing " .. shared.gold .. "g contribution. Edit the shared contribution first to change its reward or note.")
        return
      end
      if old and old.state ~= "removed" and not old.publicClosed then err = "This target already has a guild listing. Open it on the Guild board."
      else
        local saved = B.Personal()[B.Key(name)]
        b, err = B.Add(name, gold, note)
        if b then
          b, err = B.Submit(b.name)
          if not b then B.Personal()[B.Key(name)] = saved end
        end
      end
    end
  elseif P.Own(name) or B.GuildSource(name) then
    err = "This bounty is already published. Use More to withdraw it; saving a private copy cannot make it private."
  else b, err = B.Add(name, gold, note) end
  if not b then w.error:SetText(err or "Could not save this bounty."); return end
  w:Hide(); B.Board.SetTab("mine"); B.Emit("updated")
end

function Form.Layout(w)
  local extra = math.max(0, ns.Core.FontScale() - 1)
  w:SetSize(570 + 140 * extra, 580 + 180 * extra)
  local y, step = 194 + extra * 36, 68 + extra * 24
  w.audienceLabel:ClearAllPoints(); w.audienceLabel:SetPoint("TOPLEFT", 24, -166 - extra * 32)
  for i, mode in ipairs(MODES) do
    local button = w.modes[mode.key]
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", 24 + (i - 1) * (w:GetWidth() - 48) / 3, -y)
    button:SetWidth((w:GetWidth() - 64) / 3); button:SetHeight(30 + extra * 12)
  end
  w.audienceHint:ClearAllPoints(); w.audienceHint:SetPoint("TOPLEFT", 24, -y - 40 - extra * 12)
  w.audienceHint:SetPoint("RIGHT", -24, 0); w.audienceHint:SetHeight(38 + extra * 20)
  local inputY = 112 + extra * 24
  w.name:ClearAllPoints(); w.name:SetPoint("TOPLEFT", 24, -inputY); w.name:SetPoint("RIGHT", w.target, "LEFT", -10, 0)
  w.target:ClearAllPoints(); w.target:SetPoint("TOPRIGHT", -24, -inputY); w.target:SetWidth(108 + extra * 40)
  local rewardY = 304 + extra * 76
  w.gold:ClearAllPoints(); w.gold:SetPoint("TOPLEFT", 24, -rewardY)
  w.duration:ClearAllPoints(); w.duration:SetPoint("TOPLEFT", w.gold, "TOPRIGHT", 28, 0)
  w.note:ClearAllPoints(); w.note:SetPoint("TOPLEFT", 24, -rewardY - step); w.note:SetPoint("RIGHT", -24, 0)
  w.terms:ClearAllPoints(); w.terms:SetPoint("TOPLEFT", w.note, "BOTTOMLEFT", 0, -14)
  w.terms:SetPoint("RIGHT", -24, 0); w.terms:SetHeight(40 + extra * 18)
  w.error:SetHeight(48 + extra * 36)
  w.action:SetWidth(260 + extra * 160); w.action:SetHeight(32 + extra * 12)
end

function Form.Build()
  if Form.win then return Form.win end
  local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyCreate", {
    title = "CREATE BOUNTY", width = 570, height = 560, header = 64, accent = "gold", alpha = 1, strata = "FULLSCREEN_DIALOG" })
  Form.win = w
  w.audienceLabel = T.Text(w, "heading", "text")
  w.audienceLabel:SetPoint("TOPLEFT", 24, -82); w.audienceLabel:SetText("Who can see this bounty?")
  w.modes = {}
  for _, mode in ipairs(MODES) do
    w.modes[mode.key] = Kit.Choice(w, mode.label, 160, "radio", function() Form.SetMode(w, mode.key) end)
    Kit.Tooltip(w.modes[mode.key], { mode.label, mode.hint })
  end
  w.audienceHint = T.Text(w, "body", "textMuted"); w.audienceHint:SetJustifyH("LEFT")
  w.audienceHint:SetJustifyV("TOP"); w.audienceHint:SetWordWrap(true)
  w.name = Kit.Input(w, 350, "PLAYER NAME (REALM OPTIONAL)")
  w.target = Kit.Button(w, "Use target", 108, 26, { onClick = function()
    local name, err = B.Board.TargetPlayer()
    if name then w.name:SetText(name); w.error:SetText("") else w.error:SetText(err) end
  end })
  w.gold = Kit.Input(w, 180, "YOUR REWARD (GOLD)")
  w.duration = Kit.Input(w, 180, "EXPIRES AFTER (e.g. 24h)")
  w.note = Kit.Input(w, 500, "NOTE (OPTIONAL)"); w.note:SetMaxLetters(B.NOTE_MAX)
  w.terms = T.Text(w, "body", "textMuted"); w.terms:SetJustifyH("LEFT"); w.terms:SetJustifyV("TOP")
  w.error = T.Text(w, "body", "warning")
  w.error:SetPoint("BOTTOMLEFT", 24, 64); w.error:SetPoint("RIGHT", -24, 0)
  w.error:SetJustifyH("LEFT"); w.error:SetJustifyV("BOTTOM"); w.error:SetWordWrap(true)
  for _, field in ipairs({ w.name, w.gold, w.duration, w.note }) do
    -- A validation result belongs to the submitted draft, not later edits.
    field:HookScript("OnTextChanged", function() w.error:SetText("") end)
  end
  w.cancel = Kit.Button(w, "Cancel", 100, 32, { onClick = function() w:Hide() end })
  w.cancel:SetPoint("BOTTOMLEFT", 24, 22)
  w.action = Kit.Button(w, "", 260, 32, { tone = "gold", onClick = function() Form.Save(w) end })
  w.action:SetPoint("BOTTOMRIGHT", -24, 22)
  Kit.Tooltip(w.name, { "Player to hunt", "Use an exact character name. Include Name-Realm for another realm. Names from different realms are separate targets." })
  Kit.Tooltip(w.target, { "Use your target", "Copy the selected player's exact name and realm, including friendly or unflagged players. This only fills the name; it does not publish anything." })
  Kit.Tooltip(w.gold, { "Your reward", "Whole gold offered by you. Shared rewards must be positive and covered by your carried gold after other commitments. Sharing an existing guild reward does not double it." })
  Kit.Tooltip(w.duration, { "When your contribution expires", "Use 30m, 2h or 7d. Allowed range: 5 minutes to 30 days. Other posters choose their own expiry. An edit can extend, but cannot shorten, an active pledge." })
  Kit.Tooltip(w.note, { "Optional context", "A short note shown to this bounty's audience. It is not an automatically verified kill condition." })
  Kit.Tooltip(w.action, function() return { w.action:GetText(), "Save to the selected audience. Enable sharing & publish also opts you into sending contributions and funding reports. It does not enable receiving other players' bounties." } end)
  Kit.Tooltip(w.cancel, { "Discard this draft", "Close without saving or changing sharing preferences." })
  w.name:SetScript("OnEnterPressed", function(self) self:ClearFocus(); w.gold:SetFocus() end)
  w.gold:SetScript("OnEnterPressed", function(self) self:ClearFocus(); (w.formMode == "public" and w.duration or w.note):SetFocus() end)
  w.duration:SetScript("OnEnterPressed", function(self) self:ClearFocus(); w.note:SetFocus() end)
  w.note:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  Form.Layout(w); ns.Core.OnFontScaleChange(function() Form.Layout(w) end)
  return w
end

function Form.Open(name, mode, source)
  local w = Form.Build()
  name = name or B.Board.TargetPlayer()
  mode = mode or "personal"
  local own = name and P.Own(name)
  local draft = own or source or name and (B.GuildSource(name) or B.Personal()[B.Key(name)])
  w.name:SetText(name or ""); w.gold:SetText(draft and tostring(draft.gold) or "")
  w.note:SetText(draft and draft.note or "")
  w.duration:SetText(own and (math.max(5, math.ceil((own.expiresAt - P.Now()) / 60)) .. "m")
    or ((ns.Core.O("bountyDurationHours") or 24) .. "h"))
  w:SetTitle(draft and "EDIT / SHARE BOUNTY" or "CREATE BOUNTY")
  Form.SetMode(w, mode); B.Widgets.ShowWindow(w); w.name:SetFocus()
  return w
end
