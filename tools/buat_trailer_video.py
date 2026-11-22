"""Menyusun trailer ROBLOCK CITY dari REKAMAN permainan (marketing/rekaman/*.mp4) + dua gambar.

Rekaman diambil dari layar Studio saat uji main (kamera sinematik), lalu di sini dipotong, diperbesar
ke 1920x1080, diberi teks, dan disambung dengan kartu judul. Tanpa suara.
Butuh Pillow dan imageio-ffmpeg:
    python tools/buat_trailer_video.py
"""

import os
import subprocess
import tempfile

import imageio_ffmpeg
from PIL import Image

from buat_trailer import FPS, H, W, caption_layer, ease, frame, prepare, title_card

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REC = os.path.join(ROOT, "marketing", "rekaman")
OUT = os.path.join(ROOT, "marketing", "trailer_roblock_city.mp4")
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
ENCODE = ["-c:v", "libx264", "-preset", "medium", "-crf", "21", "-pix_fmt", "yuv420p", "-r", str(FPS), "-an"]

# ("video", berkas, mulai detik, lama detik, teks) atau ("gambar", berkas sumber, lama, teks, zoom, fokus awal, fokus akhir)
PLAN = [
    ("judul", "Kota seru untuk semua umur", 1.4),
    ("video", "a_kota.mp4", 1.6, 3.8, "Selamat datang di kota yang ramah untuk semua!"),
    ("gambar", "pekerjaan_dekat.jpg", 2.2, "Pilih pekerjaanmu: polisi, pemadam, dokter, pilot...", (1.22, 1.1), (0.32, 0.62), (0.68, 0.62)),
    ("video", "d_mobil.mp4", 5.3, 2.6, "Kendarai mobil dan motor impianmu"),
    ("video", "b_pesawat.mp4", 3.4, 4.6, "Jadi pilot dan lepas landas!"),
    ("video", "c_terbang.mp4", 2.0, 4.6, "Terbang di atas kota"),
    ("video", "e_perahu.mp4", 5.6, 3.0, "Sewa perahu di Pulau Pantai"),
    ("gambar", "hewan.jpg", 2.2, "Ajak hewan peliharaan jalan-jalan", (1.32, 1.2), (0.28, 0.48), (0.72, 0.48)),
    ("video", "f_taman.mp4", 2.2, 3.0, "Beli rumah, berkebun, dan selesaikan misi harian"),
    ("judul", "Main sekarang, gratis!", 2.2),
]


def run(args):
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", *args], check=True)


def frames_to_video(frames, path):
    proc = subprocess.Popen(
        [FFMPEG, "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
         "-r", str(FPS), "-i", "-", *ENCODE, path],
        stdin=subprocess.PIPE,
    )
    assert proc.stdin is not None
    for image in frames:
        proc.stdin.write(image.tobytes())
    proc.stdin.close()
    proc.wait()


def main() -> None:
    work = tempfile.mkdtemp(prefix="trailer_")
    parts = []
    for index, entry in enumerate(PLAN):
        part = os.path.join(work, f"bagian_{index:02d}.mp4")
        kind = entry[0]
        if kind == "judul":
            card = title_card(entry[1])
            frames_to_video((card for _ in range(int(entry[2] * FPS))), part)
        elif kind == "gambar":
            _, name, seconds, text, zooms, f0, f1 = entry
            image, layer = prepare(name), caption_layer(text)
            count = int(seconds * FPS)

            def still_frames():
                for i in range(count):
                    t = ease(i / max(count - 1, 1))
                    zoom = zooms[0] + (zooms[1] - zooms[0]) * t
                    focus = (f0[0] + (f1[0] - f0[0]) * t, f0[1] + (f1[1] - f0[1]) * t)
                    shot = frame(image, zoom, focus).convert("RGBA")
                    yield Image.alpha_composite(shot, layer).convert("RGB")

            frames_to_video(still_frames(), part)
        else:
            _, name, start, seconds, text = entry
            overlay = os.path.join(work, f"teks_{index:02d}.png")
            caption_layer(text).save(overlay)
            run([
                "-ss", str(start), "-t", str(seconds), "-i", os.path.join(REC, name), "-i", overlay,
                "-filter_complex",
                f"[0:v]fps={FPS},scale={W}:{H}:flags=lanczos,unsharp=5:5:0.5,eq=saturation=1.1[v];[v][1:v]overlay=0:0",
                *ENCODE, part,
            ])
        parts.append(part)
        print("bagian", index, kind, flush=True)

    listing = os.path.join(work, "daftar.txt")
    with open(listing, "w", encoding="utf-8") as handle:
        for part in parts:
            handle.write("file '" + part.replace("\\", "/") + "'\n")
    joined = os.path.join(work, "gabung.mp4")
    run(["-f", "concat", "-safe", "0", "-i", listing, "-c", "copy", joined])
    total = sum(e[2] if e[0] != "video" else e[3] for e in PLAN)
    run(["-i", joined, "-vf", f"fade=t=in:st=0:d=0.4,fade=t=out:st={total - 0.5:.2f}:d=0.5",
         *ENCODE, "-movflags", "+faststart", OUT])
    print("ok", OUT, f"{total:.1f} detik")


if __name__ == "__main__":
    main()
