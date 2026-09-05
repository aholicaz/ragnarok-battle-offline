## SocketSystem — ระบบ "เจาะรูการ์ด" ให้ของสวมใส่ที่ไม่มีรู (รอบ 56)
##
## ★★ ปรับเงื่อนไขทั้งหมดที่ตาราง TIERS ข้างล่างที่เดียว ★★
##
## หลักการ: ของที่ซื้อจากร้าน (slots = 0) เอามาเจาะรูเองได้ โดยจ่ายวัตถุดิบ + ซีนี
## ของที่ดรอปจากมอนมีรูติดมาอยู่แล้ว (slots > 0) จะเจาะซ้ำไม่ได้
##
## จำนวนรูที่ได้ = card_slots ของไอเทมชนิดนั้น (1 หรือ 2 รู)
## ไอเทมที่เจาะได้ 2 รู ใช้วัตถุดิบและซีนี "เท่าตัว"
class_name SocketSystem
extends RefCounted

## ★ ตารางเงื่อนไขการเจาะ ★ ดูจาก required_level ของไอเทม
##   min_level/max_level  ช่วงเลเวลไอเทมที่เจาะได้
##   ore / ore_count      วัตถุดิบต่อ 1 รู
##   zeny                 ค่าเจาะต่อ 1 รู
##   rate                 โอกาสสำเร็จ (%)
##   need_duplicate       ต้องมีไอเทมชนิดเดียวกันอีก 1 ชิ้นไหม (ถูกใช้หมดไม่ว่าสำเร็จหรือไม่)
##   destroy_on_fail      เจาะไม่ติดแล้วของหายไหม
const TIERS := [
	{
		"name": "ของเลเวล 1-30",
		"min_level": 1, "max_level": 30,
		"ore": &"phracon", "ore_count": 10,
		"zeny": 15000, "rate": 70.0,
		"need_duplicate": true, "destroy_on_fail": true,
	},
	{
		"name": "ของเลเวล 40-70",
		"min_level": 40, "max_level": 70,
		"ore": &"emveretarcon", "ore_count": 10,
		"zeny": 50000, "rate": 60.0,
		"need_duplicate": false, "destroy_on_fail": true,
	},
]


## เงื่อนไขของไอเทมชิ้นนี้ (คืน {} ถ้าเลเวลไม่อยู่ในช่วงไหนเลย เช่นเลเวล 31-39)
static func tier_for(item: ItemData) -> Dictionary:
	if item == null:
		return {}
	for t in TIERS:
		if item.required_level >= int(t.min_level) and item.required_level <= int(t.max_level):
			return t
	return {}


## จำนวนรูที่จะได้ถ้าเจาะสำเร็จ
static func slots_gain(item: ItemData) -> int:
	return item.card_slots if item != null else 0


## เจาะได้ไหม (ไม่สนว่าของ/เงินพอหรือยัง — อันนั้นดูที่ requirements())
static func can_punch(inst: ItemInstance) -> bool:
	return reason_cannot_punch(inst) == ""


## เหตุผลที่เจาะไม่ได้ ("" = เจาะได้)
static func reason_cannot_punch(inst: ItemInstance) -> String:
	if inst == null:
		return "ยังไม่ได้เลือกไอเทม"
	var d := inst.data()
	if d == null or not d.is_equipment():
		return "เจาะรูได้เฉพาะของสวมใส่"
	if d.card_slots <= 0:
		return "ไอเทมชนิดนี้ใส่การ์ดไม่ได้เลย (เจาะรูไม่ได้)"
	if inst.slots > 0:
		return "ชิ้นนี้มีรูอยู่แล้ว %d รู" % inst.slots
	if tier_for(d).is_empty():
		return "ของเลเวล %d ยังเจาะรูไม่ได้ (รับเฉพาะเลเวล 1-30 และ 40-70)" % d.required_level
	return ""


## ของ/เงินที่ต้องใช้ + โอกาสสำเร็จ ของไอเทมชิ้นนี้
## คืน {} ถ้าเจาะไม่ได้
static func requirements(inst: ItemInstance) -> Dictionary:
	if not can_punch(inst):
		return {}
	var d := inst.data()
	var t := tier_for(d)
	var n: int = slots_gain(d)
	return {
		"tier_name": String(t.name),
		"slots": n,
		"ore_id": StringName(t.ore),
		"ore_count": int(t.ore_count) * n,
		"zeny": int(t.zeny) * n,
		"rate": float(t.rate),
		"need_duplicate": bool(t.need_duplicate),
		"destroy_on_fail": bool(t.destroy_on_fail),
	}


## หาช่องกระเป๋าที่มี "ไอเทมชนิดเดียวกัน" ไว้ใช้เป็นวัตถุดิบ
## ข้ามชิ้นที่กำลังจะเจาะ · ไม่เอาชิ้นที่มีการ์ด/มีรู · เลือกชิ้นที่ + น้อยสุดก่อน
static func find_duplicate(inst: ItemInstance, inventory: Inventory) -> int:
	if inst == null or inventory == null:
		return -1
	var best := -1
	var best_refine := 999
	for i in range(inventory.size):
		var other: ItemInstance = inventory.get_slot(i)
		if other == null or other == inst:
			continue
		if other.item_id != inst.item_id:
			continue
		if other.slots > 0 or not other.cards.is_empty():
			continue
		if other.refine < best_refine:
			best_refine = other.refine
			best = i
	return best


## ตรวจว่าของ/เงินครบไหม — คืน { "ok": bool, "message": String }
static func check(inst: ItemInstance, inventory: Inventory, zeny_holder: Object) -> Dictionary:
	var why := reason_cannot_punch(inst)
	if why != "":
		return {"ok": false, "message": why}
	var req := requirements(inst)
	if zeny_holder.zeny < int(req.zeny):
		return {"ok": false, "message": "ซีนีไม่พอ (ต้องการ %d)" % int(req.zeny)}
	if inventory.count_of(req.ore_id) < int(req.ore_count):
		return {"ok": false, "message": "ต้องใช้ %s x%d" % [GameData.item_name(req.ore_id), int(req.ore_count)]}
	if bool(req.need_duplicate) and find_duplicate(inst, inventory) < 0:
		return {"ok": false, "message": "ต้องมี %s อีก 1 ชิ้นในกระเป๋า (ชิ้นที่ไม่มีรู/ไม่มีการ์ด)" % GameData.item_name(inst.item_id)}
	return {"ok": true, "message": ""}


## ★ เจาะจริง ★
## คืน { "ok": bool, "success": bool, "destroyed": bool, "slots": int, "message": String }
##   ok = จ่ายค่าใช้จ่ายแล้วได้ลุ้นจริง (false = เงื่อนไขไม่ครบ ไม่ถูกหักอะไรเลย)
##   destroyed = ของหาย → ผู้เรียกต้องเอาออกจากช่องเอง
static func try_punch(inst: ItemInstance, inventory: Inventory, zeny_holder: Object) -> Dictionary:
	var out := {"ok": false, "success": false, "destroyed": false, "slots": 0, "message": ""}

	var pre := check(inst, inventory, zeny_holder)
	if not bool(pre.ok):
		out.message = String(pre.message)
		return out

	var req := requirements(inst)
	var item_name := inst.display_name()

	# ---------- หักค่าใช้จ่าย (หักทั้งสำเร็จและล้มเหลว) ----------
	if bool(req.need_duplicate):
		var dup := find_duplicate(inst, inventory)
		if dup < 0:
			out.message = "หาไอเทมชิ้นที่สองไม่เจอ"
			return out
		inventory.take_from_slot(dup, 1)
	inventory.remove_id(req.ore_id, int(req.ore_count))
	zeny_holder.add_zeny(-int(req.zeny))
	out.ok = true

	# ---------- ลุ้น ----------
	if randf() * 100.0 < float(req.rate):
		inst.slots = int(req.slots)
		out.success = true
		out.slots = inst.slots
		out.message = "เจาะรูสำเร็จ! %s มี %d รูแล้ว" % [item_name, inst.slots]
	else:
		out.success = false
		out.destroyed = bool(req.destroy_on_fail)
		out.message = "เจาะไม่ติด — %s แตกหายไป" % item_name if out.destroyed \
			else "เจาะไม่ติด แต่ %s ยังอยู่" % item_name

	Events.socket_result.emit(out.success, item_name, out.slots)
	Events.inventory_changed.emit()
	Events.equipment_changed.emit()
	return out


## ข้อมูลสรุปไว้โชว์ใน UI
static func preview(inst: ItemInstance, inventory: Inventory) -> Dictionary:
	var req := requirements(inst)
	if req.is_empty():
		return {}
	req["name"] = inst.display_name()
	req["have_ore"] = inventory.count_of(req.ore_id)
	req["ore_name"] = GameData.item_name(req.ore_id)
	req["dup_index"] = find_duplicate(inst, inventory) if bool(req.need_duplicate) else -1
	return req
