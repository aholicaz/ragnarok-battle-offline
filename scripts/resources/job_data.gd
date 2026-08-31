## JobData — ข้อมูลสายอาชีพ
## สร้างไฟล์ .tres ใหม่ 1 ไฟล์ต่อ 1 อาชีพ แล้วแก้ค่าใน Inspector ได้เลย
class_name JobData
extends Resource

@export var id: StringName = &"swordsman"
@export var display_name: String = "นักดาบ"
@export_multiline var description: String = ""

# =========================================================
# การเติบโตของ HP / SP
# MaxHP = (hp_base + hp_per_level * (Lv-1)) * (1 + Vit * hp_vit_percent / 100)
# =========================================================
@export_group("HP / SP Growth")
@export var hp_base: int = 40
@export var hp_per_level: float = 14.0
@export var hp_vit_percent: float = 1.0

@export var sp_base: int = 15
@export var sp_per_level: float = 3.0
@export var sp_int_percent: float = 1.0

# =========================================================
# ตัวคูณความสามารถของอาชีพ (1.0 = ปกติ)
# =========================================================
@export_group("Combat Modifier")
@export var atk_mod: float = 1.0
@export var matk_mod: float = 0.6
@export var def_mod: float = 1.0
@export var hit_mod: float = 1.0
@export var flee_mod: float = 1.0

## ความเร็วโจมตีพื้นฐาน (ครั้ง/วินาที) ตอน Agi = 0
@export var aspd_base: float = 1.1
## Agi ทุก 1 หน่วยเพิ่มความเร็วโจมตีกี่ %
@export var aspd_agi_percent: float = 1.2

# =========================================================
# อาวุธที่ใส่ได้ / สกิลของอาชีพ
# =========================================================
@export_group("Equipment & Skill")
@export var weapon_types: Array[StringName] = [&"sword"]
@export var skill_ids: Array[StringName] = []

@export_group("Job Change")
## ต้องเลเวลเท่าไหร่ถึงเปลี่ยนอาชีพต่อไปได้
@export var job_change_level: int = 30
## id ของอาชีพที่ต่อยอดได้ (เอาไว้ใช้ในอนาคต)
@export var next_job_ids: Array[StringName] = []
