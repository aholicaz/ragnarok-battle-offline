#!/usr/bin/env python3
"""รอบ 44 — prontera_field: เปลี่ยน TileMap 22,000 กระเบื้อง → Sprite2D รูปเดียว (แก้กระตุก)

ภาพฉากหลัง Asgard forest 1.png (6128x941) ถูกหั่นเป็นกระเบื้อง 16x16 ทั้งรูป (383x58 = 22,214 ช่อง)
แล้ววางเรียงกลับเป็นรูปเดิมใน TileMap → Godot ต้องสร้าง/วาดกระเบื้อง 22,000 ชิ้น
ทั้งที่ผลลัพธ์บนจอ = รูปเดียวเป๊ะ ๆ  สคริปต์นี้ถอดรหัส tile_data ตรวจว่าทุกช่องชี้ตรงตำแหน่งเดิม
แล้วแทนด้วย Sprite2D ที่พิกัดเดียวกัน (ภาพที่เห็นไม่เปลี่ยน) — กล่องชนพื้น/กำแพงย้ายไปอยู่ใต้โหนด Terrain
"""
import re, sys, pathlib, shutil

ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')
SCENE = ROOT / 'scenes/maps/prontera_field.tscn'
TILE = 16

s = SCENE.read_text(encoding='utf8')
if 'type="TileMap"' not in s:
    print('= prontera_field.tscn ไม่มี TileMap แล้ว (ทำไปแล้ว)')
    sys.exit(0)

bak = SCENE.with_name('prontera_field_ก่อนถอด_TileMap.tscn.bak')
if not bak.exists():
    shutil.copy(SCENE, bak)

# ---- ถอดรหัสกระเบื้อง ----
m = re.search(r'layer_0/tile_data = PackedInt32Array\(([^)]*)\)', s)
if not m:
    raise SystemExit('ไม่พบ tile_data')
a = [int(x) for x in m.group(1).split(',')]
tex_m = re.search(r'\[sub_resource type="TileSetAtlasSource"[^\]]*\]\ntexture = ExtResource\("([^"]+)"\)', s)
if not tex_m:
    raise SystemExit('ไม่พบ texture ของ TileSetAtlasSource')
tex_id = tex_m.group(1)

def s16(v):
    v &= 0xffff
    return v - 65536 if v >= 32768 else v

groups = {}   # (offset x,y) -> list of (cx,cy)
for i in range(len(a) // 3):
    c, b, d = a[3 * i:3 * i + 3]
    cx, cy = s16(c), s16(c >> 16)
    ax, ay = (b >> 16) & 0xffff, d & 0xffff
    groups.setdefault((ax - cx, ay - cy), []).append((cx, cy, ax, ay))

# กลุ่มใหญ่สุด = ตัวรูปหลัก  กลุ่มเล็ก = แถบที่ก็อปวางเพิ่ม (วาดด้วย Sprite2D region)
main_off = max(groups, key=lambda k: len(groups[k]))
print('กระเบื้องทั้งหมด', len(a) // 3, '| รูปหลัก', len(groups[main_off]), 'ช่อง offset', main_off,
      '| แถบเสริม', {k: len(v) for k, v in groups.items() if k != main_off})

nodes = []
nodes.append('[node name="Terrain" type="Node2D" parent="."]\n')
ox, oy = main_off
nodes.append('[node name="Background" type="Sprite2D" parent="Terrain"]\n'
             f'position = Vector2({-ox * TILE}, {-oy * TILE})\n'
             f'texture = ExtResource("{tex_id}")\ncentered = false\n')
n = 0
for off, cells in groups.items():
    if off == main_off:
        continue
    # แถบเสริมต้องเป็นสี่เหลี่ยมต่อเนื่อง — แยกเป็นแถว
    rows = {}
    for cx, cy, ax, ay in cells:
        rows.setdefault(cy, []).append((cx, ax, ay))
    for cy, lst in rows.items():
        lst.sort()
        # แบ่งช่วงต่อเนื่อง
        start = 0
        while start < len(lst):
            end = start
            while end + 1 < len(lst) and lst[end + 1][0] == lst[end][0] + 1 and lst[end + 1][1] == lst[end][1] + 1:
                end += 1
            cx0, ax0, ay0 = lst[start]
            w = end - start + 1
            n += 1
            nodes.append(f'[node name="Strip{n}" type="Sprite2D" parent="Terrain"]\n'
                         f'position = Vector2({cx0 * TILE}, {cy * TILE})\n'
                         f'texture = ExtResource("{tex_id}")\ncentered = false\n'
                         f'region_enabled = true\n'
                         f'region_rect = Rect2({ax0 * TILE}, {ay0 * TILE}, {w * TILE}, {TILE})\n')
            start = end + 1

# ---- ตัด sub_resource ของ TileSet ทิ้ง ----
s = re.sub(r'\[sub_resource type="TileSetAtlasSource"[^\]]*\]\n.*?\n\n', '', s, count=1, flags=re.S)
s = re.sub(r'\[sub_resource type="TileSet"[^\]]*\]\n.*?\n\n', '', s, count=1, flags=re.S)

# ---- แทนโหนด TileMap ----
s = re.sub(r'\[node name="TileMap" type="TileMap" parent="\."[^\]]*\]\n(?:[^\[\n][^\n]*\n)*\n',
           '\n'.join(nodes) + '\n', s, count=1)
s = s.replace('parent="TileMap"', 'parent="Terrain"')
s = s.replace('parent="TileMap/', 'parent="Terrain/')
assert 'TileMap' not in s and 'TileSet' not in s, 'ยังมีร่องรอย TileMap เหลืออยู่'
SCENE.write_text(s, encoding='utf8')
print('+ prontera_field.tscn:', len(s), 'bytes (เดิม', bak.stat().st_size, ')  สำรองไว้ที่', bak.name)
