#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ตัดไฟล์เสียงพากย์ยาว ๆ 1 ไฟล์ ให้เป็นไฟล์ย่อยตามบทพูดของ NPC (รอบ 61)

    python3 cut_voice.py เสียงฮันส์.wav --voice hans            # ดูว่าจะตัดยังไง (ยังไม่เขียนไฟล์)
    python3 cut_voice.py เสียงฮันส์.wav --voice hans --apply    # ตัดจริง → Sprites/voice/hans/*.ogg
    python3 cut_voice.py เสียงฮันส์.wav --voice hans --apply --skip greeting,dialog_1
                                                              # ถ้าไฟล์เสียงไม่ได้อ่านบางประโยค
    python3 cut_voice.py ไฟล์2.wav --voice hans --apply --only m5_old_mine_iron_complete
                                                              # ไฟล์นี้มีแค่ประโยคเดียว (TTS แบ่งไฟล์)

★ ทำงานยังไง ★
 1. หา "ช่วงที่มีเสียง" ด้วยระดับความดัง (เงียบเกิน 0.68 วิ = ขึ้นประโยคใหม่)
 2. เอาบทพูดของ voice_id นั้นจาก dump_npc_lines.py มาเรียงตามลำดับเดิม
 3. จับคู่ "ช่วงเสียง" กับ "ประโยค" ด้วยจำนวนพยางค์ (ประโยคยาว = เสียงยาว) แบบหาทางที่พอดีที่สุด
 4. ตัด + ใส่เฟดหัวท้ายกันเสียงป๊อก + แปลงเป็น .ogg วางใน Sprites/voice/<voice_id>/

★ ถ้าจับคู่ผิด ★ ใช้ --skip บอกว่าประโยคไหน "ไม่มีในไฟล์เสียง" แล้วรันใหม่
   หรือแก้ไฟล์แผนที่ตัด (--plan ไฟล์.json) แล้วสั่ง --from-plan ไฟล์.json --apply

★ อัดเสียงใหม่ทับของเดิม ★ ถ้าในโฟลเดอร์มีไฟล์เก่าอยู่แล้ว จะเทียบเสียงใหม่กับเก่าให้อัตโนมัติ
   (ตัวเลข "เทียบของเดิม" ยิ่งน้อยยิ่งเป็นประโยคเดียวกัน — ต่ำกว่า 0.10 = ตรงแน่นอน · เกิน 0.15 = น่าจะจับคู่ผิด)

ต้องมี ffmpeg · (ไม่บังคับ) pythainlp ช่วยนับพยางค์ให้แม่นขึ้น
"""
import os, sys, json, wave, subprocess, shutil
import numpy as np

# ---------------- ตัวเลือกบรรทัดคำสั่ง ----------------
args = sys.argv[1:]
def opt(name, default=None):
    return args[args.index(name) + 1] if name in args else default

WAV = args[0] if args and not args[0].startswith("--") else None
VOICE = opt("--voice", "")
APPLY = "--apply" in args
SKIP = [s.strip() for s in (opt("--skip", "") or "").split(",") if s.strip()]
ONLY = [s.strip() for s in (opt("--only", "") or "").split(",") if s.strip()]
PLAN_OUT = opt("--plan", "_to_delete/voice_plan_%s.json" % (VOICE or "x"))
FROM_PLAN = opt("--from-plan")
OUT_DIR = opt("--out", "Sprites/voice")
CSV = opt("--csv", "_to_delete/npc_lines.csv")

## เงียบนานกว่านี้ = ขึ้นประโยคใหม่ (วินาที)
LINE_GAP = float(opt("--gap", "0.68"))
## ระดับที่ถือว่า "เงียบ" (dB)
SILENCE_DB = float(opt("--db", "-40"))
## เผื่อหัว-ท้ายคลิป (วินาที)
PAD_HEAD, PAD_TAIL = 0.08, 0.18
FADE = 0.015


# ---------------- อ่านไฟล์เสียง ----------------
def load_wav(path):
    tmp = None
    if not path.lower().endswith(".wav"):
        tmp = "/tmp/_cutvoice_in.wav"
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", path, "-ac", "1", tmp], check=True)
        path = tmp
    w = wave.open(path)
    sr, n, ch = w.getframerate(), w.getnframes(), w.getnchannels()
    x = np.frombuffer(w.readframes(n), dtype=np.int16).astype(np.float32) / 32768.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(1)
    return x, sr


def find_segments(x, sr):
    """หาช่วงที่มีเสียง (ปิดช่องว่างสั้น ๆ ในประโยคเดียวกัน)"""
    hop, win = int(sr * 0.01), int(sr * 0.025)
    nf = 1 + (len(x) - win) // hop
    e = np.array([np.sqrt(np.mean(x[i * hop:i * hop + win] ** 2)) for i in range(nf)])
    db = 20 * np.log10(np.maximum(e, 1e-8))
    v = db > SILENCE_DB
    def fill(v, fr, dr):
        v = v.copy(); i = 0
        while i < len(v):
            if not v[i]:
                j = i
                while j < len(v) and not v[j]: j += 1
                if i > 0 and j < len(v) and (j - i) < fr: v[i:j] = True
                i = j
            else: i += 1
        i = 0
        while i < len(v):
            if v[i]:
                j = i
                while j < len(v) and v[j]: j += 1
                if (j - i) < dr: v[i:j] = False
                i = j
            else: i += 1
        return v
    v = fill(v, int(0.35 / 0.01), int(0.10 / 0.01))
    out = []; i = 0
    while i < len(v):
        if v[i]:
            j = i
            while j < len(v) and v[j]: j += 1
            out.append((round(i * 0.01, 3), round(j * 0.01, 3)))
            i = j
        else: i += 1
    return out


def group(segs, gap):
    g = []; cur = list(segs[0])
    for a, b in segs[1:]:
        if a - cur[1] >= gap: g.append(tuple(cur)); cur = [a, b]
        else: cur[1] = b
    g.append(tuple(cur))
    return g


# ---------------- บทพูด ----------------
def syllables(t):
    try:
        from pythainlp.tokenize import syllable_tokenize
        return max(1, len([s for s in syllable_tokenize(t) if s.strip()]))
    except Exception:
        # ไม่มี pythainlp → ประมาณจากจำนวนตัวอักษร (ไทย ~3 ตัวอักษร/พยางค์)
        return max(1, round(len(t.replace(" ", "").replace("\n", "")) / 3.0))


def load_lines(voice_id):
    import csv as _csv
    if not os.path.exists(CSV):
        sys.exit("ไม่พบ %s — รัน  python3 dump_npc_lines.py  ก่อน" % CSV)
    rows = []
    for r in _csv.DictReader(open(CSV, encoding="utf-8-sig")):
        if r["voice_id"] != voice_id:
            continue
        key = [v for k, v in r.items() if k.startswith("ไฟล์เสียง")][0].replace(".ogg", "")
        if key in SKIP or (ONLY and key not in ONLY):
            continue
        rows.append({"key": key, "text": r["คำพูด"], "syl": syllables(r["คำพูด"])})
    return rows


# ---------------- จับคู่ ----------------
def align(groups, lines):
    N, M = len(lines), len(groups)
    if N == 0: sys.exit("ไม่มีบทพูดของ voice_id นี้")
    if N > M:
        sys.exit("บทพูดมี %d ประโยค แต่ในไฟล์เสียงมีแค่ %d ช่วง — ใช้ --skip บอกประโยคที่ไม่ได้อ่าน" % (N, M))
    best = None
    for rate in np.arange(2.0, 7.0, 0.05):
        want = [l["syl"] / rate for l in lines]
        INF = 1e18
        D = np.full((N + 1, M + 1), INF); D[0, 0] = 0
        BT = np.zeros((N + 1, M + 1), dtype=int)
        for i in range(1, N + 1):
            for j in range(i, M + 1):
                for k in range(i - 1, j):
                    if D[i - 1, k] >= INF: continue
                    c = D[i - 1, k] + (groups[j - 1][1] - groups[k][0] - want[i - 1]) ** 2
                    if c < D[i, j]: D[i, j] = c; BT[i, j] = k
        if D[N, M] < INF and (best is None or D[N, M] < best[0]):
            path = []; j = M
            for i in range(N, 0, -1):
                k = BT[i, j]; path.append((k, j)); j = k
            path.reverse(); best = (D[N, M], rate, path)
    return best


# ---------------- เทียบเสียงใหม่กับไฟล์เดิมที่มีอยู่ (กันจับคู่ผิด) ----------------
def _logmel(sig, sr):
    from numpy.fft import rfft
    NFFT = 512; win = int(sr * 0.025); hop = int(sr * 0.01)
    def mel_fb(nmel=32, fmin=60, fmax=8000):
        h = lambda f: 2595 * np.log10(1 + f / 700); m2 = lambda m: 700 * (10 ** (m / 2595) - 1)
        pts = m2(np.linspace(h(fmin), h(fmax), nmel + 2))
        b = np.floor((NFFT + 1) * pts / sr).astype(int)
        fb = np.zeros((nmel, NFFT // 2 + 1))
        for i in range(1, nmel + 1):
            l, c, r = b[i - 1], b[i], b[i + 1]; c = max(c, l + 1); r = max(r, c + 1)
            fb[i - 1, l:c] = (np.arange(l, c) - l) / (c - l)
            fb[i - 1, c:r] = (r - np.arange(c, r)) / (r - c)
        return fb
    FB = mel_fb(); wf = np.hamming(win); out = []
    for i in range(max(1, 1 + (len(sig) - win) // hop)):
        fr = sig[i * hop:i * hop + win]
        if len(fr) < win: break
        p = np.abs(rfft(fr * wf, NFFT)) ** 2 / NFFT
        out.append(np.log(np.maximum(FB @ p, 1e-10)))
    m = np.array(out)
    return (m - m.mean()) if len(m) else m


def _dtw(A, B):
    if len(A) < 3 or len(B) < 3:
        return 9.9
    An = A / np.linalg.norm(A, axis=1, keepdims=True)
    Bn = B / np.linalg.norm(B, axis=1, keepdims=True)
    d = 1 - An @ Bn.T; n, m = d.shape
    D = np.full((n + 1, m + 1), np.inf); D[0, 0] = 0
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            D[i, j] = d[i - 1, j - 1] + min(D[i - 1, j], D[i, j - 1], D[i - 1, j - 1])
    return D[n, m] / (n + m)


## มีไฟล์เดิมชื่อเดียวกันอยู่แล้วไหม → เทียบว่าเป็น "ประโยคเดียวกัน" หรือเปล่า
## (อัดใหม่ด้วยเสียง/ความเร็วต่างกันก็ยังได้ค่าต่ำ ถ้าเป็นประโยคเดียวกันจริง)
def compare_old(x, sr, plan, voice_id):
    out_dir = os.path.join(OUT_DIR, voice_id)
    rows = []
    for c in plan:
        old = os.path.join(out_dir, c["key"] + ".ogg")
        if not os.path.exists(old):
            continue
        tmp = "/tmp/_cutvoice_old.wav"
        try:
            subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", old, "-ar", str(sr), "-ac", "1", tmp], check=True)
            w = wave.open(tmp)
            o = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
        except Exception:
            continue
        # ตัดช่วงแบบเดียวกับตอนบันทึกจริง (มีเผื่อหัวท้าย) จะได้เทียบกันตรง ๆ
        a = max(0.0, c["start"] - PAD_HEAD); b = min(len(x) / sr, c["end"] + PAD_TAIL)
        d = _dtw(_logmel(x[int(a * sr):int(b * sr)], sr), _logmel(o, sr))
        rows.append((c["key"], d))
    if not rows:
        return
    print("\nเทียบกับไฟล์เดิมในโฟลเดอร์ (ยิ่งน้อยยิ่งเป็นประโยคเดียวกัน):")
    for k, d in rows:
        mark = "ตรง" if d < 0.10 else ("น่าจะตรง" if d < 0.15 else "★ สงสัยจับคู่ผิด ★")
        print("   %-30s %.3f  %s" % (k, d, mark))


# ---------------- ตัดไฟล์ ----------------
def cut(x, sr, plan, voice_id):
    out_dir = os.path.join(OUT_DIR, voice_id)
    os.makedirs(out_dir, exist_ok=True)
    made = []
    for c in plan:
        a = max(0.0, c["start"] - PAD_HEAD)
        b = min(len(x) / sr, c["end"] + PAD_TAIL)
        clip = x[int(a * sr):int(b * sr)].copy()
        nf = int(FADE * sr)
        if len(clip) > 2 * nf:
            clip[:nf] *= np.linspace(0, 1, nf)
            clip[-nf:] *= np.linspace(1, 0, nf)
        tmp = "/tmp/_cutvoice_clip.wav"
        w = wave.open(tmp, "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((np.clip(clip, -1, 1) * 32767).astype(np.int16).tobytes()); w.close()
        dst = os.path.join(out_dir, c["key"] + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", tmp,
                        "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
        made.append(dst)
        print("   %-30s %6.2f-%6.2f  %5.2f วิ  %5.0f KB" %
              (c["key"] + ".ogg", a, b, b - a, os.path.getsize(dst) / 1024))
    return made


def main():
    if FROM_PLAN:
        plan = json.load(open(FROM_PLAN, encoding="utf-8"))
        x, sr = load_wav(plan[0]["_wav"] if "_wav" in plan[0] else WAV)
        print("ตัดตามแผนใน %s" % FROM_PLAN)
        if APPLY: cut(x, sr, plan, VOICE or plan[0]["_voice"])
        return

    if not WAV or not VOICE:
        sys.exit(__doc__)
    x, sr = load_wav(WAV)
    segs = find_segments(x, sr)
    groups = group(segs, LINE_GAP)
    lines = load_lines(VOICE)
    print("ไฟล์ %s  ยาว %.2f วิ · มีเสียง %d ช่วง → รวมเป็น %d ประโยค · บทพูดของ %s มี %d ประโยค"
          % (os.path.basename(WAV), len(x) / sr, len(segs), len(groups), VOICE, len(lines)))
    if SKIP: print("ข้ามประโยค: %s" % ", ".join(SKIP))
    if ONLY: print("เอาเฉพาะ: %s" % ", ".join(ONLY))
    cost, rate, path = align(groups, lines)
    print("จับคู่ได้ (ความเร็วพูด %.2f พยางค์/วินาที · ยิ่งตัวเลข 'พยางค์/วิ' ของแต่ละบรรทัดใกล้กัน ยิ่งน่าเชื่อ)\n" % rate)
    plan = []
    print("%-30s %-14s %6s %8s  %s" % ("ไฟล์", "ช่วงเวลา", "ยาว", "พยางค์/วิ", "ข้อความ"))
    for (k, j), l in zip(path, lines):
        a, b = groups[k][0], groups[j - 1][1]
        plan.append({"key": l["key"], "start": a, "end": b, "text": l["text"],
                     "_wav": os.path.abspath(WAV), "_voice": VOICE})
        print("%-30s %6.2f-%6.2f %6.2f %8.2f  %s"
              % (l["key"], a, b, b - a, l["syl"] / (b - a), l["text"][:38].replace("\n", " / ")))
    os.makedirs(os.path.dirname(PLAN_OUT) or ".", exist_ok=True)
    json.dump(plan, open(PLAN_OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    compare_old(x, sr, plan, VOICE)
    print("\nแผนการตัดเก็บไว้ที่ %s (แก้เวลาเองได้ แล้วสั่ง --from-plan %s --apply)" % (PLAN_OUT, PLAN_OUT))
    if APPLY:
        print("\nตัดไฟล์:")
        cut(x, sr, plan, VOICE)
        print("\nเสร็จ → %s/%s/" % (OUT_DIR, VOICE))
    else:
        print("(ใส่ --apply เพื่อตัดจริง)")


if __name__ == "__main__":
    main()
