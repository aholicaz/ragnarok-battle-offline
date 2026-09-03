#!/usr/bin/env python3
"""รอบ 44 — เอฟเฟกต์รอยฟันตอนโจมตีปกติ (player.gd + skill_effect.gd flip_v)"""
import sys, pathlib
ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')

def patch(path, old, new, marker):
    p = ROOT / path
    s = p.read_text(encoding='utf8')
    if marker in s:
        print('  =', path, '(already)')
        return
    if old not in s:
        raise SystemExit('!! %s: ไม่พบ %s' % (path, old[:80]))
    p.write_text(s.replace(old, new, 1), encoding='utf8')
    print('  +', path)

# ---- skill_effect.gd : รองรับพลิกแนวตั้ง ----
patch('scripts/entities/skill_effect.gd',
      '\t_sprite.flip_h = _dir < 0\n',
      '\t_sprite.flip_h = _dir < 0\n\t_sprite.flip_v = bool(cfg.get("flip_v", false))   # รอบ 44: ฟันสวนขึ้น\n',
      marker='flip_v')

# ---- player.gd : ช่องตั้งค่า ----
patch('scripts/entities/player.gd',
      '@export_group("ท่าโจมตี")\n## ชื่อท่าตอนมือเปล่า\n',
      '''# =========================================================
# ★ เอฟเฟกต์รอยฟันตอนโจมตีปกติ (รอบ 44) ★
# ภาพเสี้ยวแสงโผล่ข้างหน้าตัวละครทุกครั้งที่ตี สลับ "ฟันลง" / "ฟันสวนขึ้น"
# ไม่ทำดาเมจเอง (ดาเมจยังคิดจากกรอบ Attack Range เหมือนเดิม) — แค่ภาพ
# ว่างไว้ = ใช้ res://data/sprites/fx_attack.tres อัตโนมัติ · อยากปิดให้ติ๊ก Attack Effect Enabled ออก
# =========================================================
@export_group("เอฟเฟกต์โจมตีปกติ")
@export var attack_effect_enabled: bool = true
@export var attack_effect_frames: SpriteFrames
## ชื่อท่าที่จะสลับกันเล่น (ว่าง = ทุกท่าในไฟล์) — ท่าที่ 2, 4, ... จะถูกพลิกแนวตั้ง (ฟันสวนขึ้น)
@export var attack_effect_anims: Array[StringName] = [&"slash", &"slash2"]
## จุดเกิดเทียบกับตัวละคร (x = ข้างหน้า)
@export var attack_effect_offset: Vector2 = Vector2(78, -28)
## ความสูงของภาพบนจอ (0 = ใช้ Scale)
@export var attack_effect_height: float = 230.0
@export var attack_effect_scale: float = 1.0
## โผล่หลังกดตีกี่วิ (ให้ตรงจังหวะดาบเหวี่ยง)
@export var attack_effect_delay: float = 0.06
@export var attack_effect_z: int = 40
const ATTACK_FX_PATH := "res://data/sprites/fx_attack.tres"
var _attack_fx_turn := 0

@export_group("ท่าโจมตี")
## ชื่อท่าตอนมือเปล่า
''',
      marker='attack_effect_enabled')

# ---- player.gd : เรียกตอนตี ----
patch('scripts/entities/player.gd',
      '\t_jump_anim = ""\n\t_play(attack_animation())\n\n\tawait get_tree().create_timer(attack_windup).timeout\n',
      '\t_jump_anim = ""\n\t_play(attack_animation())\n\t_spawn_attack_effect()\n\n\tawait get_tree().create_timer(attack_windup).timeout\n',
      marker='_spawn_attack_effect()\n')

patch('scripts/entities/player.gd',
      '## ★ เอฟเฟกต์สกิล ★ เกิดเป็นโหนดแยกในแมพ',
      '''## ★ รอยฟันตอนโจมตีปกติ (รอบ 44) ★
func _spawn_attack_effect() -> void:
	if not attack_effect_enabled:
		return
	if attack_effect_frames == null and ResourceLoader.exists(ATTACK_FX_PATH):
		attack_effect_frames = load(ATTACK_FX_PATH)
	if attack_effect_frames == null:
		return
	var anims: Array = attack_effect_anims.duplicate()
	if anims.is_empty():
		for a in attack_effect_frames.get_animation_names():
			if String(a) != "default":
				anims.append(StringName(a))
	if anims.is_empty():
		return
	var idx: int = _attack_fx_turn % anims.size()
	_attack_fx_turn += 1
	SkillEffect.spawn_config({
		"frames": attack_effect_frames,
		"anim": anims[idx],
		"offset": attack_effect_offset,
		"height": attack_effect_height,
		"scale": attack_effect_scale,
		"follow": true,
		"delay": attack_effect_delay,
		"z": attack_effect_z,
		"name": "attack",
		"flip_v": idx % 2 == 1,
		"damage": false,
	}, self, facing)


## ★ เอฟเฟกต์สกิล ★ เกิดเป็นโหนดแยกในแมพ''',
      marker='func _spawn_attack_effect')
print('done')
