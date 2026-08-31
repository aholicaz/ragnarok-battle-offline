## ConfirmDialog — กล่องยืนยัน ใช่/ไม่ กลางจอ
## เรียกใช้: var ok: bool = await UI.ask("หัวข้อ", "ข้อความ", "ตกลง", "ยกเลิก")
##
## โครงสร้าง (สร้างด้วยโค้ดทั้งหมด):
##   ConfirmDialog (Control เต็มจอ)
##   ├── ColorRect        (ฉากหลังมืด ๆ ให้กล่องเด่นขึ้น)
##   └── CenterContainer  (ตัวจัดกลางจอ — ให้เอนจินจัดให้ จะได้ไม่หลุดมุมจอ)
##       └── PanelContainer  (ตัวกล่องจริง)
class_name ConfirmDialog
extends Control

signal answered(accepted: bool)

var _panel: PanelContainer
var _title: Label
var _message: Label
var _yes: Button
var _no: Button
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 200

	# ★ ตัวกล่องเองกินเต็มจอ แล้วให้ CenterContainer จัดกล่องไว้กลางจอ ★
	# (เดิมใช้วิธีตั้ง Anchor เป็น Center ตอนสร้าง ซึ่งตอนนั้นกล่องยังกว้าง 0 อยู่
	#  ค่าตำแหน่งเลยถูกล็อกไว้ผิด กล่องจึงลอยไปมุมบนซ้าย)
	# ต้องใช้ set_anchors_and_offsets_preset ไม่ใช่ set_anchors_preset
	# เพราะ set_anchors_preset จะ "รักษากรอบเดิม" ซึ่งตอนนี้ยังกว้าง 0 อยู่
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # กันคลิกทะลุไปโดนของข้างหลัง

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.add_theme_stylebox_override("panel",
		UITheme.panel_style(Color("#141926f5"), UITheme.ACCENT, 8))
	_panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)

	_title = UITheme.make_label("", 18, UITheme.ACCENT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	box.add_child(UITheme.separator())

	_message = UITheme.make_label("", 15, UITheme.TEXT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	_yes = UITheme.make_button("ตกลง", 130)
	_yes.pressed.connect(func(): _answer(true))
	row.add_child(_yes)

	_no = UITheme.make_button("ยกเลิก", 130)
	_no.pressed.connect(func(): _answer(false))
	row.add_child(_no)

	var hint := UITheme.make_label("Enter / F = ตกลง     Esc = ยกเลิก", 11, UITheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


## ตำแหน่งกลางกล่องบนจอ (ไว้ตรวจสอบ/ทดสอบ)
func panel_center() -> Vector2:
	if _panel == null:
		return Vector2.ZERO
	return _panel.global_position + _panel.size * 0.5


func is_open() -> bool:
	return _open


## เปิดกล่องถาม แล้วรอคำตอบ
func ask(title: String, message: String, yes_text: String = "ตกลง", no_text: String = "ยกเลิก") -> void:
	if _open:
		_answer(false)
	_title.text = title
	_message.text = message
	_yes.text = yes_text
	_no.text = no_text
	_open = true
	visible = true
	move_to_front()
	# หยุดเกมไว้ก่อน ผู้เล่นจะได้ไม่เดินทะลุระหว่างอ่าน
	get_tree().paused = true


func _answer(accepted: bool) -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	answered.emit(accepted)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_answer(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("close_windows") or event.is_action_pressed("ui_cancel"):
		_answer(false)
		get_viewport().set_input_as_handled()
