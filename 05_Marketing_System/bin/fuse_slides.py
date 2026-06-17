#!/usr/bin/env python3
"""fuse_slides.py — stage 3 of the render pipeline. Fuse the generated base
photos (assets/) with the Remotion UI screenshots (ui/) per the render manifest,
and burn the caption pill. Non-destructive: reads assets/ + ui/, writes composed/.

Two fuse modes (declared per slide in render_manifest.json):
  screen-overlay : detect the flat #FF00FF phone screen in the base photo,
                   perspective-warp the UI screenshot onto it, then caption.
  photo-caption  : base photo + caption pill only.

Usage: fuse_slides.py --run-dir <abs run dir>
Exit: 0 success · 2 usage/missing input · 1 a slide failed
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1920
PINK = (255, 0, 255)

FONT_CANDIDATES_BOLD = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/Library/Fonts/Arial Bold.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]


def load_font(size):
    for p in FONT_CANDIDATES_BOLD:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


def prepare_base(path):
    img = Image.open(path).convert("RGBA")
    if img.size != (W, H):
        # cover-fit to 1080x1920 without distortion
        sw, sh = img.size
        scale = max(W / sw, H / sh)
        img = img.resize((int(sw * scale), int(sh * scale)), Image.Resampling.LANCZOS)
        left = (img.width - W) // 2
        top = (img.height - H) // 2
        img = img.crop((left, top, left + W, top + H))
    return img


def find_pink_quad(img):
    """Return [TL,TR,BR,BL] of the flat magenta screen region, or None."""
    arr = np.array(img.convert("RGB"))
    r, g, b = arr[:, :, 0].astype(int), arr[:, :, 1].astype(int), arr[:, :, 2].astype(int)
    mask = (r > 200) & (g < 80) & (b > 200)
    ys, xs = np.where(mask)
    if len(xs) < 500:  # not enough pink to be a screen
        return None
    pts = np.column_stack([xs, ys])
    s = pts[:, 0] + pts[:, 1]
    d = pts[:, 0] - pts[:, 1]
    tl = pts[np.argmin(s)]
    br = pts[np.argmax(s)]
    tr = pts[np.argmax(d)]
    bl = pts[np.argmin(d)]
    return [tuple(tl), tuple(tr), tuple(br), tuple(bl)]


def perspective_coeffs(src, dst):
    # coeffs to pass to Image.transform(PERSPECTIVE): maps OUTPUT(dst)->INPUT(src)
    matrix = []
    for (x, y), (u, v) in zip(dst, src):
        matrix.append([x, y, 1, 0, 0, 0, -x * u, -y * u])
        matrix.append([0, 0, 0, x, y, 1, -x * v, -y * v])
    A = np.array(matrix, dtype=float)
    B = np.array([c for p in src for c in p], dtype=float)
    res = np.linalg.solve(A, B)
    return res.reshape(8)


def expand_quad(quad, factor=0.02):
    """Push each corner out from the centroid so the opaque UI overlaps the keyed
    edge — kills the magenta fringe left when the warp under-covers the screen."""
    cx = sum(p[0] for p in quad) / 4.0
    cy = sum(p[1] for p in quad) / 4.0
    return [(x + (x - cx) * factor, y + (y - cy) * factor) for (x, y) in quad]


def warp_ui_onto_quad(base, ui, quad):
    ui = ui.convert("RGBA")
    uw, uh = ui.size
    src = [(0, 0), (uw, 0), (uw, uh), (0, uh)]
    coeffs = perspective_coeffs(src, expand_quad(quad))
    warped = ui.transform((W, H), Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    out = Image.alpha_composite(base, warped)
    # belt-and-braces: paint over any magenta still peeking past the UI
    arr = np.array(out.convert("RGB"))
    r, g, b = arr[:, :, 0].astype(int), arr[:, :, 1].astype(int), arr[:, :, 2].astype(int)
    resid = (r > 200) & (g < 80) & (b > 200)
    if resid.any():
        arr[resid] = (18, 16, 14)  # neutral dark; real photos won't hit this path much
        out = Image.fromarray(arr, "RGB").convert("RGBA")
    return out


def draw_caption(img, text):
    if not text:
        return img
    draw = ImageDraw.Draw(img)
    font = load_font(46)
    max_w = int(W * 0.82)
    words, lines, cur = text.split(), [], []
    for word in words:
        cur.append(word)
        if draw.textlength(" ".join(cur), font=font) > max_w:
            cur.pop()
            lines.append(" ".join(cur))
            cur = [word]
    if cur:
        lines.append(" ".join(cur))
    lh = int(draw.textbbox((0, 0), "Ag", font=font)[3] * 1.4)
    total = lh * len(lines)
    y0 = int(H * 0.74) - total // 2
    padx, pady = 34, 16
    for i, line in enumerate(lines):
        lw = draw.textlength(line, font=font)
        lx = (W - lw) // 2
        ly = y0 + i * lh
        draw.rounded_rectangle(
            [lx - padx, ly - pady, lx + lw + padx, ly + lh - pady + 6],
            radius=22, fill=(0, 0, 0, 210),
        )
        draw.text((lx, ly), line, font=font, fill=(255, 255, 255, 255))
    return img


def contact_sheet(paths, out):
    cols, rows, tw, th = 3, 2, 360, 640
    sheet = Image.new("RGB", (cols * tw, rows * th), (245, 245, 245))
    for i, p in enumerate(paths):
        if not os.path.exists(p):
            continue
        thumb = Image.open(p).convert("RGB").resize((tw, th), Image.Resampling.LANCZOS)
        sheet.paste(thumb, ((i % cols) * tw, (i // cols) * th))
    sheet.save(out, "PNG")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-dir", required=True)
    args = ap.parse_args()

    run_dir = args.run_dir
    mpath = os.path.join(run_dir, "render_manifest.json")
    if not os.path.isfile(mpath):
        print(f"E2: no render_manifest.json in {run_dir}", file=sys.stderr)
        sys.exit(2)
    man = json.load(open(mpath))
    composed_dir = os.path.join(run_dir, man["dirs"]["composed"])
    os.makedirs(composed_dir, exist_ok=True)

    finals, failures = [], 0
    for s in man["slides"]:
        n = s["n"]
        base_path = os.path.join(run_dir, s["base"]["file"])
        out_path = os.path.join(run_dir, s["out"])
        if not os.path.isfile(base_path):
            print(f"  slide {n}: MISSING base photo {s['base']['file']} — skipped", file=sys.stderr)
            failures += 1
            finals.append(out_path)
            continue
        img = prepare_base(base_path)

        # Only the python-warp fallback composites the UI here. In model-fuse the
        # image model already painted the UI into the generated photo, so we just caption.
        if s["fuse_mode"] == "screen-overlay" and s.get("screen_mode") == "python-warp" and s.get("ui"):
            ui_path = os.path.join(run_dir, s["ui"]["file"])
            quad = find_pink_quad(img)
            if quad is None:
                print(f"  slide {n}: no #FF00FF screen found — caption-only fallback", file=sys.stderr)
            elif not os.path.isfile(ui_path):
                print(f"  slide {n}: UI screenshot {s['ui']['file']} missing — caption-only fallback", file=sys.stderr)
            else:
                img = warp_ui_onto_quad(img, Image.open(ui_path), quad)
                print(f"  slide {n}: [python-warp] warped {s['ui']['component']} onto screen quad")
        elif s["fuse_mode"] == "screen-overlay":
            print(f"  slide {n}: [model-fuse] UI already in photo — caption only")

        img = draw_caption(img, s.get("caption", ""))
        img.convert("RGB").save(out_path, "PNG")
        finals.append(out_path)
        print(f"  slide {n}: composed -> {s['out']}")

    sheet = os.path.join(composed_dir, "contact-sheet.png")
    contact_sheet(finals, sheet)
    print(f"fuse_slides.py: {len(finals) - failures}/{len(finals)} slides composed; contact sheet -> {sheet}")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
