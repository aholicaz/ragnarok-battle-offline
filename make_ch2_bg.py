# -*- coding: utf-8 -*-
## ★ รอบ 38 — ฉากหลังแมพบท 2 ทั้ง 5 แมพ + แมพรอยสายฟ้า ★ (ภาพชั่วคราวสวย ๆ รอผู้ใช้วาดจริง)
## สร้างภาพครึ่งสเกล (ประหยัดพื้นที่) แล้วผูกเข้า Polygon2D "Sky" ของแต่ละแมพด้วย uv
## รันซ้ำได้ · ปิด Godot ก่อนรัน
import math, random, os, re, shutil
from PIL import Image, ImageDraw, ImageFilter

os.chdir(os.path.dirname(os.path.abspath(__file__)))
OUT = "Sprites/map/generated"

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def vgrad(w, h, stops):
    """ไล่สีแนวตั้ง stops = [(y0-1.0, สี)]"""
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        c = stops[-1][1]
        for i in range(len(stops) - 1):
            (t0, c0), (t1, c1) = stops[i], stops[i + 1]
            if t0 <= t <= t1:
                c = lerp(c0, c1, (t - t0) / max(0.0001, t1 - t0))
                break
        for x in range(0, w):
            px[x, y] = c
    return img

def ridge(d, w, y_base, amp, col, seed, step=60, spikes=False):
    random.seed(seed)
    pts = [(0, y_base + random.uniform(-amp, amp))]
    x = 0
    while x < w:
        x += random.randint(step, step * 2)
        y = y_base + random.uniform(-amp, amp * 0.4)
        if spikes and random.random() < 0.3:
            y -= amp * random.uniform(0.8, 1.6)
        pts.append((min(x, w), y))
    pts += [(w, y_base + amp * 4), (0, y_base + amp * 4)]
    d.polygon(pts, fill=col)

def glow_dots(img, n, y0, y1, col, seed, rmin=2, rmax=5, blur=6):
    random.seed(seed)
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    w, h = img.size
    for _ in range(n):
        x = random.uniform(0, w); y = random.uniform(y0 * h, y1 * h)
        r = random.uniform(rmin, rmax)
        d.ellipse((x - r, y - r, x + r, y + r), fill=col + (200,))
    img.paste(Image.alpha_composite(img.convert("RGBA"), lay.filter(ImageFilter.GaussianBlur(blur))).convert("RGB"), (0, 0))
    img.paste(Image.alpha_composite(img.convert("RGBA"), lay).convert("RGB"), (0, 0))

def houses(d, w, gy, n, body, warm, seed):
    """บ้านคนแคระเงาดำ + หน้าต่างไฟส้ม"""
    random.seed(seed)
    for i in range(n):
        bw = random.randint(120, 260); bh = random.randint(90, 220)
        x = random.uniform(0, w - bw); y = gy - bh
        d.rectangle((x, y, x + bw, gy), fill=body)
        d.polygon([(x - 10, y), (x + bw + 10, y), (x + bw * 0.5 + random.uniform(-20, 20), y - bh * random.uniform(0.3, 0.55))], fill=body)
        for _ in range(random.randint(1, 4)):
            wx = x + random.uniform(8, bw - 22); wy = y + random.uniform(10, bh - 24)
            d.rectangle((wx, wy, wx + random.randint(8, 16), wy + random.randint(10, 18)), fill=warm)

def pillars(d, w, gy, top, n, col, seed, cap=True):
    random.seed(seed)
    for i in range(n):
        x = (i + 0.5) * w / n + random.uniform(-40, 40)
        pw = random.uniform(28, 44)
        d.rectangle((x - pw, top, x + pw, gy), fill=col)
        if cap:
            d.rectangle((x - pw * 1.5, top, x + pw * 1.5, top + 26), fill=col)
            d.rectangle((x - pw * 1.4, gy - 30, x + pw * 1.4, gy), fill=col)

def ground_strip(img, gy_px, col_top, col_body, seed):
    w, h = img.size
    d = ImageDraw.Draw(img)
    d.rectangle((0, gy_px, w, h), fill=col_body)
    d.rectangle((0, gy_px, w, gy_px + 6), fill=col_top)
    random.seed(seed)
    for _ in range(int(w / 6)):
        x = random.uniform(0, w); y = random.uniform(gy_px + 10, h - 4)
        r = random.uniform(1.5, 5)
        shade = lerp(col_body, (0, 0, 0), random.uniform(0.15, 0.4))
        d.ellipse((x - r, y - r * 0.5, x + r, y + r * 0.5), fill=shade)

GY = 0.8308     # เส้นพื้น (880+200)/1300

def paint(mp):
    w, h = mp["size"]
    gy = int(h * GY)
    img = vgrad(w, h, mp["sky"]).convert("RGB")
    d = ImageDraw.Draw(img)
    mp["draw"](img, d, w, h, gy)
    ground_strip(img, gy, mp["ground_top"], mp["ground"], hash(mp["id"]) % 999)
    return img

# ---------- ทางเหล็ก: หุบเขาเหล็กมืด เสาโซ่ ประตูภูเขา ----------
def draw_iron_road(img, d, w, h, gy):
    ridge(d, w, h * 0.42, h * 0.16, (38, 36, 44), 1, spikes=True)
    ridge(d, w, h * 0.58, h * 0.12, (30, 28, 34), 2, spikes=True)
    pillars(d, w, gy, int(h * 0.30), 7, (24, 22, 26), 3)
    glow_dots(img, 26, 0.35, 0.75, (255, 150, 60), 4, 1.5, 3.5, 5)

# ---------- นิดาเวลลิร์: นครในถ้ำ ไฟเตาหลอมอุ่น ๆ ----------
def draw_nidavellir(img, d, w, h, gy):
    # เพดานถ้ำ
    ridge(d, w, h * 0.10, h * 0.10, (26, 20, 18), 11, spikes=True)
    pts = [(0, 0), (w, 0), (w, h * 0.16), (0, h * 0.16)]
    ridge(d, w, h * 0.5, h * 0.14, (44, 34, 30), 12)
    houses(d, w, gy, 14, (30, 24, 22), (255, 170, 70), 13)
    houses(ImageDraw.Draw(img), w, int(gy - h * 0.02), 8, (22, 17, 16), (255, 140, 50), 14)
    glow_dots(img, 60, 0.45, 0.82, (255, 170, 70), 15, 1.5, 3, 4)

# ---------- เหมืองถ่านไฟ: ถ้ำลาวา ค้ำยันไม้ ----------
def draw_ember_mine(img, d, w, h, gy):
    ridge(d, w, h * 0.14, h * 0.10, (30, 16, 12), 21, spikes=True)
    # หินย้อย
    random.seed(22)
    for _ in range(26):
        x = random.uniform(0, w); ln = random.uniform(30, 120); pw = random.uniform(10, 26)
        d.polygon([(x - pw, 0), (x + pw, 0), (x, ln)], fill=(34, 20, 15))
    ridge(d, w, h * 0.55, h * 0.12, (52, 26, 18), 23)
    # แสงลาวาจากด้านล่าง
    lava = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dl = ImageDraw.Draw(lava)
    for i in range(14):
        x = random.uniform(0, w); r = random.uniform(60, 160)
        dl.ellipse((x - r, gy - r * 0.25, x + r, gy + r * 0.25), fill=(255, 90, 20, 60))
    img.paste(Image.alpha_composite(img.convert("RGBA"), lava.filter(ImageFilter.GaussianBlur(18))).convert("RGB"), (0, 0))
    # ค้ำยันไม้
    random.seed(24)
    for i in range(6):
        x = (i + 0.5) * w / 6 + random.uniform(-50, 50)
        d.rectangle((x - 12, gy - 190, x + 12, gy), fill=(48, 32, 20))
        d.rectangle((x - 90, gy - 200, x + 90, gy - 178), fill=(48, 32, 20))
    glow_dots(img, 50, 0.55, 0.85, (255, 120, 40), 25, 1.5, 3.5, 5)

# ---------- ห้องโถงเงียบ: มหาวิหารใต้ดิน เสาหิน แสงเย็น ----------
def draw_hall(img, d, w, h, gy):
    # ลำแสงเย็นจากรอยแยกเพดาน
    beams = Image.new("RGBA", img.size, (0, 0, 0, 0))
    db = ImageDraw.Draw(beams)
    random.seed(31)
    for i in range(5):
        x = (i + 0.5) * w / 5 + random.uniform(-80, 80)
        db.polygon([(x - 26, 0), (x + 26, 0), (x + 120, gy), (x - 120, gy)], fill=(150, 180, 220, 26))
    img.paste(Image.alpha_composite(img.convert("RGBA"), beams.filter(ImageFilter.GaussianBlur(6))).convert("RGB"), (0, 0))
    pillars(d, w, gy, int(h * 0.06), 9, (22, 24, 32), 32)
    ridge(d, w, h * 0.60, h * 0.10, (18, 20, 28), 33)
    glow_dots(img, 24, 0.3, 0.7, (120, 160, 220), 34, 1.5, 3, 6)

# ---------- เตาหลอมร้าง: เตายักษ์พัง ถ่านใกล้ดับ ----------
def draw_cold_forge(img, d, w, h, gy):
    ridge(d, w, h * 0.20, h * 0.10, (22, 22, 28), 41)
    # เตาหลอมยักษ์ตรงกลาง-ขวา
    cx = w * 0.62
    d.polygon([(cx - 260, gy), (cx - 180, h * 0.22), (cx + 180, h * 0.22), (cx + 260, gy)], fill=(30, 28, 34))
    d.rectangle((cx - 70, h * 0.35, cx + 70, gy), fill=(16, 15, 20))
    # รอยแตกเรืองส้มจาง ๆ ในเตา
    random.seed(42)
    for _ in range(10):
        x = cx + random.uniform(-160, 160); y = random.uniform(h * 0.3, gy - 20)
        d.line([(x, y), (x + random.uniform(-30, 30), y + random.uniform(10, 40))], fill=(200, 90, 40), width=3)
    # ท่อ/ปล่อง
    for px in (w * 0.18, w * 0.33, w * 0.85):
        d.rectangle((px - 30, h * 0.30, px + 30, gy), fill=(26, 25, 31))
        d.rectangle((px - 44, h * 0.28, px + 44, h * 0.32), fill=(26, 25, 31))
    glow_dots(img, 20, 0.5, 0.8, (230, 110, 50), 43, 1.5, 3, 7)

# ---------- รอยสายฟ้า: ฟ้าพายุ แสงฟ้าแลบ ต้นไม้ไหม้ ----------
def draw_thunder(img, d, w, h, gy):
    # ฟ้าแลบเป็นเส้นแตกกิ่ง
    random.seed(51)
    bolts = Image.new("RGBA", img.size, (0, 0, 0, 0))
    db = ImageDraw.Draw(bolts)
    for i in range(3):
        x = w * (0.3 + 0.25 * i) + random.uniform(-60, 60)
        y = 0
        while y < gy * 0.7:
            nx = x + random.uniform(-40, 40); ny = y + random.uniform(40, 90)
            db.line([(x, y), (nx, ny)], fill=(200, 220, 255, 120), width=4)
            if random.random() < 0.4:
                db.line([(nx, ny), (nx + random.uniform(-70, 70), ny + random.uniform(30, 70))], fill=(180, 200, 255, 70), width=2)
            x, y = nx, ny
    img.paste(Image.alpha_composite(img.convert("RGBA"), bolts.filter(ImageFilter.GaussianBlur(2))).convert("RGB"), (0, 0))
    ridge(d, w, h * 0.5, h * 0.13, (24, 24, 34), 52, spikes=True)
    # ต้นไม้ไหม้เกรียม
    random.seed(53)
    for _ in range(14):
        x = random.uniform(0, w); th = random.uniform(90, 200)
        d.line([(x, gy), (x + random.uniform(-14, 14), gy - th)], fill=(14, 13, 18), width=8)
        d.line([(x, gy - th * 0.6), (x + random.uniform(-40, 40), gy - th * 0.9)], fill=(14, 13, 18), width=4)
    glow_dots(img, 18, 0.55, 0.8, (150, 190, 255), 54, 1.5, 3, 6)

MAPS = [
    dict(id="iron_road", size=(2500, 650), draw=draw_iron_road, ground_top=(70, 62, 58), ground=(52, 46, 43),
         sky=[(0.0, (14, 13, 18)), (0.5, (30, 27, 32)), (0.83, (44, 39, 40)), (1.0, (30, 27, 28))]),
    dict(id="nidavellir_town", size=(1800, 650), draw=draw_nidavellir, ground_top=(92, 74, 58), ground=(64, 50, 40),
         sky=[(0.0, (10, 8, 8)), (0.45, (34, 24, 20)), (0.83, (66, 44, 32)), (1.0, (40, 30, 24))]),
    dict(id="ember_mine", size=(2600, 650), draw=draw_ember_mine, ground_top=(96, 52, 32), ground=(58, 32, 22),
         sky=[(0.0, (16, 8, 6)), (0.5, (40, 18, 12)), (0.83, (80, 34, 18)), (1.0, (50, 24, 14))]),
    dict(id="hall_of_silence", size=(2400, 650), draw=draw_hall, ground_top=(58, 62, 78), ground=(38, 41, 54),
         sky=[(0.0, (8, 9, 14)), (0.5, (18, 20, 30)), (0.83, (30, 33, 46)), (1.0, (20, 22, 32))]),
    dict(id="cold_forge", size=(1600, 650), draw=draw_cold_forge, ground_top=(52, 52, 64), ground=(34, 34, 44),
         sky=[(0.0, (8, 8, 12)), (0.5, (16, 16, 24)), (0.83, (30, 30, 42)), (1.0, (20, 20, 28))]),
    dict(id="thunder_scar", size=(1500, 650), draw=draw_thunder, ground_top=(46, 42, 52), ground=(30, 28, 36),
         sky=[(0.0, (10, 10, 20)), (0.4, (22, 22, 40)), (0.83, (38, 36, 52)), (1.0, (24, 23, 34))]),
]

# =========================================================
# ผูกภาพเข้าโหนด Sky ของแมพ + ซ่อน FarLayer / Ground Visual
# =========================================================
def wire(mp):
    path = "scenes/maps/%s.tscn" % mp["id"]
    s = open(path, encoding="utf-8").read()
    if "bg38" in s:
        print("ครบแล้ว", path)
        return
    # ext_resource ของภาพ
    lastext = list(re.finditer(r'^\[ext_resource [^\n]*\]$', s, flags=re.M))[-1]
    line = '\n[ext_resource type="Texture2D" path="res://%s/%s_bg.png" id="bg38"]' % (OUT, mp["id"])
    s = s[:lastext.end()] + line + s[lastext.end():]
    if "load_steps=" in s:
        n = len(re.findall(r"^\[(ext_resource|sub_resource) ", s, flags=re.M)) + 1
        s = re.sub(r"load_steps=\d+", "load_steps=%d" % n, s, count=1)
    iw, ih = mp["size"]
    # Sky: ใส่ texture + uv + สีขาว (★ Polygon2D สีคูณทับภาพ — ต้องขาว ★)
    sky = re.search(r'(\[node name="Sky" type="Polygon2D"[^\n]*\]\n)((?:[^\n]+\n)*?)(polygon = [^\n]+\n)', s)
    body = sky.group(2)
    body = re.sub(r"^color = [^\n]*\n", "", body, flags=re.M)
    body += 'color = Color(1, 1, 1, 1)\ntexture = ExtResource("bg38")\n'
    poly = sky.group(3)
    uv = "uv = PackedVector2Array(0, 0, %d, 0, %d, %d, 0, %d)\n" % (iw, iw, ih, ih)
    s = s[:sky.start()] + sky.group(1) + body + poly + uv + s[sky.end():]
    # ซ่อน FarLayer กับ Visual ของพื้น (ภาพวาดรวมไว้แล้ว)
    for pat in [r'(\[node name="FarLayer" type="Polygon2D"[^\n]*\]\n)', r'(\[node name="Visual" type="Polygon2D" parent="Terrain/Ground"[^\n]*\]\n)']:
        m = re.search(pat, s)
        if m and "visible = false" not in s[m.end():m.end() + 40]:
            s = s[:m.end()] + "visible = false\n" + s[m.end():]
    bak = path.replace(".tscn", "_ก่อนใส่ฉากหลัง38.tscn.bak")
    if not os.path.exists(bak):
        shutil.copy(path, bak)
    open(path, "w", encoding="utf-8").write(s)
    print("แก้", path)

def main():
    os.makedirs(OUT, exist_ok=True)
    for mp in MAPS:
        p = "%s/%s_bg.png" % (OUT, mp["id"])
        if not os.path.exists(p):
            paint(mp).save(p)
            print("วาด", p)
        wire(mp)
    print("★ เปิด Godot ใหม่แล้วกด F5 ★")

if __name__ == "__main__":
    main()
