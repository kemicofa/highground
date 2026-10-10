-- Load the real manifest's data and pure rules without a WoW client.
return function(client)
  local ns = {}
  local toc = client == "cata" and "Warboard_Cata.toc" or "Warboard.toc"
  for line in io.lines(toc) do
    line = line:match("^%s*(.-)%s*$")
    if line == "Core.lua" then break end
    if line ~= "" and line:sub(1, 1) ~= "#" then
      assert(loadfile(line))("Warboard", ns)
    end
  end
  assert(ns.CLIENT == client, "wrong client configuration loaded")
  return ns
end
