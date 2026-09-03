# -*- coding: utf-8 -*-
## ★ เอฟเฟกต์ "ฟันธรรมดา" ของผู้เล่น (รอบ 44) ★
## รอยฟันโค้งพระจันทร์เสี้ยว สีขาว-ฟ้าอ่อน โปร่งแสง เล่นเร็ว (7 เฟรม 384x384 · 30fps ≈ 0.23 วิ)
##   ท่า slash  = ฟันจากบนขวาลงล่างซ้าย (ตีครั้งที่ 1)
##   ท่า slash2 = ภาพเดียวกันพลิกแนวตั้ง = ฟันสวนขึ้น (ตีครั้งที่ 2) → สลับกันทุกครั้งที่ตี
## → Sprites/effects/attack_slash.png (2688x384) + data/sprites/fx_attack.tres
## หันขวาเสมอ — ระบบ SkillEffect พลิกให้เองตอนหันซ้าย
import math, os
from PIL import Image, ImageDraw, ImageFilter

S = 2
FW = FH = 384
N = 7
FPS = 30
CW, CH = FW * S, FH * S
CX, CY = CW * 0.5, CH * 0.5
R = 140 * S                # รัศมีเสี้ยว

CORE = (255, 255, 255)
EDGE = (170, 225, 255)
GLOW = (90, 170, 255)


def layer():
    return Image.new("RGBA", (CW, CH), (0, 0, 0, 0))


def crescent(d, a0, a1, width, col, alpha, r=R):
    """วาดเสี้ยวจากมุม a0→a1 (องศา) ความหนาแปรตามตำแหน่ง (ปลายบาง กลางหนา)"""
    steps = 60
    pts_out, pts_in = [], []
    for i in range(steps + 1):
        t = i / steps
        a = math.radians(a0 + (a1 - a0) * t)
        w = width * math.sin(math.pi * t) ** 0.7 + 1.5 * S
        ox, oy = CX + math.cos(a) * (r + w * 0.5), CY + math.sin(a) * (r + w * 0.5)
        ix, iy = CX + math.cos(a) * (r - w * 0.5), CY + math.sin(a) * (r - w * 0.5)
        pts_out.append((ox, oy))
        pts_in.append((ix, iy))
    d.polygon(pts_out + pts_in[::-1], fill=col + (alpha,))


def frame(i):
    img = layer()
    t = i / (N - 1)
    # ช่วงมุมของเสี้ยว: เริ่มบนขวา (-75°) กวาดลงล่างซ้าย (+95°) — หัวเสี้ยวนำ หางตามหลัง
    head = -80 + 180 * min(1.0, t * 1.5)
    tail = -80 + 180 * max(0.0, (t - 0.4) * 1.55)
    if head - tail < 12:
        tail = head - 12
    fade = 1.0 if t < 0.55 else max(0.0, 1.0 - (t - 0.55) / 0.45)
    # เรืองแสงฟ้า (กว้าง เบลอ)
    g = layer()
    dg = ImageDraw.Draw(g)
    crescent(dg, tail, head, 76 * S, GLOW, int(160 * fade))
    g = g.filter(ImageFilter.GaussianBlur(9 * S))
    img = Image.alpha_composite(img, g)
    # ขอบฟ้าอ่อน
    e = layer()
    de = ImageDraw.Draw(e)
    crescent(de, tail, head, 42 * S, EDGE, int(220 * fade))
    e = e.filter(ImageFilter.GaussianBlur(2 * S))
    img = Image.alpha_composite(img, e)
    # แกนขาว
    c = layer()
    dc = ImageDraw.Draw(c)
    crescent(dc, tail + 3, head - 2, 20 * S, CORE, int(250 * fade))
    c = c.filter(ImageFilter.GaussianBlur(0.8 * S))
    img = Image.alpha_composite(img, c)
    # เส้นลมบาง ๆ ตามหลังหัวเสี้ยว
    if 0.15 < t < 0.8:
        s = layer()
        ds = ImageDraw.Draw(s)
        for k in range(3):
            rr = R + (28 + k * 22) * S
            a0 = tail + 10 + k * 8
            a1 = min(head - 6, a0 + 40)
            if a1 > a0:
                crescent(ds, a0, a1, 3 * S, EDGE, int(140 * fade), r=rr)
        s = s.filter(ImageFilter.GaussianBlur(1.2 * S))
        img = Image.alpha_composite(img, s)
    # ประกายเล็ก ๆ ที่หัวเสี้ยว
    if t < 0.7:
        sp = layer()
        dsp = ImageDraw.Draw(sp)
        a = math.radians(head)
        hx, hy = CX + math.cos(a) * R, CY + math.sin(a) * R
        rad = (14 - 8 * t) * S
        dsp.ellipse((hx - rad, hy - rad, hx + rad, hy + rad), fill=CORE + (int(230 * fade),))
        sp = sp.filter(ImageFilter.GaussianBlur(3 * S))
        img = Image.alpha_composite(img, sp)
    return img.resize((FW, FH), Image.LANCZOS)


def write_tres(path):
    lines = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (N + 2), "",
             '[ext_resource type="Texture2D" path="res://Sprites/effects/attack_slash.png" id="1_tex"]', ""]
    for i in range(N):
        lines += ['[sub_resource type="AtlasTexture" id="fx_%d"]' % i, 'atlas = ExtResource("1_tex")',
                  "region = Rect2(%d, 0, %d, %d)" % (i * FW, FW, FH), ""]

    def anim(name, flip):
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("fx_%d")\n}' % i for i in range(N))
        return '{\n"frames": [%s],\n"loop": false,\n"name": &"%s",\n"speed": %d.0\n}' % (fr, name, FPS)
    # slash2 ใช้ภาพชุดเดียวกัน — ตัว player พลิกแนวตั้งให้ตอนเล่น (flip_v) ผ่าน SkillEffect
    lines += ["[resource]", "animations = [" + anim("slash", False) + ", " + anim("slash2", True) + "]", ""]
    open(path, "w", encoding="utf-8").write("\n".join(lines))


def main():
    sheet = Image.new("RGBA", (FW * N, FH), (0, 0, 0, 0))
    for i in range(N):
        sheet.paste(frame(i), (FW * i, 0))
    os.makedirs("Sprites/effects", exist_ok=True)
    os.makedirs("data/sprites", exist_ok=True)
    sheet.save("Sprites/effects/attack_slash.png")
    write_tres("data/sprites/fx_attack.tres")
    print("บันทึก Sprites/effects/attack_slash.png", sheet.size, "+ data/sprites/fx_attack.tres")
    pv = Image.new("RGBA", (FW * N // 2, FH // 2), (60, 75, 60, 255))
    pv.alpha_composite(sheet.resize((FW * N // 2, FH // 2)))
    pv.save("/tmp/attack_fx_preview.png")


if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    main()
