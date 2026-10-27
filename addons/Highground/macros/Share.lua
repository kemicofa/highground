local _, ns = ...
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
  local raw, tag = Codec.Decode64(text), Host.SHARE_TAG
  if not raw or not (raw == tag or raw:sub(1, #tag + 1) == tag .. ";") then return nil, "not a Highground macro string" end
  local list = {}
  for token in raw:gmatch("[^;]+") do
    if token ~= tag then
      local name, scope, body = token:match("^([^:]*):([cg]):([^:]*)$")
      name = name and Codec.Decode64(name)
      body = body == "" and "" or (body and Codec.Decode64(body))
      if not (name and body) or name == "" then return nil, "damaged macro entry" end
      list[#list + 1] = { name = name:sub(1, Macros.NAME_MAX), body = body, perCharacter = scope == "c" }
    end
  end
  if #list == 0 then return nil, "no macros in this string" end
  return list
end

local win
local function Build()
  if win then return win end
  local function import(scope)
    return function() Share.Import(scope) end
  end
  -- Right to left from the bottom right corner: As exported, To Character, To General.
  win = Kit.CopyBox(Host.PREFIX .. "MacroShare", { width = 480, height = 360, strata = "FULLSCREEN_DIALOG",
    savedKey = "macroShare", point = { "CENTER", "CENTER", 0, 40 },
    onText = function() Share.Preview() end, below = PREVIEW_H,
    buttons = {
      { key = "toGeneral", label = "To General", onClick = import(false) },
      { key = "toCharacter", label = "To Character", onClick = import(true) },
      { key = "asExported", label = "As exported", onClick = import(nil) },
    } })
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
  w:Open("EXPORT " .. #list .. " MACRO" .. (#list == 1 and "" or "S"),
    "Ctrl+C to copy, then paste it anywhere. Import it with /hg macros import.", Share.Encode(list), true)
  w.preview:SetText(table.concat(names, ", "))
end

function Share.ShowImport()
  local w = Build()
  SetMode(w, "import")
  w:Open("IMPORT MACROS", "Paste a Highground macro string (Ctrl+V). Each macro is checked before anything is written.", "")
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
    local state = c.errors > 0 and Theme.Hex("danger") .. c.errors .. " error(s)|r"
      or c.warnings > 0 and Theme.Hex("warning") .. c.warnings .. " warning(s)|r" or Theme.Hex("success") .. "ok|r"
    lines[#lines + 1] = string.format("%s  (%s)  %s%s", c.name, c.perCharacter and "character" or "general", state,
      c.exists and ("  · replaces your " .. c.exists .. " macro") or "")
  end
  w.preview:SetText(table.concat(lines, "\n"))
end
Theme.OnChange(Share.ShowChecks)

-- scope: nil = as exported, true = Character, false = General.
function Share.Import(scope)
  local w = win
  if not (w and w.list) then return false end
  local done, failed = 0, {}
  for _, m in ipairs(w.list) do
    local perCharacter = scope == nil and m.perCharacter or scope == true
    local ok, msg = Macros.Save(m.name, m.body, perCharacter)
    if ok then done = done + 1 else failed[#failed + 1] = m.name .. ": " .. msg end
  end
  Host.Say("imported " .. done .. " macro" .. (done == 1 and "" or "s")
    .. (#failed > 0 and (" (failed: " .. table.concat(failed, "; ") .. ")") or ""))
  if Macros.Window.Refresh then Macros.Window.Refresh() end
  w:Hide()
  return #failed == 0
end
