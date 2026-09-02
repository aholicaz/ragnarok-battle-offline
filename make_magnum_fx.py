# -*- coding: utf-8 -*-
## ★ เอฟเฟกต์สกิล Magnum Break — ระเบิดไฟออกรอบตัวตอนแทงดาบลงพื้น ★ (รอบ 37)
## 14 เฟรม 768x384 · 24fps ≈ 0.58 วิ → Sprites/effects/magnum_break.png (10752x384)
##
## ระยะให้ตรงกับที่ตั้งใน magnum_break.tres: Range X 270 (ซ้าย-ขวา ข้างละ 270) · Range Y 220 (สูงจากพื้น)
##   ใน tres ตั้ง effect_height = 340 → มาตราส่วน k = 340/384 = 0.885
##   วงไฟกว้างสุดในชีท ±305 px จากกลาง → ในเกม ±270 px  ✔
##   เปลวสูงสุดในชีท 248 px เหนือพื้น       → ในเกม 220 px   ✔
##   เส้นพื้นในชีทอยู่ที่ y = 296 (จากบน 384) → offset.y ในเกม = เท้า(+120) - 104*k ≈ +28
##
##   เฟรม 0-2   แฟลชขาวตรงจุดแทง + คลื่นกระแทกวงเล็ก + ลำแสงพุ่งขึ้น
##   เฟรม 2-8   วงไฟขยายออกทั้งสองข้าง เปลวลุกสูงตามวง ถ่านไฟกระเด็น
##   เฟรม 8-13  วงถึงระยะสุด → เปลวยุบเป็นควันแดง จางหาย
##
## แก้สีได้ที่ตัวแปร CORE/GOLD/ORANGE/DEEP · หันขวาเสมอ (สมมาตรอยู่แล้ว ระบบพลิกให้เอง)
import math, random, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 2                       # supersample
FW, FH = 768, 384           # ขนาดเฟรมจริง
N = 14
FPS = 24
CW, CH = FW * S, FH * S
GROUND = 296 * S            # เส้นพื้นในเฟรม
CX = CW * 0.5
R_MAX = 305 * S             # รัศมีวงไฟสุดท้าย (แนวนอน)
FLAME_MAX = 248 * S         # เปลวสูงสุด
random.seed(37)

# ---- สี (ทอง-ส้ม-แดง เหมือนสไปรท์ของผู้ใช้) ----
CORE   = (255, 252, 235)
GOLD   = (255, 225, 120)
ORANGE = (255, 150, 40)
DEEP   = (205, 60, 15)
SMOKE  = (90, 30, 15)


def layer():
    return Image.new("RGBA", (CW, CH), (0, 0, 0, 0))

def glow(img, r):
    return img.filter(ImageFilter.GaussianBlur(r))

def A(c, a):
    return (c[0], c[1], c[2], int(max(0, min(255, a))))

def over(base, top):
    base.alpha_composite(top)
    return base

def add(base, top):
    r1, g1, b1, a1 = base.split(); r2, g2, b2, a2 = top.split()
    out = Image.merge("RGB", (ImageChops.add(r1, r2), ImageChops.add(g1, g2), ImageChops.add(b1, b2))).convert("RGBA")
    out.putalpha(ImageChops.add(a1, a2))
    return out

def ease_out(t, p=2.2):
    return 1.0 - (1.0 - t) ** p


# ---------- เปลวไฟ 1 ลิ้น: หยดน้ำคว่ำ โคนกว้าง ปลายแหลม โยกไปมา ----------
def flame_poly(x, base_y, h, w, lean, wobble, phase=0.0):
    pts_l, pts_r = [], []
    steps = 10
    for i in range(steps + 1):
        t = i / steps                                  # 0 โคน → 1 ปลาย
        y = base_y - h * t
        # โคนกว้าง ปลายแหลม + คอดนิดหน่อยตรงกลาง
        ww = w * (1.0 - t) ** 0.7 * (0.85 + 0.15 * math.sin(t * math.pi))
        sway = lean * h * t * t + wobble * w * 0.6 * math.sin(t * 5.0 + phase) * t
        pts_l.append((x + sway - ww, y))
        pts_r.append((x + sway + ww, y))
    return pts_l + pts_r[::-1]


# ---------- ตำแหน่งเปลวรอบวง (ทำครั้งเดียว ให้ทุกเฟรมต่อเนื่องกัน) ----------
FLAMES = []
for i in range(38):
    ang = random.uniform(0, math.pi * 2)                 # มุมบนวงรี
    FLAMES.append({
        "ang": ang,
        "h": random.uniform(0.35, 0.85),                  # สัดส่วนความสูง
        "w": random.uniform(0.7, 1.3),
        "lean": random.uniform(-0.25, 0.25),
        "wob": random.uniform(-1, 1),
        "delay": random.uniform(0.0, 0.18),              # ลุกช้าเร็วต่างกัน
    })
# เปลวกลาง (ลำไฟที่จุดแทง)
CENTER_FLAMES = [(random.uniform(-0.28, 0.28), random.uniform(0.6, 1.0), random.uniform(0.5, 1.1), random.uniform(-0.2, 0.2)) for _ in range(9)]
EMBERS = [(random.uniform(-1, 1), random.uniform(0.3, 1.0), random.uniform(0.4, 1.1), random.uniform(0.0, 0.25),
           random.choice([GOLD, ORANGE, CORE])) for _ in range(48)]
ROCKS = [(random.uniform(-1, 1), random.uniform(0.5, 1.0), random.uniform(0.6, 1.4), random.uniform(0, 6.28)) for _ in range(14)]


def ring_radius(t):
    """รัศมีวงไฟที่เวลา t (0-1) — พุ่งเร็วตอนแรกแล้วช้าลง"""
    return R_MAX * (0.05 + 0.95 * ease_out(t, 2.6))


def frame(i):
    t = i / (N - 1)
    img = layer()
    ry_k = 0.30                                          # วงรีแบนตามมุมมองข้าง

    # ================= พื้นร้อน (ไล่สีบนพื้นใต้วง) =================
    rr = ring_radius(t)
    lay = layer(); d = ImageDraw.Draw(lay)
    a = 110 * (1.0 - t * 0.9)
    d.ellipse((CX - rr, GROUND - rr * ry_k, CX + rr, GROUND + rr * ry_k * 0.9), fill=A(DEEP, a))
    d.ellipse((CX - rr * 0.6, GROUND - rr * ry_k * 0.6, CX + rr * 0.6, GROUND + rr * ry_k * 0.55), fill=A(ORANGE, a * 0.8))
    over(img, glow(lay, 14 * S))

    # ================= แฟลช + ลำแสงที่จุดแทง (เฟรมแรก ๆ) =================
    if t < 0.26:
        k = 1.0 - t / 0.26
        lay = layer(); d = ImageDraw.Draw(lay)
        fr = (40 + 70 * (1 - k)) * S
        d.ellipse((CX - fr, GROUND - fr * 0.5, CX + fr, GROUND + fr * 0.3), fill=A(CORE, 240 * k))
        # ลำแสงพุ่งขึ้น
        bh = FLAME_MAX * (0.9 + 0.3 * (1 - k)); bw = (22 + 30 * (1 - k)) * S
        d.polygon([(CX - bw * 1.3, GROUND), (CX + bw * 1.3, GROUND), (CX + bw * 0.35, GROUND - bh), (CX - bw * 0.35, GROUND - bh)], fill=A(ORANGE, 200 * k))
        d.polygon([(CX - bw, GROUND), (CX + bw, GROUND), (CX + bw * 0.25, GROUND - bh), (CX - bw * 0.25, GROUND - bh)], fill=A(GOLD, 240 * k))
        d.polygon([(CX - bw * 0.4, GROUND), (CX + bw * 0.4, GROUND), (CX + bw * 0.1, GROUND - bh * 0.95), (CX - bw * 0.1, GROUND - bh * 0.95)], fill=A(CORE, 255 * k))
        over(img, glow(lay, 2 * S))
        over(img, glow(lay, 12 * S))

    # ================= คลื่นกระแทก (วงบาง ๆ นำหน้าไฟ) =================
    if t < 0.8:
        lay = layer(); d = ImageDraw.Draw(lay)
        sr = rr * 1.06 + 6 * S
        a = 200 * (1.0 - t / 0.8)
        w = int(max(2, (9 - 6 * t) * S))
        d.ellipse((CX - sr, GROUND - sr * ry_k, CX + sr, GROUND + sr * ry_k), outline=A(GOLD, a), width=w)
        d.ellipse((CX - sr, GROUND - sr * ry_k, CX + sr, GROUND + sr * ry_k), outline=A(CORE, a * 0.7), width=max(1, w // 2))
        over(img, glow(lay, 2 * S))
        over(img, glow(lay, 10 * S))

    # ================= วงไฟหลัก: เปลวลุกตามวง =================
    deep_l = layer(); main_l = layer(); core_l = layer()
    dd, dm, dc = ImageDraw.Draw(deep_l), ImageDraw.Draw(main_l), ImageDraw.Draw(core_l)
    life = 1.0 - max(0.0, (t - 0.55) / 0.45)             # ไฟค่อย ๆ มอดหลัง 55%
    for f in FLAMES:
        ft = max(0.0, t - f["delay"])
        if ft <= 0.0:
            continue
        r = ring_radius(ft)
        x = CX + math.cos(f["ang"]) * r
        y = GROUND + math.sin(f["ang"]) * r * ry_k
        grow = min(1.0, ft / 0.35)                        # ลุกขึ้นเร็ว
        h = FLAME_MAX * f["h"] * (0.35 + 0.65 * grow) * (0.25 + 0.75 * life) * (0.8 + 0.2 * math.sin(i * 1.7 + f["ang"] * 3)) * (0.55 if math.sin(f["ang"]) < 0 else 1.0)
        w = (18 + 14 * f["w"]) * S * (0.5 + 0.5 * grow) * (0.4 + 0.6 * life)
        lean = f["lean"] * 0.5 + math.cos(f["ang"]) * 0.18     # เอียงออกจากกลาง
        x = max(CX - R_MAX + w, min(CX + R_MAX - w, x))
        wob = f["wob"]; ph = i * 0.6 + f["ang"] * 2
        al = 255 * (0.3 + 0.7 * life)
        # เปลวหลังวง (sin<0) วาดจางกว่านิด ให้มีมิติ
        depth = 0.75 if math.sin(f["ang"]) < 0 else 1.0
        dd.polygon(flame_poly(x, y + 4 * S, h * 1.12, w * 1.35, lean, wob, ph), fill=A(DEEP, al * depth))
        dm.polygon(flame_poly(x, y, h, w, lean, wob, ph), fill=A(ORANGE, al * depth))
        dc.polygon(flame_poly(x, y - 2 * S, h * 0.6, w * 0.5, lean, wob, ph), fill=A(GOLD, al * depth))
        dc.polygon(flame_poly(x, y - 3 * S, h * 0.32, w * 0.25, lean, wob, ph), fill=A(CORE, al * 0.9 * depth))

    # แถบไฟฐานต่อเนื่องตามวง (ให้เปลวไม่ดูเป็นเทียนแยกกัน)
    bw_ = int(max(3, (26 - 10 * t) * S * (0.3 + 0.7 * life)))
    band_a = 235 * (0.25 + 0.75 * life)
    dd.ellipse((CX - rr, GROUND - rr * ry_k, CX + rr, GROUND + rr * ry_k), outline=A(DEEP, band_a), width=int(bw_ * 1.5))
    dm.ellipse((CX - rr, GROUND - rr * ry_k - 3 * S, CX + rr, GROUND + rr * ry_k - 3 * S), outline=A(ORANGE, band_a), width=bw_)
    dc.ellipse((CX - rr, GROUND - rr * ry_k - 6 * S, CX + rr, GROUND + rr * ry_k - 6 * S), outline=A(GOLD, band_a * 0.8), width=max(2, bw_ // 2))

    # ลำไฟกลาง (จุดแทง) — โตช่วงแรกแล้วแตกออก
    if t < 0.7:
        ck = 1.0 - t / 0.7
        for (ux, hh, ww, ln) in CENTER_FLAMES:
            x = CX + ux * 70 * S * (1 + t * 2)
            h = FLAME_MAX * hh * (0.5 + 0.5 * ck) * (1.0 if t < 0.3 else ck)
            w = 18 * S * ww * (0.6 + 0.4 * ck)
            dd.polygon(flame_poly(x, GROUND + 3 * S, h * 1.1, w * 1.3, ln, 0.5, i * 0.5), fill=A(DEEP, 255 * ck))
            dm.polygon(flame_poly(x, GROUND, h, w, ln, 0.5, i * 0.5), fill=A(ORANGE, 255 * ck))
            dc.polygon(flame_poly(x, GROUND - 2 * S, h * 0.6, w * 0.5, ln, 0.5, i * 0.5), fill=A(GOLD, 255 * ck))

    over(img, glow(deep_l, 10 * S))                       # แสงฟุ้งแดง
    over(img, glow(deep_l, 3 * S))
    over(img, glow(main_l, 2 * S))
    over(img, glow(core_l, 1.2 * S))
    over(img, glow(core_l, 5 * S))                        # ประกายทอง

    # ================= ควันแดงตอนท้าย =================
    if t > 0.5:
        sk = (t - 0.5) / 0.5
        lay = layer(); d = ImageDraw.Draw(lay)
        for f in FLAMES[::2]:
            r = ring_radius(t)
            x = CX + math.cos(f["ang"]) * r * (1 + 0.15 * sk)
            y = GROUND + math.sin(f["ang"]) * r * ry_k - FLAME_MAX * f["h"] * (0.5 + 0.5 * sk)
            pr = (22 + 30 * sk) * S * f["w"]
            d.ellipse((x - pr, y - pr * 0.8, x + pr, y + pr * 0.8), fill=A(SMOKE, 55 * (1 - sk)))
        over(img, glow(lay, 12 * S))

    # ================= ถ่านไฟ + ก้อนหินกระเด็น =================
    lay = layer(); d = ImageDraw.Draw(lay)
    for (ux, spd, sz, dl, col) in EMBERS:
        et = max(0.0, t - dl)
        if et <= 0:
            continue
        x = CX + ux * R_MAX * 1.15 * ease_out(et, 2.0)
        y = GROUND - (FLAME_MAX * 1.3 * spd * et - FLAME_MAX * 1.1 * et * et)
        if y > GROUND + 6 * S:
            continue
        r = (2.2 + 3.0 * sz) * S * (1.0 - 0.5 * et)
        d.ellipse((x - r, y - r, x + r, y + r), fill=A(col, 255 * (1.0 - et * 0.7)))
    over(img, glow(lay, 0.6 * S))
    over(img, glow(lay, 5 * S))
    lay = layer(); d = ImageDraw.Draw(lay)
    for (ux, spd, sz, rot) in ROCKS:
        x = CX + ux * R_MAX * 0.9 * ease_out(t, 1.8)
        y = GROUND - (FLAME_MAX * 1.0 * spd * t - FLAME_MAX * 1.25 * t * t)
        if y > GROUND + 2 * S:
            continue
        r = 7 * S * sz
        ang = rot + t * 9
        pts = [(x + r * math.cos(ang + k * 1.4) * (1 + 0.3 * math.sin(k * 2.1)), y + r * 0.8 * math.sin(ang + k * 1.4)) for k in range(5)]
        d.polygon(pts, fill=A((150, 105, 60), 255 * (1.0 - max(0.0, t - 0.7) / 0.3)))
        d.polygon([(px + 1 * S, py - 2 * S) for px, py in pts[:3]], fill=A((215, 165, 95), 200 * (1.0 - max(0.0, t - 0.7) / 0.3)))
    over(img, lay)

    # ตัดส่วนที่ต่ำกว่าพื้นออกเยอะ ๆ (ให้ขอบล่างสะอาด ไม่จมพื้น)
    cut = Image.new("L", (CW, CH), 255)
    ImageDraw.Draw(cut).rectangle((0, GROUND + 40 * S, CW, CH), fill=0)
    r_, g_, b_, a_ = img.split()
    img.putalpha(ImageChops.multiply(a_, cut))
    return img.resize((FW, FH), Image.LANCZOS)


def write_tres(path):
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (N + 2), "",
             '[ext_resource type="Texture2D" path="res://Sprites/effects/magnum_break.png" id="1_tex"]', ""]
    for i in range(N):
        lines += ['[sub_resource type="AtlasTexture" id="fx_%d"]' % i, 'atlas = ExtResource("1_tex")',
                  "region = Rect2(%d, 0, %d, %d)" % (i * FW, FW, FH), ""]
    lines += ["[resource]", "animations = [{", '"frames": [' + ", ".join('{\n"duration": 1.0,\n"texture": SubResource("fx_%d")\n}' % i for i in range(N)) + "],",
              '"loop": false,', '"name": &"burst",', '"speed": %d.0' % FPS, "}]", ""]
    open(path, "w", encoding="utf-8").write("\n".join(lines))


def main():
    sheet = Image.new("RGBA", (FW * N, FH), (0, 0, 0, 0))
    for i in range(N):
        sheet.paste(frame(i), (FW * i, 0))
        print("เฟรม", i)
    os.makedirs("Sprites/effects", exist_ok=True)
    os.makedirs("data/sprites", exist_ok=True)
    sheet.save("Sprites/effects/magnum_break.png")
    write_tres("data/sprites/fx_magnum.tres")
    print("บันทึก Sprites/effects/magnum_break.png", sheet.size, "+ data/sprites/fx_magnum.tres")
    # พรีวิว 2 แถว
    cols = 7
    pv = Image.new("RGBA", (FW * cols // 2, FH * 2 // 2), (55, 70, 55, 255))
    for i in range(N):
        fr = frame(i) if False else sheet.crop((i * FW, 0, (i + 1) * FW, FH)).resize((FW // 2, FH // 2))
        bg = Image.new("RGBA", fr.size, (55, 70, 55, 255)); bg.alpha_composite(fr)
        pv.paste(bg, ((i % cols) * FW // 2, (i // cols) * FH // 2))
    pv.convert("RGB").save("/tmp/magnum_preview.png")


if __name__ == "__main__":
    main()
