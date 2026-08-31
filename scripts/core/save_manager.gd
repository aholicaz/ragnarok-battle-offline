## SaveManager — เซฟ/โหลดเกม (Autoload ชื่อ "SaveManager")
## หมายเหตุ: ไฟล์นี้ห้ามใส่ class_name เพราะจะชนกับชื่อ Autoload
extends Node

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_game(slot: int = 0) -> bool:
	var data := PlayerState.to_dict()
	data["saved_at"] = Time.get_datetime_string_from_system()

	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] เซฟไม่ได้: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	Events.say("บันทึกเกมแล้ว")
	return true


func load_game(slot: int = 0) -> bool:
	if not has_save(slot):
		return false
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("[SaveManager] ไฟล์เซฟเสียหาย")
		return false

	PlayerState.from_dict(parsed)
	Events.say("โหลดเกมแล้ว")
	return true


func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(slot_path(slot))


## ข้อมูลย่อสำหรับหน้าเลือกเซฟ
func slot_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var s: Dictionary = parsed.get("stats", {})
	return {
		"level": s.get("level", 1),
		"job": s.get("job_id", ""),
		"zeny": parsed.get("zeny", 0),
		"map": parsed.get("map", ""),
		"saved_at": parsed.get("saved_at", ""),
	}
