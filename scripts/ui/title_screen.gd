## TitleScreen — หน้าแรกของเกม (รอบ 32)
##
## ภาพหลัก Shadows of Fate เต็มจอ (ซูมช้า ๆ) + เมนู เริ่มเกมใหม่ / โหลด 3 ช่อง / ออก
## ตั้งเป็น Main Scene แล้ว (project.godot: run/main_scene)
##
## ★ เปลี่ยนภาพ ★ วางไฟล์ทับ Sprites/ui/title_key_art.jpg (สัดส่วน 16:9 แนะนำ 1920x1080)
## ★ กลับมาหน้านี้จากในเกม ★ Tab → เมนูระบบ → "กลับหน้าหลัก"  หรือเรียก Game.go_title()
class_name TitleScreen
extends Control

const KEY_ART := "res://Sprites/ui/title_key_art.jpg"
## ★ วิดีโอเปิดเกม (รอบ 39) ★ เล่นวนเป็นพื้นหลังแทนภาพนิ่ง — ไม่มีไฟล์นี้ = ใช้ภาพนิ่งเหมือนเดิม
## ★ เปลี่ยนวิดีโอ ★ ต้องเป็น .ogv (Ogg Theora) — แปลงจาก mp4: ffmpeg -i in.mp4 -c:v libtheora -q:v 7 -c:a libvorbis out.ogv
const OPENING_VIDEO := "res://Sprites/opening_game.ogv"
const VERSION := "v0.31"

var _art: TextureRect
var _video: VideoStreamPlayer
var _menu: VBoxContainer
var _buttons: Array[Button] = []
var _slot_labels: Array[Label] = []
var _hint: Label
var _loading: Control
var _loading_label: Label
var _selected := 0
var _busy := false
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if UI != null:
		UI.set_in_game(false)
	_build_art()
	_build_menu()
	_build_loading()
	_refresh_slots()
	_select(0)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.8)


# =========================================================
# ภาพหลัก — เต็มจอ ซูมช้า ๆ ให้มีชีวิต
# =========================================================
func _build_art() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#07070f")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# ---------- วิดีโอเปิดเกม (ถ้ามี) ----------
	if ResourceLoader.exists(OPENING_VIDEO):
		_video = VideoStreamPlayer.new()
		_video.name = "OpeningVideo"
		_video.stream = load(OPENING_VIDEO)
		_video.autoplay = true
		_video.expand = true
		_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# วนซ้ำเอง (VideoStreamPlayer ไม่มีช่อง loop)
		_video.finished.connect(func():
			if is_instance_valid(_video):
				_video.play())
		add_child(_video)

	_art = TextureRect.new()
	_art.name = "KeyArt"
	if ResourceLoader.exists(KEY_ART):
		_art.texture = load(KEY_ART)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ซูมรอบจุดกลาง
	_art.pivot_offset = get_viewport_rect().size * 0.5
	# มีวิดีโอแล้ว ภาพนิ่งเป็นแค่ตัวสำรอง (ซ่อนไว้)
	_art.visible = _video == null
	add_child(_art)

	# ไล่เงาด้านล่างให้เมนูอ่านง่าย
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0, 0, 0, 0.0)
	add_child(shade)
	var grad := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.0))
	g.set_color(1, Color(0, 0, 0, 0.75))
	grad.gradient = g
	grad.fill_from = Vector2(0, 0.45)
	grad.fill_to = Vector2(0, 1.0)
	var shade_tex := TextureRect.new()
	shade_tex.texture = grad
	shade_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade_tex)


func _process(delta: float) -> void:
	_t += delta
	if _art != null and _art.visible:
		# ซูม 1.00 → 1.06 ไป-กลับช้า ๆ (60 วิ ต่อรอบ)
		var k := 1.03 + 0.03 * sin(_t * TAU / 60.0)
		_art.pivot_offset = size * 0.5
		_art.scale = Vector2(k, k)
	if _hint != null:
		_hint.modulate.a = 0.55 + 0.45 * sin(_t * 3.0)


# =========================================================
# เมนู
# =========================================================
func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.name = "Menu"
	_menu.add_theme_constant_override("separation", 6)
	_menu.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_menu.position = Vector2(84, 0)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu)

	_add_button("เริ่มเกมใหม่", _on_new_game)
	for slot in range(SaveManager.SLOT_COUNT):
		var b := _add_button("โหลดช่อง %d" % (slot + 1), _on_load.bind(slot))
		var info := UITheme.make_label("", 12, UITheme.TEXT_DIM)
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(info)
		info.position = Vector2(170, 8)
		_slot_labels.append(info)
	if not OS.has_feature("web"):
		_add_button("ออกจากเกม", func(): get_tree().quit())

	_hint = UITheme.make_label("↑↓ เลือก · Enter ยืนยัน · แตะได้", 11, UITheme.TEXT_DIM)
	_hint.name = "Hint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	var ver := UITheme.make_label("Shadows of Fate  ·  %s  ·  Godot %s" % [VERSION, Engine.get_version_info().string], 11, UITheme.TEXT_DIM)
	ver.name = "Version"
	ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ver)
	# ★ position ของ Control นับจากมุมซ้ายบนของแม่เสมอ (ไม่ใช่จาก anchor) ★
	# เลยต้องรอให้รู้ขนาดก่อน แล้วค่อยคำนวณจากขนาดจอ · ทำซ้ำตอนจอเปลี่ยนขนาดด้วย
	await get_tree().process_frame
	_layout()
	resized.connect(_layout)


func _layout() -> void:
	if _menu != null:
		_menu.position = Vector2(84, size.y - _menu.size.y - 34.0)
	if _hint != null:
		_hint.position = Vector2(88, size.y - _hint.size.y - 12.0)
	var ver := get_node_or_null("Version") as Label
	if ver != null:
		ver.position = Vector2(size.x - ver.size.x - 16.0, size.y - ver.size.y - 12.0)


func _add_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 38)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", UITheme.TEXT)
	b.add_theme_color_override("font_hover_color", UITheme.ACCENT)
	b.add_theme_color_override("font_pressed_color", UITheme.ACCENT)
	b.add_theme_color_override("font_disabled_color", Color("#6a7080"))
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 5)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.04, 0.09, 0.55 if st != "hover" else 0.8)
		sb.border_color = UITheme.ACCENT if st == "hover" else Color(1, 1, 1, 0.12)
		sb.set_border_width_all(1)
		sb.border_width_left = 4
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 18.0
		sb.content_margin_right = 18.0
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(func():
		_selected = _buttons.find(b)
		_select(_selected)
		cb.call())
	b.mouse_entered.connect(func():
		_selected = _buttons.find(b)
		_select(_selected))
	_menu.add_child(b)
	_buttons.append(b)
	return b


func _select(i: int) -> void:
	if _buttons.is_empty():
		return
	_selected = wrapi(i, 0, _buttons.size())
	for k in range(_buttons.size()):
		var b := _buttons[k]
		var on := k == _selected
		b.add_theme_color_override("font_color", UITheme.ACCENT if on else UITheme.TEXT)
		var sb: StyleBoxFlat = b.get_theme_stylebox("normal").duplicate()
		sb.border_color = UITheme.ACCENT if on else Color(1, 1, 1, 0.12)
		sb.bg_color = Color(0.03, 0.04, 0.09, 0.8 if on else 0.55)
		b.add_theme_stylebox_override("normal", sb)
		b.text = ("▸ " if on else "   ") + b.text.trim_prefix("▸ ").trim_prefix("   ")


func _refresh_slots() -> void:
	for slot in range(_slot_labels.size()):
		var b := _buttons[1 + slot]
		if SaveManager.has_save(slot):
			var info := SaveManager.slot_info(slot)
			var map_name := String(info.get("map_name", ""))
			if map_name == "":
				map_name = String(info.get("map", ""))
			_slot_labels[slot].text = "Lv.%d  %s  ·  %s" % [int(info.get("level", 1)), _job_name(String(info.get("job", ""))), map_name]
			b.disabled = false
		else:
			_slot_labels[slot].text = "— ว่าง —"
			b.disabled = true


func _job_name(job_id: String) -> String:
	var j = GameData.get_job(StringName(job_id)) if GameData.has_method("get_job") else null
	return j.display_name if j != null else job_id


func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event.is_action_pressed("ui_down"):
		_skip_disabled(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_skip_disabled(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or event.is_action_pressed("attack"):
		if not _buttons[_selected].disabled:
			_buttons[_selected].pressed.emit()
		get_viewport().set_input_as_handled()


func _skip_disabled(dir: int) -> void:
	for i in range(_buttons.size()):
		_selected = wrapi(_selected + dir, 0, _buttons.size())
		if not _buttons[_selected].disabled:
			break
	_select(_selected)


# =========================================================
# หน้าโหลด (ทับทุกอย่างตอนกำลังเข้าเกม)
# =========================================================
func _build_loading() -> void:
	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color("#05060c")
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading.mouse_filter = Control.MOUSE_FILTER_STOP
	_loading.visible = false
	_loading.modulate.a = 0.0
	add_child(_loading)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 10)
	_loading.add_child(box)
	_loading_label = UITheme.make_label("กำลังโหลด...", 22, UITheme.TEXT)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_loading_label)
	var tip := UITheme.make_label(_random_tip(), 13, UITheme.TEXT_DIM)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.custom_minimum_size.x = 520
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	await get_tree().process_frame
	box.position = (size - box.size) * 0.5


const TIPS := [
	"W หรือ Space = พุ่งหลบ ระหว่างพุ่งจะไม่โดนโจมตี",
	"กด K เปิดผังสกิล — Bash ต้องเลเวล 5 ถึงจะเรียน Slash ได้",
	"มอนสเตอร์ทุกตัวมีการ์ดของตัวเอง โอกาสดรอปน้อยมาก",
	"ของที่ดรอปจากมอนเท่านั้นที่มีช่องใส่การ์ด ของจากร้านไม่มี",
	"ศิลาสลักแห่งธอร์ในเมืองใช้บันทึกเกมได้ (หรือกด F5)",
	"อย่าเข้าป่าลึกตอนค่ำ... ผู้กองสั่งห้ามไว้",
	"ช่างตีเหล็กฮันส์ตีบวกอาวุธได้ ยิ่งบวกสูงยิ่งเสี่ยงพัง",
	"กด M เปิด/ปิดแผนที่ย่อ · U ดูสมุดเควส",
]

func _random_tip() -> String:
	return "เคล็ดลับ: " + TIPS[randi() % TIPS.size()]


func _show_loading(text: String = "กำลังโหลด...") -> void:
	_busy = true
	_loading_label.text = text
	_loading.visible = true
	var tw := create_tween()
	tw.tween_property(_loading, "modulate:a", 1.0, 0.35)
	await tw.finished
	await get_tree().process_frame


# =========================================================
# ปุ่ม
# =========================================================
func _on_new_game() -> void:
	if _busy:
		return
	await _show_loading("กำลังเริ่มการเดินทาง...")
	PlayerState.new_game()
	PlayerState.current_map_id = &"prontera_town"
	if UI != null:
		UI.set_in_game(true)
	Game.change_map(&"prontera_town", &"default")


func _on_load(slot: int) -> void:
	if _busy or not SaveManager.has_save(slot):
		return
	await _show_loading("กำลังโหลดช่อง %d..." % (slot + 1))
	if not SaveManager.load_game(slot):
		_busy = false
		_loading.visible = false
		return
	if UI != null:
		UI.set_in_game(true)
	var map_id: StringName = PlayerState.current_map_id
	if not Game.MAPS.has(map_id):
		map_id = &"prontera_town"
	Game.change_map(map_id, &"default")
