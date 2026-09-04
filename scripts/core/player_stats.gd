## PlayerStats — ค่าพลังตัวละคร (อิงสูตร Ragnarok แบบย่อ)
##
## วิธีทำงาน:
##   ค่าพื้นฐาน (base_str ฯลฯ) + โบนัสจากของสวมใส่ + โบนัสจากบัฟ/พาสซีฟ
##   -> recalculate() -> ได้ค่าสุดท้าย (atk, def, max_hp ...)
class_name PlayerStats
extends Resource

const STAT_NAMES := [&"str", &"agi", &"vit", &"int", &"dex", &"luk"]
const MAX_STAT := 99
const MAX_LEVEL := 99
## ★ เลเวลอาชีพสูงสุด ★ (Job Level แยกจาก Base Level)
const MAX_JOB_LEVEL := 50
## ★ ความเร็วเดิน/วิ่งพื้นฐาน ★ อยากให้ไวขึ้นอีก แก้เลขนี้
const BASE_MOVE_SPEED := 430.0
## DEX 1 หน่วย เพิ่มความแม่น (HIT) กี่แต้ม
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
## ★ รอบ 50 ★ DEX ทุก ๆ เท่านี้แต้ม = ลดคูลดาวน์สกิล 1% (0 = ปิดผล)
const DEX_PER_COOLDOWN := 5
## ลดคูลดาวน์ได้มากสุดกี่ % (กันสกิลร่ายรัวไม่มีคูลดาวน์)
const MAX_COOLDOWN_REDUCTION := 50.0
## LUK 1 = CRIT +0.3% · ATK +0.33
const LUK_CRIT := 0.3
const LUK_ATK := 1.0 / 3.0
## ★ รอบ 50 ★ STR ทุก ๆ เท่านี้แต้ม = ช่องกระเป๋า +1 (0 = ปิดผล)
const STR_PER_BAG_SLOT := 5

# =========================================================
# ค่าที่เซฟ
# =========================================================
@export var job_id: StringName = &"swordsman"
## ★ Base Level ★ — เพิ่มพลังชีวิต/พลังโจมตี และให้ "แต้มสเตตัส"
@export var level: int = 1
@export var exp_current: int = 0
@export var stat_points: int = 0
## ★ Job Level ★ — แยกหลอดกับ Base เลย และให้ "แต้มสกิล"
@export var job_level: int = 1
@export var job_exp_current: int = 0
@export var skill_points: int = 0

@export var base_str: int = 1
@export var base_agi: int = 1
@export var base_vit: int = 1
@export var base_int: int = 1
@export var base_dex: int = 1
@export var base_luk: int = 1

@export var hp: int = 40
@export var sp: int = 15

# =========================================================
# โบนัสจากภายนอก (ของสวมใส่ / บัฟ / พาสซีฟ)
# ให้ PlayerState เป็นคนเติมค่าเหล่านี้ก่อนเรียก recalculate()
# =========================================================
var flat_bonus: Dictionary = {}     # atk, matk, def, mdef, hit, flee, crit, max_hp, max_sp, str, agi, ...
var percent_bonus: Dictionary = {}  # atk_percent, def_percent, max_hp_percent, aspd_percent, move_speed_percent
var weapon_atk: int = 0

# =========================================================
# ค่าสุดท้ายที่คำนวณแล้ว (อ่านอย่างเดียว)
# =========================================================
var total_str: int = 1
var total_agi: int = 1
var total_vit: int = 1
var total_int: int = 1
var total_dex: int = 1
var total_luk: int = 1

var max_hp: int = 40
var max_sp: int = 15
var atk: int = 1
var matk: int = 1
var def: int = 0
var mdef: int = 0
var hit: int = 1
var flee: int = 1
var crit: float = 1.0
var crit_damage: float = 1.5
var aspd: float = 1.0            ## ครั้ง/วินาที
var move_speed: float = BASE_MOVE_SPEED
var hp_regen: float = 1.0        ## ต่อวินาที
var sp_regen: float = 0.5
## ★ รอบ 45 ★ ดาเมจสุดท้าย +% (ของสวมใส่) · ดูดเลือด/มานา % ของดาเมจที่ทำได้
var damage_percent: float = 0.0
var hp_drain_percent: float = 0.0
var sp_drain_percent: float = 0.0
## ★ รอบ 50 ★ ช่องกระเป๋าที่ได้เพิ่มจาก STR · ลดคูลดาวน์สกิล (%) จาก DEX + ของสวมใส่
var bag_bonus_slots: int = 0
var cooldown_reduction: float = 0.0


func job() -> JobData:
	var j := GameData.get_job(job_id)
	if j == null:
		j = JobData.new()   # ค่า default กันเกมพัง
	return j


# =========================================================
# คำนวณค่าสุดท้าย
# =========================================================
func recalculate(keep_ratio: bool = false) -> void:
	var j := job()

	var old_max_hp := max_hp
	var old_max_sp := max_sp

	total_str = clampi(base_str + _flat(&"str"), 1, 999)
	total_agi = clampi(base_agi + _flat(&"agi"), 1, 999)
	total_vit = clampi(base_vit + _flat(&"vit"), 1, 999)
	total_int = clampi(base_int + _flat(&"int"), 1, 999)
	total_dex = clampi(base_dex + _flat(&"dex"), 1, 999)
	total_luk = clampi(base_luk + _flat(&"luk"), 1, 999)

	# ---------- HP / SP ----------
	# ★ รอบ 45: VIT เพิ่ม HP ทั้งแบบ % (อาชีพ) และแบบตรง ๆ (VIT_HP_FLAT ต่อแต้ม) ★
	var raw_hp := (j.hp_base + j.hp_per_level * (level - 1)) * (1.0 + total_vit * j.hp_vit_percent / 100.0) \
		+ total_vit * VIT_HP_FLAT
	max_hp = maxi(1, int((raw_hp + _flat(&"max_hp")) * (1.0 + _pct(&"max_hp_percent") / 100.0)))

	# ★ รอบ 45: INT เพิ่ม SP ทั้งแบบ % (อาชีพ) และแบบตรง ๆ (INT_SP_FLAT ต่อแต้ม) ★
	var raw_sp := (j.sp_base + j.sp_per_level * (level - 1)) * (1.0 + total_int * j.sp_int_percent / 100.0) \
		+ total_int * INT_SP_FLAT
	max_sp = maxi(1, int((raw_sp + _flat(&"max_sp")) * (1.0 + _pct(&"max_sp_percent") / 100.0)))

	# ---------- ATK (สูตร RO ย่อ) ----------
	var status_atk := float(level) / 4.0 \
		+ total_str * STR_ATK \
		+ pow(floori(total_str / 10.0), 2) \
		+ total_dex * DEX_ATK \
		+ total_luk * LUK_ATK
	atk = maxi(1, int((status_atk * j.atk_mod + weapon_atk + _flat(&"atk")) * (1.0 + _pct(&"atk_percent") / 100.0)))

	# ---------- MATK ----------
	var status_matk := float(level) / 4.0 + total_int + pow(floori(total_int / 7.0), 2)
	matk = maxi(1, int((status_matk * j.matk_mod + _flat(&"matk")) * (1.0 + _pct(&"matk_percent") / 100.0)))

	# ---------- DEF / MDEF ----------
	def = maxi(0, int((floori(total_vit * VIT_DEF) + _flat(&"def")) * j.def_mod * (1.0 + _pct(&"def_percent") / 100.0)))
	mdef = maxi(0, floori(total_int * INT_MDEF) + _flat(&"mdef"))

	# ---------- HIT / FLEE / CRIT ----------
	# ★ DEX 1 หน่วย = ความแม่น +1.5% ★ (เดิม +1%) อยากให้ DEX คุ้มกว่านี้อีก แก้ HIT_PER_DEX
	hit = int((100 + level + total_dex * HIT_PER_DEX + _flat(&"hit")) * j.hit_mod)
	flee = int((100 + level + total_agi * AGI_FLEE + _flat(&"flee")) * j.flee_mod)
	crit = 1.0 + total_luk * LUK_CRIT + _flat(&"crit")
	crit_damage = 1.5 + _pct(&"crit_damage_percent") / 100.0

	# ---------- โบนัสจากเลเวลอาชีพ (Job Level) ----------
	# ทุก ๆ 1 job level: ATK +1 · HIT +1 · ทุก 2 ระดับได้ DEF +1
	var jb := job_level - 1
	if jb > 0:
		atk += jb
		hit += jb
		def += floori(jb / 2.0)

	# ---------- ASPD ----------
	var aspd_raw := j.aspd_base * (1.0 + total_agi * j.aspd_agi_percent / 100.0 + total_dex * DEX_ASPD)
	aspd = maxf(0.2, aspd_raw * (1.0 + (_pct(&"aspd_percent") + _flat(&"aspd_percent")) / 100.0))

	# ---------- ความเร็วเดิน ----------
	move_speed = BASE_MOVE_SPEED * (1.0 + _pct(&"move_speed_percent") / 100.0)

	# ---------- ฟื้นฟู ----------
	hp_regen = 1.0 + max_hp / 200.0 + total_vit * VIT_HP_REGEN
	# ★ รอบ 45: INT เพิ่มอัตราฟื้น SP ชัดขึ้น (0.03 → INT_SP_REGEN) ★
	sp_regen = 0.5 + max_sp / 300.0 + total_int * INT_SP_REGEN

	# ---------- ★ รอบ 50 — STR = ช่องกระเป๋า · DEX = ลดคูลดาวน์ ★ ----------
	bag_bonus_slots = 0 if STR_PER_BAG_SLOT <= 0 else floori(float(total_str) / STR_PER_BAG_SLOT)
	var cd_from_dex := 0.0 if DEX_PER_COOLDOWN <= 0 else floorf(float(total_dex) / DEX_PER_COOLDOWN)
	cooldown_reduction = clampf(cd_from_dex + _pct(&"cooldown_reduction_percent"),
		0.0, MAX_COOLDOWN_REDUCTION)

	# ★ รอบ 45 — ค่า % จากของสวมใส่/การ์ด ★
	damage_percent = _pct(&"damage_percent")
	hp_drain_percent = _pct(&"hp_drain_percent")
	sp_drain_percent = _pct(&"sp_drain_percent")

	# ---------- ปรับ HP/SP ปัจจุบัน ----------
	if keep_ratio and old_max_hp > 0:
		hp = int(round(float(hp) / old_max_hp * max_hp))
		sp = int(round(float(sp) / old_max_sp * max_sp))
	hp = clampi(hp, 0, max_hp)
	sp = clampi(sp, 0, max_sp)


func _flat(key: StringName) -> int:
	return int(flat_bonus.get(key, 0))


func _pct(key: StringName) -> float:
	return float(percent_bonus.get(key, 0.0))


## เวลาระหว่างการโจมตี 1 ครั้ง (วินาที)
func attack_interval() -> float:
	return 1.0 / maxf(aspd, 0.1)


# =========================================================
# ระบบเลเวล / ค่าประสบการณ์
# =========================================================
func exp_to_next() -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(round(35.0 * pow(level, 1.9)))


func add_exp(amount: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	var levels_gained := 0
	exp_current += amount
	while level < MAX_LEVEL and exp_current >= exp_to_next():
		exp_current -= exp_to_next()
		level += 1
		levels_gained += 1
		stat_points += 3 + floori(level / 5.0)
	if level >= MAX_LEVEL:
		exp_current = 0
	return levels_gained


# =========================================================
# ★ เลเวลอาชีพ (Job Level) — คนละหลอดกับ Base ★
# Job Level ขึ้น 1 ระดับ = ได้แต้มสกิล 1 แต้ม
# =========================================================
func job_exp_to_next() -> int:
	if job_level >= MAX_JOB_LEVEL:
		return 0
	return int(round(28.0 * pow(job_level, 1.85)))


func add_job_exp(amount: int) -> int:
	if job_level >= MAX_JOB_LEVEL:
		return 0
	var levels_gained := 0
	job_exp_current += amount
	while job_level < MAX_JOB_LEVEL and job_exp_current >= job_exp_to_next():
		job_exp_current -= job_exp_to_next()
		job_level += 1
		levels_gained += 1
		skill_points += 1
	if job_level >= MAX_JOB_LEVEL:
		job_exp_current = 0
	return levels_gained


# =========================================================
# การอัพสเตตัส
# =========================================================
func get_base_stat(stat: StringName) -> int:
	match stat:
		&"str": return base_str
		&"agi": return base_agi
		&"vit": return base_vit
		&"int": return base_int
		&"dex": return base_dex
		&"luk": return base_luk
	return 0


func get_total_stat(stat: StringName) -> int:
	match stat:
		&"str": return total_str
		&"agi": return total_agi
		&"vit": return total_vit
		&"int": return total_int
		&"dex": return total_dex
		&"luk": return total_luk
	return 0


func _set_base_stat(stat: StringName, value: int) -> void:
	match stat:
		&"str": base_str = value
		&"agi": base_agi = value
		&"vit": base_vit = value
		&"int": base_int = value
		&"dex": base_dex = value
		&"luk": base_luk = value


## ค่าใช้จ่ายในการอัพสเตตัสตัวถัดไป (สูตร RO)
func stat_cost(stat: StringName) -> int:
	var current := get_base_stat(stat)
	if current >= MAX_STAT:
		return -1
	return floori((current - 1) / 10.0) + 2


func can_raise_stat(stat: StringName) -> bool:
	var cost := stat_cost(stat)
	return cost > 0 and stat_points >= cost


func raise_stat(stat: StringName) -> bool:
	if not can_raise_stat(stat):
		return false
	stat_points -= stat_cost(stat)
	_set_base_stat(stat, get_base_stat(stat) + 1)
	return true


## ★ รอบ 45 — รีเซ็ตสเตตัสทั้งหมด คืนแต้มให้ครบ ★ (คืนตามค่าใช้จ่ายจริงของทุกแต้มที่เคยอัพ)
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
func to_dict() -> Dictionary:
	return {
		"job_id": String(job_id), "level": level, "exp": exp_current,
		"job_level": job_level, "job_exp": job_exp_current,
		"stat_points": stat_points, "skill_points": skill_points,
		"str": base_str, "agi": base_agi, "vit": base_vit,
		"int": base_int, "dex": base_dex, "luk": base_luk,
		"hp": hp, "sp": sp,
	}


func from_dict(d: Dictionary) -> void:
	job_id = StringName(d.get("job_id", "swordsman"))
	level = int(d.get("level", 1))
	exp_current = int(d.get("exp", 0))
	job_level = maxi(1, int(d.get("job_level", 1)))
	job_exp_current = int(d.get("job_exp", 0))
	stat_points = int(d.get("stat_points", 0))
	skill_points = int(d.get("skill_points", 0))
	base_str = int(d.get("str", 1))
	base_agi = int(d.get("agi", 1))
	base_vit = int(d.get("vit", 1))
	base_int = int(d.get("int", 1))
	base_dex = int(d.get("dex", 1))
	base_luk = int(d.get("luk", 1))
	hp = int(d.get("hp", 40))
	sp = int(d.get("sp", 15))
