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

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('--theme', default='azeroth')
p.add_argument('--scale', default='1')
p.add_argument('--state', default='draft', choices=['draft', 'empty', 'expanded', 'completion', 'hub', 'presets', 'presets-code', 'hub-presets-code', 'target', 'manual', 'home', 'features', 'alerts', 'guide', 'setup', 'journal', 'bounties', 'bounty-form', 'bounty-list', 'bounty-shared', 'bounty-details', 'bounty-claims', 'battleground'])
a = p.parse_args()
data = json.loads(subprocess.check_output(['luajit', '../../tools/macro_preview.lua', a.theme, a.scale, a.state], cwd=ROOT/'addons/Highground'))
css = []
for font in (ROOT/'libs/HighgroundKit/media').glob('*.ttf'):
    encoded = base64.b64encode(font.read_bytes()).decode()
    css.append(f'@font-face{{font-family:"{font.stem}";src:url(data:font/ttf;base64,{encoded})}}')

def rgba(c):
    return f'rgba({c[0]*255:.0f},{c[1]*255:.0f},{c[2]*255:.0f},{c[3] if len(c)>3 else 1})'

def colored(text):
    text = html.escape(text).replace('||', '|')
    text = re.sub(r'\|c([0-9a-fA-F]{2})([0-9a-fA-F]{6})', r'<span style="color:#\2">', text)
    return text.replace('|r', '</span>')

body = []
for f in data['frames']:
    x, y, w, h = f['bounds']
    if w <= 0 or h <= 0:
        continue
    z = f['depth']*8 + {'BACKGROUND': -4, 'BORDER': -2, 'ARTWORK': 0, 'OVERLAY': 2}.get(f.get('layer'), 3)
    if f.get('popup'):
        z += 1000
    if f['kind'] == 'EditBox':
        z += 10
    style = [f'left:{x}px;top:{y}px;width:{w}px;height:{h}px;z-index:{z}']
    if f.get('alpha') is not None:
        style.append('opacity:'+str(f['alpha']))
    if f.get('color'):
        style.append('background:'+rgba(f['color']))
    if f.get('border'):
        style.append('outline:1px solid '+rgba(f['border']))
    if f.get('ink'):
        style.append('color:'+rgba(f['ink']))
    if f.get('font'):
        file, size, *_ = f['font']
        family = Path(file.replace('\\', '/')).stem
        style.append(f'font-family:"{family}",Georgia,serif;font-size:{size}px;line-height:1.2')
    if f.get('align'):
        style.append('text-align:'+f['align'].lower())
    if f.get('rotation'):
        style.append(f'transform:rotate({-f["rotation"]}rad)')
    if f.get('clip'):
        cx, cy, cw, ch = f['clip']
        style.append(f'clip-path:inset({max(0, cy-y)}px {max(0, x+w-cx-cw)}px {max(0, y+h-cy-ch)}px {max(0, cx-x)}px)')
    if f['kind']=='EditBox':
        style.append('padding-left:4px')
    text = colored(f.get('text') or '')
    body.append(f'<div class="region" style="{html.escape(";".join(style), quote=True)}">{text}</div>')
page = '<!doctype html><meta charset="utf-8"><style>body{margin:0;background:#303b36}.region{position:absolute;box-sizing:border-box;white-space:pre-wrap;overflow:hidden}'+''.join(css)+'</style>'+''.join(body)
out = ROOT/'dist'/f'macro-{a.theme}-{a.state}-{a.scale}.html'
out.parent.mkdir(exist_ok=True)
out.write_text(page)
print(out)
