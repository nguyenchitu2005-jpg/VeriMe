"""Vẽ logo VeriMe: nền chuyển màu navy -> xanh dương, khiên trắng, vân tay xanh.

Xuất vào assets/icon/:
  app_icon.png             1024 – icon đầy đủ (Android < 8), bo góc
  app_icon_background.png  1024 – nền icon thích ứng (Android 8+)
  app_icon_foreground.png  1024 – lớp trước icon thích ứng (nằm trong vùng an toàn 66/108)
  app_icon_monochrome.png  1024 – icon đơn sắc theo theme (Android 13+)
Glyph lấy từ font Material Icons trong Flutter SDK (Apache-2.0).

Chạy từ thư mục gốc project (cần Pillow):  python tool/make_icon.py
rồi tạo icon Android:                     dart run flutter_launcher_icons
Ảnh xem trước các kiểu bo góc: build/icon_preview.png
"""
import math
import os
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

FLUTTER_ROOT = Path(os.environ.get("FLUTTER_ROOT") or Path(shutil.which("flutter")).resolve().parents[1])
FONT = str(FLUTTER_ROOT / "bin" / "cache" / "artifacts" / "material_fonts" / "materialicons-regular.otf")
OUT = Path("assets/icon")
PREVIEW = Path("build/icon_preview.png")
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW.parent.mkdir(parents=True, exist_ok=True)

SIZE = 1024
SHIELD, FINGERPRINT = chr(0xE596), chr(0xE287)
NAVY, BLUE, SKY = (11, 31, 77), (29, 78, 216), (59, 130, 246)


def gradient(size):
    """Chuyển màu chéo navy (trên trái) -> xanh dương (dưới phải) + vầng sáng nhẹ phía trên."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            t = t * t * (3 - 2 * t)  # smoothstep cho chuyển màu mềm
            c = [NAVY[i] + (BLUE[i] - NAVY[i]) * t for i in range(3)]
            # vầng sáng tròn ở 1/3 phía trên
            d = math.hypot(x - size * 0.5, y - size * 0.28) / (size * 0.75)
            glow = max(0.0, 1 - d) ** 2 * 0.22
            px[x, y] = tuple(int(min(255, v + (255 - v) * glow * 0.5 + SKY[i] * glow * 0.2)) for i, v in enumerate(c))
    return img


def glyph_mask(char, font_size, canvas, center):
    """Mặt nạ (L) của 1 glyph, căn giữa theo khung bao thực của glyph."""
    font = ImageFont.truetype(FONT, font_size)
    mask = Image.new("L", (canvas, canvas), 0)
    d = ImageDraw.Draw(mask)
    l, t, r, b = d.textbbox((0, 0), char, font=font)
    x = center[0] - (l + r) / 2
    y = center[1] - (t + b) / 2
    d.text((x, y), char, font=font, fill=255)
    return mask


def foreground_layers(canvas, shield_height):
    """Trả về (mặt nạ khiên, mặt nạ vân tay) đã căn giữa trong canvas."""
    # Glyph khiên cao ~0.92 em -> chọn cỡ chữ để khiên cao đúng shield_height.
    probe = glyph_mask(SHIELD, 1000, 1200, (600, 600))
    _, t, _, b = probe.getbbox()
    font_size = int(1000 * shield_height / (b - t))
    c = canvas / 2
    shield = glyph_mask(SHIELD, font_size, canvas, (c, c))
    # Vân tay đặt cao hơn tâm một chút (đáy khiên nhọn nên tâm thị giác nằm cao hơn).
    fp = glyph_mask(FINGERPRINT, int(font_size * 0.56), canvas, (c, c - shield_height * 0.04))
    return shield, fp


# ---- Lớp trước icon thích ứng: khiên trắng + vân tay xanh, có bóng mờ nhẹ ----
shield, fp = foreground_layers(SIZE, shield_height=SIZE * 0.46)
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
shadow = Image.new("RGBA", (SIZE, SIZE), (5, 15, 45, 0))
shadow.putalpha(shield.point(lambda a: a * 0.35).filter(ImageFilter.GaussianBlur(18)))
fg = Image.alpha_composite(fg, ImageChops.offset(shadow, 0, 14))
white = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
white.putalpha(shield)
fg = Image.alpha_composite(fg, white)
blue = Image.new("RGBA", (SIZE, SIZE), BLUE + (255,))
blue.putalpha(ImageChops.multiply(fp, shield))
fg = Image.alpha_composite(fg, blue)
fg.save(OUT / "app_icon_foreground.png")

bg = gradient(SIZE)
bg.save(OUT / "app_icon_background.png")

# ---- Icon đầy đủ (Android < 8): nền + lớp trước phóng to hơn, bo góc ----
full_shield, full_fp = foreground_layers(SIZE, shield_height=SIZE * 0.62)
full = bg.convert("RGBA")
sh = Image.new("RGBA", (SIZE, SIZE), (5, 15, 45, 0))
sh.putalpha(full_shield.point(lambda a: a * 0.35).filter(ImageFilter.GaussianBlur(20)))
full = Image.alpha_composite(full, ImageChops.offset(sh, 0, 16))
w = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255))
w.putalpha(full_shield)
full = Image.alpha_composite(full, w)
bl = Image.new("RGBA", (SIZE, SIZE), BLUE + (255,))
bl.putalpha(ImageChops.multiply(full_fp, full_shield))
full = Image.alpha_composite(full, bl)
corner = Image.new("L", (SIZE, SIZE), 0)
ImageDraw.Draw(corner).rounded_rectangle((0, 0, SIZE - 1, SIZE - 1), radius=int(SIZE * 0.22), fill=255)
full.putalpha(corner)
full.save(OUT / "app_icon.png")

# ---- Đơn sắc (Android 13 themed icons): khiên, vân tay khoét rỗng ----
mono = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
mono.putalpha(ImageChops.subtract(shield, fp))
mono.save(OUT / "app_icon_monochrome.png")

# ---- Ảnh xem trước: icon thích ứng dưới các kiểu mặt nạ launcher + cỡ nhỏ ----
adaptive = Image.alpha_composite(bg.convert("RGBA"), fg)
# Launcher chỉ hiện 72/108 ở giữa icon thích ứng.
inset = int(SIZE * 18 / 108)
visible = adaptive.crop((inset, inset, SIZE - inset, SIZE - inset)).resize((256, 256), Image.LANCZOS)
masks = []
for shape in ("circle", "squircle", "rounded"):
    m = Image.new("L", (256, 256), 0)
    d = ImageDraw.Draw(m)
    if shape == "circle":
        d.ellipse((0, 0, 255, 255), fill=255)
    elif shape == "squircle":
        d.rounded_rectangle((0, 0, 255, 255), radius=90, fill=255)
    else:
        d.rounded_rectangle((0, 0, 255, 255), radius=40, fill=255)
    tile = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    tile.paste(visible, (0, 0), m)
    masks.append(tile)
pv = Image.new("RGBA", (256 * 3 + 40 * 4 + 300, 340), (243, 244, 246, 255))
for i, tile in enumerate(masks):
    pv.alpha_composite(tile, (40 + i * 296, 40))
small = visible.resize((48, 48), Image.LANCZOS)
m48 = Image.new("L", (48, 48), 0)
ImageDraw.Draw(m48).ellipse((0, 0, 47, 47), fill=255)
s48 = Image.new("RGBA", (48, 48), (0, 0, 0, 0))
s48.paste(small, (0, 0), m48)
pv.alpha_composite(s48, (40 + 3 * 296, 40))
mono_prev = Image.new("RGBA", (256, 256), (30, 41, 59, 255))
mono_small = mono.crop((inset, inset, SIZE - inset, SIZE - inset)).resize((150, 150), Image.LANCZOS)
pv.alpha_composite(full.resize((128, 128), Image.LANCZOS), (40 + 3 * 296, 110))
mono_tile = Image.new("RGBA", (128, 128), (30, 41, 59, 255))
mono_tile.alpha_composite(mono.crop((inset, inset, SIZE - inset, SIZE - inset)).resize((128, 128), Image.LANCZOS))
pv.alpha_composite(mono_tile, (40 + 3 * 296 + 140, 110))
pv.save(PREVIEW)
print("ok", [p.name for p in OUT.iterdir()])
