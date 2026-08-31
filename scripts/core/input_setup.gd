## InputSetup — สร้างปุ่มควบคุมให้อัตโนมัติ ไม่ต้องไปตั้งใน Project Settings เอง
## ถ้าอยากเปลี่ยนปุ่ม แก้ที่ DEFAULT_KEYS ด้านล่าง หรือไปตั้งทับใน Input Map ก็ได้
class_name InputSetup
extends RefCounted

const DEFAULT_KEYS := {
	"attack": [KEY_X],
	"skill_1": [KEY_1],
	"skill_2": [KEY_2],
	"skill_3": [KEY_3],
	"skill_4": [KEY_4],
	"pickup": [KEY_Z],
	"quick_potion": [KEY_Q],
	"quick_sp_potion": [KEY_R],
	"interact": [KEY_F],
	"toggle_status": [KEY_C],
	"toggle_inventory": [KEY_I],
	"toggle_equipment": [KEY_E],
	"toggle_skills": [KEY_K],
	"toggle_cards": [KEY_V],
	"close_windows": [KEY_ESCAPE],
	"quick_save": [KEY_F5],
	"quick_load": [KEY_F9],
}

# ★ ปุ่มเมาส์ไม่ผูกไว้ใน InputMap แล้ว ★
# เพราะถ้าผูกไว้ คลิกโดนหน้าต่าง UI ก็จะนับเป็น "โจมตี" ไปด้วย
# ตอนนี้ย้ายไปรับที่ Player._unhandled_input() แทน (UI กินคลิกก่อนได้)
#   คลิกซ้าย = โจมตีปกติ   ·   คลิกขวา = สกิลช่องลัด 1


static func ensure() -> void:
	for action in DEFAULT_KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		# ถ้ามีปุ่มผูกไว้แล้ว (ผู้ใช้ตั้งเอง) ไม่ต้องยุ่ง
		if not InputMap.action_get_events(action).is_empty():
			continue
		for key in DEFAULT_KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
