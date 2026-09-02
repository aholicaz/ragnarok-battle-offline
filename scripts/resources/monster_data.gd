## MonsterData — ค่าพลังของมอนสเตอร์ 1 ชนิด
##
## ★ ไฟล์นี้คือ "ศูนย์กลางการปรับบาลานซ์มอนสเตอร์" ★
## เพิ่มมอนใหม่ = สร้างไฟล์ .tres ใหม่ 1 ไฟล์ ไม่ต้องเขียนโค้ดเพิ่มเลย
## แล้วลากไปใส่ใน MonsterSpawner หรือใส่ใน GameData
class_name MonsterData
extends Resource

enum Element { NEUTRAL, FIRE, WATER, EARTH, WIND, POISON, HOLY, SHADOW, GHOST, UNDEAD }
enum Race { FORMLESS, UNDEAD, BRUTE, PLANT, INSECT, FISH, DEMON, DEMIHUMAN, ANGEL, DRAGON }
enum Size { SMALL, MEDIUM, LARGE }
enum AIType {
	PASSIVE,     ## ไม่โจมตีก่อน ตีแล้วค่อยสู้
	AGGRESSIVE,  ## เห็นแล้วไล่ทันที
	STATIONARY,  ## ไม่เดิน ยืนตีอย่างเดียว
}

@export var id: StringName = &"poring"
@export var display_name: String = "โพริง"

@export_group("Visual")
## SpriteFrames ของมอนตัวนี้ (ต้องมีอนิเมชัน Idle / Run / Attack / Hit / Death)
@export var sprite_frames: SpriteFrames
@export var sprite_scale: Vector2 = Vector2.ONE
@export var sprite_offset: Vector2 = Vector2.ZERO
## ขนาดกล่องชน (แคปซูล)
@export var hitbox_size: Vector2 = Vector2(28, 24)
## ความสูงของหลอดเลือดเหนือหัว
@export var hp_bar_offset_y: float = -48.0
## ★ ความสูงของมอนบนจอ (พิกเซล) ★ 0 = ใช้ Sprite Scale ตามปกติ
## ตั้งค่านี้แล้วระบบจะย่อ/ขยายให้เอง ไม่ว่าไฟล์ภาพจะขนาดไหน
@export var display_height: float = 0.0
## จัดให้เท้าแตะพื้น (ระดับล่างของกล่องชน) เสมอ — ทำให้ยืนระนาบเดียวกับผู้เล่น
@export var align_feet: bool = true

# =========================================================
# ค่าพลังหลัก — แก้ตรงนี้เพื่อปรับความยาก
# =========================================================
@export_group("Core Stats")
@export var level: int = 1
@export var max_hp: int = 50
@export var atk_min: int = 8
@export var atk_max: int = 12
@export var def: int = 0
@export var mdef: int = 0
## hit / flee เป็น "โบนัส" ระบบจะบวก 100 + เลเวล ให้อัตโนมัติ
## ยิ่งสูง = ยิ่งตีโดนง่าย / ยิ่งหลบเก่ง (แนะนำประมาณ เลเวล x 1.5)
@export var hit: int = 8
@export var flee: int = 4
@export var crit: int = 1

@export_group("Type")
@export var element: Element = Element.WATER
@export var element_level: int = 1
@export var race: Race = Race.FORMLESS
@export var size: Size = Size.MEDIUM

# =========================================================
# การเคลื่อนที่และ AI
# =========================================================
@export_group("Movement & AI")
@export var ai_type: AIType = AIType.PASSIVE
@export var move_speed: float = 90.0
## แรงกระโดด (ติดลบ = ขึ้น) ตั้ง 0.0 ถ้ามอนตัวนี้ไม่กระโดด
@export var jump_force: float = -300.0
## กระโดดตอนไล่ผู้เล่นไหม (โพริงกระโดด แต่ผีไม่กระโดด)
@export var jump_while_chasing: bool = true
## ระยะที่เริ่มเห็นผู้เล่น
@export var detect_range: float = 250.0
## ระยะที่เข้าโจมตีได้
@export var attack_range: float = 70.0
## เดินไปไกลจากจุดเกิดได้แค่ไหน (0 = ไม่จำกัด)
@export var leash_range: float = 600.0
## ความเร็วตอนเดินเล่นไปมาตอนไม่เจอผู้เล่น (0 = ยืนเฉย)
@export var wander_speed: float = 50.0
## เดินเล่นห่างจากจุดเกิดได้ไกลสุดเท่าไหร่ (พิกเซล)
@export var wander_range: float = 240.0
## เด้ง/กระโดดตอนเดินเล่นด้วยไหม (โพริงควรเป็น true)
@export var hop_while_wandering: bool = true

## ★★ จังหวะยืนพักตอนเดินเล่น (รอบ 33) ★★
## เดินไปสักพัก -> ยืนนิ่งเล่นท่า Idle -> เดินต่อ  ทำให้แมพดูมีชีวิตขึ้นมาก
## โอกาสที่เดินจบ 1 ช่วงแล้วจะ "ยืนพัก" (0 = ไม่พักเลย เดินตลอด · 1 = พักทุกครั้ง)
@export_range(0.0, 1.0) var wander_pause_chance: float = 0.65
## ยืนพักนานเท่าไหร่ (วินาที) — สุ่มระหว่างสองค่านี้
@export_range(0.2, 12.0) var wander_pause_min: float = 3.0
@export_range(0.2, 12.0) var wander_pause_max: float = 5.0
## เดินติดต่อกันนานเท่าไหร่ก่อนจะพักรอบถัดไป
@export_range(0.3, 12.0) var wander_walk_min: float = 1.6
@export_range(0.3, 12.0) var wander_walk_max: float = 3.2
## ★ ระหว่างพักหันมองรอบ ๆ ★ โอกาสที่จะหันกลับด้านกลางช่วงพัก (0 = ยืนนิ่งอย่างเดียว)
@export_range(0.0, 1.0) var wander_look_chance: float = 0.7
## เว้นกี่วินาทีถึงจะกระโดดได้อีกครั้ง (กันกระโดดรัวจนดูแปลก)
@export var jump_interval: float = 0.7

@export_group("Attack Timing")
## หน่วงกี่วินาทีหลังเริ่มอนิเมชันถึงจะเกิดดาเมจ
@export var attack_windup: float = 0.3
## อนิเมชันโจมตีกินเวลาเท่าไหร่
@export var attack_duration: float = 0.4
## รอกี่วินาทีถึงจะโจมตีได้อีก
@export var attack_cooldown: float = 1.5
## ผู้เล่นโดนแล้วกระเด็นแรงแค่ไหน
@export var knockback_force: float = 120.0

# =========================================================
# รางวัล
# =========================================================
@export_group("Reward")
@export var exp_reward: int = 12
## ★ ค่าประสบการณ์อาชีพ (Job EXP) ★ 0 = คิดให้เอง (70% ของ EXP ปกติ)
@export var job_exp_reward: int = 0
@export var zeny_min: int = 3
@export var zeny_max: int = 10
@export var drops: Array[DropEntry] = []

# =========================================================
# ★ บอส ★
# =========================================================
@export_group("บอส")
## เป็นบอสไหม (ตายแล้วขึ้นป้าย MVP เหนือหัวผู้เล่น + หลอดเลือดใหญ่)
@export var is_boss: bool = false
## คำนำหน้าชื่อตอนโชว์ (เช่น "MVP")
@export var boss_title: String = "MVP"

## ★ วิดีโอเปิดตัวบอส (รอบ 41) ★ เล่นตอนผู้เล่น "เจอบอสตัวนี้ครั้งแรก" — ครั้งเดียวต่อเซฟ
## (จำด้วยธงเนื้อเรื่อง seen_intro_<id> เก็บลงเซฟ) · เว้นว่าง = ไม่มีฉากเปิดตัว
## ต้องเป็น Ogg Theora (.ogv) — แปลงจาก mp4 ด้วย ffmpeg (ดูคู่มือ 7.50)
@export_file("*.ogv") var intro_video: String = ""
## ผู้เล่นเข้าใกล้กว่าระยะนี้ = เริ่มเล่นวิดีโอ
@export var intro_range: float = 700.0

# =========================================================
# ★ สกิลมอนสเตอร์ (ใช้กับบอสเป็นหลัก) ★
#
# ตั้งชื่อท่าใน SpriteFrames ตามช่อง Skill Anim ด้านล่าง
# ไม่มีท่านั้นก็ถอยไปใช้ท่า "Skill" แล้วถอยไป "Attack" ให้เอง
# (ตัวพิมพ์เล็ก-ใหญ่ไม่สำคัญ)
# =========================================================
@export_group("สกิลมอนสเตอร์")
## ชื่อสกิลที่โชว์ตอนร่าย เว้นว่าง = ไม่มีสกิล
@export var skill_name: String = ""
## ★ ชื่อท่าใน SpriteFrames ★ เช่น "Skill_SlimeBomb"
@export var skill_anim: StringName = &""
## ระยะที่เริ่มร่ายสกิลได้
@export var skill_range: float = 320.0
## รัศมีที่โดนสกิล (แนวนอน/แนวตั้ง)
@export var skill_radius_x: float = 300.0
@export var skill_radius_y: float = 180.0
## ตัวคูณดาเมจของสกิล
@export var skill_damage_mult: float = 2.2
## หน่วงกี่วินาทีหลังเริ่มท่าถึงจะเกิดดาเมจ
@export var skill_windup: float = 0.7
## ท่าสกิลกินเวลาทั้งหมดกี่วินาที
@export var skill_duration: float = 0.8
## ร่ายซ้ำได้อีกทีเมื่อไหร่ (วินาที)
@export var skill_cooldown: float = 9.0
## โอกาสร่ายเมื่อคูลดาวน์หมดและผู้เล่นอยู่ในระยะ (0-1)
@export_range(0.0, 1.0) var skill_chance: float = 0.6
## แรงกระเด็นตอนโดนสกิล
@export var skill_knockback: float = 320.0

# =========================================================
# ★ เอฟเฟกต์สกิลของมอน (ภาพที่ใหญ่/ไกลเกินตัวมอนได้) ★
#
# กติกาเดียวกับเอฟเฟกต์สกิลของผู้เล่น:
# วาดเป็น SpriteFrames แยกอีกไฟล์ แล้วลากมาใส่ช่องนี้
# ระบบจะสร้างโหนดใหม่ "ในโลก" ไม่ใช่ลูกของสไปรท์มอน
# =========================================================
@export_group("เอฟเฟกต์สกิลมอน")
## SpriteFrames ของเอฟเฟกต์ (เว้นว่าง = ไม่มีเอฟเฟกต์)
@export var skill_effect_frames: SpriteFrames
## ชื่อท่าใน SpriteFrames นั้น (เว้นว่าง = ใช้ท่าแรกที่เจอ)
@export var skill_effect_anim: StringName = &""
## เยื้องจากตัวมอนกี่พิกเซล — x กลับข้างให้เองตามที่มอนหัน
@export var skill_effect_offset: Vector2 = Vector2(0, -60)
## อยากให้เอฟเฟกต์สูงกี่พิกเซลบนจอ (0 = ใช้ Skill Effect Scale)
@export var skill_effect_height: float = 0.0
@export var skill_effect_scale: float = 1.0
## พุ่งออกไปข้างหน้ากี่พิกเซล/วินาที (0 = อยู่กับที่)
@export var skill_effect_speed: float = 0.0
## เกาะไปกับตัวมอนไหม
@export var skill_effect_follow: bool = true
## อยู่บนจอกี่วินาที (0 = จนกว่าอนิเมชันจะจบ)
@export var skill_effect_life: float = 0.0
## หน่วงกี่วินาทีหลังเริ่มร่ายถึงจะโผล่ (ตั้งเท่า Skill Windup จะระเบิดพร้อมดาเมจพอดี)
@export var skill_effect_delay: float = 0.0
@export var skill_effect_z: int = 60

@export_group("โจมตีระยะไกล — ยิงกระสุน (รอบ 36)")
## ★ ใส่รูปแล้วท่าโจมตีปกติจะ "ยิงกระสุน" ใส่ผู้เล่นแทนการตีติดตัว ★ (เช่น ลูนาติกยิงบอล)
## ยิงตอน Attack Windup · ตั้ง Attack Range ให้ไกล ๆ (300+) มอนจะหยุดยิงจากระยะนั้น
@export var projectile_texture: Texture2D
## ความเร็วกระสุน (พิกเซล/วิ)
@export var projectile_speed: float = 520.0
## ขนาดกระสุนบนจอ (ความสูง พิกเซล)
@export var projectile_height: float = 64.0
## จุดปล่อย นับจากเท้า (x = ไปข้างหน้าตามที่หัน · y ติดลบ = สูงขึ้น)
@export var projectile_offset: Vector2 = Vector2(30, -80)
## กล่องชนของกระสุน (0,0 = ใช้ขนาดรูป)
@export var projectile_hit_size: Vector2 = Vector2.ZERO
## รูปต้นฉบับหันซ้าย (ปกติสไปรท์มอนหันซ้าย) — ยิงไปขวาระบบจะพลิกให้
@export var projectile_faces_left: bool = true
## หมุนกี่รอบต่อวินาที (0 = ไม่หมุน)
@export var projectile_spin: float = 0.0
## วิ่งได้ไกลสุดแล้วหาย
@export var projectile_range: float = 720.0

@export_group("สกิล — บอลโค้งตกพื้นระเบิด (รอบ 36)")
## ★ ใส่รูปแล้วสกิลจะ "ขว้างบอลโค้ง" ไปตกที่ตำแหน่งผู้เล่น แล้วระเบิดทำดาเมจรอบ ๆ ★
## ดาเมจ/รัศมี/กระเด็นใช้ค่า Skill Damage Mult · Skill Radius X/Y · Skill Knockback ตามเดิม
@export var skill_projectile_texture: Texture2D
## ขนาดบอลบนจอ (สูง)
@export var skill_projectile_height: float = 100.0
## จุดปล่อย นับจากเท้า
@export var skill_projectile_offset: Vector2 = Vector2(60, -170)
## โค้งสูงขึ้นจากเส้นตรงเท่าไหร่ (พิกเซล)
@export var skill_projectile_arc: float = 240.0
## เวลาบินจนตกพื้น (วิ)
@export var skill_projectile_time: float = 0.9
## หมุนกี่รอบต่อวินาที
@export var skill_projectile_spin: float = 0.8
## เอฟเฟกต์ตอนระเบิด (เว้นว่าง = ใช้ Sprites/effects/slime_burst.png)
@export var skill_explosion_frames: SpriteFrames
@export var skill_explosion_anim: StringName = &"burst"
## ขนาดเอฟเฟกต์ระเบิดบนจอ (สูง)
@export var skill_explosion_height: float = 260.0

@export_group("ท่าตาย")
## ★ ให้ท่าตายเล่นนานกี่วินาที ★ 0 = คิดจากจำนวนเฟรม/ความเร็วของอนิเมชันเอง
## (ชื่ออนิเมชันจะตั้งเป็น Death / Die / Dead / Dying ก็ได้ พิมพ์เล็ก-ใหญ่ไม่สำคัญ)
@export var death_time: float = 0.0
## เล่นจบแล้วค่อย ๆ จางหายไปกี่วินาที (0 = หายทันที)
@export var death_fade: float = 0.35

@export_group("Respawn")
## ตายแล้วอีกกี่วินาทีเกิดใหม่ (spawner เป็นคนใช้ค่านี้)
@export var respawn_time: float = 8.0


## ระยะจากจุดกำเนิดลงไปถึงพื้นเท้า (= ครึ่งหนึ่งของความสูงกล่องชน)
func foot_offset() -> float:
	return hitbox_size.y * 0.5


## สุ่มพลังโจมตี 1 ครั้ง
func roll_attack() -> int:
	return randi_range(atk_min, max(atk_min, atk_max))


## ค่าประสบการณ์อาชีพที่ได้จากมอนตัวนี้
func job_exp() -> int:
	if job_exp_reward > 0:
		return job_exp_reward
	return maxi(1, int(round(exp_reward * 0.7)))


## มอนตัวนี้มีสกิลไหม
func has_skill() -> bool:
	return skill_name != "" or skill_anim != &""


func roll_zeny() -> int:
	return randi_range(zeny_min, max(zeny_min, zeny_max))


## สุ่มไอเทมที่ดรอปทั้งหมด
func roll_drops() -> Array[ItemInstance]:
	var result: Array[ItemInstance] = []
	for entry in drops:
		if entry == null:
			continue
		var inst := entry.roll()
		if inst != null:
			result.append(inst)
	return result
