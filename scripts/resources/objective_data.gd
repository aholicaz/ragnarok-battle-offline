## ObjectiveData — เงื่อนไข 1 ข้อของเควส (รอบ 30)
##
## ★ ทำไมต้องมี ★
## ของเดิมเควสทำได้อย่างเดียวคือ "ฆ่ามอนกี่ตัว" เขียนเควสเนื้อเรื่องไม่ได้เลย
## ตอนนี้เควส 1 อันมีได้หลายเงื่อนไข และมีได้หลายชนิด
##
## ★ วิธีสร้าง ★ ในหน้าต่าง Inspector ของไฟล์เควส (.tres)
##   ช่อง "เงื่อนไข (หลายข้อ)" -> กด + -> เลือก New ObjectiveData -> กรอกช่องข้างล่าง
##
## ★ ของเดิมยังใช้ได้ ★ เควสที่กรอก Kill Monster Id / Kill Count ไว้แบบเก่า
## ระบบจะแปลงให้เป็นเงื่อนไข KILL 1 ข้ออัตโนมัติ ไม่ต้องแก้ไฟล์เก่า
class_name ObjectiveData
extends Resource

## ชนิดของเงื่อนไข
enum Kind {
	KILL,     ## ฆ่ามอนสเตอร์ — Target = id ของมอน
	COLLECT,  ## มีไอเทมในกระเป๋า — Target = id ของไอเทม (นับสด ๆ จากกระเป๋า)
	TALK,     ## คุยกับ NPC — Target = "ชื่อ NPC" ที่โชว์บนหัว
	VISIT,    ## ไปให้ถึงแมพ — Target = map_id
	READ,     ## อ่าน/ตรวจของในแมพ — Target = id ของจุดนั้น (ตั้งเองได้)
	FLAG,     ## ธงเนื้อเรื่องถูกตั้งแล้ว — Target = ชื่อธง (นับสด ๆ)
}

@export var kind: Kind = Kind.KILL
## ★ เป้าหมาย ★ ความหมายเปลี่ยนตามชนิด (ดูคำอธิบายของ Kind ข้างบน)
@export var target: StringName = &""
## ต้องกี่ครั้ง/กี่ชิ้น (TALK · VISIT · READ · FLAG ใช้ 1 ก็พอ)
@export var count: int = 1
## ★ ข้อความในสมุดเควส ★ เว้นว่าง = ระบบเขียนให้เอง
@export var text: String = ""
## COLLECT: ยึดของตอนส่งเควสไหม (ปิด = ให้ผู้เล่นเก็บของไว้)
@export var consume: bool = true


func need() -> int:
	return maxi(1, count)


## ★ เงื่อนไขนี้นับสดจากสถานะปัจจุบันไหม ★
## COLLECT อ่านจากกระเป๋า · FLAG อ่านจากธงเนื้อเรื่อง — ไม่ต้องเก็บตัวเลขไว้
func is_live() -> bool:
	return kind == Kind.COLLECT or kind == Kind.FLAG


## ทำไปแล้วเท่าไหร่ (เฉพาะชนิดที่นับสด) — ชนิดอื่นให้ QuestLog เก็บเอง
func live_progress() -> int:
	match kind:
		Kind.COLLECT:
			if PlayerState.inventory == null:
				return 0
			return PlayerState.inventory.count_of(target)
		Kind.FLAG:
			return 1 if PlayerState.has_flag(target) else 0
	return 0


## ข้อความที่โชว์ในสมุดเควส
func describe() -> String:
	if text != "":
		return text
	match kind:
		Kind.KILL:
			var m := GameData.get_monster(target)
			return "ล่า %s" % (m.display_name if m != null else String(target))
		Kind.COLLECT:
			var it := GameData.get_item(target)
			return "หา %s" % (it.display_name if it != null else String(target))
		Kind.TALK:
			return "คุยกับ %s" % String(target)
		Kind.VISIT:
			return "ไปที่ %s" % String(target)
		Kind.READ:
			return "ตรวจดู %s" % String(target)
		Kind.FLAG:
			return String(target)
	return String(target)


## บรรทัดเต็มพร้อมตัวเลข เช่น "ล้ม โพริง  7/10"
func line(done: int) -> String:
	var n := need()
	if n <= 1:
		return "%s  %s" % [describe(), "[x]" if done >= 1 else "[ ]"]
	return "%s  %d/%d" % [describe(), mini(done, n), n]
