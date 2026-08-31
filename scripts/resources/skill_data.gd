## SkillData — ข้อมูลสกิล 1 ตัว
## เพิ่มสกิลใหม่ = สร้าง .tres ใหม่ แล้วใส่ id ลงใน JobData.skill_ids
class_name SkillData
extends Resource

enum SkillType {
	ACTIVE_MELEE,  ## โจมตีระยะประชิดตรงหน้า
	ACTIVE_AOE,    ## โจมตีรอบตัว
	BUFF,          ## เพิ่มค่าพลังให้ตัวเอง
	HEAL,          ## ฟื้นเลือด
	PASSIVE,       ## ติดตัวถาวร ไม่ต้องกด
	## ★ พุ่งไปข้างหน้าแล้วฟันทุกตัวที่ขวางทาง ★ (ต่อท้ายเสมอ ห้ามสลับลำดับ
	## เพราะไฟล์ .tres เก็บค่า type เป็นตัวเลข)
	ACTIVE_DASH,
}

@export var id: StringName = &"bash"
@export var display_name: String = "Bash"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export var type: SkillType = SkillType.ACTIVE_MELEE
@export var max_level: int = 10
## อาชีพไหนเรียนได้ (ว่าง = ทุกอาชีพ)
@export var job_ids: Array[StringName] = [&"swordsman"]

@export_group("Requirement")
## ต้องเรียนสกิลนี้ถึงเลเวลนี้ก่อน เช่น {"bash": 5}
@export var required_skills: Dictionary = {}
@export var required_level: int = 1

@export_group("Cost — ต่อ 1 เลเวลสกิล")
## SP ที่ใช้ = sp_cost_base + sp_cost_per_level * (skill_lv - 1)
@export var sp_cost_base: int = 8
@export var sp_cost_per_level: float = 1.0
@export var cooldown: float = 1.0
## หน่วงก่อนดาเมจออก (ให้ตรงจังหวะอนิเมชัน)
@export var cast_windup: float = 0.15

@export_group("Damage — ต่อ 1 เลเวลสกิล")
## ตัวคูณดาเมจ = damage_mult_base + damage_mult_per_level * (skill_lv - 1)
## 1.0 = ดาเมจปกติ, 1.5 = 150%
@export var damage_mult_base: float = 1.3
@export var damage_mult_per_level: float = 0.2
## ตีกี่ครั้งต่อการใช้ 1 ครั้ง
@export var hit_count: int = 1
## ใช้ MATK แทน ATK ไหม
@export var use_matk: bool = false

## ท่าอนิเมชันตอนร่ายสกิลนี้ (เว้นว่าง = ใช้ท่าโจมตีปกติตามอาวุธที่ถือ)
@export var animation: StringName = &""

@export_group("Range")
@export var range_x: float = 130.0
@export var range_y: float = 80.0
## จำนวนเป้าหมายสูงสุด (สำหรับ AOE) 0 = ไม่จำกัด
@export var max_targets: int = 1

# =========================================================
# ★ สกิลพุ่ง (ACTIVE_DASH) ★
# ตัวละครพุ่งไปข้างหน้า มอนที่อยู่ในแนวพุ่งโดนดาเมจทุกตัว
# =========================================================
@export_group("พุ่ง (Dash)")
## พุ่งไปไกลกี่พิกเซล
@export var dash_distance: float = 300.0
## เพิ่มระยะพุ่งต่อ 1 เลเวลสกิล
@export var dash_distance_per_level: float = 15.0
## ความเร็วตอนพุ่ง (พิกเซล/วินาที)
@export var dash_speed: float = 1400.0
## ความสูงของแนวที่โดน (จากระดับเท้า)
@export var dash_range_y: float = 90.0
## มอนตัวเดิมโดนได้ครั้งเดียวต่อการพุ่ง 1 ครั้ง
@export var dash_hit_once: bool = true
## ชนกำแพงแล้วหยุดพุ่ง
@export var dash_stop_on_wall: bool = true

# =========================================================
# ★ เอฟเฟกต์สกิล (ภาพที่ใหญ่/ไกลเกินตัวละครได้) ★
#
# วิธีทำ: วาดเอฟเฟกต์เป็น SpriteFrames แยกอีกไฟล์ (ไม่ต้องยัดใน player_frames)
# ระบบจะสร้างโหนดใหม่ "ในโลก" ไม่ใช่ลูกของสไปรท์ตัวละคร
# เอฟเฟกต์เลยใหญ่แค่ไหน ไกลแค่ไหนก็ได้ ไม่ถูกกรอบตัวละครตัดทิ้ง
# =========================================================
@export_group("เอฟเฟกต์สกิล")
## SpriteFrames ของเอฟเฟกต์ (เว้นว่าง = ไม่มีเอฟเฟกต์)
@export var effect_frames: SpriteFrames
## ชื่อท่าใน SpriteFrames นั้น (เว้นว่าง = ใช้ท่าแรกที่เจอ)
@export var effect_anim: StringName = &""
## เยื้องจากตัวละครกี่พิกเซล — x จะกลับข้างให้เองตามที่ตัวละครหัน
@export var effect_offset: Vector2 = Vector2(90, -60)
## อยากให้เอฟเฟกต์สูงกี่พิกเซลบนจอ (0 = ใช้ Effect Scale แทน)
@export var effect_height: float = 0.0
@export var effect_scale: float = 1.0
## พุ่งออกไปข้างหน้ากี่พิกเซล/วินาที (0 = อยู่กับที่)
@export var effect_speed: float = 0.0
## ให้เอฟเฟกต์เกาะไปกับตัวละคร (ใช้กับสกิลพุ่ง)
@export var effect_follow: bool = false
## อยู่บนจอกี่วินาที (0 = จนกว่าอนิเมชันจะเล่นจบ)
@export var effect_life: float = 0.0
## หน่วงกี่วินาทีหลังเริ่มร่ายถึงจะโผล่
@export var effect_delay: float = 0.0
## ชั้นการวาด (มากกว่าตัวละคร = อยู่หน้า)
@export var effect_z: int = 60

@export_group("Buff / Heal")
@export var duration_base: float = 30.0
@export var duration_per_level: float = 10.0
## ค่าที่เพิ่มให้ตอนบัฟ เช่น {"atk_percent": 10.0, "max_hp_percent": 5.0}
## key ที่รองรับ: atk_percent, def_percent, aspd_percent, flee, hit, crit,
##               max_hp_percent, move_speed_percent
@export var buff_effects: Dictionary = {}
@export var buff_value_per_level: float = 2.0
## ฟื้นเลือด = heal_base + heal_per_level * (skill_lv - 1) + Int * heal_int_scale
@export var heal_base: float = 30.0
@export var heal_per_level: float = 25.0
@export var heal_int_scale: float = 2.0

@export_group("Passive Bonus — ค่าที่ได้ต่อ 1 เลเวลสกิล")
## key เดียวกับ buff_effects เช่น {"max_hp_percent": 3.0}
@export var passive_effects: Dictionary = {}


func sp_cost(skill_lv: int) -> int:
	return int(sp_cost_base + sp_cost_per_level * (skill_lv - 1))


func damage_mult(skill_lv: int) -> float:
	return damage_mult_base + damage_mult_per_level * (skill_lv - 1)


func duration(skill_lv: int) -> float:
	return duration_base + duration_per_level * (skill_lv - 1)


func heal_amount(skill_lv: int, int_stat: int) -> int:
	return int(heal_base + heal_per_level * (skill_lv - 1) + int_stat * heal_int_scale)


## ค่าบัฟจริงที่เลเวลนี้
func buff_values(skill_lv: int) -> Dictionary:
	var out := {}
	for key in buff_effects.keys():
		out[key] = float(buff_effects[key]) + buff_value_per_level * (skill_lv - 1)
	return out


func passive_values(skill_lv: int) -> Dictionary:
	var out := {}
	for key in passive_effects.keys():
		out[key] = float(passive_effects[key]) * skill_lv
	return out


func is_active() -> bool:
	return type != SkillType.PASSIVE


## ระยะพุ่งจริงที่เลเวลนี้
func dash_range(skill_lv: int) -> float:
	return dash_distance + dash_distance_per_level * (skill_lv - 1)


func has_effect() -> bool:
	return effect_frames != null


## ข้อความบอกเงื่อนไขการเรียน (ใช้โชว์ในหน้าต่างสกิล)
func requirement_text() -> String:
	var parts: Array[String] = []
	if required_level > 1:
		parts.append("Lv.%d" % required_level)
	for req_id in required_skills.keys():
		var rs := GameData.get_skill(StringName(req_id))
		var rname: String = rs.display_name if rs != null else String(req_id)
		# ตัดวงเล็บไทยออกให้สั้นลง เช่น "Bash (ฟันแรง)" -> "Bash"
		var cut := rname.find(" (")
		if cut > 0:
			rname = rname.substr(0, cut)
		parts.append("%s %d" % [rname, int(required_skills[req_id])])
	return " · ".join(parts)


## สกิลนี้ต่อยอดมาจากสกิลไหน (ตัวแรกในรายการ) — ใช้จัดผังต้นไม้สกิล
func parent_skill() -> StringName:
	for req_id in required_skills.keys():
		return StringName(req_id)
	return &""
