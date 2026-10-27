-- docs/commands.md mirrors the command catalog (config/Commands.lua).
local ns = {}
assert(loadfile("config/Commands.lua"))("Warboard", ns)
local file = assert(io.open("docs/commands.md"))
local doc = file:read("*a")
file:close()

local lines = {}
for line in doc:gmatch("[^\n]+") do lines[line] = true end

-- "a  |  b" -> "a | b"; pipes are escaped in Markdown tables.
local function Code(s) return (s:gsub("%s+|%s+", " | "):gsub("|", "\\|")) end
local function Cata(row) return row.cata and " (Cata)" or "" end

local checks, missing = 0, {}
local function Expect(line)
  checks = checks + 1
  if not lines[line] then missing[#missing + 1] = line end
end
for _, row in ipairs(ns.CommandCatalog.commands) do
  if row[2] then
    Expect("| `" .. Code(row[1]) .. "` | " .. row[2] .. Cata(row) .. " |")
  else
    Expect("## " .. row[1])
  end
end
for _, p in ipairs(ns.CommandCatalog.previews) do
  Expect("| " .. p.label .. " | `/wb " .. p.cmd .. "` | " .. p.desc .. Cata(p) .. " |")
end
assert(#missing == 0, "docs/commands.md is missing catalog rows (config/Commands.lua):\n  " .. table.concat(missing, "\n  "))

-- No command rows that the catalog does not have.
local rows = 0
for line in doc:gmatch("[^\n]+") do
  if line:match("^| `/wb") then rows = rows + 1 end
end
local listed = 0
for _, row in ipairs(ns.CommandCatalog.commands) do if row[2] then listed = listed + 1 end end
assert(rows == listed, "docs/commands.md has " .. rows .. " command rows, the catalog " .. listed)
print("Docs: " .. checks .. " command catalog rows match docs/commands.md")
