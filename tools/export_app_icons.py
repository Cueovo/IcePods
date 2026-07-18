from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets" / "app_icon" / "app_icon_1024.png"
IOS_BG = (222, 208, 255)
CANVAS = 1024


def fit_square(img: Image.Image, size: int = CANVAS) -> Image.Image:
    """Scale image to fit inside size x size without distortion, centered."""
    img = img.convert("RGBA")
    w, h = img.size
    if w == size and h == size:
        return img

    scale = min(size / w, size / h)
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    resized = img.resize((nw, nh), Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(resized, ((size - nw) // 2, (size - nh) // 2), resized)
    return canvas


def load_master() -> Image.Image:
    img = Image.open(MASTER)
    print(f"source raw: {img.size} mode={img.mode}")
    return fit_square(img, CANVAS)


def flatten(img: Image.Image, bg: tuple[int, int, int]) -> Image.Image:
    if img.mode != "RGBA":
        return img.convert("RGB")
    flat = Image.new("RGB", img.size, bg)
    flat.paste(img, mask=img.split()[-1])
    return flat


def save(
    img: Image.Image,
    path: Path,
    size: int,
    *,
    background: tuple[int, int, int] | None = None,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    out = img.resize((size, size), Image.Resampling.LANCZOS)
    if background is not None:
        out = flatten(out, background)
    out.save(path, "PNG", optimize=True)
    print(f"wrote {path.relative_to(ROOT)} ({size}x{size})")


def main() -> None:
    master = load_master()
    print(f"master square: {master.size}")

    # Overwrite master asset as true square so future exports stay correct
    master.save(MASTER, "PNG", optimize=True)
    print(f"normalized {MASTER.relative_to(ROOT)} -> {CANVAS}x{CANVAS}")

    web = ROOT / "web" / "icons"
    save(master, web / "Icon-192.png", 192)
    save(master, web / "Icon-512.png", 512)

    padded = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    scaled = master.resize((int(CANVAS * 0.80), int(CANVAS * 0.80)), Image.Resampling.LANCZOS)
    off = (CANVAS - scaled.size[0]) // 2
    padded.paste(scaled, (off, off), scaled)
    save(padded, web / "Icon-maskable-192.png", 192)
    save(padded, web / "Icon-maskable-512.png", 512)
    save(master, ROOT / "web" / "favicon.png", 32)

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
        save(master, ios / name, s, background=IOS_BG)

    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, s in android_sizes.items():
        save(
            master,
            ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png",
            s,
        )

    print("done")


if __name__ == "__main__":
    main()
