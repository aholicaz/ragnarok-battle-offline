## TouchControls — ปุ่มบนจอสำหรับเล่นบนมือถือ / จอสัมผัส
##
## ★ ทำไมต้องเขียนเอง ไม่ใช้ปุ่มธรรมดา ★
## Godot แปลง "นิ้วแรก" เป็นเมาส์ให้เท่านั้น ถ้าใช้ Button ปกติจะกดได้ทีละปุ่ม
## (เดินไปตีไปไม่ได้) ไฟล์นี้เลยอ่าน InputEventScreenTouch เองแยกตามนิ้ว (multi-touch)
##
## ★ ปุ่มส่งเป็น "action" ★ เกมทั้งเกมเลยไม่ต้องแก้อะไรเลย
## กดปุ่มบนจอ = เหมือนกดคีย์บอร์ด (ทั้งแบบ polling และแบบรับ event)
##
## ★ เปิด/ปิด ★  UI.touch.set_mode(TouchControls.Mode.AUTO / ON / OFF)
## AUTO = โผล่เองเมื่อเครื่องมีจอสัมผัส หรือเมื่อมีการแตะจอครั้งแรก
## ค่าที่เลือกถูกจำไว้ใน user://ui_layout.cfg
class_name TouchControls
extends Control

enum Mode { AUTO, ON, OFF }

const LAYOUT_PATH := "user://ui_layout.cfg"

## ---------- ขนาดปุ่ม (แก้ตรงนี้ถ้าอยากให้ใหญ่/เล็กลง) ----------
const PAD_BIG := 112.0        # ปุ่มเดินซ้าย-ขวา · ปุ่มโจมตี
const PAD_MID := 96.0         # กระโดด · คุย/เก็บของ
const PAD_SMALL := 78.0       # สกิล 1-4
const PAD_TINY := 68.0        # ยา Q/R · เมนู
const EDGE := 22.0            # ห่างจากขอบจอ
const GAP := 10.0             # ห่างระหว่างปุ่ม
## ความจางตอนไม่ได้กด / ตอนกด
const IDLE_ALPHA := 0.55
const HOLD_ALPHA := 1.0

var mode: Mode = Mode.AUTO

## รายการปุ่มทั้งหมด: {id, action, label, size, node, rect, callable}
var _zones: Array = []
## นิ้วไหนกดปุ่มไหนอยู่ (index ของนิ้ว -> id ปุ่ม)
var _fingers: Dictionary = {}
var _shown := false


func _ready() -> void:
	name = "TouchControls"
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 190
	# ปุ่มพวกนี้ไม่กินเมาส์ — เราอ่านการแตะเองใน _input()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	_define_zones()
	_build()
	_load_mode()
	get_viewport().size_changed.connect(_layout)
	_refresh_visible()


# =========================================================
# รายการปุ่ม
# =========================================================
func _define_zones() -> void:
	# ฝั่งซ้าย = เดิน · ฝั่งขวา = สู้
	_zones = [
		{"id": "left",    "action": "move_left",  "arrow": "left",  "size": PAD_BIG},
		{"id": "right",   "action": "move_right", "arrow": "right", "size": PAD_BIG},
		{"id": "down",    "action": "move_down",  "arrow": "down",  "size": PAD_MID},

		{"id": "attack",  "action": "attack",   "label": "โจมตี",  "size": PAD_BIG},
		{"id": "jump",    "action": "jump",     "label": "กระโดด", "size": PAD_MID},
		{"id": "interact","action": "interact", "label": "คุย/เก็บ", "size": PAD_MID},

		{"id": "skill_1", "action": "skill_1", "label": "1", "size": PAD_SMALL},
		{"id": "skill_2", "action": "skill_2", "label": "2", "size": PAD_SMALL},
		{"id": "skill_3", "action": "skill_3", "label": "3", "size": PAD_SMALL},
		{"id": "skill_4", "action": "skill_4", "label": "4", "size": PAD_SMALL},

		{"id": "potion",  "action": "quick_potion",    "label": "ยา", "size": PAD_TINY},
		{"id": "sp",      "action": "quick_sp_potion", "label": "มานา", "size": PAD_TINY},
		{"id": "menu",    "action": "",  "label": "เมนู", "size": PAD_TINY,
			"tap": func(): Events.toggle_window.emit(&"system")},
	]


func _build() -> void:
	for z in _zones:
		var panel := PanelContainer.new()
		panel.name = "Btn_%s" % z.id
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", _pad_style(false))
		panel.modulate.a = IDLE_ALPHA
		add_child(panel)
		z["node"] = panel

		if z.has("arrow"):
			var arrow := _Arrow.new()
			arrow.dir = String(z.arrow)
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(arrow)
			if z.has("caption"):
				var cap := UITheme.make_label(String(z.caption), 13, Color(1, 1, 1, 0.85))
				cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
				cap.offset_top = -20
				cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				panel.add_child(cap)
		else:
			var lbl := UITheme.make_label(String(z.get("label", "")),
				18 if float(z.size) >= PAD_MID else 15, Color.WHITE)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			lbl.add_theme_constant_override("outline_size", 5)
			panel.add_child(lbl)


static func _pad_style(pressed: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#4a5c86") if pressed else Color("#1b2333")
	st.border_color = UITheme.ACCENT if pressed else Color("#8ea0c4")
	st.set_border_width_all(3)
	st.set_corner_radius_all(999)   # กลม
	return st


# =========================================================
# วางตำแหน่งปุ่ม
# =========================================================
func _layout() -> void:
	var vp := get_viewport_rect().size
	var bottom := vp.y - EDGE

	# ---------- ฝั่งซ้าย: เดิน ----------
	_set_rect("left",  Vector2(EDGE, bottom - PAD_BIG))
	_set_rect("right", Vector2(EDGE + PAD_BIG + GAP, bottom - PAD_BIG))
	_set_rect("down",  Vector2(EDGE + (PAD_BIG * 2.0 + GAP - PAD_MID) * 0.5,
		bottom - PAD_BIG - GAP - PAD_MID))

	# ---------- ฝั่งขวา แถวล่าง: โจมตี / กระโดด / คุย ----------
	var x := vp.x - EDGE - PAD_BIG
	_set_rect("attack", Vector2(x, bottom - PAD_BIG))
	x -= GAP + PAD_MID
	_set_rect("jump", Vector2(x, bottom - PAD_MID))
	x -= GAP + PAD_MID
	_set_rect("interact", Vector2(x, bottom - PAD_MID))

	# ---------- ฝั่งขวา แถวสกิล ----------
	var row2 := bottom - PAD_BIG - GAP - PAD_SMALL
	var sx := vp.x - EDGE - PAD_SMALL
	for id in ["skill_4", "skill_3", "skill_2", "skill_1"]:
		_set_rect(id, Vector2(sx, row2))
		sx -= GAP + PAD_SMALL

	# ---------- ฝั่งขวา แถวยา + เมนู ----------
	var row3 := row2 - GAP - PAD_TINY
	var tx := vp.x - EDGE - PAD_TINY
	for id in ["menu", "sp", "potion"]:
		_set_rect(id, Vector2(tx, row3))
		tx -= GAP + PAD_TINY


func _set_rect(id: String, pos: Vector2) -> void:
	for z in _zones:
		if z.id != id:
			continue
		var s: float = float(z.size)
		z["rect"] = Rect2(pos, Vector2(s, s))
		var node: Control = z.node
		node.position = pos
		node.size = Vector2(s, s)
		return


# =========================================================
# เปิด / ปิด
# =========================================================
func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_save_mode()
	_refresh_visible()


func mode_text() -> String:
	match mode:
		Mode.ON: return "เปิดตลอด"
		Mode.OFF: return "ปิด"
	return "อัตโนมัติ"


## เครื่องนี้ควรมีปุ่มจอสัมผัสไหม
func should_show() -> bool:
	match mode:
		Mode.ON: return true
		Mode.OFF: return false
	if DisplayServer.is_touchscreen_available():
		return true
	return _shown   # เคยมีการแตะจอมาแล้ว


func _refresh_visible() -> void:
	var want: bool = should_show()
	# ระหว่างเปิดหน้าต่าง/คุยกับ NPC/ตายอยู่ ให้ซ่อนไว้ก่อน จะได้ไม่บังปุ่มในกล่อง
	if want and (UI.is_any_window_open() or UI.is_asking()):
		want = false
	# แถบคำใบ้ปุ่มคีย์บอร์ดล่างจอไม่มีประโยชน์บนมือถือ แถมทับปุ่ม — ซ่อนไว้
	if UI.hud != null and UI.hud.bottom_panel != null:
		var dlg_open: bool = UI.dialogue != null and UI.dialogue.is_open()
		UI.hud.bottom_panel.visible = not want and not dlg_open

	if want == visible:
		return
	visible = want
	if not want:
		_release_all()
	else:
		_layout()


func _process(_delta: float) -> void:
	_refresh_visible()


# =========================================================
# อ่านการแตะจอ (แยกตามนิ้ว = กดพร้อมกันหลายปุ่มได้)
# =========================================================
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		# แตะจอครั้งแรก = เครื่องนี้มีจอสัมผัสจริง โผล่ปุ่มให้เลย (โหมดอัตโนมัติ)
		if not _shown and mode == Mode.AUTO:
			_shown = true
			_refresh_visible()
		if not visible:
			return
		if t.pressed:
			_press_at(t.index, t.position)
		else:
			_release_finger(t.index)
	elif event is InputEventScreenDrag and visible:
		var d := event as InputEventScreenDrag
		# ลากนิ้วจากปุ่มหนึ่งไปอีกปุ่ม (เช่นสไลด์ซ้าย->ขวา) ให้เปลี่ยนปุ่มตาม
		var now := _zone_at(d.position)
		var was: String = String(_fingers.get(d.index, ""))
		var now_id: String = String(now.id) if not now.is_empty() else ""
		if now_id != was:
			_release_finger(d.index)
			if now_id != "":
				_press_at(d.index, d.position)


func _press_at(index: int, pos: Vector2) -> void:
	var z := _zone_at(pos)
	if z.is_empty():
		return
	_fingers[index] = z.id
	_set_pressed(z, true)
	var action := String(z.get("action", ""))
	if action != "" and InputMap.has_action(action):
		# ส่งทั้ง 2 แบบ: action_press (โค้ดที่เช็คแบบ polling)
		# + InputEventAction (โค้ดที่เช็คใน _input/_unhandled_input เช่น NPC กด F)
		Input.action_press(action)
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = true
		Input.parse_input_event(ev)


func _release_finger(index: int) -> void:
	if not _fingers.has(index):
		return
	var id: String = String(_fingers[index])
	_fingers.erase(index)
	for z in _zones:
		if z.id != id:
			continue
		_set_pressed(z, false)
		var action := String(z.get("action", ""))
		if action != "" and InputMap.has_action(action):
			Input.action_release(action)
			var ev := InputEventAction.new()
			ev.action = action
			ev.pressed = false
			Input.parse_input_event(ev)
		if z.has("tap"):
			(z.tap as Callable).call()
		return


func _release_all() -> void:
	for index in _fingers.keys().duplicate():
		_release_finger(index)


func _set_pressed(z: Dictionary, on: bool) -> void:
	var node: Control = z.node
	node.add_theme_stylebox_override("panel", _pad_style(on))
	node.modulate.a = HOLD_ALPHA if on else IDLE_ALPHA


## ปุ่มไหนอยู่ตรงจุดนี้ (เผื่อระยะนิ้วอ้วนไว้นิดหน่อย)
func _zone_at(pos: Vector2) -> Dictionary:
	for z in _zones:
		if not z.has("rect"):
			continue
		if (z.rect as Rect2).grow(6.0).has_point(pos):
			return z
	return {}


## จุดนี้ทับปุ่มจอสัมผัสไหม (UI.is_point_over_ui เรียกใช้ กันคลิกทะลุไปตีมอน)
func is_over(point: Vector2) -> bool:
	if not visible:
		return false
	return not _zone_at(point).is_empty()


# =========================================================
# จำค่าที่เลือกไว้
# =========================================================
func _save_mode() -> void:
	var cfg := ConfigFile.new()
	cfg.load(LAYOUT_PATH)
	cfg.set_value("touch", "mode", int(mode))
	cfg.save(LAYOUT_PATH)


func _load_mode() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LAYOUT_PATH) != OK:
		return
	var v = cfg.get_value("touch", "mode", int(Mode.AUTO))
	if typeof(v) == TYPE_INT and v >= 0 and v <= 2:
		mode = v as Mode


# =========================================================
# ลูกศรบนปุ่มเดิน (วาดเอง — ฟอนต์ไทยไม่มี glyph ลูกศร)
# =========================================================
class _Arrow extends Control:
	var dir := "left"

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r: float = minf(size.x, size.y) * 0.26
		var pts := PackedVector2Array()
		match dir:
			"left":
				pts = PackedVector2Array([c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r, 0)])
			"right":
				pts = PackedVector2Array([c + Vector2(-r, -r), c + Vector2(-r, r), c + Vector2(r, 0)])
			"down":
				pts = PackedVector2Array([c + Vector2(-r, -r * 0.6), c + Vector2(r, -r * 0.6),
					c + Vector2(0, r * 0.8)])
			_:
				pts = PackedVector2Array([c + Vector2(-r, r * 0.6), c + Vector2(r, r * 0.6),
					c + Vector2(0, -r * 0.8)])
		draw_colored_polygon(pts, Color(1, 1, 1, 0.92))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
