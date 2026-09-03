#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 44 — สลับมอนในแมพ + แมพใหม่ "ป่าเงาลึกชั้นใน" (dark_forest_2)

  asgard_forest_2  มอนเกิด → drops, chonchon, wolf  (คิงโพริงยังอยู่)
  dark_forest      มอนเกิด → hornet, wolf, lunatic · เอาบาฟโฟเมทออก · ประตูขวาไป dark_forest_2 (ไม่ล็อกแล้ว)
  dark_forest_2    ใหม่ (บท 1) มอน munak, orc_warrior, baphomet_jr · บาฟโฟเมทเฝ้าหน้าประตูไป iron_road (ล็อกธง chapter2_open)
  iron_road        ประตูซ้ายกลับมา dark_forest_2
  Game.MAPS        ลงทะเบียน dark_forest_2
รันซ้ำได้ · รันในโฟลเดอร์โปรเจกต์ (ปิด Godot ก่อน)
"""
import os, re, sys, shutil, importlib.util

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else '.')
os.chdir(ROOT)
HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    spec = importlib.util.spec_from_file_location(name, os.path.join(HERE, name + '.py'))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


g = load('gen_round31')
bg = load('make_ch2_bg')
os.chdir(ROOT)
LOG = []


def backup(path, tag='รอบ44'):
    b = path.replace('.tscn', '_ก่อน%s.tscn.bak' % tag).replace('.gd', '_ก่อน%s.gd.bak' % tag)
    if not os.path.exists(b):
        shutil.copy(path, b)


def read(p):
    return open(p, encoding='utf-8').read()


def write(p, s):
    open(p, 'w', encoding='utf-8').write(s)


def ensure_ext(s, mid):
    """ใส่ ext_resource ของมอน (ถ้ายังไม่มี)"""
    if 'id="md_%s"' % mid in s:
        return s
    lastext = list(re.finditer(r'^\[ext_resource [^\n]*\]$', s, flags=re.M))[-1]
    line = '\n[ext_resource type="Resource" path="res://data/monsters/%s.tres" id="md_%s"]' % (mid, mid)
    return s[:lastext.end()] + line + s[lastext.end():]


def drop_unused_ext(s):
    for m in list(re.finditer(r'^\[ext_resource [^\n]*id="(md_[a-z_]+)"\]\n', s, flags=re.M)):
        if s.count('ExtResource("%s")' % m.group(1)) == 0:
            s = s.replace(m.group(0), '', 1)
    return s


def fix_load_steps(s):
    if 'load_steps=' in s:
        n = len(re.findall(r'^\[(ext_resource|sub_resource) ', s, flags=re.M)) + 1
        s = re.sub(r'load_steps=\d+', 'load_steps=%d' % n, s, count=1)
    return s


def set_spawner_types(s, node_name, mons):
    pat = re.compile(r'(\[node name="%s" type="Node2D" parent="Spawners"[^\n]*\]\n(?:[^\n\[][^\n]*\n)*?monster_types = )Array\[ExtResource\("monster_data"\)\]\(\[[^\]]*\]\)' % re.escape(node_name))
    new = 'Array[ExtResource("monster_data")]([%s])' % ', '.join('ExtResource("md_%s")' % m for m in mons)
    if not pat.search(s):
        raise SystemExit('ไม่พบ spawner %s' % node_name)
    return pat.sub(lambda m: m.group(1) + new, s, count=1)


def remove_node(s, name):
    return re.sub(r'\[node name="%s" [^\n]*\]\n(?:[^\n\[][^\n]*\n)*\n?' % re.escape(name), '', s, count=1)


# =========================================================
# 1) asgard_forest_2 → drops / chonchon / wolf
# =========================================================
p = 'scenes/maps/asgard_forest_2.tscn'
s = read(p)
if 'ExtResource("md_drops"), ExtResource("md_chonchon"), ExtResource("md_wolf")' not in s:
    backup(p)
    for m in ('drops', 'chonchon', 'wolf'):
        s = ensure_ext(s, m)
    s = set_spawner_types(s, 'MapSpawner', ['drops', 'chonchon', 'wolf'])
    s = fix_load_steps(drop_unused_ext(s))
    write(p, s)
    LOG.append('ป่าสนธยา: มอนเกิด = ดรอปส์ ชอนชอน หมาป่า')

# =========================================================
# 2) dark_forest → hornet / wolf / lunatic · เอาบอสออก · ประตูไป dark_forest_2
# =========================================================
p = 'scenes/maps/dark_forest.tscn'
s = read(p)
if 'target_map = &"dark_forest_2"' not in s:
    backup(p)
    for m in ('hornet', 'wolf', 'lunatic'):
        s = ensure_ext(s, m)
    s = set_spawner_types(s, 'MapSpawner', ['hornet', 'wolf', 'lunatic'])
    s = remove_node(s, 'BaphometBoss')
    s = s.replace('[node name="ToIronRoad" parent="Portals"', '[node name="ToDarkForest2" parent="Portals"', 1)
    s = re.sub(r'(\[node name="ToDarkForest2" parent="Portals"[^\n]*\]\n)((?:[^\n\[][^\n]*\n)*)',
               lambda m: m.group(1) + re.sub(r'^(target_map|target_spawn_point|label_text|destination_name|required_flag|locked_text) = [^\n]*\n', '', m.group(2), flags=re.M)
               + 'target_map = &"dark_forest_2"\ntarget_spawn_point = &"from_dark_forest"\nlabel_text = "→ ป่าเงาลึกชั้นใน"\ndestination_name = "ป่าเงาลึกชั้นใน"\n',
               s, count=1)
    if 'name="from_dark_forest_2"' not in s:
        s = s.rstrip('\n') + '\n\n[node name="from_dark_forest_2" type="Marker2D" parent="SpawnPoints"]\nposition = Vector2(3590, 519)\n'
    s = fix_load_steps(drop_unused_ext(s))
    write(p, s)
    LOG.append('ป่าเงาลึก: มอนเกิด = ฮอร์เน็ต หมาป่า ลูนาติก · เอาบาฟโฟเมทออก · ประตูขวา → ป่าเงาลึกชั้นใน')

# =========================================================
# 3) dark_forest_2 (ใหม่)
# =========================================================
DF2 = dict(id='dark_forest_2', name='ป่าเงาลึกชั้นใน', w=4200, h=1100, ground_y=880,
           colors=('0.07, 0.06, 0.1', '0.12, 0.1, 0.16', '0.17, 0.15, 0.2'),
           mons=['munak', 'orc_warrior', 'baphomet_jr'], count=4,
           boss=['baphomet'], boss_x=3880,
           plats=[(1200, 700, 320), (2300, 640, 300), (3100, 700, 340)],
           spawns=[('default', 200), ('from_dark_forest', 200), ('from_iron_road', 3980)],
           portals=[('ToDarkForest', 60, 'dark_forest', 'from_dark_forest_2', '← ป่าเงาลึก', 'ป่าเงาลึก'),
                    ('ToIronRoad', 4140, 'iron_road', 'from_forest', '→ ทางเหล็ก', 'ทางเหล็ก (บทที่ 2)')],
           lore=[dict(node='AltarStone', x=2700, id='dark_altar', title='แท่นบูชาหินดำ',
                      text='หินดำสลักรูปแพะเขาโค้ง เลือดแห้งกรังเป็นชั้น ๆ\n\nรอยกีบเท้าขนาดใหญ่เดินวนรอบแท่น... แล้วมุ่งหน้าไปทางตะวันออก',
                      label='แท่นบูชาหินดำ')])
p = 'scenes/maps/dark_forest_2.tscn'
if not os.path.exists(p):
    txt = g.map_tscn(DF2)
    txt = txt.replace('chapter = 2', 'chapter = 1').replace('region = "สวาร์ทัลฟ์เฮม"', 'region = "มิดการ์ด"')
    # ประตูไปบท 2 ล็อกธง + บาฟโฟเมทเฝ้าอยู่หน้าประตู
    txt = txt.replace('destination_name = "ทางเหล็ก (บทที่ 2)"',
                      'destination_name = "ทางเหล็ก (บทที่ 2)"\nrequired_flag = &"chapter2_open"\n'
                      'locked_text = "ทางเดินแคบ ๆ ลงไปใต้ดิน... มืดเกินกว่าจะไปต่อโดยไม่มีแผนที่"')
    write(p, txt)
    LOG.append('สร้าง scenes/maps/dark_forest_2.tscn (มูนัค ออร์คนักรบ บาฟโฟเมทจูเนียร์ · บอสบาฟโฟเมทเฝ้าประตู)')


# ฉากหลัง (วาดด้วย PIL แบบเดียวกับบท 2)
def draw_dark2(img, d, w, h, gy):
    import random
    from PIL import Image, ImageDraw, ImageFilter
    bg.ridge(d, w, h * 0.40, h * 0.14, (18, 15, 26), 61, spikes=True)
    bg.ridge(d, w, h * 0.55, h * 0.10, (13, 11, 20), 62)
    # ต้นไม้ตายสูง ๆ เงาดำ
    random.seed(63)
    for _ in range(26):
        x = random.uniform(0, w); th = random.uniform(160, 330)
        d.line([(x, gy), (x + random.uniform(-10, 10), gy - th)], fill=(9, 8, 13), width=int(random.uniform(7, 14)))
        for k in range(3):
            y0 = gy - th * random.uniform(0.45, 0.9)
            d.line([(x, y0), (x + random.uniform(-70, 70), y0 - random.uniform(20, 60))], fill=(9, 8, 13), width=4)
    # หมอกม่วงต่ำ ๆ + ดวงตาแดงในความมืด
    bg.glow_dots(img, 30, 0.6, 0.82, (120, 70, 170), 64, 8, 18, 14)
    bg.glow_dots(img, 14, 0.5, 0.78, (255, 60, 60), 65, 1.2, 2.2, 2)


BG = dict(id='dark_forest_2', size=(2100, 650), draw=draw_dark2, ground_top=(40, 34, 48), ground=(26, 22, 32),
          sky=[(0.0, (6, 5, 10)), (0.45, (16, 13, 24)), (0.83, (30, 26, 40)), (1.0, (18, 16, 24))])
os.makedirs(bg.OUT, exist_ok=True)
bgp = '%s/%s_bg.png' % (bg.OUT, BG['id'])
if not os.path.exists(bgp):
    bg.paint(BG).save(bgp)
    LOG.append('วาดฉากหลัง ' + bgp)
bg.wire(BG)

# =========================================================
# 4) iron_road ประตูซ้าย → dark_forest_2
# =========================================================
p = 'scenes/maps/iron_road.tscn'
s = read(p)
if 'target_map = &"dark_forest_2"' not in s:
    backup(p)
    s = re.sub(r'(\[node name="ToForest" parent="Portals"[^\n]*\]\n(?:[^\n\[][^\n]*\n)*?)target_map = &"dark_forest"\n',
               r'\1target_map = &"dark_forest_2"\n', s, count=1)
    s = re.sub(r'(\[node name="ToForest" parent="Portals"[^\n]*\]\n(?:[^\n\[][^\n]*\n)*?)label_text = "[^"]*"\n',
               r'\1label_text = "← ป่าเงาลึกชั้นใน"\n', s, count=1)
    s = re.sub(r'(\[node name="ToForest" parent="Portals"[^\n]*\]\n(?:[^\n\[][^\n]*\n)*?)destination_name = "[^"]*"\n',
               r'\1destination_name = "ป่าเงาลึกชั้นใน"\n', s, count=1)
    write(p, s)
    LOG.append('ทางเหล็ก: ประตูซ้าย → ป่าเงาลึกชั้นใน')

# =========================================================
# 5) Game.MAPS
# =========================================================
p = 'scripts/core/game.gd'
s = read(p)
if '&"dark_forest_2"' not in s:
    backup(p)
    s = s.replace('	&"thunder_scar": "res://scenes/maps/thunder_scar.tscn",\n',
                  '	&"thunder_scar": "res://scenes/maps/thunder_scar.tscn",\n'
                  '	## ★ ป่าเงาลึกชั้นใน (รอบ 44) — มอนบท 1 ที่เหลือ + บาฟโฟเมทเฝ้าทางไปบท 2 ★\n'
                  '	&"dark_forest_2": "res://scenes/maps/dark_forest_2.tscn",\n', 1)
    assert '&"dark_forest_2"' in s, 'ไม่พบบรรทัด thunder_scar ใน Game.MAPS'
    write(p, s)
    LOG.append('Game.MAPS + dark_forest_2')

for l in LOG:
    print('  +', l)
if not LOG:
    print('  = ทำครบแล้ว')
