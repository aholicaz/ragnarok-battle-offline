## CardGetPopup — เด้งกลางจอตอนได้การ์ด "ใบใหม่" ครั้งแรก
##
## โครงสร้าง (สร้างด้วยโค้ดทั้งหมด):
##   CardGetPopup (Control เต็มจอ)
##   ├── ColorRect        (ฉากหลังมืด)
##   └── CenterContainer  (จัดกลางจอโดยเอนจิน)
##       └── PanelContainer
##           ├── "ยินดีด้วยนักผจญภัย"
##           ├── CardView   (ภาพการ์ดใบเต็ม)
##           └── "คุณได้การ์ด <ชื่อ>"
class_name CardGetPopup
extends Control

## โชว์นานกี่วินาทีแล้วปิดเอง (0 = ไม่ปิดเอง)
@export var auto_close: float = 6.0

var _panel: PanelContainer
var _title: Label
var _message: Label
var _card_view: CardView
var _open := false
var _timer := 0.0
var _grace := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	z_index = 190
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
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
		UITheme.panel_style(Color("#171d2ef8"), Color("#ffe14a"), 12))
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)

	_title = UITheme.make_label("ยินดีด้วยนักผจญภัย!", 24, Color("#ffe14a"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	box.add_child(UITheme.separator())

	# ภาพการ์ดใบเต็ม จัดกึ่งกลาง
	var holder := CenterContainer.new()
	box.add_child(holder)
	_card_view = CardView.new()
	holder.add_child(_card_view)

	_message = UITheme.make_label("", 18, UITheme.TEXT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size.x = 260
	box.add_child(_message)

	var hint := UITheme.make_label("กดปุ่มใดก็ได้เพื่อปิด", 12, UITheme.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	Events.card_obtained.connect(show_card)


func is_open() -> bool:
	return _open


## เปิด popup โชว์การ์ดใบนี้
func show_card(card_id: StringName) -> void:
	var card := GameData.get_card(card_id)
	if card == null:
		return

	_card_view.show_card(card, true)
	_message.text = "คุณได้การ์ด\n[ %s ]" % card.display_name
	_message.add_theme_color_override("font_color", card.rarity_color())

	_open = true
	visible = true
	move_to_front()
	_timer = auto_close
	_grace = 0.35   # กันปุ่มที่เพิ่งกดเก็บของมาปิด popup ทันที
	get_tree().paused = true
	Events.say("ได้การ์ดใหม่: %s" % card.display_name)


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false


func _process(delta: float) -> void:
	if not _open:
		return
	if _grace > 0.0:
		_grace -= delta
	# หัวเรื่องกะพริบเบา ๆ ให้ดูมีชีวิต
	if _title != null:
		_title.modulate.a = 0.75 + 0.25 * absf(sin(Time.get_ticks_msec() * 0.004))
	if auto_close > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			close()


func _input(event: InputEvent) -> void:
	if not _open or _grace > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		close()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		close()
		get_viewport().set_input_as_handled()
