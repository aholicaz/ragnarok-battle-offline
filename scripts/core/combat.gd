## Combat — สูตรคำนวณดาเมจกลาง (เรียกแบบ static ได้เลย)
## อยากปรับความยากทั้งเกม แก้ที่นี่ที่เดียว
class_name Combat
extends RefCounted

## ค่าความสุ่มของดาเมจ (0.9 = ดาเมจแกว่ง ±10%)
const DAMAGE_VARIANCE := 0.12
# =========================================================
# ★ ความแม่นในการโจมตี — อยากให้ miss น้อยลง/มากขึ้น แก้ 4 ตัวนี้ ★
# สูตร: โอกาสเข้า % = ฐาน + HIT ของคนตี − FLEE ของเป้าหมาย
# =========================================================
## ฐานตอน "ผู้เล่นตีมอน" (ยิ่งสูง ยิ่ง miss น้อย)
const BASE_HIT_RATE := 85.0
## ฐานตอน "มอนตีผู้เล่น" (แยกกัน จะได้ปรับความแม่นของผู้เล่นโดยไม่ทำให้มอนแม่นขึ้นตาม)
const MONSTER_BASE_HIT_RATE := 72.0
## ต่ำสุด/สูงสุด — ไม่มีทางเข้า 100% เพื่อให้ยังมีลุ้นอยู่บ้าง
const MIN_HIT_RATE := 5.0
const MAX_HIT_RATE := 98.0

# =========================================================
# ★★ มอนเลเวลต่ำหลบเก่งเกินไป — ลดค่าหลบให้ (รอบ 29) ★★
#
# ช่วงต้นเกมผู้เล่นมี HIT น้อย (100 + Lv + Dex x 1.5) แต่มอนอย่างชอนชอน/ฮอร์เน็ต
# ค่าหลบสูงจนตี 10 ครั้งพลาด 4-5 ครั้ง เล่นแล้วหงุดหงิด
# เลยลดค่า FLEE ของมอนที่ "เลเวลต่ำกว่า LOW_LEVEL_FLEE_CAP" ลงตามสัดส่วนข้างล่าง
#
# ★ อยากให้ตีโดนง่ายขึ้นอีก ★ เพิ่ม LOW_LEVEL_FLEE_REDUCTION (0.20 = ลด 20%)
# ★ อยากให้ครอบคลุมมอนเลเวลสูงขึ้นด้วย ★ เพิ่ม LOW_LEVEL_FLEE_CAP
# =========================================================
## มอนที่เลเวล "ต่ำกว่า" ค่านี้ จะโดนลดค่าหลบ
const LOW_LEVEL_FLEE_CAP := 15
## ลดค่าหลบลงกี่ส่วน (0.20 = ลด 20%)
const LOW_LEVEL_FLEE_REDUCTION := 0.20

## ตารางธาตุ [ธาตุที่โจมตี][ธาตุของเป้าหมาย] = ตัวคูณดาเมจ
## ลำดับ: NEUTRAL FIRE WATER EARTH WIND POISON HOLY SHADOW GHOST UNDEAD
const ELEMENT_CHART := [
	[1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 0.25, 1.00],  # NEUTRAL
	[1.00, 0.25, 0.50, 1.50, 1.00, 1.25, 1.00, 1.00, 0.75, 1.50],  # FIRE
	[1.00, 1.50, 0.25, 1.00, 0.50, 1.00, 1.00, 1.00, 0.75, 1.00],  # WATER
	[1.00, 0.50, 1.00, 0.25, 1.50, 1.25, 1.00, 1.00, 0.75, 1.00],  # EARTH
	[1.00, 1.00, 1.50, 0.50, 0.25, 1.00, 1.00, 1.00, 0.75, 1.00],  # WIND
	[1.00, 1.00, 1.00, 1.00, 1.00, 0.25, 1.00, 0.50, 0.25, 0.25],  # POISON
	[1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 0.00, 1.25, 0.75, 1.50],  # HOLY
	[1.00, 1.00, 1.00, 1.00, 1.00, 0.50, 1.25, 0.00, 0.75, 0.50],  # SHADOW
	[0.25, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.00, 1.50, 1.00],  # GHOST
	[1.00, 1.00, 1.00, 1.00, 1.00, 0.50, 1.50, 0.50, 0.75, 0.00],  # UNDEAD
]


static func element_modifier(attack_element: int, defense_element: int) -> float:
	if attack_element < 0 or attack_element >= ELEMENT_CHART.size():
		return 1.0
	var row: Array = ELEMENT_CHART[attack_element]
	if defense_element < 0 or defense_element >= row.size():
		return 1.0
	return float(row[defense_element])


## โอกาสโจมตีเข้า (%) — ส่ง base มาเองได้ ถ้าไม่ส่งจะใช้ฐานของฝั่งผู้เล่น
static func hit_rate(attacker_hit: int, target_flee: int, base: float = BASE_HIT_RATE) -> float:
	return clampf(base + attacker_hit - target_flee, MIN_HIT_RATE, MAX_HIT_RATE)


## โอกาสที่ผู้เล่นจะตีมอนตัวนี้เข้า (%) — เอาไว้โชว์ในหน้าสเตตัสได้
static func player_hit_chance(stats: PlayerStats, monster: MonsterData) -> float:
	return hit_rate(stats.hit, monster_flee(monster))


## ค่า HIT/FLEE จริงของมอนสเตอร์
## MonsterData.hit / flee เป็น "ค่าโบนัส" ระบบจะบวก 100 + เลเวล ให้เอง
## เพื่อให้เทียบกับผู้เล่น (100 + Lv + Dex/Agi) ได้ตรง ๆ
static func monster_hit(monster: MonsterData) -> int:
	return 100 + monster.level + monster.hit


static func monster_flee(monster: MonsterData) -> int:
	var value: float = float(100 + monster.level + monster.flee)
	# ★ มอนเลเวลต่ำ หลบยากขึ้น ★ (ดูเหตุผลที่หัวไฟล์)
	if monster.level < LOW_LEVEL_FLEE_CAP:
		value *= (1.0 - LOW_LEVEL_FLEE_REDUCTION)
	return int(roundf(value))


## ตัวลดดาเมจจากค่า DEF — DEF 100 = ลดดาเมจครึ่งหนึ่ง
static func def_reduction(target_def: int) -> float:
	return 100.0 / (100.0 + maxf(0.0, float(target_def)))


# =========================================================
# ผู้เล่นตีมอนสเตอร์
# คืน { "damage": int, "crit": bool, "miss": bool, "element": float }
# =========================================================
static func player_hits_monster(
		stats: PlayerStats,
		monster: MonsterData,
		skill_mult: float = 1.0,
		use_matk: bool = false,
		attack_element: int = MonsterData.Element.NEUTRAL) -> Dictionary:

	var result := {"damage": 0, "crit": false, "miss": false, "element": 1.0}

	# --- พลาด ---
	if randf() * 100.0 > hit_rate(stats.hit, monster_flee(monster)):
		result.miss = true
		return result

	# --- คริติคอล ---
	var is_crit := randf() * 100.0 < stats.crit
	result.crit = is_crit

	var power := float(stats.matk if use_matk else stats.atk)
	var damage := power * skill_mult

	# --- ธาตุ ---
	var elem := element_modifier(attack_element, monster.element)
	result.element = elem
	damage *= elem

	# --- ป้องกัน (คริติคอลทะลุ DEF) ---
	if not is_crit:
		damage *= def_reduction(monster.mdef if use_matk else monster.def)
	else:
		damage *= stats.crit_damage

	# --- สุ่มแกว่ง ---
	damage *= randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)

	# ★ รอบ 45 — ดาเมจสุดท้าย +% จากของสวมใส่ ★
	damage *= 1.0 + stats.damage_percent / 100.0

	result.damage = maxi(1, int(round(damage))) if elem > 0.0 else 0
	return result


# =========================================================
# มอนสเตอร์ตีผู้เล่น
# =========================================================
static func monster_hits_player(monster: MonsterData, stats: PlayerStats) -> Dictionary:
	var result := {"damage": 0, "crit": false, "miss": false}

	if randf() * 100.0 > hit_rate(monster_hit(monster), stats.flee, MONSTER_BASE_HIT_RATE):
		result.miss = true
		return result

	var is_crit := randf() * 100.0 < monster.crit
	result.crit = is_crit

	var damage := float(monster.roll_attack())
	if not is_crit:
		damage *= def_reduction(stats.def)
	else:
		damage *= 1.4

	damage *= randf_range(1.0 - DAMAGE_VARIANCE, 1.0 + DAMAGE_VARIANCE)
	result.damage = maxi(1, int(round(damage)))
	return result


## สีของตัวเลขดาเมจ ใช้ร่วมกันทั้งเกม
static func damage_color(is_crit: bool, is_player_target: bool) -> Color:
	if is_player_target:
		return Color("#ff3030")
	return Color("#ffd54a") if is_crit else Color("#ffffff")
