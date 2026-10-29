local _, ns = ...
local M = ns.Macros
local H, S = M.Host, M.Share

function S.Plan(list, scope, decisions)
  local out, names, counts = {}, {}, { general = 0, character = 0 }
  for i, entry in ipairs(list) do
    local d = decisions and decisions[i] or { action = "replace" }
    if d.action ~= "skip" then
      local name = H.Trim(d.action == "rename" and (d.name or "") or entry.name)
      local character = scope == nil and entry.perCharacter or scope == true
      local tab = character and "character" or "general"
      if name == "" or #name > M.NAME_MAX or name:find("%c") then return nil, "Every name must be 1–16 characters on one line." end
      local identity = tab .. ":" .. name
      if names[identity] then return nil, "Duplicate import name: " .. name end
      names[identity] = true
      local check = M.Analyze(entry.body)
      if (check.errors > 0 and entry.body ~= "") or #entry.body > M.BODY_MAX then return nil, name .. ": fix its errors or skip this entry." end
      local old = M.Find(name, character)
      if d.action == "rename" and old then return nil, name .. " already exists. Choose another name or Replace." end
      if not old then counts[tab] = counts[tab] + 1 end
      out[#out + 1] = { name = name, body = entry.body, perCharacter = character }
    end
  end
  local general, character, maxGeneral, maxCharacter = M.Limits()
  if general + counts.general > maxGeneral or character + counts.character > maxCharacter then return nil, "Not enough macro slots. Skip entries or use another tab." end
  if #out == 0 then return nil, "Every entry is skipped." end
  return out
end

function S.Review(scope)
  local source = S.window
  if not source or not source.list then return end
  S.scope, S.decisions, S.reviewList = scope, {}, {}
  if S.rename then S.rename:Hide() end
  for i, m in ipairs(source.list) do
    S.reviewList[i] = { name = m.name, body = m.body, perCharacter = m.perCharacter }
    local perCharacter = scope == nil and m.perCharacter or scope == true
    S.decisions[i] = { action = M.Find(H.Trim(m.name), perCharacter) and "skip" or "replace" }
  end
  if not S.review then
    S.review = H.Kit.Browser(H.PREFIX .. "MacroReview", { title = "REVIEW MACRO IMPORT", strata = "FULLSCREEN_DIALOG",
      hint = "Existing names start skipped. Choose Replace, Skip, or Rename for each entry.",
      data = function()
        local out = {}
        for i, m in ipairs(S.reviewList or {}) do
          local d = S.decisions[i]
          out[#out + 1] = { key = i, macro = m, title = d.name or m.name, summary = d.action,
            detail = m.name .. "\n\n" .. m.body .. "\n\n" .. M.Analyze(m.body).errors .. " errors" }
        end
        return out
      end,
      actions = {
        { label = "Skip", run = function(e) S.decisions[e.key] = { action = "skip" } end },
        { label = "Replace / add", run = function(e) S.decisions[e.key] = { action = "replace" } end },
        { label = "Rename", run = function(e)
          if not S.rename then
            S.rename = H.Kit.CopyBox(H.PREFIX .. "MacroRename", { width = 400, height = 240, strata = "FULLSCREEN_DIALOG",
              buttons = { { key = "save", label = "Use name", onClick = function()
                local name = H.Trim(S.rename:GetText())
                if name == "" or #name > M.NAME_MAX or name:find("[\r\n]") then return S.rename:SetStatus("Use 1–16 characters on one line.", "danger") end
                S.decisions[S.rename.index] = { action = "rename", name = name }
                S.rename:Hide(); S.review:Refresh()
              end } } })
          end
          S.rename.index = e.key
          S.rename:SetFrameLevel(S.review:GetFrameLevel() + 10)
          S.rename:Open("IMPORT AS", "Choose an unused macro name.", e.macro.name)
        end },
        { label = "Import selected", always = true, run = function()
          local plan, err = S.Plan(S.reviewList, S.scope, S.decisions)
          if not plan then return false, err end
          local ok = S.Import(S.scope, plan)
          if ok then S.review:Hide() end
          return ok, ok and "Selected macros imported. Backups are in History." or "Import failed; check chat for details."
        end },
      },
    })
  end
  S.review:SetFrameLevel(source:GetFrameLevel() + 10)
  S.review:Open()
end
