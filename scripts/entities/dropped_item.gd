## DroppedItem — ไอเทมที่ตกอยู่บนพื้น
##
## โครงสร้าง Scene (res://scenes/items/dropped_item.tscn):
##   DroppedItem (Area2D)  <- ใส่สคริปต์นี้
##   ├── Sprite2D           (ไอคอนไอเทม จะถูกเปลี่ยนอัตโนมัติ)
##   ├── CollisionShape2D   (CircleShape2D รัศมี ~16)
##   └── Label              (ชื่อไอเทม)
extends Area2D

## ★ เก็บอัตโนมัติเมื่อเดินผ่านไหม ★
## false (ค่าเริ่มต้น) = ต้องเดินเข้าไปใกล้แล้ว "กด F" ถึงจะเก็บ
@export var auto_pickup: bool = false
@export var pickup_delay: float = 0.4
@export var lifetime: float = 60.0
## ระยะที่ขึ้นป้าย "กด F" / ระยะเก็บอัตโนมัติ — วัดจาก "ปลายเท้า" ของผู้เล่น
@export var auto_pickup_range_x: float = 70.0
@export var auto_pickup_range_y: float = 80.0

var instance: ItemInstance
var _age := 0.0
var _can_pickup := false
var _collected := false
var _velocity := Vector2.ZERO
var _sprite: Sprite2D
var _base_sprite_y := 0.0
var _ground_y := INF
var _landed := false
var _hint: Label


func _ready() -> void:
	add_to_group("dropped_item")
	monitoring = true
	_velocity = Vector2(randf_range(-60, 60), -180)
	_build_hint()
	await get_tree().create_timer(pickup_delay).timeout
	_can_pickup = true


## ป้าย "กด F เก็บ" ที่ลอยเหนือไอเทม จะโผล่เฉพาะตอนผู้เล่นเดินเข้ามาใกล้
func _build_hint() -> void:
	_hint = Label.new()
	_hint.name = "PickupHint"
	_hint.text = "กด F เก็บ"
	_hint.visible = false
	_hint.z_index = 20
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(-60, -78)
	_hint.custom_minimum_size = Vector2(120, 0)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color("#ffe14a"))
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 5)
	add_child(_hint)


func _update_hint() -> void:
	if _hint == null:
		return
	if _collected or not _can_pickup:
		_hint.visible = false
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		_hint.visible = false
		return
	var foot: Vector2 = player.foot_position() if player.has_method("foot_position") \
		else player.global_position
	var offset: Vector2 = global_position - foot
	_hint.visible = absf(offset.x) < auto_pickup_range_x and absf(offset.y) < auto_pickup_range_y
	if _hint.visible:
		_hint.position.y = -78 + sin(_age * 5.0) * 3.0


## ยิงเรย์จากจุดปัจจุบันไปยังจุดถัดไป ถ้าเจอพื้นก็หยุดตรงนั้น
## (ต้องเช็คทุกเฟรมระหว่างตก เพราะตอนสร้าง ไอเทมยังไม่ถูกย้ายไปตำแหน่งจริง)
func _ground_between(from: Vector2, to: Vector2) -> Vector2:
	var world := get_world_2d()
	if world == null:
		return Vector2.INF
	var query := PhysicsRayQueryParameters2D.create(from, to + Vector2(0.0, 4.0))
	query.collision_mask = 1
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector2.INF
	return hit.position


func setup(inst: ItemInstance) -> void:
	instance = inst
	_refresh_visual()


func _refresh_visual() -> void:
	if instance == null:
		return
	var d := instance.data()
	if d == null:
		return

	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr != null and d.icon != null:
		spr.texture = d.icon
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		# ย่อให้ขนาดพอดีกับพื้น ไม่ว่าไฟล์ภาพจะใหญ่แค่ไหน
		if d.drop_display_size > 0.0:
			var tex_size := d.icon.get_size()
			var longest := maxf(1.0, maxf(tex_size.x, tex_size.y))
			var k := d.drop_display_size / longest
			spr.scale = Vector2(k, k)
			# ให้ "ก้นภาพ" อยู่ที่จุดกำเนิดของไอเทม (ซึ่งจะแตะพื้นพอดี)
			spr.position.y = -tex_size.y * k * 0.5
		_sprite = spr
		_base_sprite_y = spr.position.y

	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = instance.display_name()
		if instance.count > 1:
			label.text += " x%d" % instance.count
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 13)


func _physics_process(delta: float) -> void:
	# เด้งขึ้นแล้วตกลง "พื้น" แล้วหยุดนิ่ง
	if not _landed:
		_velocity.y += 900.0 * delta
		_velocity.x = move_toward(_velocity.x, 0.0, 120.0 * delta)
		var next := global_position + _velocity * delta

		if _velocity.y > 0.0:
			var ground := _ground_between(global_position, next)
			if ground != Vector2.INF:
				next = ground
				_velocity = Vector2.ZERO
				_landed = true
				_ground_y = ground.y

		global_position = next

		# กันร่วงหายลงเหวถ้าแมพตรงนั้นไม่มีพื้น
		if not _landed and _age > 2.5:
			_velocity = Vector2.ZERO
			_landed = true

	_age += delta

	# ลอยขึ้นลงเบา ๆ ให้สังเกตเห็นง่าย
	if _sprite != null and _landed:
		_sprite.position.y = _base_sprite_y + sin(_age * 3.0) * 3.0

	if lifetime > 0.0 and _age > lifetime:
		queue_free()
		return
	if lifetime > 0.0 and _age > lifetime - 5.0:
		modulate.a = 0.4 + 0.6 * absf(sin(_age * 6.0))

	_update_hint()

	if auto_pickup and _can_pickup and not _collected:
		var player := get_tree().get_first_node_in_group("player")
		if player != null:
			# ★ เทียบกับ "ปลายเท้า" ผู้เล่น ★
			# จุดกำเนิดของผู้เล่นอยู่กลางลำตัว (สูงจากพื้น ~ครึ่งหนึ่งของกล่องชน)
			# ถ้าวัดจากจุดกำเนิด ของที่ตกอยู่แทบเท้าจะดูห่างเป็นร้อยพิกเซล จนเก็บไม่ได้
			var foot: Vector2 = player.foot_position() if player.has_method("foot_position") \
				else player.global_position
			var offset: Vector2 = global_position - foot
			if absf(offset.x) < auto_pickup_range_x and absf(offset.y) < auto_pickup_range_y:
				collect()


## เก็บไอเทมเข้ากระเป๋า
func collect() -> void:
	if _collected or instance == null or not _can_pickup:
		return

	var leftover := PlayerState.gain_item(instance)
	if leftover >= instance.count:
		Events.say("กระเป๋าเต็ม")
		return

	_collected = true
	var got := instance.count - leftover
	Events.floating_text(
		global_position,
		"%s x%d" % [instance.display_name(), got],
		Color("#9be7ff"),
		18,
		5
	)

	if leftover > 0:
		instance.count = leftover
		_collected = false
		_refresh_visual()
		Events.say("กระเป๋าเต็ม เก็บได้ไม่หมด")
		return

	queue_free()
