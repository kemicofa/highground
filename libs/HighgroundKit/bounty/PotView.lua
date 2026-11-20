local _, ns = ...
local B, Kit, T = ns.Bounty, ns.Kit, ns.Theme
local M = B.Pot

local function Place(text, value, x, y, width)
  text:ClearAllPoints(); text:SetPoint("TOPLEFT", x, -y); text:SetWidth(width)
  if value ~= nil then text:SetText(value) end
  text:SetHeight(0); text:SetHeight(math.ceil(text:GetStringHeight()) + 2)
  return text:GetHeight()
end

local function Layout(w)
  if not w.contract then return end
  local scale = math.max(1, ns.Core.FontScale())
  w:SetSize(math.min(720 + (scale - 1) * 180, UIParent:GetWidth() - 40), math.min(700 + (scale - 1) * 160, UIParent:GetHeight() - 40))
  local errorHeight = w.error:GetText() ~= "" and Place(w.error, nil, 24, 0, w:GetWidth() - 48) or 0
  w.error:ClearAllPoints(); w.error:SetPoint("BOTTOMLEFT", 24, 66); w.error:SetShown(errorHeight > 0)
  w.content:ClearAllPoints(); w.content:SetPoint("TOPLEFT", 20, -78)
  w.content:SetPoint("BOTTOMRIGHT", -12, 82 + errorHeight)
  local width = w:GetWidth() - 48
  w.content.body:SetWidth(width)
  local card, entered = w.targetCard, B.Terms.Gold(w.gold:GetText()) or 0
  local amount = w.editing and entered - w.ownGold or entered
  card:ClearAllPoints(); card:SetPoint("TOPLEFT"); card:SetWidth(width)
  for _, key in ipairs({ "status", "trackingLabel", "class", "rewardLabel", "killProgress", "note", "owner", "location", "detail", "rule" }) do card[key]:Hide() end
  local portrait, x = 88 + (scale - 1) * 24, 132 + (scale - 1) * 24
  card.portraitWell:ClearAllPoints(); card.portraitWell:SetPoint("TOPLEFT", 24, -28); card.portraitWell:SetSize(portrait, portrait)
  Place(card.likeness, nil, 18, 36 + portrait, portrait + 12)
  T.SetRole(card.title, "caption")
  local y = 20 + Place(card.title, "WANTED", x, 20, width - x - 24) + 6
  y = y + Place(card.name, nil, x, y, width - x - 24) + 16
  local column = (width - x - 48) / 2
  Place(w.currentLabel, "CURRENT POT", x, y, column)
  y = y + Place(w.newLabel, "WITH YOUR GOLD", x + column + 24, y, column) + 4
  local old = Place(w.current, ns.Util.Gold(w.currentGold), x, y, column)
  local updated = Place(card.reward, ns.Util.Gold(w.currentGold + amount), x + column + 24, y, column)
  y = y + math.max(old, updated) + 12
  y = y + Place(w.perKill, "Gold per approved kill", x, y, width - x - 24) + 16
  card:SetHeight(math.max(y, portrait + card.likeness:GetHeight() + 54)); card:Show()
  y = card:GetHeight() + 42
  w.gold:ClearAllPoints(); w.gold:SetPoint("TOPLEFT", 4, -y); w.gold:SetSize(width - 8, 38 * scale)
  y = y + w.gold:GetHeight() + 10
  Kit.LayoutGrid(w.amounts, { width = width - 8, columns = 4, height = 30 * scale, x = 4, y = -y })
  for _, button in ipairs(w.amounts) do button:SetSelected(not w.editing and amount == button.amount) end
  y = y + 30 * scale + 14
  local total = (w.ownGold + amount) * w.remaining
  y = y + Place(w.commitment, "Your reward: " .. ns.Util.Gold(w.ownGold + amount) .. " per kill · up to " .. ns.Util.Gold(total)
    .. " for " .. w.remaining .. " remaining " .. (w.remaining == 1 and "kill" or "kills"), 4, y, width - 8) + 22
  y = y + Place(w.conditions, nil, 4, y, width - 8) + 14
  y = y + Place(w.terms, nil, 4, y, width - 8) + 10
  w.content.body:SetHeight(y); w.content:Refresh()
  w.add:SetSize(w.add.label:GetStringWidth() + 30, 32 * scale)
  w.cancel:SetSize(w.cancel.label:GetStringWidth() + 30, 32 * scale)
end

function M.Open(source, preview)
  if not source then return end
  local field = preview and "previewWin" or "win"
  if not M[field] then
    local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyAddGold" .. (preview and "Preview" or ""), {
      title = preview and "PREVIEW · RAISE THE REWARD" or "RAISE THE REWARD", width = 720, height = 700, header = 64, alpha = 1, child = true,
      strata = "FULLSCREEN_DIALOG", accent = "gold" })
    M[field], w.preview = w, preview
    w.content = Kit.ScrollArea(w)
    w.targetCard = B.Wanted.Build(w.content.body)
    local card = w.targetCard
    w.summary = card.name
    w.currentLabel, w.newLabel = B.Wanted.Text(card, "caption", "posterMuted"), B.Wanted.Text(card, "caption", "posterStamp")
    w.current, w.perKill = B.Wanted.Text(card, "displayLarge", "posterMuted"), B.Wanted.Text(card, "bodySmall", "posterMuted")
    for _, text in ipairs({ w.currentLabel, w.newLabel, w.current, w.perKill }) do text:SetJustifyH("CENTER") end
    w.gold = Kit.Input(w.content.body, 560, "YOUR GOLD TO ADD · PER APPROVED KILL")
    T.SetRole(w.gold, "number")
    w.amounts = {}
    for i, amount in ipairs({ "10", "50", "100", "500" }) do
      local button = Kit.Choice(w.content.body, "+" .. amount .. "g", 100, "check", function() w.gold:SetText(tostring((w.editing and w.ownGold or 0) + tonumber(amount))); w.gold:ClearFocus() end)
      button.amount = tonumber(amount); w.amounts[i] = button
    end
    w.commitment, w.conditions, w.terms = T.Text(w.content.body, "body", "gold"), T.Text(w.content.body, "body", "text"), T.Text(w.content.body, "bodySmall", "textMuted")
    for _, text in ipairs({ w.commitment, w.conditions, w.terms }) do text:SetWordWrap(true); text:SetJustifyH("LEFT"); text:SetJustifyV("TOP") end
    w.error = T.Text(w, "body", "warning"); w.error:SetWordWrap(true); w.error:SetJustifyH("LEFT")
    w.cancel = Kit.Button(w, "Cancel", 100, 32, { onClick = function() w:Hide() end }); w.cancel:SetPoint("BOTTOMLEFT", 24, 24)
    w.add = Kit.Button(w, "Accept terms & add gold", 300, 32, { tone = "gold", onClick = function()
      if preview then return B.Preview.AddGold(w) end
      local current = M.Source(w.sourceID)
      if not current or not M.SameContract(M.Contract(current), w.contract) then
        w.error:SetText("The original bounty changed. Reopen the reward and review its terms."); w:Layout(); return
      end
      if w.editing and current.gold ~= w.ownGold then
        w.error:SetText("Your reward changed while this editor was open. Reopen Edit reward to review the current amount."); w:Layout(); return
      end
      local amount = B.Terms.Gold(w.gold:GetText())
      if w.editing then
        if not amount or amount < w.ownGold then w.error:SetText("An active reward can only be increased."); w:Layout(); return end
        if amount == w.ownGold then w:Hide(); return end
        amount = amount - w.ownGold
      end
      local b, err = M.Add(current, amount, true)
      if not b then w.error:SetText(err); w:Layout(); return end
      w:Hide(); B.Say("Reward updated. Open the bounty and choose Share bounty to send the updated link.")
    end }); w.add:SetPoint("BOTTOMRIGHT", -24, 24)
    w.Layout = Layout
    w.gold:HookScript("OnTextChanged", function() w.error:SetText(""); w:Layout() end)
    ns.Core.OnFontScaleChange(function() w:Layout() end)
  end
  local w = M[field]
  local pot = preview and B.Preview.bounty or M.Find(source.name)
  w.sourceID, w.contract = M.ID(source), M.Contract(source)
  local own = preview and B.Preview.state.addedContribution or not preview and M.Own(source.name)
  local progress = own or not preview and M.Source(w.contract.id) or source
  local approved = preview and (B.Preview.state.approved or 0)
    or math.max(progress.killsAwarded or B.Ledger.Progress(progress), M.DecisionProgress(w.contract.id))
  w.currentGold, w.ownGold, w.remaining = pot and pot.pledgedGold or source.gold, own and own.gold or 0, math.max(0, B.Terms.Count(w.contract) - approved)
  local display = B.Public.Copy(source); display.note = ""
  B.Wanted.Fill(w.targetCard, display, { preview = preview, width = 600, portraitLabel = source.previewPortraitLabel })
  local audience = ({ private = "Private reward", guild = "Guild reward", community = B.Organizations.Label(source), global = "Shared reward" })[w.contract.audience]
  w.conditions:SetText(audience .. " · Reviewed by " .. ns.Core.DisplayName(w.contract.by)
    .. "\nExpires " .. date("%d %b · %H:%M", w.contract.expiresAt)
    .. (B.Terms.Methods(w.contract) ~= "" and ("\nPreferred finish: " .. B.Terms.Methods(w.contract)) or "")
    .. (w.contract.note ~= "" and ("\n" .. w.contract.note) or ""))
  w.terms:SetText("Adding gold accepts the original poster's completion decision. If they accept a claim, you owe your contribution to the same hunter. Pay through the game; no gold moves now.")
  w.editing = not preview and own and (source.by == B.Me() or source.id and B.Public.Mine(source)) or false
  w:SetTitle(w.editing and "EDIT REWARD" or preview and "PREVIEW · ADD GOLD" or "ADD GOLD")
  w.gold.caption:SetText(w.editing and "YOUR REWARD · GOLD PER APPROVED KILL" or "GOLD TO ADD · PER APPROVED KILL")
  w.add:SetText(w.editing and "Save reward" or "Accept terms & add gold")
  if w.editing then
    w.terms:SetText(own.contract and "Your contribution follows the original poster's terms and claim decisions. Pay approved claims through the game."
      or "You review hunters' claims and pay approved rewards through the game. Published terms stay fixed; no gold moves now.")
  end
  w.gold:SetText(w.editing and tostring(w.ownGold) or ""); w.error:SetText(""); w:Layout(); w.content:Scroll(0)
  B.Widgets.ShowWindow(w); w.gold:SetFocus()
  return w
end

function M.Default(name)
  local own = M.Own(name)
  if own then return own end
  local pot = M.Find(name)
  local source
  for _, p in ipairs(pot and pot.contributions or {}) do
    if p.state ~= "pending" and (not source or (p.createdAt or p.potAt or p.at) < (source.createdAt or source.potAt or source.at)) then source = p end
  end
  return source
end

B.Listen("scope", function() if M.win then M.win:Hide() end end)
