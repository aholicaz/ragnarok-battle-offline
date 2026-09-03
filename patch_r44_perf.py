#!/usr/bin/env python3
"""รอบ 44 — แก้กระตุก: ใช้ SpriteFit กลาง + อุ่นเครื่องตอนโหลดแมพ + แก้ลูปโหลดที่ไม่ await"""
import re, sys, pathlib
ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')

def patch(path, old, new, marker=None, count=1):
    p = ROOT / path
    s = p.read_text(encoding='utf8')
    if marker and marker in s:
        print('  =', path, '(already)')
        return
    if old not in s:
        raise SystemExit(f'!! {path}: ไม่พบข้อความที่ต้องแก้:\n{old[:200]}')
    s = s.replace(old, new, count)
    p.write_text(s, encoding='utf8')
    print('  +', path)

# ---------- player.gd ----------
PLAYER_OLD = re.compile(r'\tvar list: Array = \[\]\n\tvar tallest := 0\.0\n\n\tfor i in range\(frames\.get_frame_count\(anim\)\):.*?\n\tvar info := \{\n\t\t"scale": auto_fit_height / maxf\(1\.0, tallest\),\n\t\t"frames": list,\n\t\t"tallest": tallest,\n\t\}', re.S)
p = ROOT / 'scripts/entities/player.gd'
s = p.read_text(encoding='utf8')
if 'SpriteFit.measure' not in s:
    m = PLAYER_OLD.search(s)
    if not m:
        raise SystemExit('!! player.gd: ไม่พบบล็อก _fit_info')
    new = ('\t# ★ รอบ 44 — วัดผ่าน SpriteFit (จำไว้ตรงกลางทั้งเกม ไม่วัดซ้ำทุกครั้งที่ถูกสร้างใหม่) ★\n'
           '\t# get_image() คือการดึงภาพกลับจากการ์ดจอ ช้ามาก — เดิมทำใหม่หลังเปลี่ยนแมพทุกครั้ง = กระตุก\n'
           '\t# ค่ากลาง (median) กันตัวเด้งของรอบ 39 ย้ายไปอยู่ใน SpriteFit แล้ว (SNAP 12 px)\n'
           '\tvar base: Dictionary = SpriteFit.measure(frames, anim)\n'
           '\tif base.is_empty():\n\t\treturn {}\n'
           '\tvar tallest: float = base.tallest\n'
           '\tvar info := {\n\t\t"scale": auto_fit_height / maxf(1.0, tallest),\n\t\t"frames": base.frames,\n\t\t"tallest": tallest,\n\t}')
    s = s[:m.start()] + new + s[m.end():]
    p.write_text(s, encoding='utf8')
    print('  + player.gd')
else:
    print('  = player.gd (already)')

# ---------- monster_base.gd ----------
MON_OLD = re.compile(r'\tvar list: Array = \[\]\n\tvar tallest := 0\.0\n\tfor i in range\(frames\.get_frame_count\(anim\)\):.*?\n\tvar k: float = data\.sprite_scale\.y', re.S)
p = ROOT / 'scripts/entities/monster_base.gd'
s = p.read_text(encoding='utf8')
if 'SpriteFit.measure' not in s:
    m = MON_OLD.search(s)
    if not m:
        raise SystemExit('!! monster_base.gd: ไม่พบบล็อก _fit_frames')
    new = ('\t# ★ รอบ 44 — วัดผ่าน SpriteFit (วัดครั้งเดียวทั้งเกมต่อชนิดมอน ไม่ใช่ทุกครั้งที่เกิด) ★\n'
           '\tvar base: Dictionary = SpriteFit.measure(frames, anim)\n'
           '\tif base.is_empty():\n\t\treturn {}\n'
           '\tvar list: Array = base.frames\n'
           '\tvar tallest: float = base.tallest\n\n'
           '\tvar k: float = data.sprite_scale.y')
    s = s[:m.start()] + new + s[m.end():]
    # ใช้ค่ากลางของท่า (กันมอนเด้งเหมือนผู้เล่นรอบ 39)
    s = s.replace('\tsprite.offset.x = data.sprite_offset.x + (fd.dx if sprite.flip_h else -fd.dx)\n'
                  '\tif data.align_feet:\n'
                  '\t\tsprite.offset.y = data.sprite_offset.y + data.foot_offset() / k - fd.bottom',
                  '\tsprite.offset.x = data.sprite_offset.x + (fd.dx_use if sprite.flip_h else -fd.dx_use)\n'
                  '\tif data.align_feet:\n'
                  '\t\tsprite.offset.y = data.sprite_offset.y + data.foot_offset() / k - fd.bottom_use')
    p.write_text(s, encoding='utf8')
    print('  + monster_base.gd')
else:
    print('  = monster_base.gd (already)')

# dropped_item: preload แทน load ตอนดรอป
patch('scripts/entities/monster_base.gd',
      '\tvar scene: PackedScene = load("res://scenes/items/dropped_item.tscn")',
      '\tvar scene: PackedScene = DROPPED_ITEM_SCENE',
      marker='DROPPED_ITEM_SCENE')
p = ROOT / 'scripts/entities/monster_base.gd'
s = p.read_text(encoding='utf8')
if 'const DROPPED_ITEM_SCENE' not in s:
    s = s.replace('var _fit_cache: Dictionary = {}',
                  'var _fit_cache: Dictionary = {}\n'
                  '## โหลดฉากของตกไว้ล่วงหน้า (รอบ 44 — เดิม load() ตอนมอนตาย)\n'
                  'const DROPPED_ITEM_SCENE: PackedScene = preload("res://scenes/items/dropped_item.tscn")', 1)
    p.write_text(s, encoding='utf8')

# ---------- map_base.gd : อุ่นเครื่อง ----------
patch('scripts/world/map_base.gd',
      '\t_ensure_floating_text_layer()\n\t_spawn_player()\n\t_setup_camera()\n\tEvents.say(display_name)',
      '\t_ensure_floating_text_layer()\n\t_spawn_player()\n\t_setup_camera()\n'
      '\t_warm_sprite_fit()\n'
      '\tEvents.say(display_name)',
      marker='_warm_sprite_fit')
p = ROOT / 'scripts/world/map_base.gd'
s = p.read_text(encoding='utf8')
if 'func _warm_sprite_fit' not in s:
    s = s.rstrip('\n') + '''


# =========================================================
# ★ รอบ 44 — อุ่นเครื่อง auto-fit ตอนโหลดแมพ ★
# วัดขอบภาพของผู้เล่น + มอนทุกชนิดในแมพนี้ให้เสร็จระหว่างจอยังมืด
# (SpriteFit จำไว้ทั้งเกม — มอนเกิดกลางเกมจะไม่ต้องดึงภาพจากการ์ดจออีก = ไม่กระตุก)
# =========================================================
func _warm_sprite_fit() -> void:
	var n := 0
	if player != null:
		var ps := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		if ps != null:
			n += SpriteFit.warm(ps.sprite_frames)
	for node in _all_descendants(self):
		if "monster_types" in node:
			for md in node.monster_types:
				if md != null and "sprite_frames" in md:
					n += SpriteFit.warm(md.sprite_frames)
		if "data" in node and node.data != null and "sprite_frames" in node.data:
			n += SpriteFit.warm(node.data.sprite_frames)
	if n > 0:
		print("[Map] %s อุ่นเครื่อง auto-fit %d ท่า" % [map_id, n])
'''
    p.write_text(s, encoding='utf8')
    print('  + map_base.gd (_warm_sprite_fit)')

print('done')
