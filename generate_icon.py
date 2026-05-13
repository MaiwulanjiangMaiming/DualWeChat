import sys
import os
import tempfile
import shutil
from pathlib import Path

from PIL import Image
import numpy as np

def create_metallic_icon(src_icns_path, dst_icns_path):
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

        out_r = np.zeros((H, W), dtype=np.float32)
        out_g = np.zeros((H, W), dtype=np.float32)
        out_b = np.zeros((H, W), dtype=np.float32)

        hi = gray_norm > 0.7
        mid = (gray_norm > 0.4) & (~hi)
        lo = ~hi & ~mid

        ht = np.clip((gray_norm - 0.7) / 0.3, 0, 1)
        out_r[hi] = 50 + 155 * ht[hi]
        out_g[hi] = 50 + 155 * ht[hi]
        out_b[hi] = 55 + 155 * ht[hi]

        mt = np.clip((gray_norm - 0.4) / 0.3, 0, 1)
        out_r[mid] = 22 + 28 * mt[mid]
        out_g[mid] = 22 + 28 * mt[mid]
        out_b[mid] = 26 + 29 * mt[mid]

        lt = np.clip(gray_norm / 0.4, 0, 1)
        out_r[lo] = 6 + 16 * lt[lo]
        out_g[lo] = 6 + 16 * lt[lo]
        out_b[lo] = 8 + 18 * lt[lo]

        shimmer = np.sin(y_coords * np.pi * 2.5) * 15
        out_r += shimmer
        out_g += shimmer
        out_b += shimmer + 4

        out_arr = np.zeros((H, W, 4), dtype=np.uint8)
        out_arr[:,:,0] = np.clip(out_r, 0, 255).astype(np.uint8)
        out_arr[:,:,1] = np.clip(out_g, 0, 255).astype(np.uint8)
        out_arr[:,:,2] = np.clip(out_b, 0, 255).astype(np.uint8)
        out_arr[:,:,3] = a.astype(np.uint8)

        result = Image.fromarray(out_arr, "RGBA")

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
            print(f"✅ Metallic icon applied to {dst_icns_path}")
            return True
        else:
            print("❌ Failed to create icns file")
            return False

    finally:
        shutil.rmtree(tmp_dir, ignore_errors=True)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <target.icns>")
        print(f"  Reads from original WeChat.icns, generates metallic version,")
        print(f"  and writes to <target.icns>")
        sys.exit(1)

    src = "/Applications/WeChat.app/Contents/Resources/AppIcon.icns"
    if not os.path.exists(src):
        print(f"❌ Source icon not found: {src}")
        sys.exit(1)

    dst = sys.argv[1]
    success = create_metallic_icon(src, dst)
    sys.exit(0 if success else 1)
