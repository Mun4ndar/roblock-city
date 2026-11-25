"""Thumbnail (1920x1080) dan ikon (512x512) ROBLOCK CITY versi iklan, dari tangkapan layar Studio.

Sumber: marketing/sumber/n_*.jpg. Hasil: marketing/baru/*.png.
Jalankan dengan Python yang punya Pillow:  python tools/buat_thumbnail_baru.py
"""

import math
import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "marketing", "sumber")
OUT = os.path.join(ROOT, "marketing", "baru")
os.makedirs(OUT, exist_ok=True)
IMPACT = r"C:\Windows\Fonts\impact.ttf"
BOLD = r"C:\Windows\Fonts\segoeuib.ttf"

NAVY = (18, 34, 80)
WHITE = (255, 255, 255)
YELLOW = (255, 214, 64)
ORANGE = (255, 122, 40)
RED = (235, 50, 60)
GREEN = (60, 200, 90)
CYAN = (40, 200, 240)


def font(path, size):
    return ImageFont.truetype(path, size)


def load(name, w, h, focus=(0.5, 0.5), zoom=1.0):
    img = Image.open(os.path.join(SRC, name)).convert("RGB")
    iw, ih = img.size
    ratio = w / h
    cw, ch = (int(ih * ratio), ih) if iw / ih > ratio else (iw, int(iw / ratio))
    cw, ch = int(cw / zoom), int(ch / zoom)
    left = min(max(int(iw * focus[0] - cw / 2), 0), iw - cw)
    top = min(max(int(ih * focus[1] - ch / 2), 0), ih - ch)
    out = img.crop((left, top, left + cw, top + ch)).resize((w, h), Image.LANCZOS)
    out = out.filter(ImageFilter.UnsharpMask(radius=2.2, percent=90, threshold=2))
    out = ImageEnhance.Color(out).enhance(1.22)
    out = ImageEnhance.Contrast(out).enhance(1.08)
    return out.convert("RGBA")


def gradient(size, top_alpha, bottom_alpha, color=NAVY, top_frac=0.45, bottom_frac=0.4):
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for y in range(h):
        t = y / h
        a = 0
        if t < top_frac:
            a = int(top_alpha * (1 - t / top_frac) ** 1.4)
        elif t > 1 - bottom_frac:
            a = int(bottom_alpha * ((t - (1 - bottom_frac)) / bottom_frac) ** 1.4)
        if a:
            d.line([(0, y), (w, y)], fill=(*color, a))
    return layer


def rays(size, center, color=(255, 255, 255), alpha=38, count=18):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy = center
    r = max(size) * 1.6
    for i in range(count):
        a0 = 2 * math.pi * i / count
        a1 = a0 + math.pi / count
        d.polygon([(cx, cy), (cx + r * math.cos(a0), cy + r * math.sin(a0)),
                   (cx + r * math.cos(a1), cy + r * math.sin(a1))], fill=(*color, alpha))
    return layer


def outlined(img, xy, value, fnt, fill, stroke, anchor="la", outline=NAVY, shadow=True):
    d = ImageDraw.Draw(img)
    x, y = xy
    if shadow:
        d.text((x + stroke * 0.5, y + stroke * 1.3), value, font=fnt, fill=(0, 0, 0, 150), anchor=anchor,
               stroke_width=stroke, stroke_fill=(0, 0, 0, 150))
    d.text((x, y), value, font=fnt, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=outline)


def badge(img, center, text, size, fill=RED, text_fill=WHITE, angle=-10, points=14):
    """Lencana bergerigi (seperti bintang) dengan tulisan; di-rotasi."""
    s = size * 2
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = s / 2
    pts = []
    for i in range(points * 2):
        r = c * 0.97 if i % 2 == 0 else c * 0.82
        a = math.pi * i / points
        pts.append((c + r * math.cos(a), c + r * math.sin(a)))
    d.polygon(pts, fill=(*NAVY, 255))
    pts2 = [(c + (x - c) * 0.93, c + (y - c) * 0.93) for x, y in pts]
    d.polygon(pts2, fill=(*fill, 255))
    lines = text.split("\n")
    fsize = int(size * (0.34 if len(lines) == 1 else 0.3))
    f = font(IMPACT, fsize)
    lh = fsize * 1.05
    y0 = c - lh * (len(lines) - 1) / 2
    for i, line in enumerate(lines):
        d.text((c, y0 + i * lh), line, font=f, fill=text_fill, anchor="mm", stroke_width=max(2, size // 70),
               stroke_fill=NAVY)
    layer = layer.rotate(angle, resample=Image.BICUBIC).resize((size, size), Image.LANCZOS)
    img.alpha_composite(layer, (int(center[0] - size / 2), int(center[1] - size / 2)))


def ribbon(img, box, text, fill=YELLOW, text_fill=NAVY, fsize=58):
    x0, y0, x1, y1 = box
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle((x0 + 6, y0 + 10, x1 + 6, y1 + 10), radius=26, fill=(0, 0, 0, 110))
    d.rounded_rectangle(box, radius=26, fill=(*NAVY, 255))
    d.rounded_rectangle((x0 + 7, y0 + 7, x1 - 7, y1 - 7), radius=21, fill=(*fill, 255))
    d.text(((x0 + x1) / 2, (y0 + y1) / 2 + 2), text, font=font(BOLD, fsize), fill=text_fill, anchor="mm")
    img.alpha_composite(layer)


def logo(img, xy, size=170, anchor="la"):
    """ROBLOCK putih + CITY kuning dalam satu baris."""
    f = font(IMPACT, size)
    d = ImageDraw.Draw(img)
    w1 = d.textlength("ROBLOCK ", font=f)
    w2 = d.textlength("CITY", font=f)
    x, y = xy
    total = w1 + w2
    if anchor == "ma":
        x -= total / 2
    outlined(img, (x, y), "ROBLOCK ", f, WHITE, size // 14)
    outlined(img, (x + w1, y), "CITY", f, YELLOW, size // 14)
    return total


def party(img, seed=7):
    """Confetti dan nada musik untuk suasana pesta."""
    import random
    r = random.Random(seed)
    W, H = img.size
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cols = [RED, YELLOW, CYAN, GREEN, ORANGE, (255, 110, 200), (160, 110, 255)]
    for _ in range(90):
        x, y = r.randint(0, W), r.randint(0, int(H * 0.9))
        w, h = r.randint(10, 24), r.randint(18, 40)
        c = Image.new("RGBA", (w, h), (*r.choice(cols), 235))
        c = c.rotate(r.randint(0, 180), expand=True)
        layer.alpha_composite(c, (x, y))
    sym = ImageFont.truetype(r"C:\Windows\Fonts\seguisym.ttf", 120)
    for x, y, t in [(1480, 420, "♪"), (1700, 300, "♫"), (1250, 560, "♫"), (1820, 560, "♪")]:
        d.text((x, y), t, font=sym, fill=(255, 255, 255, 235), stroke_width=7, stroke_fill=(*NAVY, 255), anchor="mm")
    img.alpha_composite(layer)


def thumb(name, spec):
    W, H = 1920, 1080
    img = load(spec["src"], W, H, spec.get("focus", (0.5, 0.5)), spec.get("zoom", 1.0))
    img.alpha_composite(rays(img.size, spec.get("ray", (W * 0.5, H * 0.55)), alpha=spec.get("ray_alpha", 20)))
    img.alpha_composite(gradient(img.size, 185, 190, top_frac=0.36, bottom_frac=0.3))
    if spec.get("party"):
        party(img)
    lx = spec.get("logo_x", 70)
    if spec.get("logo_center"):
        logo(img, (W // 2, 20), size=130, anchor="ma")
    else:
        logo(img, (lx, 20), size=130)
    # judul besar
    tf = font(IMPACT, spec.get("title_size", 175))
    x = spec.get("title_x", 70)
    d = ImageDraw.Draw(img)
    for line, color in spec["title"]:
        outlined(img, (x, spec.get("title_y", 175)), line + " ", tf, color, 13)
        x += d.textlength(line + " ", font=tf)
    rw = int(ImageDraw.Draw(img).textlength(spec["sub"], font=font(BOLD, spec.get("rib_font", 58)))) + 90
    ribbon(img, (spec.get("rib_x", 70), 930, spec.get("rib_x", 70) + rw, 1035), spec["sub"],
           fill=spec.get("rib_fill", YELLOW), fsize=spec.get("rib_font", 58))
    for b in spec.get("badges", []):
        badge(img, b["pos"], b["text"], b["size"], fill=b.get("fill", RED), angle=b.get("angle", -10))
    img.convert("RGB").save(os.path.join(OUT, name), quality=95)
    print("ok", name)


SPECS = {
    "thumb_A_kota_baru.png": dict(
        src="n_balaikota.jpg", focus=(0.5, 0.52), zoom=1.0,
        title=[("KOTAMU", WHITE), ("SEKARANG!", YELLOW)], title_size=150, title_y=160,
        sub="Kerja • Mobil • Pesawat • Jet Ski", rib_w=1020,
        badges=[dict(pos=(1700, 770), text="BARU!\nBalai Kota\nMewah", size=330, fill=RED, angle=-9)]),
    "thumb_B_pesawat.png": dict(
        src="n_bandara.jpg", focus=(0.5, 0.55), zoom=1.0,
        title=[("TERBANG", WHITE), ("DARI BANDARA!", ORANGE)], title_size=150, title_y=160,
        sub="Jadi pilot di bandara internasional", rib_w=1040,
        badges=[dict(pos=(1740, 770), text="GRATIS\nMAIN!", size=330, fill=GREEN, angle=9)]),
    "thumb_C_jetski.png": dict(
        src="n_jetski2.jpg", focus=(0.5, 0.5), zoom=1.0,
        title=[("TANTANGAN", WHITE), ("JET SKI!", CYAN)], title_size=150, title_y=160,
        sub="Kumpulkan cincin • Santai di Kafe Pantai", rib_w=1130,
        badges=[dict(pos=(1700, 770), text="REKOR\nBARU?", size=330, fill=ORANGE, angle=-8)]),
    "thumb_D_petani.png": dict(
        src="n_perkebunan.jpg", focus=(0.5, 0.5), zoom=1.0,
        title=[("JADI PETANI", WHITE), ("SUKSES!", GREEN)], title_size=150, title_y=160,
        sub="Tanam • Panen • Jual di Perkebunan Besar", rib_w=1190,
        badges=[dict(pos=(1720, 770), text="60 PETAK\nLADANG", size=330, fill=RED, angle=8)]),
    "thumb_E_mobil.png": dict(
        src="n_dealer.jpg", focus=(0.45, 0.5), zoom=1.0,
        title=[("MOBIL", WHITE), ("IMPIANMU!", YELLOW)], title_size=150, title_y=160,
        sub="ROBLOCK AUTO • 6 mobil & motor keren", rib_w=1130,
        badges=[dict(pos=(1730, 770), text="ADA\nCAT &\nVELG!", size=330, fill=CYAN, angle=-8)]),
    "thumb_F_hewan.png": dict(
        src="n_hewan.jpg", focus=(0.5, 0.38), zoom=1.0,
        title=[("PELIHARA", WHITE), ("HEWAN LUCU!", ORANGE)], title_size=150, title_y=160,
        sub="Ikut kamu ke mana saja • Beri makan & sayangi", rib_w=1230,
        badges=[dict(pos=(1780, 880), text="5 HEWAN\nIMUT!", size=330, fill=RED, angle=8)]),
    "thumb_G_pesta_pantai.png": dict(
        src="n_pesta2.jpg", focus=(0.5, 0.42), zoom=1.0, party=True,
        title=[("PESTA", WHITE), ("DI PANTAI!", CYAN)], title_size=150, title_y=160,
        sub="Jus Segar • Lantai Dansa • Musik EDM", rib_w=1040,
        badges=[dict(pos=(1730, 770), text="BUKA\n08-21!", size=330, fill=ORANGE, angle=-8)]),
    "thumb_H_resort.png": dict(
        src="n_resort.jpg", focus=(0.5, 0.5), zoom=1.0,
        title=[("LIBURAN", WHITE), ("DI RESORT!", YELLOW)], title_size=150, title_y=160,
        sub="Bangunan baru: kolam renang, mall, bioskop!", rib_w=1210,
        badges=[dict(pos=(1730, 770), text="BARU!", size=330, fill=RED, angle=-8)]),
}


def icon(name, src, focus, zoom):
    S = 512
    img = load(src, S, S, focus, zoom)
    img.alpha_composite(gradient(img.size, 200, 210, top_frac=0.45, bottom_frac=0.4))
    logo(img, (S // 2, 18), size=84, anchor="ma")
    # "CITY" besar tidak perlu: logo sudah satu baris; tambah tagline
    ribbon(img, (30, 410, 482, 490), "KOTA SERU!", fsize=46)
    img.convert("RGB").save(os.path.join(OUT, name), quality=95)
    print("ok", name)


if __name__ == "__main__":
    for n, s in SPECS.items():
        thumb(n, s)
    icon("ikon_512_balaikota.png", "n_balaikota.jpg", (0.52, 0.52), 1.5)
    icon("ikon_512_pesawat.png", "n_bandara.jpg", (0.45, 0.6), 1.7)
    icon("ikon_512_hewan.png", "n_hewan.jpg", (0.5, 0.5), 1.4)
    icon("ikon_512_jetski.png", "n_jetski.jpg", (0.42, 0.62), 1.6)
