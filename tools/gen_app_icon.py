from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(r"e:\Code\qqmusic-ipod")
SIZE = 1024
BG = (14, 16, 22)


def clamp(v, lo=0.0, hi=255.0):
    return int(max(lo, min(hi, v)))


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(clamp(lerp(a, b, t)) for a, b in zip(c1, c2))


def radial(size, center, colors, radius=None):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx, cy = center
    r = radius if radius is not None else size * 0.75
    stops = sorted(colors, key=lambda x: x[0])
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx, y - cy) / r
            if d >= 1.0:
                c = stops[-1][1]
            else:
                c = stops[-1][1]
                for i in range(len(stops) - 1):
                    s0, c0 = stops[i]
                    s1, c1 = stops[i + 1]
                    if s0 <= d <= s1:
                        t = 0 if s1 == s0 else (d - s0) / (s1 - s0)
                        c = mix(c0, c1, t)
                        break
                else:
                    if d < stops[0][0]:
                        c = stops[0][1]
            px[x, y] = c
    return img


def linear_v(w, h, top, bottom):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        c = mix(top, bottom, t)
        for x in range(w):
            px[x, y] = c
    return img


def create_icon(size: int = SIZE) -> Image.Image:
    # Deep ambient gradient background
    bg = radial(
        size,
        (size * 0.35, size * 0.28),
        [
            (0.0, (48, 56, 78, 255)),
            (0.35, (28, 34, 52, 255)),
            (0.7, (16, 18, 28, 255)),
            (1.0, (8, 9, 14, 255)),
        ],
        radius=size * 1.05,
    )

    # Soft colored glow (music / ambient accent)
    glow = radial(
        size,
        (size * 0.55, size * 0.58),
        [
            (0.0, (90, 140, 255, 70)),
            (0.35, (120, 90, 220, 40)),
            (0.7, (40, 60, 120, 12)),
            (1.0, (0, 0, 0, 0)),
        ],
        radius=size * 0.55,
    )
    bg = Image.alpha_composite(bg, glow)

    glow2 = radial(
        size,
        (size * 0.32, size * 0.42),
        [
            (0.0, (70, 200, 220, 45)),
            (0.5, (50, 120, 180, 15)),
            (1.0, (0, 0, 0, 0)),
        ],
        radius=size * 0.4,
    )
    bg = Image.alpha_composite(bg, glow2)

    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # --- Center disc / vinyl-inspired circle ---
    cx, cy = size // 2, int(size * 0.48)
    outer = int(size * 0.28)

    # Disc shadow
    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse(
        (cx - outer + 6, cy - outer + 14, cx + outer + 6, cy + outer + 14),
        fill=(0, 0, 0, 100),
    )
    sh = sh.filter(ImageFilter.GaussianBlur(18))
    bg = Image.alpha_composite(bg, sh)

    # Glass disc
    disc = radial(
        size,
        (cx - outer * 0.25, cy - outer * 0.3),
        [
            (0.0, (255, 255, 255, 55)),
            (0.4, (200, 210, 230, 38)),
            (0.75, (140, 155, 185, 28)),
            (1.0, (100, 115, 145, 22)),
        ],
        radius=outer * 1.1,
    )
    disc_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(disc_mask).ellipse(
        (cx - outer, cy - outer, cx + outer, cy + outer), fill=255
    )
    layer.paste(disc, (0, 0), disc_mask)

    d = ImageDraw.Draw(layer)
    d.ellipse(
        (cx - outer, cy - outer, cx + outer, cy + outer),
        outline=(255, 255, 255, 70),
        width=max(2, size // 280),
    )

    # Inner ring
    mid = int(outer * 0.62)
    d.ellipse(
        (cx - mid, cy - mid, cx + mid, cy + mid),
        outline=(255, 255, 255, 40),
        width=max(1, size // 400),
    )

    # --- Stylized music note (clean, bold) ---
    note = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    nd = ImageDraw.Draw(note)

    # Note color: soft white with cool tint
    fill = (245, 248, 255, 245)
    fill_soft = (200, 220, 255, 230)

    # Scale relative to disc
    s = outer * 0.011  # unit scale

    # Stem positions for double eighth note (modern music mark)
    # Classic clean: single eighth note is clearer at small sizes
    # Head (oval tilted)
    head_w = int(outer * 0.42)
    head_h = int(outer * 0.30)
    head_cx = cx - int(outer * 0.12)
    head_cy = cy + int(outer * 0.18)

    # Draw tilted oval for note head via rotated ellipse
    head = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hd = ImageDraw.Draw(head)
    bbox = (
        head_cx - head_w // 2,
        head_cy - head_h // 2,
        head_cx + head_w // 2,
        head_cy + head_h // 2,
    )
    hd.ellipse(bbox, fill=fill)
    # slight rotate
    head_rot = head.rotate(22, resample=Image.Resampling.BICUBIC, center=(head_cx, head_cy))
    note = Image.alpha_composite(note, head_rot)
    nd = ImageDraw.Draw(note)

    # Stem
    stem_x = head_cx + head_w // 2 - max(2, int(outer * 0.04))
    stem_top = cy - int(outer * 0.38)
    stem_bot = head_cy - int(head_h * 0.1)
    stem_w = max(6, int(outer * 0.085))
    nd.rounded_rectangle(
        (stem_x - stem_w // 2, stem_top, stem_x + stem_w // 2, stem_bot),
        radius=stem_w // 2,
        fill=fill,
    )

    # Flag / beam (curved flag of eighth note)
    flag = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fd = ImageDraw.Draw(flag)
    # simple geometric flag: rounded path using polygon
    fx = stem_x + stem_w // 2
    fy = stem_top
    # flag shape points
    pts = [
        (fx - 2, fy),
        (fx + int(outer * 0.28), fy + int(outer * 0.05)),
        (fx + int(outer * 0.32), fy + int(outer * 0.28)),
        (fx + int(outer * 0.12), fy + int(outer * 0.38)),
        (fx + int(outer * 0.08), fy + int(outer * 0.22)),
        (fx - 2, fy + int(outer * 0.18)),
    ]
    fd.polygon(pts, fill=fill)
    # soften flag edge slightly
    flag = flag.filter(ImageFilter.GaussianBlur(0.6))
    note = Image.alpha_composite(note, flag)

    # Soft glow under note
    note_glow = note.filter(ImageFilter.GaussianBlur(radius=size * 0.02))
    # boost glow alpha
    r, g, b, a = note_glow.split()
    a = a.point(lambda v: min(255, int(v * 0.55)))
    note_glow = Image.merge("RGBA", (r, g, b, a))
    # tint glow blue
    glow_tint = Image.new("RGBA", (size, size), (120, 170, 255, 0))
    glow_tint.putalpha(a)
    bg = Image.alpha_composite(bg, glow_tint)
    bg = Image.alpha_composite(bg, note_glow)
    bg = Image.alpha_composite(bg, layer)
    bg = Image.alpha_composite(bg, note)

    # --- Sound wave arcs under / around ---
    waves = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    wd = ImageDraw.Draw(waves)
    wave_color = (180, 210, 255, 90)
    base_y = int(size * 0.78)
    # equalizer bars - clean modern music signal
    bars = 7
    bar_vals = [0.35, 0.55, 0.85, 1.0, 0.7, 0.48, 0.32]
    total_w = int(size * 0.38)
    bar_w = int(total_w / (bars * 1.7))
    gap = int(bar_w * 0.7)
    start_x = (size - (bars * bar_w + (bars - 1) * gap)) // 2
    max_h = int(size * 0.09)

    for i, v in enumerate(bar_vals):
        h = max(bar_w, int(max_h * v))
        x0 = start_x + i * (bar_w + gap)
        y0 = base_y - h
        y1 = base_y
        # gradient-ish solid with soft blue-white
        alpha = 140 + int(80 * v)
        col = (160 + int(40 * v), 190 + int(30 * v), 255, alpha)
        wd.rounded_rectangle(
            (x0, y0, x0 + bar_w, y1),
            radius=bar_w // 2,
            fill=col,
        )

    # soft blur bars slightly for premium look
    waves_soft = waves.filter(ImageFilter.GaussianBlur(0.8))
    bg = Image.alpha_composite(bg, waves_soft)
    bg = Image.alpha_composite(bg, waves)

    # Top ambient shine
    shine = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shine).ellipse(
        (-size * 0.15, -size * 0.6, size * 1.15, size * 0.45),
        fill=(255, 255, 255, 16),
    )
    bg = Image.alpha_composite(bg, shine)

    # Vignette
    vig = radial(
        size,
        (size * 0.5, size * 0.5),
        [
            (0.0, (0, 0, 0, 0)),
            (0.65, (0, 0, 0, 0)),
            (1.0, (0, 0, 0, 70)),
        ],
        radius=size * 0.72,
    )
    bg = Image.alpha_composite(bg, vig)

    return bg.convert("RGBA")


def resize_cover(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.Resampling.LANCZOS)


def save_png(img: Image.Image, path: Path, size: int | None = None):
    path.parent.mkdir(parents=True, exist_ok=True)
    out = resize_cover(img, size) if size else img
    if out.mode == "RGBA":
        flat = Image.new("RGB", out.size, BG)
        flat.paste(out, mask=out.split()[-1])
        flat.save(path, "PNG", optimize=True)
    else:
        out.save(path, "PNG", optimize=True)
    print(f"wrote {path} ({path.stat().st_size} bytes)")


def main():
    master = create_icon(SIZE)
    assets = ROOT / "assets" / "app_icon"
    assets.mkdir(parents=True, exist_ok=True)
    save_png(master, assets / "app_icon_1024.png")

    web_icons = ROOT / "web" / "icons"
    save_png(master, web_icons / "Icon-192.png", 192)
    save_png(master, web_icons / "Icon-512.png", 512)

    def maskable() -> Image.Image:
        padded = Image.new("RGBA", (SIZE, SIZE), (*BG, 255))
        scaled = master.resize((int(SIZE * 0.80), int(SIZE * 0.80)), Image.Resampling.LANCZOS)
        off = (SIZE - scaled.size[0]) // 2
        padded.paste(scaled, (off, off), scaled if scaled.mode == "RGBA" else None)
        return padded

    m = maskable()
    save_png(m, web_icons / "Icon-maskable-192.png", 192)
    save_png(m, web_icons / "Icon-maskable-512.png", 512)
    save_png(master, ROOT / "web" / "favicon.png", 32)

    ios = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, s in ios_sizes.items():
        save_png(master, ios / name, s)

    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, s in android_sizes.items():
        save_png(
            master,
            ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png",
            s,
        )

    print("done")


if __name__ == "__main__":
    main()
