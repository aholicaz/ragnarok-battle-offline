## SkillEffect — ภาพเอฟเฟกต์ตอนใช้สกิล
##
## ★ ทำไมต้องแยกเป็นโหนดต่างหาก ★
## ถ้าวาดเอฟเฟกต์ลงไปในสไปรท์ตัวละคร (player_frames) เอฟเฟกต์จะโตได้แค่เท่ากรอบภาพตัวละคร
## และขยับออกไปไกลกว่านั้นไม่ได้เลย
##
## ตัวนี้เป็นโหนดใหม่ที่ไปเกิด "ในโลก" (ลูกของแมพ ไม่ใช่ลูกของตัวละคร)
## เลยใหญ่แค่ไหน ไกลแค่ไหน พุ่งไปทางไหนก็ได้ ไม่ถูกกรอบตัวละครตัดทิ้ง
##
## วิธีใช้: ไม่ต้องสร้างโหนดเอง —
##   ผู้เล่น  : ใส่ SpriteFrames ลงช่อง "Effect Frames" ใน SkillData
##   มอน/บอส : ใส่ลงช่อง "Skill Effect Frames" ใน MonsterData
## แล้วระบบเรียกให้อัตโนมัติตอนร่ายสกิล
class_name SkillEffect
extends Node2D

var _sprite: AnimatedSprite2D
var _life := 0.0
var _speed := 0.0
var _dir := 1
var _follow: Node2D = null
var _follow_offset := Vector2.ZERO

# ★ ให้เอฟเฟกต์ทำดาเมจเอง (รอบ 29) ★
var _damage := false
var _mult := 1.0
var _use_matk := false
var _hit_size := Vector2.ZERO
var _max_targets := 0
var _hit_once := true
var _pierce := true
var _hits: Array = []
## ★ ตีหลายครั้งต่อตัว (รอบ 32) ★
var _hit_count := 1              # ตีกี่ครั้งต่อมอน 1 ตัว
var _hit_interval := 0.2         # เว้นช่วงระหว่างครั้ง
var _stick := true               # ชนครบโควตาแล้วหยุดวิ่ง
var _hit_n: Dictionary = {}      # มอน -> ตีไปแล้วกี่ครั้ง
var _next_hit: Dictionary = {}   # มอน -> อีกกี่วิถึงตีได้อีก
var _ending := false
var _delay := 0.0


## สร้างเอฟเฟกต์จากสกิลของผู้เล่น
## damage_mult = ตัวคูณดาเมจที่เลเวลสกิลนี้ (ใช้ตอนเปิดช่อง Effect Damage)
static func spawn(skill: SkillData, caster: Node2D, facing: int,
		damage_mult: float = 1.0) -> SkillEffect:
	if skill == null or skill.effect_frames == null:
		return null
	return spawn_config({
		"frames": skill.effect_frames,
		"anim": skill.effect_anim,
		"offset": skill.effect_offset,
		"height": skill.effect_height,
		"scale": skill.effect_scale,
		"speed": skill.effect_speed,
		"follow": skill.effect_follow,
		"life": skill.effect_life,
		"delay": skill.effect_delay,
		"z": skill.effect_z,
		"name": String(skill.id),
		# ★ ดาเมจที่ตัวเอฟเฟกต์ทำเอง ★
		"damage": skill.effect_damage,
		"mult": damage_mult,
		"use_matk": skill.use_matk,
		"hit_size": skill.effect_hit_size,
		"max_targets": skill.effect_max_targets,
		"hit_once": skill.effect_hit_once,
		"pierce": skill.effect_pierce,
		"hits": skill.effect_hit_count if skill.effect_hit_count > 0 else skill.hit_count,
		"hit_interval": skill.effect_hit_interval,
		"stick": skill.effect_stick_on_hit,
	}, caster, facing)


## สร้างเอฟเฟกต์จากสกิลของมอนสเตอร์/บอส
static func spawn_monster(data: MonsterData, caster: Node2D, facing: int) -> SkillEffect:
	if data == null or data.skill_effect_frames == null:
		return null
	return spawn_config({
		"frames": data.skill_effect_frames,
		"anim": data.skill_effect_anim,
		"offset": data.skill_effect_offset,
		"height": data.skill_effect_height,
		"scale": data.skill_effect_scale,
		"speed": data.skill_effect_speed,
		"follow": data.skill_effect_follow,
		"life": data.skill_effect_life,
		"delay": data.skill_effect_delay,
		"z": data.skill_effect_z,
		"name": String(data.id),
	}, caster, facing)


## ตัวกลางที่ทำงานจริง — cfg มีคีย์: frames anim offset height scale speed follow life delay z name
## caster = ตัวที่ร่าย · facing = 1 ขวา / -1 ซ้าย
static func spawn_config(cfg: Dictionary, caster: Node2D, facing: int) -> SkillEffect:
	var frames: SpriteFrames = cfg.get("frames", null)
	if frames == null or caster == null:
		return null
	var tree := caster.get_tree()
	if tree == null:
		return null

	# วางไว้ในแมพ (หรือฉากปัจจุบัน) ไม่ใช่ใต้ตัวละคร
	var parent: Node = tree.get_first_node_in_group("map")
	if parent == null:
		parent = tree.current_scene
	if parent == null:
		return null

	var fx := SkillEffect.new()
	fx.name = "SkillEffect_%s" % String(cfg.get("name", "fx"))
	fx._setup(cfg, caster, facing)

	# ★ ตั้งตำแหน่งก่อน add_child เสมอ ★ ไม่งั้นจะเห็นเอฟเฟกต์แวบที่จุด (0,0) 1 เฟรม
	var base_offset: Vector2 = cfg.get("offset", Vector2.ZERO)
	var offset := Vector2(base_offset.x * signf(facing), base_offset.y)
	fx.position = caster.global_position + offset - parent.global_position
	parent.add_child(fx)
	return fx


func _setup(cfg: Dictionary, caster: Node2D, facing: int) -> void:
	var frames: SpriteFrames = cfg.get("frames", null)
	var base_offset: Vector2 = cfg.get("offset", Vector2.ZERO)
	z_index = int(cfg.get("z", 60))
	_dir = 1 if facing >= 0 else -1
	_speed = float(cfg.get("speed", 0.0))
	_life = float(cfg.get("life", 0.0))

	# ★ ตั้งค่าการทำดาเมจของตัวเอฟเฟกต์เอง ★
	_damage = bool(cfg.get("damage", false))
	_mult = float(cfg.get("mult", 1.0))
	_use_matk = bool(cfg.get("use_matk", false))
	_hit_size = cfg.get("hit_size", Vector2.ZERO)
	_max_targets = int(cfg.get("max_targets", 0))
	_hit_once = bool(cfg.get("hit_once", true))
	_hit_count = maxi(1, int(cfg.get("hits", 1)))
	_hit_interval = maxf(0.02, float(cfg.get("hit_interval", 0.2)))
	_stick = bool(cfg.get("stick", true))
	_pierce = bool(cfg.get("pierce", true))

	if bool(cfg.get("follow", false)):
		_follow = caster
		_follow_offset = Vector2(base_offset.x * signf(facing), base_offset.y)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.flip_h = _dir < 0
	_sprite.flip_v = bool(cfg.get("flip_v", false))   # รอบ 44: ฟันสวนขึ้น
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)

	# ---------- เลือกท่า ----------
	var anim := String(cfg.get("anim", ""))
	if anim == "" or not frames.has_animation(anim):
		var names := Array(frames.get_animation_names())
		# ข้าม "default" ที่ Godot แถมมาให้เสมอ ถ้ามีท่าอื่นให้เลือก
		anim = ""
		for n in names:
			if String(n) != "default":
				anim = String(n)
				break
		if anim == "" and not names.is_empty():
			anim = String(names[0])
	if anim == "":
		queue_free()
		return

	_sprite.animation = StringName(anim)
	_sprite.frame = 0
	# ★ เริ่มเล่นตอน "โผล่" เท่านั้น ★ (รอบ 32)
	# ถ้าตั้ง Effect Delay ไว้ ห้ามเริ่มเล่นตรงนี้ ไม่งั้นภาพเดินไปแล้วตอนยังซ่อนอยู่
	# พอโผล่มาก็เหลือแต่เฟรมท้าย ๆ (Bash เห็นแค่จังหวะเดียว — บั๊กที่ผู้ใช้เจอ)
	if float(cfg.get("delay", 0.0)) <= 0.0:
		_sprite.play(StringName(anim))

	# ---------- ขนาด ----------
	var k := float(cfg.get("scale", 1.0))
	var want_height := float(cfg.get("height", 0.0))
	if want_height > 0.0:
		var tex := frames.get_frame_texture(StringName(anim), 0)
		if tex != null and tex.get_height() > 0:
			k = want_height / float(tex.get_height())
	_sprite.scale = Vector2(k, k)

	# ---------- อายุ ----------
	if _life <= 0.0:
		_life = _anim_length(frames, StringName(anim))
	if _life <= 0.0:
		_life = 0.5

	# ★★ หน่วงก่อนโผล่ ★★
	# ห้ามสร้าง SceneTree timer ตรงนี้ — _setup() ถูกเรียก "ก่อน add_child"
	# ตอนนั้น get_tree() ยังเป็น null ตัวจับเวลาเลยไม่เกิด เอฟเฟกต์ซ่อนค้างตลอดไป
	# (บั๊กนี้ไม่โผล่จนกว่าจะมีสกิลที่ตั้ง Effect Delay จริง ๆ — เจอตอนทำ Bash รอบ 29)
	_delay = maxf(0.0, float(cfg.get("delay", 0.0)))
	if _delay > 0.0:
		visible = false


func _ready() -> void:
	if _delay > 0.0:
		await get_tree().create_timer(_delay).timeout
		if is_instance_valid(self):
			visible = true
			_sprite.frame = 0
			_sprite.play()          # เริ่มเล่นพร้อมกับที่โผล่ ภาพเลยครบทุกเฟรม


func _anim_length(frames: SpriteFrames, anim: StringName) -> float:
	if frames == null or not frames.has_animation(anim):
		return 0.0
	var speed: float = maxf(0.01, frames.get_animation_speed(anim))
	var total := 0.0
	for i in range(frames.get_frame_count(anim)):
		total += frames.get_frame_duration(anim, i)
	return total / speed


func _process(delta: float) -> void:
	# ★ ยังไม่ถึงเวลาโผล่ (Effect Delay) ★ ยังไม่ต้องวิ่ง ไม่ต้องทำดาเมจ
	if not visible:
		return

	if _follow != null and is_instance_valid(_follow):
		global_position = _follow.global_position + _follow_offset
	elif _speed != 0.0:
		position.x += _dir * _speed * delta

	# ★★ ดาเมจจากตัวเอฟเฟกต์ ★★ มอนตัวไหนโดนภาพนี้ ตัวนั้นกินดาเมจ
	if _damage and visible:
		_tick_hit_timers(delta)
		_damage_step()

	_life -= delta
	if _life <= 0.0:
		_expire()


## จางหายแทนที่จะหายวับ
func _expire() -> void:
	if _ending:
		return
	_ending = true
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.tween_callback(queue_free)


# =========================================================
# ★★ กรอบชนของเอฟเฟกต์ ★★
# ไม่ได้ตั้ง Effect Hit Size ไว้ = ใช้ขนาดภาพจริงของเฟรมที่กำลังโชว์อยู่
# (ย่อ/ขยายตาม Effect Scale / Effect Height ให้แล้ว)
# =========================================================
func hit_rect() -> Rect2:
	var size := _hit_size
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(80, 80)
		if _sprite != null and _sprite.sprite_frames != null:
			var frames := _sprite.sprite_frames
			var anim := _sprite.animation
			if frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
				var idx: int = clampi(_sprite.frame, 0, frames.get_frame_count(anim) - 1)
				var tex := frames.get_frame_texture(anim, idx)
				if tex != null:
					size = Vector2(tex.get_width(), tex.get_height()) * _sprite.scale
	return Rect2(global_position - size * 0.5, size)


## กรอบตัวมอน — มอนบอกขนาดตัวเองได้ ถ้าไม่มีก็เดาให้ (เหมือนใน player.gd)
static func _enemy_rect(enemy: Node) -> Rect2:
	if enemy.has_method("body_rect"):
		return enemy.body_rect()
	var f: Vector2 = enemy.foot_position() if enemy.has_method("foot_position") \
		else (enemy as Node2D).global_position
	return Rect2(f.x - 20.0, f.y - 60.0, 40.0, 60.0)


func _damage_step() -> void:
	var tree := get_tree()
	if tree == null or _ending:
		return
	var box := hit_rect()

	for enemy in tree.get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage_from_player"):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var done: int = int(_hit_n.get(enemy, 0))
		# ★ ตีครบจำนวนครั้งของตัวนี้แล้ว ★ (hit_once ปิด = ตีซ้ำได้เรื่อย ๆ ตามช่วงเวลา)
		if _hit_once and done >= _hit_count:
			continue
		# ยังไม่ถึงเวลาตีครั้งถัดไป
		if float(_next_hit.get(enemy, 0.0)) > 0.0:
			continue
		# ★ ตัวที่โดนไปแล้ว (คอมโบต่อเนื่อง) ให้กรอบกว้างขึ้น ★
		# ครั้งแรกมักเด้งถอย (knockback) ออกจากกรอบ ถ้าเช็คเป๊ะจะโดนแค่ครั้งเดียว
		var test_box := box if done == 0 else box.grow_individual(box.size.x * 0.5, box.size.y * 0.3, box.size.x * 0.5, box.size.y * 0.3)
		if not test_box.intersects(_enemy_rect(enemy), true):
			continue
		# ★ โควตาจำนวนตัวเต็มแล้ว ★ ตัวใหม่ไม่โดน (ตัวเดิมยังโดนครั้งถัดไปได้)
		if not (enemy in _hits):
			if _max_targets > 0 and _hits.size() >= _max_targets:
				continue
			_hits.append(enemy)

		var ex: float = enemy.foot_position().x if enemy.has_method("foot_position") \
			else (enemy as Node2D).global_position.x
		var dx: float = ex - global_position.x
		enemy.take_damage_from_player(_mult, _use_matk,
			signi(int(dx)) if dx != 0.0 else _dir)
		_hit_n[enemy] = done + 1
		_next_hit[enemy] = _hit_interval

		# ไม่ทะลุ = ชนตัวแรกแล้วหายไปเลย (เหมือนกระสุน)
		if not _pierce:
			_expire()
			return
		# ★ ชนครบโควตาแล้ว: หยุดอยู่กับที่ เล่นภาพต่อจนจบ ★ (ไม่หายวับกลางคัน)
		if _stick and _max_targets > 0 and _hits.size() >= _max_targets:
			_speed = 0.0
			_follow = null


## นับถอยหลังช่วงเว้นระหว่างครั้ง
func _tick_hit_timers(delta: float) -> void:
	for k in _next_hit.keys():
		_next_hit[k] = float(_next_hit[k]) - delta