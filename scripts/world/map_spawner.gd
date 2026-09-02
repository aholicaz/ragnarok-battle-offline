## MapSpawner — เกิดมอนกระจายทั่วทั้งแมพ (ไม่กระจุกที่เดิม)
##
## วางแค่ตัวเดียวต่อ 1 แมพ แล้วใส่ MonsterData ที่อยากให้เกิดในแมพนั้น
## ระบบจะสุ่มหาพื้นทั่วแมพเอง (ยิงเรย์ลงหาพื้น) แล้วกระจายมอนออกไปให้ทั่ว
## ตายแล้วเกิดใหม่ "ที่จุดใหม่" ไม่ใช่ที่เดิม
class_name MapSpawner
extends Node2D

## ★ ชนิดมอนที่จะเกิดในแมพนี้ ★ (ใส่ได้หลายชนิด แนะนำ 3 ชนิดต่อแมพ)
@export var monster_types: Array[MonsterData] = []
## เกิดชนิดละกี่ตัว
@export var count_per_type: int = 5
## Scene ต้นแบบของมอน (ปกติคือ res://scenes/monsters/monster.tscn)
@export var monster_scene: PackedScene

@export_group("การกระจายตัว")
## เว้นระยะจากขอบซ้าย-ขวาของแมพ
@export var edge_margin: float = 150.0
## มอนแต่ละตัวต้องห่างกันอย่างน้อยกี่พิกเซล
@export var min_spacing: float = 170.0
## ห้ามเกิดใกล้ผู้เล่นเกินระยะนี้ (กันโผล่ใส่หน้า)
@export var avoid_player_range: float = 280.0
## ความสูงสูงสุดที่ยอมให้เกิด (นับจากพื้นล่างสุดของแมพขึ้นมา) 0 = ไม่จำกัด
@export var max_height_above_floor: float = 0.0

@export_group("เกิดนอกจอ")
## ★ ให้มอนเกิด "นอกจอ" เท่านั้น ★ เดินไปเรื่อย ๆ ถึงค่อยเจอ ไม่ใช่โผล่มาต่อหน้า
@export var spawn_offscreen: bool = true
## เผื่อระยะจากขอบจอออกไปอีกเท่าไหร่ (ยิ่งมาก ยิ่งเกิดไกลจากขอบจอ)
@export var offscreen_margin: float = 120.0
## ★ ไกลสุดที่ยอมให้เกิด ★ กันไปเกิดคนละฟากแมพจนเดินหาไม่เจอ (0 = ไม่จำกัด)
@export var max_spawn_distance: float = 1600.0
## ถ้าหาที่เกิดนอกจอไม่ได้นานเกินกี่วินาที ให้ผ่อนเงื่อนไขลง (กันแมพว่างเปล่า)
## แมพยิ่งแคบยิ่งต้องผ่อนบ่อย — ตั้งน้อยลงถ้าอยากให้มอนครบเร็ว
@export var relax_after: float = 2.0
## ★ มอนที่อยู่ไกลเกินระยะนี้จะถูกเก็บกลับ ★ แล้วไปเกิดใหม่ข้างหน้าที่ผู้เล่นกำลังเดินไป
## (0 = ไม่เก็บ มอนจะค้างอยู่ที่เดิมตลอด) ควรมากกว่า Max Spawn Distance พอสมควร
@export var despawn_distance: float = 2600.0

@export_group("จังหวะ")
## หน่วงก่อนเกิดชุดแรก
@export var initial_delay: float = 0.3
## เกิดทีละตัว ห่างกันกี่วินาที (ค่อย ๆ โผล่มาตอนเดินเปิดแมพ)
@export var spawn_interval: float = 0.6
## เกิดใหม่ที่จุดสุ่มใหม่ (ปิด = เกิดที่เดิม)
@export var respawn_at_random_spot: bool = true
## เกิดเฉพาะตอนผู้เล่นอยู่ในแมพ
@export var only_when_player_exists: bool = true

var _bounds: Rect2
var _alive: Array = []
var _pending: int = 0
var _band_pool: Array[int] = []
var _ready_done := false
var _spawn_timer := 0.0
var _dry_time := 0.0


func _ready() -> void:
	if monster_scene == null:
		monster_scene = load("res://scenes/monsters/monster.tscn")
	if monster_types.is_empty():
		push_warning("[MapSpawner] ยังไม่ได้ใส่ MonsterData ให้ %s" % name)
		return

	_bounds = _find_map_bounds()
	await get_tree().physics_frame
	await get_tree().create_timer(initial_delay).timeout
	_ready_done = true
	_fill()


## ขอบเขตแมพจาก MapBase ถ้าหาไม่เจอก็เดาจากกล้อง
func _find_map_bounds() -> Rect2:
	var node: Node = self
	while node != null:
		if "map_bounds" in node:
			return node.map_bounds
		node = node.get_parent()
	return Rect2(-2000, -2000, 4000, 4000)


func _total_wanted() -> int:
	return monster_types.size() * count_per_type


func _process(delta: float) -> void:
	if not _ready_done:
		return
	# ตัวที่ตายแล้ว (กำลังเล่นท่าตายอยู่) ไม่นับเป็นตัวเป็น ๆ
	# ไม่งั้นระหว่างเล่นท่าตาย ระบบจะคิดว่ามอนยังครบ แล้วไม่ยอมเกิดตัวใหม่
	_alive = _alive.filter(func(m):
		return is_instance_valid(m) and not (m.has_method("is_dead") and m.is_dead()))
	_cull_far_monsters()
	if _alive.size() + _pending >= _total_wanted():
		_dry_time = 0.0
		return

	# นับเวลาที่ "ยังหาที่เกิดไม่ได้" ไว้ เผื่อต้องผ่อนกติกาทีหลัง
	_dry_time += delta

	# เกิดทีละตัว ไม่ใช่โผล่พรึบทีเดียว
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = maxf(0.05, spawn_interval)
	_fill()


## เก็บมอนที่อยู่ไกลลิบ (ผู้เล่นเดินผ่านไปไกลแล้ว) กลับเข้าคิว
## เพื่อให้ไปเกิดใหม่ข้างหน้า — เดินเปิดแมพไปเรื่อย ๆ ก็จะเจอมอนเรื่อย ๆ
func _cull_far_monsters() -> void:
	if despawn_distance <= 0.0:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var keep: Array = []
	for m in _alive:
		if not is_instance_valid(m):
			continue
		var dead: bool = m.has_method("is_dead") and m.is_dead()
		if not dead and absf(m.global_position.x - player.global_position.x) > despawn_distance:
			m.queue_free()
			continue
		keep.append(m)
	_alive = keep


func _fill() -> void:
	if only_when_player_exists and get_tree().get_first_node_in_group("player") == null:
		return
	if _alive.size() + _pending >= _total_wanted():
		return

	# เลือก "ชนิดที่ยังขาดมากที่สุด" มาเกิด 1 ตัว ทุกชนิดจะได้ทยอยโผล่สลับกัน
	var target: MonsterData = null
	var fewest := count_per_type
	for data in monster_types:
		if data == null:
			continue
		var have := 0
		for m in _alive:
			if is_instance_valid(m) and m.data == data:
				have += 1
		if have < fewest:
			fewest = have
			target = data

	if target != null and _spawn_one(target):
		_dry_time = 0.0


# =========================================================
# หาจุดยืนบนพื้น
# =========================================================
## แบ่งความกว้างแมพเป็นช่อง ๆ เท่าจำนวนมอน แล้วให้แต่ละตัวไปคนละช่อง
## (ช่องจะถูกใช้ก็ต่อเมื่อหาที่ยืนในช่องนั้นได้จริง จึงไม่เสียช่องฟรี ๆ)
func _ensure_bands() -> void:
	if _band_pool.is_empty():
		var n: int = maxi(1, _total_wanted())
		for i in range(n):
			_band_pool.append(i)
		_band_pool.shuffle()


func _x_of_band(band: int) -> float:
	var left := _bounds.position.x + edge_margin
	var right := _bounds.position.x + _bounds.size.x - edge_margin
	var width := maxf(1.0, right - left)
	var total: int = maxi(1, _total_wanted())
	# สุ่มเฉพาะช่วงกลางของช่อง (60%) เพื่อกันตัวที่อยู่ช่องติดกันมาชิดกันเกินไป
	return left + (band + 0.2 + randf() * 0.6) * width / total


## ครึ่งหนึ่งของความกว้างจอในหน่วยพิกเซลของโลก (คิดค่า Zoom ของกล้องด้วย)
func _half_screen_width() -> float:
	var half := get_viewport_rect().size.x * 0.5
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.zoom.x > 0.001:
		half /= cam.zoom.x
	return half


## ระยะใกล้สุดที่ยอมให้เกิด = พ้นขอบจอไปแล้ว (ผู้เล่นจะไม่เห็นมอนโผล่ต่อหน้า)
## ถ้าแมพแคบกว่าจอมาก ก็จะลดให้เท่าที่แมพไหว
func _min_spawn_distance() -> float:
	if not spawn_offscreen:
		return avoid_player_range
	var want := _half_screen_width() + offscreen_margin
	var usable := maxf(1.0, _bounds.size.x - edge_margin * 2.0)
	return clampf(want, avoid_player_range, maxf(avoid_player_range, usable * 0.55))


## ยิงเรย์หาพื้น
## - ปกติจะบังคับให้เกิด "นอกจอ" และ "ไม่ไกลเกินไป"
## - ถ้าหาที่ไม่ได้นาน ๆ (แมพแคบ / ผู้เล่นยืนมุมแมพ) จะค่อย ๆ ผ่อนระยะลง
##   เพื่อไม่ให้แมพว่างเปล่า แต่ยังไงก็ไม่เกิดใกล้กว่า Avoid Player Range
func _find_ground() -> Vector2:
	var t: float = clampf(_dry_time / maxf(0.1, relax_after), 0.0, 1.0)
	var near: float = lerpf(_min_spawn_distance(), avoid_player_range, t)
	# ★ รอบ 40: ตอนผ่อนเงื่อนไข "ไกลสุด" ต้องไม่เกินโซนเก็บกลับ ★
	# เดิมผ่อนเป็น "ไม่จำกัด" → ระบบเลือกจุดไกลสุดของแมพ → เกิดปุ๊บโดน despawn เก็บทันที
	# วนลูปเกิด-หายไปเรื่อย ๆ มอนในแมพเลยไม่เพิ่มสักที (เจอในทุ่งวิหารหลังผู้ใช้ขยายแมพ)
	var far: float = max_spawn_distance if t < 1.0 else _relaxed_far()

	for relax in [1.0, 0.7, 0.45]:
		var point := _try_find(min_spacing * relax, near, far)
		if point != Vector2.INF:
			return point

	# ทางสุดท้าย: แมพแคบจริง ๆ / ผู้เล่นยืนนิ่งตรงมุมแมพ
	# ยอมให้เกิดใกล้ขึ้นได้บ้าง แต่ยังไม่ประชิดตัวผู้เล่น
	if t >= 1.0:
		for relax in [0.45, 0.25]:
			var point := _try_find(min_spacing * relax, avoid_player_range * 0.6, 0.0)
			if point != Vector2.INF:
				return point
			# บางแมพ "พื้นจริง" แคบกว่าขอบเขตแมพมาก ช่องบางช่องจึงไม่มีพื้นให้ยืนเลย
			# กรณีนี้เลิกใช้ระบบช่อง แล้วสุ่มทั่วแมพแทน
			point = _try_random(min_spacing * relax, avoid_player_range * 0.6)
			if point != Vector2.INF:
				return point
	return Vector2.INF


## เพดานระยะไกลสุดตอนผ่อนเงื่อนไข — ห้ามเกินโซนเก็บกลับ (despawn)
func _relaxed_far() -> float:
	if despawn_distance > 0.0:
		return despawn_distance * 0.9
	return 0.0


## สุ่มหาที่ยืนทั่วแมพ (ไม่สนระบบช่อง) — ใช้ตอนช่องที่เหลือไม่มีพื้นให้ยืน
func _try_random(spacing: float, player_gap: float) -> Vector2:
	var left := _bounds.position.x + edge_margin
	var right := _bounds.position.x + _bounds.size.x - edge_margin
	var best_point := Vector2.INF
	var best_gap := -1.0
	for i in range(24):
		var point := _check_x(randf_range(left, right), spacing, player_gap, _relaxed_far())
		if point == Vector2.INF:
			continue
		var gap := absf(point.x - _player_x())
		if gap > best_gap:
			best_gap = gap
			best_point = point
	return best_point


## หาที่ยืนที่ผ่านเงื่อนไขทั้งหมด แล้วเลือก "ช่องที่ไกลผู้เล่นที่สุด"
## (ไกลที่สุดเท่าที่ยังไม่เกิน Max Spawn Distance — จะได้โผล่นอกจอเสมอถ้าเป็นไปได้)
func _try_find(spacing: float, player_gap: float, player_far: float) -> Vector2:
	_ensure_bands()
	var best_band := -1
	var best_point := Vector2.INF
	var best_gap := -1.0

	for band in _band_pool:
		for attempt in range(3):
			var point := _check_x(_x_of_band(band), spacing, player_gap, player_far)
			if point == Vector2.INF:
				continue
			var gap := absf(point.x - _player_x())
			if gap > best_gap:
				best_gap = gap
				best_point = point
				best_band = band
			break

	if best_band >= 0:
		_band_pool.erase(best_band)
		return best_point
	return Vector2.INF


func _player_x() -> float:
	var player := get_tree().get_first_node_in_group("player")
	return player.global_position.x if player != null else 0.0


## ยิงเรย์ลงที่ตำแหน่ง x นี้ แล้วเช็คเงื่อนไขทั้งหมด — ผ่านแล้วคืนจุดยืนบนพื้น
func _check_x(x: float, spacing: float, player_gap: float, player_far: float) -> Vector2:
	var space := get_world_2d().direct_space_state
	var top := _bounds.position.y
	var bottom := _bounds.position.y + _bounds.size.y

	var query := PhysicsRayQueryParameters2D.create(Vector2(x, top), Vector2(x, bottom))
	query.collision_mask = 1
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return Vector2.INF

	var point: Vector2 = hit.position

	if max_height_above_floor > 0.0 and (bottom - point.y) > max_height_above_floor:
		return Vector2.INF

	# ไม่เกิดใกล้ผู้เล่น (ต้องพ้นขอบจอ) และไม่เกิดไกลเกินไป
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		var gap: float = absf(point.x - player.global_position.x)
		if player_gap > 0.0 and gap < player_gap:
			return Vector2.INF
		if player_far > 0.0 and gap > player_far:
			return Vector2.INF

	# ไม่เกิดทับตัวอื่น
	for m in _alive:
		if is_instance_valid(m) and absf(m.global_position.x - point.x) < spacing:
			return Vector2.INF

	# ★★ ห้ามเกิดหลังกำแพง (รอบ 35) ★★
	# ยิงเส้นจากผู้เล่นมาที่จุดนี้ระดับอก ถ้ามีพื้น/กำแพงขวาง = เดินมาหากันไม่ได้
	# ไม่งั้นมอนจะเกิดในโซนที่ปิดตายแล้วเดินชนกำแพงอยู่อย่างนั้น
	if player != null and not _reachable_from(player.global_position, point):
		return Vector2.INF

	return point


## เดินจากคอลัมน์ x ของผู้เล่น มาถึงจุดนี้ได้ไหม (เช็คแค่กำแพงขวางแนวนอน)
## ★ ยิงที่ระดับ "เหนือพื้นตรงจุดเป้าหมาย" ★ ไม่ใช้ y ของผู้เล่น
## เพราะผู้เล่นอาจกำลังกระโดด/ตกอยู่ ทำให้เส้นลอยผิดระดับแล้ววัดพลาด
func _reachable_from(from: Vector2, to: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	# รอบ 40: ยกเส้นสูงขึ้น (110 px เหนือพื้นเป้าหมาย) — เนินเตี้ย ๆ ของ TileMap ในแมพจริง
	# ไม่ควรถือว่า "เดินไปไม่ถึง" (เดิม 40 px ทำให้ทุ่งวิหารหาที่เกิดมอนแทบไม่ได้ มอนเลยโหรงเหรง)
	# กำแพงจริง (สูง 700+) ยังขวางเส้นนี้อยู่ = ยังกันเกิดหลังกำแพงได้เหมือนเดิม
	var y: float = to.y - 110.0
	var query := PhysicsRayQueryParameters2D.create(Vector2(from.x, y), Vector2(to.x, y))
	query.collision_mask = 1
	return space.intersect_ray(query).is_empty()


func _spawn_one(data: MonsterData) -> bool:
	if monster_scene == null:
		return false

	var point := _find_ground()
	if point == Vector2.INF:
		return false

	var monster := monster_scene.instantiate()
	monster.data = data
	get_parent().add_child(monster)
	# วางให้ "เท้า" อยู่บนพื้นพอดี
	monster.global_position = point - Vector2(0.0, data.foot_offset())

	if monster.has_method("set_home"):
		monster.set_home(monster.global_position)
	if monster.has_signal("died"):
		monster.died.connect(_on_monster_died)

	_alive.append(monster)
	return true


func _on_monster_died(_monster: Node, data: MonsterData) -> void:
	_pending += 1
	await get_tree().create_timer(data.respawn_time).timeout
	_pending -= 1
	# ถ้าปิด respawn_at_random_spot ไว้ ก็ยังใช้ระบบเดิมคือหาที่ใหม่อยู่ดี
	# (จุดเกิดเดิมเก็บไว้ในตัวมอนที่ตายไปแล้ว)


## วาดกรอบพื้นที่เกิดให้เห็นในโปรแกรมแก้ไข
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var b := _find_map_bounds()
	var rect := Rect2(b.position - global_position + Vector2(edge_margin, 0),
		Vector2(b.size.x - edge_margin * 2.0, b.size.y))
	draw_rect(rect, Color(0.2, 0.9, 0.4, 0.08))
	draw_rect(rect, Color(0.2, 0.9, 0.4, 0.7), false, 2.0)
