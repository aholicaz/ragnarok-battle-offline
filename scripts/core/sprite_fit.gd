## SpriteFit — วัด "ขอบภาพจริง" ของ SpriteFrames ครั้งเดียวทั้งเกม (รอบ 44)
##
## ทำไมต้องมี: ระบบ auto-fit ของผู้เล่น/มอน ต้องรู้ว่าในแต่ละเฟรม ตัวละครอยู่ตรงไหนของผ้าใบ
## (ตัดพื้นที่โปร่งใสทิ้ง) → ต้องเรียก Texture2D.get_image() ซึ่ง "ดึงภาพกลับจากการ์ดจอ"
## ช้ามาก (หลาย ms ต่อเฟรมภาพ) และเดิมทำใหม่ทุกครั้งที่มอนเกิด / ผู้เล่นถูกสร้างใหม่หลังเปลี่ยนแมพ
## = เกมกระตุกทุกครั้งที่มอนเกิดหรือเล่นท่าใหม่ครั้งแรก
##
## ตอนนี้: จำผลไว้ตรงกลาง (static) คีย์ = path ของ SpriteFrames + ชื่อท่า
## วัดครั้งเดียวตลอดการรันเกม และ map_base อุ่นเครื่องล่วงหน้าตอนโหลดแมพ (ระหว่างจอมืด)
class_name SpriteFit
extends RefCounted

## เฟรมที่ขอบต่างจากค่ากลางของท่าไม่เกินนี้ (พิกเซลในภาพต้นฉบับ) ถือว่าเป็น "ขอบเบลอ/เงา" ใช้ค่ากลางแทน
const SNAP := 12.0

static var _cache: Dictionary = {}
static var measured_count: int = 0   # ไว้ดูสถิติ/เทสต์


static func _key(frames: SpriteFrames, anim: StringName) -> String:
	# ★ ห้ามใช้ instance id ของ SpriteFrames ★ player_frames.tres ตั้ง resource_local_to_scene
	# → ผู้เล่นทุกตัวที่ถูกสร้าง (ทุกครั้งที่เปลี่ยนแมพ) ได้สำเนา SpriteFrames ใหม่ path ว่าง
	# ใช้ "ภาพเฟรมแรก + จำนวนเฟรม" เป็นตัวระบุแทน — ภาพ (Texture) ถูกแชร์กันเสมอ
	var base := frames.resource_path
	if base == "" and frames.has_animation(anim) and frames.get_frame_count(anim) > 0:
		var tex := frames.get_frame_texture(anim, 0)
		if tex != null:
			base = tex.resource_path if tex.resource_path != "" else "tex:" + str(tex.get_instance_id())
			if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
				var at: Texture2D = (tex as AtlasTexture).atlas
				base = (at.resource_path if at.resource_path != "" else "tex:" + str(at.get_instance_id())) \
					+ "@" + str((tex as AtlasTexture).region)
			base += "x" + str(frames.get_frame_count(anim))
	if base == "":
		base = "id:" + str(frames.get_instance_id())
	return base + "#" + String(anim)


## คืน {"frames": [ {bottom, dx, bottom_use, dx_use} ... ], "tallest": float}
## bottom = ระยะจากกึ่งกลางผ้าใบถึงปลายเท้า · dx = ตัวเยื้องจากกึ่งกลางไปทางขวาเท่าไหร่
## *_use = ค่าที่ควรใช้จริง (ค่ากลางของท่า เว้นแต่เฟรมนั้นต่างมากจริง ๆ)
static func measure(frames: SpriteFrames, anim: StringName) -> Dictionary:
	if frames == null or not frames.has_animation(anim):
		return {}
	var key := _key(frames, anim)
	if _cache.has(key):
		return _cache[key]

	var list: Array = []
	var tallest := 0.0
	for i in range(frames.get_frame_count(anim)):
		var tex := frames.get_frame_texture(anim, i)
		if tex == null:
			continue
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var used := Rect2i(0, 0, int(tw), int(th))
		var img := tex.get_image()
		if img != null:
			var r := img.get_used_rect()
			if r.size.x > 0 and r.size.y > 0:
				used = r
		tallest = maxf(tallest, float(used.size.y))
		list.append({
			"bottom": float(used.position.y + used.size.y) - th * 0.5,
			"dx": float(used.position.x) + float(used.size.x) * 0.5 - tw * 0.5,
		})

	# ค่ากลาง (median) ของทั้งท่า — กันตัวเด้งจากขอบภาพที่คลาดกันเล็กน้อย (รอบ 39)
	var bots: Array = []
	var dxs: Array = []
	for fd in list:
		bots.append(fd.bottom)
		dxs.append(fd.dx)
	bots.sort()
	dxs.sort()
	var med_bottom: float = bots[bots.size() >> 1] if not bots.is_empty() else 0.0
	var med_dx: float = dxs[dxs.size() >> 1] if not dxs.is_empty() else 0.0
	for fd in list:
		fd["bottom_use"] = fd.bottom if absf(fd.bottom - med_bottom) > SNAP else med_bottom
		fd["dx_use"] = fd.dx if absf(fd.dx - med_dx) > SNAP else med_dx

	var info := {"frames": list, "tallest": tallest}
	_cache[key] = info
	measured_count += 1
	return info


## วัดทุกท่าของ SpriteFrames นี้ล่วงหน้า (เรียกตอนโหลดแมพ จะได้ไม่กระตุกกลางเกม)
static func warm(frames: SpriteFrames) -> int:
	if frames == null:
		return 0
	var n := 0
	for a in frames.get_animation_names():
		if not _cache.has(_key(frames, a)):
			measure(frames, a)
			n += 1
	return n


static func is_cached(frames: SpriteFrames, anim: StringName) -> bool:
	return frames != null and _cache.has(_key(frames, anim))


static func clear() -> void:
	_cache.clear()
