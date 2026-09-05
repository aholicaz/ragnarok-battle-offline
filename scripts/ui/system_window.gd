## SystemWindow — เมนูระบบ: เซฟเกม / โหลดเกม / เริ่มเกมใหม่ (กด Tab)
## มี 3 ช่องเซฟ เลือกได้ว่าจะเซฟช่องไหน
class_name SystemWindow
extends GameWindow

var _slot_rows: Array = []      # [{label, save_btn, load_btn, del_btn}]
var _status: Label
var _touch_btn: Button
## ★ รอบ 52 — ระดับเสียงเพลง ★
var _music_slider: HSlider
var _music_label: Label
var _music_btn: Button
var _sfx_slider: HSlider
var _sfx_label: Label
var _sfx_btn: Button
var _voice_slider: HSlider
var _voice_label: Label
var _voice_btn: Button


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

	# ---------- ★ รอบ 52 — เพลงประจำแมพ ★ ----------
	var music_row := HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 6)
	content.add_child(music_row)

	_music_label = UITheme.make_label("เพลง", 13, UITheme.TEXT)
	_music_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_row.add_child(_music_label)

	_music_slider = HSlider.new()
	_music_slider.min_value = 0.0
	_music_slider.max_value = 100.0
	_music_slider.step = 5.0
	_music_slider.custom_minimum_size = Vector2(150, 20)
	_music_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_music_slider.value_changed.connect(_on_music_volume)
	music_row.add_child(_music_slider)

	_music_btn = UITheme.make_button("", 70)
	_music_btn.pressed.connect(_toggle_music)
	music_row.add_child(_music_btn)
	_refresh_music()
	visibility_changed.connect(_refresh_music)    # เปิดเมนูทีไร อัปเดตชื่อเพลงที่เล่นอยู่

	content.add_child(UITheme.make_label(
		"เพลงเปลี่ยนตามแมพเอง — วางไฟล์ Sprites/music/<ชื่อแมพ>.mp3 แล้วเล่นได้เลย",
		11, UITheme.TEXT_DIM))

	# ---------- ★ รอบ 57 — เสียงเอฟเฟกต์ ★ ----------
	var sfx_row := HBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 6)
	content.add_child(sfx_row)

	_sfx_label = UITheme.make_label("เสียงเอฟเฟกต์", 13, UITheme.TEXT)
	_sfx_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_row.add_child(_sfx_label)

	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 100.0
	_sfx_slider.step = 5.0
	_sfx_slider.custom_minimum_size = Vector2(150, 20)
	_sfx_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sfx_slider.value_changed.connect(_on_sfx_volume)
	sfx_row.add_child(_sfx_slider)

	_sfx_btn = UITheme.make_button("", 70)
	_sfx_btn.pressed.connect(_toggle_sfx)
	sfx_row.add_child(_sfx_btn)
	_refresh_sfx()
	visibility_changed.connect(_refresh_sfx)

	content.add_child(UITheme.make_label(
		"เสียงฟันดาบ/สกิล — วางไฟล์ Sprites/sfx/<ชื่อ>.ogg (attack_blade = ดาบทุกเล่ม)",
		11, UITheme.TEXT_DIM))

	# ---------- ★ รอบ 59 — เสียงพากย์ NPC ★ ----------
	var voice_row := HBoxContainer.new()
	voice_row.add_theme_constant_override("separation", 6)
	content.add_child(voice_row)

	_voice_label = UITheme.make_label("เสียงพากย์ NPC", 13, UITheme.TEXT)
	_voice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	voice_row.add_child(_voice_label)

	_voice_slider = HSlider.new()
	_voice_slider.min_value = 0.0
	_voice_slider.max_value = 100.0
	_voice_slider.step = 5.0
	_voice_slider.custom_minimum_size = Vector2(150, 20)
	_voice_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_voice_slider.value_changed.connect(_on_voice_volume)
	voice_row.add_child(_voice_slider)

	_voice_btn = UITheme.make_button("", 70)
	_voice_btn.pressed.connect(_toggle_voice)
	voice_row.add_child(_voice_btn)
	_refresh_voice()
	visibility_changed.connect(_refresh_voice)

	content.add_child(UITheme.make_label(
		"เสียงพากย์ — วางไฟล์ Sprites/voice/<voice_id>/<ประโยค>.ogg (ดูรายชื่อใน dump_npc_lines.py)",
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


# =========================================================
# ★ รอบ 52 — เพลง ★
# =========================================================
func _on_music_volume(v: float) -> void:
	if Game.music == null:
		return
	Game.music.set_volume(v / 100.0)
	_refresh_music()


func _toggle_music() -> void:
	if Game.music == null:
		return
	Game.music.set_enabled(not Game.music.enabled)
	_refresh_music()


func _on_sfx_volume(v: float) -> void:
	if Game.sfx != null:
		Game.sfx.set_volume(v / 100.0)
		Game.sfx.play_first(["attack_blade", "attack"])     # ให้ได้ยินตัวอย่างทันที
	_refresh_sfx()


func _toggle_sfx() -> void:
	if Game.sfx != null:
		Game.sfx.set_enabled(not Game.sfx.enabled)
	_refresh_sfx()


func _on_voice_volume(v: float) -> void:
	if Game.voice != null:
		Game.voice.set_volume(v / 100.0)
	_refresh_voice()


func _toggle_voice() -> void:
	if Game.voice != null:
		Game.voice.set_enabled(not Game.voice.enabled)
	_refresh_voice()


func _refresh_voice() -> void:
	if Game.voice == null or _voice_slider == null:
		return
	_voice_slider.set_block_signals(true)
	_voice_slider.value = Game.voice.volume_percent()
	_voice_slider.set_block_signals(false)
	_voice_btn.text = "เปิด" if Game.voice.enabled else "ปิด"
	_voice_label.text = "เสียงพากย์ NPC  %d%%" % Game.voice.volume_percent()


func _refresh_sfx() -> void:
	if Game.sfx == null or _sfx_slider == null:
		return
	_sfx_slider.set_block_signals(true)
	_sfx_slider.value = Game.sfx.volume_percent()
	_sfx_slider.set_block_signals(false)
	_sfx_btn.text = "เปิด" if Game.sfx.enabled else "ปิด"
	_sfx_label.text = "เสียงเอฟเฟกต์  %d%%" % Game.sfx.volume_percent()
	if not Game.sfx.has_sound("attack_blade"):
		_sfx_label.text += "   (ยังไม่มีไฟล์เสียง)"


func _refresh_music() -> void:
	if Game.music == null or _music_slider == null:
		return
	_music_slider.set_block_signals(true)
	_music_slider.value = Game.music.volume_percent()
	_music_slider.set_block_signals(false)
	_music_btn.text = "เปิด" if Game.music.enabled else "ปิด"
	var track := Game.music.current_track()
	_music_label.text = "เพลง  %d%%" % Game.music.volume_percent()
	if track != "" and Game.music.enabled:
		_music_label.text += "   (%s)" % track


func _refresh_touch_button() -> void:
	if _touch_btn == null or UI.touch == null:
		return
	_touch_btn.text = UI.touch.mode_text()
