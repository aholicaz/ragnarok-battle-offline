## CardData — การ์ดมอนสเตอร์ (สืบทอดจาก ItemData เลย การ์ดจึงเป็นไอเทมชิ้นหนึ่ง)
##
## เพิ่มการ์ดใหม่ = สร้างไฟล์ .tres ใหม่ใน res://data/cards/ ไม่ต้องเขียนโค้ด
## โบนัสแบบตัวเลขตรง ๆ (atk, def, bonus_str ...) ใช้ช่องที่สืบทอดมาจาก ItemData ได้เลย
class_name CardData
extends ItemData

## มอนสเตอร์เจ้าของการ์ดใบนี้ (ใช้ดึงรูปมาโชว์ในอัลบั้ม)
@export var monster_id: StringName = &""

## ใส่ได้กับอุปกรณ์ช่องไหน
## WEAPON=อาวุธ / OFFHAND=โล่ / HEAD=ศีรษะ / ARMOR=เกราะ / GARMENT=ผ้าคลุม / SHOES=รองเท้า / ACCESSORY=เครื่องประดับ
@export var fits_slot: ItemData.Slot = ItemData.Slot.WEAPON

## ★ ภาพการ์ดเต็มใบ ★ (ถ้าไม่ใส่ ระบบจะวาดกรอบการ์ดแล้วเอารูปมอนมาใส่ให้เอง)
@export var illustration: Texture2D

## คำอธิบายคุณสมบัติ (เว้นว่างไว้ ระบบจะสร้างข้อความให้เองจากค่าโบนัส)
@export_multiline var effect_text: String = ""

## โบนัสแบบเปอร์เซ็นต์ เช่น {"atk_percent": 5.0, "max_hp_percent": 3.0}
## key ที่รองรับ: atk_percent, matk_percent, def_percent, max_hp_percent,
##               max_sp_percent, aspd_percent, move_speed_percent, crit_damage_percent
@export var percent_effects: Dictionary = {}

## ระดับความหายาก 1-5 (ใช้เลือกสีกรอบการ์ด)
@export_range(1, 5) var rarity: int = 1


func monster() -> MonsterData:
	return GameData.get_monster(monster_id)


func slot_name() -> String:
	match fits_slot:
		ItemData.Slot.WEAPON: return "อาวุธ"
		ItemData.Slot.OFFHAND: return "โล่ / มือรอง"
		ItemData.Slot.HEAD: return "ศีรษะ"
		ItemData.Slot.ARMOR: return "ชุดเกราะ"
		ItemData.Slot.GARMENT: return "ผ้าคลุม"
		ItemData.Slot.SHOES: return "รองเท้า"
		ItemData.Slot.ACCESSORY: return "เครื่องประดับ"
	return "-"


## สีกรอบการ์ดตามความหายาก
func rarity_color() -> Color:
	match rarity:
		1: return Color("#9aa7bd")   # ธรรมดา
		2: return Color("#5ccf7a")   # ไม่ธรรมดา
		3: return Color("#4c9ce6")   # หายาก
		4: return Color("#b96bff")   # หายากมาก
		_: return Color("#ffb43a")   # ระดับตำนาน


func rarity_name() -> String:
	match rarity:
		1: return "ธรรมดา"
		2: return "ไม่ธรรมดา"
		3: return "หายาก"
		4: return "หายากมาก"
	return "ระดับตำนาน"


## สร้างข้อความคุณสมบัติจากค่าโบนัสที่ตั้งไว้
func describe() -> String:
	if effect_text != "":
		return effect_text

	var parts: Array[String] = []
	var add := func(label: String, value) -> void:
		if typeof(value) == TYPE_FLOAT:
			if not is_zero_approx(value):
				parts.append("%s %+.0f%%" % [label, value])
		elif int(value) != 0:
			parts.append("%s %+d" % [label, int(value)])

	add.call("STR", bonus_str)
	add.call("AGI", bonus_agi)
	add.call("VIT", bonus_vit)
	add.call("INT", bonus_int)
	add.call("DEX", bonus_dex)
	add.call("LUK", bonus_luk)
	add.call("ATK", atk)
	add.call("MATK", matk)
	add.call("DEF", def)
	add.call("MDEF", mdef)
	add.call("HIT", hit)
	add.call("FLEE", flee)
	add.call("CRIT", crit)
	add.call("MaxHP", max_hp)
	add.call("MaxSP", max_sp)

	const PERCENT_LABELS := {
		"atk_percent": "ATK", "matk_percent": "MATK", "def_percent": "DEF",
		"max_hp_percent": "MaxHP", "max_sp_percent": "MaxSP",
		"aspd_percent": "ความเร็วโจมตี", "move_speed_percent": "ความเร็วเดิน",
		"crit_damage_percent": "ดาเมจคริติคอล", "damage_percent": "ดาเมจ", "hp_drain_percent": "ดูดเลือด", "sp_drain_percent": "ดูดมานา",
	}
	for key in percent_effects.keys():
		var label: String = PERCENT_LABELS.get(String(key), String(key))
		parts.append("%s %+.0f%%" % [label, float(percent_effects[key])])

	if parts.is_empty():
		return "ยังไม่มีคุณสมบัติ"
	return "\n".join(parts)
