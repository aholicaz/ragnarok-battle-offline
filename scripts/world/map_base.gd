## MapBase — สคริปต์กลางของทุกแมพ
##
## หน้าที่: วางผู้เล่นที่จุดเกิด, ตั้งกล้องให้เดินได้ไกลกว่า 1 หน้าจอ,
##          ใส่ชั้นข้อความลอย
##
## โครงสร้าง Scene ของแมพ:
##   Map (Node2D)  <- ใส่สคริปต์นี้
##   ├── Background        (ParallaxBackground / Sprite2D — ตกแต่ง)
##   ├── Terrain           (TileMapLayer หรือ StaticBody2D พื้น)
##   ├── SpawnPoints (Node2D)
##   │   ├── default   (Marker2D)   <- ชื่อต้องตรงกับที่ Portal ส่งมา
##   │   └── from_town (Marker2D)
##   ├── Spawners (Node2D)  <- ใส่ MonsterSpawner ไว้ข้างใน
##   ├── Portals   (Node2D)
##   └── NPCs      (Node2D)
extends Node2D

@export var map_id: StringName = &"prontera_field"
@export var display_name: String = "ทุ่งหญ้าพรอนเทรา"
## ★ บทที่เท่าไหร่ของเนื้อเรื่อง (รอบ 31) ★ 1 = มิดการ์ด · 2 = สวาร์ทัลฟ์เฮม ...
@export var chapter: int = 1
## ชื่อภูมิภาค (โชว์ในมินิแมพ/สมุดเควสในอนาคต) เช่น "มิดการ์ด"
@export var region: String = "มิดการ์ด"

## ★ ขอบเขตของแมพ — กำหนดให้กว้างกว่าหน้าจอได้เลย ★
## เช่น Rect2(0, 0, 4000, 1200) = แมพกว้าง 4000 พิกเซล
@export var map_bounds: Rect2 = Rect2(0, 0, 4000, 1200)

## ★ เปิดอันนี้แล้วไม่ต้องมาแก้ Map Bounds เองทุกครั้ง ★
## ระบบจะวัดขนาดแมพจาก TileMap + กล่องชนของพื้นให้อัตโนมัติ
## ขยายพื้น/วาดกระเบื้องเพิ่ม = แมพกว้างขึ้นเองทันที
@export var auto_fit_bounds: bool = false
## เผื่อขอบซ้าย-ขวา / เผื่อที่ว่างเหนือหัว (พิกเซล)
@export var bounds_padding: Vector2 = Vector2(0, 300)

@export var player_scene: PackedScene
@export var camera_zoom: Vector2 = Vector2.ONE
## กล้องตามแบบนุ่มนวล (0 = ติดตัวเป๊ะ)
@export_range(0.0, 20.0) var camera_smoothing: float = 6.0
## กล้องเลื่อนขึ้นเล็กน้อยเพื่อเห็นข้างหน้ามากขึ้น
@export var camera_offset: Vector2 = Vector2(0, -60)

var player: Node2D
var camera: Camera2D


func _ready() -> void:
	add_to_group("map")
	PlayerState.current_map_id = map_id
	if auto_fit_bounds:
		map_bounds = _measure_bounds()
		print("[Map] %s ขนาดแมพที่วัดได้: %s" % [map_id, str(map_bounds)])
	_ensure_floating_text_layer()
	_spawn_player()
	_setup_camera()
	Events.say(display_name)


# =========================================================
# วัดขนาดแมพจากของที่วางไว้จริง
# =========================================================
func _measure_bounds() -> Rect2:
	var rect := Rect2()
	var found := false

	for node in _all_descendants(self):
		var r := _rect_of(node)
		if r.size == Vector2.ZERO:
			continue
		rect = r if not found else rect.merge(r)
		found = true

	if not found:
		return map_bounds

	# เผื่อขอบซ้ายขวา + เผื่อที่ว่างเหนือหัวไว้ให้กระโดด
	return rect.grow_individual(bounds_padding.x, bounds_padding.y, bounds_padding.x, 0.0)


func _rect_of(node: Node) -> Rect2:
	# กระเบื้องที่วาดไว้
	if node.has_method("get_used_rect") and node.has_method("map_to_local"):
		var used: Rect2i = node.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			return Rect2()
		var top_left: Vector2 = node.to_global(node.map_to_local(used.position))
		var bottom_right: Vector2 = node.to_global(node.map_to_local(used.position + used.size))
		return Rect2(top_left, bottom_right - top_left).abs()

	# กล่องชนของพื้น / แท่น
	if node is CollisionShape2D:
		var shape: Shape2D = (node as CollisionShape2D).shape
		var scale_v: Vector2 = (node as CollisionShape2D).global_scale
		if shape is RectangleShape2D:
			var sz: Vector2 = (shape as RectangleShape2D).size * scale_v
			return Rect2((node as CollisionShape2D).global_position - sz * 0.5, sz)
		if shape is CircleShape2D:
			var rad: float = (shape as CircleShape2D).radius * maxf(scale_v.x, scale_v.y)
			return Rect2((node as CollisionShape2D).global_position - Vector2(rad, rad), Vector2(rad, rad) * 2.0)
		if shape is CapsuleShape2D:
			var cap := shape as CapsuleShape2D
			var sz2 := Vector2(cap.radius * 2.0, cap.height) * scale_v
			return Rect2((node as CollisionShape2D).global_position - sz2 * 0.5, sz2)

	return Rect2()


func _all_descendants(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child in root.get_children():
		out.append(child)
		out.append_array(_all_descendants(child))
	return out


func _ensure_floating_text_layer() -> void:
	if get_node_or_null("FloatingTextLayer") != null:
		return
	var layer := Node2D.new()
	layer.name = "FloatingTextLayer"
	layer.set_script(load("res://scripts/world/floating_text_layer.gd"))
	add_child(layer)


# =========================================================
# วางผู้เล่น
# =========================================================
func _spawn_player() -> void:
	player = get_tree().get_first_node_in_group("player")

	if player == null:
		if player_scene == null:
			push_error("[Map] ยังไม่ได้ใส่ Player Scene ให้แมพ %s" % map_id)
			return
		player = player_scene.instantiate()
		add_child(player)

	player.global_position = _find_spawn_position()


func _find_spawn_position() -> Vector2:
	var wanted := Game.requested_spawn_point()
	var points := get_node_or_null("SpawnPoints")

	if points != null:
		var target := points.get_node_or_null(String(wanted))
		if target == null:
			target = points.get_node_or_null("default")
		if target == null and points.get_child_count() > 0:
			target = points.get_child(0)
		if target is Node2D:
			return (target as Node2D).global_position

	return map_bounds.position + map_bounds.size * 0.5


# =========================================================
# กล้อง — จุดสำคัญที่ทำให้แมพเดินได้ไกลกว่า 1 หน้าจอ
# =========================================================
func _setup_camera() -> void:
	if player == null:
		return

	camera = player.get_node_or_null("Camera2D")
	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		player.add_child(camera)

	camera.zoom = camera_zoom
	camera.offset = camera_offset

	camera.limit_left = int(map_bounds.position.x)
	camera.limit_top = int(map_bounds.position.y)
	camera.limit_right = int(map_bounds.position.x + map_bounds.size.x)
	camera.limit_bottom = int(map_bounds.position.y + map_bounds.size.y)
	camera.limit_smoothed = true

	camera.position_smoothing_enabled = camera_smoothing > 0.0
	camera.position_smoothing_speed = camera_smoothing

	camera.make_current()
