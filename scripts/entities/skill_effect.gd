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


## สร้างเอฟเฟกต์จากสกิลของผู้เล่น
static func spawn(skill: SkillData, caster: Node2D, facing: int) -> SkillEffect:
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
	if bool(cfg.get("follow", false)):
		_follow = caster
		_follow_offset = Vector2(base_offset.x * signf(facing), base_offset.y)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.flip_h = _dir < 0
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

	var delay := float(cfg.get("delay", 0.0))
	if delay > 0.0:
		visible = false
		var t := get_tree().create_timer(delay) if get_tree() != null else null
		if t != null:
			t.timeout.connect(func():
				if is_instance_valid(self):
					visible = true)


func _anim_length(frames: SpriteFrames, anim: StringName) -> float:
	if frames == null or not frames.has_animation(anim):
		return 0.0
	var speed: float = maxf(0.01, frames.get_animation_speed(anim))
	var total := 0.0
	for i in range(frames.get_frame_count(anim)):
		total += frames.get_frame_duration(anim, i)
	return total / speed


func _process(delta: float) -> void:
	if _follow != null and is_instance_valid(_follow):
		global_position = _follow.global_position + _follow_offset
	elif _speed != 0.0:
		position.x += _dir * _speed * delta

	_life -= delta
	if _life <= 0.0:
		# จางหายแทนที่จะหายวับ
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.12)
		tween.tween_callback(queue_free)
		set_process(false)
