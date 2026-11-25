# ROBLOCK CITY: interior Balai Kota (aula, fountain, loket, sayap walikota + pelayanan).
# Dijalankan lewat Blender MCP: exec(helpers.py) lalu exec(file ini). Skala 1 unit = 1 stud,
# koordinat sama dengan balai_kota.py (depan = +Y, atas = +Z). Lantai atas = z 1.3.
import math
import random

new_scene("BalaiKotaDalam")
OUT = r"D:\ROBLOX STUDIO\assets\blender\balai_kota_dalam.fbx"
BLEND = r"D:\ROBLOX STUDIO\assets\blender\roblock_balai_kota_dalam.blend"
F = 1.3  # tinggi lantai
rnd = random.Random(7)

# ---------------- lantai ----------------
box("IFloorA", 0, -2, 1.0, 41, 21, 0.3)  # aula x +-20.5, y -12.5..8.5
box("IFloorA", 0, 9.25, 1.0, 7.4, 1.6, 0.3)  # ambang pintu
NX, NY = 20, 10
tx, ty = 41 / NX, 21 / NY
for i in range(NX):
    for j in range(NY):
        if (i + j) % 2:
            box("IFloorB", -20.5 + (i + 0.5) * tx, -12.5 + (j + 0.5) * ty, F, tx, ty, 0.02)
box("IParquet", -29.25, -2, 1.0, 14.5, 17, 0.3)  # sayap kiri (walikota)
box("IFloorA", 29.25, -2, 1.0, 14.5, 17, 0.3)  # sayap kanan (pelayanan)
for j in range(8):
    for i in range(7):
        if (i + j) % 2:
            box("IFloorB", 22 + (i + 0.5) * (14.5 / 7), -10.5 + (j + 0.5) * (17 / 8), F, 14.5 / 7, 17 / 8, 0.02)
# karpet merah: lorong dari pintu + cincin di sekeliling air mancur
cyl("IGold", 0, -1, F, 5.2, 0.02, 48)
cyl("IRug", 0, -1, F, 5.0, 0.04, 48)
box("IRug", 0, 5.7, F, 4.4, 8.2, 0.04)
box("IGold", -2.3, 5.7, F, 0.12, 8.2, 0.045)
box("IGold", 2.3, 5.7, F, 0.12, 8.2, 0.045)
box("IRugB", -29.0, -2, F, 9.0, 11.0, 0.04)  # karpet sayap kiri
box("IRugB", 19.0, 2.0, F, 0.1, 0.1, 0.0)

# ---------------- air mancur (pusat aula, ukuran kecil supaya tidak menghalangi) ----------------
FX, FY = 0, -1
K, KH = 0.56, 0.78  # skala jari-jari dan tinggi
def R(v): return v * K
def Z(v): return F + v * KH
cyl("IStone", FX, FY, F, R(5.5), 1.0, 36)
cyl("IGold", FX, FY, F + 0.83, R(5.65), 0.15, 36)
cyl("IWater", FX, FY, F + 0.6, R(5.0), 0.55, 36)
cyl("IStone", FX, FY, Z(0.7), R(1.4), 2.2 * KH, 24, R(1.0))
cyl("IStone", FX, FY, Z(2.9), R(1.2), 0.9 * KH, 28, R(3.0))
cyl("IGold", FX, FY, Z(3.6), R(3.1), 0.1, 28)
cyl("IWater", FX, FY, Z(3.55), R(2.75), 0.3 * KH, 28)
cyl("IStone", FX, FY, Z(3.8), R(0.55), 2.0 * KH, 16)
cyl("IStone", FX, FY, Z(5.5), R(0.6), 0.6 * KH, 20, R(1.7))
cyl("IGold", FX, FY, Z(5.9), R(1.75), 0.08, 20)
cyl("IWater", FX, FY, Z(5.95), R(1.4), 0.2 * KH, 20)
cyl("IGold", FX, FY, Z(6.1), R(0.28), 1.9 * KH, 12, 0.05)
ball("IGold", FX, FY, Z(8.2), 0.3)
cyl("IGold", FX, FY, F, R(7.75) + 0.2, 0.02, 40)
for k in range(4):
    a = k * math.pi / 2 + math.pi / 4
    ball("IGold", FX + math.cos(a) * R(5.5), FY + math.sin(a) * R(5.5), F + 1.3, 0.25)

# ---------------- panel dinding + hiasan ----------------
def panel(x0, x1, y0, y1, thick_axis, off):
    pass

H = 4.4  # tinggi panel kayu
for (xa, xb, ya, yb, face) in [  # (x0,x1,y0,y1): papan tipis menempel dinding
    (-20.5, 20.5, -12.5, -12.35, "B"),
    (-20.5, -3.6, 8.35, 8.5, "F"), (3.6, 20.5, 8.35, 8.5, "F"),
    (-20.5, -20.35, -12.5, -7, "L"), (-20.5, -20.35, 3, 8.5, "L"),
    (20.35, 20.5, -12.5, -7, "R"), (20.35, 20.5, 3, 8.5, "R"),
]:
    box("IPanel", (xa + xb) / 2, (ya + yb) / 2, F, xb - xa, yb - ya, H)
    box("IGold", (xa + xb) / 2, (ya + yb) / 2, F + H, (xb - xa) + (0.12 if face in "BF" else 0.1) * 0, (yb - ya), 0.18)
# kornis emas di bawah langit-langit aula
box("IGold", 0, -12.2, 20.9, 41, 0.6, 0.6)
box("IGold", 0, 8.2, 20.9, 41, 0.6, 0.6)
box("IGold", -20.2, -2, 20.9, 0.6, 21, 0.6)
box("IGold", 20.2, -2, 20.9, 0.6, 21, 0.6)

# ---------------- lampu gantung ----------------
for (cx, cy, r) in [(0, -1, 2.6), (-12, -1, 1.5), (12, -1, 1.5)]:
    cyl("IGold", cx, cy, 18.4, 0.08, 3.1, 6)
    cyl("IGold", cx, cy, 18.0, r, 0.25, 28)
    cyl("INeon", cx, cy, 17.85, r - 0.3, 0.14, 28)
    for k in range(8):
        a = k * math.pi / 4
        ball("INeon", cx + math.cos(a) * r, cy + math.sin(a) * r, 18.45, 0.18, 6)
for (cx, cy) in [(-29, -2), (29, -2)]:  # sayap
    cyl("IGold", cx, cy, 12.0, 0.06, 2.0, 6)
    cyl("IGold", cx, cy, 11.7, 1.4, 0.2, 20)
    cyl("INeon", cx, cy, 11.58, 1.1, 0.12, 20)

# ---------------- meja resepsionis (belakang) ----------------
box("IWood", 0, -8.1, F, 13, 1.8, 2.9)
box("IStone", 0, -8.1, F + 2.9, 13.6, 2.3, 0.2)
box("IGold", 0, -7.1, F + 0.4, 13, 0.1, 0.15)
box("IGold", 0, -7.1, F + 2.5, 13, 0.1, 0.15)
box("IDark", -3.2, -8.3, F + 3.1, 1.3, 0.12, 0.8)  # monitor
box("IScreen", -3.2, -8.22, F + 3.2, 1.1, 0.04, 0.6)
box("IDark", 3.2, -8.3, F + 3.1, 1.3, 0.12, 0.8)
box("IScreen", 3.2, -8.22, F + 3.2, 1.1, 0.04, 0.6)
box("IDark", 0, -8.2, F + 3.1, 0.6, 0.25, 0.25)  # telepon meja

# ---------------- loket depan (dua meja, petugas duduk menghadap aula) ----------------
for sx in (-1, 1):
    cx = sx * 12
    box("IWood", cx, 6.0, F, 5.0, 1.6, 2.7)
    box("IStone", cx, 6.0, F + 2.7, 5.4, 2.0, 0.18)
    box("IGold", cx, 5.18, F + 0.4, 5.0, 0.1, 0.15)
    box("IDark", cx - 1.0, 6.25, F + 2.88, 1.3, 0.1, 0.8)  # monitor (layar menghadap +Y = petugas)
    box("IScreen", cx - 1.0, 6.32, F + 2.98, 1.1, 0.04, 0.6)
    box("IDark", cx - 1.0, 6.45, F + 2.88, 0.2, 0.2, 0.2)
    box("IDark", cx - 1.0, 6.7, F + 2.88, 1.2, 0.45, 0.06)  # papan ketik
    box("IPaper", cx + 1.4, 6.0, F + 2.88, 0.8, 1.0, 0.04)
    # kursi petugas (y 7.5) menghadap -Y
    box("IBlue", cx, 7.5, F + 1.45, 1.7, 1.7, 0.3)
    box("IBlue", cx, 8.2, F + 1.75, 1.7, 0.3, 2.0)
    cyl("IDark", cx, 7.5, F, 0.15, 1.45, 6)
    cyl("IDark", cx, 7.5, F, 0.8, 0.12, 6)

# ---------------- bangku tunggu + tanaman ----------------
def bench(cx, cy, w=4.2, face=1):
    box("IWood", cx, cy, F + 0.9, w, 1.3, 0.25)
    box("IBlue", cx, cy, F + 1.15, w - 0.2, 1.1, 0.25)
    box("IWood", cx, cy - face * 0.6, F + 1.3, w, 0.2, 1.4)
    for dx in (-w / 2 + 0.3, w / 2 - 0.3):
        box("IGold", cx + dx, cy, F, 0.2, 1.1, 0.9)

bench(-14.5, -11.4, 4.2, -1)
bench(14.5, -11.4, 4.2, -1)


def plant(cx, cy, s=1.0):
    cyl("IPot", cx, cy, F, 0.75 * s, 1.5 * s, 14, 0.95 * s)
    cyl("IGold", cx, cy, F + 1.5 * s, 1.0 * s, 0.12, 14)
    ball("ILeaf", cx, cy, F + 2.7 * s, 1.15 * s, 10)
    ball("ILeaf", cx + 0.55 * s, cy + 0.3 * s, F + 3.5 * s, 0.8 * s, 8)
    ball("ILeaf", cx - 0.5 * s, cy - 0.3 * s, F + 3.3 * s, 0.85 * s, 8)

for (px, py) in [(-19.3, 7.2), (19.3, 7.2), (-19.3, -11.3), (19.3, -11.3), (-6.2, 7.5), (6.2, 7.5)]:
    plant(px, py)

# ---------------- sayap kiri: ruang walikota ----------------
box("IWoodD", -29.5, -2, F, 2.2, 7.0, 2.9)  # meja walikota
box("IWoodL", -29.5, -2, F + 2.9, 2.8, 7.6, 0.2)
box("IGold", -28.35, -2, F + 0.5, 0.1, 7.0, 0.15)
box("IDark", -29.9, -2.0, F + 3.1, 0.12, 1.3, 0.8)  # monitor, layar menghadap -X (walikota)
box("IScreen", -29.98, -2.0, F + 3.2, 0.04, 1.1, 0.6)
box("IPaper", -28.9, -3.6, F + 3.1, 1.0, 0.8, 0.04)
box("IPaper", -28.9, -0.6, F + 3.1, 0.8, 1.0, 0.04)
box("IGold", -29.0, -2.0, F + 3.1, 0.5, 0.25, 0.3)  # papan nama
# kursi walikota (x -32), menghadap +X
box("IRed", -32.3, -2, F + 1.7, 1.9, 1.9, 0.35)
box("IRed", -33.2, -2, F + 2.0, 0.35, 1.9, 3.0)
cyl("IDark", -32.3, -2, F, 0.15, 1.7, 6)
cyl("IDark", -32.3, -2, F, 0.9, 0.12, 6)
# bendera di belakang (x -35.8)
for fy, mat in [(-8.4, "IFlag1"), (1.9, "IFlag2")]:
    cyl("IGold", -35.8, fy, F, 0.1, 9.5, 8)
    ball("IGold", -35.8, fy, F + 9.6, 0.25, 6)
    box(mat, -35.8, fy + 1.5, F + 5.6, 0.1, 3.0, 3.2)
# rak buku sepanjang dinding belakang (y -10.5)
for sx0 in (-34, -29.5, -25):
    box("IWoodD", sx0, -9.9, F, 3.8, 1.0, 8.0)
    for k in range(5):
        box("IWoodL", sx0, -9.85, F + 0.2 + k * 1.6, 3.6, 1.1, 0.12)
        bx = sx0 - 1.7
        while bx < sx0 + 1.5:
            w = rnd.uniform(0.18, 0.35)
            h = rnd.uniform(0.9, 1.35)
            box(rnd.choice(["IBook1", "IBook2", "IBook3"]), bx + w / 2, -9.55, F + 0.32 + k * 1.6, w, 0.6, h)
            bx += w + 0.04
# sofa tunggu (dinding depan sayap y 6.5)
for sx0 in (-31.5, -26.0):
    box("IBlue", sx0, 5.0, F + 0.7, 4.0, 1.6, 0.9)
    box("IBlue", sx0, 5.7, F + 1.6, 4.0, 0.35, 1.4)
    box("IBlue", sx0 - 1.85, 5.0, F + 1.6, 0.3, 1.6, 0.7)
    box("IBlue", sx0 + 1.85, 5.0, F + 1.6, 0.3, 1.6, 0.7)
plant(-23.3, 5.2, 0.9)
plant(-35.0, 5.2, 0.9)
plant(-35.0, -9.0, 0.0001)

# ---------------- sayap kanan: loket pelayanan ----------------
box("IWood", 26.3, -2, F, 1.6, 12.5, 2.8)  # konter panjang
box("IStone", 26.3, -2, F + 2.8, 2.2, 13.0, 0.2)
box("IGold", 25.45, -2, F + 0.5, 0.1, 12.5, 0.15)
for cy in (-6.5, -2.0, 2.5):  # tiga loket: sekat + monitor
    box("IWoodL", 26.6, cy - 2.0, F + 3.0, 1.9, 0.12, 1.5)
    box("IDark", 26.9, cy, F + 3.0, 0.12, 1.2, 0.75)
    box("IScreen", 26.97, cy, F + 3.08, 0.04, 1.0, 0.55)
box("IWoodL", 26.6, 4.5, F + 3.0, 1.9, 0.12, 1.5)
# lemari arsip di dinding timur
for cy in (-8.5, -6.0, -3.5, -1.0, 1.5, 4.0):
    box("IMetal", 35.8, cy, F, 1.2, 2.2, 4.6)
    box("IDark", 35.15, cy, F + 3.4, 0.05, 1.4, 0.15)
    box("IDark", 35.15, cy, F + 1.6, 0.05, 1.4, 0.15)
for sx0 in (24.5, 29.5):
    bench(sx0, 5.0, 4.2, 1)
plant(23.2, -9.3, 0.9)
plant(35.0, 5.5, 0.9)

# ---------------- bingkai lukisan / papan (kanvas ditempel di Studio) ----------------
# (dinding, u, z tengah, lebar, tinggi). L: x=-20.5 | R: x=20.5 | B: y=-12.5 | F: y=8.5 | LW: x=-36.5 | RW: x=36.5 | LF: y=6.5 sayap kiri
FRAMES = {
    "info1": ("L", -9.75, 6.1, 4.8, 3.8), "info2": ("L", 5.75, 6.1, 4.8, 3.8),
    "info3": ("R", -9.75, 6.1, 4.8, 3.8), "info4": ("R", 5.75, 6.1, 4.8, 3.8),
    "lukDowntown": ("L", -9.75, 14.8, 7.0, 5.0), "lukPantai": ("L", 5.75, 14.8, 7.0, 5.0),
    "lukRumah": ("R", -9.75, 14.8, 7.0, 5.0), "lukDesa": ("R", 5.75, 14.8, 7.0, 5.0),
    "lukBandara": ("B", -12.0, 14.0, 7.0, 5.0), "potretWalikota": ("B", 12.0, 13.5, 4.2, 5.6),
    "lambang": ("B", 0.0, 15.2, 7.0, 6.0),
    "aturan": ("F", -12.0, 12.8, 6.0, 4.0), "selamat": ("F", 12.0, 12.8, 6.0, 4.0),
    "visi": ("LW", -2.0, 8.4, 6.0, 4.2), "lukWaterfront": ("LF", -29.0, 8.2, 6.5, 3.6),
    "layanan": ("RW", -2.0, 8.4, 11.0, 5.2),
}
FRAME_INFO = {}
for name, (wall_id, u, zc, w, h) in FRAMES.items():
    def put(m, du, dv, sw, sh, depth, off):
        # du: geser sepanjang dinding, dv: geser z; off: jarak dari dinding
        z0 = zc + dv - sh / 2
        if wall_id == "L":
            box(m, -20.5 + off, u + du, z0, depth, sw, sh)
        elif wall_id == "R":
            box(m, 20.5 - off, u + du, z0, depth, sw, sh)
        elif wall_id == "B":
            box(m, u + du, -12.5 + off, z0, sw, depth, sh)
        elif wall_id == "F":
            box(m, u + du, 8.5 - off, z0, sw, depth, sh)
        elif wall_id == "LW":
            box(m, -36.5 + off, u + du, z0, depth, sw, sh)
        elif wall_id == "RW":
            box(m, 36.5 - off, u + du, z0, depth, sw, sh)
        elif wall_id == "LF":
            box(m, u + du, 6.5 - off, z0, sw, depth, sh)
    put("IFrameBack", 0, 0, w, h, 0.12, 0.06)
    b = 0.28
    put("IGold", 0, h / 2 - b / 2, w, b, 0.26, 0.13)
    put("IGold", 0, -h / 2 + b / 2, w, b, 0.26, 0.13)
    put("IGold", -w / 2 + b / 2, 0, b, h - 2 * b, 0.26, 0.13)
    put("IGold", w / 2 - b / 2, 0, b, h - 2 * b, 0.26, 0.13)
    FRAME_INFO[name] = (wall_id, u, zc, w - 2 * b, h - 2 * b)

print("FRAMES", {k: v for k, v in FRAME_INFO.items()})
print(export(OUT, BLEND))
