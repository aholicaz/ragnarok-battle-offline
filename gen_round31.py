# -*- coding: utf-8 -*-
## ★ รอบ 31 — ไอเทมขยะเฉพาะตัว · ของสวมใส่ 29 ชิ้น · มอนบท 2 (7 ตัว + บอส) · แมพบท 2 (5 แมพ) ★
##
## รันได้ซ้ำ ไม่พัง:
##   - ไฟล์ .tres/.tscn ใหม่ = สร้างเฉพาะที่ยังไม่มี (ไม่ทับของที่ผู้ใช้แก้แล้ว)
##   - ไฟล์เดิม (มอน 12 ตัว · ร้านโทนี่ · dark_forest · game.gd) = แก้เฉพาะจุด เช็คก่อนทุกครั้ง
##   - ไอคอนชั่วคราว = สร้างเฉพาะตอนมี PIL (บนคลาวด์) — เครื่องผู้ใช้ได้ไฟล์ png มากับ zip แล้ว
##
## ★ ปิด Godot ก่อนรัน ★
import os, re, shutil, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
os.chdir(ROOT)
LOG = []

def w(path, text, overwrite=False):
    """เขียนไฟล์ใหม่ — ถ้ามีอยู่แล้วและไม่สั่ง overwrite จะข้าม"""
    if os.path.exists(path) and not overwrite:
        return False
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    open(path, "w", encoding="utf-8").write(text)
    LOG.append("สร้าง " + path)
    return True

def backup(path, tag):
    base, ext = os.path.splitext(path)
    bak = "%s_ก่อน%s%s.bak" % (base, tag, ext)
    if not os.path.exists(bak):
        shutil.copy(path, bak)

def patch(path, pairs, tag="รอบ31", markers=()):
    """pairs = [(เดิม, ใหม่)] · markers = ข้อความที่ถ้ามีอยู่แล้วแปลว่าแก้ไปแล้ว (กันแทรกซ้ำ)"""
    s = open(path, encoding="utf-8").read()
    hits = 0
    for i, (old, new) in enumerate(pairs):
        if new in s:
            continue
        if i < len(markers) and markers[i] and markers[i] in s:
            continue
        if old not in s:
            print("  ! ไม่เจอใน %s: %s" % (path, old[:60].replace("\n", "|")))
            continue
        s = s.replace(old, new, 1)
        hits += 1
    if hits:
        backup(path, tag)
        open(path, "w", encoding="utf-8").write(s)
        LOG.append("แก้ %s (%d จุด)" % (path, hits))

ITEM_SCRIPT = '[ext_resource type="Script" path="res://scripts/resources/item_data.gd" id="1_item"]'
ICON_DIR = "Sprites/items/placeholder"

# =========================================================
# 0) ไอคอนชั่วคราว (สร้างด้วย PIL เฉพาะบนคลาวด์)
# =========================================================
ICON_JOBS = []   # (id, ตัวอักษร, สี)

def icon_line(item_id):
    return '[ext_resource type="Texture2D" path="res://%s/%s.png" id="2_icon"]' % (ICON_DIR, item_id)

def make_icons():
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return
    os.makedirs(ICON_DIR, exist_ok=True)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 26)
    except Exception:
        font = ImageFont.load_default()
    n = 0
    for item_id, code, color in ICON_JOBS:
        p = os.path.join(ICON_DIR, item_id + ".png")
        if os.path.exists(p):
            continue
        im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle((3, 3, 60, 60), radius=12, fill=color, outline=(20, 16, 12, 255), width=3)
        d.rounded_rectangle((9, 9, 54, 26), radius=8, fill=(255, 255, 255, 60))
        bbox = d.textbbox((0, 0), code, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        d.text(((64 - tw) / 2 - bbox[0], (64 - th) / 2 - bbox[1] + 2), code, font=font,
               fill=(255, 255, 255, 255), stroke_width=2, stroke_fill=(20, 16, 12, 255))
        im.save(p)
        n += 1
    if n:
        LOG.append("สร้างไอคอนชั่วคราว %d รูปใน %s" % (n, ICON_DIR))

COLOR = {
    "junk":   (139, 110, 78, 255),
    "junk2":  (96, 120, 140, 255),
    "weapon": (178, 52, 52, 255),
    "shield": (70, 96, 150, 255),
    "head":   (150, 110, 50, 255),
    "armor":  (60, 110, 90, 255),
    "cloak":  (110, 70, 130, 255),
    "shoes":  (100, 80, 60, 255),
    "acc":    (190, 150, 40, 255),
    "card":   (40, 40, 60, 255),
}

# =========================================================
# 1) ไอเทมขยะ / วัตถุดิบ (type 3 MATERIAL)
# =========================================================
def junk_tres(item_id, name, desc, sell, code, tint="junk"):
    ICON_JOBS.append((item_id, code, COLOR[tint]))
    return '''[gd_resource type="Resource" script_class="ItemData" load_steps=3 format=3]

%s
%s

[resource]
script = ExtResource("1_item")
id = &"%s"
display_name = "%s"
description = "%s"
icon = ExtResource("2_icon")
type = 3
buy_price = %d
sell_price = %d
''' % (ITEM_SCRIPT, icon_line(item_id), item_id, name, desc, sell * 3, sell)

# (id, ชื่อ, คำอธิบาย, ราคาขาย, รหัสบนไอคอน, มอน, โอกาส%, max_count)
JUNK = [
    # ---- บท 1 ----
    ("poring_core",        "แกนวุ้นโพริง",     "ก้อนวุ้นใสตรงกลางตัวโพริง นาน ๆ ถึงจะเจอสักที",        40,  "PC", "poring",       8,  1),
    ("fabre_silk",         "ใยแฟเบร",           "ใยเหนียว ๆ ที่แฟเบรใช้พันตัว ช่างทอชอบซื้อ",             9,   "FS", "fabre",        35, 2),
    ("feeler",             "หนวดแมลง",          "หนวดยาวสองเส้น ยังกระดิกได้นิด ๆ",                       12,  "FE", "fabre",        15, 1),
    ("lunatic_tail",       "หางกระต่ายขาว",     "หางฟูนุ่ม เชื่อกันว่านำโชค",                            14,  "LT", "lunatic",      30, 1),
    ("chewed_carrot",      "แครอทกัดครึ่ง",     "ลูนาติกกัดทิ้งไว้ ยังกินได้ถ้าไม่รังเกียจ",              8,   "CR", "lunatic",      20, 2),
    ("orange_jelly",       "วุ้นสีส้ม",         "วุ้นของดรอปส์ อุ่นนิด ๆ เหมือนโดนแดด",                    10,  "OJ", "drops",        45, 2),
    ("sun_dew",            "หยดน้ำค้างแสง",     "หยดน้ำใสที่เรืองแสงจาง ๆ นักบวชซื้อไปใช้ในพิธี",         45,  "SD", "drops",        10, 1),
    ("insect_wing",        "ปีกแมลงใส",         "ปีกบางใสของชอนชอน ส่องแดดแล้วเห็นเป็นสีรุ้ง",           16,  "IW", "chonchon",     40, 2),
    ("chonchon_eye",       "ตาโปนชอนชอน",       "ลูกตากลมโต... ยังจ้องอยู่",                              60,  "CE", "chonchon",     8,  1),
    ("stinger",            "เหล็กใน",           "เหล็กในของฮอร์เน็ต แหลมและมีพิษอ่อน ๆ",                 22,  "ST", "hornet",       35, 1),
    ("honey_drop",         "หยดน้ำผึ้ง",        "น้ำผึ้งป่าหวานจัด กินแล้วสดชื่นเล็กน้อย",               35,  "HD", "hornet",       15, 1),
    ("wolf_fang",          "เขี้ยวหมาป่า",      "เขี้ยวแหลมคม เอาไปทำจี้ห้อยคอได้",                       45,  "WF", "wolf",         30, 1),
    ("wolf_claw",          "กรงเล็บหมาป่า",     "กรงเล็บใหญ่ มีรอยดินติดอยู่",                            60,  "WC", "wolf",         15, 2),
    ("royal_jelly",        "วุ้นราชา",          "วุ้นสีทองจากคิงโพริง เหนียวและหนักกว่าปกติ",             150, "RJ", "king_poring",  80, 2),
    ("tiny_crown",         "มงกุฎจิ๋ว",         "มงกุฎเล็ก ๆ ของคิงโพริง ทำจากอะไรก็ไม่รู้แต่แวววาว",     900, "TC", "king_poring",  25, 1),
    ("old_hairpin",        "ปิ่นปักผมเก่า",     "ปิ่นปักผมลายดอกไม้ เจ้าของคงจากไปนานแล้ว",              120, "HP", "munak",        25, 1),
    ("burial_cloth",       "ผ้าห่อศพเก่า",      "ผ้าเก่าคร่ำคร่า มีกลิ่นดินอับ ๆ",                        55,  "BC", "munak",        30, 2),
    ("broken_axe_blade",   "ใบขวานหัก",         "ใบขวานของออร์คที่หักครึ่ง เหล็กยังดีอยู่ หลอมใหม่ได้",   140, "AX", "orc_warrior",  30, 1),
    ("orc_bandana",        "ผ้าโพกหัวออร์ค",    "ผ้าโพกหัวลายเผ่า เหงื่อยังไม่แห้ง",                     220, "OB", "orc_warrior",  12, 1),
    ("small_horn",         "เขาเล็กปีศาจ",      "เขาเล็ก ๆ ของบาฟโฟเมทจูเนียร์ ร้อนนิด ๆ เวลาจับ",       260, "SH", "baphomet_jr",  40, 1),
    ("imp_tail",           "หางปีศาจน้อย",      "หางปลายแหลม ยังสะบัดได้เอง",                            380, "IT", "baphomet_jr",  15, 1),
    ("giant_hoof",         "กีบเท้ายักษ์",      "กีบเท้าของบาฟโฟเมท หนักเท่าก้อนหิน",                    2500, "GH", "baphomet",    100, 1),
    ("cursed_scythe_shard", "เศษเคียวต้องสาป",  "เศษใบเคียวสีดำ ใครถือนานจะรู้สึกหนาว",                  6000, "CS", "baphomet",    50, 1),
    # ---- บท 2 ----
    ("mole_claw",          "กรงเล็บขุดดิน",     "กรงเล็บแบนกว้างของพิตแมน ขุดหินได้",                     70,  "MC", "pitman",       40, 2),
    ("dirt_clump",         "ก้อนดินอัด",        "ดินอัดแน่นจากใต้ดิน มีเศษแร่ปน",                        20,  "DC", "pitman",       30, 3),
    ("steel_shell",        "เปลือกเหล็กด้วง",   "เปลือกแข็งเหมือนเหล็ก ช่างตีเหล็กต้องการ",              160, "SS", "steel_beetle", 35, 1),
    ("beetle_horn",        "เขาด้วงเหล็ก",      "เขาโค้งแข็งแรง เอาไปทำด้ามอาวุธได้",                     240, "BH", "steel_beetle", 12, 1),
    ("ember_wing",         "ปีกถ่านไฟ",         "ปีกค้างคาวที่ยังมีประกายไฟคุอยู่",                       130, "EW", "ember_bat",    40, 2),
    ("bat_fang",           "เขี้ยวค้างคาว",     "เขี้ยวเล็กแหลม มีรอยไหม้",                               90,  "BF", "ember_bat",    20, 1),
    ("magma_core",         "แกนลาวา",           "ก้อนหินร้อนแดงจากตัวทากลาวา ยังอุ่นอยู่หลายวัน",        420, "MG", "magma_slug",   12, 1),
    ("slug_slime",         "เมือกร้อน",         "เมือกเหนียวร้อนจัด ห้ามจับมือเปล่า",                     60,  "SL", "magma_slug",   45, 2),
    ("golem_plate",        "แผ่นเกราะโกเลม",    "แผ่นโลหะจากตัวโกเลม มีรอยสลักรูนจาง ๆ",                 350, "GP", "forge_golem",  30, 1),
    ("hot_gear",           "เฟืองร้อน",         "เฟืองเหล็กที่ยังหมุนได้เอง ใครสร้างมันขึ้นมา?",          280, "HG", "forge_golem",  20, 1),
    ("silent_veil",        "ผ้าคลุมไร้เสียง",   "ผ้าบางสีเทา ห่มแล้วเสียงฝีเท้าหายไป",                    500, "SV", "silent_wraith", 25, 1),
    ("wraith_dust",        "ผงภูตเรือง",        "ผงเรืองแสงสีน้ำเงินจาง ๆ",                               140, "WD", "silent_wraith", 40, 2),
    ("broken_rune",        "รูนแตก",            "แผ่นหินสลักรูนที่แตกครึ่ง อ่านไม่ออกแล้ว",               600, "BR", "rune_watcher", 40, 1),
    ("watcher_lens",       "เลนส์ผู้เฝ้า",      "เลนส์แก้วใสจากดวงตาผู้เฝ้ารูน มองผ่านแล้วเห็นรูนเรือง", 1500, "WL", "rune_watcher", 10, 1),
    ("guardian_core",      "แกนผู้พิทักษ์",     "แกนพลังงานของผู้พิทักษ์เตาหลอม ยังเต้นตุบ ๆ",           8000, "GC", "forge_guardian", 100, 1),
]

# =========================================================
# 2) ของสวมใส่ 29 ชิ้น
# =========================================================
def equip_tres(e):
    lines = [
        '[gd_resource type="Resource" script_class="ItemData" load_steps=3 format=3]', '',
        ITEM_SCRIPT, icon_line(e["id"]), '', '[resource]', 'script = ExtResource("1_item")',
        'id = &"%s"' % e["id"], 'display_name = "%s"' % e["name"], 'description = "%s"' % e["desc"],
        'icon = ExtResource("2_icon")',
    ]
    if e["lv"] > 1:
        lines.append("required_level = %d" % e["lv"])
    lines.append("type = %d" % e["type"])
    lines.append("slot = %d" % e["slot"])
    if e["slot"] == 1:
        lines.append('weapon_type = &"sword"')
        lines.append('attack_animation = &"Attack_Blade"')
    lines.append("card_slots = %d" % e.get("cards", 1))
    lines.append("max_stack = 1")
    lines.append("buy_price = %d" % e["buy"])
    lines.append("sell_price = %d" % (e["buy"] * 2 // 5))
    for k in ["atk", "matk", "def", "mdef", "hit", "flee", "crit", "max_hp", "max_sp",
              "bonus_str", "bonus_agi", "bonus_vit", "bonus_int", "bonus_dex", "bonus_luk"]:
        if e.get(k):
            lines.append("%s = %d" % (k, e[k]))
    if e.get("aspd"):
        lines.append("aspd_percent = %.1f" % e["aspd"])
    if e["slot"] in (1, 2, 3, 4, 5, 6):
        lines.append("refinable = true")
        if e["slot"] == 1:
            lines.append("refine_atk_per_level = %d" % e.get("ref", 3))
    return "\n".join(lines) + "\n"

def E(id, name, desc, slot, lv, buy, tint, code, **st):
    d = {"id": id, "name": name, "desc": desc, "slot": slot, "lv": lv, "buy": buy,
         "type": 1 if slot == 1 else 2}
    d.update(st)
    ICON_JOBS.append((id, code, COLOR[tint]))
    return d

EQUIP = [
    # ---- อาวุธ (slot 1) ----
    E("wooden_sword", "ดาบไม้", "ดาบไม้ฝึกหัด เบาแต่ไม่ค่อยคม", 1, 1, 120, "weapon", "WS", atk=14, ref=1),
    E("short_sword", "ดาบสั้น", "ดาบสั้นใบตรง ควงง่าย", 1, 4, 900, "weapon", "SS", atk=30, ref=2),
    E("rapier", "เรเปียร์", "ดาบเรียวปลายแหลม แทงแม่นและเข้าจุดตาย", 1, 8, 1800, "weapon", "RP", atk=34, hit=8, crit=3, ref=2),
    E("bastard_sword", "ดาบบาสตาร์ด", "ดาบยาวถือได้ทั้งมือเดียวและสองมือ หนักหน่วง", 1, 18, 9500, "weapon", "BS", atk=46, aspd=-4.0),
    E("iron_blade", "ใบมีดเหล็กคนแคระ", "ดาบเหล็กจากใต้ภูเขา หนา ทื่อแต่ทนทาน", 1, 22, 14000, "weapon", "IB", atk=50, **{"def": 3}),
    E("forge_saber", "ดาบเตาหลอม", "ดาบที่ตีในเตาหลอมนิดาเวลลิร์ ใบดาบยังอุ่นอยู่", 1, 30, 32000, "weapon", "FS", atk=72, bonus_str=2, ref=4),
    E("runic_blade", "ดาบรูน", "ดาบสลักรูนโบราณ เรืองแสงจาง ๆ ตอนกลางคืน", 1, 36, 60000, "weapon", "RB", atk=94, matk=20, bonus_int=2, ref=4),
    # ---- โล่ (slot 2) ----
    E("wooden_shield", "โล่ไม้", "โล่ไม้กลม กันได้บ้าง", 2, 1, 150, "shield", "WD", **{"def": 4}),
    E("iron_shield", "โล่เหล็ก", "โล่เหล็กหนัก กันแรงกระแทกได้ดี", 2, 20, 7500, "shield", "IS", max_hp=60, **{"def": 22}),
    E("mirror_shield", "โล่กระจก", "โล่ขัดเงาจนสะท้อนภาพได้ สะท้อนเวทได้บางส่วน", 2, 32, 21000, "shield", "MS", mdef=8, **{"def": 26}),
    # ---- หมวก (slot 3) ----
    E("ribbon", "ริบบิ้น", "ริบบิ้นผูกผมสีสด", 3, 1, 250, "head", "RI", bonus_int=1, **{"def": 1}),
    E("leather_cap", "หมวกหนัง", "หมวกหนังสัตว์ นุ่มและทน", 3, 6, 1200, "head", "LC", **{"def": 7}),
    E("iron_helm", "หมวกเหล็ก", "หมวกเหล็กครอบหัว หนักแต่อุ่นใจ", 3, 18, 5200, "head", "IH", max_hp=40, **{"def": 11}),
    E("miner_helmet", "หมวกนักขุด", "หมวกของคนงานเหมืองคนแคระ มีตะเกียงเล็ก ๆ ติดอยู่", 3, 24, 8800, "head", "MH", bonus_vit=1, **{"def": 13}),
    # ---- เกราะ (slot 4) ----
    E("leather_jacket", "เสื้อหนัง", "เสื้อหนังหนา กันรอยข่วนได้", 4, 8, 1600, "armor", "LJ", **{"def": 10}),
    E("chain_mail", "เกราะโซ่", "เกราะถักจากห่วงเหล็ก คล่องตัวกว่าเกราะเพลท", 4, 18, 7800, "armor", "CM", max_hp=80, **{"def": 20}),
    E("scale_mail", "เกราะเกล็ด", "เกราะเกล็ดเหล็กซ้อนกัน หนักขึ้นมาหน่อย", 4, 26, 14500, "armor", "SM", max_hp=110, aspd=-3.0, **{"def": 26}),
    E("dwarven_mail", "เกราะคนแคระ", "เกราะเหล็กตีโดยช่างคนแคระ แน่นหนาเหมือนกำแพง", 4, 34, 38000, "armor", "DM", max_hp=200, bonus_str=1, aspd=-6.0, **{"def": 36}),
    # ---- ผ้าคลุม (slot 5) ----
    E("muffler", "ผ้าพันคอ", "ผ้าพันคอขนสัตว์ อุ่นและเบา", 5, 10, 2200, "cloak", "MF", flee=4, **{"def": 5}),
    E("wolf_cloak", "ผ้าคลุมหนังหมาป่า", "ผ้าคลุมจากหนังหมาป่า ทำให้เคลื่อนไหวเงียบขึ้น", 5, 15, 5600, "cloak", "WK", flee=7, **{"def": 6}),
    E("ember_cape", "ผ้าคลุมถ่านไฟ", "ผ้าคลุมทอจากใยทนไฟ ขอบยังมีประกายแดง", 5, 28, 16000, "cloak", "EC", mdef=6, flee=4, **{"def": 8}),
    # ---- รองเท้า (slot 6) ----
    E("leather_shoes", "รองเท้าหนัง", "รองเท้าหนังพื้นหนา เดินไกลไม่เมื่อย", 6, 6, 1100, "shoes", "LS", max_hp=40, **{"def": 5}),
    E("iron_greaves", "สนับแข้งเหล็ก", "แผ่นเหล็กหุ้มหน้าแข้ง", 6, 22, 8200, "shoes", "IG", max_hp=100, **{"def": 10}),
    E("miner_boots", "รองเท้านักขุด", "รองเท้าบูทหนังหนาของคนงานเหมือง เหยียบหินร้อนได้", 6, 26, 12500, "shoes", "MB", bonus_vit=2, **{"def": 11}),
    # ---- เครื่องประดับ (slot 7) ----
    E("necklace", "สร้อยคอ", "สร้อยคอเงินเส้นเล็ก", 7, 12, 9500, "acc", "NK", bonus_vit=2, max_hp=50, cards=0),
    E("earring", "ต่างหู", "ต่างหูหยกเขียว", 7, 12, 9500, "acc", "ER", bonus_int=2, max_sp=30, cards=0),
    E("brooch", "เข็มกลัด", "เข็มกลัดรูปปีก", 7, 12, 9500, "acc", "BR", bonus_agi=2, flee=3, cards=0),
    E("rosary", "ลูกประคำ", "ลูกประคำของนักบวช ป้องกันเวทร้าย", 7, 20, 15000, "acc", "RS", mdef=5, bonus_luk=2, cards=0),
    E("belt", "เข็มขัดหนัง", "เข็มขัดหนังหนาหัวเหล็ก", 7, 24, 18000, "acc", "BT", bonus_vit=2, cards=0, **{"def": 3}),
]

# =========================================================
# 3) มอนบท 2 (7 ตัว + บอส 1) — สไปรท์ชั่วคราว รอผู้ใช้วาด
# =========================================================
# element: NEUTRAL0 FIRE1 WATER2 EARTH3 WIND4 POISON5 HOLY6 SHADOW7 GHOST8 UNDEAD9
# race: FORMLESS0 UNDEAD1 BRUTE2 PLANT3 INSECT4 FISH5 DEMON6 DEMIHUMAN7 · size S0 M1 L2 · ai PASSIVE0 AGGR1 STAT2
MON = [
    dict(id="pitman", name="พิตแมน", lv=19, hp=700, atk=(72, 98), df=16, mdef=4, hit=34, flee=18, crit=2,
         el=3, race=2, size=0, ai=0, spd=95, exp=300, zeny=(100, 190), h=150, hb=(30, 30),
         color=(120, 85, 50), code="PM", card=dict(slot=1, atk=8, bonus_str=1, r=2, txt="พลังขุดจากใต้ดิน ทำให้โจมตีหนักขึ้น"),
         extra=[("iron_ore", 25, 2), ("red_potion", 5, 1)]),
    dict(id="steel_beetle", name="ด้วงเหล็ก", lv=22, hp=900, atk=(80, 110), df=30, mdef=8, hit=36, flee=12, crit=1,
         el=3, race=4, size=1, ai=0, spd=80, exp=400, zeny=(130, 240), h=160, hb=(40, 34),
         color=(90, 100, 110), code="SB", card=dict(slot=4, df=8, max_hp=60, r=2, txt="เปลือกแข็งดั่งเหล็ก"),
         extra=[("iron_ore", 40, 3), ("iron_shield", 1, 1)]),
    dict(id="ember_bat", name="ค้างคาวถ่านไฟ", lv=25, hp=820, atk=(100, 140), df=12, mdef=14, hit=44, flee=38, crit=4,
         el=1, race=2, size=0, ai=1, spd=170, exp=520, zeny=(150, 280), h=140, hb=(34, 30), jump=-360,
         color=(160, 60, 30), code="EB", card=dict(slot=5, flee=8, pct={"move_speed_percent": 5.0}, r=3, txt="บินเร็วราวประกายไฟ"),
         extra=[("orange_potion", 8, 1), ("ember_cape", 1.5, 1)]),
    dict(id="magma_slug", name="ทากลาวา", lv=27, hp=1300, atk=(110, 150), df=26, mdef=20, hit=42, flee=8, crit=1,
         el=1, race=0, size=1, ai=0, spd=60, exp=640, zeny=(170, 320), h=150, hb=(46, 30),
         color=(200, 70, 20), code="MS", card=dict(slot=6, max_hp=120, mdef=3, r=3, txt="ร่างที่ร้อนดั่งลาวา"),
         extra=[("phracon", 10, 1), ("orange_potion", 10, 1)]),
    dict(id="forge_golem", name="โกเลมเตาหลอม", lv=30, hp=2400, atk=(150, 210), df=40, mdef=12, hit=48, flee=5, crit=1,
         el=3, race=0, size=2, ai=1, spd=70, exp=950, zeny=(250, 450), h=240, hb=(60, 64), kb=260,
         color=(110, 90, 70), code="FG", card=dict(slot=2, df=12, pct={"def_percent": 5.0}, r=3, txt="กำแพงที่เดินได้"),
         extra=[("iron_ore", 50, 4), ("emveretarcon", 12, 1), ("chain_mail", 1.5, 1)]),
    dict(id="silent_wraith", name="ภูตไร้เสียง", lv=33, hp=1600, atk=(140, 190), df=18, mdef=35, hit=58, flee=48, crit=6,
         el=7, race=6, size=1, ai=1, spd=150, exp=1100, zeny=(280, 500), h=190, hb=(36, 50),
         color=(70, 80, 120), code="SW", card=dict(slot=7, flee=12, crit=3, r=4, txt="ไร้เสียง ไร้เงา ไร้ร่องรอย"),
         extra=[("blue_potion", 8, 1), ("emveretarcon", 15, 1)]),
    dict(id="rune_watcher", name="ผู้เฝ้ารูน", lv=35, hp=3200, atk=(170, 230), df=30, mdef=30, hit=62, flee=30, crit=3,
         el=0, race=0, size=2, ai=1, spd=90, exp=1600, zeny=(400, 700), h=230, hb=(56, 60), kb=220,
         color=(60, 120, 140), code="RW", card=dict(slot=1, matk=20, pct={"atk_percent": 4.0}, r=4, txt="ดวงตาที่เห็นรูนทุกตัว"),
         extra=[("emveretarcon", 30, 2), ("white_potion", 15, 1), ("runic_blade", 1, 1)],
         skill=dict(name="รูนระเบิด", rng=340, rx=260, ry=160, mult=2.0, windup=0.8, dur=0.7)),
    dict(id="forge_guardian", name="ผู้พิทักษ์เตาหลอม", lv=38, hp=9000, atk=(210, 290), df=45, mdef=25, hit=70, flee=20, crit=2,
         el=1, race=0, size=2, ai=1, spd=85, exp=6000, zeny=(2000, 3500), h=320, hb=(80, 90), kb=320, boss="ผู้พิทักษ์เตาหลอม",
         color=(180, 110, 40), code="GD", card=dict(slot=4, df=10, pct={"max_hp_percent": 8.0}, r=5, txt="หัวใจของเตาหลอมโบราณ"),
         extra=[("white_potion", 100, 2), ("emveretarcon", 100, 3), ("dwarven_mail", 10, 1), ("mirror_shield", 15, 1), ("forge_saber", 12, 1)],
         skill=dict(name="ค้อนเตาหลอม", rng=380, rx=340, ry=200, mult=2.4, windup=0.9, dur=0.9)),
]

def monster_tres(m):
    junks = [j for j in JUNK if j[5] == m["id"]]
    subs, refs = [], []
    n = 0
    for (jid, _n, _d, _s, _c, _m, chance, maxc) in junks:
        subs.append('[sub_resource type="Resource" id="Drop_%s_%d"]\nscript = ExtResource("2_drop")\nitem_id = &"%s"\nchance = %.1f\n%s'
                    % (m["id"], n, jid, chance, ("max_count = %d\n" % maxc) if maxc > 1 else ""))
        refs.append('SubResource("Drop_%s_%d")' % (m["id"], n)); n += 1
    for (iid, chance, maxc) in m.get("extra", []):
        subs.append('[sub_resource type="Resource" id="Drop_%s_%d"]\nscript = ExtResource("2_drop")\nitem_id = &"%s"\nchance = %.1f\n%s'
                    % (m["id"], n, iid, chance, ("max_count = %d\n" % maxc) if maxc > 1 else ""))
        refs.append('SubResource("Drop_%s_%d")' % (m["id"], n)); n += 1
    subs.append('[sub_resource type="Resource" id="Drop_%s_card"]\nscript = ExtResource("2_drop")\nitem_id = &"card_%s"\nchance = 5.0\n' % (m["id"], m["id"]))
    refs.append('SubResource("Drop_%s_card")' % m["id"])

    body = [
        'script = ExtResource("1_monster")',
        'sprite_frames = ExtResource("3_frames")',
        'id = &"%s"' % m["id"], 'display_name = "%s"' % m["name"],
        'hitbox_size = Vector2(%d, %d)' % m["hb"],
        'hp_bar_offset_y = %.1f' % (-(m["h"] * 0.38)),
        'display_height = %.1f' % m["h"],
        'level = %d' % m["lv"], 'max_hp = %d' % m["hp"],
        'atk_min = %d' % m["atk"][0], 'atk_max = %d' % m["atk"][1],
        'def = %d' % m["df"], 'mdef = %d' % m["mdef"], 'hit = %d' % m["hit"], 'flee = %d' % m["flee"], 'crit = %d' % m["crit"],
        'element = %d' % m["el"], 'race = %d' % m["race"], 'size = %d' % m["size"], 'ai_type = %d' % m["ai"],
        'move_speed = %.1f' % m["spd"],
        'jump_force = %.1f' % m.get("jump", -280),
        'jump_while_chasing = %s' % ("true" if m.get("jump") else "false"),
        'detect_range = %.1f' % (420 if m["ai"] == 1 else 250),
        'attack_range = %.1f' % (70 + m["hb"][0]),
        'leash_range = 750.0', 'wander_range = 260.0',
        'hop_while_wandering = %s' % ("true" if m.get("jump") else "false"),
        'attack_windup = 0.4', 'attack_duration = 0.5', 'attack_cooldown = 1.8',
        'knockback_force = %.1f' % m.get("kb", 160),
        'exp_reward = %d' % m["exp"], 'job_exp_reward = %d' % int(m["exp"] * 0.7),
        'zeny_min = %d' % m["zeny"][0], 'zeny_max = %d' % m["zeny"][1],
        'drops = Array[ExtResource("2_drop")]([%s])' % ", ".join(refs),
        'respawn_time = %.1f' % (60.0 if m.get("boss") else 15.0),
    ]
    if m.get("boss"):
        body += ['is_boss = true', 'boss_title = "%s"' % m["boss"]]
    if m.get("skill"):
        sk = m["skill"]
        body += ['skill_name = "%s"' % sk["name"], 'skill_anim = &"Attack"',
                 'skill_range = %.1f' % sk["rng"], 'skill_radius_x = %.1f' % sk["rx"], 'skill_radius_y = %.1f' % sk["ry"],
                 'skill_damage_mult = %.1f' % sk["mult"], 'skill_windup = %.1f' % sk["windup"], 'skill_duration = %.1f' % sk["dur"]]
    return '''[gd_resource type="Resource" script_class="MonsterData" load_steps=%d format=3]

[ext_resource type="Script" path="res://scripts/resources/monster_data.gd" id="1_monster"]
[ext_resource type="Script" path="res://scripts/resources/drop_entry.gd" id="2_drop"]
[ext_resource type="SpriteFrames" path="res://data/sprites/placeholder/%s_frames.tres" id="3_frames"]

%s
[resource]
%s
''' % (4 + len(subs), m["id"], "\n".join(subs), "\n".join(body))

def frames_tres(m):
    """SpriteFrames ชั่วคราว 1 รูป ใช้ทุกท่า — ผู้ใช้วาดจริงแล้วค่อยเปลี่ยนไฟล์นี้"""
    tex = 'ExtResource("1_tex")'
    def anim(name, n, loop, speed):
        fr = ", ".join(['{\n"duration": 1.0,\n"texture": %s\n}' % tex] * n)
        return '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", name, speed)
    return '''[gd_resource type="SpriteFrames" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://Sprites/monsters/placeholder/%s.png" id="1_tex"]

[resource]
animations = [%s]
''' % (m["id"], ", ".join([anim("Idle", 2, True, 4), anim("Attack", 3, False, 8), anim("Hit", 2, False, 6), anim("Die", 3, False, 5)]))

def monster_png(m):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return
    d = "Sprites/monsters/placeholder"
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, m["id"] + ".png")
    if os.path.exists(p):
        return
    hsize = int(m["h"]); wsize = int(m["h"] * 0.8)
    im = Image.new("RGBA", (wsize, hsize), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    c = m["color"] + (255,)
    dr.ellipse((6, int(hsize * 0.18), wsize - 6, hsize - 4), fill=c, outline=(20, 16, 12, 255), width=4)
    dr.ellipse((int(wsize * 0.25), 4, int(wsize * 0.75), int(hsize * 0.45)), fill=c, outline=(20, 16, 12, 255), width=4)
    # ตา 2 ข้าง
    ey = int(hsize * 0.22)
    for ex in (int(wsize * 0.38), int(wsize * 0.62)):
        dr.ellipse((ex - 7, ey - 7, ex + 7, ey + 7), fill=(255, 255, 255, 255))
        dr.ellipse((ex - 3, ey - 3, ex + 3, ey + 3), fill=(0, 0, 0, 255))
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", max(18, hsize // 6))
    except Exception:
        font = ImageFont.load_default()
    bbox = dr.textbbox((0, 0), m["code"], font=font)
    dr.text(((wsize - (bbox[2] - bbox[0])) / 2 - bbox[0], hsize * 0.6 - (bbox[3] - bbox[1]) / 2 - bbox[1]), m["code"],
            font=font, fill=(255, 255, 255, 255), stroke_width=3, stroke_fill=(20, 16, 12, 255))
    im.save(p)
    LOG.append("สร้างสไปรท์ชั่วคราว " + p)

def card_tres(m):
    c = m["card"]
    lines = [
        '[gd_resource type="Resource" script_class="CardData" load_steps=3 format=3]', '',
        '[ext_resource type="Script" path="res://scripts/resources/card_data.gd" id="1_card"]', '',
        '[resource]', 'script = ExtResource("1_card")',
        'monster_id = &"%s"' % m["id"], 'fits_slot = %d' % c["slot"], 'rarity = %d' % c["r"],
        'id = &"card_%s"' % m["id"], 'display_name = "การ์ด%s"' % m["name"],
        'description = "%s"' % c["txt"], 'type = 5', 'slot = 0', 'max_stack = 99',
        'buy_price = 0', 'sell_price = %d' % (m["lv"] * 1500),
    ]
    for k in ["atk", "matk", "flee", "hit", "crit", "max_hp", "mdef", "bonus_str", "bonus_agi", "bonus_vit", "bonus_int", "bonus_luk"]:
        if c.get(k):
            lines.append("%s = %d" % (k, c[k]))
    if c.get("df"):
        lines.append("def = %d" % c["df"])
    if c.get("pct"):
        lines.append("percent_effects = {\n%s\n}" % ",\n".join('"%s": %.1f' % (k, v) for k, v in c["pct"].items()))
    return "\n".join(lines) + "\n"

# =========================================================
# 4) แมพบท 2
# =========================================================
def map_tscn(mp):
    ext = [
        '[ext_resource type="Script" path="res://scripts/world/map_base.gd" id="map_base"]',
        '[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="player"]',
        '[ext_resource type="PackedScene" path="res://scenes/monsters/monster.tscn" id="monster_scene"]',
        '[ext_resource type="Script" path="res://scripts/world/map_spawner.gd" id="map_spawner"]',
        '[ext_resource type="Script" path="res://scripts/world/monster_spawner.gd" id="spawner"]',
        '[ext_resource type="Script" path="res://scripts/resources/monster_data.gd" id="monster_data"]',
        '[ext_resource type="PackedScene" path="res://scenes/world/portal.tscn" id="portal"]',
        '[ext_resource type="PackedScene" path="res://scenes/npc/npc.tscn" id="npc"]',
        '[ext_resource type="PackedScene" path="res://scenes/world/lore_object.tscn" id="lore"]',
    ]
    for mid in mp.get("mons", []) + mp.get("boss", []):
        ext.append('[ext_resource type="Resource" path="res://data/monsters/%s.tres" id="md_%s"]' % (mid, mid))
    W, H = mp["w"], mp["h"]
    gy = mp["ground_y"]            # ขอบบนของพื้น
    sky, far, gnd = mp["colors"]
    subs = ['[sub_resource type="RectangleShape2D" id="Rect_ground"]\nsize = Vector2(%d, 240)' % (W + 400)]
    plats = mp.get("plats", [])
    for i, (px, py, pw) in enumerate(plats):
        subs.append('[sub_resource type="RectangleShape2D" id="Rect_p%d"]\nsize = Vector2(%d, 32)' % (i, pw))
    nodes = [
        '[node name="Map" type="Node2D"]\nscript = ExtResource("map_base")\nmap_id = &"%s"\ndisplay_name = "%s"\nchapter = 2\nregion = "สวาร์ทัลฟ์เฮม"\nmap_bounds = Rect2(-100, -200, %d, %d)\nplayer_scene = ExtResource("player")'
        % (mp["id"], mp["name"], W + 200, H + 200),
        '[node name="Background" type="Node2D" parent="."]',
        '[node name="Sky" type="Polygon2D" parent="Background"]\nz_index = -100\nposition = Vector2(-100, -200)\ncolor = Color(%s, 1)\npolygon = PackedVector2Array(0, 0, %d, 0, %d, %d, 0, %d)'
        % (sky, W + 200, W + 200, H + 200, H + 200),
        '[node name="FarLayer" type="Polygon2D" parent="Background"]\nz_index = -90\nposition = Vector2(-100, %d)\ncolor = Color(%s, 1)\npolygon = PackedVector2Array(0, 0, %d, 0, %d, %d, 0, %d)'
        % (gy - 360, far, W + 200, W + 200, 360, 360),
        '[node name="Art" type="Sprite2D" parent="Background"]\nz_index = -80\nposition = Vector2(%d, %d)' % (W // 2, H // 2),
        '[node name="Terrain" type="Node2D" parent="."]',
        '[node name="Ground" type="StaticBody2D" parent="Terrain"]\nposition = Vector2(%d, %d)\ncollision_layer = 1\ncollision_mask = 0' % (W // 2, gy + 120),
        '[node name="Shape" type="CollisionShape2D" parent="Terrain/Ground"]\nshape = SubResource("Rect_ground")',
        '[node name="Visual" type="Polygon2D" parent="Terrain/Ground"]\ncolor = Color(%s, 1)\npolygon = PackedVector2Array(%d, -120, %d, -120, %d, 120, %d, 120)'
        % (gnd, -(W + 400) // 2, (W + 400) // 2, (W + 400) // 2, -(W + 400) // 2),
    ]
    for i, (px, py, pw) in enumerate(plats):
        nodes.append('[node name="Plat%d" type="StaticBody2D" parent="Terrain"]\nposition = Vector2(%d, %d)\ncollision_layer = 1\ncollision_mask = 0' % (i, px, py))
        nodes.append('[node name="Shape" type="CollisionShape2D" parent="Terrain/Plat%d"]\nshape = SubResource("Rect_p%d")' % (i, i))
        nodes.append('[node name="Visual" type="Polygon2D" parent="Terrain/Plat%d"]\ncolor = Color(%s, 1)\npolygon = PackedVector2Array(%d, -16, %d, -16, %d, 16, %d, 16)'
                     % (i, gnd, -pw // 2, pw // 2, pw // 2, -pw // 2))
    nodes.append('[node name="SpawnPoints" type="Node2D" parent="."]')
    for sp_name, sx in mp["spawns"]:
        nodes.append('[node name="%s" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2(%d, %d)' % (sp_name, sx, gy - 60))
    nodes.append('[node name="Spawners" type="Node2D" parent="."]')
    if mp.get("mons"):
        nodes.append('[node name="MapSpawner" type="Node2D" parent="Spawners"]\nscript = ExtResource("map_spawner")\nmonster_types = Array[ExtResource("monster_data")]([%s])\ncount_per_type = %d\nmonster_scene = ExtResource("monster_scene")\nmax_spawn_distance = 1700.0'
                     % (", ".join('ExtResource("md_%s")' % m for m in mp["mons"]), mp.get("count", 4)))
    for i, bid in enumerate(mp.get("boss", [])):
        nodes.append('[node name="Boss_%s" type="Node2D" parent="Spawners"]\nposition = Vector2(%d, %d)\nscript = ExtResource("spawner")\nmonster_types = Array[ExtResource("monster_data")]([ExtResource("md_%s")])\nmonster_scene = ExtResource("monster_scene")\nmax_alive = 1\nspawn_width = 160'
                     % (bid, mp["boss_x"], gy - 30, bid))
    nodes.append('[node name="Portals" type="Node2D" parent="."]')
    for (pname, px, tmap, tsp, label, dest) in mp["portals"]:
        nodes.append('[node name="%s" parent="Portals" instance=ExtResource("portal")]\nposition = Vector2(%d, %d)\ntarget_map = &"%s"\ntarget_spawn_point = &"%s"\nlabel_text = "%s"\ndestination_name = "%s"'
                     % (pname, px, gy, tmap, tsp, label, dest))
    if mp.get("npcs"):
        nodes.append('[node name="NPCs" type="Node2D" parent="."]')
        for n in mp["npcs"]:
            extra = ""
            if n.get("shop"):
                extra += '\nshop_items = Array[StringName]([%s])' % ", ".join('&"%s"' % s for s in n["shop"])
            if n.get("by_flag"):
                extra += '\ndialog_by_flag = {\n%s\n}' % ",\n".join('"%s": "%s"' % (k, v) for k, v in n["by_flag"].items())
            nodes.append('[node name="%s" parent="NPCs" instance=ExtResource("npc")]\nposition = Vector2(%d, %d)\nnpc_name = "%s"\ntype = %d\ndialog = "%s"%s'
                         % (n["node"], n["x"], gy - 60, n["name"], n["type"], n["dialog"], extra))
    if mp.get("lore"):
        nodes.append('[node name="Lore" type="Node2D" parent="."]')
        for l in mp["lore"]:
            nodes.append('[node name="%s" parent="Lore" instance=ExtResource("lore")]\nposition = Vector2(%d, %d)\nlore_id = &"%s"\ntitle = "%s"\ntext = "%s"\nlabel_text = "%s"%s'
                         % (l["node"], l["x"], gy - 90, l["id"], l["title"], l["text"], l["label"],
                            ('\nrequired_flag = &"%s"\nlocked_text = "%s"' % (l["flag"], l["locked"])) if l.get("flag") else ""))
    return '[gd_scene load_steps=%d format=3]\n\n%s\n\n%s\n\n%s\n' % (
        len(ext) + len(subs) + 1, "\n".join(ext), "\n\n".join(subs), "\n\n".join(nodes))

HELGA_SHOP = ["red_potion", "orange_potion", "white_potion", "blue_potion", "iron_ore", "phracon", "emveretarcon",
              "bastard_sword", "iron_blade", "forge_saber", "iron_shield", "iron_helm", "miner_helmet",
              "chain_mail", "scale_mail", "iron_greaves", "miner_boots", "rosary", "belt"]

MAPS = [
    dict(id="iron_road", name="ทางเหล็ก", w=4800, h=1100, ground_y=880,
         colors=("0.16, 0.15, 0.17", "0.22, 0.2, 0.2", "0.3, 0.27, 0.25"),
         plats=[(900, 700, 340), (1800, 620, 300), (2700, 700, 360), (3700, 640, 320)],
         mons=["pitman", "steel_beetle"], count=5,
         spawns=[("default", 200), ("from_forest", 200), ("from_town", 4600)],
         portals=[("ToForest", 60, "dark_forest", "from_iron_road", "← ป่าเงาลึก", "ป่าเงาลึก"),
                  ("ToTown", 4740, "nidavellir_town", "from_road", "→ นิดาเวลลิร์", "นิดาเวลลิร์ นครเตาหลอม")]),
    dict(id="nidavellir_town", name="นิดาเวลลิร์ นครเตาหลอม", w=3400, h=1000, ground_y=880,
         colors=("0.14, 0.1, 0.09", "0.26, 0.17, 0.12", "0.34, 0.26, 0.2"),
         spawns=[("default", 300), ("from_road", 200), ("from_mine", 3200)],
         portals=[("ToRoad", 60, "iron_road", "from_town", "← ทางเหล็ก", "ทางเหล็ก"),
                  ("ToMine", 3340, "ember_mine", "from_town", "→ เหมืองถ่านไฟ", "เหมืองถ่านไฟ")],
         npcs=[
             dict(node="Helga", x=350, name="นายหน้าเฮลกา", type=1, shop=HELGA_SHOP,
                  dialog="คนบนดินสินะ ของที่นี่แพงหน่อยนะ แต่ของดีทุกชิ้น\\n\\nอย่าถามว่าใครตี... ที่นี่ไม่ถามกัน"),
             dict(node="Dvalin", x=900, name="ช่างเอกดวาลิน", type=2,
                  dialog="เอาของมาตีบวกก็วางตรงนี้\\n\\n...เจ้ามากับฮันส์ใช่ไหม บอกมันว่าข้ายังไม่ให้อภัย"),
             dict(node="Brokk", x=1450, name="บรอกก์", type=0,
                  dialog="ข้าไม่พูดเรื่องเก่าแล้ว ไปเถอะ\\n\\n...ค้อนน่ะ? ค้อนอะไร",
                  by_flag={"read_sindri_grave": "เจ้าไปดูหลุมนั้นมาแล้วสินะ\\n\\nใช่ ข้ากับซินดริตีค้อนเล่มนั้น\\nแต่เราไม่เคยตีมันเพื่อปกป้องใครทั้งนั้น"}),
             dict(node="SavePoint", x=1950, name="ศิลาสลักโบราณ", type=4,
                  dialog="ศิลาเก่าแก่ ตราค้อนที่สลักไว้ดูใหม่กว่าตัวหินมาก"),
             dict(node="Healer", x=2400, name="หมอคนแคระเฮดิน", type=3,
                  dialog="เจ็บตรงไหน ให้ข้าดู\\n\\nที่นี่ไม่มีใครขอบคุณธอร์หรอกนะ อย่าแปลกใจ"),
             dict(node="Hans", x=2850, name="ช่างตีเหล็กฮันส์", type=0,
                  dialog="ข้าตามเจ้ามาถึงนี่แล้ว...\\n\\nสิบปีที่ไม่ได้กลับบ้าน ทุกคนยังจำหน้าข้าได้ แต่ไม่มีใครทัก"),
         ],
         lore=[dict(node="SindriGrave", x=3050, id="sindri_grave", title="หลุมศพไร้ชื่อ",
                    text="หลุมศพเก่า ชื่อบนป้ายถูกสกัดออกจนอ่านไม่ได้\\n\\nเหมือนกับศิลาสลักที่พรอนเทรา... รอยสกัดแบบเดียวกัน\\n\\nมีดอกไม้แห้งวางอยู่ ใครบางคนยังมาเยี่ยม",
                    label="หลุมศพเก่า")]),
    dict(id="ember_mine", name="เหมืองถ่านไฟ", w=5000, h=1200, ground_y=900,
         colors=("0.12, 0.06, 0.05", "0.3, 0.1, 0.06", "0.28, 0.2, 0.16"),
         plats=[(800, 720, 320), (1600, 600, 300), (2500, 700, 380), (3300, 580, 300), (4200, 700, 340)],
         mons=["ember_bat", "magma_slug"], count=5,
         spawns=[("default", 200), ("from_town", 200), ("from_hall", 4800)],
         portals=[("ToTown", 60, "nidavellir_town", "from_mine", "← นิดาเวลลิร์", "นิดาเวลลิร์"),
                  ("ToHall", 4940, "hall_of_silence", "from_mine", "→ ห้องโถงเงียบ", "ห้องโถงเงียบ")]),
    dict(id="hall_of_silence", name="ห้องโถงเงียบ", w=4600, h=1200, ground_y=900,
         colors=("0.07, 0.08, 0.12", "0.12, 0.14, 0.2", "0.2, 0.22, 0.28"),
         plats=[(1000, 700, 360), (2100, 620, 320), (3200, 700, 360)],
         mons=["forge_golem", "silent_wraith"], count=4, boss=["rune_watcher"], boss_x=4100,
         spawns=[("default", 200), ("from_mine", 200), ("from_forge", 4400)],
         portals=[("ToMine", 60, "ember_mine", "from_hall", "← เหมืองถ่านไฟ", "เหมืองถ่านไฟ"),
                  ("ToForge", 4540, "cold_forge", "from_hall", "→ เตาหลอมร้าง", "เตาหลอมร้าง")]),
    dict(id="cold_forge", name="เตาหลอมร้าง", w=3000, h=1100, ground_y=880,
         colors=("0.06, 0.05, 0.06", "0.16, 0.1, 0.08", "0.24, 0.18, 0.15"),
         boss=["forge_guardian"], boss_x=2500,
         spawns=[("default", 200), ("from_hall", 200)],
         portals=[("ToHall", 60, "hall_of_silence", "from_forge", "← ห้องโถงเงียบ", "ห้องโถงเงียบ")],
         lore=[dict(node="HammerBlueprint", x=1500, id="hammer_blueprint", title="แบบร่างบนกำแพง",
                    text="แบบร่างค้อนขนาดใหญ่สลักบนกำแพงหิน\\n\\nวงจรรูนรอบหัวค้อน... ไม่ใช่รูนป้องกัน\\n\\nมันคือรูน «ดูด»",
                    label="แบบร่างโบราณ", flag="killed_forge_guardian", locked="ผู้พิทักษ์ยังยืนขวางอยู่ มองไม่เห็นกำแพงด้านหลัง")]),
]

# =========================================================
# ทำงาน
# =========================================================
def main():
    print("[1] ไอเทมขยะ %d ชิ้น" % len(JUNK))
    for j in JUNK:
        w("data/items/%s.tres" % j[0], junk_tres(j[0], j[1], j[2], j[3], j[4], "junk2" if j[5] in [m["id"] for m in MON] else "junk"))

    print("[2] ของสวมใส่ %d ชิ้น" % len(EQUIP))
    for e in EQUIP:
        w("data/items/%s.tres" % e["id"], equip_tres(e))

    print("[3] มอนบท 2 %d ตัว" % len(MON))
    for m in MON:
        monster_png(m)
        w("data/sprites/placeholder/%s_frames.tres" % m["id"], frames_tres(m))
        w("data/monsters/%s.tres" % m["id"], monster_tres(m))
        ICON_JOBS.append(("card_" + m["id"], "C" + m["code"][0], COLOR["card"]))
        w("data/cards/card_%s.tres" % m["id"], card_tres(m).replace(
            '[ext_resource type="Script" path="res://scripts/resources/card_data.gd" id="1_card"]',
            '[ext_resource type="Script" path="res://scripts/resources/card_data.gd" id="1_card"]\n' + icon_line("card_" + m["id"])
        ).replace('type = 5', 'icon = ExtResource("2_icon")\ntype = 5'))

    print("[4] ใส่ของขยะลงมอนเดิม 12 ตัว")
    old_mons = sorted(set(j[5] for j in JUNK) - set(m["id"] for m in MON))
    for mid in old_mons:
        p = "data/monsters/%s.tres" % mid
        if not os.path.exists(p):
            print("  ! ไม่เจอ", p); continue
        s = open(p, encoding="utf-8").read()
        m = re.search(r'ExtResource\("([^"]+)"\)\s*\n', s)
        drop_id = re.search(r'\[ext_resource type="Script"[^\n]*drop_entry\.gd" id="([^"]+)"\]', s)
        if not drop_id:
            print("  ! %s ไม่มี drop_entry" % mid); continue
        did = drop_id.group(1)
        adds, refs = [], []
        for (jid, _n, _d, _s, _c, _m, chance, maxc) in [j for j in JUNK if j[5] == mid]:
            if '&"%s"' % jid in s:
                continue
            sid = "Drop_%s_junk_%s" % (mid, jid)
            adds.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("%s")\nitem_id = &"%s"\nchance = %.1f\n%s\n'
                        % (sid, did, jid, chance, ("max_count = %d\n" % maxc) if maxc > 1 else ""))
            refs.append('SubResource("%s")' % sid)
        # ของสวมใส่ใหม่ดรอปจากมอนเดิมบางตัว (โอกาสต่ำ)
        for (iid, chance) in {"wolf": [("wolf_cloak", 2.0)], "hornet": [("brooch", 0.5)], "munak": [("old_hairpin", 0), ("rosary", 0.8)],
                              "orc_warrior": [("bastard_sword", 1.5), ("iron_helm", 1.0)], "baphomet_jr": [("ember_cape", 2.0)],
                              "king_poring": [("leather_jacket", 5.0), ("ribbon", 8.0)], "lunatic": [("ribbon", 1.0)],
                              "fabre": [("wooden_shield", 1.0)], "poring": [("wooden_sword", 1.0)]}.get(mid, []):
            if chance <= 0 or '&"%s"' % iid in s:
                continue
            sid = "Drop_%s_eq_%s" % (mid, iid)
            adds.append('[sub_resource type="Resource" id="%s"]\nscript = ExtResource("%s")\nitem_id = &"%s"\nchance = %.1f\n\n' % (sid, did, iid, chance))
            refs.append('SubResource("%s")' % sid)
        if not adds:
            continue
        s = s.replace("\n[resource]\n", "\n" + "".join(adds) + "[resource]\n", 1)
        s = re.sub(r'(drops = Array\[ExtResource\("%s"\)\]\(\[)(.*?)(\]\))' % re.escape(did),
                   lambda mm: mm.group(1) + mm.group(2) + ", " + ", ".join(refs) + mm.group(3), s, count=1)
        backup(p, "ใส่ของขยะ")
        open(p, "w", encoding="utf-8").write(s)
        LOG.append("แก้ %s (+%d ดรอป)" % (p, len(adds)))

    print("[5] ร้านโทนี่ขายของใหม่")
    patch("scenes/maps/prontera_town.tscn", [
        ('shop_items = Array[StringName]([&"red_potion", &"orange_potion", &"blue_potion", &"meat", &"novice_sword", &"falchion", &"cotton_shirt", &"guard", &"cap", &"hood", &"sandals", &"phracon", &"emveretarcon"])',
         'shop_items = Array[StringName]([&"red_potion", &"orange_potion", &"blue_potion", &"meat", &"wooden_sword", &"novice_sword", &"short_sword", &"rapier", &"falchion", &"wooden_shield", &"guard", &"ribbon", &"cap", &"leather_cap", &"cotton_shirt", &"leather_jacket", &"hood", &"muffler", &"sandals", &"leather_shoes", &"necklace", &"earring", &"brooch", &"phracon", &"emveretarcon"])'),
    ], "ร้านขายของใหม่")

    print("[6] แมพบท 2 %d แมพ" % len(MAPS))
    for mp in MAPS:
        w("scenes/maps/%s.tscn" % mp["id"], map_tscn(mp))

    print("[7] ประตูจากป่าเงาลึกไปบท 2 + ลงทะเบียนแมพ")
    patch("scenes/maps/dark_forest.tscn", [
        ('[node name="from_field" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2(200, 850)\n',
         '[node name="from_field" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2(200, 850)\n\n'
         '[node name="from_iron_road" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2(5300, 850)\n'),
        ('label_text = "→ ทุ่งวิหาร"\n',
         'label_text = "→ ทุ่งวิหาร"\n\n'
         '[node name="ToIronRoad" parent="Portals" instance=ExtResource("portal")]\n'
         'position = Vector2(5560, 900)\ntarget_map = &"iron_road"\ntarget_spawn_point = &"from_forest"\n'
         'label_text = "→ ทางเหล็ก"\ndestination_name = "ทางเหล็ก (บทที่ 2)"\n'
         'required_flag = &"chapter2_open"\nlocked_text = "ทางเดินแคบ ๆ ลงไปใต้ดิน... มืดเกินกว่าจะไปต่อโดยไม่มีแผนที่"\n'),
    ], "ประตูบท2", markers=('name="from_iron_road"', 'name="ToIronRoad"'))
    print("[8] ต่อสายแมพ ป่าสนธยา <-> ป่าเงาลึก (เดิมป่าเงาลึกไม่มีทางเข้า)")
    patch("scenes/maps/asgard_forest_2.tscn", [
        ('[node name="boss_gate" type="Marker2D" parent="SpawnPoints"',
         '[node name="from_dark_forest" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2(3250, 820)\n\n'
         '[node name="boss_gate" type="Marker2D" parent="SpawnPoints"'),
        ('position = Vector2(3380, 880)\ndestination_name = "พรอนเทรา"',
         'position = Vector2(3380, 880)\ntarget_map = &"dark_forest"\ntarget_spawn_point = &"from_forest_2"\n'
         'label_text = "→ ป่าเงาลึก"\ndestination_name = "ป่าเงาลึก"'),
    ], "ต่อสายแมพ", markers=('name="from_dark_forest"', 'target_spawn_point = &"from_forest_2"'))
    patch("scenes/maps/dark_forest.tscn", [
        ('[node name="from_iron_road" type="Marker2D" parent="SpawnPoints"]',
         '[node name="from_forest_2" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2(200, 850)\n\n'
         '[node name="from_iron_road" type="Marker2D" parent="SpawnPoints"]'),
        ('target_map = &"prontera_field"\ntarget_spawn_point = &"from_forest"\nlabel_text = "→ ทุ่งวิหาร"',
         'target_map = &"asgard_forest_2"\ntarget_spawn_point = &"from_dark_forest"\nlabel_text = "← ป่าสนธยา"\ndestination_name = "ป่าสนธยา"'),
    ], "ต่อสายแมพ")
    patch("scripts/core/game.gd", [
        ('	&"dark_forest": "res://scenes/maps/dark_forest.tscn",\n}',
         '	&"dark_forest": "res://scenes/maps/dark_forest.tscn",\n'
         '	## ★ บทที่ 2 — สวาร์ทัลฟ์เฮม (รอบ 31) ★\n'
         '	&"iron_road": "res://scenes/maps/iron_road.tscn",\n'
         '	&"nidavellir_town": "res://scenes/maps/nidavellir_town.tscn",\n'
         '	&"ember_mine": "res://scenes/maps/ember_mine.tscn",\n'
         '	&"hall_of_silence": "res://scenes/maps/hall_of_silence.tscn",\n'
         '	&"cold_forge": "res://scenes/maps/cold_forge.tscn",\n}'),
    ], "แมพบท2")

    make_icons()
    print()
    if LOG:
        print("ทำไปทั้งหมด %d รายการ:" % len(LOG))
        for l in LOG:
            print("  ·", l)
    else:
        print("ทุกอย่างมีครบแล้ว ไม่ได้สร้าง/แก้อะไรเพิ่ม")

if __name__ == "__main__":
    main()
