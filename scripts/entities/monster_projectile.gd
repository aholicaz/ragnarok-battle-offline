## MonsterProjectile — กระสุนของมอนสเตอร์ (รอบ 36)
##
## 2 แบบ:
##   ★ ยิงตรง ★  fire_straight() — บอลพุ่งไปข้างหน้า ชนผู้เล่นแล้วทำดาเมจ (ลูนาติก)
##   ★ ขว้างโค้ง ★ fire_lob()    — บอลลอยเป็นโค้งไปตกที่ตำแหน่งผู้เล่น แล้วระเบิดทำดาเมจรอบ ๆ (คิงโพริง)
##
## ไม่ต้องสร้างเอง — ใส่รูปในช่อง Projectile Texture / Skill Projectile Texture ของ MonsterData แล้ว
## monster_base.gd จะเรียกให้เองตอนโจมตี/ร่ายสกิล
class_name MonsterProjectile
extends Node2D

const DEFAULT_BURST := "res://Sprites/effects/slime_burst.png"
const BURST_FRAMES := 8
const BURST_CELL := 256

enum Mode { STRAIGHT, LOB }

var data: MonsterData
var mode: Mode = Mode.STRAIGHT
var _dir := 1
var _speed := 0.0
var _range := 0.0
var _travelled := 0.0
var _hit_size := Vector2.ZERO
var _spin := 0.0
var _sprite: Sprite2D
var _done := false
## ★ รอบ 69 ★ ตัวคูณดาเมจของนัดนี้ (ใช้ตอนมอนยิงหลายนัดในท่าเดียว)
var damage_mult := 1.0

# ---- แบบโค้ง ----
var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _arc := 0.0
var _flight := 1.0
var _t := 0.0
var _shadow_y := 0.0


# =========================================================
# สร้าง
# =========================================================
## ยิงตรงจากตัวมอน — facing: 1 = ขวา · -1 = ซ้าย
static func fire_straight(d: MonsterData, caster: Node2D, facing: int) -> MonsterProjectile:
	if d == null or d.projectile_texture == null:
		return null
	var p := MonsterProjectile.new()
	p.data = d
	p.mode = Mode.STRAIGHT
	p._dir = 1 if facing > 0 else -1
	p._speed = d.projectile_speed
	p._range = d.projectile_range
	p._hit_size = d.projectile_hit_size
	p._spin = d.projectile_spin
	var foot: Vector2 = caster.foot_position() if caster.has_method("foot_position") else caster.global_position
	p.global_position = foot + Vector2(d.projectile_offset.x * p._dir, d.projectile_offset.y)
	p._build_sprite(d.projectile_texture, d.projectile_height, d.projectile_faces_left)
	_add_to_map(caster, p)
	return p


## ขว้างโค้งไปตกที่ target (จุดเท้าผู้เล่น) แล้วระเบิด
static func fire_lob(d: MonsterData, caster: Node2D, target: Vector2) -> MonsterProjectile:
	if d == null or d.skill_projectile_texture == null:
		return null
	var p := MonsterProjectile.new()
	p.data = d
	p.mode = Mode.LOB
	var foot: Vector2 = caster.foot_position() if caster.has_method("foot_position") else caster.global_position
	p._dir = 1 if target.x >= foot.x else -1
	p._start = foot + Vector2(d.skill_projectile_offset.x * p._dir, d.skill_projectile_offset.y)
	p._end = target
	p._arc = d.skill_projectile_arc
	p._flight = maxf(0.15, d.skill_projectile_time)
	p._spin = d.skill_projectile_spin
	p._shadow_y = target.y
	p.global_position = p._start
	p._build_sprite(d.skill_projectile_texture, d.skill_projectile_height, false)
	_add_to_map(caster, p)
	return p


static func _add_to_map(caster: Node2D, p: MonsterProjectile) -> void:
	var parent: Node = caster.get_tree().current_scene if caster.get_tree() != null else caster.get_parent()
	if parent == null:
		parent = caster.get_parent()
	p.z_index = 70
	parent.add_child(p)


func _build_sprite(tex: Texture2D, height: float, faces_left: bool) -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	var k: float = height / maxf(1.0, float(tex.get_height()))
	_sprite.scale = Vector2(k, k)
	# รูปต้นฉบับหันซ้าย → ยิงไปขวาต้องพลิก
	_sprite.flip_h = faces_left and _dir > 0
	add_child(_sprite)
	if _hit_size == Vector2.ZERO:
		_hit_size = tex.get_size() * k * 0.7
	# โผล่มาแบบเด้งเล็กน้อย
	_sprite.scale = Vector2(k, k) * 0.4
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2(k, k), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# =========================================================
# เคลื่อนที่
# =========================================================
func _process(delta: float) -> void:
	if _done:
		return
	if _spin != 0.0 and _sprite != null:
		_sprite.rotation += _spin * TAU * delta * _dir

	if mode == Mode.STRAIGHT:
		var step: float = _speed * delta
		position.x += _dir * step
		_travelled += step
		if _hits_player():
			_hit_player_direct()
			_pop()
			return
		if _travelled >= _range or _hits_terrain():
			_pop()
			return
	else:
		_t += delta / _flight
		var u: float = minf(1.0, _t)
		# เส้นตรงจากจุดปล่อยไปเป้า + โค้งพาราโบลาขึ้นตรงกลาง
		global_position = _start.lerp(_end, u) + Vector2(0, -_arc * 4.0 * u * (1.0 - u))
		queue_redraw()
		if _t >= 1.0:
			_explode()


## เงาบนพื้นใต้บอล (เฉพาะแบบโค้ง) — เล็กลงตอนบอลอยู่สูง
func _draw() -> void:
	if mode != Mode.LOB or _done:
		return
	var h: float = maxf(0.0, _shadow_y - global_position.y)
	var k: float = clampf(1.0 - h / 500.0, 0.35, 1.0)
	var r := Vector2(38.0 * k, 12.0 * k)
	draw_set_transform(Vector2(0, h), 0.0, r)
	draw_circle(Vector2.ZERO, 1.0, Color(0, 0, 0, 0.35 * k))


# =========================================================
# ชน
# =========================================================
func _player_rect() -> Rect2:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or PlayerState.is_dead():
		return Rect2()
	if p.has_method("body_rect"):
		return p.body_rect()
	var f: Vector2 = p.foot_position() if p.has_method("foot_position") else p.global_position
	var h: float = float(p.auto_fit_height) if "auto_fit_height" in p and p.auto_fit_height > 0.0 else 200.0
	return Rect2(f.x - h * 0.16, f.y - h, h * 0.32, h)


func _hits_player() -> bool:
	var pr := _player_rect()
	if pr.size == Vector2.ZERO:
		return false
	var mine := Rect2(global_position - _hit_size * 0.5, _hit_size)
	return mine.intersects(pr, true)


func _hits_terrain() -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(_dir * _hit_size.x * 0.5, 0))
	q.collision_mask = 1
	return not space.intersect_ray(q).is_empty()


## ยิงตรง: ดาเมจเท่าโจมตีปกติ
func _hit_player_direct() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or data == null:
		return
	var result := Combat.monster_hits_player(data, PlayerState.stats)
	if result.miss:
		Events.floating_text(p.global_position + Vector2(0, -40), "MISS", Color("#cccccc"), 20, 3)
		return
	if p.has_method("take_damage"):
		p.take_damage(maxi(1, int(round(result.damage * damage_mult))), data.knockback_force, _dir)


## ขว้างโค้ง: ระเบิดที่จุดตก ทำดาเมจถ้าผู้เล่นอยู่ในรัศมีสกิล
func _explode() -> void:
	if _done:
		return
	_done = true
	queue_redraw()
	_spawn_burst(_end)

	var p := get_tree().get_first_node_in_group("player")
	if p != null and not PlayerState.is_dead() and data != null:
		var pf: Vector2 = p.foot_position() if p.has_method("foot_position") else p.global_position
		var diff: Vector2 = pf - _end
		if absf(diff.x) <= data.skill_radius_x and absf(diff.y) <= data.skill_radius_y:
			var result := Combat.monster_hits_player(data, PlayerState.stats)
			var dmg := maxi(1, int(round(result.damage * data.skill_damage_mult)))
			if p.has_method("take_damage"):
				p.take_damage(dmg, data.skill_knockback, signi(int(signf(diff.x))) if diff.x != 0.0 else _dir)
		else:
			Events.floating_text(p.global_position + Vector2(0, -40), "หลบได้!", Color("#cccccc"), 20, 3)

	# บอลหายวับพร้อมระเบิด
	if _sprite != null:
		_sprite.visible = false
	await get_tree().create_timer(0.05).timeout
	queue_free()


## เอฟเฟกต์ระเบิด — ใช้ SpriteFrames ที่ตั้งไว้ หรือชีท slime_burst.png ที่ทำให้
func _spawn_burst(at: Vector2) -> void:
	var frames: SpriteFrames = data.skill_explosion_frames if data != null else null
	var anim: StringName = data.skill_explosion_anim if data != null else &"burst"
	if frames == null:
		frames = _default_burst_frames()
		anim = &"burst"
	if frames == null or not frames.has_animation(anim):
		return
	var fx := AnimatedSprite2D.new()
	fx.sprite_frames = frames
	fx.z_index = 80
	var tex := frames.get_frame_texture(anim, 0)
	var k: float = 1.0
	if tex != null and tex.get_height() > 0:
		k = data.skill_explosion_height / float(tex.get_height())
	fx.scale = Vector2(k, k)
	# วางให้ขอบล่างของเอฟเฟกต์อยู่ที่พื้นพอดี
	fx.global_position = at + Vector2(0, -data.skill_explosion_height * 0.42)
	get_parent().add_child(fx)
	fx.play(anim)
	fx.animation_finished.connect(fx.queue_free)


static var _burst_cache: SpriteFrames

static func _default_burst_frames() -> SpriteFrames:
	if _burst_cache != null:
		return _burst_cache
	if not ResourceLoader.exists(DEFAULT_BURST):
		return null
	var tex: Texture2D = load(DEFAULT_BURST)
	var f := SpriteFrames.new()
	f.add_animation(&"burst")
	f.set_animation_loop(&"burst", false)
	f.set_animation_speed(&"burst", 18.0)
	for i in range(BURST_FRAMES):
		var a := AtlasTexture.new()
		a.atlas = tex
		a.region = Rect2(i * BURST_CELL, 0, BURST_CELL, BURST_CELL)
		f.add_frame(&"burst", a)
	_burst_cache = f
	return f


## กระสุนตรงหายไปแบบแตกเป็นประกาย
func _pop() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	if _sprite == null:
		queue_free()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "scale", _sprite.scale * 1.6, 0.12)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.12)
	tw.chain().tween_callback(queue_free)
