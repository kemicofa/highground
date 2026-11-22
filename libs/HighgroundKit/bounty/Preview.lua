local _, ns = ...
local B, Kit = ns.Bounty, ns.Kit
local Demo = B.Preview
local CloseWindows, RenderGuided

function Demo.HideAlerts()
  Demo.changing = true
  B.Poster.StopPreview()
  if B.Matches.previewWin then B.Matches.previewWin:Hide() end
  if B.Proof.previewWin then B.Proof.previewWin:Hide() end
  Demo.alert, Demo.changing = nil, nil
end

function Demo.Dock(w)
  if Demo.testing then return end
  if not w or not (Demo.guided or Demo.win) then return end
  Demo.alert, w.tourDocked = w, true
  w:SetMovable(false); w:SetFrameStrata("FULLSCREEN_DIALOG")
  if Demo.guided then
    w:SetParent(UIParent); w:SetFrameLevel(110); w:SetClampedToScreen(true)
    w:ClearAllPoints(); w:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  else
    w:SetParent(Demo.win.body); w:SetFrameLevel(Demo.win.body:GetFrameLevel() + 5)
  end
  if not w.tourHideHook then
    w.tourHideHook = true
    w:HookScript("OnHide", function()
      if not Demo.guided and not Demo.changing and not Demo.stopping
        and Demo.win and Demo.win:IsVisible() and not w:IsShown() then Demo.Refresh() end
    end)
  end
end

function Demo.Replay()
  if not Demo.scene then return end
  Demo.HideAlerts()
  local key, b = Demo.scene.key, Demo.bounty
  if key == "nearby" then
    local pulse = not Demo.guided and Demo.win and Demo.win.examples.marker.pulse
    if pulse then pulse:Play() end
    B.Announce(b, "Tarren Mill", true); Demo.Dock(B.Poster.previewWin)
  elseif key == "guild" then
    B.OnChanged(b, b.by, nil, true)
    if b.state == "approved" then B.Matches.Show(b, true); Demo.Dock(B.Matches.previewWin) end
  elseif key == "shared" then
    local state = Demo.Ensure()
    if not state.receive or b.gold < state.minGold or state.fundingIndex and state.fundingIndex ~= 1 then
      Demo.Notice("No sample arrival: receiving must be on and available funds must meet the notification minimum."); return
    end
    B.AnnounceShared(b, true); Demo.Dock(B.Matches.previewWin)
  elseif key == "kill" then
    B.OnKilled(b, B.Public.ClaimMessage(2), true); Demo.Dock(B.Proof.Preview(b))
  end
  Demo.Refresh()
end

function Demo.Prepare(key)
  local selected, index
  for i, scene in ipairs(Demo.scenes) do if scene.key == key then selected, index = scene, i; break end end
  if not selected then return end
  Demo.HideAlerts()
  local state = Demo.Ensure()
  if not state.samples[key] then state.samples[key] = { Demo.Sample(key) } end
  Demo.scene, Demo.index = selected, index
  Demo.row, Demo.bounty = unpack(state.samples[key])
  state.addedContribution = state.addedContributions and state.addedContributions[Demo.bounty]
  if Demo.testing then
    local name = B.Key(Demo.bounty.name)
    state.interests, state.targetClaims = state.interests or {}, state.targetClaims or {}
    state.interest = state.interests[name]
    state.targetClaims[name] = state.targetClaims[name] or Demo.Claims()
    Demo.claims = state.targetClaims[name]
  else Demo.claims = Demo.claims or Demo.Claims() end
  state.visited[key] = true
  return true
end

local function Render(key, state)
  if not Demo.Prepare(key) then return end
  local w = Demo.Build()
  w.contentArea:Scroll(0); Demo.Refresh(); B.Widgets.ShowWindow(w); Demo.Replay()
  -- Keep the selected chapter visible at larger text sizes.
  local position = (Demo.index - 1) * (32 * math.max(1, ns.Core.FontScale()) + 6)
  if position < w.menu.offset then w.menu:Scroll(position)
  elseif position + w.scenes[key]:GetHeight() > w.menu.offset + w.menu.view:GetHeight() then
    w.menu:Scroll(position + w.scenes[key]:GetHeight() - w.menu.view:GetHeight())
  end
  if state then w.contentArea:Scroll(state.scroll or 0) end
  return w
end

function Demo.GetRouter()
  if Demo.router then return Demo.router end
  local router = ns.Router.New()
  Demo.router = router
  router:Register("stopped")
  for _, scene in ipairs(Demo.scenes) do
    router:Register(scene.key, {
      capture = function() return { scroll = not Demo.guided and Demo.win and Demo.win.contentArea.offset or 0 } end,
      enter = function(to)
        if not not to.params.guided ~= not not Demo.guided then return false, "Sample session has ended" end
        if Demo.guided then RenderGuided(to.name) else Render(to.name, to.state) end
      end,
    })
  end
  return router
end

function Demo.Select(key)
  if Demo.testing then return Demo.SelectTest(key) end
  if Demo.guided then return Demo.SelectGuided(key) end
  local router = Demo.GetRouter()
  local current = router:Current()
  local target = current and current.name == key and current or { name = key }
  local ok = router:Navigate(target, { refresh = true })
  if ok then return Demo.win end
end

function Demo.Step(delta)
  local nextIndex = (Demo.index or 1) + delta
  if nextIndex > #Demo.scenes then Demo.Stop()
  elseif nextIndex >= 1 then Demo.Select(Demo.scenes[nextIndex].key) end
end

function Demo.Resume()
  if Demo.testing then return Demo.TestBoard() end
  if Demo.guided then
    if B.Details.preview and B.Details.win then B.Details.win:Hide() end
    return
  end
  if Demo.scene then Demo.Refresh(); B.Widgets.ShowWindow(Demo.win) end
end

local function Windows()
  local out = {}
  local function Add(w) if w then out[#out + 1] = w end end
  Add(Demo.win); Add(B.Form.previewWin); Add(B.GoldView.previewWin); Add(B.Preferences.previewWin); Add(B.Pot.previewWin)
  for _, board in pairs(B.Board.previews) do Add(board.win) end
  Add(B.Exchange.previewShareWin); Add(B.Exchange.previewImportWin); Add(B.Exchange.previewProofWin)
  if B.Exchange.destinationWin and B.Exchange.destinationWin.preview then Add(B.Exchange.destinationWin) end
  Add(B.Suggestions.View.previewWin); Add(Demo.claimsWin); if B.Details.preview then Add(B.Details.win) end
  return out
end

CloseWindows = function()
  -- Retire hidden parents before closing their children so Escape cannot
  -- resurrect an old preview form.
  for _, w in ipairs(Windows()) do Kit.Windows.Close(w) end
end

-- The coach owns progression and feedback. Selecting a guided chapter
-- only prepares its data and retires the preceding chapter's dialogs.
RenderGuided = function(key)
  if not Demo.guided then return nil end
  if not Demo.Prepare(key) then return nil end
  Demo.changing = true; CloseWindows(); Demo.changing = nil
  B.Details.preview = nil
  return Demo.bounty, Demo.row
end

function Demo.SelectGuided(key)
  if not Demo.guided then return end
  local router = Demo.GetRouter()
  local current = router:Current()
  local target = current and current.name == key and current or { name = key, params = { guided = true } }
  local ok = router:Navigate(target, { refresh = true })
  if ok then return Demo.bounty, Demo.row end
end

function Demo.Stop()
  if Demo.stopping then return end
  Demo.stopping = true
  local callback = Demo.onReturn
  Demo.onReturn = nil
  Demo.HideAlerts()
  if Demo.win then
    B.GoldTooltip.Hide(Demo.win.money)
    local pulse = Demo.win.examples.marker.pulse
    if pulse then pulse:Stop() end
  end
  CloseWindows()
  if Demo.EndTest then Demo.EndTest() end
  B.Details.preview = nil
  Demo.scene, Demo.index, Demo.row, Demo.bounty, Demo.claims, Demo.state = nil, nil, nil, nil, nil, nil
  Demo.guided = nil
  if Demo.router then Demo.router:Reset("stopped") end
  Demo.stopping = nil
  if callback then callback() end
end

-- The full addon guide can launch the same safe tour and resume on exit.
function Demo.Start(onReturn, key)
  if ns.Modules and not ns.Modules.Require("bounties") then return end
  Demo.onReturn = nil
  Demo.Stop()
  Demo.onReturn = onReturn
  return Demo.Select(key or "nearby")
end

-- Reuse actual sample controls without constructing the tour shell. Old
-- posters may still be parented to that shell after a previous normal tour.
function Demo.StartGuided(onReturn, key)
  if ns.Modules and not ns.Modules.Require("bounties") then return end
  Demo.onReturn = nil; Demo.Stop()
  Demo.guided, Demo.onReturn = true, onReturn
  for _, owner in ipairs({ B.Poster, B.Matches, B.Proof }) do
    if owner.previewWin then Demo.Dock(owner.previewWin) end
  end
  return Demo.SelectGuided(key or "nearby")
end

function Demo.GuideCommand(text)
  local key = ns.Util.Trim(text or ""):lower()
  if key == "stop" or key == "off" then Demo.Stop(); return end
  if Demo.guided and ns.Onboarding then Demo.onReturn = nil; ns.Onboarding.StopExploring() end
  if Demo.testing or Demo.guided then Demo.Stop() end
  if key == "" then
    local active = Kit.Windows.Active()
    for _, w in pairs(Windows()) do if w == active and Demo.scene then Demo.Stop(); return end end
    key = "nearby"
  end
  key = ({ world = "shared", share = "exchange", import = "exchange", settings = "gold", proof = "kill", list = "board" })[key] or key
  for _, scene in ipairs(Demo.scenes) do if scene.key == key then return Demo.Select(key) end end
  B.Say("Use " .. B.CMD .. " guide [nearby|board|create|gold|guild|shared|pot|exchange|kill|claims|suggestions|stop].")
end

B.Listen("scope", function() if Demo.scene then Demo.Stop() end end)
