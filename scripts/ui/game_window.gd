## GameWindow — หน้าต่างพื้นฐาน ลากย้ายได้ มีปุ่มปิด
## หน้าต่างอื่น ๆ ทั้งหมด extends จากไฟล์นี้ แล้ว override _build_content()
class_name GameWindow
extends PanelContainer

var window_title: String = "หน้าต่าง"
var content: VBoxContainer
var title_label: Label

var _dragging := false
var _drag_offset := Vector2.ZERO
var _built := false


func _ready() -> void:
	if _built:
		return
	_built = true

	add_theme_stylebox_override("panel", UITheme.panel_style(Color("#161b28ee")))
	custom_minimum_size = Vector2(300, 200)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# ---------- แถบหัวเรื่อง ----------
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.PANEL_LIGHT, UITheme.BORDER, 4))
	bar.gui_input.connect(_on_titlebar_input)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bar)

	var bar_box := HBoxContainer.new()
	bar.add_child(bar_box)

	title_label = UITheme.make_label(window_title, 16, UITheme.ACCENT)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_box.add_child(title_label)

	var close := UITheme.make_button("✕")
	close.pressed.connect(hide_window)
	bar_box.add_child(close)

	# ---------- เนื้อหา ----------
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	_build_content()
	refresh()


## หน้าต่างลูกเขียนเนื้อหาตรงนี้
func _build_content() -> void:
	pass


## เรียกทุกครั้งที่ข้อมูลเปลี่ยน
func refresh() -> void:
	pass


func set_title(text: String) -> void:
	window_title = text
	if title_label != null:
		title_label.text = text


func show_window() -> void:
	show()
	refresh()
	move_to_front()
	fit_to_content()


## ★ หดหน้าต่างให้พอดีเนื้อหา ★
## หน้าต่างไม่ได้อยู่ในคอนเทนเนอร์ Godot จึง "ไม่หดให้เอง" — ขนาดเก่าจะค้างอยู่
## ถ้าปล่อยไว้ กรอบหน้าต่าง (get_global_rect) จะใหญ่เกินจริง
## แล้วไปกินคลิกเมาส์บริเวณที่ไม่มีอะไรอยู่ (ดู UI.is_point_over_ui)
func fit_to_content() -> void:
	await get_tree().process_frame
	if is_instance_valid(self) and visible:
		reset_size()


func hide_window() -> void:
	hide()


func toggle() -> void:
	if visible:
		hide_window()
	else:
		show_window()


# =========================================================
# ลากย้ายหน้าต่าง
# =========================================================
func _on_titlebar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if _dragging:
			_drag_offset = get_global_mouse_position() - global_position
			move_to_front()
	elif event is InputEventMouseMotion and _dragging:
		var new_pos := get_global_mouse_position() - _drag_offset
		var vp := get_viewport_rect().size
		position = Vector2(
			clampf(new_pos.x, 0.0, maxf(0.0, vp.x - size.x)),
			clampf(new_pos.y, 0.0, maxf(0.0, vp.y - size.y))
		)


# =========================================================
# ตัวช่วยสร้าง UI
# =========================================================
func add_row(left: String, right: String, right_color: Color = UITheme.TEXT) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := UITheme.make_label(left, 14, UITheme.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var r := UITheme.make_label(right, 14, right_color)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(r)
	content.add_child(row)
	return row


func clear_content() -> void:
	clear_container(content)


## ลบลูกทั้งหมดทันที (ไม่รอ queue_free) เพื่อสร้างใหม่ได้เลย
static func clear_container(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
