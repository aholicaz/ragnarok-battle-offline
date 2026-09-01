# -*- coding: utf-8 -*-
## ★ เอฟเฟกต์สกิล Bash — ฟันสีแดง 2 จังหวะเร็ว ★ (ให้เข้ากับสไปรท์ Attack_Blade_bash ของผู้ใช้)
## 12 เฟรม 512x512 · 24fps = 0.5 วิ → Sprites/effects/bash_slash.png (6144x512)
##
##   เฟรม 0-2  จังหวะ 1: โค้งแดงกวาดจากบนซ้าย → ลงขวา (โค้งคว่ำ เหมือนเฟรม 6 ของสไปรท์)
##   เฟรม 3    กระแทกครั้งที่ 1 (ประกายที่ปลาย)          ← ดาเมจครั้งที่ 1
##   เฟรม 4-7  จังหวะ 2: โค้งแดงกวาดจากล่างซ้าย → ขึ้นขวา (โค้งหงาย ไขว้กับอันแรก)
##   เฟรม 8    กระแทกครั้งที่ 2 + ประกายไฟ                ← ดาเมจครั้งที่ 2
##   เฟรม 9-11 จางหาย
##
## หันขวาเสมอ (ระบบพลิกให้เอง) · วางกลางเฟรม · แก้สีที่ตัวแปรด้านล่างได้เลย
import math, random, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 2                 # supersample
F = 512               # ขนาดเฟรมจริง
N = 12                # จำนวนเฟรม
FPS = 24
C = F * S
random.seed(11)

# ---- สี (แดง) ----
CORE   = (255, 245, 235)   # แกนขาวอมชมพู
LIGHT  = (255, 120, 110)   # ชั้นใน
MAIN   = (235, 30, 45)     # แดงหลัก
DEEP   = (150, 0, 25)      # แดงเข้ม (แสงฟุ้ง)


def layer():
    return Image.new("RGBA", (C, C), (0, 0, 0, 0))

def glow(img, radius):
    return img.filter(ImageFilter.GaussianBlur(radius))

def add(base, top):
    r1, g1, b1, a1 = base.split(); r2, g2, b2, a2 = top.split()
    out = Image.merge("RGB", (ImageChops.add(r1, r2), ImageChops.add(g1, g2), ImageChops.add(b1, b2))).convert("RGBA")
    out.putalpha(ImageChops.add(a1, a2))
    return out

def A(color, a):
    return (color[0], color[1], color[2], int(max(0, min(255, a))))


def rot(p, deg):
    """หมุนจุดรอบกลางเฟรม (เอียงโค้งให้ดูเป็นฟันเฉียง)"""
    a = math.radians(deg); ox, oy = C * 0.5, C * 0.5
    x, y = p[0] - ox, p[1] - oy
    return (ox + x * math.cos(a) - y * math.sin(a), oy + x * math.sin(a) + y * math.cos(a))


def arc_poly(cx, cy, r, a0, a1, thick, sweep=1.0, steps=72, tilt=0.0):
    """จุดของโค้ง จาก a0→a1 (องศา) · sweep = โผล่มาถึงไหนแล้ว · ปลายเรียวทั้งสองข้าง หนากลาง-ปลายหน้า"""
    a1 = a0 + (a1 - a0) * sweep
    outer, inner = [], []
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(a0 + (a1 - a0) * t)
        k = (t ** 0.45) * ((1.0 - t) ** 0.55) * 2.0        # หนาสุดค่อนไปทางหน้า
        th = thick * (0.06 + 0.94 * min(1.0, k))
        outer.append(rot((cx + (r + th * 0.5) * math.cos(a), cy + (r + th * 0.5) * math.sin(a)), tilt))
        inner.append(rot((cx + (r - th * 0.5) * math.cos(a), cy + (r - th * 0.5) * math.sin(a)), tilt))
    return outer + inner[::-1]


def slash(alpha, sweep, flip=False, thick_mul=1.0, trail=True):
    """
    โค้งกว้างแนวนอน กวาดจากซ้าย (หลัง) ไปขวา (หน้า = ศัตรู)
    flip=False: โค้งคว่ำ (∩ กลับด้าน → จุดศูนย์กลางอยู่ข้างบน) เริ่มบนซ้าย จบล่างขวา
    flip=True : โค้งหงาย จุดศูนย์กลางอยู่ข้างล่าง เริ่มล่างซ้าย จบบนขวา
    """
    r = C * 0.44
    if not flip:
        cx, cy = C * 0.50, C * 0.50 - r + C * 0.34     # โค้งคว่ำ ปลายอยู่ y≈0.38 ท้องโค้ง y≈0.60
        a0, a1, tilt = 148.0, 32.0, 14.0               # เอียงลงขวา
    else:
        cx, cy = C * 0.50, C * 0.50 + r - C * 0.34     # โค้งหงาย
        a0, a1, tilt = -148.0, -32.0, -14.0            # เอียงขึ้นขวา
    thick = C * 0.10 * thick_mul
    out = layer()
    # เงาฟุ้งตามหลัง
    if trail:
        for lag, mul, th in [(6, 0.30, 1.6), (13, 0.16, 2.0)]:
            lay = layer(); d = ImageDraw.Draw(lay)
            la = lag if not flip else -lag
            d.polygon(arc_poly(cx, cy, r, a0 + la, a1 + la, thick * th, sweep, tilt=tilt), fill=A(DEEP, 255 * alpha * mul))
            out = add(out, glow(lay, 16 * S))
    # แสงฟุ้งแดงเข้ม
    lay = layer(); d = ImageDraw.Draw(lay)
    d.polygon(arc_poly(cx, cy, r, a0, a1, thick * 2.2, sweep, tilt=tilt), fill=A(DEEP, 200 * alpha))
    out = add(out, glow(lay, 20 * S))
    # ตัวโค้งแดง
    lay = layer(); d = ImageDraw.Draw(lay)
    d.polygon(arc_poly(cx, cy, r, a0, a1, thick * 1.15, sweep, tilt=tilt), fill=A(MAIN, 245 * alpha))
    out = add(out, glow(lay, 2.5 * S))
    # ชั้นในชมพู
    lay = layer(); d = ImageDraw.Draw(lay)
    d.polygon(arc_poly(cx, cy, r, a0, a1, thick * 0.55, sweep, tilt=tilt), fill=A(LIGHT, 255 * alpha))
    out = add(out, glow(lay, 1.2 * S))
    # แกนขาวคม
    lay = layer(); d = ImageDraw.Draw(lay)
    d.polygon(arc_poly(cx, cy, r, a0, a1, thick * 0.22, sweep, tilt=tilt), fill=A(CORE, 255 * alpha))
    out = add(out, lay)
    return out


def tip(flip, sweep=1.0):
    """พิกัดปลายหน้าของโค้ง (จุดกระแทก)"""
    r = C * 0.44
    if not flip:
        cx, cy = C * 0.50, C * 0.50 - r + C * 0.34
        a = math.radians(148.0 + (32.0 - 148.0) * sweep); tilt = 14.0
    else:
        cx, cy = C * 0.50, C * 0.50 + r - C * 0.34
        a = math.radians(-148.0 + (-32.0 + 148.0) * sweep); tilt = -14.0
    return rot((cx + r * math.cos(a), cy + r * math.sin(a)), tilt)


def burst(alpha, size, cx, cy, n_rays=10):
    out = layer()
    lay = layer(); d = ImageDraw.Draw(lay)
    for i in range(n_rays):
        a = math.radians(i * 360.0 / n_rays + random.uniform(-8, 8))
        L = size * random.uniform(0.5, 1.0)
        w = size * 0.08 * random.uniform(0.6, 1.2)
        p1 = (cx + math.cos(a) * L, cy + math.sin(a) * L)
        perp = (-math.sin(a) * w, math.cos(a) * w)
        d.polygon([(cx + perp[0], cy + perp[1]), (cx - perp[0], cy - perp[1]), p1], fill=A(LIGHT, 230 * alpha))
    out = add(out, glow(lay, 2 * S))
    out = add(out, glow(lay, 12 * S))
    lay = layer(); d = ImageDraw.Draw(lay)
    rr = size * 0.18
    d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=A(CORE, 255 * alpha))
    out = add(out, glow(lay, 8 * S))
    return out


SPARKS = [(random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(0.5, 1.5), random.uniform(0.4, 1.0)) for _ in range(40)]

def sparks(alpha, t, cx, cy):
    out = layer(); lay = layer(); d = ImageDraw.Draw(lay)
    for (ux, uy, spd, sz) in SPARKS:
        n = math.hypot(ux, uy) or 1.0
        dist = C * 0.20 * spd * t
        x = cx + ux / n * dist + C * 0.03 * ux
        y = cy + uy / n * dist + C * 0.16 * t * t
        s = C * 0.007 * sz * (1.0 - 0.5 * t)
        col = LIGHT if sz > 0.7 else MAIN
        d.ellipse((x - s, y - s, x + s, y + s), fill=A(col, 255 * alpha))
        d.line((x, y, x - ux / n * s * 5 * t, y - uy / n * s * 5 * t), fill=A(MAIN, 150 * alpha), width=int(max(1, s * 0.8)))
    out = add(out, glow(lay, 2 * S))
    out = add(out, glow(lay, 7 * S))
    return out


def frame(i):
    img = layer()
    t1x, t1y = tip(False)
    t2x, t2y = tip(True)
    if i == 0:
        img = add(img, slash(0.85, 0.45, False, 0.8))
    elif i == 1:
        img = add(img, slash(1.0, 0.80, False, 1.0))
    elif i == 2:
        img = add(img, slash(1.0, 1.0, False, 1.1))
        img = add(img, burst(0.6, C * 0.13, t1x, t1y, 8))
    elif i == 3:
        img = add(img, slash(0.9, 1.0, False, 1.0, trail=False))
        img = add(img, burst(1.0, C * 0.22, t1x, t1y, 12))
        img = add(img, sparks(0.8, 0.15, t1x, t1y))
    elif i == 4:
        img = add(img, slash(0.6, 1.0, False, 0.85, trail=False))
        img = add(img, sparks(0.7, 0.4, t1x, t1y))
        img = add(img, slash(0.9, 0.40, True, 0.8))
    elif i == 5:
        img = add(img, slash(0.4, 1.0, False, 0.7, trail=False))
        img = add(img, sparks(0.4, 0.65, t1x, t1y))
        img = add(img, slash(1.0, 0.80, True, 1.0))
    elif i == 6:
        img = add(img, slash(0.25, 1.0, False, 0.6, trail=False))
        img = add(img, slash(1.0, 1.0, True, 1.15))
        img = add(img, burst(0.6, C * 0.13, t2x, t2y, 8))
    elif i == 7:
        img = add(img, slash(1.0, 1.0, True, 1.1, trail=False))
        img = add(img, burst(1.0, C * 0.26, t2x, t2y, 14))
        img = add(img, sparks(0.9, 0.15, t2x, t2y))
    elif i == 8:
        img = add(img, slash(0.65, 1.0, True, 0.9, trail=False))
        img = add(img, burst(0.5, C * 0.18, t2x, t2y, 10))
        img = add(img, sparks(1.0, 0.4, t2x, t2y))
    elif i == 9:
        img = add(img, slash(0.35, 1.0, True, 0.7, trail=False))
        img = add(img, sparks(0.8, 0.65, t2x, t2y))
    elif i == 10:
        img = add(img, slash(0.15, 1.0, True, 0.55, trail=False))
        img = add(img, sparks(0.55, 0.85, t2x, t2y))
    else:
        img = add(img, sparks(0.3, 1.0, t2x, t2y))
    return img.resize((F, F), Image.LANCZOS)


def main():
    sheet = Image.new("RGBA", (F * N, F), (0, 0, 0, 0))
    for i in range(N):
        sheet.paste(frame(i), (F * i, 0))
    os.makedirs("Sprites/effects", exist_ok=True)
    sheet.save("Sprites/effects/bash_slash.png")
    print("บันทึก Sprites/effects/bash_slash.png", sheet.size)

    subs = "\n\n".join('[sub_resource type="AtlasTexture" id="fx_%d"]\natlas = ExtResource("1_tex")\nregion = Rect2(%d, 0, %d, %d)' % (i, F * i, F, F) for i in range(N))
    frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("fx_%d")\n}' % i for i in range(N))
    tres = '''[gd_resource type="SpriteFrames" load_steps=%d format=3]

[ext_resource type="Texture2D" path="res://Sprites/effects/bash_slash.png" id="1_tex"]

%s

[resource]
animations = [{
"frames": [%s],
"loop": false,
"name": &"slash",
"speed": %.1f
}]
''' % (N + 2, subs, frames, FPS)
    os.makedirs("data/sprites", exist_ok=True)
    open("data/sprites/fx_bash.tres", "w", encoding="utf-8").write(tres)
    print("บันทึก data/sprites/fx_bash.tres (%d เฟรม %dfps = %.2f วิ)" % (N, FPS, N / float(FPS)))

    bg = Image.new("RGBA", sheet.size, (38, 40, 52, 255)); bg.alpha_composite(sheet)
    bg.convert("RGB").resize((F * N // 3, F // 3)).save("/tmp/bash_fx_preview.png")


if __name__ == "__main__":
    main()
