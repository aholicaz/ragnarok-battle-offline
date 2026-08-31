## GameData — คลังข้อมูลกลาง (Autoload ชื่อ "GameData")
## โหลดไฟล์ .tres ทั้งหมดจากโฟลเดอร์ res://data/ ตอนเปิดเกม
## เพิ่มไอเทม/มอน/สกิลใหม่ = แค่วางไฟล์ .tres ในโฟลเดอร์ ไม่ต้องแก้โค้ดนี้
## หมายเหตุ: ไฟล์นี้ห้ามใส่ class_name เพราะจะชนกับชื่อ Autoload
extends Node

const ITEM_DIR := "res://data/items"
const MONSTER_DIR := "res://data/monsters"
const SKILL_DIR := "res://data/skills"
const JOB_DIR := "res://data/jobs"
const CARD_DIR := "res://data/cards"
const QUEST_DIR := "res://data/quests"

var items: Dictionary = {}      # StringName -> ItemData
var monsters: Dictionary = {}   # StringName -> MonsterData
var skills: Dictionary = {}     # StringName -> SkillData
var jobs: Dictionary = {}       # StringName -> JobData
var cards: Dictionary = {}      # StringName -> CardData (เป็นสับเซ็ตของ items)
var quests: Dictionary = {}     # StringName -> QuestData


func _ready() -> void:
	_load_dir(ITEM_DIR, items)
	_load_dir(MONSTER_DIR, monsters)
	_load_dir(SKILL_DIR, skills)
	_load_dir(JOB_DIR, jobs)
	_load_dir(QUEST_DIR, quests)
	# การ์ดสืบทอดจาก ItemData จึงเก็บไว้ในคลังไอเทมด้วย
	_load_dir(CARD_DIR, items)
	for item in items.values():
		if item is CardData:
			cards[StringName(item.id)] = item
	print("[GameData] items=%d (การ์ด %d) monsters=%d skills=%d jobs=%d เควส=%d"
		% [items.size(), cards.size(), monsters.size(), skills.size(), jobs.size(), quests.size()])


func _load_dir(path: String, target: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("[GameData] ไม่พบโฟลเดอร์: " + path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			_load_dir(path.path_join(file_name), target)
		else:
			# ตอน export เกม .tres จะกลายเป็น .tres.remap
			var clean := file_name.trim_suffix(".remap")
			if clean.ends_with(".tres") or clean.ends_with(".res"):
				var res := load(path.path_join(clean))
				if res != null and "id" in res:
					target[StringName(res.id)] = res
		file_name = dir.get_next()

	dir.list_dir_end()


# =========================================================
# ตัวช่วยดึงข้อมูล
# =========================================================

func get_item(id: StringName) -> ItemData:
	return items.get(id, null)


func get_quest(id: StringName) -> QuestData:
	return quests.get(id, null)


## เควสทั้งหมด เรียงตามเลเวลที่ต้องใช้
func all_quests() -> Array[QuestData]:
	var out: Array[QuestData] = []
	for q in quests.values():
		out.append(q)
	out.sort_custom(func(a, b): return a.required_level < b.required_level)
	return out


func get_monster(id: StringName) -> MonsterData:
	return monsters.get(id, null)


func get_skill(id: StringName) -> SkillData:
	return skills.get(id, null)


func get_job(id: StringName) -> JobData:
	return jobs.get(id, null)


func get_card(id: StringName) -> CardData:
	return cards.get(id, null)


## การ์ดทั้งหมด เรียงตามเลเวลมอนสเตอร์
func all_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for c: CardData in cards.values():
		out.append(c)
	out.sort_custom(func(a: CardData, b: CardData) -> bool:
		var ma := a.monster()
		var mb := b.monster()
		var la: int = ma.level if ma != null else 999
		var lb: int = mb.level if mb != null else 999
		if la != lb:
			return la < lb
		return String(a.id) < String(b.id)
	)
	return out


## การ์ดที่ดรอปจากมอนตัวนี้ (ถ้ามี)
func card_of_monster(monster_id: StringName) -> CardData:
	for c: CardData in cards.values():
		if c.monster_id == monster_id:
			return c
	return null


func item_name(id: StringName) -> String:
	var d := get_item(id)
	return d.display_name if d != null else String(id)


## รายชื่อสกิลทั้งหมดของอาชีพหนึ่ง
func skills_for_job(job_id: StringName) -> Array[SkillData]:
	var out: Array[SkillData] = []
	var job := get_job(job_id)
	if job != null and not job.skill_ids.is_empty():
		for sid in job.skill_ids:
			var s := get_skill(sid)
			if s != null:
				out.append(s)
		return out
	# ถ้า JobData ไม่ได้ระบุไว้ ให้กรองจาก SkillData.job_ids แทน
	for s: SkillData in skills.values():
		if s.job_ids.is_empty() or job_id in s.job_ids:
			out.append(s)
	return out
