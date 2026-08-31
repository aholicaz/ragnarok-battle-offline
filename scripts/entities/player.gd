## Player — ตัวละครผู้เล่น
##
## โครงสร้าง Scene ที่ต้องมี:
##   Player (CharacterBody2D)  <- ใส่สคริปต์นี้
##   ├── AnimatedSprite2D      (อนิเมชัน: Idle, Run, Attack, Hit, Death, Jump)
##   └── CollisionShape2D
##
## ค่าพลังทั้งหมดดึงจาก PlayerState ไม่ต้องแก้ในไฟล์นี้
extends CharacterBody2D

const JUMP_VELOCITY := -420.0
const KNOCKBACK_DECAY := 900.0

## สไปรท์ต้นฉบับหันหน้าไปทางซ้ายหรือเปล่า (ตามที่ทำไว้เดิม = จริง)
@export var sprite_faces_left: bool = true
## ★ ระยะโจมตีปกติ ★ วัดจาก "กลางตัวเรา" ไปถึง "ขอบตัวมอน" (ไม่ใช่กลางตัวมอน)
## มอนตัวใหญ่อย่างบอสเลยตีโดนตั้งแต่ขอบตัว ไม่ต้องเดินไปประชิดกลางตัว
@export var attack_range_x: float = 150.0
## ดาบเอื้อมขึ้นไปเหนือปลายเท้าได้สูงเท่าไหร่ (ครอบทั้งตัวขึ้นไปบนหัว)
@export var attack_range_y: float = 200.0
## ★ เอื้อมไปข้างหลังได้เท่าไหร่ ★ สำหรับตัวที่ยืนทับ/เราเหยียบอยู่ ให้ฟันโดนด้วย
@export var attack_back_reach: float = 55.0
## ★ ฟันต่ำกว่าปลายเท้าลงไปได้เท่าไหร่ ★ สำหรับตัวที่เราเหยียบหัวอยู่
@export var attack_reach_down: float = 40.0
## จังหวะที่ดาบฟันโดน (วินาทีหลังเริ่มอนิเมชัน)
@export var attack_windup: float = 0.15
## ระยะที่เก็บไอเทมได้ (แนวนอน) — วัดจาก "ปลายเท้า" ไม่ใช่จุดกำเนิด
@export var pickup_range: float = 90.0
## ระยะที่เก็บไอเทมได้ (แนวตั้ง) เผื่อของตกอยู่ต่างระดับเล็กน้อย
@export var pickup_range_y: float = 90.0

# =========================================================
# ปรับขนาดตัวละครอัตโนมัติ
# ใช้ตอนไฟล์ภาพแต่ละท่าขนาดไม่เท่ากัน (เช่น Idle 300x300 แต่ Run 50x90)
# ระบบจะย่อ/ขยายให้ตัวละคร "สูงเท่ากันบนจอ" เสมอ และจัดเท้าให้อยู่ระดับพื้น
# =========================================================
@export_group("ขนาดตัวละคร")
## ★ อยากให้ตัวละครสูงกี่พิกเซลบนจอ ★ (0 = ปิดระบบนี้ ใช้ค่า Scale ที่ตั้งใน Scene แทน)
@export var auto_fit_height: float = 240.0:
	set(value):
		auto_fit_height = value
		_fit_cache.clear()
		_collision_synced = false
## จัดเท้าให้อยู่ระดับล่างของกล่องชนเสมอ
@export var auto_fit_align_feet: bool = true
## ปรับขนาดกล่องชนตาม Auto Fit Height ให้อัตโนมัติ (จะได้แก้ตัวเลขเดียวจบ)
@export var auto_fit_collision: bool = true
## ความกว้างของกล่องชน เทียบกับความสูง (0.16 = ผอม, 0.25 = อ้วน)
@export_range(0.08, 0.45) var collision_width_ratio: float = 0.17

# =========================================================
# ★ ท่าตัวละคร — แยกตามอาวุธที่ถือ และแยกตามสกิล ★
#
# ★★ ทุกท่าใช้กฎเดียวกัน ★★  ท่าไหนก็ได้ ไม่ใช่แค่ท่าโจมตี
#   ท่า + "_" + ชื่ออาวุธ   ->  ถ้ามีจะใช้อันนี้ก่อนเสมอ
#
#   ถือ falchion:  Idle_falchion · Run_falchion · Jump_falchion
#                  Attack_falchion · Attack_falchion_bash · Hit_falchion · Death_falchion
#   ไม่มีท่าไหน ก็ถอยไปใช้ท่าธรรมดา (Idle / Run / Attack ...) ให้เอง
#
# "ชื่ออาวุธ" มาจากช่อง Attack Animation ของไอเทม ("Attack_Falchion" -> "Falchion")
# ถ้าไม่ได้ตั้งไว้ จะใช้ id ของไอเทมแทน (falchion -> "falchion")
# ตัวพิมพ์เล็ก-ใหญ่ไม่สำคัญ (Attack_Falchion = attack_falchion)
#
# ทำอาวุธใหม่ = วาดเฉพาะท่าที่อยากให้เปลี่ยน ไม่ต้องวาดครบทุกท่า
# ไม่ต้องแก้โค้ดเลย
# =========================================================
@export_group("ท่าโจมตี")
## ชื่อท่าตอนมือเปล่า
@export var unarmed_attack_anim: StringName = &"Attack"
## รูปแบบชื่อท่าตามชนิดอาวุธ ({type} = weapon_type ของอาวุธ)
@export var weapon_attack_anim_format: String = "Attack_{type}"
## ★ รูปแบบชื่อท่าสกิลที่แยกตามอาวุธ ★
## {attack} = ชื่อท่าโจมตีของอาวุธที่ถืออยู่ · {skill} = id ของสกิล
## เช่น ถือดาบมือใหม่ (Attack_Blade) ใช้สกิล bash -> "Attack_Blade_bash"
@export var skill_weapon_anim_format: String = "{attack}_{skill}"
## รูปแบบชื่อท่าสกิลกลาง (ใช้ตอนอาวุธชิ้นนั้นยังไม่มีท่าเฉพาะ)
@export var skill_anim_format: String = "Attack_{skill}"

# =========================================================
# ★ ปุ่มเมาส์ ★
#   คลิกซ้าย = โจมตีปกติ (เหมือนกดปุ่มโจมตี)
#   คลิกขวา  = ใช้สกิลช่องลัดที่ตั้งไว้ (ปกติคือช่อง 1)
# คลิกโดนหน้าต่าง/ปุ่มบนจอ จะไม่ทำให้ตัวละครโจมตี (UI กินคลิกไปก่อนแล้ว)
# =========================================================
@export_group("ปุ่มเมาส์")
## คลิกซ้าย = โจมตีปกติ
@export var mouse_attack: bool = true
## คลิกขวา = ใช้สกิลช่องลัดนี้ (1-4) · ใส่ 0 = ปิด
@export_range(0, 4) var mouse_skill_slot: int = 1
## คลิกแล้วให้ตัวละครหันไปทางที่คลิกก่อนฟัน
@export var mouse_turns_facing: bool = true

var _fit_cache: Dictionary = {}
var _collision_synced := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing: int = 1              # 1 = ขวา, -1 = ซ้าย
var is_attacking := false
var attack_cooldown := 0.0
var knockback := Vector2.ZERO
var _hurt_flash := 0.0
var _dead := false

# ★ สถานะตอนพุ่ง (สกิล ACTIVE_DASH เช่น Slash) ★
var _dash_time := 0.0          # เหลือเวลาพุ่งอีกกี่วินาที
var _dash_speed := 0.0
var _dash_range_x := 110.0
var _dash_range_y := 90.0
var _dash_mult := 1.0
var _dash_use_matk := false
var _dash_max_targets := 0
var _dash_stop_on_wall := true
var _dash_hits: Array = []     # มอนที่โดนไปแล้วในการพุ่งครั้งนี้

# คลิกเมาส์ที่รับมาแล้วรอให้ _handle_input() เอาไปใช้ในเฟรมถัดไป
var _click_attack := false
var _click_skill := false
var _click_pos := Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	Events.player_died.connect(_on_died)
	Events.level_up.connect(_on_level_up)
	_dead = PlayerState.is_dead()


# =========================================================
# PHYSICS
# =========================================================
func _physics_process(delta: float) -> void:
	if _dead:
		velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_DECAY * delta)
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		if _hurt_flash <= 0.0:
			sprite.modulate = Color.WHITE

	# แรงกระเด็น
	if knockback.length() > 1.0:
		knockback = knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	# แรงโน้มถ่วง
	if not is_on_floor():
		velocity += get_gravity() * delta

	_handle_input()

	# ★ กำลังพุ่งอยู่ ★ เดินหน้าต่อแล้วฟันทุกตัวที่ขวางทาง
	if _dash_time > 0.0:
		_dash_step(delta)
		return

	if is_attacking:
		velocity.x = knockback.x
		move_and_slide()
		return

	# กระโดด — W / Space / ลูกศรขึ้น
	if (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_accept")) \
			and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# เดิน — A / D (หรือลูกศรซ้าย-ขวา)
	var speed := PlayerState.stats.move_speed
	var direction := Input.get_axis("move_left", "move_right")
	if direction == 0.0:
		direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		velocity.x = direction * speed + knockback.x
		facing = 1 if direction > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, knockback.x, speed)

	_update_facing()
	_update_animation()
	move_and_slide()


func _process(_delta: float) -> void:
	_apply_auto_fit()


# =========================================================
# ★ คลิกเมาส์ ★
# ใช้ _unhandled_input เพราะถ้าคลิกโดนหน้าต่าง/ปุ่มบนจอ
# ตัว UI จะกินคลิกนั้นไปก่อน คลิกจะไม่ไหลมาถึงตรงนี้ = ไม่เผลอฟันลม
# =========================================================
func _unhandled_input(event: InputEvent) -> void:
	if _dead or get_tree().paused:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.is_echo():
		return
	# คลิกทับหน้าต่าง/แผงบนจอ = ไม่นับเป็นการโจมตี
	if UI != null and UI.is_point_over_ui(mb.position):
		return

	if mouse_attack and mb.button_index == MOUSE_BUTTON_LEFT:
		_click_attack = true
	elif mouse_skill_slot > 0 and mb.button_index == MOUSE_BUTTON_RIGHT:
		_click_skill = true
	else:
		return

	# แปลงจุดที่คลิกบนจอ -> พิกัดในโลก (เผื่อกล้องเลื่อนอยู่)
	_click_pos = get_viewport().get_canvas_transform().affine_inverse() * mb.position
	get_viewport().set_input_as_handled()


## หันหน้าไปทางที่คลิก (ถ้าเปิดใช้)
func _face_click() -> void:
	if not mouse_turns_facing:
		return
	var dx := _click_pos.x - global_position.x
	if absf(dx) < 8.0:
		return
	facing = 1 if dx > 0.0 else -1
	_update_facing()


func _handle_input() -> void:
	# ---------- รับคลิกเมาส์ที่ค้างไว้ ----------
	var click_attack := _click_attack
	var click_skill := _click_skill
	_click_attack = false
	_click_skill = false

	# โจมตีปกติ — ปุ่มโจมตี หรือ คลิกซ้าย
	if (Input.is_action_just_pressed("attack") or click_attack) \
			and not is_attacking and attack_cooldown <= 0.0:
		if click_attack:
			_face_click()
		start_attack()
		return

	# คลิกขวา = สกิลช่องลัดที่ตั้งไว้
	if click_skill and mouse_skill_slot > 0:
		var msid := PlayerState.skills.hotkey_at(mouse_skill_slot - 1)
		if msid != &"":
			_face_click()
			use_skill(msid)
		return

	# สกิลปุ่มลัด 1-4
	for i in range(SkillBook.HOTKEY_COUNT):
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			var sid := PlayerState.skills.hotkey_at(i)
			if sid != &"":
				use_skill(sid)
			return

	# เก็บไอเทม — กด F (หรือ Z)
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("pickup"):
		pickup_nearby()

	# ยาด่วน — Q = ช่องยาเลือด · R = ช่องยามานา (เลือกยาเองได้ในกระเป๋า)
	if Input.is_action_just_pressed("quick_potion"):
		PlayerState.use_item_hotkey(0)
	elif InputMap.has_action("quick_sp_potion") \
			and Input.is_action_just_pressed("quick_sp_potion"):
		PlayerState.use_item_hotkey(1)


func _update_facing() -> void:
	if sprite_faces_left:
		sprite.flip_h = facing > 0
	else:
		sprite.flip_h = facing < 0


func _update_animation() -> void:
	if is_attacking or sprite.sprite_frames == null:
		return
	if not is_on_floor() and _has_anim("Jump"):
		_play("Jump")
	elif absf(velocity.x) > 10.0:
		_play("Run")
	else:
		_play("Idle")


## ★ ชื่ออนิเมชันที่ระบบยอมรับ ★
## ตั้งชื่อแบบไหนก็ได้ในลิสต์ และ "ตัวพิมพ์เล็ก-ใหญ่ไม่สำคัญ" (Die = die = DIE)
## ถ้าไม่มีชื่อไหนเลย จะไล่ลงไปใช้ตัวสำรองท้ายลิสต์แทน (กันตัวละครค้าง/หาย)
const ANIM_FALLBACK := {
	"Idle": ["Idle", "Stand"],
	"Run": ["Run", "Walk", "Move", "Jump", "Idle"],
	"Jump": ["Jump", "Hop", "Run", "Idle"],
	"Attack": ["Attack", "Atk", "Attact", "Idle"],
	"Hit": ["Hit", "Hurt", "Damage", "Idle"],
	"Death": ["Death", "Die", "Dead", "Dying", "Hit", "Idle"],
}

var _anim_lookup: Dictionary = {}   # ชื่อตัวพิมพ์เล็ก -> ชื่อจริงใน SpriteFrames


## ★ คำต่อท้ายของอาวุธที่ถืออยู่ ★ เช่น "Blade", "falchion"  ("" = มือเปล่า)
## เอามาจากช่อง Attack Animation ของไอเทม ("Attack_Falchion" -> "Falchion")
## ถ้าไม่ได้ตั้งไว้ ใช้ id ของไอเทมแทน (falchion -> "falchion")
func weapon_suffix() -> String:
	var weapon := PlayerState.equipment.weapon()
	if weapon == null:
		return ""
	var d := weapon.data()
	if d == null:
		return ""
	if d.attack_animation != &"":
		var t := String(d.attack_animation)
		return t.substr(7) if t.begins_with("Attack_") else t
	return String(d.id)


## ลำดับท่าสำรอง
## 1) ท่าเฉพาะอาวุธที่ถืออยู่  เช่น Idle_falchion / Run_falchion / Attack_falchion
## 2) ท่าปกติของท่านั้น        เช่น Idle / Run / Attack
## 3) ตัวสำรองอื่น ๆ
func _fallback_chain(anim: String) -> Array:
	var chain: Array = []

	# ท่าเฉพาะอาวุธ — ทำให้เปลี่ยนอาวุธแล้วภาพตัวละครเปลี่ยนตามได้ทุกท่า
	var suffix := weapon_suffix()
	if suffix != "" and not anim.to_lower().contains("_" + suffix.to_lower()):
		chain.append("%s_%s" % [anim, suffix])

	if ANIM_FALLBACK.has(anim):
		chain.append_array(ANIM_FALLBACK[anim])
		return chain

	chain.append(anim)
	if anim.begins_with("Attack"):
		chain.append(String(unarmed_attack_anim))
		chain.append("Attack")
	chain.append("Idle")
	return chain


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
	for candidate in _fallback_chain(anim):
		var real := _real_anim(String(candidate))
		if real != "" and sprite.sprite_frames.get_frame_count(real) > 0:
			if sprite.animation != real:
				sprite.play(real)
			return real
	return ""


# =========================================================
# ปรับขนาด/ตำแหน่งภาพให้เท่ากันทุกท่า
# =========================================================
func _apply_auto_fit() -> void:
	if auto_fit_height <= 0.0 or sprite.sprite_frames == null:
		return

	if auto_fit_collision and not _collision_synced:
		_collision_synced = true
		_sync_collision()
	var info: Dictionary = _fit_info(sprite.animation)
	if info.is_empty():
		return

	var k: float = info.scale
	sprite.scale = Vector2(k, k)

	var list: Array = info.frames
	if list.is_empty():
		return
	var fd: Dictionary = list[clampi(sprite.frame, 0, list.size() - 1)]

	# แนวนอน: จัดให้ตัวละครอยู่กึ่งกลาง (สลับข้างตอนหันกลับ)
	sprite.offset.x = fd.dx if sprite.flip_h else -fd.dx

	# แนวตั้ง: ให้ปลายเท้าแตะระดับพื้นของกล่องชน
	if auto_fit_align_feet:
		sprite.offset.y = (_feet_y() - sprite.position.y) / k - fd.bottom


## ปรับกล่องชนให้พอดีกับขนาดตัวละคร
func _sync_collision() -> void:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null:
		return
	var cap := CapsuleShape2D.new()
	cap.height = auto_fit_height
	cap.radius = maxf(4.0, auto_fit_height * collision_width_ratio * 0.5)
	col.shape = cap


## ตำแหน่งเท้าในโลก — ใช้เทียบระนาบกับมอนสเตอร์
func foot_position() -> Vector2:
	return global_position + Vector2(0.0, _feet_y())


## ระดับพื้นของกล่องชน (เท้าควรอยู่ตรงนี้)
func _feet_y() -> float:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col == null or col.shape == null:
		return 0.0
	var shape := col.shape
	if shape is CapsuleShape2D:
		return col.position.y + (shape as CapsuleShape2D).height * 0.5
	if shape is RectangleShape2D:
		return col.position.y + (shape as RectangleShape2D).size.y * 0.5
	if shape is CircleShape2D:
		return col.position.y + (shape as CircleShape2D).radius
	return col.position.y


## วัดขนาดตัวละครจริงในแต่ละท่า (ไม่นับพื้นที่โปร่งใส) แล้วจำไว้
func _fit_info(anim: StringName) -> Dictionary:
	if _fit_cache.has(anim):
		return _fit_cache[anim]

	var frames := sprite.sprite_frames
	if frames == null or not frames.has_animation(anim):
		return {}

	var list: Array = []
	var tallest := 0.0

	for i in range(frames.get_frame_count(anim)):
		var tex := frames.get_frame_texture(anim, i)
		if tex == null:
			continue
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var used := Rect2i(0, 0, int(tw), int(th))
		var img := tex.get_image()
		if img != null:
			var r := img.get_used_rect()
			if r.size.x > 0 and r.size.y > 0:
				used = r
		tallest = maxf(tallest, float(used.size.y))
		list.append({
			# ระยะจากกึ่งกลางผ้าใบถึงปลายเท้า
			"bottom": float(used.position.y + used.size.y) - th * 0.5,
			# ตัวละครเยื้องจากกึ่งกลางผ้าใบไปทางขวาเท่าไหร่
			"dx": float(used.position.x) + float(used.size.x) * 0.5 - tw * 0.5,
		})

	var info := {
		"scale": auto_fit_height / maxf(1.0, tallest),
		"frames": list,
		"tallest": tallest,
	}
	_fit_cache[anim] = info
	return info


## เรียกเมื่อเปลี่ยนชุดภาพตัวละคร
func clear_fit_cache() -> void:
	_fit_cache.clear()
	_anim_lookup.clear()


# =========================================================
# ท่าโจมตี
# =========================================================
## ชื่อท่าโจมตีที่ควรเล่นตอนนี้ (ดูจากอาวุธที่ถืออยู่)
func attack_animation() -> String:
	var weapon := PlayerState.equipment.weapon()
	if weapon != null:
		var d := weapon.data()
		if d != null:
			# 1) ท่าเฉพาะที่ตั้งไว้ในไอเทมชิ้นนั้น
			if d.attack_animation != &"" and _has_anim(String(d.attack_animation)):
				return String(d.attack_animation)
			# 2) ท่าตามชื่อไอเทม เช่น falchion -> "Attack_falchion" (ไม่ต้องตั้งค่าอะไรเลย)
			var by_id := "Attack_%s" % String(d.id)
			if _has_anim(by_id):
				return by_id
			# 3) ท่าตามชนิดอาวุธ เช่น Attack_sword
			if d.weapon_type != &"":
				var by_type := weapon_attack_anim_format.replace("{type}", String(d.weapon_type))
				if _has_anim(by_type):
					return by_type
	# 3) ท่ามือเปล่า
	return String(unarmed_attack_anim)


## ★ ชื่อท่าที่ควรเล่นตอนใช้สกิลนี้ ★ (ดูจากอาวุธที่ถือ + สกิลที่ใช้)
## ไล่หาตามลำดับ: ท่าที่ตั้งไว้ในสกิล → ท่าอาวุธ+สกิล → ท่าสกิลกลาง → ท่าโจมตีของอาวุธ
func skill_animation(skill_id: StringName) -> String:
	var s := GameData.get_skill(skill_id)

	# 1) ท่าเฉพาะที่ตั้งไว้ในไฟล์สกิลเอง (ช่อง Animation)
	if s != null and s.animation != &"" and _has_anim(String(s.animation)):
		return String(s.animation)

	var base := attack_animation()
	var sid := String(skill_id)

	# 2) ท่าเฉพาะ "อาวุธนี้ + สกิลนี้"  เช่น Attack_Blade_bash
	var by_weapon := skill_weapon_anim_format.replace("{attack}", base).replace("{skill}", sid)
	if _has_anim(by_weapon):
		return by_weapon

	# 3) ท่าสกิลกลาง ใช้ได้กับทุกอาวุธ  เช่น Attack_bash
	var by_skill := skill_anim_format.replace("{skill}", sid)
	if _has_anim(by_skill):
		return by_skill

	# 4) ไม่มีท่าสกิลเลย ก็ใช้ท่าโจมตีปกติของอาวุธที่ถืออยู่
	return base


func _has_anim(name: String) -> bool:
	if sprite.sprite_frames == null:
		return false
	var real := _real_anim(name)
	return real != "" and sprite.sprite_frames.get_frame_count(real) > 0


# =========================================================
# โจมตีปกติ
# =========================================================
func start_attack() -> void:
	is_attacking = true
	attack_cooldown = PlayerState.stats.attack_interval()
	velocity.x = 0.0
	_play(attack_animation())

	await get_tree().create_timer(attack_windup).timeout
	if not is_instance_valid(self) or _dead:
		return

	_deal_damage(attack_range_x, attack_range_y, 1.0, false, 0)

	# กลับสู่ท่าปกติหลังจบอนิเมชัน (เผื่อ signal ไม่ถูกต่อไว้)
	var rest: float = maxf(0.05, attack_cooldown - attack_windup)
	await get_tree().create_timer(rest).timeout
	if is_instance_valid(self):
		is_attacking = false


# =========================================================
# ใช้สกิล
# =========================================================
func use_skill(skill_id: StringName) -> void:
	if is_attacking or _dead:
		return
	var s := GameData.get_skill(skill_id)
	if s == null:
		return
	if not PlayerState.commit_skill_use(skill_id):
		return

	var lv := PlayerState.skills.level_of(skill_id)

	match s.type:
		SkillData.SkillType.HEAL:
			var amount := s.heal_amount(lv, PlayerState.stats.total_int)
			PlayerState.heal_hp(amount)
			Events.floating_text(global_position, s.display_name, Color("#7ef0ff"), 20, 0)

		SkillData.SkillType.BUFF:
			PlayerState.apply_buff(skill_id)
			Events.floating_text(global_position, s.display_name, Color("#ffd54a"), 20, 0)

		SkillData.SkillType.ACTIVE_DASH:
			# ★ สกิลพุ่ง ★ ออกตัวไปข้างหน้าแล้วฟันทุกตัวที่ขวางทาง
			is_attacking = true
			attack_cooldown = maxf(PlayerState.stats.attack_interval(), s.cast_windup + 0.25)
			velocity.x = 0.0
			_play(skill_animation(skill_id))
			Events.floating_text(global_position, s.display_name, Color("#ffd54a"), 18, 0)
			_spawn_skill_effect(s)

			await get_tree().create_timer(s.cast_windup).timeout
			if not is_instance_valid(self) or _dead:
				return
			_start_dash(s, lv)

			# รอจนพุ่งจบจริง ๆ (เผื่อชนกำแพงแล้วหยุดก่อนกำหนด)
			while is_instance_valid(self) and _dash_time > 0.0:
				await get_tree().physics_frame
			await get_tree().create_timer(0.15).timeout
			if is_instance_valid(self):
				is_attacking = false

		_:
			is_attacking = true
			attack_cooldown = maxf(PlayerState.stats.attack_interval(), s.cast_windup + 0.15)
			velocity.x = 0.0
			# ★ ท่าสกิลแยกตามอาวุธที่ถือ ★ เช่น ถือดาบมือใหม่ใช้ bash -> Attack_Blade_bash
			_play(skill_animation(skill_id))
			Events.floating_text(global_position, s.display_name, Color("#ffd54a"), 18, 0)
			_spawn_skill_effect(s)

			for i in range(maxi(1, s.hit_count)):
				await get_tree().create_timer(s.cast_windup if i == 0 else 0.12).timeout
				if not is_instance_valid(self) or _dead:
					return
				var all_dir := s.type == SkillData.SkillType.ACTIVE_AOE
				_deal_damage(s.range_x, s.range_y, s.damage_mult(lv), s.use_matk, s.max_targets, all_dir)

			await get_tree().create_timer(0.2).timeout
			if is_instance_valid(self):
				is_attacking = false


## ★ เอฟเฟกต์สกิล ★ เกิดเป็นโหนดแยกในแมพ เลยใหญ่/ไกลเกินตัวละครได้
## ใส่ SpriteFrames ลงช่อง "Effect Frames" ของ SkillData แล้วมันทำงานเอง
func _spawn_skill_effect(s: SkillData) -> void:
	if s == null or not s.has_effect():
		return
	SkillEffect.spawn(s, self, facing)


# =========================================================
# ★ สกิลพุ่ง (Slash) ★
#
# ตัวละครพุ่งไปข้างหน้าด้วยความเร็วสูง มอนทุกตัวที่อยู่ในแนวพุ่งโดนดาเมจ
# ตัวเดิมโดนได้ครั้งเดียวต่อการพุ่ง 1 ครั้ง (ตั้งปิดได้ที่ Dash Hit Once)
# =========================================================
func _start_dash(s: SkillData, lv: int) -> void:
	var distance: float = s.dash_range(lv)
	_dash_speed = maxf(50.0, s.dash_speed)
	_dash_time = distance / _dash_speed
	_dash_range_x = s.range_x
	_dash_range_y = s.dash_range_y
	_dash_mult = s.damage_mult(lv)
	_dash_use_matk = s.use_matk
	_dash_max_targets = s.max_targets
	_dash_stop_on_wall = s.dash_stop_on_wall
	_dash_hits.clear()
	if not s.dash_hit_once:
		_dash_hits = []


func _dash_step(delta: float) -> void:
	_dash_time -= delta
	velocity.x = facing * _dash_speed
	velocity.y = minf(velocity.y, 0.0)   # ไม่ให้ร่วงระหว่างพุ่ง
	move_and_slide()
	_dash_damage()

	if _dash_stop_on_wall and is_on_wall():
		_dash_time = 0.0
	if _dash_time <= 0.0:
		velocity.x = 0.0


## ฟันทุกตัวที่อยู่ในแนวพุ่งตอนนี้ (ตัวที่โดนแล้วข้าม)
func _dash_damage() -> void:
	var my_foot := foot_position()
	# ระหว่างพุ่งฟันได้รอบตัว (ชนขอบก็นับ) เหมือนกรอบฟันปกติ
	var blade := attack_rect(_dash_range_x, _dash_range_y, true)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage_from_player"):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		if enemy in _dash_hits:
			continue
		if not blade.intersects(enemy_rect(enemy), true):
			continue

		var enemy_foot: Vector2 = enemy.foot_position() if enemy.has_method("foot_position") \
			else enemy.global_position
		var offset: Vector2 = enemy_foot - my_foot
		enemy.take_damage_from_player(_dash_mult, _dash_use_matk,
			signi(int(offset.x)) if offset.x != 0.0 else facing)
		_dash_hits.append(enemy)

		if _dash_max_targets > 0 and _dash_hits.size() >= _dash_max_targets:
			_dash_time = 0.0
			return


func is_dashing() -> bool:
	return _dash_time > 0.0


# =========================================================
# ★★ กรอบการฟัน ★★
# เดิมวัด "จุดกึ่งกลางถึงจุดกึ่งกลาง" เลยมีปัญหา 3 อย่าง
#   1) มอนตัวใหญ่ (บอส) ต้องเดินเข้าไปประชิดกลางตัวถึงจะโดน
#   2) ตัวที่ยืนทับเรา/เราเหยียบอยู่ ไม่โดนเลย (อยู่ข้างหลังนิดเดียวก็ถูกตัดทิ้ง)
#   3) มอนที่กระโดดอยู่ (โพริง) ปลายเท้าลอย เลยหลุดเงื่อนไขแนวตั้ง
# ตอนนี้เปลี่ยนเป็น "กรอบฟัน" ชนกับ "กรอบตัวมอน" — ขอบชนขอบก็นับว่าโดน
# =========================================================

## กรอบดาบในพิกัดโลก
func attack_rect(range_x: float, range_y: float, all_directions: bool = false) -> Rect2:
	var f := foot_position()
	var forward: float = maxf(range_x, 10.0)
	var back: float = forward if all_directions else attack_back_reach
	var left: float = f.x - (back if facing > 0 else forward)
	var up: float = maxf(range_y, body_height() * 0.9)
	return Rect2(left, f.y - up, forward + back, up + attack_reach_down)


## ความสูงตัวผู้เล่นบนจอ (ใช้กะกรอบฟันแนวตั้ง)
func body_height() -> float:
	return auto_fit_height if auto_fit_height > 0.0 else 180.0


## กรอบตัวศัตรู — มอนบอกขนาดตัวเองได้ ถ้าไม่มีก็เดาให้
static func enemy_rect(enemy: Node) -> Rect2:
	if enemy.has_method("body_rect"):
		return enemy.body_rect()
	var f: Vector2 = enemy.foot_position() if enemy.has_method("foot_position") \
		else (enemy as Node2D).global_position
	return Rect2(f.x - 20.0, f.y - 60.0, 40.0, 60.0)


func _deal_damage(range_x: float, range_y: float, mult: float, use_matk: bool,
		max_targets: int, all_directions: bool = false) -> void:

	var enemies := get_tree().get_nodes_in_group("enemy")
	var hit_count := 0
	var blade := attack_rect(range_x, range_y, all_directions)
	var my_foot := foot_position()

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage_from_player"):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		if not blade.intersects(enemy_rect(enemy), true):
			continue

		var enemy_foot: Vector2 = enemy.foot_position() if enemy.has_method("foot_position") \
			else enemy.global_position
		var dx: float = enemy_foot.x - my_foot.x
		enemy.take_damage_from_player(mult, use_matk, signi(int(dx)) if dx != 0.0 else facing)
		hit_count += 1

		if max_targets > 0 and hit_count >= max_targets:
			return


# =========================================================
# รับดาเมจ
# =========================================================
func take_damage(amount: int, knockback_force: float = 0.0, from_direction: int = 0) -> void:
	if _dead:
		return

	PlayerState.take_damage(amount)
	# ★ ดาเมจที่เราโดน — ตัวใหญ่ สีแดง ★
	Events.floating_text(global_position + Vector2(0, -40), str(amount), Color("#ff4040"), 32, 2)

	sprite.modulate = Color(1, 0.5, 0.5)
	_hurt_flash = 0.15

	if knockback_force > 0.0:
		var dir := from_direction if from_direction != 0 else -facing
		knockback = Vector2(dir * knockback_force, 0)
		if is_on_floor():
			velocity.y = -140.0

	if PlayerState.stats.hp > 0 and not is_attacking:
		_play("Hit")


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	is_attacking = false
	velocity = Vector2.ZERO
	sprite.modulate = Color.WHITE

	# ท่าตายของผู้เล่น ตั้งชื่อ Death / Die / Dead ก็ได้ (พิมพ์เล็ก-ใหญ่ไม่สำคัญ)
	var played := _play("Death")
	if played != "":
		sprite.frame = 0
		sprite.play(played)
	await get_tree().create_timer(1.2).timeout
	Game.respawn_in_town()


func _on_level_up(new_level: int) -> void:
	Events.floating_text(global_position + Vector2(0, -60), "LEVEL UP!", Color("#ffe14a"), 32, 0)
	sprite.modulate = Color(1.4, 1.4, 1.0)
	_hurt_flash = 0.5


# =========================================================
# เก็บไอเทมที่ตกอยู่
# =========================================================
## เก็บของที่อยู่ใกล้ที่สุด
## ★ วัดจาก "ปลายเท้า" ★ เพราะจุดกำเนิดของผู้เล่นลอยอยู่กลางตัว (สูงจากพื้นครึ่งหนึ่งของกล่องชน)
## ถ้าวัดจากจุดกำเนิด ของที่วางอยู่แทบเท้าจะดูห่างเป็นร้อยพิกเซล จนเก็บไม่ได้
func pickup_nearby() -> bool:
	var item := nearest_pickup()
	if item == null:
		return false
	if item.has_method("collect"):
		item.collect()
	return true


## ของชิ้นที่ใกล้ที่สุดที่กด F แล้วเก็บได้ตอนนี้ (null = ไม่มี)
## ประตูวาปใช้ฟังก์ชันนี้เช็คด้วย จะได้ไม่แย่งปุ่ม F กัน
func nearest_pickup() -> Node:
	var my_foot := foot_position()
	var items := get_tree().get_nodes_in_group("dropped_item")
	items.sort_custom(func(a, b):
		return my_foot.distance_squared_to(a.global_position) \
			< my_foot.distance_squared_to(b.global_position))

	for item in items:
		if not is_instance_valid(item):
			continue
		var offset: Vector2 = item.global_position - my_foot
		if absf(offset.x) <= pickup_range and absf(offset.y) <= pickup_range_y:
			return item
	return null


# =========================================================
# ต่อ signal animation_finished ของ AnimatedSprite2D มาที่นี่ (ถ้าต้องการ)
# =========================================================
func _on_animated_sprite_2d_animation_finished() -> void:
	if String(sprite.animation).begins_with("Attack"):
		is_attacking = false
		_update_animation()
	elif sprite.animation == "Hit" and not _dead:
		_update_animation()
