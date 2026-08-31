## DeathPopup — หน้าจอตอนตัวละครตาย (รอบ 27)
##
## ตายแล้วไม่เด้งกลับเมืองเองอีกต่อไป — จอจะมืดลง แล้วขึ้นกล่องกลางจอ
##   · ท่าตายของตัวละครค้างอยู่ข้างหลัง (เกมหยุดนิ่ง)
##   · มี "คำอวยพรจากธอร์" สุ่มมาให้กำลังใจ 1 ประโยค
##   · ผู้เล่นกดเองว่าจะเกิดใหม่ที่เมือง หรือย้อนกลับไปเซฟล่าสุด
##
## ปุ่มลัด: Enter / Space / F  = เกิดใหม่   ·   F9 = โหลดเซฟล่าสุด
##
## ★ เพิ่มคำอวยพรเอง ★ แก้ที่ลิสต์ THOR_BLESSINGS ข้างล่างได้เลย
class_name DeathPopup
extends Control

## คำอวยพรจากธอร์ — สุ่มมา 1 ข้อทุกครั้งที่ตาย
const THOR_BLESSINGS := [
	"สายฟ้าไม่เคยกลัวเมฆดำ  จงลุกขึ้นอีกครั้ง แล้วฟาดให้ดังกว่าเดิม",
	"ค้อนของข้าหนักขึ้นทุกครั้งที่เจ้าล้ม  เพราะเจ้าลุกขึ้นมาทุกครั้งเช่นกัน",
	"นักรบไม่ได้วัดกันที่ล้มกี่หน  แต่วัดกันที่ยืนขึ้นได้อีกกี่ครั้ง",
	"เจ้ายังหายใจอยู่ในวัลฮัลลาไม่ได้  กลับไปสู้ต่อเถอะ ลูกข้า",
	"ความเจ็บวันนี้ คือเกราะของเจ้าในวันหน้า",
	"ข้าเห็นเจ้าสู้จนหยดสุดท้าย  รางวัลของเจ้าคือลมหายใจอีกครั้ง",
	"พายุจะพาเจ้ากลับเมือง  แต่ดาบต้องเจ้าถือเอง",
	"อย่าอายที่แพ้ปีศาจ  จงอายถ้าไม่กล้ากลับไปหามันอีก",
	"เลือดที่เสียไปวันนี้ ธอร์จะคืนให้ครึ่งหนึ่ง  ที่เหลือจงหามาเอง",
	"ฟ้าร้องเพื่อเจ้าแล้ว  ตื่นได้แล้วนักดาบ",
]

const PANEL_W := 520.0
const TITLE_SIZE := 30
const BLESS_SIZE := 19

var _dim: ColorRect
var _panel: PanelContainer
var _bless: Label
var _title: Label
var _hint: Label
var _respawn_btn: Button
var _load_btn: Button
var _open := false
var _was_paused := false


func _ready() -> void:
	name = "DeathPopup"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# กินคลิกทั้งจอ กันไม่ให้คลิกทะลุไปสั่งตัวละครฟันดาบตอนตาย
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	_build()


func _build() -> void:
	# ---------- ฉากหลังมืด ----------
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.02, 0.05, 0.78)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	# ---------- กล่องกลางจอ ----------
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.custom_minimum_size.x = PANEL_W
	# จัดกลางจอเอง (ยึดกลาง แล้วโตขึ้น-ลงจากจุดกลาง)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	# ---------- สายฟ้า + หัวข้อ ----------
	var bolt := _Bolt.new()
	bolt.custom_minimum_size = Vector2(0, 54)
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bolt)

	_title = UITheme.make_label("เจ้าล้มลงแล้ว...", TITLE_SIZE, Color("#ff6b6b"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.add_theme_constant_override("outline_size", 6)
	box.add_child(_title)

	box.add_child(UITheme.separator())

	# ---------- คำอวยพรจากธอร์ ----------
	# ★ ห้ามใส่อีโมจิ ★ ฟอนต์ไทยที่ฝังไว้ (Noto Sans Thai) ไม่มีตัวอีโมจิ
	# ใส่ไปจะกลายเป็นสี่เหลี่ยมบนเว็บ/มือถือ — ใช้สายฟ้าที่วาดด้วยโค้ดแทน
	var head := UITheme.make_label("คำอวยพรจากธอร์", 15, UITheme.ACCENT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)

	_bless = UITheme.make_label("", BLESS_SIZE, Color("#ffeec4"))
	_bless.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bless.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# ★ ต้องกำหนดความกว้างก่อน ★ ไม่งั้น Label ที่ตัดบรรทัดอัตโนมัติจะคิดความสูงผิด
	# (ตัดทีละตัวอักษรจนกล่องสูงเป็นพันพิกเซล — เจอมาแล้วตอนทำกล่องสนทนา)
	_bless.custom_minimum_size = Vector2(PANEL_W - 60.0, 0)
	box.add_child(_bless)

	box.add_child(UITheme.separator())

	# ---------- ปุ่ม ----------
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	_respawn_btn = UITheme.make_button("เกิดใหม่ที่เมือง  (Enter)", 210.0)
	_respawn_btn.add_theme_font_size_override("font_size", 16)
	_respawn_btn.pressed.connect(respawn)
	row.add_child(_respawn_btn)

	_load_btn = UITheme.make_button("โหลดเซฟล่าสุด  (F9)", 180.0)
	_load_btn.add_theme_font_size_override("font_size", 16)
	_load_btn.pressed.connect(load_save)
	row.add_child(_load_btn)

	_hint = UITheme.make_label("", 13, UITheme.TEXT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)


static func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color("#141a28f2")
	s.border_color = Color("#7a4a4a")
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(22)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 16
	return s


# =========================================================
# เปิด / ปิด
# =========================================================
func open() -> void:
	if _open:
		return
	_open = true

	_bless.text = "\"%s\"" % THOR_BLESSINGS[randi() % THOR_BLESSINGS.size()]
	_hint.text = "เกิดใหม่ที่พรอนเทรา · ฟื้นเลือดครึ่งหนึ่ง · ไม่เสียของและค่าประสบการณ์"
	_load_btn.visible = SaveManager.has_save(0)

	show()
	modulate.a = 0.0
	# เกมหยุดนิ่งไว้ ให้ผู้เล่นค่อย ๆ อ่าน (UI ทั้งชั้นตั้ง PROCESS_MODE_ALWAYS อยู่แล้ว)
	_was_paused = get_tree().paused
	get_tree().paused = true

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.35)
	await tween.finished
	if _open and _respawn_btn != null:
		_respawn_btn.grab_focus()


func close() -> void:
	if not _open:
		return
	_open = false
	hide()
	get_tree().paused = _was_paused


func is_open() -> bool:
	return _open and visible


# =========================================================
# ปุ่ม
# =========================================================
func respawn() -> void:
	if not _open:
		return
	close()
	Game.respawn_in_town()


func load_save() -> void:
	if not _open:
		return
	close()
	if SaveManager.load_game(0):
		Game.reload_map()
	else:
		Events.say("ยังไม่มีไฟล์เซฟ — เกิดใหม่ที่เมืองแทน")
		Game.respawn_in_town()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var accept := event.is_action_pressed("ui_accept") \
		or (InputMap.has_action("interact") and event.is_action_pressed("interact"))
	if accept:
		respawn()
		get_viewport().set_input_as_handled()
		return
	if InputMap.has_action("quick_load") and event.is_action_pressed("quick_load"):
		load_save()
		get_viewport().set_input_as_handled()
		return
	# แตะจอ/คลิกที่ไหนก็ได้ = เกิดใหม่ (มือถือกดง่าย)
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		respawn()
		get_viewport().set_input_as_handled()


# =========================================================
# ★ สายฟ้าเหนือหัวข้อ ★ วาดด้วยโค้ด ไม่ต้องมีไฟล์ภาพ
# =========================================================
class _Bolt extends Control:
	func _draw() -> void:
		var w := size.x
		var cx := w * 0.5
		var pts := PackedVector2Array([
			Vector2(cx + 8, 2), Vector2(cx - 16, 28), Vector2(cx - 2, 28),
			Vector2(cx - 10, 52), Vector2(cx + 18, 22), Vector2(cx + 3, 22),
		])
		draw_colored_polygon(pts, Color("#ffd54a"))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("#fff3b0"), 2.0, true)
		# เส้นประกายซ้าย-ขวา
		var y := 30.0
		draw_line(Vector2(cx - 120, y), Vector2(cx - 34, y), Color("#ffd54a55"), 2.0)
		draw_line(Vector2(cx + 34, y), Vector2(cx + 120, y), Color("#ffd54a55"), 2.0)
