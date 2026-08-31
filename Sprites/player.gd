extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# =========================
# PLAYER HP
# =========================
const MAX_HP = 100
var hp = MAX_HP

# =========================
# PLAYER ATTACK
# =========================
const ATTACK_RANGE_X = 110.0
const ATTACK_RANGE_Y = 70.0
const ATTACK_DAMAGE = 20

var is_attacking = false
var attack_has_hit = false

var hp_bar: ProgressBar


func _ready() -> void:

	# Group Player
	if not is_in_group("player"):
		add_to_group("player")

	create_hp_bar()


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(delta: float) -> void:

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta


	# Attack
	if Input.is_action_just_pressed("Attack") and not is_attacking:
		start_attack()


	# ระหว่างโจมตี
	if is_attacking:
		velocity.x = 0
		move_and_slide()
		return


	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY


	# Movement
	var direction := Input.get_axis("ui_left", "ui_right")

	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)


	# Animation
	if velocity.x < 0:

		$AnimatedSprite2D.play("Run")
		$AnimatedSprite2D.flip_h = false

	elif velocity.x > 0:

		$AnimatedSprite2D.play("Run")
		$AnimatedSprite2D.flip_h = true

	else:

		$AnimatedSprite2D.play("Idle")


	move_and_slide()


# =========================================================
# PLAYER ATTACK
# =========================================================

func start_attack() -> void:

	is_attacking = true
	attack_has_hit = false

	velocity.x = 0

	$AnimatedSprite2D.play("Attack")

	# จังหวะฟันโดน
	await get_tree().create_timer(0.15).timeout

	if is_attacking and not attack_has_hit:
		attack_enemy()


# =========================================================
# ตรวจศัตรู
# =========================================================

func attack_enemy() -> void:

	attack_has_hit = true

	var enemies = get_tree().get_nodes_in_group("enemy")

	for enemy in enemies:

		if not is_instance_valid(enemy):
			continue

		var dx = abs(enemy.global_position.x - global_position.x)
		var dy = abs(enemy.global_position.y - global_position.y)

		# ไม่ใช้ distance_to แล้ว
		# ตรวจแยกแกน X/Y ทำให้ตีง่ายขึ้น
		if dx <= ATTACK_RANGE_X and dy <= ATTACK_RANGE_Y:

			print("⚔ PLAYER HIT: ", enemy.name)

			if enemy.has_method("take_damage"):
				enemy.take_damage(ATTACK_DAMAGE)


# =========================================================
# PLAYER รับดาเมจ
# =========================================================

func take_damage(damage: int) -> void:

	if hp <= 0:
		return

	hp -= damage

	hp = max(hp, 0)

	print("💥 PLAYER DAMAGE: ", damage, " HP:", hp)

	update_hp_bar()

	show_damage_popup(damage)

	if $AnimatedSprite2D.sprite_frames.has_animation("Hit"):
		$AnimatedSprite2D.play("Hit")

	if hp <= 0:
		die()


# =========================================================
# PLAYER ตาย
# =========================================================

func die() -> void:

	is_attacking = false

	velocity = Vector2.ZERO

	if $AnimatedSprite2D.sprite_frames.has_animation("Death"):

		$AnimatedSprite2D.play("Death")

		await get_tree().create_timer(0.8).timeout

	queue_free()


# =========================================================
# PLAYER HP BAR
# =========================================================

func create_hp_bar() -> void:

	hp_bar = ProgressBar.new()

	hp_bar.name = "HPBar"

	hp_bar.max_value = MAX_HP
	hp_bar.value = hp

	hp_bar.show_percentage = false

	# ขนาด
	hp_bar.size = Vector2(70, 8)

	# ตำแหน่งเหนือหัว
	hp_bar.position = Vector2(-35, -95)

	hp_bar.z_index = 100

	# =========================
	# BACKGROUND
	# =========================

	var background = StyleBoxFlat.new()

	background.bg_color = Color("#202020")

	background.border_width_left = 2
	background.border_width_right = 2
	background.border_width_top = 2
	background.border_width_bottom = 2

	background.border_color = Color("#111111")

	background.corner_radius_top_left = 3
	background.corner_radius_top_right = 3
	background.corner_radius_bottom_left = 3
	background.corner_radius_bottom_right = 3

	hp_bar.add_theme_stylebox_override(
		"background",
		background
	)


	# =========================
	# GREEN HP
	# =========================

	var fill = StyleBoxFlat.new()

	fill.bg_color = Color("#35d04f")

	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3

	hp_bar.add_theme_stylebox_override(
		"fill",
		fill
	)

	add_child(hp_bar)


func update_hp_bar() -> void:

	if is_instance_valid(hp_bar):

		hp_bar.value = hp


# =========================================================
# PLAYER DAMAGE POPUP
# =========================================================

func show_damage_popup(damage: int) -> void:

	var label = Label.new()

	label.text = "-" + str(damage)

	label.position = Vector2(-30, -70)

	label.z_index = 200

	# Player = ใหญ่
	label.add_theme_font_size_override(
		"font_size",
		28
	)

	# Player = แดง
	label.add_theme_color_override(
		"font_color",
		Color("#ff3030")
	)

	# ขอบดำ
	label.add_theme_color_override(
		"font_outline_color",
		Color("#000000")
	)

	label.add_theme_constant_override(
		"outline_size",
		5
	)

	add_child(label)

	var tween = create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		label,
		"position",
		Vector2(-30, -115),
		0.5
	).set_trans(Tween.TRANS_BACK)

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


# =========================================================
# ATTACK ANIMATION FINISHED
# =========================================================

func _on_animated_sprite_2d_animation_finished() -> void:

	if $AnimatedSprite2D.animation == "Attack":

		is_attacking = false
		attack_has_hit = false

		$AnimatedSprite2D.play("Idle")
