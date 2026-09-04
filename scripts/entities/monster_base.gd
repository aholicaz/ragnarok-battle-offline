## MonsterBase — มอนสเตอร์ทุกตัวใช้สคริปต์นี้ตัวเดียว
##
## เพิ่มมอนใหม่ = สร้างไฟล์ MonsterData (.tres) ใหม่ แล้วลากใส่ช่อง "Data"
## ไม่ต้องเขียนสคริปต์ใหม่ ไม่ต้องสร้าง Scene ใหม่
##
## โครงสร้าง Scene:
##   Monster (CharacterBody2D)  <- ใส่สคริปต์นี้
##   ├── AnimatedSprite2D
##   └── CollisionShape2D  (ใช้ CapsuleShape2D)
extends CharacterBody2D

enum State { IDLE, WANDER, CHASE, ATTACK, HURT, DEAD }

## มอนใจดีที่ถูกตี จะไล่ตามต่ออีกกี่วินาทีหลังคลาดสายตา
## ★ รอบ 44: ไม่ใช้แล้ว ★ — โดนตี/เห็นผู้เล่น = ไล่ไม่หยุดจนกว่าผู้เล่นหรือมอนตัวนั้นตาย
const AGGRO_MEMORY := 8.0

## ★ ขนาดตัวเลขดาเมจ ★ อยากให้ใหญ่ขึ้นอีก แก้สองเลขนี้
const DAMAGE_FONT_SIZE := 32
const DAMAGE_FONT_CRIT := 40

signal died(monster: Node, data: MonsterData)

## ★ ลาก MonsterData (.tres) มาใส่ตรงนี้ ★
@export var data: MonsterData

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var hp: int = 1
var state: State = State.IDLE
var spawn_position: Vector2
var facing: int = -1

var _player: Node2D = null
var _attack_timer := 0.0
var _wander_timer := 0.0
var _wander_dir := 0
var _look_timer := 0.0
## ★ กันติดกำแพง (รอบ 35) ★ จะเดินแต่ไม่ขยับ = ติด
var _stuck_time := 0.0
var _last_x := 0.0
var _want_vx := 0.0   # ความเร็วที่ "ตั้งใจ" ก่อน move_and_slide (มันแก้ velocity ให้หลังไถล)      # ★ หันมองรอบ ๆ ระหว่างยืนพัก (รอบ 33) ★ 0 = ไม่ต้องหัน
var _hurt_flash := 0.0
var _hp_bar: ProgressBar
var _aggro := false
var _aggro_timer := 0.0
## ★ รอบ 44 — "ล็อกเป้า" แล้ว ★ มอนที่เห็นผู้เล่น (ตัวดุ) หรือโดนตี (ทุกตัว)
## จะไล่ตามได้ไกลไม่จำกัด ไม่สนระยะ leash/detect อีก จนกว่าผู้เล่นตาย หรือมันตาย
var _aggro_locked := false
var _jump_cd := 0.0
var _skill_cd := 0.0
var _spawn_locked := false
var _fit_cache: Dictionary = {}
## ★ รอบ 54 — บิน ★ เฟสของการโยกขึ้นลง (สุ่มเริ่ม ไม่งั้นทั้งฝูงโยกพร้อมกัน)
var _hover_t: float = randf() * TAU
## โหลดฉากของตกไว้ล่วงหน้า (รอบ 44 — เดิม load() ตอนมอนตาย)
const DROPPED_ITEM_SCENE: PackedScene = preload("res://scenes/items/dropped_item.tscn")


## ให้ Spawner เรียกหลังวางตำแหน่งเสร็จ เพื่อบอกว่า "บ้าน" อยู่ตรงไหน
func set_home(pos: Vector2) -> void:
	spawn_position = pos
	_last_x = global_position.x
	# ★ สุ่มจังหวะเริ่มต้น ★ ไม่งั้นมอนทั้งฝูงจะเดิน/หยุดพร้อมกันเป๊ะ ดูเป็นหุ่นยนต์
	_wander_timer = randf() * 1.5
	_wander_dir = 0 if randf() < 0.35 else (-1 if randf() < 0.5 else 1)
	_spawn_locked = true


func _ready() -> void:
	add_to_group("enemy")
	if not _spawn_locked:
		spawn_position = global_position

	if data == null:
		push_error("[Monster] ยังไม่ได้ใส่ MonsterData ให้ %s" % name)
		set_physics_process(false)
		return

	hp = data.max_hp
	_apply_visual()
	_create_hp_bar()
	_aggro = data.ai_type == MonsterData.AIType.AGGRESSIVE
	# กันบอสร่ายสกิลใส่ทันทีที่เห็นหน้า
	_skill_cd = data.skill_cooldown * 0.5


func _apply_visual() -> void:
	if data.sprite_frames != null:
		sprite.sprite_frames = data.sprite_frames
	sprite.scale = data.sprite_scale
	sprite.offset = data.sprite_offset

	if collision != null and collision.shape is CapsuleShape2D:
		var shape := (collision.shape as CapsuleShape2D).duplicate() as CapsuleShape2D
		shape.radius = data.hitbox_size.x * 0.5
		shape.height = maxf(data.hitbox_size.y, shape.radius * 2.0)
		collision.shape = shape

	_play("Idle")
	_apply_fit()


# =========================================================
# ปรับขนาด/จัดเท้าให้ยืนระนาบเดียวกับผู้เล่น
# =========================================================
## ตำแหน่งเท้าในโลก — ใช้เทียบระนาบกับผู้เล่น
func foot_position() -> Vector2:
	if data == null:
		return global_position
	return global_position + Vector2(0.0, data.foot_offset())


## ★ ขนาดตัวจริงบนจอ (กว้าง, สูง) ★ ใช้ตัดสินว่าดาบผู้เล่นฟันถึงไหม
## ขยายมอนให้ใหญ่ขึ้น = กรอบนี้ใหญ่ตามเอง ไม่ต้องไปแก้ระยะที่ไหนอีก
func body_size() -> Vector2:
	var w := 40.0
	var h := 60.0
	if data != null:
		w = maxf(data.hitbox_size.x, 16.0)
		h = maxf(data.hitbox_size.y, 16.0)
		if data.display_height > 0.0:
			h = maxf(h, data.display_height)
	# ถ้าไม่ได้ตั้ง Display Height ก็วัดจากสไปรท์จริง
	if sprite != null and sprite.sprite_frames != null:
		var info: Dictionary = _fit_frames(sprite.animation)
		if not info.is_empty():
			h = maxf(h, float(info.tallest) * absf(sprite.scale.y))
	# ตัวสูงแต่กล่องชนแคบมาก ๆ ให้กว้างขึ้นหน่อย ไม่งั้นฟันยาก
	w = maxf(w, h * 0.35)
	return Vector2(w, h)


## ★ กรอบตัวมอนในพิกัดโลก ★ (เท้าอยู่ขอบล่าง)
func body_rect() -> Rect2:
	var f := foot_position()
	var s := body_size()
	# ★ รอบ 54: มอนบิน — กรอบโดนฟันลอยขึ้นตามภาพ (ฟันที่พื้นจะไม่โดน ต้องฟันที่ตัวมัน) ★
	return Rect2(f.x - s.x * 0.5, f.y - s.y - hover_lift(), s.x, s.y)


## ระยะที่มอนตัวนี้ตีถึง — วัดจาก "ขอบตัวมัน" ออกไป
## (บอสตัวใหญ่จะได้ไม่ต้องเอาจุดกึ่งกลางมาจ่อตัวผู้เล่นถึงจะตีโดน)
func attack_reach() -> float:
	if data == null:
		return 70.0
	return data.attack_range + body_size().x * 0.5


func _apply_fit() -> void:
	if data == null or sprite.sprite_frames == null:
		return
	if data.display_height <= 0.0 and not data.align_feet:
		return

	var info: Dictionary = _fit_frames(sprite.animation)
	if info.is_empty():
		return

	var k: float = info.scale
	sprite.scale = Vector2(k, k)

	var list: Array = info.frames
	if list.is_empty():
		return
	var fd: Dictionary = list[clampi(sprite.frame, 0, list.size() - 1)]

	sprite.offset.x = data.sprite_offset.x + (fd.dx_use if sprite.flip_h else -fd.dx_use)
	if data.align_feet:
		sprite.offset.y = data.sprite_offset.y + data.foot_offset() / k - fd.bottom_use


## วัดขนาดจริงของมอน (ไม่นับพื้นที่โปร่งใส) แล้วจำไว้
func _fit_frames(anim: StringName) -> Dictionary:
	if _fit_cache.has(anim):
		return _fit_cache[anim]

	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return {}

	# ★ รอบ 44 — วัดผ่าน SpriteFit (วัดครั้งเดียวทั้งเกมต่อชนิดมอน ไม่ใช่ทุกครั้งที่เกิด) ★
	var base: Dictionary = SpriteFit.measure(frames, anim)
	if base.is_empty():
		return {}
	var list: Array = base.frames
	var tallest: float = base.tallest

	var k: float = data.sprite_scale.y
	if data.display_height > 0.0:
		k = data.display_height / maxf(1.0, tallest)

	var info := {"scale": k, "frames": list, "tallest": tallest}
	_fit_cache[anim] = info
	return info


func _process(delta: float) -> void:
	_apply_fit()
	_apply_hover(delta)


# =========================================================
# ★ บิน / ลอยเหนือพื้น (รอบ 54) ★
# ตัวมอน (กล่องชน/foot_position) ยังอยู่บนพื้นตามเดิม → AI, ระนาบ, ระยะตี ไม่เปลี่ยน
# ยกเฉพาะ "ภาพ + หลอดเลือด" ขึ้นไป และ body_rect() (กรอบโดนฟัน) ขยับตามให้ผู้เล่นฟันโดนที่ตัวจริง
# =========================================================
## มอนบินตายแล้วร่วงลงพื้นเร็วแค่ไหน (พิกเซล/วินาที)
const HOVER_FALL_SPEED := 320.0

## ระยะที่ภาพลอยเหนือพื้นตอนนี้ (พิกเซลโลก · 0 = มอนธรรมดา)
func hover_lift() -> float:
	if data == null or not data.flying or state == State.DEAD:
		return 0.0
	return data.hover_height + sin(_hover_t) * data.hover_bob


func _apply_hover(delta: float) -> void:
	if data == null or not data.flying:
		return
	if state == State.DEAD:
		# ตายแล้วร่วงลงพื้น (ไม่วูบหายทันที)
		sprite.position.y = move_toward(sprite.position.y, 0.0, HOVER_FALL_SPEED * delta)
		return
	_hover_t += delta * TAU * data.hover_bob_speed
	var lift := hover_lift()
	sprite.position.y = -lift
	if _hp_bar != null:
		_hp_bar.position.y = data.hp_bar_offset_y - lift


# =========================================================
# PHYSICS
# =========================================================
func _physics_process(delta: float) -> void:
	_check_boss_intro()
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		if _hurt_flash <= 0.0:
			sprite.modulate = Color.WHITE

	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _jump_cd > 0.0:
		_jump_cd -= delta
	if _skill_cd > 0.0:
		_skill_cd -= delta

	# ★ รอบ 44 — ความโกรธไม่จางอีกแล้ว ★ (เดิมมอนใจดีเลิกไล่หลัง 8 วิ)
	# เลิกไล่อย่างเดียวคือผู้เล่นตาย → กลับไปเดินเล่นตามปกติ
	_player = get_tree().get_first_node_in_group("player")
	if _aggro_locked and (_player == null or not is_instance_valid(_player) or PlayerState.is_dead()):
		_aggro_locked = false
		_aggro = data.ai_type == MonsterData.AIType.AGGRESSIVE

	if state == State.ATTACK or state == State.HURT:
		velocity.x = move_toward(velocity.x, 0.0, data.move_speed * 4.0 * delta)
		move_and_slide()
		return

	var home_offset := global_position.x - spawn_position.x
	# ★ รอบ 44 — ล็อกเป้าแล้วไม่มี "กำแพงระยะ" ★ ไล่ไปได้ทั่วแมพ
	var too_far_from_home: bool = (not _aggro_locked) and data.leash_range > 0.0 \
		and absf(home_offset) > data.leash_range

	# ------- ตัดสินใจว่าจะสู้ไหม -------
	# วัดจาก "ตำแหน่งเท้า" ทั้งคู่ จะได้ไม่เพี้ยนเพราะกล่องชนคนละขนาด
	var distance := INF
	var to_player_x := 0.0
	if _player != null and is_instance_valid(_player) and not PlayerState.is_dead():
		var player_foot: Vector2 = _player.foot_position() if _player.has_method("foot_position") \
			else _player.global_position
		var to_player: Vector2 = player_foot - foot_position()
		distance = to_player.length()
		to_player_x = to_player.x

	# มอนดุ = เห็นแล้วไล่เลย / มอนใจดี = ไล่เฉพาะตอนถูกตี
	var hostile: bool = _aggro or data.ai_type == MonsterData.AIType.AGGRESSIVE
	# ★ รอบ 44 — มอนดุที่ "เห็น" ผู้เล่นครั้งแรก (เข้าระยะ detect) = ล็อกเป้าทันที ★
	if hostile and not _aggro_locked and distance <= data.detect_range \
			and data.ai_type != MonsterData.AIType.STATIONARY:
		_set_aggro()
	# ล็อกเป้าแล้ว = ไล่ได้ไกลไม่จำกัด (เดิมจำกัดที่ detect/leash → มอนวิ่งไปชน "กำแพงระยะ" แล้วหยุด)
	var chase_range: float = INF if _aggro_locked else data.detect_range
	var will_engage: bool = hostile and distance <= chase_range and not too_far_from_home

	if data.ai_type == MonsterData.AIType.STATIONARY:
		velocity.x = 0.0
		if hostile and _try_skill(distance, to_player_x):
			move_and_slide()
			return
		if distance <= attack_reach():
			_face_to(to_player_x)
			_try_attack()
		else:
			_play("Idle")

	elif will_engage:
		# ★ บอสร่ายสกิลได้จากระยะไกลกว่าการตีปกติ ★
		if _try_skill(distance, to_player_x):
			move_and_slide()
			return
		if distance <= attack_reach():
			velocity.x = 0.0
			_face_to(to_player_x)
			_try_attack()
		else:
			state = State.CHASE
			_face_to(to_player_x)
			var chase_dir := signi(int(signf(to_player_x)))
			# มอนที่กระโดดไม่ได้ จะไม่เดินตกเหวตามผู้เล่น
			if data.jump_force == 0.0 and not _has_ground_ahead(chase_dir):
				velocity.x = 0.0
				_play("Idle")
			else:
				velocity.x = chase_dir * data.move_speed
				_play("Run")
				if data.jump_while_chasing:
					_try_hop(1.0)

	elif too_far_from_home:
		# เดินกลับบ้าน
		state = State.WANDER
		var back := signf(-home_offset)
		velocity.x = back * data.move_speed * 0.6
		_face_to(back)
		_play("Run")
		if data.jump_while_chasing:
			_try_hop(0.8)

	else:
		_do_wander(delta)

	_want_vx = velocity.x
	move_and_slide()
	_check_stuck(delta)


## มีพื้นอยู่ข้างหน้าไหม (กันมอนเดินตกขอบแมพ/ตกแท่น)
func _has_ground_ahead(dir: int) -> bool:
	if dir == 0 or not is_on_floor():
		return true
	var space := get_world_2d().direct_space_state
	var ahead := global_position + Vector2(dir * (data.hitbox_size.x * 0.5 + 14.0), -4.0)
	var query := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 110.0))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


## กระโดดตามจังหวะ ไม่ใช่กระโดดรัวทุกเฟรม
func _try_hop(power_scale: float = 1.0) -> void:
	if data.jump_force == 0.0:
		return
	if data.flying and data.flying_no_hop:
		return                      # ★ รอบ 54: มอนบินไม่กระโดด (โยกขึ้นลงแทน) ★
	if not is_on_floor() or _jump_cd > 0.0:
		return
	velocity.y = data.jump_force * power_scale
	_jump_cd = maxf(0.15, data.jump_interval)
	_play("Jump")


# =========================================================
# ★★ กันมอนติดกำแพง (รอบ 35) ★★
# =========================================================
## ขยับได้ช้ากว่านี้ (พิกเซล/วินาที) ทั้งที่สั่งให้เดิน = ถือว่าติด
const STUCK_SPEED := 8.0
## ติดนานเกินนี้ (วินาที) ถึงจะแก้ให้
const STUCK_LIMIT := 0.7

func _check_stuck(delta: float) -> void:
	if state == State.DEAD or state == State.ATTACK or state == State.HURT:
		_stuck_time = 0.0
		_last_x = global_position.x
		return
	var moved: float = absf(global_position.x - _last_x)
	_last_x = global_position.x

	# สั่งให้เดินอยู่ แต่แทบไม่ขยับ = โดนอะไรบางอย่างขวาง
	if absf(_want_vx) > 1.0 and moved < STUCK_SPEED * delta:
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.0)
		return

	if _stuck_time < STUCK_LIMIT:
		return
	_stuck_time = 0.0
	_free_from_wall()


## ★ หลุดจากกำแพง ★ กลับตัว + ย้าย "บ้าน" มาฝั่งนี้
## ถ้าไม่ย้ายบ้าน ระบบ leash จะลากมันกลับไปชนกำแพงเดิมซ้ำ ๆ ไม่จบ
func _free_from_wall() -> void:
	var away: int = -signi(int(signf(_want_vx)))
	if away == 0:
		away = -facing

	# กระโดดข้ามได้ก็ลองข้ามก่อน (มอนที่กระโดดไม่ได้ jump_force = 0)
	if data.jump_force < 0.0 and is_on_floor():
		velocity.y = data.jump_force

	# กำลังไล่ผู้เล่นอยู่ ไม่ต้องเลิกไล่ แค่ลองกระโดดข้าม
	if state == State.CHASE:
		return

	_wander_dir = away
	_wander_timer = randf_range(1.2, 2.2)
	_look_timer = 0.0
	velocity.x = away * data.wander_speed
	_face_to(away)
	# ★ ย้ายบ้านมาอยู่ฝั่งที่เดินได้ ★
	spawn_position.x = global_position.x + away * 60.0


# =========================================================
# เดินเล่นไปมารอบจุดเกิด
# =========================================================
func _do_wander(delta: float) -> void:
	if data.wander_speed <= 0.0:
		state = State.IDLE
		velocity.x = move_toward(velocity.x, 0.0, data.move_speed)
		_play("Idle")
		return

	state = State.WANDER
	_wander_timer -= delta

	if _wander_timer <= 0.0:
		_pick_new_wander()

	var offset := global_position.x - spawn_position.x
	var limit: float = data.wander_range
	if data.leash_range > 0.0:
		limit = minf(limit, data.leash_range * 0.9)

	# ออกนอกอาณาเขต -> เดินกลับ (ตั้งเวลาไว้ด้วย จะได้ไม่สลับทิศทุกเฟรม)
	if absf(offset) > limit:
		var back := -1 if offset > 0.0 else 1
		if _wander_dir != back:
			_wander_dir = back
			_wander_timer = randf_range(1.0, 2.0)

	# ชนกำแพง หรือ ข้างหน้าเป็นเหว -> กลับตัว
	elif _wander_dir != 0 and (is_on_wall() or not _has_ground_ahead(_wander_dir)):
		_wander_dir = -_wander_dir
		_wander_timer = randf_range(1.0, 2.0)

	if _wander_dir == 0:
		# ★ ยืนพัก ★ หยุดสนิทแล้วเล่นท่า Idle
		velocity.x = move_toward(velocity.x, 0.0, data.wander_speed * 4.0)
		_play("Idle")
		# หันไปมองอีกด้านหนึ่งกลางช่วงพัก — ทำให้ดูเหมือนกำลังมองรอบ ๆ ไม่ใช่ค้างแข็ง
		if _look_timer > 0.0:
			_look_timer -= delta
			if _look_timer <= 0.0:
				_face_to(-facing)
	else:
		velocity.x = _wander_dir * data.wander_speed
		_face_to(_wander_dir)
		_play("Run")
		if data.hop_while_wandering:
			_try_hop(0.55)


func _pick_new_wander() -> void:
	# ★★ สลับ "เดิน" กับ "ยืนพัก" ★★ (รอบ 33 — ปรับค่าได้ต่อมอนในไฟล์ .tres)
	# ห้ามพักติดกัน 2 รอบ (เช็ค _wander_dir != 0) ไม่งั้นมอนจะยืนแช่ยาวผิดปกติ
	if _wander_dir != 0 and randf() < data.wander_pause_chance:
		_wander_dir = 0
		_wander_timer = randf_range(data.wander_pause_min, data.wander_pause_max)
		# หันมองรอบ ๆ ประมาณกลางช่วงพัก
		_look_timer = _wander_timer * randf_range(0.35, 0.65) \
			if randf() < data.wander_look_chance else 0.0
	else:
		_wander_dir = -1 if randf() < 0.5 else 1
		_wander_timer = randf_range(data.wander_walk_min, data.wander_walk_max)
		_look_timer = 0.0


func _face_to(dir_x: float) -> void:
	if dir_x == 0.0:
		return
	facing = 1 if dir_x > 0.0 else -1
	sprite.flip_h = facing > 0   # สไปรท์ต้นฉบับหันซ้าย


## ★ ชื่ออนิเมชันที่ระบบยอมรับ ★
## ตั้งชื่อแบบไหนก็ได้ในลิสต์ และ "ตัวพิมพ์เล็ก-ใหญ่ไม่สำคัญ" (Die = die = DIE)
## ถ้าไม่มีชื่อไหนเลย จะไล่ลงไปใช้ตัวสำรองท้ายลิสต์แทน (กันมอนค้าง/หาย)
const ANIM_FALLBACK := {
	"Idle": ["Idle", "Stand"],
	"Run": ["Run", "Walk", "Move", "Jump", "Idle"],
	"Jump": ["Jump", "Hop", "Run", "Idle"],
	"Attack": ["Attack", "Atk", "Attact", "Idle"],
	"Hit": ["Hit", "Hurt", "Damage", "Idle"],
	"Death": ["Death", "Die", "Dead", "Dying", "Hit", "Idle"],
}

var _anim_lookup: Dictionary = {}   # ชื่อตัวพิมพ์เล็ก -> ชื่อจริงใน SpriteFrames


## หาชื่ออนิเมชันจริง โดยไม่สนตัวพิมพ์เล็ก-ใหญ่
func _real_anim(anim_name: String) -> String:
	if sprite.sprite_frames == null:
		return ""
	if sprite.sprite_frames.has_animation(anim_name):
		return anim_name
	if _anim_lookup.is_empty():
		for a in sprite.sprite_frames.get_animation_names():
			_anim_lookup[String(a).to_lower()] = String(a)
	return _anim_lookup.get(anim_name.to_lower(), "")


## เล่นท่านี้ แล้วคืนชื่อท่าที่ได้เล่นจริง ("" = ไม่มีท่าไหนใช้ได้เลย)
func _play(anim: String) -> String:
	if sprite.sprite_frames == null:
		return ""
	for candidate in ANIM_FALLBACK.get(anim, [anim]):
		var real := _real_anim(String(candidate))
		if real != "" and sprite.sprite_frames.get_frame_count(real) > 0:
			# ★ รอบ 54 — กับดัก 82 ★ มอนที่มีท่าเดียว (เช่นฮอร์เน็ต มีแค่ Idle): ตอนใส่ SpriteFrames
			# Godot จะตั้ง sprite.animation เป็นท่านั้นให้เอง "แต่ไม่เล่น" → เช็คแค่ชื่อไม่พอ ต้องเช็ค is_playing ด้วย
			# (ท่าที่ไม่วนซ้ำแล้วเล่นจบ เช่น Attack/Death ไม่ต้องเริ่มใหม่ ไม่งั้นจะกระตุกวนไปเรื่อย)
			if sprite.animation != real or (not sprite.is_playing() and sprite.sprite_frames.get_animation_loop(real)):
				sprite.play(real)
			return real
	return ""


## อนิเมชันนี้เล่นครบ 1 รอบใช้เวลากี่วินาที
func _anim_length(anim: String) -> float:
	if anim == "" or sprite.sprite_frames == null:
		return 0.0
	if not sprite.sprite_frames.has_animation(anim):
		return 0.0
	var frames := sprite.sprite_frames.get_frame_count(anim)
	var speed := sprite.sprite_frames.get_animation_speed(anim)
	if frames <= 0 or speed <= 0.0:
		return 0.0
	var total := 0.0
	for i in range(frames):
		total += sprite.sprite_frames.get_frame_duration(anim, i)
	return total / speed


# =========================================================
# ★ สกิลมอนสเตอร์ / สกิลบอส ★
#
# ตั้งค่าทุกอย่างใน MonsterData (.tres) ไม่ต้องแก้โค้ด
# ชื่อท่าใน SpriteFrames เอามาจากช่อง Skill Anim
# ไม่มีท่านั้น -> ถอยไปใช้ "Skill" -> ถอยไป "Attack"
# =========================================================
func _try_skill(distance: float, to_player_x: float) -> bool:
	if not data.has_skill():
		return false
	if state == State.ATTACK or _skill_cd > 0.0:
		return false
	if distance > data.skill_range:
		return false
	if randf() > data.skill_chance:
		# พลาดจังหวะนี้ รออีกนิดค่อยสุ่มใหม่ (ไม่ต้องรอเต็มคูลดาวน์)
		_skill_cd = 1.0
		return false
	velocity.x = 0.0
	_face_to(to_player_x)
	_cast_skill()
	return true


func _cast_skill() -> void:
	state = State.ATTACK
	velocity.x = 0.0
	_skill_cd = data.skill_cooldown

	# ท่าสกิล: Skill Anim -> "Skill" -> ท่าโจมตีปกติ
	var played := ""
	if data.skill_anim != &"":
		played = _play(String(data.skill_anim))
	if played == "":
		played = _play("Skill")
	if played == "":
		played = _play("Attack")

	if data.skill_name != "":
		Events.floating_text(global_position + Vector2(0, data.hp_bar_offset_y - 26 - hover_lift()),
			data.skill_name, Color("#ff9a4a"), 22, 0)

	# ★ เอฟเฟกต์สกิล ★ เกิดเป็นโหนดแยกในแมพ เลยใหญ่/ไกลเกินตัวมอนได้
	# ใส่ SpriteFrames ลงช่อง "Skill Effect Frames" ใน MonsterData แล้วมันทำงานเอง
	if data.skill_effect_frames != null:
		SkillEffect.spawn_monster(data, self, facing)

	await get_tree().create_timer(data.skill_windup).timeout
	if state == State.DEAD or not is_instance_valid(self):
		return

	# ★ สกิลขว้างบอลโค้ง (รอบ 36) ★ บอลไปตกที่ตำแหน่งผู้เล่นแล้วระเบิดเอง — ดาเมจคิดตอนระเบิด
	if data.skill_projectile_texture != null:
		var target: Vector2 = foot_position() + Vector2(facing * 300.0, 0)
		if _player != null and is_instance_valid(_player):
			target = _player.foot_position() if _player.has_method("foot_position") else _player.global_position
		MonsterProjectile.fire_lob(data, self, target)
	else:
		_skill_hit()

	await get_tree().create_timer(maxf(0.05, data.skill_duration - data.skill_windup)).timeout
	if state == State.DEAD or not is_instance_valid(self):
		return
	state = State.IDLE
	_attack_timer = maxf(_attack_timer, data.attack_cooldown * 0.5)


## จังหวะที่สกิลระเบิดจริง
func _skill_hit() -> void:
	if _player == null or not is_instance_valid(_player) or PlayerState.is_dead():
		return
	var pf: Vector2 = _player.foot_position() if _player.has_method("foot_position") \
		else _player.global_position
	var diff: Vector2 = pf - foot_position()
	if absf(diff.x) > data.skill_radius_x or absf(diff.y) > data.skill_radius_y:
		Events.floating_text(_player.global_position + Vector2(0, -40), "หลบได้!",
			Color("#cccccc"), 20, 3)
		return

	var result := Combat.monster_hits_player(data, PlayerState.stats)
	var damage := maxi(1, int(round(result.damage * data.skill_damage_mult)))
	if _player.has_method("take_damage"):
		var dir := signi(int(pf.x - global_position.x))
		_player.take_damage(damage, data.skill_knockback, dir)


# =========================================================
# โจมตี
# =========================================================
func _try_attack() -> void:
	if _attack_timer > 0.0 or state == State.ATTACK:
		return
	_attack()


func _attack() -> void:
	state = State.ATTACK
	velocity.x = 0.0
	_play("Attack")

	await get_tree().create_timer(data.attack_windup).timeout
	if state == State.DEAD or not is_instance_valid(self):
		return

	# ★ โจมตีระยะไกล (รอบ 36) ★ ใส่รูปกระสุนไว้ = ยิงบอลแทนตีติดตัว
	if data.projectile_texture != null:
		if _player != null and is_instance_valid(_player):
			_face_to(_player.global_position.x - global_position.x)
		MonsterProjectile.fire_straight(data, self, facing)
	elif _player != null and is_instance_valid(_player) and not PlayerState.is_dead():
		var pf: Vector2 = _player.foot_position() if _player.has_method("foot_position") \
			else _player.global_position
		var dist := foot_position().distance_to(pf)
		if dist <= attack_reach() + 25.0:
			var result := Combat.monster_hits_player(data, PlayerState.stats)
			if result.miss:
				Events.floating_text(_player.global_position + Vector2(0, -40), "MISS", Color("#cccccc"), 20, 3)
			elif _player.has_method("take_damage"):
				var dir := signi(int(_player.global_position.x - global_position.x))
				_player.take_damage(result.damage, data.knockback_force, dir)

	await get_tree().create_timer(data.attack_duration).timeout
	if state == State.DEAD or not is_instance_valid(self):
		return
	state = State.IDLE
	_attack_timer = data.attack_cooldown


# =========================================================
# รับดาเมจจากผู้เล่น
# =========================================================
func take_damage_from_player(skill_mult: float = 1.0, use_matk: bool = false, from_dir: int = 0) -> void:
	if state == State.DEAD:
		return

	var result := Combat.player_hits_monster(PlayerState.stats, data, skill_mult, use_matk)

	if result.miss:
		Events.floating_text(global_position + Vector2(0, data.hp_bar_offset_y - hover_lift()), "MISS", Color("#cccccc"), 20, 3)
		_set_aggro()
		return

	take_damage(int(result.damage), bool(result.crit), from_dir)
	_drain_to_player(int(result.damage))


## ★ รอบ 45 — ดูดเลือด/ดูดมานา ★ ได้คืน = % ของดาเมจที่ทำได้ (ตัวเลขลอยสีเขียว/ฟ้าเล็ก ๆ)
func _drain_to_player(damage: int) -> void:
	if damage <= 0:
		return
	var st := PlayerState.stats
	if st == null:
		return
	if st.hp_drain_percent > 0.0:
		var hp_gain := maxi(1, int(damage * st.hp_drain_percent / 100.0))
		PlayerState.heal_hp(hp_gain, false)
	if st.sp_drain_percent > 0.0:
		var sp_gain := maxi(1, int(damage * st.sp_drain_percent / 100.0))
		PlayerState.restore_sp(sp_gain)


## ทำดาเมจตรง ๆ (ใช้กับกับดัก/สกิลพิเศษ)
func take_damage(amount: int, is_crit: bool = false, from_dir: int = 0) -> void:
	if state == State.DEAD:
		return

	hp = maxi(0, hp - amount)
	_set_aggro()

	# ★ ตัวเลขดาเมจ — ใหญ่และหนา ★ คริติคอลใหญ่กว่าอีก
	var text := str(amount) + ("!" if is_crit else "")
	Events.floating_text(
		global_position + Vector2(randf_range(-6, 6), data.hp_bar_offset_y - hover_lift()),
		text,
		Combat.damage_color(is_crit, false),
		DAMAGE_FONT_CRIT if is_crit else DAMAGE_FONT_SIZE,
		1
	)
	Events.damage_dealt.emit(self, amount, is_crit)

	_update_hp_bar()
	sprite.modulate = Color(1, 0.45, 0.45)
	_hurt_flash = 0.12

	# กระเด็นเล็กน้อย
	if from_dir != 0:
		velocity.x = from_dir * 60.0

	if hp <= 0:
		_die()
	elif state != State.ATTACK:
		_play("Hit")


## ป้าย MVP เด้งเหนือหัวผู้เล่นตอนล้มบอส
func _show_mvp() -> void:
	var title: String = data.boss_title if data.boss_title != "" else "MVP"
	var p := get_tree().get_first_node_in_group("player")
	var at: Vector2 = p.global_position + Vector2(0, -110) if p != null \
		else global_position + Vector2(0, -120)
	Events.floating_text(at, title, Color("#ffd44a"), 52, 6)
	Events.say("%s!  ล้ม %s ได้แล้ว" % [title, data.display_name])
	Events.boss_killed.emit(data.id, data.display_name)


func _set_aggro() -> void:
	_aggro = true
	_aggro_timer = AGGRO_MEMORY
	# ★ รอบ 44 — ล็อกเป้าถาวร (จนกว่าผู้เล่นตาย/มอนตาย) ★ ตัวนิ่ง (STATIONARY) ไม่ไล่อยู่แล้ว
	if data != null and data.ai_type != MonsterData.AIType.STATIONARY:
		_aggro_locked = true


## ล็อกเป้าอยู่ไหม (ไว้ให้เทสต์/ระบบอื่นดู)
func is_aggro_locked() -> bool:
	return _aggro_locked


func is_dead() -> bool:
	return state == State.DEAD


# =========================================================
# ตาย + ดรอปของ
# =========================================================
func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector2.ZERO
	collision.set_deferred("disabled", true)
	sprite.modulate = Color.WHITE
	if _hp_bar != null:
		_hp_bar.hide()

	# --- รางวัล ---
	var job_exp := data.job_exp()
	PlayerState.gain_exp(data.exp_reward, job_exp)
	var zeny := data.roll_zeny()
	if zeny > 0:
		PlayerState.add_zeny(zeny)

	# ★ EXP กับ Job EXP อยู่บรรทัดเดียวกัน และลอยแยกทางกับตัวเลขดาเมจ ★
	Events.floating_text(global_position + Vector2(0, data.hp_bar_offset_y + sprite.position.y),
		"+%d EXP   +%d JOB" % [data.exp_reward, job_exp], Color("#8ad6ff"), 18, 4)
	Events.monster_killed.emit(data.id, data.level)

	# ★ ล้มบอส = ป้าย MVP เหนือหัวผู้เล่น + ตั้งธงเนื้อเรื่อง killed_<id> (รอบ 38) ★
	# ธงนี้ใช้ปลดล็อก LoreObject / เควส เช่น killed_forge_guardian เปิดแบบร่างค้อน
	if data.is_boss:
		_show_mvp()
		PlayerState.set_flag(StringName("killed_" + String(data.id)))

	_spawn_drops()
	died.emit(self, data)

	# ★ ท่าตาย ★
	# ชื่อท่าตั้งเป็น Death / Die / Dead ก็ได้ (พิมพ์เล็ก-ใหญ่ไม่สำคัญ)
	var played := _play("Death")
	if played != "":
		sprite.frame = 0
		sprite.play(played)   # เริ่มใหม่จากเฟรมแรกเสมอ

	# รอให้ท่าตายเล่นจบจริง ๆ ไม่ใช่ตัดทิ้งที่ 0.6 วินาทีเหมือนเดิม
	var wait: float = data.death_time
	if wait <= 0.0:
		wait = _anim_length(played)
		# หยุดกลางเฟรมสุดท้าย เผื่อท่าตายตั้ง loop ไว้ จะได้ไม่วนกลับไปเฟรมแรก
		var n := sprite.sprite_frames.get_frame_count(played) if played != "" else 0
		if wait > 0.0 and n > 1:
			wait *= 1.0 - 0.5 / float(n)
	if wait <= 0.0:
		wait = 0.6
	wait = clampf(wait, 0.2, 4.0)

	# ค้างท่าสุดท้ายไว้แป๊บหนึ่ง (ถ้าท่าตั้ง loop ไว้ จะได้ไม่วนซ้ำ)
	await get_tree().create_timer(wait).timeout
	if not is_instance_valid(self):
		return
	sprite.pause()

	# จาง ๆ หายไป
	if data.death_fade > 0.0:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, data.death_fade)
		await tween.finished
	queue_free()


func _spawn_drops() -> void:
	var drops := data.roll_drops()
	if drops.is_empty():
		return

	var scene: PackedScene = DROPPED_ITEM_SCENE
	if scene == null:
		# ถ้ายังไม่มี scene ให้ใส่เข้ากระเป๋าตรง ๆ กันของหาย
		for inst in drops:
			PlayerState.gain_item(inst)
		return

	var parent := get_parent()
	var i := 0
	for inst in drops:
		var node := scene.instantiate()
		parent.add_child(node)
		node.global_position = global_position + Vector2(randf_range(-30, 30), -20)
		if node.has_method("setup"):
			node.setup(inst)
		i += 1


# =========================================================
# หลอดเลือด
# =========================================================
func _create_hp_bar() -> void:
	_hp_bar = ProgressBar.new()
	_hp_bar.name = "HPBar"
	_hp_bar.max_value = data.max_hp
	_hp_bar.value = hp
	_hp_bar.show_percentage = false
	_hp_bar.size = Vector2(48, 6)
	_hp_bar.position = Vector2(-24, data.hp_bar_offset_y)
	_hp_bar.z_index = 100

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.06, 0.06, 0.9)
	bg.set_corner_radius_all(3)
	_hp_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.85, 0.3)
	fill.set_corner_radius_all(3)
	_hp_bar.add_theme_stylebox_override("fill", fill)

	add_child(_hp_bar)


func _update_hp_bar() -> void:
	if _hp_bar == null:
		return
	_hp_bar.value = hp
	var ratio := float(hp) / maxf(1.0, float(data.max_hp))
	var fill := _hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = Color(0.9, 0.2, 0.2) if ratio < 0.3 else Color(0.2, 0.85, 0.3)


# =========================================================
# ★ วิดีโอเปิดตัวบอส (รอบ 41) ★
# ผู้เล่นเดินเข้าใกล้บอสครั้งแรก (ระยะ Intro Range) = เล่นวิดีโอที่ตั้งไว้ 1 ครั้ง
# จำด้วยธง seen_intro_<id> (เก็บลงเซฟ) — โหลดเซฟ/กลับมาใหม่ไม่เล่นซ้ำ
# =========================================================
var _intro_done := false

func _check_boss_intro() -> void:
	if _intro_done:
		return
	# ★ รอบ 42: ไม่บังคับว่าต้อง is_boss ★ ขอแค่ตั้งช่อง Intro Video ก็ใช้ได้
	# (บาฟโฟเมทไม่ได้ติ๊ก is_boss ไว้ วิดีโอเลยไม่เล่น — เจอตอนตรวจข้อมูลรอบ 42)
	if data == null or data.intro_video == "" or state == State.DEAD:
		_intro_done = true
		return
	var intro_flag := StringName("seen_intro_" + String(data.id))
	if PlayerState.has_flag(intro_flag):
		_intro_done = true
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or PlayerState.is_dead():
		return
	if global_position.distance_to(player.global_position) > data.intro_range:
		return
	_intro_done = true
	PlayerState.set_flag(intro_flag)
	UI.play_video(data.intro_video)
