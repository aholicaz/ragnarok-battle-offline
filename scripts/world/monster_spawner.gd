## MonsterSpawner — จุดเกิดมอนสเตอร์
##
## วิธีใช้: วาง Node นี้ในแมพ -> ใส่ MonsterData (.tres) ที่อยากให้เกิด
##          ตั้งจำนวน และความกว้างของพื้นที่เกิด
## หนึ่งแมพวางได้หลายตัว = มอนหลายชนิดในแมพเดียว
extends Node2D

## ★ มอนสเตอร์ที่จะเกิดตรงนี้ ★ (ใส่ได้หลายชนิด ระบบจะสุ่ม)
@export var monster_types: Array[MonsterData] = []
## Scene ต้นแบบของมอน (ใช้ monster_base.gd) — ปกติคือ res://scenes/monsters/monster.tscn
@export var monster_scene: PackedScene
@export var max_alive: int = 3
## เกิดกระจายในพื้นที่กว้างเท่าไหร่ (พิกเซล)
@export var spawn_width: float = 400.0
@export var spawn_height: float = 40.0
## หน่วงก่อนเกิดชุดแรก
@export var initial_delay: float = 0.5
## เกิดใหม่หลังตายกี่วินาที (0 = ใช้ค่า respawn_time ของ MonsterData)
@export var respawn_override: float = 0.0
## เกิดเฉพาะตอนผู้เล่นเข้าใกล้ (ช่วยประหยัดเครื่องในแมพใหญ่)
@export var only_spawn_when_player_near: bool = false
@export var activation_range: float = 1200.0
## ★ รอบ 59 ★ บอสยังติดคูลดาวน์ → เกิดเป็น "ศพ" ค้างเฟรมสุดท้าย + ป้ายนับถอยหลัง (ปิด = ว่างเปล่าจนกว่าจะครบเวลา)
@export var spawn_corpse_while_locked: bool = true

var _alive: Array = []
var _pending := 0


func _ready() -> void:
	if monster_scene == null:
		monster_scene = load("res://scenes/monsters/monster.tscn")
	if monster_types.is_empty():
		push_warning("[Spawner] %s ยังไม่ได้ใส่ MonsterData" % name)
		return
	await get_tree().create_timer(initial_delay).timeout
	_fill()


func _process(_delta: float) -> void:
	_alive = _alive.filter(func(m): return is_instance_valid(m))
	if _alive.size() + _pending < max_alive:
		if only_spawn_when_player_near and not _player_near():
			return
		_fill()


func _player_near() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return false
	return global_position.distance_to(p.global_position) <= activation_range


func _fill() -> void:
	# ★ รอบ 56 ★ _spawn_one คืน false ได้ (เช่นบอสยังติดคูลดาวน์) — ต้องหยุดวน ไม่งั้นค้างทั้งเกม
	while _alive.size() + _pending < max_alive:
		if not _spawn_one():
			return


func _spawn_one() -> bool:
	if monster_scene == null or monster_types.is_empty():
		return false

	var data: MonsterData = monster_types.pick_random()
	if data == null:
		return false

	# ★ รอบ 56/59 — ยังติดคูลดาวน์เกิดใหม่ (บอส) ★
	# รอบ 59: เกิดมาเป็น "ศพ" ค้างเฟรมสุดท้าย + ป้ายนับถอยหลังแทน (ผู้เล่นเห็นว่าอีกกี่วิจะเกิด)
	# ศพนับเป็น _alive ด้วย → สปอว์นเนอร์ไม่พยายามเกิดซ้ำ · ศพลบตัวเองตอนครบเวลา แล้ว _process เกิดตัวจริงให้
	var as_corpse: bool = data.uses_persistent_respawn() and not PlayerState.can_respawn(data.id)
	if as_corpse and not spawn_corpse_while_locked:
		return false

	var monster := monster_scene.instantiate()
	monster.data = data

	get_parent().add_child(monster)
	monster.global_position = global_position + Vector2(
		randf_range(-spawn_width * 0.5, spawn_width * 0.5),
		randf_range(-spawn_height, 0.0)
	)
	if as_corpse and monster.has_method("spawn_as_corpse"):
		monster.spawn_as_corpse()
		_alive.append(monster)
		return true

	# สำคัญ: ต้องบอกจุดเกิดหลังวางตำแหน่งเสร็จ
	# ไม่งั้นมอนจะคิดว่าบ้านอยู่ที่ (0,0) แล้วเดินกลับบ้านตลอดเวลา
	if monster.has_method("set_home"):
		monster.set_home(monster.global_position)

	if monster.has_signal("died"):
		monster.died.connect(_on_monster_died)

	_alive.append(monster)
	return true


func _on_monster_died(_monster: Node, data: MonsterData) -> void:
	# บอส/มอนที่ใช้คูลดาวน์ข้ามแมพ: monster_base ล็อกเวลาไว้ในเซฟแล้ว
	# ตรงนี้แค่กันไม่ให้เกิดทันทีในแมพเดิม (เช็คซ้ำอีกชั้นตอน _spawn_one)
	if data.uses_persistent_respawn():
		return
	var wait: float = respawn_override if respawn_override > 0.0 else data.respawn_time
	_pending += 1
	await get_tree().create_timer(wait).timeout
	_pending -= 1


## วาดกรอบพื้นที่เกิดให้เห็นในโปรแกรมแก้ไข
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(Vector2(-spawn_width * 0.5, -spawn_height), Vector2(spawn_width, spawn_height))
	draw_rect(rect, Color(1, 0.4, 0.2, 0.25))
	draw_rect(rect, Color(1, 0.4, 0.2, 0.9), false, 2.0)
