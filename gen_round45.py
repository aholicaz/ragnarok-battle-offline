#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 45 — ไอเทมใหม่ 3 ชิ้น + ร้านของนักบวชสูงสุดวาลเดอร์ (รันซ้ำได้ · รันในโฟลเดอร์โปรเจกต์ ปิด Godot ก่อน)

  reset_skill       สมุดลืมสกิล      100,000 z  ใช้แล้วรีเซ็ตสกิลทั้งหมด คืนแต้มสกิล
  reset_stat        น้ำแห่งการเกิดใหม่ 100,000 z  ใช้แล้วรีเซ็ตสเตตัสทั้งหมด คืนแต้มสเตตัส
  thunder_blessing  พรแห่งสายฟ้า       1,500 z  ความเร็วโจมตี +10% นาน 3 นาที
"""
import os, re, sys, shutil
ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else '.')
os.chdir(ROOT)
ICON_DIR = "Sprites/items/placeholder"
LOG = []

ITEMS = [
    dict(id="reset_skill", name="สมุดลืมสกิล", code="RS", color=(120, 80, 200, 255),
         desc="คัมภีร์ต้องห้ามของนักบวช อ่านแล้วลืมวิชาทั้งหมด\nรีเซ็ตสกิลทุกอย่าง คืนแต้มสกิลให้ครบ",
         buy=100000, sell=1000, extra='special_effect = &"reset_skills"\nmax_stack = 10'),
    dict(id="reset_stat", name="น้ำแห่งการเกิดใหม่", code="RE", color=(60, 160, 200, 255),
         desc="น้ำศักดิ์สิทธิ์จากศิลาสลักแห่งธอร์ ดื่มแล้วร่างกายกลับสู่จุดเริ่มต้น\nรีเซ็ตสเตตัสทุกอย่าง คืนแต้มสเตตัสให้ครบ",
         buy=100000, sell=1000, extra='special_effect = &"reset_stats"\nmax_stack = 10'),
    dict(id="thunder_blessing", name="พรแห่งสายฟ้า", code="TB", color=(230, 190, 40, 255),
         desc="พรจากนักบวชสูงสุด สายฟ้าเข้าสิงมือที่ถือดาบ\nความเร็วโจมตี +10% นาน 3 นาที",
         buy=1500, sell=300, extra='buff_values = {\n"aspd_percent": 10.0\n}\nbuff_duration = 180.0\nmax_stack = 30'),
]
VALDER_SHOP = ["thunder_blessing", "reset_skill", "reset_stat"]


def make_icon(item_id, code, color):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return
    os.makedirs(ICON_DIR, exist_ok=True)
    p = os.path.join(ICON_DIR, item_id + ".png")
    if os.path.exists(p):
        return
    S = 256
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((12, 12, S - 12, S - 12), radius=48, fill=color, outline=(20, 16, 12, 255), width=10)
    d.rounded_rectangle((36, 36, S - 36, 100), radius=30, fill=(255, 255, 255, 60))
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 104)
    except Exception:
        font = ImageFont.load_default()
    bbox = d.textbbox((0, 0), code, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text(((S - tw) / 2 - bbox[0], (S - th) / 2 - bbox[1] + 8), code, font=font,
           fill=(255, 255, 255, 255), stroke_width=8, stroke_fill=(20, 16, 12, 255))
    im.save(p)
    LOG.append("ไอคอน " + p)


for it in ITEMS:
    make_icon(it["id"], it["code"], it["color"])
    path = "data/items/%s.tres" % it["id"]
    if os.path.exists(path):
        continue
    txt = ('[gd_resource type="Resource" script_class="ItemData" load_steps=3 format=3]\n\n'
           '[ext_resource type="Texture2D" path="res://%s/%s.png" id="2_icon"]\n'
           '[ext_resource type="Script" path="res://scripts/resources/item_data.gd" id="1_item"]\n\n'
           '[resource]\nscript = ExtResource("1_item")\nid = &"%s"\ndisplay_name = "%s"\ndescription = "%s"\n'
           'icon = ExtResource("2_icon")\ntype = 0\nbuy_price = %d\nsell_price = %d\n%s\n'
           % (ICON_DIR, it["id"], it["id"], it["name"], it["desc"], it["buy"], it["sell"], it["extra"]))
    open(path, "w", encoding="utf-8").write(txt)
    LOG.append("ไอเทม " + path)

# ---- วาลเดอร์: ร้าน ----
p = "scenes/maps/prontera_town.tscn"
s = open(p, encoding="utf-8").read()
m = re.search(r'(\[node name="[^"]+" parent="NPCs"[^\n]*\]\n(?:[^\n\[][^\n]*\n)*?npc_name = "นักบวชสูงสุดวาลเดอร์"\n)', s)
if m is None:
    raise SystemExit("ไม่พบโหนดวาลเดอร์ใน prontera_town.tscn")
# หาขอบเขตของโหนด (ถึงบรรทัดว่างก่อน [node ถัดไป)
start = m.start()
end = s.find("\n[node ", m.end())
if end < 0:
    end = len(s)
block = s[start:end]
if "has_shop = true" not in block:
    bak = p.replace(".tscn", "_ก่อนรอบ45.tscn.bak")
    if not os.path.exists(bak):
        shutil.copy(p, bak)
    # ตัด shop_items / has_shop เดิม (ถ้ามี) — ระวังค่าหลายบรรทัดใน dialog_by_flag: ใส่ต่อท้ายบล็อกแทน
    block = re.sub(r'^shop_items = [^\n]*\n', '', block, flags=re.M)
    block = re.sub(r'^has_shop = [^\n]*\n', '', block, flags=re.M)
    block = re.sub(r'^greeting = [^\n]*\n', '', block, flags=re.M)
    block = block.rstrip("\n") + '\nhas_shop = true\ngreeting = "เจ้ามาหาข้าด้วยเรื่องใด ลูกเอ๋ย"\n' \
        + 'shop_items = Array[StringName]([%s])\n' % ", ".join('&"%s"' % x for x in VALDER_SHOP)
    s = s[:start] + block + s[end:]
    open(p, "w", encoding="utf-8").write(s)
    LOG.append("วาลเดอร์: has_shop + ร้าน " + ", ".join(VALDER_SHOP))

for l in LOG:
    print("  +", l)
if not LOG:
    print("  = ทำครบแล้ว")
