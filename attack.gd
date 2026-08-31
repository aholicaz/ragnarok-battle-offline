extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var is_attacking = false


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY

	# Attack
	if Input.is_action_just_pressed("attack") and not is_attacking:
		is_attacking = true
		velocity.x = 0
		$AnimatedSprite2D.play("Attack")

	# ถ้ากำลังโจมตี ไม่ให้เปลี่ยน Animation เป็น Run/Idle
	if is_attacking:
		velocity.x = 0
		move_and_slide()
		return

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


func _on_animated_sprite_2d_animation_finished() -> void:
	if $AnimatedSprite2D.animation == "Attack":
		is_attacking = false
