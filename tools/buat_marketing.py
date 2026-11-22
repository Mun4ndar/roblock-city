"""Menyusun ikon (512x512) dan thumbnail (1920x1080) ROBLOCK CITY dari tangkapan layar game.

Sumber gambar: marketing/sumber/*.jpg (diambil dari Studio). Hasil: marketing/*.png.
    python tools/buat_marketing.py
"""

import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "marketing", "sumber")
OUT = os.path.join(ROOT, "marketing")
FONT = r"C:\Windows\Fonts\impact.ttf"
FONT_SUB = r"C:\Windows\Fonts\segoeuib.ttf"

YELLOW = (255, 214, 64)
WHITE = (255, 255, 255)
NAVY = (22, 40, 86)


def fit(image: Image.Image, width: int, height: int, focus=(0.5, 0.5)) -> Image.Image:
    """Potong sesuai rasio (berpusat di `focus`), lalu perbesar ke ukuran tujuan."""
    ratio = width / height
    w, h = image.size
    if w / h > ratio:
        cw, ch = int(h * ratio), h
    else:
        cw, ch = w, int(w / ratio)
    left = min(max(int(w * focus[0] - cw / 2), 0), w - cw)
    top = min(max(int(h * focus[1] - ch / 2), 0), h - ch)
    out = image.crop((left, top, left + cw, top + ch)).resize((width, height), Image.LANCZOS)
    out = out.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
    return ImageEnhance.Color(out).enhance(1.12)


def shade(image: Image.Image, top: float, bottom: float) -> Image.Image:
    """Gelapkan pita atas/bawah supaya tulisan terbaca."""
    w, h = image.size
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for y in range(h):
        t = y / h
        alpha = 0
        if t < top:
            alpha = int(150 * (1 - t / top))
        elif t > 1 - bottom:
            alpha = int(170 * ((t - (1 - bottom)) / bottom))
        if alpha:
            draw.line([(0, y), (w, y)], fill=(*NAVY, alpha))
    return Image.alpha_composite(image.convert("RGBA"), overlay)


def text(draw, xy, value, font, fill, stroke, anchor="mm"):
    x, y = xy
    draw.text((x + stroke // 2, y + stroke), value, font=font, fill=(0, 0, 0, 120), anchor=anchor,
              stroke_width=stroke, stroke_fill=(0, 0, 0, 120))
    draw.text((x, y), value, font=font, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=NAVY)


def title(image: Image.Image, center_y: int, size: int) -> None:
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(FONT, size)
    w = image.size[0]
    left = draw.textlength("ROBLOCK ", font=font)
    right = draw.textlength("CITY", font=font)
    x0 = (w - left - right) / 2
    stroke = max(4, size // 14)
    text(draw, (x0, center_y), "ROBLOCK ", font, WHITE, stroke, "lm")
    text(draw, (x0 + left, center_y), "CITY", font, YELLOW, stroke, "lm")


def thumbnail(name: str, source: str, focus, tagline: str, big_title: bool) -> None:
    image = fit(Image.open(os.path.join(SRC, source)).convert("RGB"), 1920, 1080, focus)
    image = shade(image, 0.34 if big_title else 0.2, 0.26)
    title(image, 150 if big_title else 96, 210 if big_title else 120)
    draw = ImageDraw.Draw(image)
    text(draw, (960, 985), tagline, ImageFont.truetype(FONT_SUB, 62), WHITE, 6)
    image.convert("RGB").save(os.path.join(OUT, name), "PNG")
    print("ok", name, image.size)


def icon() -> None:
    # potong lebih dekat ke hewan-hewan supaya terbaca di ukuran kecil
    source = Image.open(os.path.join(SRC, "hero.jpg")).convert("RGB").crop((440, 150, 1000, 710))
    image = fit(source, 512, 512)
    image = shade(image, 0.42, 0.0)
    draw = ImageDraw.Draw(image)
    text(draw, (256, 70), "ROBLOCK", ImageFont.truetype(FONT, 104), WHITE, 7)
    text(draw, (256, 166), "CITY", ImageFont.truetype(FONT, 104), YELLOW, 7)
    image.convert("RGB").save(os.path.join(OUT, "ikon_512.png"), "PNG")
    print("ok ikon_512.png", image.size)


if __name__ == "__main__":
    icon()
    thumbnail("thumbnail_1_utama.png", "hero.jpg", (0.5, 0.42), "Mobil, motor, pesawat, dan hewan peliharaan!", True)
    thumbnail("thumbnail_2_kota.png", "kota.jpg", (0.5, 0.55), "Jelajahi kota, bekerja, dan beli rumah impianmu", False)
    thumbnail("thumbnail_3_pantai.png", "pantai.jpg", (0.5, 0.5), "Liburan di Pulau Pantai dan sewa perahu", False)
