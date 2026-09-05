#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 60 — วาดไอคอน "ปีกแห่งวาลคีรี" ชั่วคราว (256x256 พื้นหลังโปร่งใส)

    python3 make_wing_icon.py

ได้ไฟล์  Sprites/items/placeholder/wing_of_valkyrie.png
★ วาดของจริงแล้วเอาทับไฟล์นี้ได้เลย (ชื่อเดิม path เดิม ไม่ต้องแก้ .tres) ★
ขนาดที่แนะนำ: 256x256 พื้นหลังโปร่งใส (เท่าไอคอนอื่นหลังย่อด้วย shrink_icons.py)
"""
import os, math
from PIL import Image, ImageDraw, ImageFilter

SIZE = 256
OUT = "Sprites/items/placeholder/wing_of_valkyrie.png"

WHITE = (250, 251, 255, 255)
SHADE = (206, 216, 238, 255)
GOLD = (255, 206, 92, 255)
GOLD_DEEP = (214, 156, 40, 255)


def feather(draw, pivot, angle, length, width, fill, outline):
    """ขนนก 1 เส้น — วงรีที่ยื่นออกจากจุดหมุนไปตามมุมที่กำหนด (0 องศา = ชี้ขึ้น)"""
    px, py = pivot
    a = math.radians(angle)
    cx = px + math.sin(a) * length * 0.5
    cy = py - math.cos(a) * length * 0.5
    pts = []
    for t in range(0, 360, 10):
        u = math.radians(t)
        ex = math.sin(u) * width * 0.5          # แกนสั้น
        ey = -math.cos(u) * length * 0.5        # แกนยาว
        pts.append((cx + ex * math.cos(a) + ey * math.sin(a),
                    cy + ex * math.sin(a) - ey * math.cos(a)))
    draw.polygon(pts, fill=fill, outline=outline)


def right_wing(size):
    """ปีกขวา 1 ข้าง (โปร่งใส)
    ขอบนำปีกลากจาก "โคน" (ซ้ายล่าง) ไป "ปลายปีก" (ขวาบน)
    ขนเสียบตามขอบนำแล้วลู่ลงหลัง · ใกล้โคนสั้น ปลายปีกยาวสุด (ขนปลายปีก = สีทอง)"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    N = 11
    for i in range(N):
        t = i / (N - 1.0)
        ax = size * (0.10 + 0.80 * t)                 # จุดเสียบขนบนขอบนำ
        ay = size * (0.46 - 0.24 * t * t)
        ang = 158 - 58 * t                            # 180 = ลงล่าง · ยิ่งปลายปีกยิ่งลู่ออกข้าง
        length = size * (0.20 + 0.52 * t)
        width = size * (0.10 + 0.02 * t)
        col = GOLD if t > 0.78 else (SHADE if t > 0.5 else WHITE)
        edge = GOLD_DEEP if col is GOLD else (146, 162, 198, 255)
        feather(d, (ax, ay), ang, length, width, col, edge)
    # หัวไหล่ปีก (โคน) ให้ดูทึบ ไม่ขาดเป็นเส้น ๆ
    d.ellipse([size * 0.03, size * 0.34, size * 0.30, size * 0.56],
              fill=WHITE, outline=(146, 162, 198, 255), width=3)
    return img


def main():
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # แสงเรืองข้างหลัง
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([SIZE * 0.14, SIZE * 0.20, SIZE * 0.86, SIZE * 0.88], fill=(255, 226, 150, 85))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(18)))

    # ปีกขวา → ตัดขอบว่างออก → ย่อให้พอดีครึ่งไอคอน → กลับด้านเป็นปีกซ้าย (สมมาตรเป๊ะ)
    w = right_wing(SIZE)
    w = w.crop(w.getbbox())
    target_w = int(SIZE * 0.45)
    target_h = max(1, int(w.height * target_w / w.width))
    right = w.resize((target_w, target_h), Image.LANCZOS)
    left = right.transpose(Image.FLIP_LEFT_RIGHT)
    top = int(SIZE * 0.50 - target_h * 0.52)
    overlap = int(SIZE * 0.045)                  # ให้โคนปีกซ้อนกันตรงกลางเล็กน้อย
    img.alpha_composite(left, (SIZE // 2 - target_w + overlap, top))
    img.alpha_composite(right, (SIZE // 2 - overlap, top))

    d = ImageDraw.Draw(img)
    cx, cy = SIZE * 0.5, SIZE * 0.5
    # อัญมณีตรงกลางที่ปีกสองข้างมาบรรจบ
    d.ellipse([cx - SIZE * 0.10, cy - SIZE * 0.10, cx + SIZE * 0.10, cy + SIZE * 0.10],
              fill=GOLD, outline=GOLD_DEEP, width=3)
    d.ellipse([cx - SIZE * 0.065, cy - SIZE * 0.065, cx + SIZE * 0.065, cy + SIZE * 0.065],
              fill=(120, 200, 255, 255), outline=GOLD_DEEP, width=2)
    d.ellipse([cx - SIZE * 0.043, cy - SIZE * 0.046, cx - SIZE * 0.008, cy - SIZE * 0.004],
              fill=(235, 250, 255, 235))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, optimize=True)
    print("สร้าง %s  %s  %.1f KB" % (OUT, img.size, os.path.getsize(OUT) / 1024))


if __name__ == "__main__":
    main()
