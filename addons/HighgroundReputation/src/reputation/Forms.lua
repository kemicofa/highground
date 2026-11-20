local _, ns = ...
local W, K, T = ns.Reputation, ns.Kit, ns.Theme
W.UI = { mode = "blacklist", page = 1 }
local UI = W.UI

function UI.Label(parent, text, x, y, width, color)
  local label = T.Text(parent, "body", color or "textMuted")
  label:SetPoint("TOPLEFT", x, y)
  label:SetWidth(width)
  label:SetJustifyH("LEFT")
  label:SetText(text)
  return label
end

function UI.Dialog(key, title, width, height, preview)
  return K.Dialog((ns.FRAME_PREFIX or "Highground") .. "Reputation" .. key .. (preview and "Preview" or ""),
    { title = title, width = width, height = height, savedKey = not preview and "reputation" .. key or nil, child = key ~= "Window" })
end

function UI.Result(frame, value, err, source)
  local UI = (source or W).UI
  if not value then frame.status:SetText(err or "The action could not be completed."); return end
  frame:Hide()
  if UI.Refresh then UI.Refresh() end
end

function UI.CommunityChoices(source)
  local W = source or W
  local O = W.organizations or ns.Organizations
  local choices, counts, ids = {}, {}, {}
  for _, c in ipairs(W.List()) do
    local org = O.Get(c.id)
    if org then
      local label = (org.kind == "guild" and "Guild: " or "Community: ") .. org.name
      choices[#choices + 1] = { key = c.id, label = label }
      counts[label], ids[c.id] = (counts[label] or 0) + 1, org.clubId or org.id
    end
  end
  -- Native IDs keep identically named communities distinguishable without
  -- changing the identity used to submit a report or select its audience.
  for _, choice in ipairs(choices) do
    if counts[choice.label] > 1 then choice.label = choice.label .. " (#" .. tostring(ids[choice.key]) .. ")" end
  end
  return choices
end

function W.OpenOrganizations()
  UI.SetMode("organizations")
  return W.Open()
end

function W.OpenNative(c)
  local ok, err = ns.Organizations.Open(c and c.id)
  if not ok then W.Say(err or "Open Guild & Communities from the game's social menu.") end
end

local function ReportRole(f, source)
  local W = source or W
  local c = W.Get(f.community:GetValue())
  local role, mod = W.Role(c), W.CanModerate(c)
  f:SetTitle(mod and "BLACKLIST PLAYER" or "REPORT PLAYER")
  f.submit:SetText(mod and "Save blacklist decision" or "Submit proposal")
  f.submit:SetEnabled(role ~= nil)
  f.hint:SetText(not W.Joined(c) and "This organization is unavailable. Your draft is kept; wait for it to reconnect or choose another organization."
    or not role and "Waiting for your organization role. Your draft is kept."
    or mod and "Your approved categories and explanation are shared with community members."
    or "A moderator must approve this proposal. Your note is sent to moderators.")
end

-- Roster and presence events must not interrupt an editor. Refresh access
-- without changing its audience or discarding the entered name and notes.
function UI.RefreshDialogs(source)
  local W = source or W
  local UI = W.UI
  local f = UI.report
  if f then
    local id, previous = f.community:GetValue()
    for _, choice in ipairs(f.community.choices) do if choice.key == id then previous = choice end end
    local choices, found = UI.CommunityChoices(), false
    for _, choice in ipairs(choices) do if choice.key == id then found = true end end
    if previous and not found then table.insert(choices, 1, previous) end
    f.community:SetChoices(choices); f.community:SetValue(id, true)
    ReportRole(f, W)
  end
  f = UI.reason
  if f and f.community then
    local allowed = W.CanModerate(f.community)
    f.submit:SetEnabled(allowed)
    if not allowed then f.status:SetText("Moderator access is unavailable. Your draft is kept.")
    elseif f.accessUnavailable then f.status:SetText("") end
    f.accessUnavailable = not allowed
  end
  f = UI.details
  if f and f.community and (not W.Joined(f.community) or f.moderator and not W.CanModerate(f.community)) then
    -- A suspended history window must not reveal private notes on return.
    f.text:SetText(""); f.row = nil
    K.Windows.Close(f)
  end
end

function UI.CloseDialogs(source)
  local UI = (source or W).UI
  for _, key in ipairs({ "details", "report", "reason" }) do
    local f = UI[key]
    if f then K.Windows.Forget(f); f:Hide() end
  end
end

W.Listen(function() UI.RefreshDialogs() end)

function W.OpenReport(target, community, source)
  local W = source or W
  local UI = W.UI
  if not W.ready then return W.Say(W.loadError or "Reputation is loading.") end
  if #W.List() == 0 then W.Open(); return W.Say("Enable reputation for your guild or a WoW community in Organizations first.") end
  if not UI.report then
    local f = UI.Dialog("Report", "REPORT PLAYER", 560, 560)
    UI.report = f
    f.community = K.Select(f.content, { width = 508, label = "Organization", menu = true,
      onChange = function() ReportRole(f, W) end })
    f.community:SetPoint("TOPLEFT", 0, -24)
    f.name = K.Input(f.content, 508, ns.Caps.hideRealmNames and "Full player name (include surname)" or "Full player name (include realm)")
    f.name:SetPoint("TOPLEFT", 0, -90); f.name:SetMaxLetters(200)
    f.categories = {}
    for i, category in ipairs(W.CATEGORIES) do
      local toggle = K.Toggle(f.content, category[2], { width = 245 })
      toggle:SetPoint("TOPLEFT", ((i - 1) % 2) * 260, -140 - math.floor((i - 1) / 2) * 32)
      f.categories[category[1]] = toggle
    end
    f.note = K.Input(f.content, 508, "Explanation / note (optional, 280 characters)")
    f.note:SetPoint("TOPLEFT", 0, -270); f.note:SetMaxLetters(280)
    f.hint = UI.Label(f.content, "", 0, -310, 508)
    f.status = UI.Label(f.content, "", 0, -365, 508, "danger")
    f.submit = K.Button(f, "Submit proposal", 235, 32, { tone = "accent", onClick = function()
      local c = W.Get(f.community:GetValue())
      local name = W.Text(f.name:GetText(), 200)
      local player, err = f.target
      if not player or name ~= player.name and name ~= ns.Core.DisplayName(player.name, true) then player, err = W.Target(name) end
      if not player then return UI.Result(f, nil, err) end
      local categories = {}
      for key, toggle in pairs(f.categories) do if toggle:GetChecked() then categories[key] = true end end
      local result
      if W.CanModerate(c) then result, err = W.Decide(c, player, "ban", categories, f.note:GetText())
      else result, err = W.Submit(c, player, categories, f.note:GetText()) end
      UI.Result(f, result, err)
    end })
    f.submit:SetPoint("BOTTOMRIGHT", -18, 18)
  end
  local f = UI.report
  local c = community or W.Get()
  if not W.Joined(c) then c = W.List()[1] end
  f.target = target and W.Copy(target) or nil
  f.community:SetChoices(UI.CommunityChoices()); f.community:SetValue(c.id, true)
  f.name:SetText(ns.Core.DisplayName(target and target.name, true))
  local old = target and W.OwnReport(c, target)
  local row = target and W.FindCase(c, target)
  local source = W.CanModerate(c) and row and row.active or old
  for key, toggle in pairs(f.categories) do toggle:SetChecked(source and source.categories[key] or false, true) end
  f.note:SetText(source and source.note or "")
  f.status:SetText(""); ReportRole(f, W); f:Show()
  if not target then f.name:SetFocus() end
end

function W.OpenReason(c, target, kind, source)
  local W = source or W
  local UI = W.UI
  if not UI.reason then
    local f = UI.Dialog("Reason", "MODERATION REASON", 560, 290)
    UI.reason = f
    f.player = UI.Label(f.content, "", 0, 0, 508, "text")
    f.reason = K.Input(f.content, 508, "Reason (required, shared with members)")
    f.reason:SetPoint("TOPLEFT", 0, -70); f.reason:SetMaxLetters(280)
    f.status = UI.Label(f.content, "", 0, -112, 508, "danger")
    f.submit = K.Button(f, "Save", 180, 32, { tone = "danger", onClick = function()
      local op, err = W.Decide(f.community, f.target, f.kind, {}, f.reason:GetText())
      UI.Result(f, op, err)
      if op and UI.details then UI.details:Hide() end
    end })
    f.submit:SetPoint("BOTTOMRIGHT", -18, 18)
  end
  local f = UI.reason
  f.community, f.target, f.kind = c, W.Copy(target), kind
  f.player:SetText(ns.Core.DisplayName(target.name, true) .. " - " .. W.Name(c))
  f:SetTitle(kind == "revoke" and "REVOKE BLACKLIST ENTRY" or "DISMISS PROPOSALS")
  f.submit:SetText(kind == "revoke" and "Revoke entry" or "Dismiss proposals")
  f.status:SetText(""); f.reason:SetText(""); UI.RefreshDialogs(); f:Show(); f.reason:SetFocus()
end
