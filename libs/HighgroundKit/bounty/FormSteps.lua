local _, ns = ...
local B, Kit, T = ns.Bounty, ns.Kit, ns.Theme
local F, P = B.Form, B.Public
local LABELS = { "Target", "Reward", "Review" }

function F.Step(w, step)
  for _, input in ipairs({ w.name, w.gold, w.duration, w.note, w.kills }) do input:ClearFocus() end
  w.step = math.max(1, math.min(3, step))
  w.error:SetText("")
  F.Refresh(w)
  w.fields:Scroll(0)
end

function F.ValidateStep(w, step)
  local name = P.Name(F.Name(w))
  if not name or name == B.Me() and not w.preview then return "Enter another player's name.", w.name end
  if w.formMode == "guild" and not w.preview and not B.Organizations.Member(w.organizationID) then
    return "Join a guild or community, choose it here, or select Only me.", w.name
  end
  if step == 1 then return end
  local gold = B.Terms.Gold(w.gold:GetText())
  if not gold or w.formMode == "public" and gold < 1 then
    return "Enter a whole gold amount" .. (w.formMode == "public" and " of at least 1g." or ", or leave it blank for tracking."), w.gold
  end
  if w.formMode == "public" and not P.Duration(w.duration:GetText()) then
    return "Choose an expiry from 5 minutes to 30 days.", w.duration
  end
  local terms, err = B.Terms.Validate(tonumber(w.kills:GetText()) or 0, B.TermsEditor.Read(w).killMethods)
  if not terms then w.customize = true; return err, w.kills end
  -- Saving cuts a longer note at a byte, not a letter: block it instead.
  local note = B.Clean(w.note:GetText())
  if #note > B.NOTE_MAX then
    return ns.Locale:Format("bounty.form.note_too_long", { max = B.NOTE_MAX, used = #note }), w.note
  end
  if w.preview then
    local wallet = B.Preview.Wallet()
    if wallet.required and gold * terms.killsRequired * 10000 > wallet.available then
      return "Not enough sample gold. Change the reward or open Gold & settings.", w.gold
    end
  else
    local own = P.Own(name)
    local warning = P.FundingWarning(gold * terms.killsRequired, own and own.id, B.GuildSource(name))
    if warning and B.Gold.Required() then return warning, w.gold end
  end
end

function F.Advance(w)
  local err, field = F.ValidateStep(w, w.step)
  if err then
    F.Step(w, field == w.name and 1 or 2)
    w.error:SetText(err)
    if field:IsShown() then field:SetFocus() end
    return
  end
  if w.step < 3 then F.Step(w, w.step + 1) else F.Save(w) end
end

-- Match the journal profile's hierarchy: accented identity, one stats strip,
-- then labelled details. These are read-only facts, not another set of controls.
local function ReviewText(parent, role, color, text)
  local fs = Kit.Paragraph(parent, role, color)
  fs:SetNonSpaceWrap(true); fs:SetText(text or "")
  return fs
end

local function BuildReview(w)
  local p = CreateFrame("Frame", nil, w.fields.body)
  p.hero = Kit.Hero(p, "gold")
  p.strip = p.hero.strip
  p.audienceLabel = ReviewText(p.hero, "caption", "textMuted", "VISIBLE TO")
  p.audience = ReviewText(p.hero, "displayLarge", "gold")
  p.audienceHint = ReviewText(p.hero, "body", "textMuted")
  -- The commitment as labelled facts on one well.
  p.stats = CreateFrame("Frame", nil, p)
  T.Fill(p.stats, "BACKGROUND", "well"):SetAllPoints()
  p.metrics = {}
  for i, spec in ipairs({ { "Kill goal", "info" }, { "Expires in", "text" }, { "Max reward", "gold" } }) do
    p.metrics[i] = Kit.KeyValue(p.stats, { label = spec[1], role = "readout", tone = spec[2] })
  end
  p.conditionsLabel = ReviewText(p, "caption", "gold", "HUNT CONDITIONS")
  p.conditions = ReviewText(p, "bodyLarge", "text")
  p.nextRule = T.Fill(p, "ARTWORK", "border")
  p.nextLabel = ReviewText(p, "caption", "gold", "WHAT HAPPENS NEXT")
  w.terms:SetParent(p)
  return p
end

local function ReviewDetails(w, width, terms, gold, count)
  local p, pad = w.review, 14
  p:SetWidth(width)
  local shared, guild = w.formMode == "public", w.formMode == "guild"
  p.audience:SetText(shared and "Shared board" or guild and B.Organizations.Label(w.organizationID) or "Only me")
  p.audienceHint:SetText(shared and "Hunters on your realm and faction"
    or guild and "Members of your organization" or "Private tracking and alerts")
  p.metrics[1].value:SetText(tostring(count))
  p.metrics[2].value:SetText(w.duration:GetText()); p.metrics[2]:SetShown(shared)
  p.metrics[3].value:SetText(ns.Util.Gold(gold * count))
  local methods = B.Terms.Methods(terms)
  p.conditions:SetText(methods ~= "" and ("Preferred finish: " .. methods) or "Any finish")
  local function Place(text, x, y, span)
    Kit.Place(text, "TOPLEFT", text:GetParent(), "TOPLEFT", x, -y, math.max(1, span), 0)
    text:SetHeight(math.ceil(text:GetStringHeight()) + 2)
    return text:GetHeight()
  end
  local inner, y = width - 2 * pad, pad
  y = y + Place(p.audienceLabel, pad, y, inner) + 6
  y = y + Place(p.audience, pad, y, inner) + 5
  y = y + Place(p.audienceHint, pad, y, inner) + pad
  Kit.Place(p.hero, "TOPLEFT", p, "TOPLEFT", 0, 0, width, y)
  local statsHeight = 12
  for _, metric in ipairs(p.metrics) do
    if metric:IsShown() then
      Kit.Place(metric, "TOPLEFT", p.stats, "TOPLEFT", pad, -statsHeight)
      statsHeight = statsHeight + metric:Layout(inner) + 8
    end
  end
  statsHeight = statsHeight + 4
  Kit.Place(p.stats, "TOPLEFT", p, "TOPLEFT", 0, -y, width, statsHeight)
  y = y + statsHeight + 20
  y = y + Place(p.conditionsLabel, pad, y, inner) + 7
  y = y + Place(p.conditions, pad, y, inner) + 18
  Kit.Place(p.nextRule, "TOPLEFT", p, "TOPLEFT", pad, -y, inner, 1)
  y = y + 16
  y = y + Place(p.nextLabel, pad, y, inner) + 8
  y = y + Place(w.terms, pad, y, inner) + pad
  p:SetHeight(y)
  return y
end

function F.BuildSteps(w)
  w.step = 1
  w.stepper = Kit.ProgressStepper(w, { steps = LABELS, tone = "gold", onSelect = function(_, index) F.Step(w, index) end })
  w.steps = w.stepper.buttons
  w.stepTitle = Kit.Paragraph(w.fields.body, "heading", "text")
  w.reviewPoster = B.Wanted.Build(w.fields.body)
  w.review = BuildReview(w)
  w.previous = Kit.Button(w, "Back", 110, 32, { onClick = function() F.Step(w, w.step - 1) end })
  Kit.Tooltip(w.previous, { "Previous step", "Keep your draft and go back one step." })
end

function F.Review(w, width, y)
  local terms = B.TermsEditor.Read(w)
  local gold, count = B.Terms.Gold(w.gold:GetText()) or 0, terms.killsRequired or 1
  local draft = { name = P.Name(F.Name(w)) or F.Name(w), gold = gold, note = B.Clean(w.note:GetText()),
    killsRequired = count, killMethods = terms.killMethods }
  local poster, zoom = w.reviewPoster, 1
  local paperWidth = math.min(B.Wanted.PopupWidth(), width / zoom)
  poster:SetScale(zoom)
  B.Wanted.Fill(poster, draft, { width = paperWidth, compact = true, preview = true, status = "DRAFT PREVIEW",
    tracking = "", progress = "", detail = "" })
  local posterWidth, posterHeight = paperWidth * zoom, poster:GetHeight() * zoom
  local beside = width - posterWidth - 24 >= 200 * math.max(1, ns.Core.FontScale())
  local textX, textY = beside and posterWidth + 24 or 0, beside and y or y + posterHeight + 24
  local textWidth = beside and width - textX or width
  poster:ClearAllPoints(); poster:SetPoint("TOPLEFT", w.fields.body, "TOPLEFT", (beside and 0 or (width - posterWidth) / 2) / zoom, -y / zoom)
  Kit.Place(w.review, "TOPLEFT", w.fields.body, "TOPLEFT", textX, -textY)
  return math.max(y + posterHeight, textY + ReviewDetails(w, textWidth, terms, gold, count))
end

function F.Layout(w)
  if w.layingOut then return end
  w.layingOut = true
  local scale = math.max(1, ns.Core.FontScale())
  local extra, step = scale - 1, w.step or 1
  if not w.bountyPage then w:SetSize(math.min(640 + 180 * extra, UIParent:GetWidth() - 40), math.min(640 + 180 * extra, UIParent:GetHeight() - 40)) end
  local width = w:GetWidth() - 68
  w.fields.body:SetWidth(width)
  Kit.Place(w.stepper, "TOPLEFT", w, "TOPLEFT", 24, -78, w:GetWidth() - 48, w.stepper:GetHeight())
  w.stepper:SetCurrent(step)
  w.stepper:Layout()
  local function Show(controls, on)
    for _, control in ipairs(controls) do control:SetShown(on); if control.caption then control.caption:SetShown(on) end end
  end
  Show({ w.name, w.target, w.audienceLabel, w.audienceHint }, step == 1)
  w.modeSelect:SetShown(step == 1)
  w.organization:SetShown(step == 1 and w.formMode == "guild" and not w.preview)
  Show({ w.gold, w.goldSummary, w.goldWarning, w.goldDetails, w.note, w.customizeButton, w.huntSummary }, step == 2)
  Show({ w.expiry }, step == 2 and w.formMode == "public")
  Show({ w.duration }, step == 2 and w.formMode == "public" and w.durationChoice == "custom")
  Show({ w.kills, w.killBudget, w.methodLabel, w.methodHint }, step == 2 and w.customize == true)
  for _, button in pairs(w.methodButtons) do button:SetShown(step == 2 and w.customize == true) end
  w.reviewPoster:SetShown(step == 3); w.review:SetShown(step == 3); w.terms:SetShown(step == 3)
  w.previous:SetShown(step > 1)
  w.previous:ClearAllPoints(); w.previous:SetPoint("BOTTOMLEFT", 24, 22)
  w.previous:SetSize(110 * scale, 32 * scale)
  w.cancel:SetShown(step == 1); w.cancel:SetText(w.preview and "Return" or "Cancel")
  w.cancel:SetSize(110 * scale, 32 * scale)
  w.action:SetSize(math.max(180 * scale, w.action.label:GetStringWidth() + 28), 32 * scale)
  w.error:SetHeight(44 * scale)
  w.fields:ClearAllPoints(); w.fields:SetPoint("TOPLEFT", w.stepper, "BOTTOMLEFT", 0, -20)
  w.fields:SetPoint("BOTTOMRIGHT", -24, 120 + 24 * extra)
  local y = 0
  local function Text(text, value, gap)
    text:ClearAllPoints(); text:SetPoint("TOPLEFT", 0, -y); text:SetWidth(width)
    if value then text:SetText(value) end
    text:SetHeight(0); text:SetHeight(math.ceil(text:GetStringHeight()) + 2)
    y = y + text:GetHeight() + (gap or 16)
  end
  w.fieldY = {}
  local function Input(input)
    y = y + 24 * scale
    input:ClearAllPoints(); input:SetPoint("TOPLEFT", 0, -y); input:SetWidth(width)
    w.fieldY[input] = y
    y = y + input:GetHeight() + 16
  end
  w.stepTitle:SetShown(step < 3)
  if step < 3 then Text(w.stepTitle, step == 1 and "Choose your target" or "Set the reward", 16) end
  if step == 1 then
    Input(w.name)
    w.target:ClearAllPoints(); w.target:SetPoint("TOPRIGHT", 0, -w.fieldY[w.name]); w.target:SetSize(120 * scale, w.name:GetHeight())
    w.name:SetWidth(width - w.target:GetWidth() - 12)
    y = y + 12; Text(w.audienceLabel, "Who can see this bounty?", 12)
    Kit.Place(w.modeSelect, "TOPLEFT", w.fields.body, "TOPLEFT", 0, -y)
    y = y + w.modeSelect:Layout(width) + 14
    Text(w.audienceHint)
    if w.organization:IsShown() then w.organization:ClearAllPoints(); w.organization:SetPoint("TOPLEFT", 0, -y); w.organization:SetWidth(width); y = y + 44 * scale end
  elseif step == 2 then
    Input(w.gold)
    Text(w.goldSummary, nil, 12)
    w.goldDetails:ClearAllPoints(); w.goldDetails:SetPoint("TOPLEFT", 0, -y); w.goldDetails:SetSize(160 * scale, 28 * scale)
    y = y + 28 * scale + 14
    if w.goldWarning:GetText() ~= "" then Text(w.goldWarning) else w.goldWarning:Hide() end
    if w.formMode == "public" then
      y = y + 24 * scale
      Kit.Place(w.expiry, "TOPLEFT", w.fields.body, "TOPLEFT", 0, -y)
      Kit.Place(w.expirySelect, "TOPLEFT", w.expiry, "TOPLEFT", 0, 0)
      local height = w.expirySelect:Layout(width)
      w.expiry:SetSize(width, height)
      y = y + height + 16
      if w.durationChoice == "custom" then Input(w.duration) end
    end
    w.fieldY[w.kills] = y + 60
    y = B.TermsEditor.Layout(w, width, y, extra)
    Input(w.note)
  else
    y = F.Review(w, width, y)
  end
  w.fields.body:SetHeight(y + 8); w.fields:Refresh()
  w.layingOut = nil
end
