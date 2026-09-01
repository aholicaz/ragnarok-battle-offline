## SystemWindow — เมนูระบบ: เซฟเกม / โหลดเกม / เริ่มเกมใหม่ (กด Tab)
## มี 3 ช่องเซฟ เลือกได้ว่าจะเซฟช่องไหน
class_name SystemWindow
extends GameWindow

var _slot_rows: Array = []      # [{label, save_btn, load_btn, del_btn}]
var _status: Label
var _touch_btn: Button


func _ready() -> void:
	window_title = "เมนูระบบ"
	super._ready()
	custom_minimum_size = Vector2(420, 0)


func _build_content() -> void:
	content.add_child(UITheme.make_label(
		"เซฟเกมไว้กันหาย — เลือกช่องแล้วกดบันทึก", 12, UITheme.TEXT_DIM))

	for slot in range(SaveManager.SLOT_COUNT):
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UITheme.slot_style())
		content.add_child(panel)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		panel.add_child(row)

		var info := UITheme.make_label("ช่อง %d — ว่าง" % (slot + 1), 13, UITheme.TEXT)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)

		var s := slot
		var save_btn := UITheme.make_button("บันทึก", 74)
		save_btn.pressed.connect(func(): _do_save(s))
		row.add_child(save_btn)

		var load_btn := UITheme.make_button("โหลด", 66)
		load_btn.pressed.connect(func(): _do_load(s))
		row.add_child(load_btn)

		var del_btn := UITheme.make_button("ลบ", 48)
		del_btn.pressed.connect(func(): _do_delete(s))
		row.add_child(del_btn)

		_slot_rows.append({"info": info, "load": load_btn, "del": del_btn})

	content.add_child(UITheme.separator())

	# ---------- ★ ปุ่มจอสัมผัส (มือถือ) ★ ----------
	var touch_row := HBoxContainer.new()
	touch_row.add_theme_constant_override("separation", 6)
	content.add_child(touch_row)

	var touch_label := UITheme.make_label("ปุ่มจอสัมผัส (มือถือ)", 13, UITheme.TEXT)
	touch_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	touch_row.add_child(touch_label)

	_touch_btn = UITheme.make_button("", 150)
	_touch_btn.pressed.connect(_cycle_touch_mode)
	touch_row.add_child(_touch_btn)
	_refresh_touch_button()

	content.add_child(UITheme.make_label(
		"อัตโนมัติ = โผล่เองเมื่อเล่นบนจอสัมผัส · กดปุ่มนี้เพื่อลองบนคอมได้",
		11, UITheme.TEXT_DIM))

	content.add_child(UITheme.separator())

	var new_btn := UITheme.make_button("เริ่มเกมใหม่ (ข้อมูลปัจจุบันจะหายไป)", 380)
	new_btn.add_theme_color_override("font_color", Color("#ff9a9a"))
	new_btn.pressed.connect(_do_new_game)
	content.add_child(new_btn)

	var title_btn := UITheme.make_button("กลับหน้าหลัก (อย่าลืมบันทึกก่อน)", 380)
	title_btn.pressed.connect(_do_go_title)
	content.add_child(title_btn)

	_status = UITheme.make_label("", 12, UITheme.TEXT_DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)


# =========================================================
# ปุ่มต่าง ๆ
# =========================================================
func _do_go_title() -> void:
	var ok: bool = await UI.ask("กลับหน้าหลัก", "ข้อมูลที่ยังไม่ได้บันทึกจะหายไป\nกลับหน้าหลักหรือไม่?", "กลับ", "ยังก่อน")
	if ok:
		Game.go_title()


func _do_save(slot: int) -> void:
	PlayerState.current_map_id = _current_map_id()
	if SaveManager.save_game(slot):
		_say("บันทึกลงช่อง %d แล้ว" % (slot + 1))
	else:
		_say("บันทึกไม่สำเร็จ")
	refresh()


func _do_load(slot: int) -> void:
	if not SaveManager.has_save(slot):
		_say("ช่อง %d ยังไม่มีข้อมูลเซฟ" % (slot + 1))
		return
	var ok: bool = await UI.ask("โหลดเกม",
		"โหลดข้อมูลจากช่อง %d?\nความคืบหน้าที่ยังไม่ได้เซฟจะหายไป" % (slot + 1),
		"โหลดเลย", "ยกเลิก")
	if not ok:
		return
	if SaveManager.load_game(slot):
		hide_window()
		Game.change_map(PlayerState.current_map_id, &"default")
	else:
		_say("ไฟล์เซฟเสียหาย โหลดไม่ได้")


func _do_delete(slot: int) -> void:
	if not SaveManager.has_save(slot):
		return
	var ok: bool = await UI.ask("ลบเซฟ",
		"ลบข้อมูลในช่อง %d ทิ้ง?" % (slot + 1), "ลบเลย", "ยกเลิก")
	if ok:
		SaveManager.delete_save(slot)
		_say("ลบช่อง %d แล้ว" % (slot + 1))
		refresh()


func _do_new_game() -> void:
	var ok: bool = await UI.ask("เริ่มเกมใหม่",
		"เริ่มใหม่ตั้งแต่ต้น?\nตัวละคร ของ และความคืบหน้าปัจจุบันจะหายทั้งหมด\n(ไฟล์เซฟที่บันทึกไว้ยังอยู่)",
		"เริ่มใหม่", "ยกเลิก")
	if not ok:
		return
	hide_window()
	PlayerState.new_game()
	Game.change_map(PlayerState.current_map_id, &"default")
	Events.say("เริ่มเกมใหม่แล้ว")


func _current_map_id() -> StringName:
	var scene := get_tree().current_scene
	if scene != null and "map_id" in scene:
		return scene.map_id
	return PlayerState.current_map_id


func _say(text: String) -> void:
	if _status != null:
		_status.text = text
	Events.say(text)


func refresh() -> void:
	for slot in range(_slot_rows.size()):
		var row: Dictionary = _slot_rows[slot]
		var has: bool = SaveManager.has_save(slot)
		if has:
			var d: Dictionary = SaveManager.slot_info(slot)
			row["info"].text = "ช่อง %d — Lv.%s  %s" % [
				slot + 1, str(d.get("level", "?")), str(d.get("saved_at", ""))]
			row["info"].add_theme_color_override("font_color", UITheme.TEXT)
		else:
			row["info"].text = "ช่อง %d — ว่าง" % (slot + 1)
			row["info"].add_theme_color_override("font_color", UITheme.TEXT_DIM)
		row["load"].disabled = not has
		row["del"].disabled = not has


# =========================================================
# ★ ปุ่มจอสัมผัส ★ อัตโนมัติ -> เปิดตลอด -> ปิด -> วนกลับ
# =========================================================
func _cycle_touch_mode() -> void:
	if UI.touch == null:
		return
	var next: int = (int(UI.touch.mode) + 1) % 3
	UI.touch.set_mode(next as TouchControls.Mode)
	_refresh_touch_button()
	Events.say("ปุ่มจอสัมผัส: %s" % UI.touch.mode_text())


func _refresh_touch_button() -> void:
	if _touch_btn == null or UI.touch == null:
		return
	_touch_btn.text = UI.touch.mode_text()
