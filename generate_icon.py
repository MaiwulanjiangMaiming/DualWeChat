#!/usr/bin/env python3
"""DualWeChat icon generator.

Recolors the official WeChat icon into one of ten themes while keeping the
original bubble silhouette. The result can be written as an .icns bundle icon
or as a plain .png preview.

Usage:
    python3 generate_icon.py <target.icns|target.png> [scheme]
    python3 generate_icon.py --list
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter

SCHEMES = {
    "metal": {
        "name": "Metal / 金属",
        "base": (5, 6, 9),
        "mid": (24, 25, 30),
        "glow": ((130, 145, 170), (70, 80, 100)),
        "glow_strength": (0.16, 0.10),
        "primary": (196, 201, 210),
        "accent": (250, 252, 255),
    },
    "aurora": {
        "name": "Aurora / 极光",
        "base": (7, 11, 22),
        "mid": (13, 30, 52),
        "glow": ((0, 229, 255), (123, 143, 255)),
        "glow_strength": (0.30, 0.30),
        "primary": (0, 229, 255),
        "accent": (150, 166, 255),
    },
    "neon": {
        "name": "Neon / 霓虹",
        "base": (14, 0, 20),
        "mid": (32, 5, 48),
        "glow": ((191, 0, 255), (255, 45, 120)),
        "glow_strength": (0.26, 0.24),
        "primary": (198, 60, 255),
        "accent": (255, 90, 150),
    },
    "lava": {
        "name": "Lava / 熔岩",
        "base": (9, 5, 2),
        "mid": (23, 9, 3),
        "glow": ((255, 106, 0), (255, 210, 0)),
        "glow_strength": (0.15, 0.09),
        "primary": (255, 118, 20),
        "accent": (255, 212, 90),
    },
    "matrix": {
        "name": "Matrix / 矩阵",
        "base": (0, 10, 6),
        "mid": (0, 26, 17),
        "glow": ((0, 255, 136), (0, 184, 76)),
        "glow_strength": (0.24, 0.18),
        "primary": (40, 255, 150),
        "accent": (180, 255, 220),
    },
    "sakura": {
        "name": "Sakura / 樱花",
        "base": (24, 10, 20),
        "mid": (48, 16, 36),
        "glow": ((255, 130, 180), (255, 210, 220)),
        "glow_strength": (0.18, 0.10),
        "primary": (255, 120, 180),
        "accent": (255, 200, 225),
    },
    "ocean": {
        "name": "Ocean / 深海",
        "base": (2, 16, 24),
        "mid": (4, 40, 50),
        "glow": ((0, 210, 190), (0, 120, 200)),
        "glow_strength": (0.18, 0.18),
        "primary": (30, 220, 200),
        "accent": (110, 190, 255),
    },
    "sunset": {
        "name": "Sunset / 落日",
        "base": (24, 8, 16),
        "mid": (52, 16, 24),
        "glow": ((255, 95, 90), (255, 180, 70)),
        "glow_strength": (0.20, 0.14),
        "primary": (255, 110, 95),
        "accent": (255, 195, 120),
    },
    "grape": {
        "name": "Grape / 葡萄",
        "base": (16, 8, 28),
        "mid": (36, 14, 56),
        "glow": ((160, 90, 255), (255, 120, 220)),
        "glow_strength": (0.20, 0.12),
        "primary": (175, 115, 255),
        "accent": (225, 180, 255),
    },
    "crimson": {
        "name": "Crimson / 绯红",
        "base": (22, 4, 8),
        "mid": (48, 8, 14),
        "glow": ((255, 50, 70), (255, 120, 90)),
        "glow_strength": (0.18, 0.10),
        "primary": (255, 70, 85),
        "accent": (255, 150, 140),
    },
}

SCHEME_LIST = list(SCHEMES)
DEFAULT_SOURCE = "/Applications/WeChat.app/Contents/Resources/AppIcon.icns"
ICON_SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]


def _smoothstep(t):
    return t * t * (3.0 - 2.0 * t)


def load_source_icon(path=DEFAULT_SOURCE, size=1024):
    """Load any .icns/.png icon and return a square RGBA image."""
    if not os.path.exists(path):
        raise FileNotFoundError(path)

    if path.lower().endswith(".icns"):
        tmp_dir = tempfile.mkdtemp(prefix="dualwechat_src_")
        try:
            png_path = os.path.join(tmp_dir, "source.png")
            proc = subprocess.run(
                ["sips", "-s", "format", "png", path, "--out", png_path,
                 "--resampleWidth", str(size)],
                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
            )
            if proc.returncode != 0 or not os.path.exists(png_path):
                raise RuntimeError(
                    f"sips failed to read {path}: {proc.stderr.strip()}"
                )
            image = Image.open(png_path)
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)
    else:
        image = Image.open(path)

    image = image.convert("RGBA")
    if image.width != image.height:
        side = max(image.width, image.height)
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.alpha_composite(
            image, ((side - image.width) // 2, (side - image.height) // 2)
        )
        image = canvas
    if image.width != size:
        image = image.resize((size, size), Image.LANCZOS)
    return image


def render_icon(source, scheme_key="metal", size=1024):
    """Recolor `source` with the given scheme and return a 1024px RGBA image."""
    scheme = SCHEMES[scheme_key]
    image = source.convert("RGBA")
    if image.width != image.height:
        side = max(image.width, image.height)
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.alpha_composite(
            image, ((side - image.width) // 2, (side - image.height) // 2)
        )
        image = canvas
    if image.width != size:
        image = image.resize((size, size), Image.LANCZOS)

    arr = np.asarray(image, dtype=np.float32)
    r, g, b, alpha = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    gray = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

    height, width = gray.shape
    yy, xx = np.mgrid[0:height, 0:width].astype(np.float32)
    xn, yn = xx / (width - 1), yy / (height - 1)

    base = np.array(scheme["base"], dtype=np.float32)
    mid = np.array(scheme["mid"], dtype=np.float32)
    primary = np.array(scheme["primary"], dtype=np.float32)
    accent = np.array(scheme["accent"], dtype=np.float32)
    glow_a = np.array(scheme["glow"][0], dtype=np.float32)
    glow_b = np.array(scheme["glow"][1], dtype=np.float32)

    # Tile background: vertical base -> mid ramp with two soft light sources.
    ramp = _smoothstep(np.clip(yn * 1.08, 0.0, 1.0))
    background = base + (mid - base) * ramp[..., None]
    for cx, cy, color, strength, sigma in (
        (0.18, 0.10, glow_a, scheme["glow_strength"][0], 0.42),
        (0.86, 0.88, glow_b, scheme["glow_strength"][1], 0.46),
    ):
        dist = ((xn - cx) ** 2 + (yn - cy) ** 2) / (2.0 * sigma * sigma)
        background += color * (strength * np.exp(-dist))[..., None]

    # Bubbles: diagonal primary -> accent gradient plus a soft specular sheen.
    blend = np.clip(0.55 * yn + 0.45 * xn, 0.0, 1.0) ** 1.15
    bubbles = primary + (accent - primary) * blend[..., None]
    sheen = np.exp(
        -(((xn - 0.42) ** 2 + (yn - 0.30) ** 2) / (2.0 * 0.20 ** 2))
    )
    bubbles = bubbles + 255.0 * 0.14 * sheen[..., None]

    hi = gray > 0.70
    md = (gray > 0.40) & (~hi)
    out = np.where(hi[..., None], bubbles,
                   np.where(md[..., None], background, background * 0.32))

    # A thin inner rim keeps the tile edge readable on dark wallpapers.
    alpha_mask = Image.fromarray(((alpha > 10) * 255).astype(np.uint8))
    inner = np.asarray(alpha_mask.filter(ImageFilter.MinFilter(7)),
                       dtype=np.float32)
    rim = np.clip(np.asarray(alpha_mask, dtype=np.float32) - inner, 0, 255) / 255.0
    rim_color = primary * 0.55 + 255.0 * 0.10
    out = out + rim[..., None] * rim_color * 0.45

    # Very light grain avoids visible banding in the gradient.
    noise = np.random.default_rng(11).normal(0.0, 1.2, (height, width, 1))
    out = np.clip(out + noise, 0, 255)
    out = np.concatenate([out, alpha[..., None]], axis=2)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def write_icns(image, dst_path):
    """Write an .icns using the standard macOS iconset pipeline."""
    tmp_dir = tempfile.mkdtemp(prefix="dualwechat_icns_")
    try:
        iconset = os.path.join(tmp_dir, "AppIcon.iconset")
        os.makedirs(iconset, exist_ok=True)
        for name, size in ICON_SIZES:
            image.resize((size, size), Image.LANCZOS).save(
                os.path.join(iconset, name)
            )
        tmp_icns = os.path.join(tmp_dir, "AppIcon.icns")
        proc = subprocess.run(
            ["iconutil", "-c", "icns", iconset, "-o", tmp_icns],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
        )
        if proc.returncode != 0 or not os.path.exists(tmp_icns):
            raise RuntimeError(f"iconutil failed: {proc.stderr.strip()}")
        os.makedirs(os.path.dirname(os.path.abspath(dst_path)), exist_ok=True)
        shutil.copyfile(tmp_icns, dst_path)
    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


def generate_icon(src_icns_path, dst_path, scheme_key="metal"):
    """Backward-compatible helper: read a source icon and write `dst_path`."""
    if scheme_key not in SCHEMES:
        raise ValueError(f"unknown scheme: {scheme_key}")
    source = load_source_icon(src_icns_path)
    result = render_icon(source, scheme_key)
    if dst_path.lower().endswith(".png"):
        os.makedirs(os.path.dirname(os.path.abspath(dst_path)), exist_ok=True)
        result.save(dst_path)
    else:
        write_icns(result, dst_path)
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="generate_icon.py",
        description="Generate a themed DualWeChat icon from the official WeChat icon.",
    )
    parser.add_argument("target", nargs="?",
                        help="output path (.icns or .png)")
    parser.add_argument("scheme", nargs="?", default="metal",
                        choices=SCHEME_LIST, help="color scheme (default: metal)")
    parser.add_argument("--source", default=DEFAULT_SOURCE,
                        help=f"source icon (default: {DEFAULT_SOURCE})")
    parser.add_argument("--list", action="store_true",
                        help="list available schemes and exit")
    args = parser.parse_args(argv)

    if args.list:
        for key in SCHEME_LIST:
            print(f"{key:8s} {SCHEMES[key]['name']}")
        return 0

    if not args.target:
        parser.print_help()
        return 2

    try:
        generate_icon(args.source, args.target, args.scheme)
    except FileNotFoundError:
        print(f"error: source icon not found: {args.source}", file=sys.stderr)
        return 1
    except (RuntimeError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"icon [{SCHEMES[args.scheme]['name']}] -> {args.target}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
