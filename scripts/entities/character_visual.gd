## CharacterVisual — ระบบซ้อนเลเยอร์ตัวละคร (Paper Doll แบบ Ragnarok)
##
## ตัวละครฐาน = ตัวเปล่า (AnimatedSprite2D ปกติ)
## อุปกรณ์ที่สวม = เลเยอร์ AnimatedSprite2D ซ้อนทับ เล่นเฟรมตรงกับตัวเปล่าเป๊ะ ๆ
##
## โครงสร้าง Scene:
##   Player (CharacterBody2D)
##   ├── AnimatedSprite2D   <- ตัวเปล่า (body)
##   ├── EquipVisual        <- ใส่สคริปต์นี้ (Node2D)
##   └── CollisionShape2D
##
## อุปกรณ์แต่ละชิ้นตั้งภาพได้ 2 แบบใน ItemData:
##   A) Equip Sprite Frames — ภาพเคลื่อนไหวครบทุกท่า (แนะนำ เหมือน RO)
##   B) Equip Texture       — ภาพนิ่งใบเดียว ติดกับตัวไปเฉย ๆ (ทำง่าย ใช้ชั่วคราวได้)
class_name CharacterVisual
extends Node2D

## ลำดับการวาด (ตัวแรก = อยู่หลังสุด)
const LAYER_ORDER := [
	Equipment.EquipSlot.GARMENT,
	Equipment.EquipSlot.SHOES,
	Equipment.EquipSlot.ARMOR,
	Equipment.EquipSlot.OFFHAND,
	Equipment.EquipSlot.WEAPON,
	Equipment.EquipSlot.HEAD,
]

## ตัวเปล่าที่จะให้เลเยอร์เดินตาม
@export var body_path: NodePath = ^"../AnimatedSprite2D"
## ดึงของที่สวมอยู่จาก PlayerState อัตโนมัติ (ปิดถ้าใช้กับ NPC/ศัตรู)
@export var use_player_equipment: bool = true

var body: AnimatedSprite2D

var _layers: Dictionary = {}      # EquipSlot -> AnimatedSprite2D
var _layer_data: Dictionary = {}  # EquipSlot -> ItemData


func _ready() -> void:
	body = get_node_or_null(body_path) as AnimatedSprite2D
	if body == null:
		push_warning("[CharacterVisual] หา AnimatedSprite2D ของตัวเปล่าไม่เจอที่ %s" % body_path)
		return

	_build_layers()

	if use_player_equipment:
		Events.equipment_changed.connect(refresh_from_player)
		refresh_from_player()


func _build_layers() -> void:
	for i in range(LAYER_ORDER.size()):
		var slot: int = LAYER_ORDER[i]
		var layer := AnimatedSprite2D.new()
		layer.name = "Layer_%s" % Equipment.SLOT_NAMES.get(slot, str(slot))
		layer.centered = body.centered
		layer.texture_filter = body.texture_filter
		layer.hide()
		# ค่าเริ่มต้น: ผ้าคลุม/รองเท้าอยู่หลัง ที่เหลืออยู่หน้า
		layer.z_index = -1 if slot == Equipment.EquipSlot.GARMENT else i
		add_child(layer)
		_layers[slot] = layer


# =========================================================
# อัพเดตภาพตามของที่สวมอยู่
# =========================================================
func refresh_from_player() -> void:
	if not use_player_equipment or PlayerState.equipment == null:
		return
	for slot in _layers.keys():
		var inst: ItemInstance = PlayerState.equipment.get_item(slot)
		set_layer(slot, inst.data() if inst != null else null)


## ตั้งภาพของเลเยอร์เอง (ใช้กับ NPC / ตัวละครอื่น)
func set_layer(slot: int, item: ItemData) -> void:
	var layer: AnimatedSprite2D = _layers.get(slot)
	if layer == null:
		return

	_layer_data[slot] = item

	if item == null:
		layer.sprite_frames = null
		layer.hide()
		return

	if item.equip_sprite_frames != null:
		# --- แบบ A: ภาพเคลื่อนไหวครบทุกท่า ---
		layer.sprite_frames = item.equip_sprite_frames
	elif item.equip_texture != null:
		# --- แบบ B: ภาพนิ่งใบเดียว สร้าง SpriteFrames ให้อัตโนมัติ ---
		var frames := SpriteFrames.new()
		frames.add_frame(&"default", item.equip_texture)
		layer.sprite_frames = frames
	else:
		layer.sprite_frames = null
		layer.hide()
		return

	layer.z_index = item.equip_z_index
	layer.show()


# =========================================================
# ซิงก์เฟรมให้ตรงกับตัวเปล่าทุกเฟรม — หัวใจของระบบ
# =========================================================
func _process(_delta: float) -> void:
	if body == null:
		return

	# เดินตามตำแหน่ง/ขนาดของตัวเปล่า เพื่อให้ภาพซ้อนตรงกันเสมอ
	position = body.position
	scale = body.scale
	rotation = body.rotation

	var body_anim := body.animation
	var body_frame := body.frame
	var flipped := body.flip_h

	for slot in _layers.keys():
		var layer: AnimatedSprite2D = _layers[slot]
		var frames := layer.sprite_frames
		if frames == null:
			continue

		# หาอนิเมชันที่ตรงกัน ถ้าอุปกรณ์ชิ้นนี้ไม่มีท่านั้นก็ซ่อนไป
		# (ชื่อท่าไม่สนตัวพิมพ์เล็ก-ใหญ่ เหมือนที่ตัวละคร/มอนใช้)
		var anim := _match_anim(frames, body_anim)
		if anim == &"":
			# SpriteFrames จะมีอนิเมชันชื่อ "default" ติดมาเสมอ ต้องเช็คว่ามีเฟรมจริงด้วย
			if frames.has_animation(&"default") and frames.get_frame_count(&"default") > 0:
				anim = &"default"
			else:
				layer.hide()
				continue

		layer.show()
		if layer.animation != anim:
			layer.animation = anim

		var count := frames.get_frame_count(anim)
		layer.frame = clampi(body_frame, 0, maxi(0, count - 1))
		layer.flip_h = flipped

		# ตำแหน่งเยื้อง: ใช้ของตัวเปล่าเป็นฐาน แล้วบวกค่าเยื้องของอุปกรณ์
		var item: ItemData = _layer_data.get(slot)
		var extra := Vector2.ZERO
		var z: int = layer.z_index
		if item != null:
			extra = item.equip_offset
			z = item.equip_z_index_flipped if (flipped and item.use_flipped_z) else item.equip_z_index
		if flipped:
			extra.x = -extra.x
		layer.offset = body.offset + extra
		layer.z_index = z


## ซ่อน/โชว์เลเยอร์อุปกรณ์ทั้งหมด (เช่น ตอนตัวละครล่องหน)
## หาชื่อท่าในอุปกรณ์ที่ตรงกับท่าของตัวเปล่า (ไม่สนตัวพิมพ์เล็ก-ใหญ่)
## คืน &"" ถ้าไม่มีท่านั้นเลย
func _match_anim(frames: SpriteFrames, want: StringName) -> StringName:
	if frames.has_animation(want):
		return want
	var lower := String(want).to_lower()
	for a in frames.get_animation_names():
		if String(a).to_lower() == lower:
			return StringName(a)
	return &""


func set_layers_visible(v: bool) -> void:
	for layer: AnimatedSprite2D in _layers.values():
		layer.visible = v and layer.sprite_frames != null
