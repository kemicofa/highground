-- Edit boxes and lists, exercised through Highground's client manifests by
-- ui_components.lua.
return function(s, t)
  local K, env = s.ns.Kit, s.env

  t.test("colour edit boxes colour each change once", function()
    local calls = 0
    local box = env.CreateFrame("EditBox", nil, env.UIParent)
    K.ColorEditBox(box, function(plain)
      calls = calls + 1
      return "|cff336699" .. plain:gsub("|", "||") .. "|r"
    end)
    box:SetText("/cast Frostbolt")
    t.equal(calls, 1, "a change is coloured once, not again to show it")
    t.equal(box:GetPlainText(), "/cast Frostbolt", "the coloured text reads back as typed")
    box:SetText(box:GetText())
    t.equal(calls, 2, "already coloured text is checked once and kept")
    box:SetPlainText("/say a|b")
    t.equal(calls, 3, "setting plain text colours it once")
    t.equal(box:GetPlainText(), "/say a|b", "a typed bar survives")
    box:Hide()
  end)
end
