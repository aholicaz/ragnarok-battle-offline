## RefineSystem — ระบบตีบวก/อัพเกรดอุปกรณ์
## ปรับอัตราสำเร็จ ราคา และวัตถุดิบได้ที่ const ด้านล่าง
class_name RefineSystem
extends RefCounted

## โอกาสสำเร็จ (%) ของการตีจาก +index ไป +index+1
## index 0 = +0 -> +1, index 9 = +9 -> +10
const SUCCESS_RATE := [100.0, 100.0, 100.0, 90.0, 80.0, 65.0, 50.0, 35.0, 25.0, 15.0]

## ค่าธรรมเนียมซีนี = BASE_COST * (refine+1) * COST_GROWTH^refine
const BASE_COST := 500
const COST_GROWTH := 1.6

## วัตถุดิบที่ต้องใช้ (id ต้องมีไฟล์ .tres อยู่ใน res://data/items/)
const ORE_NORMAL := &"phracon"      # ใช้ตอน +0 ถึง +4
const ORE_HIGH := &"emveretarcon"   # ใช้ตอน +5 ขึ้นไป
const ORE_THRESHOLD := 5

## ตั้งแต่ +N ขึ้นไป ถ้าตีพลาดจะลดลง 1 ระดับ (ตั้ง 99 ถ้าไม่อยากให้ลด)
const DOWNGRADE_FROM := 7
## ตี +ต่อจาก DOWNGRADE_FROM แล้วพลาด มีโอกาสกี่ % ที่ของจะแตก (0 = ไม่แตกเลย)
const BREAK_CHANCE := 0.0


static func max_refine_of(inst: ItemInstance) -> int:
	var d := inst.data()
	return d.max_refine if d != null else 10


static func can_refine(inst: ItemInstance) -> bool:
	if inst == null:
		return false
	var d := inst.data()
	if d == null or not d.refinable:
		return false
	return inst.refine < d.max_refine


static func success_rate(inst: ItemInstance) -> float:
	if inst == null:
		return 0.0
	var idx: int = clampi(inst.refine, 0, SUCCESS_RATE.size() - 1)
	return SUCCESS_RATE[idx]


static func zeny_cost(inst: ItemInstance) -> int:
	if inst == null:
		return 0
	var d := inst.data()
	var value_factor: float = 1.0 + (d.buy_price / 2000.0 if d != null else 0.0)
	return int(BASE_COST * (inst.refine + 1) * pow(COST_GROWTH, inst.refine) * value_factor)


static func ore_needed(inst: ItemInstance) -> StringName:
	return ORE_HIGH if inst.refine >= ORE_THRESHOLD else ORE_NORMAL


static func ore_count(inst: ItemInstance) -> int:
	return 1


## ข้อมูลสรุปสำหรับโชว์ใน UI
static func preview(inst: ItemInstance) -> Dictionary:
	if inst == null:
		return {}
	var d := inst.data()
	return {
		"name": inst.display_name(),
		"current_refine": inst.refine,
		"next_refine": inst.refine + 1,
		"rate": success_rate(inst),
		"zeny": zeny_cost(inst),
		"ore_id": ore_needed(inst),
		"ore_count": ore_count(inst),
		"atk_gain": d.refine_atk_per_level if d != null else 0,
		"def_gain": d.refine_def_per_level if d != null else 0,
		"can_downgrade": inst.refine >= DOWNGRADE_FROM,
	}


## พยายามตีบวก 1 ครั้ง
## คืน { "ok": bool, "success": bool, "broke": bool, "message": String }
static func try_refine(inst: ItemInstance, inventory: Inventory, zeny_holder: Object) -> Dictionary:
	var out := {"ok": false, "success": false, "broke": false, "message": ""}

	if not can_refine(inst):
		out.message = "ไอเทมชิ้นนี้ตีบวกไม่ได้ หรือ +สูงสุดแล้ว"
		return out

	var cost := zeny_cost(inst)
	if zeny_holder.zeny < cost:
		out.message = "ซีนีไม่พอ (ต้องการ %d)" % cost
		return out

	var ore := ore_needed(inst)
	var need := ore_count(inst)
	if not inventory.has(ore, need):
		out.message = "ต้องใช้ %s x%d" % [GameData.item_name(ore), need]
		return out

	# หักค่าใช้จ่าย
	zeny_holder.add_zeny(-cost)
	inventory.remove_id(ore, need)
	out.ok = true

	var rate := success_rate(inst)
	if randf() * 100.0 < rate:
		inst.refine += 1
		out.success = true
		out.message = "ตีบวกสำเร็จ! กลายเป็น +%d" % inst.refine
	else:
		out.success = false
		if inst.refine >= DOWNGRADE_FROM:
			if BREAK_CHANCE > 0.0 and randf() * 100.0 < BREAK_CHANCE:
				out.broke = true
				out.message = "ตีบวกล้มเหลว อุปกรณ์แตก!"
			else:
				inst.refine = maxi(0, inst.refine - 1)
				out.message = "ตีบวกล้มเหลว ลดลงเหลือ +%d" % inst.refine
		else:
			out.message = "ตีบวกล้มเหลว แต่ของยังอยู่ (+%d)" % inst.refine

	Events.refine_result.emit(out.success, inst.display_name(), inst.refine)
	Events.inventory_changed.emit()
	Events.equipment_changed.emit()
	return out
