local _, ns = ...
local O, C, Kit, Theme = ns.Options, ns.CommandCatalog, ns.Kit, ns.Theme

local function Available(row)
  return ns.OptionAvailable(row) and (row.owner == "shared" or ns.Modules.Active(row.owner))
end
local function Run(row, values)
  if not Available(row) then
    if row.owner ~= "shared" then ns.Modules.Require(row.owner) end
    return false, ns.Locale:Get("highground.tools.this_command_is_unavailable.f5762b")
  end
  local message, problem = C.Format(row, values)
  if not message then return false, problem end
  SlashCmdList.HIGHGROUND(message)
  return true
end

-- A bounded, reused form supplies labeled arguments, never a raw slash box.
local form
local function Form(row)
  if not form then
    form = ns.Localization.BindWidget(Kit.Dialog("HighgroundCommandForm", { title = ns.Locale:Get("highground.tools.command_controls.c26067"), width = 610, height = 420, child = true }), { title = "highground.tools.command_controls.c26067" })
    O.commandForm = form
    form.fields = {}
    form.note = Theme.Text(form, "body", "text")
    form.note:SetPoint("TOPLEFT", 24, -82); form.note:SetPoint("TOPRIGHT", -24, -82)
    form.note:SetJustifyH("LEFT"); form.note:SetWordWrap(true)
    form.status = Theme.Text(form, "body", "warning")
    form.status:SetPoint("BOTTOMLEFT", 24, 64); form.status:SetPoint("BOTTOMRIGHT", -24, 64)
    form.status:SetJustifyH("LEFT"); form.status:SetWordWrap(true)
    form.apply = ns.Localization.Bind(Kit.Button(form, ns.Locale:Get("highground.profiles.apply.cfea41"), 180, 34, { onClick = function()
      local values = {}
      for i, field in ipairs(form.row.fields or {}) do
        local control = form.fields[i]
        values[i] = field.choices and control.select:GetValue() or control.input:GetText()
      end
      -- Close before dispatch so a command can open its own review dialog.
      local message, problem = C.Format(form.row, values)
      if not message then form.status:SetText(problem); return end
      local selected = form.row
      form:Hide()
      local ok, err = Run(selected, values)
      if not ok then ns.Util.Say(err) end
    end }), "highground.profiles.apply.cfea41")
    form.apply:SetPoint("BOTTOMRIGHT", -24, 20)
    form.cancel = ns.Localization.Bind(Kit.Button(form, ns.Locale:Get("highground.root.cancel.77dfd2"), 120, 34, { onClick = function() form:Hide() end }), "highground.root.cancel.77dfd2")
    form.cancel:SetPoint("RIGHT", form.apply, "LEFT", -12, 0)
  end
  form.row = row
  form:SetTitle(C.Label(row))
  form.note:SetText(C.Description(row) .. (row.confirm and "\n\n" .. row.confirm or ""))
  form.note:SetHeight(form.note:GetStringHeight())
  form.status:SetText("")
  form.apply:SetText(row.confirm and ns.Locale:Get("highground.tools.confirm.04a212") or ns.Locale:Get("highground.profiles.apply.cfea41"))
  for _, field in ipairs(form.fields) do field.label:Hide(); field.input:Hide(); field.select:Hide() end
  local y = 100 + form.note:GetHeight()
  for i, field in ipairs(row.fields or {}) do
    local control = form.fields[i]
    if not control then
      control = { label = Theme.Text(form, "body", "text"), input = Kit.Input(form, 530, ""),
        select = Kit.Select(form, { width = 530, menu = true }) }
      form.fields[i] = control
      control.label:SetJustifyH("LEFT"); control.label:SetWordWrap(true)
    end
    ns.Localization.BindField(control.label, field, "label"); control.label:SetPoint("TOPLEFT", 24, -y); control.label:SetPoint("TOPRIGHT", -24, -y); control.label:Show()
    local height = math.max(20, control.label:GetStringHeight())
    control.label:SetHeight(height); y = y + height + 8
    local choices = C.Choices(field)
    if choices then
      control.select:SetChoices(choices)
      control.select:SetValue(field.default or choices[1] and choices[1].key, true)
      control.select:SetPoint("TOPLEFT", 24, -y); control.select:Show()
    else
      control.input:SetText(field.default or ""); control.input:SetPoint("TOPLEFT", 24, -y)
      control.input:Show(); control.input:ClearFocus()
    end
    y = y + 52
  end
  form:SetHeight(math.max(300, y + 120))
  Kit.Windows.Show(form)
end

function O.OpenCommand(row)
  if not Available(row) then
    if row.owner ~= "shared" then ns.Modules.Require(row.owner) end
    return
  end
  if row.ui.tool then return O.OpenTool(row.ui.tool) end
  if row.ui.page then return ns.Hub.Open(row.ui.page) end
  if row.fields or row.confirm then return Form(row) end
  return Run(row)
end

local function Build(page, owner)
  local entries = {}
  page.commandRows = {}
  for _, group in ipairs(C.groups) do
    if not owner or group.owner == owner then
      if not owner then
        local heading = Theme.Text(page.child, "heading", "accent")
        ns.Localization.BindField(heading, group, "label"); heading:SetJustifyH("LEFT"); heading:SetWordWrap(true)
        entries[#entries + 1] = { heading = heading }
      end
      for _, row in ipairs(group.commands) do
        if ns.OptionAvailable(row) then
          local syntax = row[1]:gsub("|", "||") -- shown as text, not escape codes
          local function tooltip()
            local lines = { { syntax, "gold", true }, C.Description(row) }
            if #(row.aliases or {}) > 0 then lines[#lines + 1] = ns.Locale:Format("highground.tools.also_hg_value2.5bdb3e", { value2 = table.concat(row.aliases, ", /hg ") }) end
            lines[#lines + 1] = C.Label(row)
            return lines
          end
          local actionKey = row.confirm and "highground.tools.review.ce9d6d" or (row.ui.page or row.ui.tool or row.fields)
            and "shared.actionrow.open.cf9b77" or "highground.tools.run.b1b392"
          local action = ns.Locale:Get(actionKey)
          local frame = Kit.ActionRow(page.child, { label = syntax, detail = C.Description(row), action = action,
            role = "code", color = "gold", tooltip = tooltip, onClick = function() O.OpenCommand(row) end })
          if row.descriptionKey then ns.Localization.Bind(frame.detail, row.descriptionKey) end
          ns.Localization.Bind(frame.button, actionKey)
          local item = { frame = frame, code = frame.label, description = frame.detail, button = frame.button, definition = row }
          entries[#entries + 1] = item
          page.commandRows[#page.commandRows + 1] = item
        end
      end
    end
  end
  function page.LayoutCommands()
    if page.layingOutCommands then return end
    page.layingOutCommands = true
    local y, width = 8, math.max(1, page.child:GetWidth() - 48)
    for _, item in ipairs(entries) do
      if item.heading then
        item.heading:SetPoint("TOPLEFT", 24, -y); item.heading:SetPoint("TOPRIGHT", -24, -y)
        local height = math.max(24, item.heading:GetStringHeight())
        item.heading:SetHeight(height); y = y + height + 16
      else
        Kit.Place(item.frame, "TOPLEFT", page.child, "TOPLEFT", 24, -y)
        local height = item.frame:Layout(width)
        item.button:SetEnabled(Available(item.definition))
        y = y + height + Theme.Space("sm")
      end
    end
    page.child:SetHeight(y + 16)
    page.layingOutCommands = nil
  end
  page.child:HookScript("OnSizeChanged", page.LayoutCommands)
  page.frame:HookScript("OnShow", page.LayoutCommands)
  ns.Core.OnFontScaleChange(function() if page.frame:IsVisible() then page.LayoutCommands() end end)
  ns.Localization.Watch(page, function(self) if self.frame:IsVisible() then self.LayoutCommands() end end)
  page.LayoutCommands()
end

local function Page(key, owner)
  local page = O.MakePage(key)
  page.commands = {}
  for _, row in ipairs(C.commands) do
    if row[2] and (not owner or row.owner == owner) and ns.OptionAvailable(row) then page.commands[#page.commands + 1] = row[1] end
  end
  page.build = function() Build(page, owner) end
  return page
end
O.tools = Page("tools")
for _, module in ipairs(ns.Modules.list) do Page(O.addonPages[module.key].commands, module.key) end
