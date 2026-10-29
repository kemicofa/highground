"""Interactive motion specimen using the shipped Lua palettes and timings.

Run: python3 tools/motion_preview.py [output.html]
This browser approximation is for review, not a native WoW rendering.
"""
from html import escape
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
from theme_preview import KIT, ORDER, ROOT, fonts, read_themes  # noqa: E402


def read_motion():
    script = r'''
local ns = {}
for _, file in ipairs(arg) do assert(loadfile(file))("Preview", ns) end
for name, theme in pairs(ns.Themes) do
  for _, group in ipairs({ "motion", "alpha" }) do
    for key, value in pairs(theme[group]) do
      print(table.concat({ name, group, key, value }, "\t"))
    end
  end
end
'''
    files = [KIT / "config/Theme.lua", *sorted((KIT / "config/themes").glob("*.lua"))]
    output = subprocess.check_output(["luajit", "-", *map(str, files)], input=script, text=True)
    result = {}
    for line in output.splitlines():
        name, group, key, value = line.split("\t")
        result.setdefault(name, {}).setdefault(group, {})[key] = float(value)
    return result


STYLE = '''
*{box-sizing:border-box}body{margin:0;background:#10161c;color:#e2e8ed;font:16px Barlow,sans-serif;padding:40px}
button,input{font:inherit}button{cursor:pointer}button:disabled{cursor:default}button:focus-visible{outline:2px solid var(--focus,#a8c9ef);outline-offset:3px}
.intro,.toolbar,.grid,.footnote{max-width:1400px;margin:auto}.eyebrow{font:11px JetBrains;letter-spacing:2px;color:#8cc8bf}
h1{font:36px BarlowBold;margin:12px 0 8px}.intro p{margin:0;color:#bac6d0;font-size:17px}
.toolbar{display:flex;align-items:center;justify-content:space-between;gap:24px;margin:28px auto 24px;padding:16px 0;border-top:1px solid #465461;border-bottom:1px solid #465461}
.toolbar label{display:flex;align-items:center;gap:10px}.toolbar input{accent-color:#8cc8bf;width:16px;height:16px}
.timings{display:flex;gap:24px;font:12px JetBrains;color:#bac6d0}.timings strong{color:#e2e8ed;font-weight:normal}
.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px}
.window{background:var(--bg);color:var(--text);border:1px solid var(--borderAccent);--ease:cubic-bezier(.333333,1,.666667,1)}
.window-head{display:flex;align-items:center;justify-content:space-between;gap:16px;padding:20px 24px;border-bottom:1px solid var(--border);border-left:3px solid var(--accent)}
h2{font:24px BarlowBold;color:var(--titleText);margin:0 0 5px}.azeroth h2{font-family:Georgia,serif;font-size:22px}
.window-head p{font-size:14px;margin:0;color:var(--textMuted)}
.replay{flex:none;border:1px solid var(--border);background:var(--surface);color:var(--text);padding:7px 10px;font:12px BarlowSemi}
.tabs{display:flex;gap:8px;padding:14px 24px 0;border-bottom:1px solid var(--border)}
.tab{position:relative;isolation:isolate;border:0;padding:10px 14px;background:none;color:var(--textMuted);font:14px BarlowSemi}
.tab:before{content:"";position:absolute;inset:0;background:var(--surfaceRaised);z-index:-1;opacity:0;transition:opacity var(--m-select) var(--ease)}
.tab:hover:before,.tab[aria-selected=true]:before{opacity:1}.tab[aria-selected=true]{color:var(--accent)}
.tab:after{content:"";position:absolute;inset:auto 0 0;height:2px;background:var(--accent);display:none}
.tab[aria-selected=true]:after{display:block;animation:mark var(--m-select) var(--ease)}
.panel{padding:24px}.panel h3{font:20px BarlowSemi;margin:0 0 6px}.panel p{font-size:14px;color:var(--textMuted);margin:0 0 22px;min-height:18px}
.field-label{display:block;font:11px JetBrains;color:var(--textMuted);margin-bottom:8px}
.input-wrap{position:relative;border:1px solid var(--controlBorder);background:var(--well)}
.input-wrap input{width:100%;background:none;border:0;outline:none;color:var(--text);padding:11px 12px;font:16px BarlowSemi}
.input-wrap input::placeholder{color:var(--textDim)}.input-wrap:focus-within{border-color:var(--focus)}
.input-wrap:after{content:"";position:absolute;inset:auto -1px -1px;height:2px;background:var(--focus);display:none}
.input-wrap:focus-within:after{display:block;animation:mark var(--m-focus) var(--ease)}
.options{display:flex;gap:22px;margin:18px 0 24px;flex-wrap:wrap}
.option{position:relative;display:flex;align-items:center;gap:9px;font-size:14px;cursor:pointer}
.option input{position:absolute;opacity:0;width:16px;height:16px;margin:0}
.check{width:16px;height:16px;border:1px solid var(--controlBorder);background:var(--bg);padding:3px}
.check:after{content:"";display:none;width:8px;height:8px;background:var(--accent)}
.option input:checked+.check:after{display:block;animation:mark var(--m-select) var(--ease)}
.option input:focus-visible+.check{outline:2px solid var(--focus);outline-offset:3px}
.actions{display:flex;gap:10px;flex-wrap:wrap}
.action{position:relative;isolation:isolate;padding:9px 18px;border:1px solid var(--border);background:var(--surface);color:var(--text);font:15px BarlowSemi}
.action.primary{background:var(--accent);color:var(--onAccent);border-color:var(--accent)}
.action:before,.action:after{content:"";position:absolute;inset:0;z-index:-1;opacity:0;pointer-events:none}
.action:before{background:var(--overlayHover);transition:opacity var(--m-exit) var(--ease)}
.action:after{background:var(--overlayStrong);transition:opacity var(--m-press) var(--ease)}
.action:hover:not(:disabled){border-color:var(--controlBorder)}.action:hover:not(:disabled):before{opacity:1;transition-duration:var(--m-hover)}
.action:active:not(:disabled):before{opacity:0;transition-duration:var(--m-press)}.action:active:not(:disabled):after{opacity:1}
.action:disabled{opacity:var(--a-disabled)}
.status{border-top:1px solid var(--border);padding:14px 24px;font:12px BarlowSemi;color:var(--textMuted);display:flex;justify-content:space-between;gap:12px}
.status output{color:var(--accent)}.footnote{font-size:14px;color:#aebbc7;margin-top:24px;line-height:1.5}
.entering{animation:enter var(--m-enter) var(--ease)}.changing{animation:page var(--m-page) var(--ease)}
@keyframes enter{from{opacity:var(--a-enter)}to{opacity:1}}@keyframes page{from{opacity:var(--a-pageEnter)}to{opacity:1}}
@keyframes mark{from{opacity:var(--a-markEnter)}to{opacity:1}}
html[data-reduced=true] *,html[data-reduced=true] *:before,html[data-reduced=true] *:after{animation:none!important;transition:none!important}
@media(prefers-reduced-motion:reduce){html:not([data-reduced=false]) *,html:not([data-reduced=false]) *:before,html:not([data-reduced=false]) *:after{animation:none!important;transition:none!important}}
@media(max-width:1000px){body{padding:24px}.grid{grid-template-columns:1fr}.toolbar{align-items:flex-start;flex-direction:column}.window-head{padding:18px}.panel{padding:20px}.timings{gap:16px}}
'''


SCRIPT = '''
const preference = matchMedia('(prefers-reduced-motion: reduce)');
const reduced = document.querySelector('#reduced-motion');
let manualPreference = false;
function setReduced(on) {
  reduced.checked = on;
  document.documentElement.dataset.reduced = String(on);
  if (on) document.querySelectorAll('.entering,.changing').forEach(el => el.classList.remove('entering', 'changing'));
}
setReduced(preference.matches);
preference.addEventListener('change', e => { if (!manualPreference) setReduced(e.matches); });
reduced.addEventListener('change', () => { manualPreference = true; setReduced(reduced.checked); });
function play(el, effect) {
  if (reduced.checked || el.classList.contains(effect)) return;
  el.classList.add(effect);
}
document.addEventListener('animationend', e => {
  if (e.animationName === 'enter') e.target.classList.remove('entering');
  if (e.animationName === 'page') e.target.classList.remove('changing');
});
const descriptions = {
  Overview: ['Ready for the next match.', 'Choose what you need, then keep your attention on the game.'],
  Appearance: ['Make every interaction clear.', 'Hover, press, and use Tab to explore the focus states.'],
  Profiles: ['Your setup, ready to switch.', 'Pages settle gently. Selected states respond immediately.']
};
document.querySelectorAll('.window').forEach(card => {
  const panel = card.querySelector('.panel');
  const tabs = [...card.querySelectorAll('.tab')];
  const output = card.querySelector('output');
  function select(tab) {
    if (tab.getAttribute('aria-selected') === 'true') return;
    tabs.forEach(t => { t.setAttribute('aria-selected', String(t === tab)); t.tabIndex = t === tab ? 0 : -1; });
    panel.setAttribute('aria-labelledby', tab.id);
    const [title, description] = descriptions[tab.textContent];
    panel.querySelector('h3').textContent = title;
    panel.querySelector('p').textContent = description;
    play(panel, 'changing');
  }
  tabs.forEach((tab, i) => {
    tab.addEventListener('click', () => select(tab));
    tab.addEventListener('keydown', e => {
      if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(e.key)) return;
      e.preventDefault();
      const next = e.key === 'Home' ? 0 : e.key === 'End' ? tabs.length - 1 : (i + (e.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length;
      select(tabs[next]); tabs[next].focus();
    });
  });
  card.querySelector('.replay').addEventListener('click', () => play(card, 'entering'));
  card.querySelector('[data-action=apply]').addEventListener('click', () => { output.textContent = 'Settings applied'; });
  card.querySelector('[data-action=reset]').addEventListener('click', () => {
    card.querySelector('input[type=text]').value = '';
    card.querySelectorAll('.option input').forEach(input => { input.checked = input.defaultChecked; });
    output.textContent = 'Defaults restored';
  });
});
'''


def specimen(name, theme, tokens):
    variables = [f"--{key}:{value}" for key, value in theme["colors"].items()]
    variables += [f"--m-{key}:{value}s" for key, value in tokens["motion"].items()]
    variables += [f"--a-{key}:{value}" for key, value in tokens["alpha"].items()]
    tabs = "".join(
        f'<button class="tab" id="{name}-{label.lower()}" role="tab" aria-selected="{str(label == "Appearance").lower()}" '
        f'aria-controls="{name}-panel" tabindex="{0 if label == "Appearance" else -1}">{label}</button>'
        for label in ("Overview", "Appearance", "Profiles"))
    return f'''
<section class="window {name}" style="{';'.join(variables)}" aria-labelledby="{name}-title">
  <header class="window-head"><div><h2 id="{name}-title">{escape(theme['label'])}</h2><p>{escape(theme['description'])}</p></div>
    <button class="replay" aria-label="Replay {escape(theme['label'])} entrance">Replay entrance</button></header>
  <div class="tabs" role="tablist" aria-label="{escape(theme['label'])} pages">{tabs}</div>
  <div class="panel" id="{name}-panel" role="tabpanel" aria-labelledby="{name}-appearance" tabindex="0">
    <h3>Make every interaction clear.</h3><p>Hover, press, and use Tab to explore the focus states.</p>
    <label class="field-label" for="{name}-profile">PROFILE NAME</label>
    <div class="input-wrap"><input id="{name}-profile" type="text" placeholder="e.g. Arena" autocomplete="off"></div>
    <div class="options">
      <label class="option"><input type="checkbox" checked><span class="check" aria-hidden="true"></span>Match timers</label>
      <label class="option"><input type="checkbox"><span class="check" aria-hidden="true"></span>Nearby enemies</label>
    </div>
    <div class="actions"><button class="action primary" data-action="apply">Apply settings</button>
      <button class="action" data-action="reset">Reset</button><button class="action" disabled>Unavailable</button></div>
  </div>
  <footer class="status"><span>Fixed hit areas · No layout shifts</span><output aria-live="polite">Ready</output></footer>
</section>'''


def main():
    destination = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "dist/motion-preview.html"
    themes, motion = read_themes(), read_motion()
    cards = "".join(specimen(name, themes[name], motion[name]) for name in ORDER)
    timings = "".join(f'<span><strong>{round(motion["highground"]["motion"][key] * 1000)} ms</strong> {key}</span>'
                      for key in ("press", "hover", "enter", "page"))
    document = f'''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Highground · Motion system</title><style>{fonts()}{STYLE}</style></head><body>
<header class="intro"><span class="eyebrow">HIGHGROUND / DESIGN SYSTEM</span><h1>Motion that keeps you oriented.</h1>
<p>Quick feedback. Gentle entrances. The same rhythm in every theme.</p></header>
<div class="toolbar"><label><input id="reduced-motion" type="checkbox">Reduced motion</label><div class="timings">{timings}</div></div>
<main class="grid">{cards}</main><p class="footnote">Interactive browser specimen generated from the shipped Lua colour, timing and opacity tokens.
The addon uses cubic ease-out and respects its own Reduced motion setting. Native rendering still needs an in-game check; Azeroth's Friz font uses a serif fallback here.</p>
<script>{SCRIPT}</script></body></html>'''
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(document)
    print(destination)


if __name__ == "__main__":
    main()
