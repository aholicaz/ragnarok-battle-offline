#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""รอบ 54 — ทำ "ฉากดูมอน" ให้มอนแต่ละตัว (เปิดแท็บแล้วเห็นเฟรมแอนิเมชันแถบล่าง เหมือนหน้า player)

    python3 make_monster_preview.py hornet            # ตัวเดียว
    python3 make_monster_preview.py hornet wolf poring
    python3 make_monster_preview.py --all             # ทุกตัวใน data/monsters/

ทำอะไรบ้าง (ต่อมอน 1 ตัว):
  1. ถ้า SpriteFrames ฝังอยู่ในไฟล์มอน (SubResource) → แยกออกมาเป็นไฟล์  data/sprites/monsters/<id>_frames.tres
     แล้วให้ไฟล์มอนชี้ไปที่ไฟล์นั้นแทน (ExtResource) — ข้อมูลเฟรมเหมือนเดิมทุกอย่าง
     (ถ้าเป็น ExtResource อยู่แล้ว ใช้ไฟล์เดิม ไม่แตะ)
  2. สร้างฉาก  scenes/monsters/preview/<id>.tscn  = AnimatedSprite2D ที่ใช้ไฟล์เฟรมเดียวกัน
     → เปิดแท็บนี้ใน Godot คลิก AnimatedSprite2D จะเห็น "เฟรมแอนิเมชัน" ครบทุกท่า แก้ตรงนั้น = แก้ของมอนตัวจริง
     → กด F6 (เล่นฉากปัจจุบัน) = มอนตัวจริงเกิดบนพื้นจำลอง ดูการบิน/โยก/เดินได้เลย

★ ปิด Godot ก่อนรัน ★ (สคริปต์แก้ไฟล์ .tres ของมอน) · ต้นฉบับสำรองที่ _to_delete/originals_monster_preview/
รันซ้ำได้
"""
import os, re, sys, shutil

args = [a for a in sys.argv[1:] if a]
if not args:
    print(__doc__); sys.exit(1)
if "--all" in args:
    ids = sorted(f[:-5] for f in os.listdir("data/monsters") if f.endswith(".tres"))
else:
    ids = [a.replace(".tres", "") for a in args if not a.startswith("-")]

FRAMES_DIR = "data/sprites/monsters"
SCENE_DIR = "scenes/monsters/preview"
BACKUP = "_to_delete/originals_monster_preview"
PREVIEW_SCRIPT = "res://scripts/tools/monster_preview.gd"
os.makedirs(FRAMES_DIR, exist_ok=True)
os.makedirs(SCENE_DIR, exist_ok=True)

HEADER_RE = re.compile(r'^\[gd_resource[^\n]*\]\n', re.M)
EXT_RE = re.compile(r'^\[ext_resource ([^\n]*)\]\n', re.M)


def parse_blocks(text):
    """แยกไฟล์ .tres เป็น (header, ext_resources[list of line], sub_resources[list of (id, type, body)], resource_body)"""
    header = HEADER_RE.match(text).group(0)
    exts = [m.group(0) for m in EXT_RE.finditer(text)]
    subs = []
    for m in re.finditer(r'^\[sub_resource type="([^"]+)" id="([^"]+)"\]\n(.*?)(?=^\[sub_resource |^\[resource\])', text, re.M | re.S):
        subs.append({"type": m.group(1), "id": m.group(2), "body": m.group(3)})
    res = text[text.index("[resource]"):]
    return header, exts, subs, res


def ext_attr(line, key):
    m = re.search(r'(?<![A-Za-z_])%s="([^"]*)"' % key, line)   # กัน uid= ไปชนกับ id=
    return m.group(1) if m else None


def extract_frames(mid):
    path = "data/monsters/%s.tres" % mid
    text = open(path, encoding="utf-8").read()
    m = re.search(r'^sprite_frames = (SubResource|ExtResource)\("([^"]+)"\)', text, re.M)
    if not m:
        print("   ✗ %s ยังไม่มี sprite_frames (ยังไม่ได้ใส่ภาพ) — ข้าม" % mid)
        return None
    if m.group(1) == "ExtResource":
        line = next(l for l in EXT_RE.finditer(text) if ext_attr(l.group(0), "id") == m.group(2))
        frames_path = ext_attr(line.group(0), "path")
        print("   = %s ใช้ไฟล์เฟรมแยกอยู่แล้ว: %s" % (mid, frames_path))
        return frames_path

    header, exts, subs, res = parse_blocks(text)
    sf = next(s for s in subs if s["id"] == m.group(2) and s["type"] == "SpriteFrames")
    # sub_resource ที่ SpriteFrames อ้างถึง (AtlasTexture ฯลฯ) และ ext_resource ที่พวกนั้น + ตัวมันอ้างถึง
    needed_sub_ids = set(re.findall(r'SubResource\("([^"]+)"\)', sf["body"]))
    moved_subs = [s for s in subs if s["id"] in needed_sub_ids]
    ext_ids = set(re.findall(r'ExtResource\("([^"]+)"\)', sf["body"]))
    for s in moved_subs:
        ext_ids |= set(re.findall(r'ExtResource\("([^"]+)"\)', s["body"]))
    moved_exts = [e for e in exts if ext_attr(e, "id") in ext_ids]

    # --- ไฟล์เฟรมใหม่ ---
    frames_path = "res://%s/%s_frames.tres" % (FRAMES_DIR, mid)
    steps = len(moved_exts) + len(moved_subs) + 1
    out = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % steps, ""]
    out += [e.rstrip("\n") for e in moved_exts]
    out.append("")
    for s in moved_subs:
        out.append('[sub_resource type="%s" id="%s"]' % (s["type"], s["id"]))
        out.append(s["body"].rstrip("\n"))
        out.append("")
    out.append("[resource]")
    out.append(sf["body"].rstrip("\n"))
    fp = frames_path.replace("res://", "")
    open(fp, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")

    # --- ไฟล์มอน: ตัด sub_resource ที่ย้ายออก + ext ที่ไม่มีใครใช้แล้ว, ใส่ ext ของไฟล์เฟรม ---
    keep_subs = [s for s in subs if s["id"] not in needed_sub_ids and s["id"] != sf["id"]]
    still_used = set(re.findall(r'ExtResource\("([^"]+)"\)', res)) | set()
    for s in keep_subs:
        still_used |= set(re.findall(r'ExtResource\("([^"]+)"\)', s["body"]))
    keep_exts = [e for e in exts if ext_attr(e, "id") in still_used or ext_attr(e, "type") == "Script"]
    fid = "frames_%s" % mid
    keep_exts.append('[ext_resource type="SpriteFrames" path="%s" id="%s"]\n' % (frames_path, fid))
    res = res.replace(m.group(0), 'sprite_frames = ExtResource("%s")' % fid)
    new_steps = len(keep_exts) + len(keep_subs) + 1
    header = re.sub(r"load_steps=\d+", "load_steps=%d" % new_steps, header) if "load_steps=" in header \
        else header.replace("[gd_resource ", "[gd_resource load_steps=%d " % new_steps, 1)
    parts = [header.rstrip("\n"), ""] + [e.rstrip("\n") for e in keep_exts] + [""]
    for s in keep_subs:
        parts.append('[sub_resource type="%s" id="%s"]' % (s["type"], s["id"]))
        parts.append(s["body"].rstrip("\n"))
        parts.append("")
    parts.append(res.rstrip("\n"))
    os.makedirs(BACKUP, exist_ok=True)
    bak = os.path.join(BACKUP, os.path.basename(path))
    if not os.path.exists(bak):
        shutil.copy2(path, bak)
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(parts) + "\n")
    print("   ✓ %s แยกเฟรม %d ท่า → %s (ย้าย sub_resource %d · ext %d)" % (
        mid, len(re.findall(r'"name": &', sf["body"])), frames_path, len(moved_subs), len(moved_exts)))
    return frames_path


def first_anim(frames_path):
    t = open(frames_path.replace("res://", ""), encoding="utf-8").read()
    names = re.findall(r'"name": &"([^"]+)"', t)
    for pref in ("Idle", "idle", "Stand"):
        if pref in names:
            return pref
    return names[0] if names else "default"


def write_scene(mid, frames_path):
    anim = first_anim(frames_path)
    scene = "%s/%s.tscn" % (SCENE_DIR, mid)
    body = '''[gd_scene load_steps=3 format=3]

[ext_resource type="SpriteFrames" path="%s" id="1_frames"]
[ext_resource type="Script" path="%s" id="2_script"]

[node name="%s_preview" type="Node2D"]
script = ExtResource("2_script")
monster_id = &"%s"

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -120)
sprite_frames = ExtResource("1_frames")
animation = &"%s"
autoplay = "%s"
''' % (frames_path, PREVIEW_SCRIPT, mid, mid, anim, anim)
    if os.path.exists(scene) and open(scene, encoding="utf-8").read() == body:
        print("   = ฉาก %s มีอยู่แล้ว" % scene)
        return
    open(scene, "w", encoding="utf-8", newline="\n").write(body)
    print("   ✓ ฉาก %s (ท่าเริ่ม %s)" % (scene, anim))


for mid in ids:
    if not os.path.exists("data/monsters/%s.tres" % mid):
        print("✗ ไม่พบ data/monsters/%s.tres" % mid); continue
    print("● %s" % mid)
    fp = extract_frames(mid)
    if fp:
        write_scene(mid, fp)
print("\nเปิด Godot → FileSystem → scenes/monsters/preview/<id>.tscn → คลิก AnimatedSprite2D = เห็นเฟรม · F6 = ดูตัวจริงขยับ")
