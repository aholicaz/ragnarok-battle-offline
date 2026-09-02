# -*- coding: utf-8 -*-
## ★ เอฟเฟกต์ระเบิดเหมือก (สกิลคิงโพริง) ★ 8 เฟรม 256x256 → Sprites/effects/slime_burst.png (2048x256)
## บอลตกพื้น → แตกเป็นวงคลื่นสีชมพู + หยดเหมือกกระเด็นขึ้นแล้วตก
import math, random, os
from PIL import Image, ImageDraw, ImageFilter

S = 2; F = 256; N = 8; C = F * S
random.seed(5)
PINK = (255, 105, 160); LIGHT = (255, 190, 215); DEEP = (200, 40, 110); WHITE = (255, 245, 250)

def layer(): return Image.new("RGBA", (C, C), (0, 0, 0, 0))
def A(c, a): return (c[0], c[1], c[2], int(max(0, min(255, a))))
def over(base, top): base.alpha_composite(top); return base

DROPS = [(random.uniform(-1, 1), random.uniform(0.6, 1.5), random.uniform(0.5, 1.2), random.choice([PINK, LIGHT, DEEP])) for _ in range(26)]

def frame(i):
    t = i / (N - 1)
    img = layer()
    gy = C * 0.80                      # ระดับพื้น (ขอบล่างของเอฟเฟกต์ ~ พื้น)
    cx = C * 0.5
    # ---- แสงแฟลชตอนกระแทก (เฟรมแรก ๆ) ----
    if i < 3:
        lay = layer(); d = ImageDraw.Draw(lay)
        r = C * (0.10 + 0.10 * i)
        d.ellipse((cx - r, gy - r * 0.55, cx + r, gy + r * 0.35), fill=A(WHITE, 230 - 70 * i))
        over(img, lay.filter(ImageFilter.GaussianBlur(10 * S)))
    # ---- วงคลื่นเหมือกขยายออก (วงรีแบนตามพื้น) ----
    ring_r = C * (0.06 + 0.42 * t)
    ring_w = C * (0.10 * (1.0 - t) + 0.02)
    alpha = 255 * (1.0 - t * 0.85)
    lay = layer(); d = ImageDraw.Draw(lay)
    d.ellipse((cx - ring_r, gy - ring_r * 0.32, cx + ring_r, gy + ring_r * 0.32), outline=A(DEEP, alpha), width=int(ring_w * 1.4))
    d.ellipse((cx - ring_r, gy - ring_r * 0.32, cx + ring_r, gy + ring_r * 0.32), outline=A(PINK, alpha), width=int(ring_w))
    d.ellipse((cx - ring_r, gy - ring_r * 0.32 - ring_w * 0.25, cx + ring_r, gy + ring_r * 0.32 - ring_w * 0.25), outline=A(LIGHT, alpha * 0.8), width=int(max(2, ring_w * 0.35)))
    over(img, lay.filter(ImageFilter.GaussianBlur(1.5 * S)))
    # แสงฟุ้งรอบวง
    over(img, lay.filter(ImageFilter.GaussianBlur(14 * S)))
    # ---- แอ่งเหมือกตรงกลาง (ค่อย ๆ จาง) ----
    lay = layer(); d = ImageDraw.Draw(lay)
    pr = C * (0.12 + 0.18 * t)
    d.ellipse((cx - pr, gy - pr * 0.22, cx + pr, gy + pr * 0.22), fill=A(PINK, 170 * (1.0 - t)))
    d.ellipse((cx - pr * 0.6, gy - pr * 0.16, cx + pr * 0.6, gy + pr * 0.02), fill=A(LIGHT, 120 * (1.0 - t)))
    over(img, lay.filter(ImageFilter.GaussianBlur(2 * S)))
    # ---- หยดเหมือกกระเด็น: ขึ้นแล้วตกตามแรงโน้มถ่วง ----
    lay = layer(); d = ImageDraw.Draw(lay)
    for (ux, spd, sz, col) in DROPS:
        tt = t * 1.15
        x = cx + ux * C * 0.42 * tt
        y = gy - (C * 0.55 * spd * tt - C * 0.70 * tt * tt)
        if y > gy + 4: continue
        r = C * 0.022 * sz * (1.0 - 0.4 * t)
        d.ellipse((x - r, y - r * 1.25, x + r, y + r * 1.25), fill=A(col, 255 * (1.0 - t * 0.6)))
        d.ellipse((x - r * 0.4, y - r * 0.9, x + r * 0.1, y - r * 0.3), fill=A(WHITE, 160 * (1.0 - t * 0.6)))
    over(img, lay.filter(ImageFilter.GaussianBlur(0.8 * S)))
    return img.resize((F, F), Image.LANCZOS)

def main():
    sheet = Image.new("RGBA", (F * N, F), (0, 0, 0, 0))
    for i in range(N): sheet.paste(frame(i), (F * i, 0))
    os.makedirs("Sprites/effects", exist_ok=True)
    sheet.save("Sprites/effects/slime_burst.png")
    print("บันทึก Sprites/effects/slime_burst.png", sheet.size)
    bg = Image.new("RGBA", sheet.size, (60, 80, 60, 255)); bg.alpha_composite(sheet)
    bg.convert("RGB").save("/tmp/slime_burst_preview.png")

if __name__ == "__main__":
    main()
