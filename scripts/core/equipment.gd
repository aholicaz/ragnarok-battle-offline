## Equipment — ช่องสวมใส่ชุดและอาวุธ (แบบ Ragnarok 8 ช่อง)
class_name Equipment
extends RefCounted

enum EquipSlot {
	WEAPON,
	OFFHAND,
	HEAD,
	ARMOR,
	GARMENT,
	SHOES,
	ACCESSORY_1,
	ACCESSORY_2,
}

const SLOT_NAMES := {
	EquipSlot.WEAPON: "อาวุธ",
	EquipSlot.OFFHAND: "มือรอง",
	EquipSlot.HEAD: "ศีรษะ",
	EquipSlot.ARMOR: "ชุดเกราะ",
	EquipSlot.GARMENT: "ผ้าคลุม",
	EquipSlot.SHOES: "รองเท้า",
	EquipSlot.ACCESSORY_1: "เครื่องประดับ 1",
	EquipSlot.ACCESSORY_2: "เครื่องประดับ 2",
}

var slots: Dictionary = {}   # EquipSlot -> ItemInstance


func _init() -> void:
	for s in EquipSlot.values():
		slots[s] = null


func get_item(slot: EquipSlot) -> ItemInstance:
	return slots.get(slot, null)


## ช่องสวมใส่ที่ไอเทมชิ้นนี้ลงได้ (คืน -1 ถ้าใส่ไม่ได้)
static func slot_for(data: ItemData, prefer_second_accessory: bool = false) -> int:
	match data.slot:
		ItemData.Slot.WEAPON: return EquipSlot.WEAPON
		ItemData.Slot.OFFHAND: return EquipSlot.OFFHAND
		ItemData.Slot.HEAD: return EquipSlot.HEAD
		ItemData.Slot.ARMOR: return EquipSlot.ARMOR
		ItemData.Slot.GARMENT: return EquipSlot.GARMENT
		ItemData.Slot.SHOES: return EquipSlot.SHOES
		ItemData.Slot.ACCESSORY:
			return EquipSlot.ACCESSORY_2 if prefer_second_accessory else EquipSlot.ACCESSORY_1
	return -1


## ใส่ของ คืน ItemInstance ของชิ้นเดิมที่ถูกถอดออก (null ถ้าไม่มี)
func equip(slot: EquipSlot, inst: ItemInstance) -> ItemInstance:
	var old: ItemInstance = slots.get(slot, null)
	slots[slot] = inst
	Events.equipment_changed.emit()
	return old


func unequip(slot: EquipSlot) -> ItemInstance:
	var old: ItemInstance = slots.get(slot, null)
	slots[slot] = null
	Events.equipment_changed.emit()
	return old


func weapon() -> ItemInstance:
	return slots.get(EquipSlot.WEAPON, null)


## ATK จากอาวุธ (รวมตีบวกแล้ว) — โบนัสจากการ์ดในอาวุธไปรวมใน collect_bonus
func weapon_atk() -> int:
	var w := weapon()
	return w.total_atk() if w != null else 0


## รวมโบนัสตัวเลขตรง ๆ จากของที่ใส่อยู่ + การ์ดที่อยู่ในของ
## -> Dictionary สำหรับ PlayerStats.flat_bonus
func collect_bonus() -> Dictionary:
	var b := {}

	for slot in slots.keys():
		var inst: ItemInstance = slots[slot]
		if inst == null:
			continue
		var d := inst.data()
		if d == null:
			continue

		# อาวุธคิด ATK แยกผ่าน weapon_atk() ไม่นับซ้ำตรงนี้
		_add_item_bonus(b, d, slot != EquipSlot.WEAPON)
		# โบนัสจากตีบวก (อาวุธคิด ATK ผ่าน weapon_atk แล้ว / เกราะเท่านั้นที่ได้ DEF)
		if slot != EquipSlot.WEAPON:
			_add(b, &"atk", inst.refine * d.refine_atk_per_level)
		if d.type == ItemData.Type.ARMOR:
			_add(b, &"def", inst.refine * d.refine_def_per_level)

		# ★ การ์ดที่ใส่อยู่ในชิ้นนี้ ★
		for card in inst.card_list():
			_add_item_bonus(b, card, true)

	return b


## รวมโบนัสแบบเปอร์เซ็นต์จากการ์ด -> PlayerStats.percent_bonus
func collect_percent_bonus() -> Dictionary:
	var b := {}
	for slot in slots.keys():
		var inst: ItemInstance = slots[slot]
		if inst == null:
			continue
		for card in inst.card_list():
			for key in card.percent_effects.keys():
				var k := StringName(key)
				b[k] = float(b.get(k, 0.0)) + float(card.percent_effects[key])
	return b


static func _add(b: Dictionary, key: StringName, value) -> void:
	var v := float(value)
	if not is_zero_approx(v):
		b[key] = float(b.get(key, 0.0)) + v


## เอาค่าโบนัสจาก ItemData (ใช้ได้ทั้งอุปกรณ์และการ์ด เพราะ CardData สืบทอดมา)
static func _add_item_bonus(b: Dictionary, d: ItemData, include_atk: bool) -> void:
	if include_atk:
		_add(b, &"atk", d.atk)
	_add(b, &"def", d.def)
	_add(b, &"matk", d.matk)
	_add(b, &"mdef", d.mdef)
	_add(b, &"hit", d.hit)
	_add(b, &"flee", d.flee)
	_add(b, &"crit", d.crit)
	_add(b, &"max_hp", d.max_hp)
	_add(b, &"max_sp", d.max_sp)
	_add(b, &"aspd_percent", d.aspd_percent)

	_add(b, &"str", d.bonus_str)
	_add(b, &"agi", d.bonus_agi)
	_add(b, &"vit", d.bonus_vit)
	_add(b, &"int", d.bonus_int)
	_add(b, &"dex", d.bonus_dex)
	_add(b, &"luk", d.bonus_luk)


func to_dict() -> Dictionary:
	var out := {}
	for slot in slots.keys():
		var inst: ItemInstance = slots[slot]
		out[str(slot)] = inst.to_dict() if inst != null else null
	return out


func from_dict(d: Dictionary) -> void:
	for key in d.keys():
		var slot := int(key)
		var v = d[key]
		slots[slot] = ItemInstance.from_dict(v) if v is Dictionary else null
	Events.equipment_changed.emit()
