local _, ns = ...
local B, U = ns.Bounty, ns.Util
local G, Tip = B.Gold, {}
B.GoldTooltip = Tip
local hooked = setmetatable({}, { __mode = "k" })
local owner, tooltip, sampleOwner

function Tip.Hide(frame)
  if owner == frame then
    if tooltip then tooltip:Hide() end
    owner, sampleOwner = nil, nil
  end
end

function Tip.Show(frame, preview)
  local sample = preview and B.Preview.Wallet()
  if not frame or not sample and (not B.Public.ready or not G.Enabled()) then return end
  tooltip = tooltip or CreateFrame("GameTooltip", (ns.FRAME_PREFIX or "Highground") .. "AccountGoldTooltip", UIParent, "GameTooltipTemplate")
  owner, sampleOwner = frame, preview
  tooltip:SetOwner(frame, "ANCHOR_TOPLEFT"); tooltip:ClearLines()
  ns.Theme.TipLine(tooltip, (sample and "SAMPLE · " or "") .. "Account gold · " .. B.Scope.Label(), "gold")
  for _, row in ipairs(sample and sample.rows or G.Rows()) do
    tooltip:AddDoubleLine(ns.Core.DisplayName(row.name) .. (row.current and " (current)" or ""), G.Format(row.balance, true))
  end
  tooltip:AddLine(" ")
  tooltip:AddDoubleLine("Total", G.Format(sample and sample.total or G.Total(), true))
  tooltip:AddDoubleLine("Available for bounties", G.Format(sample and sample.available or B.Public.Available(), true))
  ns.Theme.TipLine(tooltip, "Alts: last recorded balance. Log into each character to update.", "textMuted", true)
  tooltip:Show()
  Tip.frame = tooltip
end

local function Hook(frame)
  if not frame or hooked[frame] or not frame.HookScript then return end
  hooked[frame] = true
  frame:HookScript("OnEnter", function() Tip.Show(frame) end)
  frame:HookScript("OnLeave", function() Tip.Hide(frame) end)
  frame:HookScript("OnHide", function() Tip.Hide(frame) end)
end

local function Money(frame)
  if not frame then return end
  Hook(frame)
  local name = frame.GetName and frame:GetName()
  for _, coin in ipairs({ "GoldButton", "SilverButton", "CopperButton" }) do
    Hook(frame[coin] or name and _G[name .. coin])
  end
end

function Tip.Install()
  if ns.STANDBY then return end
  Money(ContainerFrameCombinedBags and ContainerFrameCombinedBags.MoneyFrame)
  Money(ContainerFrame1MoneyFrame)
  for i = 1, 13 do
    local bag = _G["ContainerFrame" .. i]
    Money(bag and bag.MoneyFrame)
  end
  -- Also covers bags using Blizzard's PLAYER MoneyFrame template.
  if not Tip.native and hooksecurefunc and type(MoneyFrame_OnEnter) == "function" then
    Tip.native = true
    hooksecurefunc("MoneyFrame_OnEnter", function(frame)
      if frame and frame.moneyType == "PLAYER" then Tip.Show(frame) end
    end)
    if type(MoneyFrame_OnLeave) == "function" then hooksecurefunc("MoneyFrame_OnLeave", Tip.Hide) end
  end
end

U.Events({ PLAYER_LOGIN = Tip.Install, ADDON_LOADED = Tip.Install, BAG_UPDATE_DELAYED = Tip.Install,
  PLAYER_MONEY = function() if owner then Tip.Show(owner, sampleOwner) end end,
}, "account gold tooltip", "bounties")
B.Listen("scope", function() if owner then Tip.Hide(owner) end end)
ns.Theme.OnChange(function() if owner then Tip.Show(owner, sampleOwner) end end)
