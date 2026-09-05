## LightningStrike — สกิล "สายฟ้าฟาดเป็นแนว" ของมอน/บอส (รอบ 64)
##
## ★ ใช้ยังไง ★ ไม่ต้องสร้างโหนดเอง — ไปตั้งใน MonsterData (.tres) กลุ่ม
## "สกิล — สายฟ้าฟาดเป็นแนว" แล้วใส่ Skill Bolt Count มากกว่า 0
## ตอนมอนร่ายสกิล ระบบจะเรียกให้อัตโนมัติ
##
## ★ ทำงานยังไง ★
##   ฟาดทีละเส้น เรียงออกไป "ข้างหน้าตามที่มอนหัน" (เส้นแรกใกล้ตัว เส้นสุดท้ายไกลสุด)
##   แต่ละเส้น: วงเตือนบนพื้นสว่างขึ้นเรื่อย ๆ (Telegraph) → สายฟ้าฟาด → เช็คดาเมจ
##   ผู้เล่นยืนอยู่ในช่วงไหนตอนเส้นนั้นฟาดถึงจะโดน — เห็นวงเตือนแล้ววิ่งหนีทัน
##
## ทั้งชุดเป็นโหนดเดียวที่เกิด "ในแมพ" ไม่ใช่ลูกของตัวมอน (เลยยาวเกินตัวมอนได้)
class_name LightningStrike
extends Node2D

## SpriteFrames เริ่มต้นถ้าไม่ได้ใส่ในช่อง Skill Bolt Frames
const DEFAULT_FRAMES := "res://data/sprites/fx_lightning.tres"
## ชื่อท่าในไฟล์นั้น
const BOLT_ANIM := "bolt"
## สีวงเตือนบนพื้น
const WARN_COLOR := Color("#7fd4ff")
## เศษเวลาที่ปล่อยให้เอฟเฟกต์เล่นต่อหลังฟาดเส้นสุดท้าย ก่อนลบโหนดทิ้ง
const TAIL_TIME := 1.2

var _data: MonsterData
var _caster: Node2D
var _ground_y := 0.0
var _hits := 0                     ## ผู้เล่นโดนไปแล้วกี่เส้น (จำกัดด้วย Skill Bolt Max Hits)
var _marks: Array = []             ## วงเตือนที่กำลังนับถอยหลัง {"x", "y", "left", "total"}
var _base_ground := 0.0            ## ระดับพื้นที่ยิงเส้นเจอ "ตรงใต้ตัวมอน" (ไว้หักลบ)
var _has_base := false


## ★ เรียกจาก monster_base ตอนร่ายสกิล ★ คืน null ถ้ามอนตัวนี้ไม่ได้ตั้งสายฟ้าไว้
static func cast(data: MonsterData, caster: Node2D, facing: int) -> LightningStrike:
	if data == null or caster == null or data.skill_bolt_count <= 0:
		return null
	var tree := caster.get_tree()
	if tree == null:
		return null
	var parent: Node = tree.get_first_node_in_group("map")
	if parent == null:
		parent = tree.current_scene
	if parent == null:
		return null

	var node := LightningStrike.new()
	node.name = "LightningStrike_%s" % String(data.id)
	node._data = data
	node._caster = caster
	node.z_index = data.skill_bolt_z
	# จุดอ้างอิง = ตรงเท้ามอนตอนเริ่มร่าย (สายฟ้าไม่วิ่งตามมอน)
	var foot: Vector2 = caster.foot_position() if caster.has_method("foot_position") \
		else caster.global_position
	node._ground_y = foot.y
	node.position = foot - parent.global_position
	parent.add_child(node)
	node._run(1 if facing >= 0 else -1)
	return node


func _process(delta: float) -> void:
	if _marks.is_empty():
		return
	var alive: Array = []
	for m in _marks:
		m.left -= delta
		if m.left > 0.0:
			alive.append(m)
	_marks = alive
	queue_redraw()


## วงเตือนบนพื้น — ยิ่งใกล้ฟาดยิ่งสว่างและวงหด
func _draw() -> void:
	for m in _marks:
		var t: float = 1.0 - clampf(float(m.left) / maxf(0.01, float(m.total)), 0.0, 1.0)
		var rx: float = _data.skill_bolt_hit_width * (1.35 - 0.45 * t)
		var ry: float = rx * 0.32
		var a: float = 0.25 + 0.55 * t
		var center := Vector2(float(m.x), float(m.get("y", 0.0)))
		# วงนอก (ขอบ) + วงในที่ค่อย ๆ เต็ม
		draw_arc(center, rx, 0.0, TAU, 40, Color(WARN_COLOR, a * 0.9), 3.0)
		draw_set_transform(center, 0.0, Vector2(1.0, ry / maxf(1.0, rx)))
		draw_circle(Vector2.ZERO, rx * t, Color(WARN_COLOR, a * 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _run(dir: int) -> void:
	var d := _data
	await get_tree().create_timer(maxf(0.0, d.skill_bolt_delay)).timeout
	if not is_instance_valid(self):
		return

	for i in range(d.skill_bolt_count):
		if not is_instance_valid(self):
			return
		var x: float = (d.skill_bolt_start + d.skill_bolt_spacing * i) * dir
		# ★ หาพื้นจริงตรงจุดนั้น ★ พื้นลาด/ต่างระดับ สายฟ้าก็ยังลงตรงพื้น ไม่ลอย
		var y := _ground_offset_at(x)
		# วงเตือนขึ้นก่อน แล้วค่อยฟาด
		if d.skill_bolt_telegraph > 0.0:
			_marks.append({"x": x, "y": y, "left": d.skill_bolt_telegraph, "total": d.skill_bolt_telegraph})
			queue_redraw()
			await get_tree().create_timer(d.skill_bolt_telegraph).timeout
			if not is_instance_valid(self):
				return
		_strike(x, y)
		if i < d.skill_bolt_count - 1:
			await get_tree().create_timer(maxf(0.02, d.skill_bolt_interval)).timeout

	await get_tree().create_timer(TAIL_TIME).timeout
	if is_instance_valid(self):
		queue_free()


## ยิงเส้นลงหาพื้นตรงระยะ x — คืน y ของพื้น (พิกัดโลก) หรือ INF ถ้าไม่เจอ
func _raycast_ground(x: float) -> float:
	var world := get_world_2d()
	if world == null or world.direct_space_state == null:
		return INF
	var from := Vector2(global_position.x + x, global_position.y - 500.0)
	var to := Vector2(global_position.x + x, global_position.y + 400.0)
	var q := PhysicsRayQueryParameters2D.create(from, to)
	q.collision_mask = 1
	var hit := world.direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return INF
	return float(hit.position.y)


## ระดับพื้นตรงระยะ x เทียบกับจุดยืนของมอน (คืนค่า y แบบ local)
##
## ★ ทำไมต้องหักลบ ★ จุดที่ "เท้ามอน" อยู่ กับผิวพื้นที่เส้นยิงไปเจอ มักไม่ตรงกันเป๊ะ
## (กล่องชนของมอนไม่ได้จบพอดีที่ผิวพื้น) ถ้าเอาค่าดิบมาใช้ สายฟ้าจะลงต่ำกว่าเท้ามอน
## เลยยิงเส้นใต้ตัวมอนไว้เป็น "ค่าอ้างอิง" แล้วเอาส่วนต่างมาใช้แทน
## → พื้นราบ = ลงตรงระดับเท้าพอดี · พื้นลาด/ต่างระดับ = ไล่ตามพื้นจริง
func _ground_offset_at(x: float) -> float:
	if not _has_base:
		_base_ground = _raycast_ground(0.0)
		_has_base = true
	if is_inf(_base_ground):
		return 0.0
	var here := _raycast_ground(x)
	if is_inf(here):
		return 0.0
	# ต่างระดับเกินครึ่งความสูงที่โดน = คนละชั้น ไม่ต้องไล่ตาม (กันสายฟ้าไปลงหลังคา/ใต้ดิน)
	var diff := here - _base_ground
	if absf(diff) > _data.skill_bolt_hit_height:
		return 0.0
	return diff


## ฟาด 1 เส้นที่ระยะ x (นับจากตัวมอน) · y = ระดับพื้นตรงนั้น — ภาพ + เสียง + ดาเมจ
func _strike(x: float, y: float = 0.0) -> void:
	var d := _data

	# ---------- ภาพ ----------
	var frames: SpriteFrames = d.skill_bolt_frames
	if frames == null and ResourceLoader.exists(DEFAULT_FRAMES):
		frames = load(DEFAULT_FRAMES)
	if frames != null:
		var sp := AnimatedSprite2D.new()
		sp.sprite_frames = frames
		var anim := BOLT_ANIM
		if not frames.has_animation(anim):
			var names := frames.get_animation_names()
			anim = String(names[0]) if names.size() > 0 else ""
		if anim != "":
			# ★ จุดตกอยู่ขอบล่างของภาพ ★ เลยต้องยกภาพขึ้นครึ่งหนึ่งของความสูง
			var tex := frames.get_frame_texture(anim, 0)
			var k := 1.0
			if tex != null and d.skill_bolt_height > 0.0:
				k = d.skill_bolt_height / maxf(1.0, tex.get_size().y)
			sp.scale = Vector2(k, k)
			if tex != null:
				sp.position = Vector2(x, y - tex.get_size().y * k * 0.5)
			else:
				sp.position = Vector2(x, y - d.skill_bolt_height * 0.5)
			sp.animation = anim
			sp.z_index = 0
			add_child(sp)
			sp.play(anim)
			sp.animation_finished.connect(sp.queue_free)

	# ---------- เสียง ----------
	if d.skill_bolt_sfx != "" and Game.sfx != null:
		Game.sfx.play(d.skill_bolt_sfx, 1.0, 0.12)

	# ---------- ดาเมจ ----------
	if d.skill_bolt_max_hits > 0 and _hits >= d.skill_bolt_max_hits:
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player) or PlayerState.is_dead():
		return
	var pf: Vector2 = player.foot_position() if player.has_method("foot_position") \
		else player.global_position
	var hit_center := global_position + Vector2(x, y)
	if absf(pf.x - hit_center.x) > d.skill_bolt_hit_width:
		return
	if absf(pf.y - hit_center.y) > d.skill_bolt_hit_height:
		return

	_hits += 1
	var mult: float = d.skill_bolt_damage_mult if d.skill_bolt_damage_mult > 0.0 else d.skill_damage_mult
	var result := Combat.monster_hits_player(d, PlayerState.stats)
	var damage: int = maxi(1, int(round(result.damage * mult)))
	if player.has_method("take_damage"):
		# กระเด็นออกจากจุดที่ฟ้าลง
		var kb_dir: int = 1 if pf.x >= hit_center.x else -1
		player.take_damage(damage, d.skill_knockback, kb_dir)
