#!/usr/bin/env python3
"""Render actual simulated frame geometry, not a separate proposed layout.
Font metrics/native game effects remain approximate; inspect in WoW too.
"""
import argparse
import base64
import html
import json
from pathlib import Path
import re
import subprocess
from preview_assets import crest_data, tga_data

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--theme', default='azeroth')
p.add_argument('--scale', default='1')
p.add_argument('--locale', default='enUS', help='Saved addon display locale for the simulated controls')
p.add_argument('--state', default='draft', choices=['draft', 'empty', 'expanded', 'completion', 'hub', 'presets', 'presets-code', 'hub-presets-code', 'target', 'manual', 'home', 'addons', 'module', 'config', 'commands', 'features', 'alerts', 'guide', 'guide-window', 'guide-sample', 'setup', 'journal', 'journal-window', 'journal-bounty', 'journal-note', 'history-window', 'reputation', 'bounties', 'bounty-tour', 'bounty-tour-kill', 'bounty-tour-create', 'bounty-tour-gold', 'bounty-tour-share', 'bounty-tour-pot', 'bounty-form', 'bounty-gold', 'bounty-funding', 'bounty-list', 'bounty-shared', 'bounty-details', 'bounty-test', 'bounty-test-details', 'bounty-claims', 'bounty-poster', 'bounty-match', 'bounty-killed', 'bounty-hunt', 'bounty-export', 'battleground', 'battleground-hero'])
p.add_argument('--chapter', default='', help='Guide chapter, module key, or config page key')
p.add_argument('--step', default='', help='Step number within a guide sample or bounty form; pending shows addon changes in guide/guide-window')
p.add_argument('--map-art', default='', help='Optional local directory of WarsongGulch1.PNG through WarsongGulch12.PNG for map sample previews')
p.add_argument('--standalones', action='store_true', help='Show all six redundant standalone downloads installed alongside Highground')
a = p.parse_args()
data = json.loads(subprocess.check_output(['luajit', '../../tools/macro_preview.lua', a.theme, a.scale, a.state, a.chapter, a.step, a.map_art, 'standalones' if a.standalones else '', a.locale], cwd=ROOT/'addons/Highground'))
css = []
crest = crest_data()
logos = {path.stem: tga_data(path) for path in (ROOT/'addons/Highground/assets/logos').glob('*.tga')}
for font in (ROOT/'libs/HighgroundKit/media').glob('*.ttf'):
    encoded = base64.b64encode(font.read_bytes()).decode()
    css.append(f'@font-face{{font-family:"{font.stem}";src:url(data:font/ttf;base64,{encoded})}}')

def rgba(c):
    return f'rgba({c[0]*255:.0f},{c[1]*255:.0f},{c[2]*255:.0f},{c[3] if len(c)>3 else 1})'

def colored(text):
    text = html.escape(text).replace('||', '|')
    text = re.sub(r'\|[TA][^|]*\|[ta]', '◆', text)  # game-supplied inline icons
    text = re.sub(r'\|c([0-9a-fA-F]{2})([0-9a-fA-F]{6})', r'<span style="color:#\2">', text)
    return text.replace('|r', '</span>')

body = []
for f in data['frames']:
    x, y, w, h = f['bounds']
    if w <= 0 or h <= 0:
        continue
    z = f['depth']*8 + {'BACKGROUND': -4, 'BORDER': -2, 'ARTWORK': 0, 'OVERLAY': 2}.get(f.get('layer'), 3)
    z += {'BACKGROUND': 0, 'LOW': 100, 'MEDIUM': 200, 'HIGH': 300, 'DIALOG': 400,
          'FULLSCREEN': 500, 'FULLSCREEN_DIALOG': 600, 'TOOLTIP': 700}.get(f.get('strata'), 200)
    if f.get('popup'):
        z += 1000
    if f.get('coached'):
        z += 2000
    if f['kind'] == 'EditBox':
        z += 10
    style = [f'left:{x}px;top:{y}px;width:{w}px;height:{h}px;z-index:{z}']
    if f.get('alpha') is not None:
        style.append('opacity:'+str(f['alpha']))
    if f.get('color'):
        style.append('background:'+rgba(f['color']))
    if f.get('gradient'):
        gradient = f['gradient']
        direction = 'to top' if gradient['direction'] == 'VERTICAL' else 'to right'
        style.append(f'background:linear-gradient({direction},{rgba(gradient["from"])},{rgba(gradient["to"])})')
    if f.get('crest'):
        style.append(f'background:url({crest}) center/contain no-repeat')
    if f.get('guideLogo'):
        style.append(f'background:url({logos[f["guideLogo"]]}) center/contain no-repeat')
    if f.get('sampleTile'):
        tile = Path(a.map_art) / f'WarsongGulch{f["sampleTile"]}.PNG'
        encoded = base64.b64encode(tile.read_bytes()).decode()
        coords = f.get('texCoord') or [0, 1, 0, 1]
        style.append(f'background:url(data:image/png;base64,{encoded}) top left/{w/coords[1]}px {h/coords[3]}px no-repeat')
    if f.get('circle'):
        style.append('border-radius:50%;background:'+rgba(f.get('vertex') or [1, 1, 1, 1]))
    if f.get('class'):
        style.append('border-radius:50%;background:#202020;color:#fff;font:11px Arial;text-align:center;line-height:'+str(h)+'px')
    if f.get('border'):
        style.append('outline:1px solid '+rgba(f['border']))
    if f.get('ink'):
        style.append('color:'+rgba(f['ink']))
    if f.get('font'):
        file, size, *_ = f['font']
        size *= f.get('scale', 1)
        family = Path(file.replace('\\', '/')).stem
        style.append(f'font-family:"{family}",Georgia,serif;font-size:{size}px;line-height:1.2')
    if f.get('align'):
        style.append('text-align:'+f['align'].lower())
    if f.get('wrap') is False:
        style.append('white-space:nowrap;text-overflow:ellipsis')
        if f.get('valign') == 'MIDDLE':
            style.append(f'line-height:{h}px')
    if f.get('rotation'):
        style.append(f'transform:rotate({-f["rotation"]}rad)')
    if f.get('clip'):
        cx, cy, cw, ch = f['clip']
        style.append(f'clip-path:inset({max(0, cy-y)}px {max(0, x+w-cx-cw)}px {max(0, y+h-cy-ch)}px {max(0, cx-x)}px)')
    if f['kind']=='EditBox':
        style.append('padding-left:4px')
    if f.get('check'):
        style.append('color:#338b46;font:24px Arial;text-align:center')
    text = '✓' if f.get('check') else colored(f.get('text') or '')
    if f.get('class'):
        text = html.escape(f['class'][:2].upper())
    body.append(f'<div class="region" style="{html.escape(";".join(style), quote=True)}">{text}</div>')
page = '<!doctype html><meta charset="utf-8"><style>body{margin:0;background:#303b36}.region{position:absolute;box-sizing:border-box;white-space:pre-wrap;overflow:hidden}'+''.join(css)+'</style>'+''.join(body)
suffix = ('-' + re.sub(r'[^a-z0-9-]', '', a.chapter)) if a.chapter else ''
if a.locale != 'enUS':
    suffix += '-' + re.sub(r'[^A-Za-z]', '', a.locale)
if a.standalones:
    suffix += '-standalones'
if a.step:
    suffix += '-step' + re.sub(r'[^a-z0-9-]', '', a.step)
out = ROOT/'dist'/f'macro-{a.theme}-{a.state}-{a.scale}{suffix}.html'
out.parent.mkdir(exist_ok=True)
out.write_text(page)
print(out)
