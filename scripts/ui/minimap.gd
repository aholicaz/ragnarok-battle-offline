## Minimap — แผนที่ย่อมุมขวาบน (รอบ 27)
##
## โชว์ทั้งแมพย่อลงมาในกรอบเล็ก ๆ พร้อมจุดของสิ่งที่สำคัญ
##   · จุดเหลือง       = ตัวเรา (มีขีดบอกทิศที่หันอยู่)
##   · จุดแดง          = มอนสเตอร์      · จุดส้มวงใหญ่ = บอส
##   · จุดเขียว        = NPC            · เพชรฟ้า     = ประตูวาป
##   · จุดเหลืองจิ๋ว    = ของที่ตกอยู่
##   · กรอบขาวจาง ๆ   = ขอบเขตที่กล้องเห็นอยู่ตอนนี้
##   · แท่งเทา         = พื้น/แท่นที่ยืนได้ (อ่านจากกล่องชนของแมพเอง)
##
## ★ เปิด/ปิดด้วยปุ่ม M ★ หรือกดปุ่มไอคอนแผนที่ในแถบปุ่มใต้มินิแมพ
## ตำแหน่ง: ยึดมุมขวาบนเสมอ (ปรับระยะห่างขอบจอที่ MARGIN)
class_name Minimap
extends PanelContainer

## ขนาดพื้นที่วาดแผนที่ (ไม่รวมกรอบ/หัวข้อ)
const VIEW_SIZE := Vector2(210, 118)
## ระยะห่างจากขอบจอ
const MARGIN := 12.0
## อัพเดตจุดทุกกี่วินาที (ถี่เกินไปเปลืองเครื่องเปล่า ๆ)
const REFRESH := 0.06
const LAYOUT_PATH := "user://ui_layout.cfg"

const C_BG := Color("#0b101a")
const C_FIELD := Color("#151d2c")
const C_BORDER := Color("#41527a")
const C_TERRAIN := Color("#2f3f5c")
const C_PLAYER := Color("#ffe14a")
const C_ENEMY := Color("#ff5a5a")
const C_BOSS := Color("#ff9b30")
const C_NPC := Color("#5cff9a")
const C_PORTAL := Color("#7ec8ff")
const C_ITEM := Color("#ffd54a")
const C_CAM := Color("#ffffff44")

var title_label: Label
var view: Control

var _timer := 0.0
var _terrain: Array[Rect2] = []
var _terrain_from: int = 0     # instance id ของแมพที่สแกนไว้แล้ว
var _bounds := Rect2()


func _ready() -> void:
	name = "Minimap"
	add_theme_stylebox_override("panel", UITheme.panel_style(Color("#161b28dd")))
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "แผนที่ย่อ — กด M เพื่อเปิด/ปิด"

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	title_label = UITheme.make_label("แผนที่", 13, UITheme.ACCENT)
	title_label.clip_text = true
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.custom_minimum_size.x = VIEW_SIZE.x
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_label)

	view = _MapView.new()
	(view as _MapView).map_ui = self
	view.custom_minimum_size = VIEW_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(view)

	visible = _load_shown()
	Events.map_changed.connect(func(_id): _on_map_changed())
	get_viewport().size_changed.connect(place)
	place.call_deferred()


# =========================================================
# ตำแหน่ง — ยึดมุมขวาบนเสมอ
# =========================================================
func place() -> void:
	var screen := get_viewport_rect().size
	var w: float = size.x
	if w <= 1.0:
		w = get_combined_minimum_size().x
	position = Vector2(screen.x - w - MARGIN, MARGIN)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		place()


# =========================================================
# เปิด / ปิด
# =========================================================
func toggle() -> void:
	set_shown(not visible)


func set_shown(on: bool) -> void:
	visible = on
	_save_shown()
	if on:
		place()
		_on_map_changed()


func _save_shown() -> void:
	var cfg := ConfigFile.new()
	cfg.load(LAYOUT_PATH)
	cfg.set_value("hud", "minimap", visible)
	cfg.save(LAYOUT_PATH)


func _load_shown() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(LAYOUT_PATH) != OK:
		return true
	return bool(cfg.get_value("hud", "minimap", true))


# =========================================================
# ข้อมูลแมพ
# =========================================================
func current_map() -> Node:
	return get_tree().get_first_node_in_group("map")


func _on_map_changed() -> void:
	_terrain.clear()
	_terrain_from = 0
	_bounds = Rect2()


## ขอบเขตแมพในพิกัดโลก
func bounds() -> Rect2:
	var map := current_map()
	if map == null:
		return Rect2(0, 0, 1280, 720)
	if _bounds.size.x > 1.0:
		return _bounds
	var b: Rect2 = map.map_bounds if "map_bounds" in map else Rect2(0, 0, 4000, 1200)
	if b.size.x <= 1.0 or b.size.y <= 1.0:
		b = Rect2(0, 0, 4000, 1200)
	_bounds = b
	return b


## แปลงพิกัดโลก -> พิกัดในกรอบแผนที่
func to_view(world: Vector2) -> Vector2:
	var b := bounds()
	var k := view_scale()
	var used := b.size * k
	var off := (view.size - used) * 0.5
	return off + (world - b.position) * k


func view_scale() -> float:
	var b := bounds()
	if b.size.x <= 1.0 or b.size.y <= 1.0:
		return 1.0
	# ★ ย่อแบบรักษาสัดส่วน ★ แมพยาว ๆ จะได้ไม่บี้จนดูตำแหน่งไม่ออก
	return minf(view.size.x / b.size.x, view.size.y / b.size.y)


## กล่องชนของพื้น/แท่นในแมพ (สแกนครั้งเดียวต่อแมพ แล้วจำไว้)
func terrain() -> Array[Rect2]:
	var map := current_map()
	if map == null:
		return _terrain
	if _terrain_from == map.get_instance_id():
		return _terrain
	_terrain_from = map.get_instance_id()
	_terrain.clear()
	_scan(map, 0)
	return _terrain


func _scan(node: Node, depth: int) -> void:
	if _terrain.size() >= 200 or depth > 8:
		return
	for child in node.get_children():
		if child is CollisionShape2D and child.get_parent() is StaticBody2D:
			var r := _shape_rect(child as CollisionShape2D)
			if r.size.x > 4.0 and r.size.y > 1.0:
				_terrain.append(r)
		_scan(child, depth + 1)
		if _terrain.size() >= 200:
			return


static func _shape_rect(col: CollisionShape2D) -> Rect2:
	var shape := col.shape
	if shape == null:
		return Rect2()
	var sc := col.global_scale
	if shape is RectangleShape2D:
		var sz: Vector2 = (shape as RectangleShape2D).size * sc
		return Rect2(col.global_position - sz * 0.5, sz)
	if shape is CapsuleShape2D:
		var cap := shape as CapsuleShape2D
		var sz2 := Vector2(cap.radius * 2.0, cap.height) * sc
		return Rect2(col.global_position - sz2 * 0.5, sz2)
	if shape is CircleShape2D:
		var rad: float = (shape as CircleShape2D).radius * maxf(sc.x, sc.y)
		return Rect2(col.global_position - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
	if shape is WorldBoundaryShape2D:
		return Rect2()
	return Rect2()


# =========================================================
# อัพเดต
# =========================================================
func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = REFRESH

	var map := current_map()
	if map != null and "display_name" in map:
		var t: String = str(map.display_name)
		if t != "" and title_label.text != t:
			title_label.text = t
	view.queue_redraw()


# =========================================================
# ★ ตัววาดแผนที่ ★ (คลาสย่อย เพื่อให้มี _draw ของตัวเอง)
# =========================================================
class _MapView extends Control:
	var map_ui: Minimap

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if map_ui == null:
			draw_rect(r, Color("#0b101a"), true)
			return
		draw_rect(r, map_ui.C_BG, true)

		var b := map_ui.bounds()
		var k := map_ui.view_scale()
		var used := b.size * k
		var off := (size - used) * 0.5

		# พื้นที่ของแมพจริง
		draw_rect(Rect2(off, used), map_ui.C_FIELD, true)

		# ---------- พื้น/แท่นที่ยืนได้ ----------
		for t: Rect2 in map_ui.terrain():
			var p := map_ui.to_view(t.position)
			var s := t.size * k
			draw_rect(Rect2(p, Vector2(maxf(s.x, 1.0), maxf(s.y, 1.5))), map_ui.C_TERRAIN, true)

		var tree := get_tree()
		if tree == null:
			return

		# ---------- ของที่ตกอยู่ ----------
		for item in tree.get_nodes_in_group("dropped_item"):
			if item is Node2D:
				draw_circle(map_ui.to_view((item as Node2D).global_position), 1.5, map_ui.C_ITEM)

		# ---------- ประตูวาป ----------
		for portal in tree.get_nodes_in_group("portal"):
			if portal is Node2D:
				_diamond(map_ui.to_view((portal as Node2D).global_position), 4.0, map_ui.C_PORTAL)

		# ---------- NPC ----------
		for npc in tree.get_nodes_in_group("npc"):
			if npc is Node2D:
				_dot(map_ui.to_view(_feet(npc)), 3.0, map_ui.C_NPC)

		# ---------- มอนสเตอร์ ----------
		for m in tree.get_nodes_in_group("enemy"):
			if not (m is Node2D):
				continue
			if m.has_method("is_dead") and m.is_dead():
				continue
			var p2 := map_ui.to_view(_feet(m))
			var boss := false
			if "data" in m and m.data != null and "is_boss" in m.data:
				boss = bool(m.data.is_boss)
			if boss:
				_dot(p2, 4.5, map_ui.C_BOSS)
				draw_arc(p2, 7.0, 0.0, TAU, 16, map_ui.C_BOSS, 1.0, true)
			else:
				_dot(p2, 2.5, map_ui.C_ENEMY)

		# ---------- ผู้เล่น + กรอบกล้อง ----------
		var player := tree.get_first_node_in_group("player")
		if player is Node2D:
			_draw_camera(player as Node2D, k)
			var pp := map_ui.to_view(_feet(player))
			_dot(pp, 3.8, map_ui.C_PLAYER)
			var face: int = int(player.facing) if "facing" in player else 1
			draw_line(pp, pp + Vector2(face * 9.0, 0), map_ui.C_PLAYER, 1.5)

		# ขอบกรอบ
		draw_rect(r, map_ui.C_BORDER, false, 1.0)

	## กรอบสี่เหลี่ยมบาง ๆ = พื้นที่ที่มองเห็นบนจอตอนนี้
	func _draw_camera(player: Node2D, k: float) -> void:
		var cam := player.get_node_or_null("Camera2D") as Camera2D
		if cam == null:
			return
		var half: Vector2 = get_viewport_rect().size * 0.5 / cam.zoom
		var center: Vector2 = cam.get_screen_center_position()
		var tl := map_ui.to_view(center - half)
		var br := map_ui.to_view(center + half)
		draw_rect(Rect2(tl, br - tl), map_ui.C_CAM, false, 1.0)

	## ตำแหน่งปลายเท้า (ถ้ามี) จะได้ตรงระดับพื้นเหมือนที่เห็นในเกม
	static func _feet(node: Node) -> Vector2:
		if node.has_method("foot_position"):
			return node.foot_position()
		return (node as Node2D).global_position

	func _dot(p: Vector2, radius: float, color: Color) -> void:
		draw_circle(p, radius + 1.0, Color(0, 0, 0, 0.65))
		draw_circle(p, radius, color)

	func _diamond(p: Vector2, radius: float, color: Color) -> void:
		var pts := PackedVector2Array([
			p + Vector2(0, -radius), p + Vector2(radius, 0),
			p + Vector2(0, radius), p + Vector2(-radius, 0),
		])
		draw_colored_polygon(pts, color)
