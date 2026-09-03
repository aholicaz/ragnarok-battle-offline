## DragSlot — ปุ่มช่องไอเทมที่ "ลากไปวาง" ได้ (รอบ 45)
##
## ใช้ระบบ Drag & Drop ในตัวของ Godot (_get_drag_data / _can_drop_data / _drop_data)
## → กดค้างแล้วขยับ = เริ่มลาก (เมาส์และนิ้วบนจอสัมผัสใช้ได้เหมือนกัน) · ปล่อยบนช่องอื่น = วาง
## → ถ้าไม่ได้ลาก ปุ่มยังทำงานเป็นคลิกปกติ (signal pressed) เหมือนเดิม
##
## ของที่ลาก (payload) = Dictionary
##   {"kind": "inventory", "slot": ช่องในกระเป๋า}   หรือ   {"kind": "equip", "slot": Equipment.EquipSlot}
## ปุ่มแต่ละอันบอกว่าตัวเองคือช่องอะไรผ่าน kind/slot_index · เจ้าของหน้าต่างเป็นคนตัดสินใจตอนวาง (on_drop)
class_name DragSlot
extends Button

## "inventory" / "equip" / "trash" (ทิ้ง) / "any" (พื้นที่รับของ เช่น กรอบตัวละคร)
var kind: String = "inventory"
var slot_index: int = -1
## ฟังก์ชันคืน Texture2D ของไอคอนที่จะลอยตามเมาส์ (null = ไม่มีของ = ลากไม่ได้)
var drag_icon_func: Callable
## ฟังก์ชันตอนวางของ: func(payload: Dictionary, target: DragSlot) -> bool
var drop_func: Callable
## ฟังก์ชันเช็คว่ารับได้ไหม (ไว้ให้ Godot โชว์เคอร์เซอร์ถูก): func(payload, target) -> bool
var can_drop_func: Callable
## ขนาดไอคอนที่ลอยตามเมาส์
var preview_size: Vector2 = Vector2(48, 48)

## ★ สถิติไว้เทสต์ ★ ครั้งล่าสุดที่วางลงช่องนี้
var last_drop: Dictionary = {}


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	add_to_group("drag_slot")


func payload() -> Dictionary:
	return {"kind": kind, "slot": slot_index}


func _get_drag_data(_at: Vector2) -> Variant:
	if kind == "any" or kind == "trash":
		return null
	var tex: Texture2D = null
	if drag_icon_func.is_valid():
		tex = drag_icon_func.call()
	if tex == null:
		return null
	var pv := TextureRect.new()
	pv.texture = tex
	pv.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pv.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pv.custom_minimum_size = preview_size
	pv.size = preview_size
	pv.modulate.a = 0.85
	# ให้ไอคอนอยู่กึ่งกลางเคอร์เซอร์
	var holder := Control.new()
	holder.add_child(pv)
	pv.position = -preview_size * 0.5
	set_drag_preview(holder)
	return payload()


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not (data is Dictionary) or not data.has("kind"):
		return false
	if can_drop_func.is_valid():
		return bool(can_drop_func.call(data, self))
	return drop_func.is_valid()


func _drop_data(_at: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	last_drop = data
	if drop_func.is_valid():
		drop_func.call(data, self)


## ★ ไว้ให้เทสต์/สคริปต์จำลองการลาก-วางโดยไม่ต้องใช้เมาส์ ★
func simulate_drop_from(source: DragSlot) -> bool:
	var data = source._get_drag_data(Vector2.ZERO)
	if data == null:
		return false
	if not _can_drop_data(Vector2.ZERO, data):
		return false
	_drop_data(Vector2.ZERO, data)
	return true
