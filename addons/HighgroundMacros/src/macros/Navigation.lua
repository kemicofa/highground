local _, ns = ...
local M = ns.Macros
local Win, Host = M.Window, M.Host
local Kit = Host.Kit

local function CaptureEditor()
  local panel, p = M.BuildPanel, M.BuildPanel.frame
  if not p then return end
  local state = { opts = panel.opts, generated = panel.generated, editing = panel.editing, code = p.code:GetPlainText(),
    destination = p.destination:GetValue(), fields = {}, groups = {}, form = p.form.offset, report = p.report.offset }
  for _, key in ipairs(M.BuildPanel.FIELDS) do state.fields[key] = p[key]:GetText() end
  for i, group in ipairs(p.groups) do state.groups[i] = group.open end
  return state
end

local function RestoreEditor(state)
  local panel, p = M.BuildPanel, M.BuildPanel.frame
  panel.loading = true
  for _, key in ipairs(M.BuildPanel.FIELDS) do p[key]:SetText(state.fields[key] or "") end
  panel.opts, panel.generated, panel.editing, panel.outcome = state.opts, state.generated, state.editing, nil
  p.spell.caption:SetText(panel.CAPTIONS[panel.opts.verb or "cast"])
  p.code:SetPlainText(state.code or "")
  p.destination:SetValue(state.destination or "general", true)
  for i, group in ipairs(p.groups) do group.open = state.groups[i] end
  panel.loading = nil
  panel.Update()
  p.form:Scroll(state.form or 0); p.report:Scroll(state.report or 0)
end

local function Capture()
  local w = Win.win
  if not w then return {} end
  return { search = w.search:GetText(), offset = Win.offset, editor = Win.tab == "build" and CaptureEditor() or nil }
end

local function Enter(to)
  local w, state = Win.Build(), to.state or {}
  Win.tab = to.name
  Host.Set("macroMode", to.params.mode or Win.Mode())
  w.search:SetText(state.search or "")
  Win.offset = state.offset or 0
  if to.name == "build" then
    -- Reveal the editor before loading a recipe; its existing updater only
    -- runs while shown. Loading never writes a game macro.
    M.BuildPanel.frame:Show()
    if state.editor then RestoreEditor(state.editor)
    elseif state.load then M.BuildPanel.Load(state.load)
    elseif state.preset then M.BuildPanel.LoadPreset(state.preset, state.resolved) end
  end
  Win.Refresh()
end

function Win.GetRouter()
  if not Win.router then
    Win.router = Host.Router.New()
    for _, key in ipairs({ "class", "mine", "general", "all", "build" }) do
      Win.router:Register(key, { enter = Enter, capture = Capture })
    end
  end
  return Win.router
end

function Win.Navigate(tab, mode, state)
  mode = Win.MODES[mode] and mode or Win.Mode()
  if mode == "ranks" and not M.Ranks.Supported() then mode = "pvp" end
  return Win.GetRouter():Navigate({ name = tab, params = { mode = mode }, state = state })
end

function Win.OpenEditor(entry, preset)
  return Win.GetRouter():Navigate({ name = "build", params = { mode = Win.Mode(), name = entry.name,
    kind = preset and "preset" or "saved", perCharacter = entry.perCharacter },
    state = preset and { preset = entry, resolved = Win.Resolve(entry) }
      or { load = { name = entry.name, body = entry.body, perCharacter = entry.perCharacter } } })
end

function Win.AttachRoutes(w)
  local router = Win.GetRouter()
  Kit.AttachNavigation(w, router)
  if not router:Current() and not router._busy then Win.Navigate(Win.tab) end
end
