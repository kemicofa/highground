"""Export five stream-banner layouts at three sizes in both faction colors.

Requires the existing banner sources, FFmpeg, librsvg and gifsicle (preferred)
or ImageMagick. PNGs, GIFs and transparent WebMs are organized by aspect ratio.
"""

from __future__ import annotations

import argparse
import base64
from dataclasses import dataclass
from html import escape
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

import export_stream_banner as core


@dataclass(frozen=True)
class Format:
    key: str
    label: str
    purpose: str
    sizes: tuple[tuple[int, int], ...]


FORMATS = [
    Format("20x3", "SLIM / ORIGINAL", "Bottom overlay with balanced logo and copy",
           ((960, 144), (1600, 240), (1920, 288))),
    Format("5x1", "WIDE", "Requested 5:1 format, starting at 1400 x 280",
           ((1400, 280), (1600, 320), (1920, 384))),
    Format("8x1", "ULTRA-WIDE", "Thin bottom strip with the least vertical coverage",
           ((960, 120), (1440, 180), (1920, 240))),
    Format("4x1", "COMPACT", "Roomier overlay or promotional banner",
           ((960, 240), (1440, 360), (1920, 480))),
    Format("3x1", "PROMO", "Large crest and readable copy for intermission scenes",
           ((960, 320), (1440, 480), (1920, 640))),
]


LAYOUTS = {
    "8x1": dict(height=200, logo=(4, 0, 200, 184), left=250, top=20,
                kicker=(46, 18), title=(99, 60), badge=(585, 66, 150, 30, 21),
                features=[(133, 25, "Battlegrounds · Arena & duels · Bounties · Macros")],
                tags=(151, 28, 20, [100, 160, 164]), author=(750, 173, 23),
                cta=(1160, 43, 390, 88, 43, 21), search=(170, 25)),
    "5x1": dict(height=320, logo=(6, 4, 338, 310), left=388, top=29,
                kicker=(71, 24), title=(147, 88), badge=(854, 104, 190, 39, 26),
                features=[(193, 32, "Battlegrounds · Arena & duels · Bounties · Macros")],
                tags=(228, 38, 26, [122, 190, 198]), author=(388, 292, 26),
                cta=(1180, 105, 370, 107, 42, 23), search=(260, 29)),
    "4x1": dict(height=400, logo=(6, 0, 420, 385), left=464, top=32,
                kicker=(74, 24), title=(153, 86), badge=(907, 110, 184, 40, 26),
                features=[(210, 32, "Battlegrounds · Arena & duels · Bounties · Macros")],
                tags=(249, 41, 27, [122, 190, 198]), author=(464, 342, 30),
                cta=(1160, 126, 392, 116, 43, 23), search=(291, 29)),
    "3x1": dict(height=1600/3, logo=(12, 10, 535, 490), left=600, top=43,
                kicker=(96, 27), title=(189, 104), badge=(1155, 148, 218, 45, 30),
                features=[(252, 38, "Battlegrounds · Arena & duels"),
                          (302, 38, "Bounties · Macros")],
                tags=(338, 43, 28, [128, 202, 210]), author=(600, 454, 31),
                cta=(1195, 394, 355, 83, 38, 19), search=(500, 26)),
}


def text(x, y, value, size, fill, weight=500, tracking=0, anchor="start"):
    return (f'<text x="{x}" y="{y}" font-size="{size}" fill="{fill}" '
            f'font-weight="{weight}" letter-spacing="{tracking}" '
            f'text-anchor="{anchor}">{escape(value)}</text>')


def svg_layout(fmt: Format, variant: str) -> tuple[Path, tuple]:
    original = core.SOURCE / "banner.svg"
    if fmt.key == "20x3":
        return original, (4, 3, 244, 224)
    layout = LAYOUTS[fmt.key]
    h = layout["height"]
    left, top = layout["left"], layout["top"]
    bottom = h - 14
    lx, ly, lw, lh = layout["logo"]
    plate_left = lx + lw/2
    # Reuse the exact gold/aura design from the existing native SVG.
    defs = re.search(r"<defs>(.*?)</defs>", original.read_text(), re.S).group(1)
    outline = f'M{plate_left} {top}H1566L1592 {top+26}V{bottom-26}L1566 {bottom}H{plate_left}Z'
    defs = re.sub(r'<clipPath id="plate">.*?</clipPath>',
                  f'<clipPath id="plate"><path d="{outline}"/></clipPath>', defs, flags=re.S)
    if variant == "horde":
        c = dict(bg="#15070a", muted="#d8c0bb", ink="#f1e0da", tag="#321315",
                 stroke="#83504b", tagink="#f6e5dc", badge="#531a1e", edge="#c97569",
                 pale="#ffd0be", badgeink="#ffdfcf", author="#cfb6b0", ctaink="#211613")
    else:
        c = dict(bg="#060d17", muted="#b9c7dc", ink="#d9e3f2", tag="#142438",
                 stroke="#4a647e", tagink="#e1ebfa", badge="#173756", edge="#6595bd",
                 pale="#a9d8ff", badgeink="#d7edff", author="#aebcd0", ctaink="#111923")
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
           f'width="1600" height="{h}" viewBox="0 0 1600 {h}">', f'<defs>{defs}</defs>',
           f'<ellipse cx="{lx+lw/2}" cy="{ly+lh/2}" rx="{lw*.56}" ry="{lh*.55}" fill="url(#aura)"/>',
           '<g clip-path="url(#plate)">',
           f'<path d="{outline}" fill="{c["bg"]}"/>',
           f'<image x="{plate_left}" y="{top}" width="{1592-plate_left}" height="{bottom-top}" '
           'xlink:href="backdrop.png" preserveAspectRatio="xMidYMid slice"/>',
           f'<path d="M{left-22} {top}H1592M{left-22} {bottom-2}H1565L1590 {bottom-26}" '
           'stroke="url(#rail)" stroke-width="3" fill="none"/>', '</g>',
           f'<path d="M{left-28} {top}H1566L1592 {top+26}V{bottom-26}L1566 {bottom}H{left-28}" '
           'fill="none" stroke="url(#edge)" stroke-width="1.5"/>',
           f'<path d="M{left-22} {top+20}V{bottom-17}" stroke="url(#divider)" stroke-width="2"/>',
           f'<path d="M{left} {top}H{left+76}M1566 {top}L1592 {top+26}" stroke="#fff1c5" stroke-width="3"/>',
           '<g font-family="Barlow Condensed">']
    ky, ksize = layout["kicker"]
    out.append(text(left, ky, "WORLD OF WARCRAFT", ksize, c["muted"], tracking=3))
    ty, tsize = layout["title"]
    out.append(text(left-2, ty, "HIGHGROUND", tsize, "#fff2cb", 700, 1))
    bx, by, bw, bh, bs = layout["badge"]
    out += [f'<path d="M{bx} {by}H{bx+bw-9}L{bx+bw} {by+9}V{by+bh}H{bx}Z" '
            f'fill="{c["badge"]}" stroke="{c["edge"]}" stroke-opacity=".65"/>',
            f'<path d="M{bx+11} {by+bh/2-6}l12 12m-12 0l12-12" '
            f'stroke="{c["pale"]}" stroke-width="2.2"/>',
            text(bx+35, by+bh/2+bs*.34, "PvP ADDON", bs, c["badgeink"], 700, .7)]
    for fy, fs, value in layout["features"]:
        out.append(text(left, fy, value, fs, c["ink"]))
    y, th, ts, widths = layout["tags"]
    x = left
    for label, width in zip(["RETAIL", "WoW FOREVER", "CATA CLASSIC"], widths):
        out.append(f'<rect x="{x}" y="{y}" width="{width}" height="{th}" rx="3" '
                   f'fill="{c["tag"]}" stroke="{c["stroke"]}"/>')
        out.append(text(x+width/2, y+th/2+ts*.34, label, ts, c["tagink"], 600, .8, "middle"))
        x += width+12
    ax, ay, az = layout["author"]
    out.append(f'<text x="{ax}" y="{ay}" font-size="{az}" fill="{c["author"]}" '
               'font-weight="500">made by <tspan fill="#f2d395" font-weight="600">kemicofa</tspan></text>')
    x, y, w, ch, cs, ks = layout["cta"]
    if fmt.key != "3x1":
        out.append(f'<path d="M{x-32} {top+20}V{bottom-17}" stroke="url(#divider)" stroke-width="2"/>')
    shape = f'M{x} {y}H{x+w-15}L{x+w} {y+15}V{y+ch}H{x}Z'
    out += [f'<path d="{shape}" transform="translate(0 4)" fill="#000" opacity=".4"/>',
            f'<path d="{shape}" fill="url(#gold)" stroke="#ffe7a2" stroke-width="1.2"/>',
            f'<path d="M{x+5} {y+5}H{x+w-18}L{x+w-5} {y+18}" fill="none" stroke="#fff8d6" stroke-opacity=".65"/>']
    ix, iy = x+30, y+ch*.57
    out.append(f'<path d="M{ix} {iy-16}v23m-11-10l11 11 11-11m-26 16v7h30v-7" '
               f'fill="none" stroke="{c["ctaink"]}" stroke-width="3.2"/>')
    out.append(text(x+66, y+ch*.32, "GET IT FREE", ks, "#352617", 700, 2.5))
    out.append(text(x+64, y+ch*.81, "CURSEFORGE", cs, c["ctaink"], 700, .8))
    sy, ss = layout["search"]
    out.append(f'<text x="{x+w/2}" y="{sy}" font-size="{ss}" text-anchor="middle" '
               f'fill="{c["ink"]}" font-weight="500">Search: '
               '<tspan fill="#ffdd92" font-weight="600">Highground</tspan></text>')
    out += ['</g>', '</svg>']
    path = core.SOURCE / f"banner-{fmt.key}.svg"
    path.write_text("\n".join(out)+"\n")
    return path, layout["logo"]


def filename(variant, fmt, width, height):
    return f"Highground-{variant.title()}-{fmt.key}-{width}x{height}"


def compose(fmt, variant, cache):
    width, height = fmt.sizes[-1]
    svg, logo = svg_layout(fmt, variant)
    plate = cache / f"{fmt.key}-plate.png"
    core.plate(svg, plate, width, height)
    scale = width/1600
    x, y, w, h = [round(value*scale) for value in logo]
    animation = core.SOURCE / "crest-spin-hd.webm"
    if not animation.exists():
        animation = core.SOURCE / "crest-spin.webm"
    master = cache / f"{fmt.key}.mkv"
    core.ffmpeg(
        "-loop", "1", "-framerate", "25", "-i", str(plate),
        "-c:v", "libvpx-vp9", "-i", str(animation), "-filter_complex",
        f"[0:v]format=rgba[bg];[1:v]scale={w}:{h}:flags=lanczos,format=rgba[crest];"
        f"[bg][crest]overlay={x}:{y}:format=auto:shortest=1,format=rgba[out]",
        "-map", "[out]", "-frames:v", "150", "-c:v", "ffv1", "-level", "3",
        "-pix_fmt", "bgra", "-an", str(master),
    )
    return master


def export_size(fmt, variant, master, width, height, cache, gifsicle):
    folder = core.ASSETS / "formats" / fmt.key
    folder.mkdir(parents=True, exist_ok=True)
    stem = filename(variant, fmt, width, height)
    out = folder / stem
    scale = f"scale={width}:{height}:flags=lanczos"
    core.ffmpeg("-i", str(master), "-vf", scale, "-frames:v", "1", "-update", "1", str(out.with_suffix(".png")))
    core.ffmpeg("-i", str(master), "-vf", scale+",format=yuva420p",
                "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "16", "-deadline", "good",
                "-cpu-used", "4", "-auto-alt-ref", "0", "-row-mt", "1", "-an", str(out.with_suffix(".webm")))
    raw = cache / f"{stem}-raw.gif"
    core.ffmpeg("-i", str(master), "-filter_complex",
                f"[0:v]{scale},split[video][stats];"
                "[stats]palettegen=max_colors=256:reserve_transparent=1:stats_mode=diff[palette];"
                "[video][palette]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle:alpha_threshold=96[out]",
                "-map", "[out]", "-loop", "0", "-final_delay", "4", "-an", str(raw))
    if gifsicle:
        core.run(gifsicle, "--no-warnings", "-O3", str(raw), "-o", str(out.with_suffix(".gif")))
    else:
        core.run("magick", str(raw), "-coalesce", "-layers", "Optimize", str(out.with_suffix(".gif")))
    raw.unlink()
    print(f"  {variant}: {fmt.key} {width}x{height} PNG / GIF / WebM", flush=True)
    return {"ratio":fmt.key.replace("x",":"), "width":width, "height":height,
            "files":{ext:str(out.with_suffix('.'+ext).relative_to(core.ASSETS)) for ext in ["png","gif","webm"]}}


def guide(variant):
    rows = []
    y = 135
    for key in ["8x1", "20x3", "5x1", "4x1", "3x1"]:
        fmt = next(f for f in FORMATS if f.key == key)
        w, h = fmt.sizes[-1]
        path = core.ASSETS / "formats" / key / (filename(variant, fmt, w, h)+".png")
        data = base64.b64encode(path.read_bytes()).decode()
        sizes = "   /   ".join(f"{a} x {b}" for a,b in fmt.sizes)
        rows.append(text(50,y,fmt.key.replace("x",":")+"  "+fmt.label,25,"#ffe4a5",700))
        rows.append(text(1350,y,sizes,21,"#bac1cd",500,anchor="end"))
        rows.append(f'<image x="50" y="{y+22}" width="1300" height="{1300*h/w}" href="data:image/png;base64,{data}"/>')
        y += 1300*h/w+104
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1400" height="{round(y+20)}">'
           f'<rect width="1400" height="100%" fill="#14151b"/><g font-family="sans-serif">'
           +text(50,58,f"HIGHGROUND / {variant.upper()} BANNER FORMATS",32,"#fff2d2",700)
           +text(50,94,"5 aspect ratios · 3 sizes each · PNG + GIF + transparent WebM",22,"#a4acb9")
           +"".join(rows)+"</g></svg>")
    output = core.ASSETS / "formats/Format-Guide.png"
    subprocess.run(["rsvg-convert","--output",str(output)],input=svg.encode(),check=True)


def docs_and_package(variant, manifest):
    files = [f"HIGHGROUND / {variant.upper()} — BANNER SIZE PACK", "",
             "15 sizes: five aspect ratios, three resolutions each.",
             "Each size includes PNG, GIF and transparent WebM (45 banner files).", "",
             "For the original slim 1080p overlay: 20x3, 960x144.",
             "For the thinnest bottom strip: 8x1, 960x120.",
             "The 5:1 exports start at the requested 1400x280.",
             "WebM: add as an OBS Media Source and enable Loop. Keep aspect ratio locked.",
             "All animations: 6 seconds, 25 fps, 150 frames, no audio.",
             "PNG is static; GIF loops automatically. WebM preserves smooth transparency.", ""]
    for fmt in FORMATS:
        files += [fmt.key.replace("x",":")+" — "+fmt.purpose,
                  "  "+" / ".join(f"{w}x{h}" for w,h in fmt.sizes)]
    files += ["", "Open Format-Guide.png to compare the layouts.",
              "Download Highground: https://www.curseforge.com/wow/addons/highground", "Made by kemicofa."]
    (core.ASSETS / "formats/FORMATS.txt").write_text("\n".join(files)+"\n")
    data = {"variant":variant,"aspect_ratios":5,"sizes_per_ratio":3,"export_count":45,"exports":manifest}
    (core.ASSETS / "formats/manifest.json").write_text(json.dumps(data,indent=2)+"\n")
    target = core.ASSETS / f"{core.NAME}-Pack.zip"
    with zipfile.ZipFile(target,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        prefix=f"Highground-{variant.title()}-Banners"
        for file in sorted((core.ASSETS/"formats").rglob("*")):
            if file.is_file():
                name=f"{prefix}/{file.relative_to(core.ASSETS/'formats')}"
                if file.name == "manifest.json":
                    portable=json.loads(file.read_text())
                    for entry in portable["exports"]:
                        entry["files"]={ext:str(Path(path).relative_to("formats"))
                                        for ext,path in entry["files"].items()}
                    archive.writestr(name,json.dumps(portable,indent=2)+"\n")
                else:
                    archive.write(file,name)
        recommended = filename(variant, FORMATS[0], 960, 144) + ".webm"
        setup = (f"HIGHGROUND / {variant.upper()} — QUICK START\n\n"
                 f"Recommended 1080p overlay: 20x3/{recommended}\n"
                 "In OBS, add a Media Source above the gameplay source.\n"
                 "Select the WebM as a Local File and enable Loop.\n"
                 "Leave hardware decoding off for smooth transparency.\n"
                 "Use 960 x 144 with aspect ratio locked, opposite the webcam.\n"
                 "Bottom-right position on a 1920 x 1080 scene: X=936, Y=912.\n\n"
                 "Format-Guide.png compares the five layouts. FORMATS.txt lists every size.\n"
                 "The 5x1 folder includes the requested 1400x280 version and two larger sizes.\n"
                 "All 15 sizes include a static PNG, looping GIF, and transparent WebM.\n"
                 "The animations run for six seconds at 25 fps with no audio.\n\n"
                 "https://www.curseforge.com/wow/addons/highground\nMade by kemicofa.\n")
        archive.writestr(f"{prefix}/START-HERE.txt", setup)
        archive.write(core.ASSETS/"previews/Placement-1080p.png",f"{prefix}/Placement-1080p.png")
    print(f"Pack: {target} ({target.stat().st_size/1e6:.1f} MB)",flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant", choices=["alliance","horde","both"],default="both")
    parser.add_argument("--gifsicle",default=shutil.which("gifsicle"))
    parser.add_argument("--stills-only",action="store_true",help="Render layout proofs only")
    args=parser.parse_args()
    variants=["horde","alliance"] if args.variant=="both" else [args.variant]
    for variant in variants:
        core.configure(variant)
        manifest=[]
        with tempfile.TemporaryDirectory(prefix=f"highground-{variant}-formats-") as tmp:
            cache=Path(tmp)
            for fmt in FORMATS:
                if args.stills_only:
                    svg,logo=svg_layout(fmt,variant)
                    w,h=fmt.sizes[-1]
                    core.plate(svg,cache/'plate.png',w,h)
                    x,y,lw,lh=[round(v*w/1600) for v in logo]
                    out=core.ASSETS/'formats'/fmt.key/(filename(variant,fmt,w,h)+'.png')
                    out.parent.mkdir(parents=True,exist_ok=True)
                    core.ffmpeg('-i',str(cache/'plate.png'),'-c:v','libvpx-vp9','-i',str(core.SOURCE/'crest-spin.webm'),
                                '-filter_complex',f'[0:v]format=rgba[bg];[1:v]scale={lw}:{lh}:flags=lanczos,format=rgba[c];'
                                f'[bg][c]overlay={x}:{y}:format=auto,format=rgba[out]',
                                '-map','[out]','-frames:v','1','-update','1',str(out))
                else:
                    master=compose(fmt,variant,cache)
                    for w,h in fmt.sizes:
                        manifest.append(export_size(fmt,variant,master,w,h,cache,args.gifsicle))
                    master.unlink()
        guide(variant)
        if not args.stills_only:
            docs_and_package(variant,manifest)


if __name__ == "__main__":
    main()
