## FloatingTextLayer — ตัวเลขดาเมจ/ข้อความลอยเหนือหัว
## วางเป็นลูกของแมพ (Node2D) 1 ตัวต่อ 1 แมพ แล้วมันจะรับสัญญาณเอง
##
## ★ จุดสำคัญ ★ ข้อความหลายอันที่เกิดพร้อมกันจะ "ไม่ทับกัน"
## ระบบจองพื้นที่ให้ทีละอัน อันไหนชนของเดิมก็ดันขึ้นไปอีกชั้น
## แล้วแยกทิศลอยตามชนิดข้อความ (ดาเมจลอยตรง · EXP ลอยขวา · ของที่เก็บได้ลอยซ้าย)
extends Node2D

## ชนิดข้อความ — ใช้เลือกทิศทางลอยและระยะห่าง
enum Kind {
	INFO,     ## ข้อความทั่วไป (ชื่อสกิล, LEVEL UP)
	DAMAGE,   ## ดาเมจที่เราตีมอน
	HURT,     ## ดาเมจที่เราโดน
	MISS,     ## พลาด
	EXP,      ## ค่าประสบการณ์
	LOOT,     ## ของที่เก็บได้ / เงิน
	BOSS,     ## ข้อความใหญ่พิเศษ (MVP)
}

## ระยะเผื่อรอบกล่องข้อความ เวลาเช็คว่าทับกันหรือยัง (พิกเซล)
const PAD := Vector2(10, 4)
## ดันขึ้นอย่างน้อยกี่พิกเซลเมื่อชนของเดิม (จริง ๆ ใช้ความสูงข้อความเป็นหลัก)
const BUMP := 26.0
## เยื้องซ้าย-ขวาสลับกันทีละชั้น จะได้ไม่เป็นเสาตรง ๆ
const BUMP_X := 12.0
## ดันขึ้นได้มากสุดกี่ชั้น
const MAX_BUMP := 9

## ตำแหน่งเริ่มต้นเพิ่มเติมของแต่ละชนิด (แยกกลุ่มให้อ่านง่ายตั้งแต่แรก)
const START_OFFSET := {
	Kind.INFO: Vector2(0, -10),
	Kind.DAMAGE: Vector2(0, -6),
	Kind.HURT: Vector2(0, -6),
	Kind.MISS: Vector2(0, -6),
	Kind.EXP: Vector2(52, -62),
	Kind.LOOT: Vector2(-58, -34),
	Kind.BOSS: Vector2(0, -30),
}
## ทิศที่ลอยไป
const DRIFT := {
	Kind.INFO: Vector2(0, -55),
	Kind.DAMAGE: Vector2(0, -70),
	Kind.HURT: Vector2(0, -70),
	Kind.MISS: Vector2(0, -50),
	Kind.EXP: Vector2(38, -46),
	Kind.LOOT: Vector2(-38, -46),
	Kind.BOSS: Vector2(0, -85),
}

## กล่องข้อความที่ยังลอยอยู่ ใช้กันไม่ให้อันใหม่ไปทับ
var _live: Array = []   # [{ "rect": Rect2, "node": Label }]


func _ready() -> void:
	z_index = 500
	Events.floating_text_requested.connect(_on_floating_text)


func _on_floating_text(world_position: Vector2, text: String, color: Color, size: int,
		kind: int = Kind.INFO) -> void:
	# ★★ ตัวเลขดาเมจ/โดนตี/ฮีล → รูปตัวเลขสไตล์ MapleStory ★★ (รอบ 34)
	if _spawn_damage_number(world_position, text, size, kind):
		return
	var label := Label.new()
	label.text = text
	label.z_index = 500

	var thick: bool = kind == Kind.DAMAGE or kind == Kind.HURT or kind == Kind.BOSS
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	label.add_theme_constant_override("outline_size", 6 if thick else 4)

	# ต้องเข้า tree ก่อนถึงจะวัดขนาดข้อความได้
	add_child(label)
	var box: Vector2 = label.get_minimum_size()
	label.pivot_offset = box * 0.5

	var start: Vector2 = world_position + START_OFFSET.get(kind, Vector2(0, -10)) \
		- Vector2(box.x * 0.5, box.y)
	start = _find_free_spot(start, box)
	label.global_position = start

	var entry := {"rect": Rect2(start - PAD, box + PAD * 2.0), "node": label}
	_live.append(entry)

	var drift: Vector2 = DRIFT.get(kind, Vector2(0, -55))
	var target: Vector2 = start + drift + Vector2(randf_range(-6, 6), 0)

	# ดาเมจ/MVP เด้งโตขึ้นก่อนแล้วค่อยหด — ให้สะดุดตา
	var punch: float = 1.35 if kind == Kind.DAMAGE or kind == Kind.BOSS else 1.12
	var life: float = 1.1 if kind == Kind.BOSS else 0.6

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", target, life) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(punch, punch), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "scale", Vector2.ONE, 0.12)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(func():
		_live.erase(entry)
		if is_instance_valid(label):
			label.queue_free()
	)


# =========================================================
# ★★ ตัวเลขดาเมจแบบ MapleStory ★★ (รอบ 34)
# =========================================================
## ขนาดฟอนต์เดิม 32 = ตัวเลขสูง 72px · ใหญ่กว่านั้นขยายตาม (คริ 40 → 1.25 เท่า)
const DIGIT_BASE_SIZE := 32.0
## ลอยขึ้นกี่พิกเซล / อยู่กี่วินาที
const DIGIT_RISE := Vector2(0, -78)
const DIGIT_LIFE := 1.05

## คืน true ถ้าจัดการเองแล้ว (เป็นตัวเลขล้วน) · false = ให้ไปใช้ Label ตามเดิม
func _spawn_damage_number(world_position: Vector2, text: String, size: int, kind: int) -> bool:
	var style := -1
	var raw := text
	if kind == Kind.DAMAGE:
		style = DamageNumber.Style.CRIT if raw.ends_with("!") else DamageNumber.Style.NORMAL
		raw = raw.trim_suffix("!")
	elif kind == Kind.HURT:
		style = DamageNumber.Style.HURT
	elif kind == Kind.INFO and raw.begins_with("+") and raw.substr(1).is_valid_int():
		style = DamageNumber.Style.HEAL     # "+120" จากยา/ฮีล
		raw = raw.substr(1)
	if style < 0 or not raw.is_valid_int():
		return false

	var k: float = maxf(0.6, float(size) / DIGIT_BASE_SIZE)
	if style == DamageNumber.Style.CRIT:
		k *= 1.12
	var num := DamageNumber.new()
	num.z_index = 500
	add_child(num)
	var box: Vector2 = num.setup(int(raw), style, k)

	# กล่องอ้างอิงมุมซ้ายบน (เหมือน Label) เพื่อใช้ระบบกันทับเดิม
	var start: Vector2 = world_position + START_OFFSET.get(kind, Vector2(0, -6)) \
		- Vector2(box.x * 0.5, box.y)
	start = _find_free_spot(start, box)
	num.global_position = start + box * 0.5      # ตัวเลขวาดจากจุดกึ่งกลาง

	var entry := {"rect": Rect2(start - PAD, box + PAD * 2.0), "node": num}
	_live.append(entry)
	num.play(DIGIT_RISE + Vector2(randf_range(-5, 5), 0), DIGIT_LIFE, func(): _live.erase(entry))
	return true


## หาที่ว่างให้ข้อความใหม่ — ชนของเดิมก็ดันขึ้นไปอีกชั้น
## ★ ต้องดันอย่างน้อยเท่าความสูงของข้อความ ★ ไม่งั้นตีรัว ๆ ตัวเลขจะเกยกัน
func _find_free_spot(start: Vector2, box: Vector2) -> Vector2:
	_live = _live.filter(func(e): return is_instance_valid(e.node))
	var step: float = maxf(BUMP, box.y + PAD.y * 2.0 + 2.0)
	for i in range(MAX_BUMP):
		var pos := start + Vector2(BUMP_X * (1 if i % 2 == 1 else -1) * ((i + 1) / 2), -step * i)
		var rect := Rect2(pos - PAD, box + PAD * 2.0)
		var clash := false
		for e in _live:
			if rect.intersects(e.rect):
				clash = true
				break
		if not clash:
			return pos
	return start + Vector2(0, -step * MAX_BUMP)
