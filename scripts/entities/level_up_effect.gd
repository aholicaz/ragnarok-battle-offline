## LevelUpEffect — เอฟเฟกต์เลเวลอัพแบบ Ragnarok Online (รอบ 48)
##
## วาดด้วยโค้ดทั้งหมด ไม่ต้องมีไฟล์ภาพ:
##   • วงแสงทองแผ่ออกที่ปลายเท้า (ตอนเริ่ม)
##   • เสาแสงทองพุ่งขึ้นจากพื้น ค่อย ๆ จางหาย (อยู่ "หลัง" ตัวละคร)
##   • รัศมีแสงหมุนช้า ๆ รอบเท้า
##   • ประกายดาวลอยขึ้นระยิบระยับ (อยู่ "หน้า" ตัวละคร)
##   • ตัวหนังสือ LEVEL UP! เด้งใหญ่ แล้วลอยขึ้นจางไป + บรรทัดเลเวลใหม่
##   • จอวาบสีทองแวบเดียว
##
## ใช้:  LevelUpEffect.spawn(player, feet_offset, LevelUpEffect.Kind.BASE, 13)
##       (ติดเป็นลูกของตัวละคร → ตามตัวไปด้วยเหมือน RO)
## แก้ความแรง/สี/เวลาที่ค่าคงที่ข้างล่างได้เลย
class_name LevelUpEffect
extends Node2D

enum Kind { BASE, JOB }

const DURATION := 2.3          # อายุรวม (วินาที)
const PILLAR_H := 380.0        # ความสูงเสาแสง
const PILLAR_W := 110.0        # ความกว้างเสาแสง (ที่ฐาน)
const RING_R := 150.0          # รัศมีวงแสงที่แผ่ออกสุด
const RING_FLAT := 0.32        # วงแบนราบกับพื้น (มุมมองด้านข้าง)
const RAYS := 10
const SPARKS := 30
const TEXT_Y := -300.0         # ตำแหน่งตัวหนังสือ (เหนือปลายเท้า)
const FLASH_ALPHA := 0.32

## สีตามชนิด
const COLORS := {
	Kind.BASE: {"main": Color("#ffd54a"), "soft": Color("#fff2b0"), "text": "LEVEL UP!"},
	Kind.JOB:  {"main": Color("#c58cf0"), "soft": Color("#ecd8ff"), "text": "JOB LEVEL UP!"},
}

var kind: Kind = Kind.BASE
var new_level: int = 0
var _t := 0.0
var _front: _Front
var _sparks: Array = []   # [{pos, vel, phase, size}]
var _label: Label
var _sub: Label
var _rng := RandomNumberGenerator.new()


## สร้างเอฟเฟกต์ติดกับ parent ที่ตำแหน่ง local (ปลายเท้า)
static func spawn(parent: Node, feet_local: Vector2, k: Kind = Kind.BASE, level: int = 0) -> LevelUpEffect:
	var fx := LevelUpEffect.new()
	fx.kind = k
	fx.new_level = level
	fx.position = feet_local
	parent.add_child(fx)
	# ★ ให้เสาแสงอยู่ "หลังตัวละคร" ด้วยลำดับในต้นไม้ (เป็นลูกคนแรก = วาดก่อน AnimatedSprite2D) ★
	# ห้ามใช้ z_index ติดลบ — จะไปอยู่ใต้ฉากหลังของแมพ (z 0) แล้วมองไม่เห็นเลย (กับดักข้อ 76)
	parent.move_child(fx, 0)
	return fx


func _ready() -> void:
	name = "LevelUpEffect"
	z_index = 0                  # เท่าตัวละคร — อยู่หลังเพราะเป็นลูกคนแรก (ดู spawn)
	_rng.randomize()
	var c: Dictionary = COLORS[kind]

	# ---------- ชั้นหน้า: ประกาย + ตัวหนังสือ ----------
	_front = _Front.new()
	_front.fx = self
	_front.z_index = 3           # เทียบกับ z ของเรา (−1) → หน้าตัวละคร
	add_child(_front)

	for i in range(SPARKS):
		_sparks.append({
			"pos": Vector2(_rng.randf_range(-PILLAR_W * 0.5, PILLAR_W * 0.5), _rng.randf_range(-30.0, 10.0)),
			"vel": Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-150.0, -70.0)),
			"phase": _rng.randf_range(0.0, TAU),
			"size": _rng.randf_range(3.0, 7.0),
			"delay": _rng.randf_range(0.0, 0.6),
		})

	_label = Label.new()
	_label.text = String(c.text)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size = Vector2(420, 70)
	_label.position = Vector2(-210, TEXT_Y)
	_label.pivot_offset = _label.size * 0.5
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 54 if kind == Kind.BASE else 44)
	_label.add_theme_color_override("font_color", c.main)
	_label.add_theme_color_override("font_outline_color", Color("#3a2400") if kind == Kind.BASE else Color("#2a1040"))
	_label.add_theme_constant_override("outline_size", 12)
	_label.scale = Vector2(0.2, 0.2)
	_front.add_child(_label)

	if new_level > 0:
		_sub = Label.new()
		_sub.text = ("Base Lv. %d" if kind == Kind.BASE else "Job Lv. %d") % new_level
		_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sub.size = Vector2(300, 30)
		_sub.position = Vector2(-150, TEXT_Y + 62)
		_sub.pivot_offset = _sub.size * 0.5
		_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sub.add_theme_font_size_override("font_size", 20)
		_sub.add_theme_color_override("font_color", c.soft)
		_sub.add_theme_color_override("font_outline_color", Color.BLACK)
		_sub.add_theme_constant_override("outline_size", 6)
		_sub.modulate.a = 0.0
		_front.add_child(_sub)

	# ตัวหนังสือ: เด้งใหญ่ → ค้าง → ลอยขึ้นจาง
	var tw := create_tween()
	tw.tween_property(_label, "scale", Vector2(1.28, 1.28), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_label, "scale", Vector2.ONE, 0.14)
	tw.tween_interval(0.95)
	tw.tween_property(_label, "position:y", TEXT_Y - 50.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_label, "modulate:a", 0.0, 0.55)
	if _sub != null:
		var tw2 := create_tween()
		tw2.tween_interval(0.25)
		tw2.tween_property(_sub, "modulate:a", 1.0, 0.2)
		tw2.tween_interval(0.95)
		tw2.tween_property(_sub, "position:y", TEXT_Y + 62.0 - 50.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw2.parallel().tween_property(_sub, "modulate:a", 0.0, 0.5)

	_screen_flash(c.main)


## จอวาบสีทองแวบเดียว (ชั้นต่ำกว่า UI เกม จะได้ไม่บังหน้าต่าง)
func _screen_flash(col: Color) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	var rect := ColorRect.new()
	rect.color = Color(col.r, col.g, col.b, FLASH_ALPHA)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	var tw := layer.create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(layer.queue_free)


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	for s in _sparks:
		if _t < s.delay:
			continue
		s.pos += s.vel * delta
		s.vel.x += sin(_t * 6.0 + s.phase) * 40.0 * delta   # ส่ายซ้ายขวานิด ๆ
	queue_redraw()
	_front.queue_redraw()


## ความคืบหน้าของช่วง (0-1) จาก t0 ถึง t1
func _phase(t0: float, t1: float) -> float:
	return clampf((_t - t0) / maxf(0.001, t1 - t0), 0.0, 1.0)


func _draw() -> void:
	var c: Dictionary = COLORS[kind]
	var main: Color = c.main
	var soft: Color = c.soft

	# ---------- วงแสงแผ่ออกที่เท้า (0 → 0.6 วิ) ----------
	var ring_p := _phase(0.0, 0.6)
	if ring_p < 1.0:
		var r: float = lerpf(20.0, RING_R, 1.0 - pow(1.0 - ring_p, 2.5))
		var a: float = (1.0 - ring_p) * 0.9
		_draw_ellipse_ring(Vector2.ZERO, r, r * RING_FLAT, Color(main.r, main.g, main.b, a), 6.0)
		_draw_ellipse_ring(Vector2.ZERO, r * 0.7, r * 0.7 * RING_FLAT, Color(soft.r, soft.g, soft.b, a * 0.6), 3.0)

	# ---------- เสาแสง (ขึ้นเร็ว 0.25 วิ · ค้าง · จาง ถึง 1.9 วิ) ----------
	var rise := _phase(0.0, 0.25)
	var fade := 1.0 - _phase(1.1, 1.9)
	var pillar_a: float = rise * fade
	if pillar_a > 0.0:
		var h: float = PILLAR_H * (0.6 + 0.4 * rise) * (0.85 + 0.15 * sin(_t * 9.0))
		var w: float = PILLAR_W * (0.9 + 0.1 * sin(_t * 7.0))
		# ชั้นนอกกว้าง จาง — ชั้นในแคบ สว่าง (ไล่สีบน→ล่างด้วย per-vertex color)
		for layer in [[1.0, 0.28], [0.55, 0.55], [0.22, 0.9]]:
			var lw: float = w * float(layer[0])
			var la: float = pillar_a * float(layer[1])
			var pts := PackedVector2Array([
				Vector2(-lw * 0.5, 0), Vector2(lw * 0.5, 0),
				Vector2(lw * 0.35, -h), Vector2(-lw * 0.35, -h)])
			var cols := PackedColorArray([
				Color(soft.r, soft.g, soft.b, la), Color(soft.r, soft.g, soft.b, la),
				Color(main.r, main.g, main.b, 0.0), Color(main.r, main.g, main.b, 0.0)])
			draw_polygon(pts, cols)
		# แสงสว่างที่ฐาน
		_draw_ellipse_fill(Vector2.ZERO, w * 0.55, w * 0.55 * RING_FLAT, Color(soft.r, soft.g, soft.b, pillar_a * 0.55))

	# ---------- รัศมีหมุนรอบเท้า ----------
	var ray_a: float = _phase(0.05, 0.3) * (1.0 - _phase(1.0, 1.7)) * 0.5
	if ray_a > 0.0:
		var spin: float = _t * 0.9
		for i in range(RAYS):
			var ang: float = spin + TAU * float(i) / float(RAYS)
			var len: float = 120.0 + 40.0 * sin(_t * 5.0 + float(i))
			var dir := Vector2(cos(ang), sin(ang) * RING_FLAT)
			var side := Vector2(-dir.y, dir.x).normalized() * 5.0
			var pts := PackedVector2Array([side, -side, dir * len])
			var cols := PackedColorArray([
				Color(soft.r, soft.g, soft.b, ray_a), Color(soft.r, soft.g, soft.b, ray_a),
				Color(main.r, main.g, main.b, 0.0)])
			draw_polygon(pts, cols)


func _draw_ellipse_ring(center: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(41):
		var a: float = TAU * float(i) / 40.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, width, true)


func _draw_ellipse_fill(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(40):
		var a: float = TAU * float(i) / 40.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


# =========================================================
# ชั้นหน้า — ประกายดาวลอยขึ้น (วาดทับตัวละคร)
# =========================================================
class _Front extends Node2D:
	var fx: LevelUpEffect

	func _draw() -> void:
		if fx == null:
			return
		var c: Dictionary = LevelUpEffect.COLORS[fx.kind]
		var main: Color = c.main
		var soft: Color = c.soft
		var life_fade: float = 1.0 - clampf((fx._t - 1.5) / 0.7, 0.0, 1.0)
		for s in fx._sparks:
			if fx._t < s.delay:
				continue
			var age: float = fx._t - s.delay
			var tw: float = 0.55 + 0.45 * sin(age * 11.0 + s.phase)   # ระยิบ
			var a: float = clampf(age * 4.0, 0.0, 1.0) * life_fade * tw
			if a <= 0.01:
				continue
			var sz: float = float(s.size) * (0.7 + 0.3 * tw)
			var p: Vector2 = s.pos
			# ดาว 4 แฉก (เพชรแนวตั้ง + แนวนอน)
			var star := PackedVector2Array([
				p + Vector2(0, -sz * 1.6), p + Vector2(sz * 0.45, 0),
				p + Vector2(0, sz * 1.6), p + Vector2(-sz * 0.45, 0)])
			draw_colored_polygon(star, Color(soft.r, soft.g, soft.b, a))
			var star2 := PackedVector2Array([
				p + Vector2(-sz * 1.2, 0), p + Vector2(0, sz * 0.4),
				p + Vector2(sz * 1.2, 0), p + Vector2(0, -sz * 0.4)])
			draw_colored_polygon(star2, Color(main.r, main.g, main.b, a * 0.9))
