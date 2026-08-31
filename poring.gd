extends CharacterBody2D

signal poring_died(position_to_respawn)

# =========================
# MOVEMENT
# =========================

const SPEED = 100.0
const JUMP_FORCE = -300.0

# =========================
# AI
# =========================

const DETECT_DISTANCE = 250.0
const ATTACK_DISTANCE = 70.0

# =========================
# ATTACK
# =========================

const ATTACK_DAMAGE = 10
const ATTACK_COOLDOWN = 1.5

# =========================
# HP
# =========================

const MAX_HP = 50

var hp = MAX_HP

# =========================
# STATE
# =========================

var player = null
var is_attacking = false
var can_attack = true
var is_dead = false

# =========================
# HP BAR
# =========================

var hp_bar: ProgressBar


func _ready() -> void:

	create_hp_bar()


# =====================================================
# PROCESS
# =====================================================

func _physics_process(delta: float) -> void:

	if is_dead:
		return

	# =========================
	# GRAVITY
	# =========================

	if not is_on_floor():
		velocity += get_gravity() * delta

	# =========================
	# FIND PLAYER
	# =========================

	player = get_tree().get_first_node_in_group("player")

	if player == null:
		velocity.x = 0
		move_and_slide()
		return

	# =========================
	# DISTANCE
	# =========================

	var distance = global_position.distance_to(player.global_position)

	# =========================
	# FACE PLAYER
	# =========================

	face_player()

	# =========================
	# ATTACK
	# =========================

	if distance <= ATTACK_DISTANCE:

		velocity.x = 0

		if can_attack and not is_attacking:
			attack()

	# =========================
	# CHASE PLAYER
	# =========================

	elif distance <= DETECT_DISTANCE:

		if not is_attacking:

			var direction = sign(
				player.global_position.x - global_position.x
			)

			velocity.x = direction * SPEED

			# กระโดดเมื่ออยู่พื้น
			if is_on_floor():
				velocity.y = JUMP_FORCE
				$AnimatedSprite2D.play("Jump")

	# =========================
	# IDLE
	# =========================

	else:

		velocity.x = move_toward(
			velocity.x,
			0,
			SPEED
		)

		if is_on_floor() and not is_attacking:
			$AnimatedSprite2D.play("Idle")

	move_and_slide()


# =====================================================
# หันหน้าเข้าหา PLAYER
# =====================================================

func face_player() -> void:

	if player == null:
		return

	if player.global_position.x < global_position.x:

		# Player อยู่ซ้าย
		$AnimatedSprite2D.flip_h = false

	else:

		# Player อยู่ขวา
		$AnimatedSprite2D.flip_h = true


# =====================================================
# ATTACK
# =====================================================

func attack() -> void:

	if is_dead:
		return

	is_attacking = true
	can_attack = false

	velocity.x = 0

	# หันหน้าหาผู้เล่นก่อนโจมตี
	face_player()

	$AnimatedSprite2D.play("Attack")

	# จังหวะโดนโจมตี
	await get_tree().create_timer(0.3).timeout

	if is_dead:
		return

	if player != null:

		var distance = global_position.distance_to(
			player.global_position
		)

		if distance <= ATTACK_DISTANCE + 20:

			if player.has_method("take_damage"):

				player.take_damage(ATTACK_DAMAGE)

	# จบ Animation
	await get_tree().create_timer(0.4).timeout

	if is_dead:
		return

	is_attacking = false

	# Cooldown
	await get_tree().create_timer(
		ATTACK_COOLDOWN
	).timeout

	if is_dead:
		return

	can_attack = true


# =====================================================
# TAKE DAMAGE
# =====================================================

func take_damage(damage: int) -> void:

	if is_dead:
		return

	hp -= damage

	hp = max(hp, 0)

	print("Poring HP = ", hp)

	update_hp_bar()

	show_damage_popup(damage)

	if hp <= 0:

		die()

	else:

		$AnimatedSprite2D.play("Hit")


# =====================================================
# HP BAR
# =====================================================

func create_hp_bar() -> void:

	hp_bar = ProgressBar.new()

	hp_bar.name = "HPBar"

	hp_bar.max_value = MAX_HP
	hp_bar.value = hp

	hp_bar.show_percentage = false

	# ขนาด
	hp_bar.size = Vector2(50, 7)

	# ตำแหน่งเหนือหัว
	hp_bar.position = Vector2(-25, -48)

	# StyleBox Background
	var bg = StyleBoxFlat.new()

	bg.bg_color = Color(0.08, 0.08, 0.08, 0.9)

	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3

	hp_bar.add_theme_stylebox_override(
		"background",
		bg
	)

	# StyleBox Fill สีเขียว
	var fill = StyleBoxFlat.new()

	fill.bg_color = Color(0.15, 0.85, 0.25, 1)

	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3

	hp_bar.add_theme_stylebox_override(
		"fill",
		fill
	)

	add_child(hp_bar)


# =====================================================
# UPDATE HP BAR
# =====================================================

func update_hp_bar() -> void:

	if hp_bar == null:
		return

	hp_bar.value = hp


# =====================================================
# DIE
# =====================================================

func die() -> void:

	if is_dead:
		return

	is_dead = true

	is_attacking = false
	can_attack = false

	velocity = Vector2.ZERO

	var respawn_position = global_position

	print("Poring ตาย")
	print("Respawn position = ", respawn_position)

	# แจ้ง WorldNode2D
	poring_died.emit(respawn_position)

	# Animation ตาย
	$AnimatedSprite2D.play("Death")

	await get_tree().create_timer(0.5).timeout

	queue_free()


# =====================================================
# DAMAGE POPUP
# =====================================================

func show_damage_popup(damage: int) -> void:

	var label = Label.new()

	label.text = "-" + str(damage)

	label.position = Vector2(-20, -50)

	label.add_theme_font_size_override(
		"font_size",
		20
	)

	# สีแดงสำหรับ Poring
	label.add_theme_color_override(
		"font_color",
		Color(1, 0.25, 0.25)
	)

	label.add_theme_color_override(
		"font_shadow_color",
		Color(0, 0, 0, 1)
	)

	label.add_theme_constant_override(
		"shadow_offset_x",
		2
	)

	label.add_theme_constant_override(
		"shadow_offset_y",
		2
	)

	add_child(label)

	var tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		label,
		"position",
		Vector2(-20, -90),
		0.5
	)

	tween.tween_property(
		label,
		"modulate:a",
		0.0,
		0.5
	)

	tween.set_parallel(false)

	tween.tween_callback(
		label.queue_free
	)
