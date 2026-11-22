local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
local Macros = ns.Macros
local Host = Macros.Host
local Theme, Kit, Codec = Host.Theme, Host.Kit, Host.Codec
local Share = {}
Macros.Share = Share

---------------------------------------------------------------------------
-- Sharing macros as one base64 string (like profiles):
--   base64("WBM1;" .. entries joined by ";"), entry = b64(name):c|g:b64(body)
-- Import previews every macro, compiled, before writing any of them.
---------------------------------------------------------------------------
local PREVIEW_H = 84 -- check results under the pasted string

function Share.Encode(list)
  local parts = { Host.SHARE_TAG }
  for _, m in ipairs(list) do
    parts[#parts + 1] = Codec.Encode64(m.name) .. ":" .. (m.perCharacter and "c" or "g") .. ":" .. Codec.Encode64(m.body or "")
  end
  return Codec.Encode64(table.concat(parts, ";"))
end

-- list or nil, error.
function Share.Decode(text)
  if type(text) ~= "string" or #text > 131072 then return nil, Locale:Get("macros.share.macro_string_is_too_large.72161e") end
  local raw, tag = Codec.Decode64(text), Host.SHARE_TAG
  if not raw or not (raw == tag or raw:sub(1, #tag + 1) == tag .. ";") then return nil, Locale:Get("macros.share.not_a_highground_macro_string.ec6315") end
  local list = {}
  for token in raw:gmatch("[^;]+") do
    if token ~= tag then
      local name, scope, body = token:match("^([^:]*):([cg]):([^:]*)$")
      name = name and Codec.Decode64(name)
      body = body == "" and "" or (body and Codec.Decode64(body))
      if not (name and body) or name == "" then return nil, Locale:Get("macros.share.damaged_macro_entry.193bf3") end
      list[#list + 1] = { name = name, body = body, perCharacter = scope == "c" }
    end
  end
  if #list == 0 then return nil, Locale:Get("macros.share.no_macros_in_this_string.8fd8f9") end
  return list
end

local win
local function Build()
  if win then return win end
  local function import(scope)
    return function() if Share.Review then Share.Review(scope) else Share.Import(scope) end end
  end
  -- Right to left from the bottom right corner: As exported, To Character, To General.
  win = Kit.CopyBox(Host.PREFIX .. "MacroShare", { width = 480, height = 360, strata = "FULLSCREEN_DIALOG",
    savedKey = "macroShare", point = { "CENTER", "CENTER", 0, 40 },
    onText = function() Share.Preview() end, below = PREVIEW_H,
    buttons = {
      { key = "toGeneral", label = Locale:Get("macros.share.to_general.1d15f2"), onClick = import(false) },
      { key = "toCharacter", label = Locale:Get("macros.share.to_character.ae05a0"), onClick = import(true) },
      { key = "asExported", label = Locale:Get("macros.share.as_exported.21c820"), onClick = import(nil) },
    } })
  Share.window = win
  -- The preview takes the bottom of the text well.
  win.preview = Theme.Text(win.below, "body")
  win.preview:SetAllPoints()
  win.preview:SetJustifyH("LEFT")
  win.preview:SetJustifyV("TOP")
  win.preview:SetWordWrap(true)
  return win
end

local function SetMode(w, mode)
  w.mode = mode
  for _, b in pairs(w.actions) do b:SetShown(mode == "import") end
end

function Share.ShowExport(list)
  local w = Build()
  SetMode(w, "export")
  local names = {}
  for _, m in ipairs(list) do names[#names + 1] = m.name end
  w:Open(Locale:Format("macros.share.export_value2.ffb182", { value2 = Host.Plural(#list, "MACRO") }),
    Locale:Get("macros.share.ctrl_c_to_copy_then_paste_it.8be087"), Share.Encode(list), true)
  w.preview:SetText(table.concat(names, ", "))
end

function Share.ShowImport()
  local w = Build()
  SetMode(w, "import")
  w:Open(Locale:Get("macros.share.import_macros.20d452"), Locale:Get("macros.share.paste_a_highground_macro_string_ctrl_v.1eaed9"), "")
  Share.Preview()
end

-- Import mode: decode and compile each macro as the text changes.
function Share.Preview()
  local w = win
  if not (w and w:IsShown() and w.mode == "import") then return end
  local text = w:GetText()
  w:SetStatus("")
  w.checks = nil
  if text == "" then w.list = nil; w.preview:SetText(""); return end
  local list, err = Share.Decode(text)
  w.list = list
  if not list then w.preview:SetText(""); w:SetStatus(err, "danger"); return end
  w.checks = {}
  for i, m in ipairs(list) do
    local r = Macros.Analyze(m.body)
    w.checks[i] = { name = m.name, perCharacter = m.perCharacter, errors = r.errors, warnings = r.warnings,
      exists = Macros.Where(m.name) }
  end
  Share.ShowChecks()
end

-- Results of the last Preview, with inline state colours.
function Share.ShowChecks()
  local w = win
  if not (w and w.mode == "import" and w.list and w.checks) then return end
  local lines = {}
  for _, c in ipairs(w.checks) do
    local state = c.errors > 0 and Theme.Hex("danger") .. Host.Plural(c.errors, "error") .. "|r"
      or c.warnings > 0 and Theme.Hex("warning") .. Host.Plural(c.warnings, "warning") .. "|r" or Theme.Hex("success") .. "ok|r"
    lines[#lines + 1] = Locale:Format("macros.share.c_name_value2_state_value4.c1ed35", { c_name = string.format("%s", c.name), value2 = string.format("%s", c.perCharacter and "character" or "general"), state = string.format("%s", state), value4 = string.format("%s", c.exists and (Locale:Format("macros.share.replaces_your_c_exists_macro.147414", { c_exists = c.exists })) or "") })
  end
  w.preview:SetText(table.concat(lines, "\n"))
end
Theme.OnChange(Share.ShowChecks)

local function Sentence(s) return Host.Text.UpperFirst(s) end

-- scope: nil = as exported, true = Character, false = General. Returns ok
-- and, on failure, the reason. Combat writes nothing; on any failure the
-- window stays open with the reasons.
function Share.Import(scope, plan)
  local w = win
  if not (w and (plan or w.list)) then return false end
  if InCombatLockdown() then
    w:SetStatus(Sentence(Macros.CombatMessage()), "danger")
    return false, Sentence(Macros.CombatMessage())
  end
  if Share.Plan and not plan then
    local err
    plan, err = Share.Plan(w.list, scope)
    if not plan then w:SetStatus(err, "danger"); return false, err end
  end
  local done, failed = 0, {}
  for _, m in ipairs(plan or w.list) do
    local perCharacter = scope == nil and m.perCharacter or scope == true
    local ok, msg = Macros.Save(m.name, m.body, perCharacter)
    if ok then done = done + 1 else failed[#failed + 1] = m.name .. ": " .. msg end
  end
  local report = Locale:Format("macros.share.imported_value2_value3.240ae3", { value2 = Host.Plural(done, "macro"), value3 = (#failed > 0 and (Locale:Format("macros.share.failed_value2.222bc6", { value2 = table.concat(failed, "; ") })) or "") })
  Host.Say(report)
  if Macros.Window.Refresh then Macros.Window.Refresh() end
  if #failed > 0 then
    w:SetStatus(Sentence(report), "danger")
    return false, Sentence(report)
  end
  Kit.Windows.Close(w)
  return true
end
