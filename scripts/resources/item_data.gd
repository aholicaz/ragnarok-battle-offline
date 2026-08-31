## ItemData — ข้อมูลไอเทม 1 ชนิด (แม่แบบ ไม่ใช่ของในกระเป๋า)
## ของที่อยู่ในกระเป๋าจริง ๆ คือ ItemInstance ซึ่งอ้างถึง ItemData ตัวนี้
class_name ItemData
extends Resource

enum Type {
	CONSUMABLE,   ## ของกิน / ยา
	WEAPON,       ## อาวุธ
	ARMOR,        ## ชุดเกราะ / ของสวมใส่
	MATERIAL,     ## วัตถุดิบ (ใช้ตีบวก / เควส)
	QUEST,        ## ของเควส ขายไม่ได้ ทิ้งไม่ได้
	CARD,         ## การ์ดมอนสเตอร์ (ใช้ CardData)
}

enum Slot {
	NONE,
	WEAPON,
	OFFHAND,      ## โล่ / อาวุธมือรอง
	HEAD,
	ARMOR,
	GARMENT,      ## ผ้าคลุม
	SHOES,
	ACCESSORY,    ## เครื่องประดับ (มี 2 ช่อง)
}

@export var id: StringName = &"item_id"
@export var display_name: String = "ไอเทม"
@export_multiline var description: String = ""
## ★ ไอคอนไอเทม ★ ใช้ทั้งในกระเป๋า ช่องสวมใส่ ร้านค้า และตอนตกอยู่บนพื้น
@export var icon: Texture2D
## ขนาดของภาพตอนตกอยู่บนพื้น (พิกเซล ด้านที่ยาวที่สุด) — 0 = ใช้ขนาดจริงของไฟล์
@export var drop_display_size: float = 46.0

## ★ ต้องเลเวลเท่าไหร่ถึงจะสวมใส่ได้ ★ (1 = ใส่ได้ตั้งแต่เริ่มเกม)
@export var required_level: int = 1

@export var type: Type = Type.MATERIAL
@export var slot: Slot = Slot.NONE
## ชนิดอาวุธ ใช้เช็คว่าอาชีพนี้ใส่ได้ไหม เช่น sword, dagger, bow
@export var weapon_type: StringName = &""

# =========================================================
# ภาพตอนสวมใส่ (Paper Doll) — ใช้กับ CharacterVisual
# =========================================================
@export_group("ภาพตอนสวมใส่")
## ★ แบบ A (แนะนำ) ★ ภาพเคลื่อนไหวครบทุกท่า
## ต้องมีชื่ออนิเมชันและจำนวนเฟรม "ตรงกับตัวเปล่า" เช่น Idle 6 เฟรม / Run 6 เฟรม / Attack 6 เฟรม
## วาดบนผืนผ้าใบขนาดเท่ากับตัวเปล่า แล้วระบบจะซ้อนให้ตรงเองโดยไม่ต้องตั้งค่าอะไรเพิ่ม
@export var equip_sprite_frames: SpriteFrames

## แบบ B (ทำง่าย) ภาพนิ่งใบเดียว ติดกับตัวไปเฉย ๆ ไม่ขยับตามท่า
## ใช้ได้ถ้ายังไม่อยากวาดครบทุกเฟรม
@export var equip_texture: Texture2D

## เยื้องตำแหน่งภาพ (ถ้าวาดผืนผ้าใบเท่าตัวเปล่า ไม่ต้องแตะเลย ปล่อย 0,0)
@export var equip_offset: Vector2 = Vector2.ZERO

## ★ ท่าโจมตีตอนถืออาวุธชิ้นนี้ ★
## เว้นว่าง = ใช้ชื่ออัตโนมัติจากชนิดอาวุธ เช่น weapon_type = sword -> "Attack_sword"
## ใส่ชื่อเองได้ถ้าอยากให้อาวุธชิ้นนี้มีท่าเฉพาะตัว เช่น "Attack_flame_sword"
@export var attack_animation: StringName = &""

## ลำดับการวาด เทียบกับตัวเปล่า (บวก = อยู่หน้าตัว, ลบ = อยู่หลังตัว)
@export var equip_z_index: int = 1
## ใช้ z คนละค่าตอนหันอีกด้านไหม (เช่น ดาบอยู่หน้าตอนหันขวา อยู่หลังตอนหันซ้าย)
@export var use_flipped_z: bool = false
@export var equip_z_index_flipped: int = -1

@export_group("Card Socket")
## ★ จำนวนช่องการ์ด "สูงสุด" ของไอเทมชนิดนี้ (0 = ใส่การ์ดไม่ได้เลย) ★
##
## ⚠ ของที่ซื้อจากร้านจะ "ไม่มีช่องการ์ด" เสมอ
## ช่องการ์ดจะติดมากับของที่ "ดรอปจากมอนสเตอร์" เท่านั้น
## (จำนวนช่องจริงของแต่ละชิ้นเก็บไว้ที่ ItemInstance.slots)
@export_range(0, 4) var card_slots: int = 0

@export_group("Stack & Price")
@export var max_stack: int = 99
@export var buy_price: int = 100
@export var sell_price: int = 40
@export var can_drop: bool = true

# =========================================================
# ค่าพลังที่ได้จากการสวมใส่
# =========================================================
@export_group("Equip Bonus")
@export var atk: int = 0
@export var matk: int = 0
@export var def: int = 0
@export var mdef: int = 0
@export var hit: int = 0
@export var flee: int = 0
@export var crit: int = 0
@export var max_hp: int = 0
@export var max_sp: int = 0
@export var aspd_percent: float = 0.0

@export_group("Stat Bonus")
@export var bonus_str: int = 0
@export var bonus_agi: int = 0
@export var bonus_vit: int = 0
@export var bonus_int: int = 0
@export var bonus_dex: int = 0
@export var bonus_luk: int = 0

# =========================================================
# การตีบวก (Refine)
# =========================================================
@export_group("Refine")
@export var refinable: bool = false
## ตีบวกได้สูงสุดเท่าไหร่
@export var max_refine: int = 10
## +1 เพิ่ม ATK เท่าไหร่ (สำหรับอาวุธ)
@export var refine_atk_per_level: int = 3
## +1 เพิ่ม DEF เท่าไหร่ (สำหรับเกราะ)
@export var refine_def_per_level: int = 1

# =========================================================
# ผลของของกิน
# =========================================================
@export_group("Consumable Effect")
@export var heal_hp: int = 0
@export var heal_sp: int = 0
## % ของ MaxHP ที่ฟื้นเพิ่ม
@export var heal_hp_percent: float = 0.0
@export var heal_sp_percent: float = 0.0


func is_equipment() -> bool:
	return type == Type.WEAPON or type == Type.ARMOR


func is_card() -> bool:
	return type == Type.CARD


func is_stackable() -> bool:
	## ของสวมใส่ที่ตีบวกหรือใส่การ์ดได้ ต้องแยกชิ้น ไม่กองรวมกัน
	return not (is_equipment() and (refinable or card_slots > 0))
