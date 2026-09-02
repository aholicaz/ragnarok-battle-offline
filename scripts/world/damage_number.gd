## DamageNumber — ตัวเลขดาเมจสไตล์ MapleStory (รอบ 34)
##
## ตัวเลขแต่ละหลักเป็นรูปจากชีท Sprites/ui/damage_digits.png (ไม่ใช่ฟอนต์)
## เด้งโผล่ทีละหลักจากซ้ายไปขวา (ใหญ่ก่อนแล้วหดลง) → ลอยขึ้นช้า ๆ → จางหาย
##
## สไตล์ (แถวในชีท): 0 ปกติ ม่วง · 1 คริ ส้มทอง · 2 โดนตี แดง · 3 ฮีล เขียว
## ★ อยากเปลี่ยนหน้าตาตัวเลข ★ แก้สีใน make_damage_digits.py แล้วรันใหม่ หรือวาดชีทเองช่องละ 56x72
class_name DamageNumber
extends Node2D

const SHEET_PATH := "res://Sprites/ui/damage_digits.png"
const CELL := Vector2(56, 72)
## หลักตัวเลขซ้อนทับกันนิดหน่อยให้ดูแน่น (เหมือน Maple)
const ADVANCE := 42.0
## เวลาที่แต่ละหลักโผล่ห่างกัน
const STAGGER := 0.035

enum Style { NORMAL, CRIT, HURT, HEAL }

static var _sheet: Texture2D

## ข้อความตัวเลข (ไว้ให้เทสต์/ดีบักอ่าน) และขนาดกล่องรวม
var text: String = ""
var box: Vector2 = Vector2.ZERO


## กรอบบนจอ (มุมซ้ายบน) — ตัวเลขวาดจากจุดกึ่งกลาง
func rect() -> Rect2:
	return Rect2(global_position - box * 0.5, box)


## สร้างหลักตัวเลข · คืนขนาดกล่องรวม (ไว้ให้ FloatingTextLayer จองพื้นที่กันทับ)
func setup(value: int, style: int, scale_mul: float = 1.0) -> Vector2:
	if _sheet == null:
		_sheet = load(SHEET_PATH)
	var digits := str(absi(value))
	text = digits
	var n := digits.length()
	var total_w: float = (ADVANCE * (n - 1) + CELL.x) * scale_mul
	box = Vector2(total_w, CELL.y * scale_mul)
	var x0: float = -total_w * 0.5 + CELL.x * 0.5 * scale_mul

	for i in range(n):
		var d := int(digits[i])
		var spr := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = _sheet
		atlas.region = Rect2(d * CELL.x, style * CELL.y, CELL.x, CELL.y)
		spr.texture = atlas
		spr.position = Vector2(x0 + i * ADVANCE * scale_mul, 0)
		# หลักท้าย ๆ อยู่หน้าหลักก่อน (ซ้อนทับสวยกว่า)
		spr.z_index = i
		spr.scale = Vector2(1.9, 1.9) * scale_mul
		spr.modulate.a = 0.0
		add_child(spr)

		# ★ เด้งโผล่ทีละหลัก ★ ใหญ่ → หด (TRANS_BACK ให้เด้งเกินนิดแล้วกลับ)
		var tw := create_tween()
		tw.tween_interval(STAGGER * i)
		tw.tween_callback(func(): spr.modulate.a = 1.0)
		tw.tween_property(spr, "scale", Vector2(scale_mul, scale_mul), 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return Vector2(total_w, CELL.y * scale_mul)


## เล่นการลอยขึ้น + จางหาย แล้วลบตัวเองทิ้ง
func play(rise: Vector2, life: float, on_done: Callable) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	# ลอยขึ้น: เร็วตอนแรก ช้าตอนท้าย
	tw.tween_property(self, "position", position + rise, life) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# จางเฉพาะช่วงท้าย
	tw.tween_property(self, "modulate:a", 0.0, life * 0.35).set_delay(life * 0.65)
	tw.chain().tween_callback(func():
		on_done.call()
		queue_free())
