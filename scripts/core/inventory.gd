## Inventory — ช่องเก็บของ
class_name Inventory
extends RefCounted

var size: int = 40
var slots: Array = []   # ItemInstance หรือ null


func _init(p_size: int = 40) -> void:
	size = p_size
	slots.resize(size)


func used_slots() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += 1
	return n


func is_full() -> bool:
	return used_slots() >= size


func first_empty() -> int:
	for i in range(size):
		if slots[i] == null:
			return i
	return -1


## ใส่ของเข้ากระเป๋า คืนค่าจำนวนที่ใส่ไม่ได้ (0 = ใส่ได้หมด)
func add(inst: ItemInstance) -> int:
	if inst == null or inst.count <= 0:
		return 0
	var data := inst.data()
	if data == null:
		push_warning("[Inventory] ไม่รู้จักไอเทม: " + String(inst.item_id))
		return inst.count

	var remaining := inst.count

	# กองรวมกับของเดิมก่อน
	if data.is_stackable():
		for i in range(size):
			var s: ItemInstance = slots[i]
			if s != null and s.same_kind_as(inst):
				var can_add: int = mini(remaining, data.max_stack - s.count)
				if can_add > 0:
					s.count += can_add
					remaining -= can_add
				if remaining <= 0:
					Events.inventory_changed.emit()
					Events.item_gained.emit(inst.item_id, inst.count)
					return 0

	# ใส่ช่องว่าง
	while remaining > 0:
		var idx := first_empty()
		if idx == -1:
			break
		if data.is_stackable():
			var put: int = mini(remaining, data.max_stack)
			slots[idx] = ItemInstance.create(inst.item_id, put, inst.refine)
			remaining -= put
		else:
			# ★ ของสวมใส่ต้องเก็บ "ชิ้นเดิม" ★
			# ไม่งั้นช่องการ์ด / การ์ดที่ใส่ไว้ / ค่าตีบวก จะหายตอนเก็บเข้ากระเป๋า
			if remaining == inst.count:
				inst.count = 1
				slots[idx] = inst
			else:
				var copy := ItemInstance.create(inst.item_id, 1, inst.refine, inst.slots)
				copy.cards = inst.cards.duplicate()
				slots[idx] = copy
			remaining -= 1

	Events.inventory_changed.emit()
	if remaining < inst.count:
		Events.item_gained.emit(inst.item_id, inst.count - remaining)
	return remaining


func add_id(item_id: StringName, count: int = 1, refine: int = 0) -> int:
	return add(ItemInstance.create(item_id, count, refine))


func count_of(item_id: StringName) -> int:
	var total := 0
	for s: ItemInstance in slots:
		if s != null and s.item_id == item_id:
			total += s.count
	return total


func has(item_id: StringName, count: int = 1) -> bool:
	return count_of(item_id) >= count


## เอาของออกตาม id คืน true ถ้าเอาออกครบ
func remove_id(item_id: StringName, count: int = 1) -> bool:
	if not has(item_id, count):
		return false
	var remaining := count
	for i in range(size):
		var s: ItemInstance = slots[i]
		if s == null or s.item_id != item_id:
			continue
		var take: int = mini(remaining, s.count)
		s.count -= take
		remaining -= take
		if s.count <= 0:
			slots[i] = null
		if remaining <= 0:
			break
	Events.inventory_changed.emit()
	return true


## เอาของออกจากช่องที่ระบุ คืน ItemInstance ที่เอาออกมา
func take_from_slot(index: int, count: int = 1) -> ItemInstance:
	if index < 0 or index >= size:
		return null
	var s: ItemInstance = slots[index]
	if s == null:
		return null
	var take: int = mini(count, s.count)
	var out := ItemInstance.create(s.item_id, take, s.refine)
	s.count -= take
	if s.count <= 0:
		slots[index] = null
	Events.inventory_changed.emit()
	return out


func get_slot(index: int) -> ItemInstance:
	if index < 0 or index >= size:
		return null
	return slots[index]


func set_slot(index: int, inst: ItemInstance) -> void:
	if index < 0 or index >= size:
		return
	slots[index] = inst
	Events.inventory_changed.emit()


func swap(a: int, b: int) -> void:
	if a < 0 or b < 0 or a >= size or b >= size:
		return
	var tmp = slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
	Events.inventory_changed.emit()


## เรียงของ: ประเภทเดียวกันอยู่ด้วยกัน ช่องว่างไปท้ายสุด
func sort_items() -> void:
	var list: Array = []
	for s in slots:
		if s != null:
			list.append(s)
	list.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		var da := a.data()
		var db := b.data()
		if da == null or db == null:
			return false
		if da.type != db.type:
			return da.type < db.type
		if a.item_id != b.item_id:
			return String(a.item_id) < String(b.item_id)
		return a.refine > b.refine
	)
	slots.clear()
	slots.resize(size)
	for i in range(mini(list.size(), size)):
		slots[i] = list[i]
	Events.inventory_changed.emit()


func to_array() -> Array:
	var out: Array = []
	for s: ItemInstance in slots:
		out.append(s.to_dict() if s != null else null)
	return out


func from_array(arr: Array) -> void:
	slots.clear()
	slots.resize(size)
	for i in range(mini(arr.size(), size)):
		var d = arr[i]
		if d is Dictionary:
			slots[i] = ItemInstance.from_dict(d)
	Events.inventory_changed.emit()
