"""Render the actual Lua theme tokens as a portable, side-by-side HTML specimen.

Run from anywhere: python3 tools/theme_preview.py [output.html]
This is a palette / typography review, not an in-game screenshot. Warcraft's
Friz Quadrata is supplied by the game; the preview uses a system serif fallback.
"""
import base64
from html import escape
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
KIT = ROOT / "libs" / "HighgroundKit"
ORDER = ("highground", "ember", "parchment", "azeroth")
EXPORT = r'''
local ns = {}
for _, file in ipairs(arg) do assert(loadfile(file))("Preview", ns) end
for name, theme in pairs(ns.Themes) do
  print("theme\t" .. name .. "\t" .. theme.label .. "\t" .. theme.description)
  for key, c in pairs(theme.color) do
    print(table.concat({ "color", name, key, c[1], c[2], c[3], c[4] or 1 }, "\t"))
  end
end
'''


def read_themes():
    files = [KIT / "config" / "Theme.lua", *sorted((KIT / "config" / "themes").glob("*.lua"))]
    lines = subprocess.run(["luajit", "-", *map(str, files)], input=EXPORT,
                           text=True, capture_output=True, check=True).stdout.splitlines()
    themes = {}
    for line in lines:
        kind, name, *parts = line.split("\t")
        theme = themes.setdefault(name, {"colors": {}})
        if kind == "theme":
            theme["label"], theme["description"] = parts
        else:
            token, *rgba = parts
            r, g, b, a = map(float, rgba)
            theme["colors"][token] = f"rgba({round(r * 255)}, {round(g * 255)}, {round(b * 255)}, {a})"
    return themes


def fonts():
    css = []
    for family, file in (("Barlow", "BarlowCondensed-Medium.ttf"),
                         ("BarlowSemi", "BarlowCondensed-SemiBold.ttf"),
                         ("BarlowBold", "BarlowCondensed-Bold.ttf"),
                         ("JetBrains", "JetBrainsMono-Bold.ttf")):
        data = base64.b64encode((KIT / "media" / file).read_bytes()).decode()
        css.append(f"@font-face{{font-family:{family};src:url(data:font/ttf;base64,{data})}}")
    return "\n".join(css)


STYLE = '''
*{box-sizing:border-box}body{margin:0;padding:30px;background:#101316;color:#dce2e8;font-family:Barlow,sans-serif}
.intro{display:flex;align-items:baseline;justify-content:space-between;max-width:1500px;margin:0 auto 24px}
h1{font:28px BarlowSemi;margin:0}.intro p{font-size:16px;color:#bac6d0;margin:0}
.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px;max-width:1500px;margin:auto}
.theme{background:var(--bg);color:var(--text);border:1px solid var(--borderAccent)}
.header{height:72px;padding:14px 22px;position:relative;border-bottom:1px solid var(--border)}
.header:before{content:"";position:absolute;inset:0 auto 0 0;width:3px;background:var(--accent)}
.header h2{font:24px BarlowBold;margin:0 0 5px;color:var(--titleText)}
.azeroth .header h2{font:23px Georgia,serif;letter-spacing:1px}
.header p{color:var(--textMuted);margin:0;font-size:14px}.close{position:absolute;right:16px;top:18px;color:var(--textMuted)}
.content{display:grid;grid-template-columns:134px 1fr;min-height:353px}
nav{padding:20px 10px;background:var(--surface);border-right:1px solid var(--border);font:14px BarlowSemi}
nav div{padding:9px 12px;margin:2px 0;color:var(--textMuted)}
nav .active{background:var(--surfaceRaised);color:var(--accent);border-left:3px solid var(--accent);padding-left:9px}
nav .caption{font:11px BarlowSemi;letter-spacing:1px;margin-top:18px;color:var(--textDim)}
main{padding:20px}.section{display:flex;justify-content:space-between;align-items:center;margin-bottom:14px}
h3{font:17px BarlowSemi;margin:0}.subtle{font-size:13px;color:var(--textMuted)}
.row{background:var(--surface);display:grid;grid-template-columns:24px 1fr auto;gap:10px;padding:10px 12px;margin:5px 0;align-items:center;border-left:3px solid var(--border)}
.row.selected{border-left-color:var(--accent);background:var(--surfaceRaised)}
.rank{font:12px JetBrains;color:var(--textMuted)}.selected .rank{color:var(--accent)}
.name{font:16px BarlowSemi}.detail{font-size:12px;color:var(--textMuted);margin-top:3px}
.chip{background:var(--chipBg);font:10px JetBrains;padding:5px 7px;color:var(--chipCc)}
.danger{color:var(--chipBurst)}.success{color:var(--chipSpent)}
.controls{display:flex;gap:10px;align-items:center;margin:17px 0 14px}
.button{font:13px BarlowSemi;padding:7px 13px;border:1px solid var(--border);background:var(--surface);color:var(--text)}
.primary{background:var(--accent);color:var(--onAccent);border-color:var(--accent)}
.input{background:var(--well);border:1px solid var(--focus);border-bottom:2px solid var(--focus);padding:7px 10px;font:13px BarlowSemi;flex:1}
.settings{display:flex;gap:18px;align-items:center;font:13px BarlowSemi;color:var(--textMuted)}
.check{display:inline-block;width:16px;height:16px;border:1px solid var(--controlBorder);background:var(--bg);vertical-align:-3px;margin-right:6px;padding:3px}
.check:after{content:"";display:block;background:var(--accent);width:8px;height:8px}
.footer{display:flex;justify-content:space-between;gap:12px;padding:12px 20px;border-top:1px solid var(--border);font-size:13px;color:var(--textMuted)}
.swatches{display:flex;gap:6px}.swatches i{width:14px;height:14px;background:var(--accent);display:inline-block}
.footnote{max-width:1500px;margin:20px auto 0;color:#aebbc7;font-size:14px}
@media(max-width:1000px){.grid{grid-template-columns:1fr}.intro{display:block}.intro p{margin-top:10px}}
'''


def specimen(name, theme):
    variables = ";".join(f"--{token}:{color}" for token, color in theme["colors"].items())
    swatches = "".join(f'<i style="background:var(--{token})"></i>'
                       for token in ("accent", "gold", "success", "danger", "info", "scopeCharacter"))
    return f'''
<section class="theme {name}" style="{variables}">
  <header class="header"><h2>{escape(theme['label'])}</h2><p>{escape(theme['description'])}</p><span class="close">×</span></header>
  <div class="content">
    <nav><div>Overview</div><div class="active">Appearance</div><div>Profiles</div>
      <div class="caption">BATTLEGROUND</div><div>Enemy roster</div><div>Timers</div><div>Bounties</div></nav>
    <main>
      <div class="section"><h3>Keep the next move clear.</h3><span class="subtle">Warsong Gulch</span></div>
      <div class="row selected"><span class="rank">01</span><div><div class="name">Aeloria</div><div class="detail">Restoration · Priority target · 24 yd</div></div><span class="chip danger">BURST</span></div>
      <div class="row"><span class="rank">02</span><div><div class="name">Thornwick</div><div class="detail">Arms · Focus target · 18 yd</div></div><span class="chip">CC</span></div>
      <div class="row"><span class="rank">03</span><div><div class="name">Vaelith</div><div class="detail">Discipline · No cooldowns · 31 yd</div></div><span class="chip success">SPENT</span></div>
      <div class="controls"><span class="input">Search players…</span><span class="button">Reset</span><span class="button primary">Apply</span></div>
      <div class="settings"><span><i class="check"></i>Reduced motion</span><span>Text size &nbsp; 100%</span></div>
    </main>
  </div>
  <footer class="footer"><span>Primary text <span class="subtle">/ Supporting text</span> <span style="color:var(--textDim)">/ Quiet detail</span></span><span class="swatches">{swatches}</span></footer>
</section>'''


def main():
    destination = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dist" / "theme-preview.html"
    themes = read_themes()
    cards = "".join(specimen(name, themes[name]) for name in ORDER)
    document = f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Highground · Theme study</title><style>{fonts()}{STYLE}</style>
<div class="intro"><h1>Highground · Four quieter ways to play</h1><p>Shared type. Clear states. A palette for every panel.</p></div>
<div class="grid">{cards}</div><p class="footnote">Palette specimen generated from the Lua tokens. In-game geometry and icons differ; Azeroth's Friz Quadrata is approximated here with a system serif.</p></html>'''
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(document)
    print(destination)


if __name__ == "__main__":
    main()
