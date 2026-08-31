## PaperdollDemo — ฉากสาธิตระบบซ้อนเลเยอร์ (เปิดฉากนี้แล้วกด F6 ดูได้เลย)
##
## โชว์ 3 แบบเทียบกัน: ตัวเปล่าอย่างเดียว / ดาบอย่างเดียว / ซ้อนกัน
## ใช้ไฟล์ตัวอย่างใน res://data/sprites/example_*.tres
extends Node2D

const BODY_FRAMES := "res://data/sprites/example_body_frames.tres"
const SWORD_FRAMES := "res://data/sprites/example_sword_frames.tres"

const ANIMS := ["Idle", "Run", "Attack"]
const SWITCH_EVERY := 2.0

var _bodies: Array[AnimatedSprite2D] = []
var _visual: CharacterVisual
var _label: Label
var _anim_index := 0
var _timer := 0.0


func _ready() -> void:
	var body_frames: SpriteFrames = load(BODY_FRAMES)
	var sword_frames: SpriteFrames = load(SWORD_FRAMES)
	if body_frames == null or sword_frames == null:
		push_error("[Demo] หาไฟล์ตัวอย่างไม่เจอ")
		return

	_add_title()

	# ---------- 1) ตัวเปล่าอย่างเดียว ----------
	_bodies.append(_make_body(body_frames, Vector2(180, 300), "ตัวเปล่า"))

	# ---------- 2) ดาบอย่างเดียว ----------
	_bodies.append(_make_body(sword_frames, Vector2(380, 300), "เลเยอร์ดาบ"))

	# ---------- 3) ซ้อนกัน (ของจริงในเกม) ----------
	var body := _make_body(body_frames, Vector2(580, 300), "ซ้อนกัน = ที่เห็นในเกม")
	_bodies.append(body)

	# สร้างไอเทมจำลองขึ้นมาเพื่อป้อนให้ระบบเลเยอร์
	var fake_sword := ItemData.new()
	fake_sword.id = &"demo_sword"
	fake_sword.display_name = "ดาบตัวอย่าง"
	fake_sword.equip_sprite_frames = sword_frames
	fake_sword.equip_z_index = 1

	_visual = CharacterVisual.new()
	_visual.use_player_equipment = false
	_visual.body_path = ^"../AnimatedSprite2D"
	body.get_parent().add_child(_visual)
	await get_tree().process_frame
	_visual.set_layer(Equipment.EquipSlot.WEAPON, fake_sword)

	_play(ANIMS[0])


func _add_title() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color("#1a1f2e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.z_index = -10
	layer.add_child(bg)

	_label = Label.new()
	_label.position = Vector2(40, 40)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color("#ffd54a"))
	layer.add_child(_label)

	var hint := Label.new()
	hint.position = Vector2(40, 74)
	hint.text = "ทุกเฟรมใช้ผ้าใบ 80x90 เท่ากัน จึงซ้อนตรงกันโดยไม่ต้องตั้ง offset"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color("#93a1b8"))
	layer.add_child(hint)


func _make_body(frames: SpriteFrames, pos: Vector2, caption: String) -> AnimatedSprite2D:
	var holder := Node2D.new()
	holder.position = pos
	add_child(holder)

	var spr := AnimatedSprite2D.new()
	spr.name = "AnimatedSprite2D"
	spr.sprite_frames = frames
	spr.scale = Vector2(3, 3)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(spr)

	var cap := Label.new()
	cap.text = caption
	cap.position = Vector2(-90, 150)
	cap.size = Vector2(180, 24)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 15)
	cap.add_theme_color_override("font_color", Color("#e6ecf5"))
	holder.add_child(cap)

	return spr


func _play(anim: String) -> void:
	for b in _bodies:
		if b.sprite_frames.has_animation(anim):
			b.play(anim)
	if _label != null:
		_label.text = "ท่า: %s   (สลับอัตโนมัติทุก %.0f วินาที)" % [anim, SWITCH_EVERY]


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= SWITCH_EVERY:
		_timer = 0.0
		_anim_index = (_anim_index + 1) % ANIMS.size()
		_play(ANIMS[_anim_index])

	# ท่าโจมตีไม่วน ให้เล่นซ้ำเองระหว่างรอสลับท่า
	for b in _bodies:
		if not b.is_playing():
			b.play(b.animation)
