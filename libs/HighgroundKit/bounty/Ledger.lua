local _, ns = ...
local B, Kit, U = ns.Bounty, ns.Kit, ns.Util
local L = {}
B.Ledger = L
local pending = {}
B.Listen("scope", function() wipe(pending) end)

-- A claim is a player's report, never proof of a kill or gold transfer.
-- Keep the offer snapshot so removing/expiring a bounty keeps its history.
function L.All()
  return B.Scope.Saved("bountyClaims")
end

function L.Tracking(c) return c.personal and not c.ownerOnly and c.by == c.claimant end

function L.Find(name, killedAt)
  local found
  local function Check(c)
    if B.Key(c.name) == B.Key(name) and c.claimant == B.Me() and (not killedAt or c.killedAt == killedAt)
      and (not found or (c.killedAt or c.claimedAt) > (found.killedAt or found.claimedAt)) then found = c end
  end
  for _, c in ipairs(L.All()) do Check(c) end
  for _, c in pairs(B.Public.Data().claims) do Check(c) end
  return found
end

function L.ForBounty(row)
  local found
  local sources = row.pot and row.pot.contributions or row.shared and row.shared.contributions
    or { row.offer or row.guild or row.personal }
  local function Check(c)
    if c.claimant ~= B.Me() and not ((c.state == "claimed" or c.state == "approved") and L.CanManage(c)) then return end
    for _, b in ipairs(sources) do
      if c.pledge == (b.id or b.publicID) and c.public or not c.public and B.Pot.MatchesClaim(c, b) then
        if not found or (c.killedAt or c.claimedAt) > (found.killedAt or found.claimedAt) then found = c end
      end
    end
  end
  for _, c in ipairs(L.All()) do Check(c) end
  for _, c in pairs(B.Public.Data().claims) do Check(c) end
  return found
end

local function ID(b, from) return table.concat({ b.name, b.by, b.at, from, b.state == "personal" and "personal" or B.Organizations.Key(b) or b.organization or "" }, ";") end
function L.Record(b, from, killedAt, evidence, cause)
  killedAt = killedAt or B.Public.Now()
  if killedAt >= B.Pot.Expires(b) then return nil end
  if b.publicID then
    local p = B.LinkedOffer(b)
    return p and B.Public.GuildClaim(p, from, killedAt, evidence, cause) or nil
  end
  local id = ID(b, from) .. (B.Terms.Count(b) > 1 and (";" .. killedAt) or "")
  for _, c in ipairs(L.All()) do if c.id == id then return c end end
  if #L.All() >= B.Public.MAX_CLAIMS then return nil end
  local reports = 0
  for _, c in ipairs(L.All()) do
    if B.Pot.MatchesClaim(c, b) and c.claimant == from and c.killedAt == killedAt then return c end
    if B.Pot.MatchesClaim(c, b) and c.state ~= "rejected"
      and (c.claimant == from or c.state == "approved" or c.state == "paid") then reports = reports + 1 end
  end
  if reports >= B.Terms.Count(b) then return nil end
  local c = { id = id, name = b.name, gold = b.gold, by = b.by, offerAt = b.at,
    claimant = from, killedAt = killedAt, evidence = evidence or "manual report", claimedAt = B.Public.Now(), at = B.Public.Now(), state = "claimed", personal = b.state == "personal",
    organization = b.organization, guild = b.state ~= "personal" and not b.organization and B.GuildKey() or nil, cause = cause and B.Public.Copy(cause) }
  B.Terms.Copy(c, b)
  c.contract = B.Pot.Contract(b)
  c.ownerOnly = b.potID ~= nil
  table.insert(L.All(), 1, c)
  if #L.All() > 200 then
    for i = #L.All(), 1, -1 do
      if #L.All() <= 200 then break end
      local old = L.All()[i]
      if old.state == "paid" or old.state == "rejected" then table.remove(L.All(), i) end
    end
  end
  if L.win then L.win:Refresh() end
  return c
end

function L.CanManage(c, who)
  who = who or B.Me()
  if c.ownerOnly then return c.by == who end
  if c.public then
    local p = B.Public.Data().offers[c.pledge]
    return p ~= nil and B.Public.CanManage(p) and who == B.Me()
  end
  return c.by == who or (not c.personal and (c.organization ~= nil or c.guild ~= nil and c.guild == B.GuildKey())
    and B.IsOfficer(who, c.organization))
end

function L.Change(c, state)
  if c.public then return B.Public.ChangeClaim(c, state) end
  if not L.CanManage(c) then return false, "Only the poster or an organization moderator can settle this claim." end
  local allowed, why = B.Public.ClaimStep(c.state, state)
  if not allowed then
    return false, ({ settled = "This claim is already settled.", unknown = "Unknown claim state.",
      unapproved = "Approve the claim before marking it paid.",
      obligation = "An approved payment obligation cannot be cancelled." })[why]
  end
  if state == "approved" then
    local awarded = 0
    for _, other in ipairs(L.All()) do
      if other.name == c.name and other.by == c.by and (other.offerAt == c.offerAt or other.contract and c.contract and other.contract.id == c.contract.id) and other.guild == c.guild and other.organization == c.organization
        and (other.state == "approved" or other.state == "paid") then
        if other.killedAt and other.killedAt == c.killedAt then return false, "This death has already been approved." end
        awarded = awarded + 1
      end
    end
    if awarded >= B.Terms.Count(c) then return false, "All requested kills have already been approved." end
  end
  c.state, c.at, c.reviewedBy = state, math.max(B.Public.Now(), c.at + 1), B.Me()
  if state == "paid" then c.paidAt = B.Public.Now() end
  if not c.personal and (c.organization and B.Organizations.Member(c) or c.guild == B.GuildKey()) then
    local sent, guild = B.Send(L.Encode(c), c.organization), B.Organizations.Get()
    pending[c.id] = not sent and not c.organization and guild and { value = c, guild = guild.id } or nil
  end
  if B.Gold then B.Gold.Record() end
  B.Pot.Decide(c)
  B.Emit("updated")
  return true, state == "paid" and "Marked paid manually. No gold was transferred." or ("Claim " .. state .. ".")
end

function L.Encode(c)
  if c.cause or c.evidence and c.evidence ~= "manual report" then
    return table.concat({ "5:L", B.Clean(c.name), c.offerAt, B.Clean(c.claimant), c.state, c.at,
      c.killedAt or c.claimedAt, B.Kills.Pack(c.evidence, c.cause) }, ",")
  end
  local text = table.concat({ B.Terms.Custom(c) and "4:L" or "1:L", B.Clean(c.name), c.offerAt, B.Clean(c.claimant), c.state, c.at }, ",")
  return text .. (B.Terms.Custom(c) and ("," .. (c.killedAt or c.claimedAt)) or "")
end

function L.Progress(b)
  local n = 0
  for _, c in ipairs(L.All()) do
    if B.Pot.MatchesClaim(c, b)
      and (c.state == "approved" or c.state == "paid"
        or c.personal and not c.ownerOnly and c.by == B.Me() and c.state == "claimed") then n = n + 1 end
  end
  return n
end

function L.Receive(rest, from, version, organization)
  local killedAt, proof
  if version == "5" then
    rest, proof = rest:match("^(.*),([^,]+)$")
    proof = B.Kills.Unpack(proof)
    if not rest or not proof then return end
  end
  if version == "4" or version == "5" then
    rest, killedAt = rest:match("^(.*),(%d+)$")
    killedAt = tonumber(killedAt)
    if not rest or not killedAt or killedAt > B.Public.Now() + 30 then return end
  end
  local name, offerAt, claimant, state, at = rest:match("^,([^,]+),(%d+),([^,]+),(%a+),(%d+)$")
  offerAt, at = tonumber(offerAt), tonumber(at)
  if not at or at > B.Public.Now() + 30 or killedAt and at < killedAt or not ({ approved = true, paid = true, rejected = true })[state]
    or B.Public.Name(claimant) ~= claimant then return end
  if version == "4" or version == "5" then
    local b = B.Guild(organization)[B.Key(name)]
    if b and b.at == offerAt and b.state == "approved" and (from == b.by or B.IsOfficer(from, organization)) then
      local known = false
      for _, c in ipairs(L.All()) do
        if c.organization == organization and c.name == name and c.offerAt == offerAt and c.claimant == claimant and c.killedAt == killedAt then known = true; break end
      end
      if not known then
        local c = L.Record(b, claimant, killedAt, proof and proof.evidence, proof and proof.cause)
        if c then c.at = 0; c.claimedAt = killedAt end
      end
    end
  end
  for _, c in ipairs(L.All()) do
    if c.organization == organization and c.name == name and c.offerAt == offerAt and c.claimant == claimant and not c.personal and (organization ~= nil or c.guild == B.GuildKey())
      and (not killedAt or c.killedAt == killedAt) and at > c.at and L.CanManage(c, from) and B.Public.ClaimStep(c.state, state, true) then
      c.state, c.at, c.reviewedBy = state, at, from
      if state == "paid" then c.paidAt = at end
    end
  end
  if L.win then L.win:Refresh() end
  B.Emit("updated")
end

function L.Retry()
  if not next(pending) then return end
  local guild = B.Organizations.Get()
  for id, item in pairs(pending) do
    if not guild or item.guild ~= guild.id or not L.CanManage(item.value) then pending[id] = nil
    elseif B.Send(L.Encode(item.value)) then pending[id] = nil
    else break end
  end
end

function L.Replay(organization, sent)
  sent = sent or {}
  for _, c in ipairs(L.All()) do
    if not c.personal and (B.Terms.Custom(c) or c.cause or c.evidence ~= "manual report")
      and c.organization == organization and (organization ~= nil or c.guild == B.GuildKey()) and c.state ~= "claimed"
      and L.CanManage(c) and sent[c.id] ~= c.at then
      if not B.Send(L.Encode(c), c.organization) then return false end
      sent[c.id] = c.at
    end
  end
  return true
end

function L.RetryReports()
  for _, c in ipairs(L.All()) do
    if c.claimant == B.Me() and c.by ~= B.Me() and c.state == "claimed"
      and c.killedAt and B.Public.Now() <= c.killedAt + B.Public.CLAIM_WINDOW then
      if not c.personal and (c.organization and B.Organizations.Member(c) or c.guild ~= nil and c.guild == B.GuildKey()) then
        B.Send(table.concat({ "5:K", B.Clean(c.name), c.killedAt, c.offerAt, B.Kills.Pack(c.evidence, c.cause) }, ","), c.organization)
      elseif c.personal and c.ownerOnly and c.contract then
        B.Public.Retry("report:" .. c.id, c.contract.by, c.killedAt + B.Public.CLAIM_WINDOW,
          function() return B.Pot.Report(c.contract, c.killedAt, c.evidence, c.cause) end)
      end
    end
  end
end

function L.Entry(c)
  local Name = ns.Core.DisplayName
  return { key = c.id, claim = c, title = B.Label(c.name), summary = c.state .. "  ·  " .. c.gold .. "g",
      detail = Name(c.name) .. "\nReward: " .. c.gold .. "g\nPosted by: " .. Name(c.by) .. "\nClaimed by: " .. Name(c.claimant)
        .. "\n" .. B.Terms.Summary(c) .. "\nStatus: " .. c.state .. "\nClaim date: " .. date("%Y-%m-%d %H:%M", c.claimedAt)
        .. "\nEvidence: " .. B.Kills.EvidenceText(c.evidence, B.Kills.Confirmed(c)) .. "\nKilling blow: " .. B.Kills.CauseText(c.cause)
        .. "\nKill date: " .. date("%Y-%m-%d %H:%M:%S", c.killedAt or c.claimedAt)
        .. (c.public and ("\nShared contribution: " .. c.pledge
          .. "\nEach kill is reviewed and paid separately, up to the requested count.") or "")
        .. (c.reviewedBy and ("\nReviewed by: " .. Name(c.reviewedBy, true)) or "")
        .. (c.paidAt and ("\nMarked paid: " .. date("%Y-%m-%d %H:%M", c.paidAt)) or "")
        .. "\n\nKill detection, reward approval and payment are separate. Pay players through the game." }
end

function L.Entries()
  local out, claims = {}, {}
  for _, c in ipairs(L.All()) do claims[#claims + 1] = c end
  if B.Public then for _, c in pairs(B.Public.Data().claims) do claims[#claims + 1] = c end end
  table.sort(claims, function(a, b) return a.claimedAt > b.claimedAt end)
  for _, c in ipairs(claims) do
    if c.by == B.Me() or c.claimant == B.Me() or L.CanManage(c) then out[#out + 1] = L.Entry(c) end
  end
  return out
end

function L.Focus(w, name, killedAt, claimID)
  local query, selected, index = ns.Core.DisplayName(name), nil, 0
  w:RestoreNavigation({ query = query })
  for i, e in ipairs(w.items) do
    if B.Key(e.claim.name) == B.Key(name) then
      if (not killedAt or e.claim.killedAt == killedAt) and (not claimID or e.key == claimID) then selected, index = e.key, i - 1; break end
    end
  end
  w:RestoreNavigation({ query = query, selected = selected, offset = selected and math.floor(index / w.visible) * w.visible or 0 })
end

function L.Build()
  if not L.win then
    local actions = {}
    for _, choice in ipairs({ { "Approve", "approved" }, { "Mark paid", "paid" }, { "Reject", "rejected" } }) do
      actions[#actions + 1] = { label = choice[1], enabled = function(e)
        local p = e.claim.public and B.Public.Data().offers[e.claim.pledge]
        return not L.Tracking(e.claim) and L.CanManage(e.claim) and (not p or not p.contract or choice[2] == "paid") and (choice[2] == "paid" and e.claim.state == "approved"
          or choice[2] ~= "paid" and e.claim.state == "claimed")
      end, run = function(e) return L.Change(e.claim, choice[2]) end }
    end
    L.win = Kit.Browser((ns.FRAME_PREFIX or "Highground") .. "BountyLedger", { title = "CLAIMS & PAYMENTS",
      router = B.Navigation.GetRouter(), route = "claims",
      width = 820, height = 680, listRatio = 0.36, rowHeight = 62,
      renderDetail = B.ClaimView.Render, renderRow = B.ClaimView.Row,
      strata = "FULLSCREEN_DIALOG", alpha = 1,
      hint = "",
      state = function() return { error = B.Public.loadError, loading = not B.Public.ready } end,
      data = L.Entries, empty = "No kill reports yet.\n\n" .. B.Kills.Hint() .. "\n\nOffering a reward? Review the report, pay the hunter through the game, then choose Mark paid.", actions = actions })
    B.Widgets.BrowserHelp(L.win, {
      "Accept this kill report and record that the reward is owed. Only an authorized reviewer can approve it; no gold is transferred.",
      "After paying the hunter through the game, record the approved claim as paid. This button does not send gold.",
      "Decline a pending kill report after review. An approved payment obligation cannot be rejected.",
    })
    local w = L.win
    w.back = Kit.Button(w, "Back to board", 156, 28, { onClick = function() w:Hide() end })
    w.back:SetPoint("TOPRIGHT", -22, -88)
    Kit.Tooltip(w.back, { "Back to the bounty board", "Return to the board without changing any claim or payment." })
    w.emptyTitle = ns.Theme.Text(w, "cardTitle", "text")
    w.emptyTitle:SetPoint("TOPLEFT", 24, -150); w.emptyTitle:SetText("From a kill report to a payment")
    w.emptyGuide = ns.Theme.Text(w, "body", "textMuted")
    w.emptyGuide:SetPoint("TOPLEFT", w.emptyTitle, "BOTTOMLEFT", 0, -20); w.emptyGuide:SetPoint("RIGHT", -24, 0)
    w.emptyGuide:SetJustifyH("LEFT"); w.emptyGuide:SetJustifyV("TOP"); w.emptyGuide:SetWordWrap(true)
    w.emptyGuide:SetText("No kill reports yet.\n\nHunting? " .. B.Kills.Hint() .. " Follow your report here.\n\nOffering a reward? Approve the report, pay the hunter through the game, then choose Mark paid.")
    local refresh = w.Refresh
    function w:Refresh()
      refresh(self)
      local empty = self.viewState.kind == "empty"
      self.emptyTitle:SetShown(empty); self.emptyGuide:SetShown(empty)
      self.emptyGuide:SetHeight(self.emptyGuide:GetStringHeight())
      self.search:SetShown(not empty); self.search.caption:SetShown(not empty); self.detailScroll:SetShown(not empty)
      self.status:SetShown(not empty)
      for _, button in ipairs(self.actions) do button:SetShown(not empty) end
    end
    w.LayoutPage = function(self) self:Layout(); self.back:SetWidth(self.back.label:GetStringWidth() + 24) end
  end
  return L.win
end

function L.Open(name, killedAt, claimID) return B.Navigation.Open("claims", { name = name, killedAt = killedAt, claimID = claimID }) end

B.Listen("claimed", L.Record)
B.Listen("updated", function() if L.win and L.win:IsShown() then L.win:Refresh() end end)
