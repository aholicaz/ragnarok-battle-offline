#!/usr/bin/env python3
"""รอบ 44 — AI มอน: เห็น/โดนตีแล้วไล่ไม่หยุด ไม่ติดกำแพงระยะ (leash) จนกว่าฝ่ายใดฝ่ายหนึ่งตาย"""
import sys, pathlib
ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')
p = ROOT / 'scripts/entities/monster_base.gd'
s = p.read_text(encoding='utf8')
if '_aggro_locked' in s:
    print('= monster_base.gd (already)')
    sys.exit(0)

def rep(old, new):
    global s
    if old not in s:
        raise SystemExit('!! ไม่พบ: ' + old[:120])
    s = s.replace(old, new, 1)

rep('''## มอนใจดีที่ถูกตี จะไล่ตามต่ออีกกี่วินาทีหลังคลาดสายตา
const AGGRO_MEMORY := 8.0
''', '''## มอนใจดีที่ถูกตี จะไล่ตามต่ออีกกี่วินาทีหลังคลาดสายตา
## ★ รอบ 44: ไม่ใช้แล้ว ★ — โดนตี/เห็นผู้เล่น = ไล่ไม่หยุดจนกว่าผู้เล่นหรือมอนตัวนั้นตาย
const AGGRO_MEMORY := 8.0
''')

rep('''var _aggro := false
var _aggro_timer := 0.0
''', '''var _aggro := false
var _aggro_timer := 0.0
## ★ รอบ 44 — "ล็อกเป้า" แล้ว ★ มอนที่เห็นผู้เล่น (ตัวดุ) หรือโดนตี (ทุกตัว)
## จะไล่ตามได้ไกลไม่จำกัด ไม่สนระยะ leash/detect อีก จนกว่าผู้เล่นตาย หรือมันตาย
var _aggro_locked := false
''')

rep('''	# ความโกรธจะจางลงถ้าไล่ผู้เล่นไม่ทันสักพัก (มอนใจดีจะกลับไปเดินเล่นเหมือนเดิม)
	if _aggro and data.ai_type != MonsterData.AIType.AGGRESSIVE:
		_aggro_timer -= delta
		if _aggro_timer <= 0.0:
			_aggro = false

	_player = get_tree().get_first_node_in_group("player")
''', '''	# ★ รอบ 44 — ความโกรธไม่จางอีกแล้ว ★ (เดิมมอนใจดีเลิกไล่หลัง 8 วิ)
	# เลิกไล่อย่างเดียวคือผู้เล่นตาย → กลับไปเดินเล่นตามปกติ
	_player = get_tree().get_first_node_in_group("player")
	if _aggro_locked and (_player == null or not is_instance_valid(_player) or PlayerState.is_dead()):
		_aggro_locked = false
		_aggro = data.ai_type == MonsterData.AIType.AGGRESSIVE
''')

rep('''	var home_offset := global_position.x - spawn_position.x
	var too_far_from_home: bool = data.leash_range > 0.0 and absf(home_offset) > data.leash_range
''', '''	var home_offset := global_position.x - spawn_position.x
	# ★ รอบ 44 — ล็อกเป้าแล้วไม่มี "กำแพงระยะ" ★ ไล่ไปได้ทั่วแมพ
	var too_far_from_home: bool = (not _aggro_locked) and data.leash_range > 0.0 \\
		and absf(home_offset) > data.leash_range
''')

rep('''	# มอนดุ = เห็นแล้วไล่เลย / มอนใจดี = ไล่เฉพาะตอนถูกตี
	var hostile: bool = _aggro or data.ai_type == MonsterData.AIType.AGGRESSIVE
	# ถ้าถูกตีแล้ว จะตามได้ไกลกว่าปกติ
	var chase_range: float = data.detect_range if not _aggro else maxf(data.detect_range, data.leash_range)
	var will_engage: bool = hostile and distance <= chase_range and not too_far_from_home
''', '''	# มอนดุ = เห็นแล้วไล่เลย / มอนใจดี = ไล่เฉพาะตอนถูกตี
	var hostile: bool = _aggro or data.ai_type == MonsterData.AIType.AGGRESSIVE
	# ★ รอบ 44 — มอนดุที่ "เห็น" ผู้เล่นครั้งแรก (เข้าระยะ detect) = ล็อกเป้าทันที ★
	if hostile and not _aggro_locked and distance <= data.detect_range \\
			and data.ai_type != MonsterData.AIType.STATIONARY:
		_set_aggro()
	# ล็อกเป้าแล้ว = ไล่ได้ไกลไม่จำกัด (เดิมจำกัดที่ detect/leash → มอนวิ่งไปชน "กำแพงระยะ" แล้วหยุด)
	var chase_range: float = INF if _aggro_locked else data.detect_range
	var will_engage: bool = hostile and distance <= chase_range and not too_far_from_home
''')

rep('''func _set_aggro() -> void:
	_aggro = true
	_aggro_timer = AGGRO_MEMORY
''', '''func _set_aggro() -> void:
	_aggro = true
	_aggro_timer = AGGRO_MEMORY
	# ★ รอบ 44 — ล็อกเป้าถาวร (จนกว่าผู้เล่นตาย/มอนตาย) ★ ตัวนิ่ง (STATIONARY) ไม่ไล่อยู่แล้ว
	if data != null and data.ai_type != MonsterData.AIType.STATIONARY:
		_aggro_locked = true


## ล็อกเป้าอยู่ไหม (ไว้ให้เทสต์/ระบบอื่นดู)
func is_aggro_locked() -> bool:
	return _aggro_locked
''')

p.write_text(s, encoding='utf8')
print('+ monster_base.gd (aggro lock)')
