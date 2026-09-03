# คู่มืออัพเกมขึ้น GitHub + เล่นบนเว็บ/มือถือ

เตรียมไฟล์ให้ครบแล้ว เหลือแค่ทำตาม 5 ขั้นนี้ ใช้เวลาประมาณ 15-20 นาที

**ผลลัพธ์ที่จะได้:** ลิงก์เว็บแบบ `https://<ชื่อคุณ>.github.io/<ชื่อ repo>/`
เปิดบนคอมหรือมือถือก็เล่นได้ทันที ส่งให้เพื่อนทดสอบได้เลย
และทุกครั้งที่อัพโค้ดใหม่ขึ้นไป เว็บจะ build ใหม่ให้เองอัตโนมัติ

---

## ไฟล์ที่เตรียมไว้ให้แล้ว

| ไฟล์ | หน้าที่ |
|---|---|
| `.gitignore` | บอกว่าไฟล์ไหนไม่ต้องอัพ (`.godot/`, `_updateN.zip`, `*.bak`, `build/`) |
| `export_presets.cfg` | ค่าตั้งสำหรับ export เป็นเว็บ (ปิด Thread Support ไว้แล้ว — สำคัญมาก) |
| `.github/workflows/deploy.yml` | สคริปต์ที่ GitHub จะรันเอง: โหลด Godot → build เว็บ → เอาขึ้น Pages |
| `README.md` | หน้าแรกของ repo |

**ทำไมต้องปิด Thread Support?** ถ้าเปิด เว็บที่โฮสต์ต้องส่ง header
`Cross-Origin-Opener-Policy` กับ `Cross-Origin-Embedder-Policy`
ซึ่ง **GitHub Pages ตั้งไม่ได้** เกมจะขึ้นจอขาวแล้วฟ้อง `SharedArrayBuffer is not defined`
ปิดไว้แบบนี้เกมช้าลงนิดหน่อยแต่รันได้ทุกที่

---

## ขั้นที่ 1 — ติดตั้ง GitHub Desktop

ทางที่ง่ายที่สุดสำหรับ Windows (ไม่ต้องพิมพ์คำสั่งเลย)

1. โหลดจาก https://desktop.github.com แล้วติดตั้ง
2. เปิดโปรแกรม → **Sign in to GitHub.com** → ล็อกอิน (ถ้ายังไม่มีบัญชี สมัครที่ github.com ก่อน ฟรี)
3. ตอนถาม Name / Email ให้ใส่ตามบัญชี GitHub ของคุณ

> ถ้าถนัดพิมพ์คำสั่งมากกว่า: ติดตั้ง Git for Windows (https://git-scm.com/download/win)
> แล้วข้ามไปดูหัวข้อ "แบบใช้คำสั่ง" ท้ายไฟล์นี้

---

## ขั้นที่ 2 — เพิ่มโปรเจกต์เข้า GitHub Desktop

1. เมนู **File → Add local repository**
2. เลือกโฟลเดอร์ `C:\Users\peeco\Downloads\Game Dev Rag\โปรเจกต์เกมใหม่`
3. โฟลเดอร์นี้ถูก `git init` ไว้ให้แล้ว (branch ชื่อ `main`) กด **Add repository** ได้เลย

> ถ้าโปรแกรมบอกว่า "this directory does not appear to be a Git repository"
> ให้กด **create a repository** ที่มันเสนอมา แล้วกด Create repository

---

## ขั้นที่ 3 — commit แล้วอัพขึ้น GitHub

1. ฝั่งซ้ายจะขึ้นรายการไฟล์เป็นพัน ๆ (ปกติ เพราะยังไม่เคย commit)
   — เช็คคร่าว ๆ ว่า **ไม่มี** `.godot/` กับ `_updateN.zip` อยู่ในรายการ (ถูก .gitignore ตัดออกแล้ว)
2. ช่อง **Summary** ล่างซ้าย พิมพ์อะไรก็ได้ เช่น `เริ่มโปรเจกต์`
3. กด **Commit to main** → รอสักครู่ (ไฟล์เยอะ)
4. กดปุ่ม **Publish repository** (มุมบนขวา)
2. ตั้งชื่อ repo เช่น `shadows-of-fate`
3. **เอาเครื่องหมายถูกออกจาก "Keep this code private"** ถ้าอยากให้เว็บเปิดได้ฟรี
   (GitHub Pages ของบัญชีฟรีใช้กับ repo แบบ public เท่านั้น)
4. กด **Publish repository** แล้วรอ — ครั้งแรกจะนานหน่อย (ไฟล์ภาพประมาณ 140 MB)

---

## ขั้นที่ 4 — เปิด GitHub Pages

1. เข้าหน้า repo บนเว็บ github.com
2. แท็บ **Settings** → เมนูซ้าย **Pages**
3. ช่อง **Source** เลือก **GitHub Actions** (ไม่ใช่ "Deploy from a branch")
4. เสร็จ — ไม่ต้องกดอะไรต่อ

---

## ขั้นที่ 5 — รอ build แล้วเปิดเล่น

1. แท็บ **Actions** → จะเห็นงานชื่อ **build-web** กำลังรัน (วงกลมสีเหลือง)
2. รอบแรกใช้เวลา ~5-10 นาที (ต้องโหลด Godot + export templates ~1.2 GB)
3. พอขึ้นติ๊กเขียว → คลิกเข้าไป จะเห็นลิงก์เว็บใต้หัวข้อ **deploy**
   หรือดูที่ Settings → Pages ก็ได้
4. เปิดลิงก์บนมือถือ → **ปุ่มบนจอจะโผล่เอง** เล่นได้เลย

**อัพเดตครั้งต่อไป:** แก้เกมใน Godot → เปิด GitHub Desktop → พิมพ์ข้อความสรุปสั้น ๆ →
กด **Commit to main** → กด **Push origin** → เว็บ build ใหม่ให้เองภายในไม่กี่นาที

---

## ถ้ามีปัญหา

| อาการ | สาเหตุ / วิธีแก้ |
|---|---|
| Actions ขึ้นกากบาทแดง ตอนขั้น "ติดตั้ง Godot" | เวอร์ชัน Godot ไม่ตรง — แก้ `GODOT_VERSION` ใน `.github/workflows/deploy.yml` ให้ตรงกับที่เปิดโปรเจกต์ (ดูที่ Godot → Help → About) |
| แดงตอน "สร้างเวอร์ชันเว็บ" | ชื่อ preset ต้องเป็น `Web` เป๊ะ ๆ (ดูใน `export_presets.cfg` บรรทัด `name="Web"`) |
| เปิดเว็บแล้วจอขาว/ดำ | เปิด F12 ดู Console · ถ้าฟ้อง `SharedArrayBuffer` แปลว่า Thread Support ถูกเปิด — ต้องเป็น `variant/thread_support=false` |
| เปิดบน iPhone ไม่ขึ้น | Safari บางรุ่นมีปัญหา WebGL 2 — ลอง Chrome บน Android ก่อน |
| ไม่มีเสียง | เบราว์เซอร์บังคับให้ผู้เล่นแตะจอก่อนถึงเล่นเสียงได้ (ปกติ) |
| เซฟหาย | เซฟอยู่ใน IndexedDB ของเบราว์เซอร์ · โหมดไม่ระบุตัวตน (incognito) เซฟไม่ติด · ล้างข้อมูลเว็บ = เซฟหาย |
| โหลดนาน / มือถือค้าง | ไฟล์ภาพใหญ่ (สไปรท์ชีท 4096x2048 หลายไฟล์) ถ้าจะเอาจริงควรย่อภาพลง |
| repo ใหญ่เกิน | `.gitignore` ตัด `_updateN.zip` กับ `.godot/` ออกให้แล้ว เหลือประมาณ 140 MB (ยังไม่เกินลิมิต GitHub) |
| git ฟ้อง `Unable to create index.lock: File exists` | ลบไฟล์ `.git\index.lock` ทิ้ง แล้วลองใหม่ |
| อยากเก็บกวาด | ไฟล์ `.git\_index.lock.เก่า`, `_lock2.เก่า`, `_lock3.เก่า` และ `_updateN.zip` ทั้งหมด ลบทิ้งได้เลย ไม่ได้ใช้แล้ว |

---

## ทางเลือก: build เองในเครื่อง (ไม่ใช้ GitHub Actions)

ถ้าอยากลองเปิดในเบราว์เซอร์บนคอมก่อนเลย

1. ใน Godot: **Project → Export** → จะเห็น preset **Web** อยู่แล้ว
2. ถ้าขึ้นเตือนสีเหลืองว่าไม่มี export template → **Editor → Manage Export Templates → Download and Install**
3. กด **Export Project** → เลือกที่เก็บ `build/web/index.html` → ติ๊ก **Export With Debug** ออก
4. **เปิดไฟล์ index.html ตรง ๆ ไม่ได้** ต้องเสิร์ฟผ่านเว็บเซิร์ฟเวอร์ เปิด Command Prompt ที่โฟลเดอร์ `build/web` แล้วพิมพ์:
   ```
   python -m http.server 8000
   ```
   แล้วเปิด `http://localhost:8000` ในเบราว์เซอร์
   (มือถือที่อยู่ไวไฟเดียวกันเปิด `http://<ไอพีคอม>:8000` ได้ด้วย)

---

## แบบใช้คำสั่ง (สำหรับคนถนัด Git CLI)

สร้าง repo เปล่าบน github.com ก่อน (อย่าติ๊ก Add README) แล้วรันที่โฟลเดอร์โปรเจกต์:

```bash
git add -A
git commit -m "เริ่มโปรเจกต์"
git remote add origin https://github.com/<ชื่อคุณ>/<ชื่อ repo>.git
git push -u origin main
```

โฟลเดอร์ถูก `git init` + ตั้ง branch `main` + ตั้ง `.gitignore` ไว้ให้แล้ว
เช็คก่อนได้ด้วย `git status` (ไฟล์ที่ถูกตัดออกดูด้วย `git status --ignored`)
