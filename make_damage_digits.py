# -*- coding: utf-8 -*-
## ★ สร้างชีทตัวเลขดาเมจสไตล์ MapleStory ★ (รอบ 34)
## → Sprites/ui/damage_digits.png  แถวละ 1 สไตล์ · 10 ช่อง (0-9) · ช่องละ 56x72
##   แถว 0 = ดาเมจปกติ (ม่วงอ่อน)   แถว 1 = คริติคอล (ส้มทอง)
##   แถว 2 = โดนตี (แดง)             แถว 3 = ฮีล (เขียว)
## ตัวเลขหนา ขอบดำหนา ไล่สีบน-ล่าง + แสงขาวด้านบน เหมือนเกม Maple
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

S = 3                    # supersample
CW, CH = 56, 72          # ขนาดช่องจริง
FONT_PX = 64             # ความสูงตัวเลข (พิกเซลจริง)
DIGITS = "0123456789"

STYLES = [
    # (สีบน, สีล่าง, สีขอบ)
    ((255, 240, 255), (196, 120, 255), (72, 30, 110)),      # ปกติ ม่วง
    ((255, 250, 190), (255, 140, 30),  (120, 40, 0)),        # คริ ส้มทอง
    ((255, 210, 210), (255, 60, 60),   (100, 0, 0)),         # โดนตี แดง
    ((225, 255, 220), (70, 220, 100),  (10, 80, 30)),        # ฮีล เขียว
]

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "C:/Windows/Fonts/arialbd.ttf",
]


def load_font(px):
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            return ImageFont.truetype(p, px)
    return ImageFont.load_default()


def render_digit(ch, top, bottom, edge, font):
    W, H = CW * S, CH * S
    # ---- หน้ากากตัวเลข ----
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    bbox = d.textbbox((0, 0), ch, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    ox = (W - tw) / 2 - bbox[0]
    oy = (H - th) / 2 - bbox[1] + 2 * S
    d.text((ox, oy), ch, font=font, fill=255)

    # ---- ขอบดำหนา (ขยายหน้ากาก) ----
    outline = mask.filter(ImageFilter.MaxFilter(int(5 * S) | 1))
    shadow = outline.filter(ImageFilter.GaussianBlur(2 * S))

    # ---- ไล่สีบน→ล่าง ----
    grad = Image.new("RGBA", (W, H))
    gp = grad.load()
    y0, y1 = int(H * 0.28), int(H * 0.78)
    for y in range(H):
        t = min(1.0, max(0.0, (y - y0) / float(y1 - y0)))
        c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(W):
            gp[x, y] = c

    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # เงาใต้ตัว
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 140))
    sh_mask = shadow.point(lambda v: v)
    out.paste(sh, (int(2 * S), int(3 * S)), sh_mask)
    # ขอบ
    out.paste(Image.new("RGBA", (W, H), edge + (255,)), (0, 0), outline)
    # ตัวเลขไล่สี
    out.paste(grad, (0, 0), mask)
    # แสงขาวด้านบน (highlight) — เฉพาะส่วนบน 35% ของตัวเลข
    hl = Image.new("L", (W, H), 0)
    hp = hl.load(); mp = mask.load()
    for y in range(H):
        k = 1.0 - min(1.0, max(0.0, (y - H * 0.22) / (H * 0.28)))
        if k <= 0:
            continue
        a = int(120 * k)
        for x in range(W):
            if mp[x, y]:
                hp[x, y] = a
    out.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0), hl)
    return out.resize((CW, CH), Image.LANCZOS)


def main():
    font = load_font(FONT_PX * S)
    sheet = Image.new("RGBA", (CW * len(DIGITS), CH * len(STYLES)), (0, 0, 0, 0))
    for row, (top, bottom, edge) in enumerate(STYLES):
        for col, ch in enumerate(DIGITS):
            sheet.paste(render_digit(ch, top, bottom, edge, font), (col * CW, row * CH))
    os.makedirs("Sprites/ui", exist_ok=True)
    sheet.save("Sprites/ui/damage_digits.png")
    print("บันทึก Sprites/ui/damage_digits.png", sheet.size, "ช่องละ %dx%d" % (CW, CH))
    # พรีวิว
    bg = Image.new("RGBA", sheet.size, (60, 80, 110, 255))
    bg.alpha_composite(sheet)
    bg.convert("RGB").save("/tmp/damage_digits_preview.png")


if __name__ == "__main__":
    main()
