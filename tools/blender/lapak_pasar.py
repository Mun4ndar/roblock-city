# Lapak pasar malam / warung tenda. Dipakai: exec(open(helpers.py).read()); exec(open(lapak_pasar.py).read())
# 1 unit = 1 stud. Depan (sisi pembeli) = +Y, atas = +Z. Satu bahan = satu objek (satu MeshPart).
# Warna asli dipasang di Studio per nama bagian (TendaA/TendaB dipilih acak per lapak).
import math

new_scene("Lapak")

W, D = 5.0, 3.4  # lebar (X) dan kedalaman (Y)
H = 4.0  # tinggi tiang depan


def tilt_box(m, cx, cy, cz, sx, sy, sz, ang):
    """kotak dimiringkan terhadap sumbu X (ang radian, + = sisi depan turun)."""
    b = bm(m)
    r = bmesh.ops.create_cube(b, size=1.0)
    bmesh.ops.scale(b, vec=(sx, sy, sz), verts=r["verts"])
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(ang, 3, "X"), verts=r["verts"])
    bmesh.ops.translate(b, vec=(cx, cy, cz), verts=r["verts"])


# --- lantai tipis (alas) dan meja
box("Kayu", 0, 0, 0.0, W, D, 0.15)
box("Kayu", 0, D / 2 - 0.9, 0.15, W - 0.3, 1.1, 0.85)  # badan meja depan
box("Meja", 0, D / 2 - 0.9, 1.0, W - 0.1, 1.5, 0.12)  # papan meja
box("Meja", 0, -0.2, 0.9, W - 0.6, 0.7, 0.1)  # rak belakang

# --- tiang dan dinding belakang
for sx in (-1, 1):
    box("Kayu", sx * (W / 2 - 0.15), D / 2 - 0.2, 0.15, 0.22, 0.22, 3.6)  # tiang depan (pendek: atap miring turun ke depan)
    box("Kayu", sx * (W / 2 - 0.15), -D / 2 + 0.2, 0.15, 0.22, 0.22, 4.3)  # tiang belakang (tinggi)
box("Kayu", 0, -D / 2 + 0.15, 0.4, W - 0.3, 0.16, H - 1.3)  # dinding belakang
box("Kayu", 0, -D / 2 + 0.3, 2.2, W - 0.5, 0.5, 0.12)  # rak atas

# --- atap tenda: belang bergantian miring ke depan
n = 10
sw = W / n
slope = math.atan2(0.8, D + 0.6)
for i in range(n):
    name = "TendaA" if i % 2 == 0 else "TendaB"
    cx = -W / 2 + sw * (i + 0.5)
    tilt_box(name, cx, 0.1, 3.95, sw, D + 0.9, 0.1, slope)
# jumbai tenda di sisi depan
for i in range(n):
    name = "TendaA" if i % 2 == 0 else "TendaB"
    cx = -W / 2 + sw * (i + 0.5)
    box(name, cx, D / 2 + 0.3, 3.05, sw, 0.1, 0.45)

# --- papan nama di atas meja
box("Papan", 0, D / 2 - 0.05, 2.3, W * 0.62, 0.12, 0.7)

# --- lampu gantung (bola kecil) di tepi depan
for i in range(6):
    cx = -W / 2 + 0.5 + i * (W - 1.0) / 5
    ball("Lampu", cx, D / 2 + 0.45, 2.95, 0.13, seg=8)

# --- panci/wajan di meja (isi dagangan)
cyl("Besi", -1.4, D / 2 - 0.9, 1.12, 0.55, 0.42, seg=16, r2=0.6)
cyl("Besi", 0.1, D / 2 - 0.9, 1.12, 0.42, 0.35, seg=16, r2=0.46)
box("Besi", 1.5, D / 2 - 0.9, 1.12, 0.8, 0.5, 0.3)

info = export(r"D:\ROBLOX STUDIO\assets\blender\lapak_pasar.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_lapak.blend")
print(info)
