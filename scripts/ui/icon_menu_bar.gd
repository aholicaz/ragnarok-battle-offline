## IconMenuBar — แถบปุ่มไอคอนเปิดหน้าต่าง (รอบ 27)
##
## วางไว้ "ใต้กล่องมินิแมพ" มุมขวาบน กดเปิด/ปิดหน้าต่างได้ทุกบาน
## ไม่ต้องจำปุ่มคีย์บอร์ด และเล่นบนมือถือได้ด้วย (แตะเอา)
##
##   [สเตตัส] [กระเป๋า] [สวมใส่] [สกิล]
##   [เควส]  [การ์ด]  [เมนู]   [แผนที่]
##
## ★ ไอคอนวาดด้วยโค้ดล้วน ★ ไม่ต้องมีไฟล์ภาพก็ใช้ได้ทันที
## ★ อยากใส่ไอคอนที่วาดเอง ★ เอาไฟล์ .png ไปวางที่
##      res://Sprites/ui_icons/<id>.png
##   ชื่อไฟล์ต้องตรงกับ id ในลิสต์ ITEMS ข้างล่าง เช่น status.png, inventory.png
##   ระบบจะหยิบไปใช้แทนไอคอนที่วาดไว้ให้เองอัตโนมัติ ไม่ต้องแก้โค้ด
class_name IconMenuBar
extends PanelContainer

## ขนาดปุ่ม (จัตุรัส)
const BTN := 48.0
## จำนวนปุ่มต่อแถว
const COLS := 4
const GAP := 6
## ห่างจากกล่องมินิแมพ
const GAP_Y := 8.0
const MARGIN := 12.0
## โฟลเดอร์ไอคอนที่ผู้เล่นเอามาใส่เองได้
const ICON_DIR := "res://Sprites/ui_icons/"

## รายการปุ่ม — เพิ่ม/ลด/สลับลำดับได้ตามใจ
const ITEMS := [
	{"id": "status",    "win": "status",    "key": "C",   "label": "สเตตัส"},
	{"id": "inventory", "win": "inventory", "key": "I",   "label": "กระเป๋า"},
	{"id": "equipment", "win": "equipment", "key": "E",   "label": "ของสวมใส่"},
	{"id": "skills",    "win": "skills",    "key": "K",   "label": "สกิล"},
	{"id": "quests",    "win": "quests",    "key": "U",   "label": "เควส"},
	{"id": "cards",     "win": "cards",     "key": "V",   "label": "สมุดการ์ด"},
	{"id": "system",    "win": "system",    "key": "Tab", "label": "เมนูระบบ"},
	{"id": "map",       "win": "",          "key": "M",   "label": "แผนที่ย่อ"},
]

## กล่องมินิแมพที่อยู่ข้างบน (ใช้คำนวณตำแหน่ง)
var minimap: Minimap

var _buttons: Dictionary = {}     # id -> Button
var _timer := 0.0


func _ready() -> void:
	name = "MenuBar"
	add_theme_stylebox_override("panel", UITheme.panel_style(Color("#161b28dd")))
	mouse_filter = Control.MOUSE_FILTER_STOP

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)

	for entry in ITEMS:
		var btn := _make_button(entry)
		grid.add_child(btn)
		_buttons[entry.id] = btn

	get_viewport().size_changed.connect(place)
	place.call_deferred()


func _make_button(entry: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(BTN, BTN)
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_contents = true
	# ฟอนต์ 1 px — ข้อความจริงอยู่ที่ป้ายซ้อนข้างใน (เหมือนช่องปุ่มลัดของ HUD)
	btn.add_theme_font_size_override("font_size", 1)
	btn.add_theme_stylebox_override("normal", UITheme.slot_style())
	btn.add_theme_stylebox_override("hover", UITheme.slot_style(true))
	btn.add_theme_stylebox_override("pressed", UITheme.slot_style(true))
	btn.tooltip_text = "%s  (%s)" % [entry.label, entry.key]

	# ---------- ไอคอน ----------
	var custom := _custom_icon(String(entry.id))
	if custom != null:
		var art := TextureRect.new()
		art.name = "Art"
		art.texture = custom
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 6
		art.offset_top = 4
		art.offset_right = -6
		art.offset_bottom = -12
		btn.add_child(art)
	else:
		var icon := _Icon.new()
		icon.name = "Art"
		icon.kind = String(entry.id)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 6
		icon.offset_top = 4
		icon.offset_right = -6
		icon.offset_bottom = -12
		btn.add_child(icon)

	# ---------- ชื่อย่อใต้ไอคอน ----------
	var cap := UITheme.make_label(String(entry.key), 10, UITheme.TEXT_DIM)
	cap.name = "Key"
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	cap.offset_top = -13
	cap.offset_bottom = -1
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_theme_color_override("font_outline_color", Color.BLACK)
	cap.add_theme_constant_override("outline_size", 3)
	btn.add_child(cap)

	var id := String(entry.id)
	var win := String(entry.win)
	btn.pressed.connect(func(): _press(id, win))
	return btn


static func _custom_icon(id: String) -> Texture2D:
	var path := ICON_DIR + id + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _press(id: String, win: String) -> void:
	if win != "":
		Events.toggle_window.emit(StringName(win))
		return
	if id == "map" and minimap != null:
		minimap.toggle()
		place()


# =========================================================
# ตำแหน่ง — ใต้กล่องมินิแมพ ชิดขวาเสมอ
# =========================================================
func place() -> void:
	var screen := get_viewport_rect().size
	var w: float = size.x
	if w <= 1.0:
		w = get_combined_minimum_size().x
	var top := MARGIN
	if minimap != null and minimap.visible:
		var mh: float = minimap.size.y
		if mh <= 1.0:
			mh = minimap.get_combined_minimum_size().y
		top = minimap.position.y + mh + GAP_Y
	position = Vector2(screen.x - w - MARGIN, top)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		place()


# =========================================================
# ปุ่มของหน้าต่างที่เปิดอยู่ = สว่างขึ้น
# =========================================================
func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.2
	place()
	for entry in ITEMS:
		var btn: Button = _buttons.get(entry.id)
		if btn == null:
			continue
		var on := false
		if String(entry.win) != "":
			var w: GameWindow = UI.windows.get(StringName(entry.win), null)
			on = w != null and w.visible
		elif entry.id == "map":
			on = minimap != null and minimap.visible
		btn.modulate = Color(1.25, 1.2, 0.85) if on else Color.WHITE


# =========================================================
# ★ ไอคอนวาดด้วยโค้ด ★ ไม่ต้องมีไฟล์ภาพ
# ทุกอันวาดบนตาราง 24x24 หน่วย แล้วย่อ/ขยายให้พอดีปุ่ม
# =========================================================
class _Icon extends Control:
	var kind := "status"
	var line := Color("#ffffff")
	var fill := Color("#c8d4e6")
	var gold := Color("#ffd54a")

	var _u := 1.0
	var _o := Vector2.ZERO

	func _draw() -> void:
		_u = minf(size.x, size.y) / 24.0
		_o = (size - Vector2(24, 24) * _u) * 0.5
		match kind:
			"status": _draw_person()
			"inventory": _draw_bag()
			"equipment": _draw_armor()
			"skills": _draw_book()
			"quests": _draw_quest()
			"cards": _draw_cards()
			"system": _draw_gear()
			"map": _draw_map()
			_: _draw_person()

	func p(x: float, y: float) -> Vector2:
		return _o + Vector2(x, y) * _u

	func poly(points: Array, color: Color) -> void:
		var out := PackedVector2Array()
		for pt in points:
			out.append(p(pt[0], pt[1]))
		draw_colored_polygon(out, color)

	func box(x: float, y: float, w: float, h: float, color: Color, filled := true,
			width: float = 1.5) -> void:
		draw_rect(Rect2(p(x, y), Vector2(w, h) * _u), color, filled, -1.0 if filled else width * _u)

	# ---------- ตัวคน = สเตตัส ----------
	func _draw_person() -> void:
		draw_circle(p(12, 7), 3.6 * _u, line)
		poly([[5, 21], [7.5, 13], [16.5, 13], [19, 21]], fill)

	# ---------- ถุงย่าม = กระเป๋า ----------
	func _draw_bag() -> void:
		draw_arc(p(12, 9.0), 3.4 * _u, PI, TAU, 14, line, 1.5 * _u)
		poly([[3.5, 9.5], [20.5, 9.5], [19, 21.5], [5, 21.5]], fill)
		box(9.5, 13.5, 5, 3.5, Color("#2a3450"))

	# ---------- เสื้อเกราะ = ของสวมใส่ ----------
	func _draw_armor() -> void:
		poly([[8, 4], [10.5, 6.5], [13.5, 6.5], [16, 4], [20, 8], [17, 11],
			[17, 21], [7, 21], [7, 11], [4, 8]], fill)
		draw_line(p(12, 7), p(12, 21), line, 1.2 * _u)

	# ---------- หนังสือ = สกิล ----------
	func _draw_book() -> void:
		poly([[3.5, 5], [11.2, 6.5], [11.2, 20], [3.5, 18.5]], fill)
		poly([[20.5, 5], [12.8, 6.5], [12.8, 20], [20.5, 18.5]], fill)
		draw_line(p(12, 6.6), p(12, 20), line, 1.4 * _u)

	# ---------- เครื่องหมายตกใจ = เควส ----------
	func _draw_quest() -> void:
		poly([[10.4, 3.5], [13.6, 3.5], [13.1, 15], [10.9, 15]], gold)
		draw_circle(p(12, 19), 1.9 * _u, gold)

	# ---------- การ์ดสองใบ ----------
	func _draw_cards() -> void:
		# ใบหลัง (เอียง) + ใบหน้า (ตั้งตรง) จะได้ดูออกว่าเป็นการ์ดสองใบ
		poly([[3.5, 8.5], [9.5, 5.5], [14.5, 16.5], [8.5, 19.5]], Color("#8a97ad"))
		box(11, 5.0, 9.5, 15, fill)
		box(11, 5.0, 9.5, 15, line, false, 1.2)
		box(13, 8.5, 5.5, 8, Color("#2a3450"))

	# ---------- เฟือง = เมนูระบบ ----------
	func _draw_gear() -> void:
		for i in range(8):
			var a := TAU * i / 8.0
			var dir := Vector2(cos(a), sin(a))
			draw_line(p(12, 12) + dir * 6.0 * _u, p(12, 12) + dir * 10.0 * _u, fill, 3.0 * _u)
		draw_circle(p(12, 12), 6.5 * _u, fill)
		draw_circle(p(12, 12), 2.8 * _u, Color("#161b28"))

	# ---------- แผนที่พับ ----------
	func _draw_map() -> void:
		poly([[3, 6.5], [9, 4.5], [15, 7], [21, 4.5], [21, 17.5], [15, 20],
			[9, 17.5], [3, 20]], fill)
		draw_line(p(9, 4.8), p(9, 17.5), line, 1.1 * _u)
		draw_line(p(15, 7), p(15, 19.8), line, 1.1 * _u)
