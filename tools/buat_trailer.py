"""Menyusun trailer ROBLOCK CITY (1920x1080, 30 fps, MP4) dari tangkapan layar game.

Tiap adegan = satu gambar yang digeser/diperbesar pelan (efek Ken Burns) dengan teks di bawah,
disambung dengan transisi lebur, dibuka dan ditutup kartu judul. Tanpa suara.
Butuh Pillow dan imageio-ffmpeg:
    python tools/buat_trailer.py
"""

import os
import subprocess

import imageio_ffmpeg
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "marketing", "sumber")
OUT = os.path.join(ROOT, "marketing", "trailer_roblock_city.mp4")
W, H, FPS = 1920, 1080, 30
FADE = 12  # bingkai lebur antar adegan
FONT = r"C:\Windows\Fonts\impact.ttf"
FONT_SUB = r"C:\Windows\Fonts\segoeuib.ttf"
YELLOW, WHITE, NAVY = (255, 214, 64), (255, 255, 255), (22, 40, 86)

# (gambar, teks, detik, (zoom awal, zoom akhir), (fokus awal x,y), (fokus akhir x,y))
SCENES = [
    ("kota.jpg", "Selamat datang di kota yang ramah untuk semua!", 3.4, (1.0, 1.22), (0.5, 0.5), (0.5, 0.52)),
    ("pekerjaan_dekat.jpg", "Pilih pekerjaanmu: polisi, pemadam, dokter, pilot...", 3.2, (1.25, 1.08), (0.3, 0.62), (0.7, 0.62)),
    ("hero.jpg", "Beli mobil dan motor impianmu", 3.0, (1.3, 1.12), (0.25, 0.6), (0.6, 0.55)),
    ("bus.jpg", "Jadi sopir bus keliling kota", 2.8, (1.1, 1.3), (0.5, 0.5), (0.55, 0.52)),
    ("pesawat.jpg", "Terbangkan pesawat di atas kota", 3.4, (1.3, 1.05), (0.6, 0.5), (0.5, 0.5)),
    ("perahu.jpg", "Sewa perahu di Pulau Pantai", 2.8, (1.05, 1.3), (0.5, 0.55), (0.5, 0.6)),
    ("hewan.jpg", "Ajak hewan peliharaan jalan-jalan", 3.0, (1.35, 1.2), (0.25, 0.48), (0.75, 0.48)),
    ("mall.jpg", "Belanja di ROBLOCK Mega Mall dan buka kafemu sendiri", 3.0, (1.2, 1.35), (0.62, 0.5), (0.6, 0.52)),
    ("air_mancur.jpg", "Beli rumah, berkebun, dan selesaikan misi harian", 2.8, (1.05, 1.25), (0.5, 0.5), (0.5, 0.5)),
    ("senja.jpg", "Siang dan malam silih berganti", 3.0, (1.25, 1.05), (0.5, 0.55), (0.5, 0.5)),
]


def stroke_text(draw, xy, value, font, fill, stroke, anchor="mm"):
    x, y = xy
    draw.text((x + stroke // 2, y + stroke), value, font=font, fill=(0, 0, 0, 110), anchor=anchor,
              stroke_width=stroke, stroke_fill=(0, 0, 0, 110))
    draw.text((x, y), value, font=font, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=NAVY)


def prepare(name: str) -> Image.Image:
    """Gambar sumber diperbesar sekali (lebih besar dari layar) supaya geser/zoom tetap tajam."""
    image = Image.open(os.path.join(SRC, name)).convert("RGB")
    scale = max(W * 1.4 / image.width, H * 1.4 / image.height)
    image = image.resize((int(image.width * scale), int(image.height * scale)), Image.LANCZOS)
    image = image.filter(ImageFilter.UnsharpMask(radius=2, percent=55, threshold=2))
    return ImageEnhance.Color(image).enhance(1.12)


def frame(image: Image.Image, zoom: float, focus) -> Image.Image:
    base = min(image.width / W, image.height / H)  # jendela terbesar berasio 16:9
    cw, ch = W * base / zoom, H * base / zoom
    left = min(max(image.width * focus[0] - cw / 2, 0), image.width - cw)
    top = min(max(image.height * focus[1] - ch / 2, 0), image.height - ch)
    return image.resize((W, H), Image.BILINEAR, box=(left, top, left + cw, top + ch))


def caption_layer(value: str) -> Image.Image:
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    for y in range(H - 300, H):
        alpha = int(175 * (y - (H - 300)) / 300)
        draw.line([(0, y), (W, y)], fill=(*NAVY, alpha))
    font = ImageFont.truetype(FONT_SUB, 64)
    while draw.textlength(value, font=font) > W - 160:
        font = ImageFont.truetype(FONT_SUB, font.size - 4)
    stroke_text(draw, (W // 2, H - 110), value, font, WHITE, 6)
    small = ImageFont.truetype(FONT, 58)
    left = draw.textlength("ROBLOCK ", font=small)
    stroke_text(draw, (48, 70), "ROBLOCK ", small, WHITE, 5, "lm")
    stroke_text(draw, (48 + left, 70), "CITY", small, YELLOW, 5, "lm")
    return layer


def title_card(tagline: str) -> Image.Image:
    back = prepare("kota.jpg")
    card = frame(back, 1.1, (0.5, 0.5)).filter(ImageFilter.GaussianBlur(7))
    card = ImageEnhance.Brightness(card).enhance(0.72).convert("RGBA")
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    big = ImageFont.truetype(FONT, 300)
    left = draw.textlength("ROBLOCK ", font=big)
    right = draw.textlength("CITY", font=big)
    x0 = (W - left - right) / 2
    stroke_text(draw, (x0, 440), "ROBLOCK ", big, WHITE, 18, "lm")
    stroke_text(draw, (x0 + left, 440), "CITY", big, YELLOW, 18, "lm")
    stroke_text(draw, (W // 2, 700), tagline, ImageFont.truetype(FONT_SUB, 76), WHITE, 7)
    return Image.alpha_composite(card, layer).convert("RGB")


def ease(t: float) -> float:
    return t * t * (3 - 2 * t)


def main() -> None:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    proc = subprocess.Popen(
        [ffmpeg, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
         "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "18",
         "-pix_fmt", "yuv420p", "-movflags", "+faststart", OUT],
        stdin=subprocess.PIPE,
    )
    assert proc.stdin is not None
    state = {"previous": None, "total": 0}  # bingkai terakhir adegan sebelumnya, untuk lebur

    def emit(clip):
        last = None
        for index, image in enumerate(clip):
            if state["previous"] is not None and index < FADE:
                image = Image.blend(state["previous"], image, (index + 1) / (FADE + 1))
            proc.stdin.write(image.tobytes())
            state["total"] += 1
            last = image
        state["previous"] = last

    def still(card, seconds):
        for _ in range(int(seconds * FPS)):
            yield card

    def scene(name, value, seconds, zooms, f0, f1):
        image = prepare(name)
        layer = caption_layer(value)
        count = int(seconds * 0.82 * FPS)
        for i in range(count):
            t = ease(i / max(count - 1, 1))
            zoom = zooms[0] + (zooms[1] - zooms[0]) * t
            focus = (f0[0] + (f1[0] - f0[0]) * t, f0[1] + (f1[1] - f0[1]) * t)
            shot = frame(image, zoom, focus).convert("RGBA")
            fade = min(1.0, i / 10)  # teks muncul pelan
            if fade < 1:
                shown = layer.copy()
                shown.putalpha(shown.getchannel("A").point(lambda a: int(a * fade)))
            else:
                shown = layer
            yield Image.alpha_composite(shot, shown).convert("RGB")

    emit(still(title_card("Kota seru untuk semua umur"), 1.9))
    for entry in SCENES:
        emit(scene(*entry))
        print("adegan", entry[0], flush=True)
    emit(still(title_card("Main sekarang, gratis!"), 2.6))
    proc.stdin.close()
    proc.wait()
    print("ok", OUT, f"{state['total'] / FPS:.1f} detik")


if __name__ == "__main__":
    main()
