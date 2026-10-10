"""Check release manifests, XML references, and Lua 5.1 compilation."""
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
for toc, client in [("Warboard.toc", "retail"), ("Warboard_Cata.toc", "cata")]:
    entries = [s.strip() for s in (root / toc).read_text().splitlines() if s.strip() and not s.startswith("#")]
    assert len(entries) == len(set(entries)), f"Duplicate load entry in {toc}"
    assert f"config/{client}/Classes.lua" in entries
    other = "cata" if client == "retail" else "retail"
    assert f"config/{other}/Classes.lua" not in entries, f"Wrong client in {toc}"
    assert entries.index("Rules.lua") < entries.index("Core.lua")
    for name in entries:
        assert (root / name).is_file(), f"Missing {name} in {toc}"
    actual = {p.relative_to(root).as_posix() for p in (root / "config/battlegrounds").glob("*.lua")}
    assert actual <= set(entries), f"Unloaded battleground config in {toc}"
for path in root.glob("*.xml"):
    tree = ET.parse(path)
    for node in tree.iter():
        if node.tag.rsplit("}", 1)[-1] in {"Script", "Include"} and "file" in node.attrib:
            assert (path.parent / node.attrib["file"]).is_file(), f"Missing XML script in {path.name}"
files = list(root.glob("*.lua")) + list((root / "config").rglob("*.lua")) + list((root / "tests").glob("*.lua"))
for path in files:
    subprocess.run(["luajit", "-b", str(path), "/dev/null"], check=True)
print(f"Manifests, XML, and {len(files)} Lua files validated")
