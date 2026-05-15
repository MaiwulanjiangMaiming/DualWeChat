import sys
import os
import tempfile
import shutil

from PIL import Image
import numpy as np

SCHEMES = {
    "metal": {
        "name": "Metal / 金属",
        "base":  (6, 6, 8),
        "mid":   (22, 22, 26),
        "primary": (50, 50, 55),
        "accent": (205, 205, 210),
        "shimmer_amp": 15,
        "shimmer_offset": 4,
    },
    "aurora": {
        "name": "Aurora / 极光",
        "base":  (10, 14, 26),
        "mid":   (13, 33, 55),
        "primary": (0, 229, 255),
        "accent": (123, 143, 255),
        "shimmer_amp": 20,
        "shimmer_offset": 0,
    },
    "neon": {
        "name": "Neon / 霓虹",
        "base":  (18, 0, 21),
        "mid":   (30, 0, 48),
        "primary": (191, 0, 255),
        "accent": (255, 45, 120),
        "shimmer_amp": 20,
        "shimmer_offset": 0,
    },
    "lava": {
        "name": "Lava / 熔岩",
        "base":  (12, 8, 0),
        "mid":   (26, 16, 0),
        "primary": (255, 106, 0),
        "accent": (255, 210, 0),
        "shimmer_amp": 20,
        "shimmer_offset": 0,
    },
    "matrix": {
        "name": "Matrix / 矩阵",
        "base":  (0, 13, 7),
        "mid":   (0, 26, 15),
        "primary": (0, 255, 136),
        "accent": (0, 184, 76),
        "shimmer_amp": 20,
        "shimmer_offset": 0,
    },
}

SCHEME_LIST = ["metal", "aurora", "neon", "lava", "matrix"]


def generate_icon(src_icns_path, dst_icns_path, scheme_key="metal"):
    scheme = SCHEMES[scheme_key]
    tmp_dir = tempfile.mkdtemp(prefix="dualwechat_")
    try:
        tmp_png = os.path.join(tmp_dir, "icon_1024.png")
        os.system(f'sips -s format png "{src_icns_path}" --out "{tmp_png}" --resampleWidth 1024 >/dev/null 2>&1')

        src = Image.open(tmp_png).convert("RGBA")
        arr = np.array(src).astype(np.float32)

        r, g, b, a = arr[:,:,0], arr[:,:,1], arr[:,:,2], arr[:,:,3]
        gray = 0.299 * r + 0.587 * g + 0.114 * b
        gray_norm = gray / 255.0

        H, W = gray_norm.shape
        y_coords = np.arange(H).reshape(-1, 1).astype(np.float32) / H

        base_c = np.array(scheme["base"], dtype=np.float32)
        mid_c = np.array(scheme["mid"], dtype=np.float32)
        primary_c = np.array(scheme["primary"], dtype=np.float32)
        accent_c = np.array(scheme["accent"], dtype=np.float32)

        hi = gray_norm > 0.7
        md = (gray_norm > 0.4) & (~hi)
        lo = ~hi & ~md

        ht = np.clip((gray_norm - 0.7) / 0.3, 0, 1)
        mt = np.clip((gray_norm - 0.4) / 0.3, 0, 1)
        lt = np.clip(gray_norm / 0.4, 0, 1)

        out = np.zeros((H, W, 4), dtype=np.float32)

        for c in range(3):
            out[:,:,c] = np.where(hi,
                mid_c[c] + (primary_c[c] - mid_c[c]) * ht + (accent_c[c] - primary_c[c]) * ht * 0.3,
                out[:,:,c])

            out[:,:,c] = np.where(md,
                base_c[c] + (mid_c[c] - base_c[c]) * mt,
                out[:,:,c])

            out[:,:,c] = np.where(lo,
                base_c[c] * 0.5 + base_c[c] * 0.5 * lt,
                out[:,:,c])

        shimmer = np.sin(y_coords * np.pi * 2.5) * scheme["shimmer_amp"]
        glow = np.sin(y_coords * np.pi * 1.2 + 0.5) * 10
        for c in range(3):
            accent_shift = (accent_c[c] - primary_c[c]) * 0.08
            out[:,:,c] += shimmer * (primary_c[c] / 255.0) + glow * (accent_c[c] / 255.0) + accent_shift * ht

        out[:,:,3] = a
        out_int = np.clip(out, 0, 255).astype(np.uint8)
        result = Image.fromarray(out_int, "RGBA")

        iconset_dir = os.path.join(tmp_dir, "AppIcon.iconset")
        os.makedirs(iconset_dir, exist_ok=True)

        sizes = [
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

        for name, size in sizes:
            resized = result.resize((size, size), Image.LANCZOS)
            resized.save(os.path.join(iconset_dir, name))

        tmp_icns = os.path.join(tmp_dir, "AppIcon.icns")
        os.system(f'iconutil -c icns "{iconset_dir}" -o "{tmp_icns}"')

        if os.path.exists(tmp_icns):
            shutil.copy2(tmp_icns, dst_icns_path)
            print(f"✅ [{scheme['name']}] icon applied to {dst_icns_path}")
            return True
        else:
            print("❌ Failed to create icns file")
            return False

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    if len(sys.argv) < 2 or len(sys.argv) > 3:
        print(f"Usage: {sys.argv[0]} <target.icns> [scheme]")
        print(f"  Schemes: {', '.join(SCHEME_LIST)}")
        print(f"  Default: metal")
        sys.exit(1)

    src = "/Applications/WeChat.app/Contents/Resources/AppIcon.icns"
    if not os.path.exists(src):
        print(f"❌ Source icon not found: {src}")
        sys.exit(1)

    dst = sys.argv[1]
    scheme = sys.argv[2] if len(sys.argv) == 3 else "metal"

    if scheme not in SCHEMES:
        print(f"❌ Unknown scheme: {scheme}")
        print(f"   Available: {', '.join(SCHEME_LIST)}")
        sys.exit(1)

    success = generate_icon(src, dst, scheme)
    sys.exit(0 if success else 1)
