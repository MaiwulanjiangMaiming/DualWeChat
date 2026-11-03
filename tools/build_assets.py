#!/usr/bin/env python3
"""Build the README / social preview artwork for DualWeChat.

The artwork is generated from the real WeChat icon with the same renderer that
produces the app icons, so the README always matches what users actually get.

Usage:
    python3 tools/build_assets.py
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from generate_icon import SCHEMES, SCHEME_LIST, load_source_icon, render_icon  # noqa: E402

ASSETS = os.path.join(ROOT, "assets")
SS = 2  # supersampling factor

SF = "/System/Library/Fonts/SFNS.ttf"
SF_MONO = "/System/Library/Fonts/SFNSMono.ttf"
CN = "/System/Library/Fonts/Hiragino Sans GB.ttc"

INK = (244, 247, 252)
MUTED = (154, 165, 184)
DIM = (98, 110, 132)
CYAN = (79, 227, 255)
VIOLET = (139, 157, 255)

THEME_LABELS = {
    "metal": ("Metal", "金属黑"),
    "aurora": ("Aurora", "冷蓝极光"),
    "neon": ("Neon", "紫粉霓虹"),
    "lava": ("Lava", "橙金熔岩"),
    "matrix": ("Matrix", "黑客矩阵"),
    "sakura": ("Sakura", "樱花粉"),
    "ocean": ("Ocean", "深海青"),
    "sunset": ("Sunset", "落日橘"),
    "grape": ("Grape", "葡萄紫"),
    "crimson": ("Crimson", "绯红"),
}


# --------------------------------------------------------------------------
# primitives


def S(value):
    return int(round(value * SS))


def latin(size, weight="Bold"):
    font = ImageFont.truetype(SF, S(size))
    font.set_variation_by_name(weight)
    return font


def mono(size):
    return ImageFont.truetype(SF_MONO, S(size))


def chinese(size, weight="W6"):
    return ImageFont.truetype(CN, S(size), index=2 if weight == "W6" else 0)


def vgradient(width, height, stops):
    """stops: [(position 0..1, (r,g,b)), ...]"""
    ys = np.linspace(0.0, 1.0, height, dtype=np.float32)
    positions = np.array([p for p, _ in stops], dtype=np.float32)
    colors = np.array([c for _, c in stops], dtype=np.float32)
    out = np.empty((height, 3), dtype=np.float32)
    for channel in range(3):
        out[:, channel] = np.interp(ys, positions, colors[:, channel])
    return np.repeat(out[:, None, :], width, axis=1)


def background(width, height, glows, grid=True, vignette=0.38):
    arr = vgradient(
        width,
        height,
        [(0.0, (4, 5, 9)), (0.48, (7, 10, 17)), (1.0, (3, 4, 8))],
    ).copy()

    yy, xx = np.mgrid[0:height, 0:width].astype(np.float32)
    xn, yn = xx / (width - 1), yy / (height - 1)
    for cx, cy, radius, color, strength in glows:
        dist = ((xn - cx) ** 2 + (yn - cy) ** 2) / (2 * radius ** 2)
        arr += np.array(color, dtype=np.float32) * (strength * np.exp(-dist))[:, :, None]

    if grid:
        overlay = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        draw = ImageDraw.Draw(overlay)
        step = S(80)
        for x in range(0, width, step):
            draw.line([(x, 0), (x, height)], fill=(255, 255, 255, 8))
        for y in range(0, height, step):
            draw.line([(0, y), (width, y)], fill=(255, 255, 255, 8))
        base = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
        base.alpha_composite(overlay)
        arr = np.asarray(base.convert("RGB"), dtype=np.float32).copy()

    # radial vignette
    dist = np.sqrt((xn - 0.5) ** 2 + (yn - 0.5) ** 2) / 0.7071
    arr *= np.clip(1.0 - vignette * dist ** 2.2, 0.25, 1.0)[:, :, None]

    rng = np.random.default_rng(5)
    arr += rng.normal(0, 1.2, (height, width, 1))
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def gradient_text(canvas, xy, text, font, top, bottom, anchor="lt"):
    mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(mask).text((S(xy[0]), S(xy[1])), text, font=font,
                              fill=255, anchor=anchor)
    if not mask.getbbox():
        raise RuntimeError(f"failed to render text: {text!r}")
    grad = vgradient(canvas.width, canvas.height,
                     [(0.0, top), (0.35, top), (1.0, bottom)])
    grad_img = Image.fromarray(grad.astype(np.uint8), "RGB").convert("RGBA")
    return Image.composite(grad_img, canvas, mask)


def text(draw, xy, value, font, fill, anchor="lt"):
    draw.text((S(xy[0]), S(xy[1])), value, font=font, fill=fill, anchor=anchor)


def text_width(draw, value, font):
    return draw.textlength(value, font=font) / SS


def pill(draw, x, y, value, font, fg=INK, fill=(255, 255, 255, 9),
         border=(255, 255, 255, 28), pad=18, height=40, dot=None,
         radius=None):
    width = text_width(draw, value, font) + pad * 2 + (14 if dot else 0)
    box = [S(x), S(y), S(x + width), S(y + height)]
    r = S(radius if radius is not None else height / 2)
    draw.rounded_rectangle(box, radius=r, fill=fill, outline=border, width=max(1, S(0.8)))
    tx = x + pad
    if dot:
        color = dot
        cy = y + height / 2
        draw.ellipse([S(tx), S(cy - 4), S(tx + 8), S(cy + 4)], fill=color)
        tx += 14
    text(draw, (tx, y + height / 2), value, font, fg, anchor="lm")
    return width


def card(canvas, box, radius=32, fill=(255, 255, 255, 6),
         border=(255, 255, 255, 20), shadow=0.35):
    x0, y0, x1, y1 = [S(v) for v in box]
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    if shadow:
        shadow_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow_layer).rounded_rectangle(
            [x0, y0 + S(18), x1, y1 + S(22)], radius=S(radius),
            fill=(0, 0, 0, int(255 * shadow)))
        shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(S(26)))
        canvas.alpha_composite(shadow_layer)
    draw.rounded_rectangle([x0, y0, x1, y1], radius=S(radius), fill=fill,
                           outline=border, width=max(1, S(0.8)))
    canvas.alpha_composite(layer)


def paste_icon(canvas, icon, center, size, glow=None, shadow=0.45, rotate=0):
    size_px = S(size)
    icon = icon.resize((size_px, size_px), Image.LANCZOS)
    if rotate:
        icon = icon.rotate(rotate, resample=Image.BICUBIC, expand=True)
    alpha = icon.getchannel("A")

    cx, cy = S(center[0]), S(center[1])
    x = cx - icon.width // 2
    y = cy - icon.height // 2

    if glow:
        color, strength, spread = glow
        pad = S(spread * 2)
        glow_layer = Image.new("RGBA", (icon.width + pad * 2, icon.height + pad * 2),
                               (0, 0, 0, 0))
        mask = Image.new("L", glow_layer.size, 0)
        mask.paste(alpha, (pad, pad))
        mask = mask.filter(ImageFilter.GaussianBlur(S(spread * 0.55)))
        tint = Image.new("RGBA", glow_layer.size, color + (0,))
        tint.putalpha(mask.point(lambda v: int(v * strength)))
        glow_layer.alpha_composite(tint)
        canvas.alpha_composite(glow_layer, (x - pad, y - pad))

    if shadow:
        pad = S(60)
        shadow_layer = Image.new("RGBA", (icon.width + pad * 2, icon.height + pad * 2),
                                 (0, 0, 0, 0))
        mask = Image.new("L", shadow_layer.size, 0)
        mask.paste(alpha, (pad, pad + S(14)))
        mask = mask.filter(ImageFilter.GaussianBlur(S(24)))
        black = Image.new("RGBA", shadow_layer.size, (0, 0, 0, 0))
        black.putalpha(mask.point(lambda v: int(v * shadow)))
        shadow_layer.alpha_composite(black)
        canvas.alpha_composite(shadow_layer, (x - pad, y - pad))

    canvas.alpha_composite(icon, (x, y))


def scheme_icon(source, key, size=1024):
    return render_icon(source, key, size=size)


# --------------------------------------------------------------------------
# artwork


def build_hero(source, lang="cn"):
    width, height = S(1600), S(800)
    canvas = background(
        width, height,
        glows=[
            (0.12, 0.02, 0.52, (0, 190, 255), 0.30),
            (0.92, 0.95, 0.55, (123, 110, 255), 0.30),
            (0.62, 0.12, 0.30, (0, 255, 210), 0.05),
        ],
    ).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    if lang == "cn":
        pill(draw, 96, 112, "macOS 微信双开 · 一键安装", chinese(19, "W3"),
             fg=(220, 236, 250), fill=(0, 229, 255, 12),
             border=(0, 229, 255, 55), dot=CYAN)
        canvas = gradient_text(canvas, (96, 186), "DualWeChat", latin(112, "Bold"),
                               (255, 255, 255), (176, 202, 246))
        draw = ImageDraw.Draw(canvas)
        canvas = gradient_text(canvas, (98, 338), "两个微信，同时在线。", chinese(46, "W6"),
                               (255, 255, 255), (168, 198, 255))
        draw = ImageDraw.Draw(canvas)
        text(draw, (98, 410), "复制一份微信，改写 Bundle ID，重新签名。", chinese(24, "W3"), MUTED)
        text(draw, (98, 449), "消息、通知、文件完全独立，与原版互不干扰。", chinese(24, "W3"), MUTED)
        chips = ["一键安装", f"{len(SCHEME_LIST)} 套主题", "自动跟随更新"]
        chip_font = chinese(19, "W3")
        x = 98
        for i, chip in enumerate(chips):
            w = pill(draw, x, 524, chip, chip_font,
                     fg=(206, 220, 238), fill=(255, 255, 255, 6),
                     border=(255, 255, 255, 22), pad=17, height=40,
                     dot=(0, 229, 255) if i == 0 else ((139, 157, 255) if i == 1 else (48, 209, 88)))
            x += w + 12
        text(draw, (98, 692), "macOS 12+   ·   Apple Silicon / Intel   ·   全程本地运行",
             chinese(18, "W3"), (104, 118, 142))
    else:
        pill(draw, 96, 112, "DUAL WECHAT FOR MACOS", latin(14, "Medium"),
             fg=(200, 226, 244), fill=(0, 229, 255, 12),
             border=(0, 229, 255, 55), dot=CYAN, pad=18, height=40)
        canvas = gradient_text(canvas, (96, 186), "DualWeChat", latin(112, "Bold"),
                               (255, 255, 255), (176, 202, 246))
        draw = ImageDraw.Draw(canvas)
        canvas = gradient_text(canvas, (98, 338), "Two WeChats. One Mac.", latin(52, "Bold"),
                               (255, 255, 255), (168, 198, 255))
        draw = ImageDraw.Draw(canvas)
        text(draw, (98, 420), "Duplicate the app, rewrite its bundle ID, re-sign it.", latin(23, "Regular"), MUTED)
        text(draw, (98, 458), "Messages, notifications and files stay fully separate.", latin(23, "Regular"), MUTED)
        chips = ["One-click setup", f"{len(SCHEME_LIST)} themes", "Update-aware"]
        chip_font = latin(16, "Medium")
        x = 98
        for i, chip in enumerate(chips):
            w = pill(draw, x, 524, chip, chip_font,
                     fg=(206, 220, 238), fill=(255, 255, 255, 6),
                     border=(255, 255, 255, 22), pad=17, height=38,
                     dot=(0, 229, 255) if i == 0 else ((139, 157, 255) if i == 1 else (48, 209, 88)))
            x += w + 12
        text(draw, (98, 690), "macOS 12+   ·   Apple Silicon / Intel   ·   100% local",
             latin(15, "Regular"), (104, 118, 142))

    # Right: glass card with the flagship icon and a 2x badge.
    card_box = (1010, 158, 1478, 626)
    card(canvas, card_box, radius=76, fill=(255, 255, 255, 7),
         border=(255, 255, 255, 26), shadow=0.45)
    draw = ImageDraw.Draw(canvas)
    icon = scheme_icon(source, "aurora", 1024)
    paste_icon(canvas, icon, (1244, 392), 372,
               glow=(CYAN, 0.34, 74), shadow=0.55)

    badge_w, badge_h = 104, 48
    bx, by = 1368, 532
    badge_fill = vgradient(S(badge_w), S(badge_h),
                           [(0.0, (79, 227, 255)), (1.0, (139, 157, 255))])
    badge_mask = Image.new("L", (S(badge_w), S(badge_h)), 0)
    ImageDraw.Draw(badge_mask).rounded_rectangle(
        [0, 0, S(badge_w), S(badge_h)], radius=S(24), fill=255)
    badge = Image.fromarray(badge_fill.astype(np.uint8), "RGB").convert("RGBA")
    badge.putalpha(badge_mask)
    canvas.alpha_composite(badge, (S(bx), S(by)))
    draw = ImageDraw.Draw(canvas)
    text(draw, (bx + badge_w / 2, by + badge_h / 2), "2×",
         latin(24, "Bold"), (8, 12, 20), anchor="mm")

    text(draw, (1244, 676), "WeChat  +  DualWeChat", mono(15), (118, 132, 158), anchor="mt")

    return canvas.convert("RGB")


def build_themes(source, lang="cn"):
    width, height = S(1600), S(1110)
    canvas = background(
        width, height,
        glows=[
            (0.16, 0.0, 0.40, (0, 200, 255), 0.16),
            (0.84, 0.95, 0.45, (130, 110, 255), 0.18),
        ],
    ).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    if lang == "cn":
        text(draw, (66, 58), "十套主题，换一种心情", chinese(42, "W6"), INK)
        text(draw, (68, 122), "安装时选择，之后随时运行  ./setup.sh  重新生成", chinese(19, "W3"), MUTED)
    else:
        text(draw, (66, 58), "Ten themes. Pick your vibe.", latin(42, "Bold"), INK)
        text(draw, (68, 122), "Choose during install, or regenerate anytime with  ./setup.sh", latin(18, "Regular"), MUTED)

    footer = "python3 generate_icon.py <target.icns> <scheme>"

    card_w, card_h, gap_x, gap_y = 276, 400, 22, 24
    columns = 5
    total = card_w * columns + gap_x * (columns - 1)
    start_x = (1600 - total) / 2
    top = 190

    for index, key in enumerate(SCHEME_LIST):
        scheme = SCHEMES[key]
        row, col = divmod(index, columns)
        x = start_x + col * (card_w + gap_x)
        y = top + row * (card_h + gap_y)

        card(canvas, (x, y, x + card_w, y + card_h), radius=34,
             fill=(255, 255, 255, 5), border=(255, 255, 255, 18), shadow=0.4)
        draw = ImageDraw.Draw(canvas)
        text(draw, (x + 24, y + 18), f"{index + 1:02d}", mono(15), (86, 98, 122))

        icon = scheme_icon(source, key, 1024)
        paste_icon(canvas, icon, (x + card_w / 2, y + 150), 164,
                   glow=(tuple(scheme["primary"]), 0.22, 34), shadow=0.4)
        draw = ImageDraw.Draw(canvas)

        en, cn = THEME_LABELS[key]
        if lang == "cn":
            text(draw, (x + card_w / 2, y + 258), cn, chinese(23, "W6"), INK, anchor="mt")
            text(draw, (x + card_w / 2, y + 296), en.upper(), mono(13), (126, 140, 166), anchor="mt")
        else:
            text(draw, (x + card_w / 2, y + 258), en, latin(25, "Bold"), INK, anchor="mt")
            text(draw, (x + card_w / 2, y + 296), f"{index + 1:02d} / {len(SCHEME_LIST)}", mono(12),
                 (126, 140, 166), anchor="mt")

        dots = [scheme["primary"], scheme["accent"], scheme["mid"]]
        dot_y = y + 344
        start = x + card_w / 2 - (len(dots) * 10 + (len(dots) - 1) * 8) / 2 + 5
        for i, color in enumerate(dots):
            cx = start + i * 18
            draw.ellipse([S(cx - 5), S(dot_y - 5), S(cx + 5), S(dot_y + 5)],
                         fill=color, outline=(255, 255, 255, 30), width=max(1, S(0.7)))
        text(draw, (x + card_w / 2, y + 376), key, mono(12), (84, 96, 120), anchor="mt")

    text(draw, (66, 1062), footer, mono(14), (92, 104, 128))
    return canvas.convert("RGB")


def build_social(source):
    width, height = S(1280), S(640)
    canvas = background(
        width, height,
        glows=[
            (0.10, 0.0, 0.48, (0, 200, 255), 0.26),
            (0.95, 1.0, 0.55, (125, 110, 255), 0.30),
        ],
    ).convert("RGBA")
    draw = ImageDraw.Draw(canvas)

    pill(draw, 80, 82, "DUAL WECHAT FOR MACOS", latin(13, "Medium"),
         fg=(200, 226, 244), fill=(0, 229, 255, 12),
         border=(0, 229, 255, 55), dot=CYAN, pad=16, height=36)

    icon = scheme_icon(source, "aurora", 1024)
    paste_icon(canvas, icon, (250, 360), 280, glow=(CYAN, 0.30, 54), shadow=0.45)
    draw = ImageDraw.Draw(canvas)

    canvas = gradient_text(canvas, (452, 214), "DualWeChat", latin(86, "Bold"),
                           (255, 255, 255), (176, 202, 246))
    draw = ImageDraw.Draw(canvas)
    text(draw, (454, 318), "Two WeChats. One Mac.", latin(32, "Bold"), (214, 226, 246))
    text(draw, (454, 372), f"One-click setup  ·  {len(SCHEME_LIST)} themes  ·  Fully local", latin(18, "Regular"), MUTED)
    text(draw, (454, 496), "github.com/MaiwulanjiangMaiming/DualWeChat",
         mono(16), (120, 136, 164))

    return canvas.convert("RGB")


def save(image, name):
    path = os.path.join(ASSETS, name)
    image = image.resize((image.width // SS, image.height // SS), Image.LANCZOS)
    image.save(path, optimize=True)
    print(f"  {name:24s} {image.width}x{image.height}  {os.path.getsize(path) / 1024:.0f} KB")


def main():
    os.makedirs(ASSETS, exist_ok=True)
    print("source icon:")
    source = load_source_icon()
    print(f"  {source.width}x{source.height}")

    print("app icons:")
    for key in SCHEME_LIST:
        image = scheme_icon(source, key, 1024).resize((512, 512), Image.LANCZOS)
        path = os.path.join(ASSETS, f"icon-{key}.png")
        image.save(path, optimize=True)
        print(f"  icon-{key}.png         512x512  {os.path.getsize(path) / 1024:.0f} KB")

    print("artwork:")
    save(build_hero(source, "cn"), "hero.png")
    save(build_hero(source, "en"), "hero-en.png")
    save(build_themes(source, "cn"), "themes.png")
    save(build_themes(source, "en"), "themes-en.png")
    save(build_social(source), "social-preview.png")


if __name__ == "__main__":
    main()
