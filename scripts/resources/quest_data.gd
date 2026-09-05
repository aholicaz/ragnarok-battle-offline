## QuestData — เควส 1 อัน
##
## ★ เพิ่มเควสใหม่ = สร้างไฟล์ .tres ใหม่ในโฟลเดอร์ data/quests/ ★
## ไม่ต้องเขียนโค้ดเพิ่มเลย แล้วเอา id ไปใส่ในช่อง Quest Ids ของ NPC ที่จะเป็นคนให้เควส
class_name QuestData
extends Resource

@export var id: StringName = &"quest_id"
@export var title: String = "ชื่อเควส"
@export_multiline var description: String = ""

@export_group("คนให้เควส")
## ชื่อ NPC ที่ให้เควสนี้ (ใช้โชว์ในสมุดเควสเฉย ๆ)
@export var giver_name: String = ""
## บทพูดตอนรับเควส
@export_multiline var dialog_offer: String = "ช่วยงานหน่อยได้ไหม"
## บทพูดตอนยังทำไม่เสร็จ
@export_multiline var dialog_progress: String = "ยังไม่ครบนะ สู้ ๆ"
## บทพูดตอนส่งเควส
@export_multiline var dialog_complete: String = "เยี่ยมมาก นี่ของตอบแทน"

@export_group("เงื่อนไข")
## ★★ เงื่อนไขแบบใหม่ (หลายข้อ หลายชนิด) ★★ รอบ 30
## กด + แล้วเลือก New ObjectiveData · ใส่ได้หลายข้อ ต้องครบทุกข้อถึงจะส่งเควสได้
## ชนิด: ฆ่ามอน · หาไอเทม · คุยกับ NPC · ไปให้ถึงแมพ · ตรวจของในแมพ · ธงเนื้อเรื่อง
##
## ★ ใส่ช่องนี้แล้ว 2 ช่องข้างล่างจะถูกมองข้าม ★
@export var objectives: Array[ObjectiveData] = []

## ★ แบบเก่า ★ ต้องล่ามอนตัวไหน (id ของ MonsterData) เว้นว่าง = ไม่ต้องล่า
## เควสเก่าที่กรอกช่องนี้ไว้ยังใช้ได้ปกติ — ระบบแปลงเป็นเงื่อนไข KILL 1 ข้อให้เอง
@export var kill_monster_id: StringName = &""
## ล่ากี่ตัว
@export var kill_count: int = 100
## ต้องเลเวลเท่าไหร่ถึงจะรับเควสได้
@export var required_level: int = 1
## ★ ต้องทำเควสไหนจบก่อน ★ ใส่ id ของเควสก่อนหน้า (ว่าง = รับได้เลย)
@export var required_quests: Array[StringName] = []
## ★ ต้องมีธงเนื้อเรื่องนี้ก่อน ★ ว่าง = ไม่ต้องมี
@export var required_flag: StringName = &""
## ★ ส่งเควสแล้วตั้งธงนี้ ★ ใช้ปลดล็อกเควสถัดไป / เปลี่ยนบทพูด NPC
@export var set_flag_on_complete: StringName = &""

@export_group("ตัวเลือกตอนส่งเควส")
## ★ คำถามหลังส่งเควส (รอบ 38 — ใช้กับ M2 คำสาบานใต้ค้อน) ★
## เว้นว่าง = ไม่มีตัวเลือก · ใส่แล้วผู้เล่นต้องเลือก 1 อย่าง แล้วธงตามช่องข้างล่างจะถูกตั้ง
@export_multiline var choice_prompt: String = ""
## ตัวเลือกที่ให้เลือก เช่น ["ข้าขอสาบาน", "...ยืนเงียบ"]
@export var choice_options: Array[String] = []
## ธงที่จะตั้งตามตัวเลือก (เรียงตรงกับตัวเลือก) เช่น [&"swore_oath", &"stayed_silent"]
@export var choice_flags: Array[StringName] = []

@export_group("ฉากพิเศษหลังส่งเควส")
## ★ แพนกล้องไปหา NPC คนนี้หลังส่งเควส (รอบ 38 — ใช้กับ M6 พิธีฉลอง) ★
## ใส่ "ชื่อ NPC ที่โชว์บนหัว" · เว้นว่าง = ไม่มีฉากพิเศษ
@export var cutscene_pan_npc: String = ""
## ข้อความที่ขึ้นตอนกล้องแพนไปถึง (เว้นบรรทัดว่าง = ขึ้นหน้าใหม่)
@export_multiline var cutscene_text: String = ""

# =========================================================
# ★★ วิดีโอคัทซีน (รอบ 59) ★★  ไฟล์ .ogv (แปลงจาก mp4: ffmpeg -i in.mp4 -c:v libtheora -q:v 7 -c:a libvorbis out.ogv)
# ตอนกด "รับเควส" หรือ "รับรางวัล" เกมจะเล่นวิดีโอเต็มจอ (กด Enter/คลิก ข้ามได้) แล้วค่อยไปต่อ
# แผนว่าเควสไหนควรมีคลิปอะไร + พรอมพ์เจนคลิป: ดู "แผนวิดีโอคัทซีน" ในโปรเจกต์/คู่มือ 7.72
# =========================================================
@export_group("วิดีโอคัทซีน")
## เล่นหลังกดรับเควส (เช่น ฉากวาลเดอร์สั่งงาน)
@export_file("*.ogv") var video_on_accept: String = ""
## เล่นหลังกดรับรางวัล (ก่อนตัวเลือก/ฉากแพนกล้อง) เช่น พิธีฉลองชัยชนะ
@export_file("*.ogv") var video_on_complete: String = ""

@export_group("รางวัล")
## ไอเทมที่จะได้ (id ของไอเทม)
@export var reward_item_id: StringName = &""
@export var reward_item_count: int = 1
@export var reward_zeny: int = 0
@export var reward_exp: int = 0
## ค่าประสบการณ์อาชีพ (Job EXP) · 0 = คิดให้เอง (70% ของ EXP)
@export var reward_job_exp: int = 0

@export_group("อื่น ๆ")
## ทำซ้ำได้ไหม (ส่งเควสแล้วรับใหม่ได้อีก)
@export var repeatable: bool = false


var _legacy_steps: Array[ObjectiveData] = []


## ★★ รายการเงื่อนไขจริงของเควสนี้ ★★
## ใส่ Objectives ไว้ = ใช้อันนั้น · ไม่ได้ใส่ = แปลงช่องแบบเก่าให้เป็นเงื่อนไข KILL 1 ข้อ
func steps() -> Array[ObjectiveData]:
	if not objectives.is_empty():
		return objectives
	if kill_monster_id == &"":
		return _legacy_steps   # ว่าง = ไม่มีเงื่อนไข (เควสแค่คุยจบ)
	if _legacy_steps.is_empty():
		var o := ObjectiveData.new()
		o.kind = ObjectiveData.Kind.KILL
		o.target = kill_monster_id
		o.count = kill_count
		_legacy_steps = [o] as Array[ObjectiveData]
	return _legacy_steps


func step_count() -> int:
	return steps().size()


## ชื่อมอนที่ต้องล่า (เอาไว้โชว์)
func target_name() -> String:
	if kill_monster_id == &"":
		return ""
	var m := GameData.get_monster(kill_monster_id)
	return m.display_name if m != null else String(kill_monster_id)


## สรุปเงื่อนไขเป็นข้อความ
func objective_text(progress: int = 0) -> String:
	if kill_monster_id == &"":
		return "คุยกับ %s" % giver_name
	return "ล่า %s  %d / %d ตัว" % [target_name(), mini(progress, kill_count), kill_count]


## สรุปรางวัลเป็นข้อความ
func reward_text() -> String:
	var parts: Array[String] = []
	if reward_item_id != &"" and reward_item_count > 0:
		parts.append("%s x%d" % [GameData.item_name(reward_item_id), reward_item_count])
	if reward_zeny > 0:
		parts.append("%d z" % reward_zeny)
	if reward_exp > 0:
		var jx: int = reward_job_exp if reward_job_exp > 0 else int(round(reward_exp * 0.7))
		parts.append("EXP %d / Job %d" % [reward_exp, jx])
	return "  ·  ".join(parts) if not parts.is_empty() else "-"
