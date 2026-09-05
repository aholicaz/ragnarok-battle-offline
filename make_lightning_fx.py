#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""★ เอฟเฟกต์ "สายฟ้าฟาดลงพื้น" ★ (รอบ 64) — ใช้กับสกิลสายฟ้าคำรามของอสูรสายฟ้า

    python3 make_lightning_fx.py

ได้ 2 ไฟล์:
    Sprites/effects/lightning_bolt.png   ชีท 10 เฟรม 256x640 (2560x640)
    data/sprites/fx_lightning.tres       SpriteFrames ท่า "bolt" 10 เฟรม 30fps (≈0.33 วิ)

★ วาดยังไง ★ เส้นสายฟ้าหักซิกแซกจากบนจอลงพื้น + แขนงแตกออกข้าง ๆ
    เฟรม 0     เส้นนำบาง ๆ จาง ๆ (ยังไม่ฟาด)
    เฟรม 1-2   ฟาดเต็มแรง เส้นหนาสว่างจ้า + แสงวาบรอบจุดตก + ประกายกระเด็น
    เฟรม 3-6   เส้นบางลง แสงที่พื้นแผ่กว้างขึ้นแล้วจางลง
    เฟรม 7-9   เหลือแค่ประกายไฟฟ้าเล็ก ๆ ที่พื้น จางหาย

★ จุดตกอยู่ที่ "ขอบล่างของเฟรม" ★ โค้ดวางให้ขอบล่างตรงกับพื้นพอดี
แก้สีได้ที่ CORE / GLOW / DEEP ข้างล่าง (ตอนนี้ ขาว-ฟ้า-น้ำเงิน ให้เข้ากับตัวอสูร)
"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter

S = 2                      # วาดใหญ่ x2 แล้วย่อ (ขอบเนียน)
FW, FH = 256, 640          # ขนาดเฟรมจริง
N = 10
FPS = 30
CW, CH = FW * S, FH * S
CX = CW * 0.5
GROUND = CH - 26 * S       # จุดที่สายฟ้าฟาดถึงพื้น (เว้นขอบล่างไว้นิดหน่อย)

CORE = (255, 255, 255)     # ไส้กลาง — ขาวจ้า
GLOW = (150, 210, 255)     # แสงรอบ — ฟ้าอ่อน
DEEP = (60, 110, 255)      # ขอบนอก — น้ำเงิน
SPARK = (200, 235, 255)

random.seed(64)


def layer():
    return Image.new("RGBA", (CW, CH), (0, 0, 0, 0))


def A(c, a):
    return (c[0], c[1], c[2], max(0, min(255, int(a))))


def bolt_path(seed, wobble=1.0):
    """เส้นทางสายฟ้า จากบนสุดลงถึงพื้น — คืนลิสต์จุด"""
    rnd = random.Random(seed)
    pts = [(CX + rnd.uniform(-30, 30) * S, -20 * S)]
    y = -20 * S
    while y < GROUND:
        step = rnd.uniform(38, 78) * S
        y = min(GROUND, y + step)
        # ยิ่งใกล้พื้นยิ่งเบนน้อยลง (ให้ปลายตรงลงจุดตก)
        t = y / GROUND
        spread = (1.0 - t * t) * 46 * S * wobble
        x = CX + rnd.uniform(-spread, spread)
        if y >= GROUND:
            x = CX + rnd.uniform(-6, 6) * S
        pts.append((x, y))
    return pts


def draw_poly(d, pts, width, color, alpha):
    if len(pts) < 2:
        return
    d.line(pts, fill=A(color, alpha), width=max(1, int(width)), joint="curve")


def branches(d, pts, seed, width, color, alpha, n=4):
    """แขนงเล็ก ๆ ที่แตกออกจากเส้นหลัก"""
    rnd = random.Random(seed + 999)
    for _ in range(n):
        i = rnd.randrange(1, max(2, len(pts) - 1))
        x, y = pts[i]
        dx = rnd.choice([-1, 1]) * rnd.uniform(25, 85) * S
        dy = rnd.uniform(30, 90) * S
        seg = [(x, y)]
        for k in range(rnd.randrange(2, 4)):
            x += dx * rnd.uniform(0.3, 0.7)
            y += dy * rnd.uniform(0.3, 0.7)
            if y > GROUND:
                break
            seg.append((x, y))
        draw_poly(d, seg, width, color, alpha)


def frame(i):
    img = layer()
    d = ImageDraw.Draw(img)

    # ---------- ความสว่างของแต่ละเฟรม ----------
    if i == 0:
        main, ground_a, spark_a, w = 0.28, 0.15, 0.0, 0.45
    elif i <= 2:
        main, ground_a, spark_a, w = 1.0, 1.0, 1.0, 1.0
    elif i <= 6:
        k = (7 - i) / 4.0
        # กะพริบ: เฟรมคู่สว่างกว่าเฟรมคี่นิดหน่อย
        fl = 1.15 if i % 2 == 0 else 0.85
        main, ground_a, spark_a, w = 0.75 * k * fl, 0.85, 0.7 * k, 0.5 + 0.4 * k
    else:
        k = (10 - i) / 3.0
        main, ground_a, spark_a, w = 0.0, 0.45 * k, 0.55 * k, 0.4

    # ---------- แสงที่พื้น (วาดก่อน อยู่หลังเส้น) ----------
    if ground_a > 0.01:
        g = layer()
        gd = ImageDraw.Draw(g)
        spread = (0.35 + 0.65 * min(1.0, i / 6.0))
        rx = (58 + 96 * spread) * S
        ry = (16 + 26 * spread) * S
        gd.ellipse([CX - rx, GROUND - ry, CX + rx, GROUND + ry * 0.75],
                   fill=A(GLOW, 215 * ground_a))
        gd.ellipse([CX - rx * 0.45, GROUND - ry * 0.6, CX + rx * 0.45, GROUND + ry * 0.45],
                   fill=A(CORE, 230 * ground_a))
        img.alpha_composite(g.filter(ImageFilter.GaussianBlur(11 * S)))

    # ---------- ตัวสายฟ้า ----------
    if main > 0.01:
        # ★ ใช้ "ทางเดินเส้นเดียวกัน" ทุกเฟรม ★ สายฟ้าจริงจะกะพริบอยู่ในร่องเดิม
        # ถ้าสุ่มใหม่ทุกเฟรมจะดูเหมือนฟาดใหม่ซ้ำ ๆ คนละที่ (เคยลองแล้วตาลาย)
        seed = 64
        pts = bolt_path(seed)

        # เรืองแสงรอบนอก (เบลอหนา)
        outer = layer()
        od = ImageDraw.Draw(outer)
        draw_poly(od, pts, 30 * S * w, DEEP, 215 * main)
        branches(od, pts, seed, 15 * S * w, DEEP, 165 * main)
        img.alpha_composite(outer.filter(ImageFilter.GaussianBlur(9 * S)))

        mid = layer()
        md = ImageDraw.Draw(mid)
        draw_poly(md, pts, 15 * S * w, GLOW, 245 * main)
        branches(md, pts, seed, 7 * S * w, GLOW, 200 * main)
        img.alpha_composite(mid.filter(ImageFilter.GaussianBlur(4 * S)))

        # ไส้กลางขาวจ้า (คมชัด ไม่เบลอ)
        draw_poly(d, pts, max(2, 6.5 * S * w), CORE, 255 * min(1.0, main * 1.25))
        branches(d, pts, seed, max(1, 3 * S * w), CORE, 220 * main)

    # ---------- ประกายกระเด็นที่พื้น ----------
    if spark_a > 0.01:
        rnd = random.Random(700 + i)
        sp = layer()
        sd = ImageDraw.Draw(sp)
        for _ in range(16):
            ang = rnd.uniform(math.pi * 1.05, math.pi * 1.95)
            r = rnd.uniform(20, 150) * S * (0.4 + 0.6 * min(1.0, i / 5.0))
            x = CX + math.cos(ang) * r
            y = GROUND + math.sin(ang) * r * 0.42
            ln = rnd.uniform(6, 20) * S
            sd.line([(x, y), (x + math.cos(ang) * ln, y + math.sin(ang) * ln * 0.5)],
                    fill=A(SPARK, 235 * spark_a), width=max(1, int(2 * S)))
        img.alpha_composite(sp.filter(ImageFilter.GaussianBlur(1.2 * S)))

    return img.resize((FW, FH), Image.LANCZOS)


def write_tres(path, png):
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (N + 2), "",
             '[ext_resource type="Texture2D" path="%s" id="1_tex"]' % png, ""]
    for i in range(N):
        lines += ['[sub_resource type="AtlasTexture" id="bolt_%d"]' % i,
                  'atlas = ExtResource("1_tex")',
                  "region = Rect2(%d, 0, %d, %d)" % (i * FW, FW, FH), ""]
    frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("bolt_%d")\n}' % i for i in range(N))
    lines += ["[resource]", "animations = [{", '"frames": [' + frames + "],",
              '"loop": false,', '"name": &"bolt",', '"speed": %d.0' % FPS, "}]", ""]
    open(path, "w", encoding="utf-8").write("\n".join(lines))


def main():
    sheet = Image.new("RGBA", (FW * N, FH), (0, 0, 0, 0))
    for i in range(N):
        sheet.paste(frame(i), (FW * i, 0))
        print("เฟรม", i)
    os.makedirs("Sprites/effects", exist_ok=True)
    os.makedirs("data/sprites", exist_ok=True)
    sheet.save("Sprites/effects/lightning_bolt.png")
    write_tres("data/sprites/fx_lightning.tres", "res://Sprites/effects/lightning_bolt.png")
    print("บันทึก Sprites/effects/lightning_bolt.png", sheet.size, "+ data/sprites/fx_lightning.tres")

    pv = Image.new("RGB", (FW * N // 2, FH // 2), (26, 30, 40))
    for i in range(N):
        fr = sheet.crop((i * FW, 0, (i + 1) * FW, FH)).resize((FW // 2, FH // 2))
        bg = Image.new("RGB", fr.size, (26, 30, 40))
        bg.paste(fr, (0, 0), fr)
        pv.paste(bg, (i * FW // 2, 0))
    pv.save("/tmp/lightning_preview.png")


if __name__ == "__main__":
    main()
