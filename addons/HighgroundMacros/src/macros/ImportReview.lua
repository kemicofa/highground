local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
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
      if name == "" or #name > M.NAME_MAX or name:find("%c") then return nil, Locale:Get("macros.importreview.every_name_must_be_1_16_characters.252f8a") end
      local identity = tab .. ":" .. name
      if names[identity] then return nil, Locale:Format("macros.importreview.duplicate_import_name_name.8c512c", { name = name }) end
      names[identity] = true
      local check = M.Analyze(entry.body)
      if (check.errors > 0 and entry.body ~= "") or #entry.body > M.BODY_MAX then return nil, Locale:Format("macros.importreview.name_fix_its_errors_or_skip_this.9dc680", { name = name }) end
      local old = M.Find(name, character)
      if d.action == "rename" and old then return nil, Locale:Format("macros.importreview.name_already_exists_choose_another_name_or.626b5a", { name = name }) end
      if not old then counts[tab] = counts[tab] + 1 end
      out[#out + 1] = { name = name, body = entry.body, perCharacter = character }
    end
  end
  local general, character, maxGeneral, maxCharacter = M.Limits()
  if general + counts.general > maxGeneral or character + counts.character > maxCharacter then return nil, Locale:Get("macros.importreview.not_enough_macro_slots_skip_entries_or.01c847") end
  if #out == 0 then return nil, Locale:Get("macros.importreview.every_entry_is_skipped.7894bb") end
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
    S.review = H.Kit.Browser(H.PREFIX .. "MacroReview", { title = Locale:Get("macros.importreview.review_macro_import.debd35"), strata = "FULLSCREEN_DIALOG", child = true,
      hint = Locale:Get("macros.importreview.existing_names_start_skipped_choose_replace_skip.a5a342"),
      data = function()
        local out = {}
        for i, m in ipairs(S.reviewList or {}) do
          local d = S.decisions[i]
          out[#out + 1] = { key = i, macro = m, title = d.name or m.name, summary = d.action,
            detail = Locale:Format("macros.importreview.m_name_m_body_value5_errors.8e0e94", { m_name = m.name, m_body = m.body, value5 = M.Analyze(m.body).errors }) }
        end
        return out
      end,
      actions = {
        { label = Locale:Get("macros.importreview.skip.3da474"), run = function(e) S.decisions[e.key] = { action = "skip" } end },
        { label = Locale:Get("macros.importreview.replace_add.6f9985"), run = function(e) S.decisions[e.key] = { action = "replace" } end },
        { label = Locale:Get("macros.importreview.rename.d3f4cb"), run = function(e)
          if not S.rename then
            S.rename = H.Kit.CopyBox(H.PREFIX .. "MacroRename", { width = 400, height = 240, strata = "FULLSCREEN_DIALOG",
              buttons = { { key = "save", label = Locale:Get("macros.importreview.use_name.e8e838"), onClick = function()
                local name = H.Trim(S.rename:GetText())
                if name == "" or #name > M.NAME_MAX or name:find("[\r\n]") then return S.rename:SetStatus(Locale:Get("macros.importreview.use_1_16_characters_on_one_line.c12e9b"), "danger") end
                S.decisions[S.rename.index] = { action = "rename", name = name }
                S.rename:Hide(); S.review:Refresh()
              end } } })
          end
          S.rename.index = e.key
          S.rename:SetFrameLevel(S.review:GetFrameLevel() + 10)
          S.rename:Open(Locale:Get("macros.importreview.import_as.ebe195"), Locale:Get("macros.importreview.choose_an_unused_macro_name.b58560"), e.macro.name)
        end },
        { label = Locale:Get("macros.importreview.import_selected.7fb57e"), always = true, run = function()
          local plan, err = S.Plan(S.reviewList, S.scope, S.decisions)
          if not plan then return false, err end
          local ok = S.Import(S.scope, plan)
          if ok then S.review:Hide() end
          return ok, ok and Locale:Get("macros.importreview.selected_macros_imported_backups_are_in_history.a45d74") or Locale:Get("macros.importreview.import_failed_check_chat_for_details.d3c67c")
        end },
      },
    })
  end
  S.review:SetFrameLevel(source:GetFrameLevel() + 10)
  S.review:ResetNavigation()
  S.review:Open()
end
