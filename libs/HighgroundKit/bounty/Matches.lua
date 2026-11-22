local _, ns = ...
local B, Kit = ns.Bounty, ns.Kit
local N = { queue = {} }
B.Matches = N

local function Allowed()
  return B.Enabled() and ns.Core.O("bountyAnnounce") and (not ns.Alerts or ns.Alerts.Allowed("bounty", "text"))
end

function N.State(name) return B.Scope.Saved("bountyInterest")[B.Key(name)] end
function N.Tracking(row)
  if row.preview then return row.tracking == true end
  local state = N.State(row.name)
  return state ~= "ignored" and (state == "tracking" or row.personal ~= nil or row.state == "personal")
end
function N.Label(row)
  return N.Tracking(row) and ns.Locale:Get("shared.matches.tracking.9ad1ea")
    or not row.preview and N.State(row.name) == "ignored" and ns.Locale:Get("shared.matches.not_tracking_alerts_off.0d9af6") or ns.Locale:Get("shared.matches.not_tracking.7b1dc4")
end
function N.Set(name, state)
  B.Scope.Saved("bountyInterest")[B.Key(name)] = state
  B.Emit("updated")
end

local function Eligible(b)
  if not b or N.State(b.name) == "ignored" or N.State(b.name) == "tracking" then return false end
  if ns.NearbyHistory and ns.NearbyHistory.Muted(b.name) then return false end
  local reward = 0
  if b.contributions then
    for _, p in ipairs(b.contributions) do
      if not B.Public.Mine(p) and B.Public.Active(p) and B.Public.Funds(p) == "available" then reward = reward + p.gold end
    end
  elseif b.state == "approved" and b.by ~= B.Me() then reward = b.gold end
  return reward > 0 and reward >= (ns.Core.O("bountyMinGold") or 0)
end

local function Current(name)
  local shared, guild = B.Public.Receiving() and B.Public.Find(name), B.Organizations.Find(name)
  if guild and (guild.state ~= "approved" or not B.Visible(guild) or guild.publicClosed) then guild = nil end
  local p = guild and B.LinkedOffer(guild)
  return Eligible(shared) and shared or p and { name = name, gold = p.gold, state = "public", contributions = { p } } or guild
end
local function Stamp(b)
  local ids = {}
  for _, p in ipairs(b.contributions or {}) do if not B.Public.Mine(p) then ids[#ids + 1] = p.id end end
  table.sort(ids)
  return #ids > 0 and table.concat(ids, ":") or (tostring(b.by) .. ":" .. tostring(b.at))
end

local function Build(preview)
  local field = preview and "previewWin" or "win"
  if N[field] then return N[field] end
  local w = B.Wanted.Build(UIParent, (ns.FRAME_PREFIX or "Highground") .. (preview and "BountyMatchPreview" or "BountyMatch"))
  N[field] = w
  w:SetFrameStrata("FULLSCREEN_DIALOG"); w:SetFrameLevel(105)
  w:SetClampedToScreen(true); w:EnableMouse(true)
  w:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 36, -110)
  w.close = Kit.Button(w, "×", 24, 24, { onClick = function() w:Hide() end })
  w.close:SetPoint("TOPRIGHT", -8, -8)
  w.details = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.coachbountysamples.start_tracking.9d94fe"), 230, 30, { tone = "gold", onClick = function()
    if preview then B.Preview.Interest("tracking"); w:Hide() else N.Set(w.bounty.name, "tracking") end
  end }), "highground.coachbountysamples.start_tracking.9d94fe")
  w.ignore = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.matches.ignore_bounty.59f872"), 230, 28, { onClick = function()
    if preview then B.Preview.Interest("ignored"); w:Hide() else N.Set(w.bounty.name, "ignored") end
  end }), "shared.matches.ignore_bounty.59f872")
  w.secondaryAction = w.ignore
  w.ignore:SetPoint("TOPLEFT", w.details, "BOTTOMLEFT", 0, -8); w.ignore:SetPoint("RIGHT", w.details, "RIGHT")
  Kit.Tooltip(w.details, function() return { ns.Locale:Get("highground.coachbountysamples.start_tracking.9d94fe"), ns.Locale:Get("shared.matches.add_this_target_to_my_bounties_your.57f115") } end)
  Kit.Tooltip(w.ignore, function() return { ns.Locale:Get("shared.matches.ignore_this_target.854a9b"), ns.Locale:Get("shared.matches.silence_new_bounty_and_sighting_alerts_start.4775d5") } end)
  w:SetScript("OnHide", function(self)
    if self:IsShown() then return end
    self.bounty = nil
    if not preview then N.Next() end
  end)
  ns.Core.OnFontScaleChange(function() if w.bounty then N.Layout(w) end end)
  return w
end

local function Width() return math.min(320 + math.max(0, ns.Core.FontScale() - 1) * 120, UIParent:GetWidth() - 48) end

function N.Layout(w) B.Wanted.Layout(w, Width()) end

local function Render(w, b, preview)
  w.bounty = b
  B.Wanted.Fill(w, b, { status = preview and ns.Locale:Get("shared.matches.preview_new_bounty.d76662") or ns.Locale:Get("shared.matches.new_bounty_filter_match.a7b35e"),
    owner = b.contributions and ns.Locale:Get("shared.matches.a_new_shared_reward_is_available.5b9912") or (b.organization and (ns.Locale:Format("shared.matches.a_new_reward_from_value2.91eed7", { value2 = B.Organizations.Label(b) })) or ns.Locale:Get("shared.matches.a_new_guild_reward_is_available.8d0f77")),
    location = not preview and B.Sightings.Location(b) ~= "" and B.Sightings.Location(b)
      or ns.Locale:Get("shared.matches.bounty_received_no_sighting_reported.097a91"),
    detail = ns.Locale:Format("shared.matches.matches_your_value2_minimum_track_to_add.173c87", { value2 = ns.Util.Gold(preview and B.Preview.Ensure().minGold or ns.Core.O("bountyMinGold") or 0) }),
    tracking = preview and B.Preview.testing and (B.Preview.state.interest == "tracking" and ns.Locale:Get("shared.matches.tracking.9ad1ea") or ns.Locale:Get("shared.matches.not_tracking.7b1dc4")) or nil,
    preview = preview, portraitLabel = preview and b.previewPortraitLabel, progress = "", compact = true, width = Width() })
  w:Show()
end

function N.Show(b, preview)
  if not preview and (not Allowed() or not Eligible(b)) then return end
  local w = Build(preview)
  if not preview and w:IsShown() then
    if B.Key(w.bounty.name) == B.Key(b.name) then return true end
    for _, item in ipairs(N.queue) do if B.Key(item.name) == B.Key(b.name) then return true end end
    if #N.queue >= 8 then return false end
    N.queue[#N.queue + 1] = b
    return true
  end
  Render(w, b, preview)
  return true
end

function N.Refresh()
  local w = N.win
  if not (w and w.bounty and w:IsShown()) then return end
  local b = Current(w.bounty.name)
  if not Allowed() or not Eligible(b) then w:Hide() else Render(w, b) end
end

function N.Next()
  if not Allowed() then wipe(N.queue); return end
  while #N.queue > 0 do
    local b = Current(table.remove(N.queue, 1).name)
    if Eligible(b) then N.Show(b); return end
  end
end

function N.Scan()
  if not Allowed() then
    wipe(N.queue)
    if N.win then N.win:Hide() end
    return
  end
  if GetTime() < (B.Public.quietUntil or 0) then return end
  N.Refresh()
  local seen, candidates = B.Scope.Saved("bountyMatches"), {}
  if B.Public.Receiving() then
    for _, b in ipairs(B.Public.All()) do if Eligible(b) then candidates[B.Key(b.name)] = b end end
  end
  for _, b in ipairs(B.Organizations.Entries()) do
    if b.state == "approved" and not candidates[B.Key(b.name)] then
      local p = B.LinkedOffer(b)
      candidates[B.Key(b.name)] = p and { name = b.name, gold = p.gold, state = "public", contributions = { p } } or b
    end
  end
  for key, b in pairs(candidates) do
    local stamp = Stamp(b)
    if Eligible(b) and seen[key] ~= stamp and N.Show(b) then
      seen[key] = stamp
      if b.contributions then B.AnnounceShared(b)
      else B.Say(ns.Locale:Format("shared.matches.new_organization_bounty_matches_your_filters_value2.9c23cc", { value2 = ns.Core.DisplayName(b.name) })) end
    end
  end
end

B.Listen("updated", N.Refresh)
B.Listen("scope", function()
  wipe(N.queue)
  if N.win then N.win:Hide() end
  if N.previewWin then N.previewWin:Hide() end
end)
