## DropEntry — 1 บรรทัดในตารางดรอปของมอนสเตอร์
class_name DropEntry
extends Resource

@export var item_id: StringName = &""
## โอกาสดรอปเป็น % (0.0 - 100.0) เช่น 12.5 = 12.5%
@export_range(0.0, 100.0, 0.01) var chance: float = 10.0
@export var min_count: int = 1
@export var max_count: int = 1
## ถ้าเป็นของสวมใส่ที่ตีบวกได้ ให้สุ่มบวกในช่วงนี้
@export var min_refine: int = 0
@export var max_refine: int = 0


func roll() -> ItemInstance:
	if randf() * 100.0 > chance:
		return null
	var amount := randi_range(min_count, max(min_count, max_count))
	var refine := randi_range(min_refine, max(min_refine, max_refine))
	# ★ ของที่ดรอปจากมอนเท่านั้นที่มีช่องการ์ดติดมา ★
	return ItemInstance.create_drop(item_id, amount, refine)
