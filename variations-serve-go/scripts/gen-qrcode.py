#!/usr/bin/env python3
"""生成官网首页的 App Store 下载二维码（中心内嵌 App icon）。

依赖：python3 -m pip install "qrcode[pil]"
用法：python3 scripts/gen-qrcode.py [url]     # 缺省用下方 APP_STORE_URL
输出：deploy/web/qrcode.png

设计要点：
- 纠错等级 H（30% 冗余）：中心 icon 为像素级合成，遮挡约 9% 模块面积，
  仅用掉纠错余量的三分之一，各扫码器均可可靠识别；
- icon 圆角 tile 外加白色隔离环，与二维码模块保持静区分离；
- 模块色 #1E1B17 与站内 --ink 一致，白底保证对比度；
- 产物为自包含 PNG，脱离网页（打印、转发、别的页面引用）也能带 icon 使用。
"""
import sys
from pathlib import Path

import qrcode
from qrcode.constants import ERROR_CORRECT_H
from PIL import Image, ImageDraw

APP_STORE_URL = (
    "https://apps.apple.com/cn/app/"
    "%E5%8F%98%E5%A5%8F-ai-%E7%85%A7%E7%89%87%E8%89%BA%E6%9C%AF%E5%8F%98%E5%A5%8F/id6803094091"
)

FILL = "#1E1B17"
BACK = "#FFFFFF"
ICON_RATIO = 0.23   # icon 边长 / 图片总宽（含静区），遮挡模块面积约 9%
RING_RATIO = 0.016  # 白色隔离环单边宽度 / 图片总宽
ICON_RADIUS = 0.22  # 圆角比例（与 iOS 图形一致）

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "deploy" / "web" / "qrcode.png"
ICON = ROOT / "deploy" / "web" / "icon.png"


def embed_icon(qr_img: Image.Image, icon_path: Path) -> Image.Image:
    """把 icon 以白色圆角隔离环包裹后合成到二维码中心。"""
    img = qr_img.convert("RGBA")
    w, _ = img.size
    icon_w = round(w * ICON_RATIO)
    ring = round(w * RING_RATIO)
    tile = icon_w + ring * 2
    radius = round(icon_w * ICON_RADIUS)

    icon = Image.open(icon_path).convert("RGBA").resize((icon_w, icon_w), Image.LANCZOS)

    # 白色圆角底（隔离环）
    tile_img = Image.new("RGBA", (tile, tile), (0, 0, 0, 0))
    ImageDraw.Draw(tile_img).rounded_rectangle(
        [0, 0, tile - 1, tile - 1], radius=radius, fill=(255, 255, 255, 255)
    )
    # icon 按同圆角裁切后贴到 tile 中心
    mask = Image.new("L", (icon_w, icon_w), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, icon_w - 1, icon_w - 1], radius=radius, fill=255
    )
    tile_img.paste(icon, (ring, ring), mask)

    img.alpha_composite(tile_img, ((w - tile) // 2, (w - tile) // 2))
    return img


def main() -> None:
    data = sys.argv[1] if len(sys.argv) > 1 else APP_STORE_URL
    qr = qrcode.QRCode(error_correction=ERROR_CORRECT_H, box_size=10, border=4)
    qr.add_data(data)
    qr.make(fit=True)
    img = qr.make_image(fill_color=FILL, back_color=BACK)
    img = embed_icon(img, ICON)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(OUT)
    print(f"QR version {qr.version}（{qr.modules_count}×{qr.modules_count} 模块，中心内嵌 icon）→ {OUT}")


if __name__ == "__main__":
    main()
