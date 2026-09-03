#!/usr/bin/env python3
"""รอบ 45 (ส่วน core) — สเตตัส VIT/INT · ช่อง % ของสวมใส่ · ไอเทมรีสกิล/รีสเตตัส/บัฟ"""
import sys, pathlib, re
ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')

def patch(path, old, new, marker):
    p = ROOT / path
    s = p.read_text(encoding='utf8')
    if marker in s:
        print('  =', path, '(already)'); return
    if old not in s:
        raise SystemExit('!! %s: ไม่พบ %s' % (path, old[:90]))
    p.write_text(s.replace(old, new, 1), encoding='utf8')
    print('  +', path)

# =========================================================
# 1) player_stats.gd — ตารางผลสเตตัส
# =========================================================
patch('scripts/core/player_stats.gd',
      '## DEX 1 หน่วย เพิ่มความแม่น (HIT) กี่แต้ม\nconst HIT_PER_DEX := 1.5\n',
      '''## DEX 1 หน่วย เพิ่มความแม่น (HIT) กี่แต้ม
const HIT_PER_DEX := 1.5

# =========================================================
# ★★ ตารางผลของสเตตัส (รอบ 45) — แก้ตัวเลขตรงนี้ที่เดียว ★★
# ค่าที่ขึ้นกับ "อาชีพ" (hp_vit_percent / sp_int_percent / aspd_agi_percent) อยู่ในไฟล์ data/jobs/*.tres
# =========================================================
## STR 1 = ATK +1 · และทุก ๆ 10 STR ได้โบนัส (STR/10)² (10→+1 · 20→+4 · 30→+9)
const STR_ATK := 1.0
## AGI 1 = FLEE +1 · ASPD +aspd_agi_percent% (อาชีพ: นักดาบ 1.2%)
const AGI_FLEE := 1.0
## VIT 1 = DEF +0.5 (2 VIT = DEF 1) · HP +VIT_HP_FLAT · HP +hp_vit_percent% ของ HP พื้นฐาน (อาชีพ) · ฟื้น HP +0.05/วิ
const VIT_DEF := 0.5
const VIT_HP_FLAT := 6
const VIT_HP_REGEN := 0.05
## INT 1 = MATK +1 (+ (INT/7)²) · MDEF +0.5 · SP +INT_SP_FLAT · SP +sp_int_percent% ของ SP พื้นฐาน (อาชีพ) · ฟื้น SP +INT_SP_REGEN/วิ
const INT_MDEF := 0.5
const INT_SP_FLAT := 4
const INT_SP_REGEN := 0.12
## DEX 1 = HIT +1.5 (HIT_PER_DEX) · ATK +0.2 · ASPD +0.4%
const DEX_ATK := 0.2
const DEX_ASPD := 0.004
## LUK 1 = CRIT +0.3% · ATK +0.33
const LUK_CRIT := 0.3
const LUK_ATK := 1.0 / 3.0
''', marker='VIT_HP_FLAT')

patch('scripts/core/player_stats.gd',
      '''	var raw_hp := (j.hp_base + j.hp_per_level * (level - 1)) * (1.0 + total_vit * j.hp_vit_percent / 100.0)
	max_hp = maxi(1, int((raw_hp + _flat(&"max_hp")) * (1.0 + _pct(&"max_hp_percent") / 100.0)))

	var raw_sp := (j.sp_base + j.sp_per_level * (level - 1)) * (1.0 + total_int * j.sp_int_percent / 100.0)
	max_sp = maxi(1, int((raw_sp + _flat(&"max_sp")) * (1.0 + _pct(&"max_sp_percent") / 100.0)))
''', '''	# ★ รอบ 45: VIT เพิ่ม HP ทั้งแบบ % (อาชีพ) และแบบตรง ๆ (VIT_HP_FLAT ต่อแต้ม) ★
	var raw_hp := (j.hp_base + j.hp_per_level * (level - 1)) * (1.0 + total_vit * j.hp_vit_percent / 100.0) \\
		+ total_vit * VIT_HP_FLAT
	max_hp = maxi(1, int((raw_hp + _flat(&"max_hp")) * (1.0 + _pct(&"max_hp_percent") / 100.0)))

	# ★ รอบ 45: INT เพิ่ม SP ทั้งแบบ % (อาชีพ) และแบบตรง ๆ (INT_SP_FLAT ต่อแต้ม) ★
	var raw_sp := (j.sp_base + j.sp_per_level * (level - 1)) * (1.0 + total_int * j.sp_int_percent / 100.0) \\
		+ total_int * INT_SP_FLAT
	max_sp = maxi(1, int((raw_sp + _flat(&"max_sp")) * (1.0 + _pct(&"max_sp_percent") / 100.0)))
''', marker='total_vit * VIT_HP_FLAT')

patch('scripts/core/player_stats.gd',
      '''	var status_atk := float(level) / 4.0 \\
		+ total_str \\
		+ pow(floori(total_str / 10.0), 2) \\
		+ total_dex / 5.0 \\
		+ total_luk / 3.0
''', '''	var status_atk := float(level) / 4.0 \\
		+ total_str * STR_ATK \\
		+ pow(floori(total_str / 10.0), 2) \\
		+ total_dex * DEX_ATK \\
		+ total_luk * LUK_ATK
''', marker='total_str * STR_ATK')

patch('scripts/core/player_stats.gd',
      '''	def = maxi(0, int((floori(total_vit / 2.0) + _flat(&"def")) * j.def_mod * (1.0 + _pct(&"def_percent") / 100.0)))
	mdef = maxi(0, floori(total_int / 2.0) + _flat(&"mdef"))
''', '''	def = maxi(0, int((floori(total_vit * VIT_DEF) + _flat(&"def")) * j.def_mod * (1.0 + _pct(&"def_percent") / 100.0)))
	mdef = maxi(0, floori(total_int * INT_MDEF) + _flat(&"mdef"))
''', marker='total_vit * VIT_DEF')

patch('scripts/core/player_stats.gd',
      '''	flee = int((100 + level + total_agi + _flat(&"flee")) * j.flee_mod)
	crit = 1.0 + total_luk * 0.3 + _flat(&"crit")
''', '''	flee = int((100 + level + total_agi * AGI_FLEE + _flat(&"flee")) * j.flee_mod)
	crit = 1.0 + total_luk * LUK_CRIT + _flat(&"crit")
''', marker='total_agi * AGI_FLEE')

patch('scripts/core/player_stats.gd',
      '''	var aspd_raw := j.aspd_base * (1.0 + total_agi * j.aspd_agi_percent / 100.0 + total_dex * 0.004)
''', '''	var aspd_raw := j.aspd_base * (1.0 + total_agi * j.aspd_agi_percent / 100.0 + total_dex * DEX_ASPD)
''', marker='total_dex * DEX_ASPD')

patch('scripts/core/player_stats.gd',
      '''	hp_regen = 1.0 + max_hp / 200.0 + total_vit * 0.05
	sp_regen = 0.5 + max_sp / 300.0 + total_int * 0.03
''', '''	hp_regen = 1.0 + max_hp / 200.0 + total_vit * VIT_HP_REGEN
	# ★ รอบ 45: INT เพิ่มอัตราฟื้น SP ชัดขึ้น (0.03 → INT_SP_REGEN) ★
	sp_regen = 0.5 + max_sp / 300.0 + total_int * INT_SP_REGEN

	# ★ รอบ 45 — ค่า % จากของสวมใส่/การ์ด ★
	damage_percent = _pct(&"damage_percent")
	hp_drain_percent = _pct(&"hp_drain_percent")
	sp_drain_percent = _pct(&"sp_drain_percent")
''', marker='damage_percent = _pct')

patch('scripts/core/player_stats.gd',
      '''var hp_regen: float = 1.0        ## ต่อวินาที
var sp_regen: float = 0.5
''', '''var hp_regen: float = 1.0        ## ต่อวินาที
var sp_regen: float = 0.5
## ★ รอบ 45 ★ ดาเมจสุดท้าย +% (ของสวมใส่) · ดูดเลือด/มานา % ของดาเมจที่ทำได้
var damage_percent: float = 0.0
var hp_drain_percent: float = 0.0
var sp_drain_percent: float = 0.0
''', marker='var damage_percent')

# ---------- รีสเตตัส ----------
patch('scripts/core/player_stats.gd',
      '''# =========================================================
# เซฟ / โหลด
# =========================================================
func to_dict() -> Dictionary:''',
      '''## ★ รอบ 45 — รีเซ็ตสเตตัสทั้งหมด คืนแต้มให้ครบ ★ (คืนตามค่าใช้จ่ายจริงของทุกแต้มที่เคยอัพ)
func reset_stats() -> int:
	var refund := 0
	for stat in STAT_NAMES:
		var base := get_base_stat(stat)
		for c in range(1, base):
			refund += floori((c - 1) / 10.0) + 2
		_set_base_stat(stat, 1)
	stat_points += refund
	return refund


## รวมแต้มที่เคยอัพไปแล้ว (ไว้โชว์ในหน้าต่าง)
func spent_stat_points() -> int:
	var total := 0
	for stat in STAT_NAMES:
		var base := get_base_stat(stat)
		for c in range(1, base):
			total += floori((c - 1) / 10.0) + 2
	return total


# =========================================================
# เซฟ / โหลด
# =========================================================
func to_dict() -> Dictionary:''', marker='func reset_stats')

# =========================================================
# 2) item_data.gd — ช่อง % + ผลไอเทมพิเศษ
# =========================================================
patch('scripts/resources/item_data.gd',
      '''@export_group("Stat Bonus")
@export var bonus_str: int = 0''',
      '''# ★ รอบ 45 — โบนัสแบบ % ของของสวมใส่ (การ์ดก็ใส่ได้เพราะสืบทอดมา) ★
@export_group("Percent Bonus")
## ดาเมจสุดท้าย +% (ทั้งตีธรรมดาและสกิล)
@export var damage_percent: float = 0.0
## DEF +%
@export var defense_percent: float = 0.0
## HP สูงสุด +%
@export var hp_percent: float = 0.0
## SP สูงสุด +%
@export var sp_percent: float = 0.0
## ดูดเลือด: ได้ HP คืน = % ของดาเมจที่ทำกับมอน
@export var hp_drain_percent: float = 0.0
## ดูดมานา: ได้ SP คืน = % ของดาเมจที่ทำกับมอน
@export var sp_drain_percent: float = 0.0

@export_group("Stat Bonus")
@export var bonus_str: int = 0''', marker='hp_drain_percent')

patch('scripts/resources/item_data.gd',
      '''@export var heal_hp_percent: float = 0.0
@export var heal_sp_percent: float = 0.0
''', '''@export var heal_hp_percent: float = 0.0
@export var heal_sp_percent: float = 0.0
## ★ รอบ 45 — ไอเทมพิเศษ ★ reset_skills = รีสกิล · reset_stats = รีสเตตัส (ว่าง = ไม่มี)
@export var special_effect: StringName = &""
## ★ รอบ 45 — บัฟชั่วคราวจากไอเทม ★ ใส่ค่าเหมือนบัฟสกิล เช่น {"aspd_percent": 10.0} · buff_duration = วินาที
@export var buff_values: Dictionary = {}
@export var buff_duration: float = 0.0
''', marker='special_effect')

# =========================================================
# 3) equipment.gd — รวม %
# =========================================================
patch('scripts/core/equipment.gd',
      '''		for card in inst.card_list():
			for key in card.percent_effects.keys():
				var k := StringName(key)
				b[k] = float(b.get(k, 0.0)) + float(card.percent_effects[key])
	return b
''', '''		var d := inst.data()
		if d != null:
			_add_percent_bonus(b, d)
		for card in inst.card_list():
			for key in card.percent_effects.keys():
				var k := StringName(key)
				b[k] = float(b.get(k, 0.0)) + float(card.percent_effects[key])
			_add_percent_bonus(b, card)
	return b


## ★ รอบ 45 — ช่อง % ของ ItemData → คีย์ที่ PlayerStats ใช้ ★
static func _add_percent_bonus(b: Dictionary, d: ItemData) -> void:
	_add(b, &"damage_percent", d.damage_percent)
	_add(b, &"def_percent", d.defense_percent)
	_add(b, &"max_hp_percent", d.hp_percent)
	_add(b, &"max_sp_percent", d.sp_percent)
	_add(b, &"hp_drain_percent", d.hp_drain_percent)
	_add(b, &"sp_drain_percent", d.sp_drain_percent)
''', marker='_add_percent_bonus')

# =========================================================
# 4) combat.gd — ดาเมจ +%
# =========================================================
patch('scripts/core/combat.gd',
      '''	# --- สุ่มแกว่ง ---
	damage *= randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)

	result.damage = maxi(1, int(round(damage))) if elem > 0.0 else 0
	return result
''', '''	# --- สุ่มแกว่ง ---
	damage *= randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)

	# ★ รอบ 45 — ดาเมจสุดท้าย +% จากของสวมใส่ ★
	damage *= 1.0 + stats.damage_percent / 100.0

	result.damage = maxi(1, int(round(damage))) if elem > 0.0 else 0
	return result
''', marker='stats.damage_percent')

# =========================================================
# 5) monster_base.gd — ดูดเลือด/มานา
# =========================================================
patch('scripts/entities/monster_base.gd',
      '''	take_damage(int(result.damage), bool(result.crit), from_dir)
''', '''	take_damage(int(result.damage), bool(result.crit), from_dir)
	_drain_to_player(int(result.damage))


## ★ รอบ 45 — ดูดเลือด/ดูดมานา ★ ได้คืน = % ของดาเมจที่ทำได้ (ตัวเลขลอยสีเขียว/ฟ้าเล็ก ๆ)
func _drain_to_player(damage: int) -> void:
	if damage <= 0:
		return
	var st := PlayerState.stats
	if st == null:
		return
	if st.hp_drain_percent > 0.0:
		var hp_gain := maxi(1, int(damage * st.hp_drain_percent / 100.0))
		PlayerState.heal_hp(hp_gain, false)
	if st.sp_drain_percent > 0.0:
		var sp_gain := maxi(1, int(damage * st.sp_drain_percent / 100.0))
		PlayerState.restore_sp(sp_gain)
''', marker='_drain_to_player')

# =========================================================
# 6) player_state.gd — ใช้ไอเทมพิเศษ/บัฟ
# =========================================================
patch('scripts/core/player_state.gd',
      '''	var heal := data.heal_hp + int(stats.max_hp * data.heal_hp_percent / 100.0)
	var sp_heal := data.heal_sp + int(stats.max_sp * data.heal_sp_percent / 100.0)

	if heal > 0 and stats.hp >= stats.max_hp and sp_heal <= 0:
		Events.say("เลือดเต็มอยู่แล้ว")
		return false

	inventory.take_from_slot(inv_index, 1)
	if heal > 0:
		heal_hp(heal)
	if sp_heal > 0:
		restore_sp(sp_heal)
	Events.item_used.emit(data.id)
	return true
''', '''	# ★ รอบ 45 — ไอเทมพิเศษ: รีสกิล / รีสเตตัส ★
	if data.special_effect != &"":
		match data.special_effect:
			&"reset_skills":
				var before := stats.skill_points
				skills.reset(stats)
				inventory.take_from_slot(inv_index, 1)
				refresh()
				Events.say("รีเซ็ตสกิลแล้ว — ได้แต้มสกิลคืน %d แต้ม" % (stats.skill_points - before))
			&"reset_stats":
				var refund := stats.reset_stats()
				inventory.take_from_slot(inv_index, 1)
				refresh()
				Events.say("รีเซ็ตสเตตัสแล้ว — ได้แต้มสเตตัสคืน %d แต้ม" % refund)
			_:
				Events.say("ไอเทมนี้ยังไม่มีผล (%s)" % String(data.special_effect))
				return false
		Events.item_used.emit(data.id)
		return true

	var heal := data.heal_hp + int(stats.max_hp * data.heal_hp_percent / 100.0)
	var sp_heal := data.heal_sp + int(stats.max_sp * data.heal_sp_percent / 100.0)
	var has_buff := data.buff_duration > 0.0 and not data.buff_values.is_empty()

	if heal > 0 and stats.hp >= stats.max_hp and sp_heal <= 0 and not has_buff:
		Events.say("เลือดเต็มอยู่แล้ว")
		return false

	inventory.take_from_slot(inv_index, 1)
	if heal > 0:
		heal_hp(heal)
	if sp_heal > 0:
		restore_sp(sp_heal)
	if has_buff:
		apply_item_buff(data)
	Events.item_used.emit(data.id)
	return true


## ★ รอบ 45 — บัฟจากไอเทม ★ เก็บใน active_buffs เหมือนบัฟสกิล (คีย์ = "item_<id>") ใช้ซ้ำ = ต่ออายุใหม่
func apply_item_buff(data: ItemData) -> void:
	var key := StringName("item_" + String(data.id))
	active_buffs[key] = {
		"time_left": data.buff_duration,
		"values": data.buff_values.duplicate(),
		"level": 1,
		"name": data.display_name,
		"icon": data.icon,
	}
	refresh()
	Events.buff_changed.emit()
	Events.floating_text(Vector2.ZERO, data.display_name, Color("#ffd54a"), 20, 0)
''', marker='apply_item_buff')

# HUD: ชื่อบัฟจากไอเทม
patch('scripts/ui/hud.gd',
      '''			var s := GameData.get_skill(StringName(sid))
			var name_text: String = s.display_name if s != null else String(sid)
''', '''			var s := GameData.get_skill(StringName(sid))
			var name_text: String = s.display_name if s != null else String(PlayerState.active_buffs[sid].get("name", sid))
''', marker='active_buffs[sid].get("name"')
patch('scripts/ui/hud.gd',
      '''			var s := GameData.get_skill(StringName(child.name))
			var n: String = s.display_name if s != null else child.name
''', '''			var s := GameData.get_skill(StringName(child.name))
			var n: String = s.display_name if s != null else String(info.get("name", child.name))
''', marker='info.get("name"')
print('done')
