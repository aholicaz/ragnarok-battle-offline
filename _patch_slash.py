#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""เพิ่มสกิล Slash เข้าสายอาชีพนักดาบ (รันซ้ำได้)"""
import io, os, re, sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
JOB = "data/jobs/swordsman.tres"
# สกิลใหม่ -> วางต่อจากสกิลนี้ในรายการ (ให้เรียงตามผังสกิล)
NEW_SKILLS = [("slash", "bash")]


def main():
    p = os.path.join(ROOT, JOB)
    if not os.path.exists(p):
        print("  ไม่เจอ %s" % JOB)
        return
    s = io.open(p, encoding="utf-8").read()
    orig = s

    m = re.search(r'^skill_ids = Array\[StringName\]\(\[(.*?)\]\)$', s, re.M | re.S)
    if m is None:
        print("  ! ไม่เจอบรรทัด skill_ids")
        return

    inner = m.group(1)
    for new_id, after_id in NEW_SKILLS:
        if ('&"%s"' % new_id) in inner:
            print("  มี %s ในสายอาชีพอยู่แล้ว ข้าม" % new_id)
            continue
        anchor = '&"%s"' % after_id
        if anchor in inner:
            inner = inner.replace(anchor, '%s, &"%s"' % (anchor, new_id), 1)
        else:
            inner = inner.rstrip() + ', &"%s"' % new_id
        print("  เพิ่ม %s ต่อจาก %s" % (new_id, after_id))

    s = s[:m.start(1)] + inner + s[m.end(1):]
    if s == orig:
        print("  ไม่มีอะไรต้องแก้")
        return
    io.open(p, "w", encoding="utf-8", newline="\n").write(s)
    print("  บันทึก swordsman.tres แล้ว")


if __name__ == "__main__":
    print("สายอาชีพนักดาบ:")
    main()
    print("เสร็จ")
