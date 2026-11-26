# Feri penumpang ROBLOCK CITY (Blender, 1 unit = 1 stud). Dijalankan tanpa tampilan:
#   blender -b -P tools/blender/feri.py
# Haluan di -Y Blender, atas = +Z, garis air z = 0, tengah lambung di x = 0, y = 0.
# Satu objek per bahan (warna dipasang di Studio oleh map/BuildFerry.luau). Kursi penumpang dibuat
# sebagai bangku di model; posisi dudukan ditulis ke map/FerryData.luau.
import bpy, math, os, json, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if "__file__" not in globals():
    ROOT = r"D:\ROBLOX STUDIO"
OUT_FBX = os.path.join(ROOT, "assets", "blender", "feri_blender.fbx")
OUT_BLEND = os.path.join(ROOT, "assets", "blender", "feri_blender.blend")  # diabaikan git
OUT_DATA = os.path.join(ROOT, "map", "FerryData.luau")

exec(open(os.path.join(ROOT, "tools", "blender", "kapal_lib.py")).read())

# bersihkan scene
bpy.ops.wm.read_factory_settings(use_empty=True)

C = {
    "Bawah": (0.07, 0.13, 0.30),
    "Garis": (0.78, 0.10, 0.12),
    "Badan": (0.97, 0.97, 0.98),
    "Geladak": (0.70, 0.50, 0.30),
    "Putih": (0.97, 0.97, 0.98),
    "Kayu": (0.55, 0.36, 0.20),
    "Jok": (0.10, 0.36, 0.72),
    "Besi": (0.72, 0.75, 0.80),
    "Kaca": (0.35, 0.60, 0.82),
    "Hitam": (0.09, 0.09, 0.11),
    "Merah": (0.85, 0.12, 0.12),
    "Oranye": (1.0, 0.55, 0.10),
    "Kuning": (1.0, 0.82, 0.15),
    "LampuMerah": (1.0, 0.1, 0.1),
    "LampuHijau": (0.1, 0.9, 0.2),
    "Biru": (0.10, 0.36, 0.72),
}
b = Boat("Feri", C)
L, WID = 62.0, 19.0
SHEER = 4.2
b.hull(L, WID, 2.6, SHEER, 1.1, ("Bawah", "Garis", "Badan"), exp=2.0, bow_fine=0.40,
       stern_taper=0.06, split=(-0.2, 1.1), keel_rise=0.7, prof=41, stations=48)
b.deck("Geladak", inset=0.94, lift=0.03)
rows = b._hull_rows


def hw(y):
    return b.deck_at(y)[0]


def side_x(y, z):
    """x sisi lambung (positif) pada ketinggian z di posisi y (interpolasi baris lambung)."""
    t = (y + L / 2) / L
    k = min(max(int(round(t * (len(rows) - 1))), 0), len(rows) - 1)
    row = rows[k]
    pts = sorted((p[2], abs(p[0])) for p in row[len(row) // 2:])
    for (z0, x0), (z1, x1) in zip(pts[:-1], pts[1:]):
        if z0 <= z <= z1 and z1 > z0:
            return x0 + (x1 - x0) * (z - z0) / (z1 - z0)
    return pts[-1][1]


Z0 = SHEER + 0.5  # lantai geladak utama (rata)
YB = -13.0  # awal lantai rata (haluan dibiarkan melengkung)
seats = []  # (x, y, z, hadap) hadap: -1 = ke haluan (-Y), 1 = ke buritan


# ---------------------------------------------------------------- lantai geladak (rata) + pagar
def slab(y0, y1, z, thick, mat, inset=0.96):
    y = y0
    step = 3.0
    while y < y1 - 1e-6:
        ye = min(y + step, y1)
        w = min(hw(y), hw(ye)) * inset
        b.box(mat, (0, (y + ye) / 2, z - thick / 2), (2 * w, ye - y + 0.02, thick))
        y = ye


slab(YB, L / 2 - 0.2, Z0, 0.5, "Geladak")


def rail_path(pts, h=1.05, post=2.4, mat="Besi", two=True):
    """pagar menyusuri titik-titik 3D (z = lantai)."""
    prev = None
    for p in pts:
        b.tube(mat, (p[0], p[1], p[2]), (p[0], p[1], p[2] + h), 0.07, seg=6)
    for p, q in zip(pts[:-1], pts[1:]):
        b.tube(mat, (p[0], p[1], p[2] + h), (q[0], q[1], q[2] + h), 0.07, seg=6)
        if two:
            b.tube(mat, (p[0], p[1], p[2] + h * 0.5), (q[0], q[1], q[2] + h * 0.5), 0.05, seg=6)


# pagar geladak utama: sisi kiri/kanan dan buritan
ys = [YB + i * 2.5 for i in range(int((L / 2 - 0.3 - YB) / 2.5) + 1)]
for s in (-1, 1):
    rail_path([(s * (hw(y) * 0.96 - 0.1), y, Z0) for y in ys])
rail_path([(x, L / 2 - 0.5, Z0) for x in [-hw(L / 2 - 0.5) * 0.9 + i * 2.2 for i in range(int(2 * hw(L / 2 - 0.5) * 0.9 / 2.2) + 2)]
           if abs(x) < hw(L / 2 - 0.5) * 0.96])

# ---------------------------------------------------------------- haluan (foredeck)
# pagar haluan mengikuti lengkung geladak
fy = [-L / 2 + 2.0 + i * 2.6 for i in range(int((YB - (-L / 2 + 2.0)) / 2.6) + 2)]
for s in (-1, 1):
    pts = [(s * (hw(y) * 0.93), y, b.deck_at(y)[1]) for y in fy if abs(hw(y)) > 0.8]
    rail_path(pts, h=1.0)
# jangkar + windlass
b.cyl("Hitam", (0, -L / 2 + 6.5, b.deck_at(-L / 2 + 6.5)[1] + 0.5), 0.9, 1.0, axis="Z", seg=12)
b.box("Hitam", (0, -L / 2 + 8.5, b.deck_at(-L / 2 + 8.5)[1] + 0.45), (1.8, 1.4, 0.9))
for s in (-1, 1):
    b.cyl("Besi", (s * 1.5, -L / 2 + 10.5, b.deck_at(-L / 2 + 10.5)[1] + 0.4), 0.3, 0.8, axis="Z", seg=8)
# tiang bendera haluan
yfl = -L / 2 + 3.0
zfl = b.deck_at(yfl)[1]
b.tube("Putih", (0, yfl, zfl), (0, yfl, zfl + 5.5), 0.12, seg=6)
b.prism("Merah", [(0, yfl, zfl + 5.4), (0, yfl, zfl + 4.1), (0, yfl + 2.6, zfl + 4.75)], 0.05)
b.sphere("Kuning", (0, yfl, zfl + 5.65), 0.2, seg=8)

# ---------------------------------------------------------------- kabin utama (ruang tunggu)
CY0, CY1 = YB + 0.5, 6.5
CW = hw(0) - 2.6  # setengah lebar kabin
CH = 4.1  # tinggi dinding
ZR = Z0 + CH  # atap kabin = geladak atas
b.box("Putih", (0, (CY0 + CY1) / 2, Z0 + CH / 2), (2 * CW, CY1 - CY0, CH))
# jendela samping (panel gelap + bingkai)
wy = CY0 + 2.2
while wy < CY1 - 1.6:
    for s in (-1, 1):
        b.box("Kaca", (s * (CW + 0.03), wy, Z0 + 2.3), (0.1, 2.7, 1.9))
        b.box("Besi", (s * (CW + 0.05), wy, Z0 + 3.31), (0.08, 2.9, 0.1))
        b.box("Besi", (s * (CW + 0.05), wy, Z0 + 1.29), (0.08, 2.9, 0.1))
    wy += 3.4
# pita biru di bawah jendela
for s in (-1, 1):
    b.box("Biru", (s * (CW + 0.03), (CY0 + CY1) / 2, Z0 + 0.8), (0.08, CY1 - CY0 - 0.2, 0.5))
# dinding depan: jendela lebar
for sx in (-1, 1):
    b.box("Kaca", (sx * (CW * 0.5), CY0 - 0.03, Z0 + 2.3), (CW * 0.78, 0.1, 1.9))
b.box("Besi", (0, CY0 - 0.04, Z0 + 2.3), (0.15, 0.12, 2.0))
# pintu samping dekat buritan kabin (dua daun)
for s in (-1, 1):
    b.box("Biru", (s * (CW + 0.04), CY1 - 1.3, Z0 + 1.6), (0.1, 1.8, 2.8))
    b.box("Kaca", (s * (CW + 0.09), CY1 - 1.3, Z0 + 2.2), (0.06, 1.2, 1.5))
# pintu buritan
b.box("Kaca", (0, CY1 + 0.03, Z0 + 2.2), (CW * 1.0, 0.1, 2.0))
b.box("Biru", (0, CY1 + 0.04, Z0 + 0.7), (CW * 1.0, 0.1, 0.9))
# atap kabin (geladak atas, sedikit menjorok)
b.box("Putih", (0, (CY0 + CY1) / 2, ZR + 0.18), (2 * CW + 1.4, CY1 - CY0 + 1.4, 0.36))
b.box("Biru", (0, (CY0 + CY1) / 2, ZR - 0.04), (2 * CW + 1.5, CY1 - CY0 + 1.5, 0.12))
ZU = ZR + 0.36  # lantai geladak atas

# ---------------------------------------------------------------- jembatan nakhoda
BY0, BY1 = CY0 + 0.2, CY0 + 6.2
BW = CW - 0.6
BH = 3.1
b.box("Putih", (0, (BY0 + BY1) / 2, ZU + BH / 2), (2 * BW, BY1 - BY0, BH))
# kaca depan miring + samping
b.box("Kaca", (0, BY0 - 0.2, ZU + 1.9), (2 * BW - 0.4, 0.1, 1.5), rot=(math.radians(-14), 0, 0))
for sx in (-1, 1):
    b.box("Kaca", (sx * (BW + 0.03), (BY0 + BY1) / 2 + 0.3, ZU + 1.9), (0.1, BY1 - BY0 - 1.2, 1.4))
    b.box("Kaca", (sx * (BW * 0.5), BY1 + 0.03, ZU + 1.9), (BW * 0.8, 0.1, 1.2))
b.box("Putih", (0, (BY0 + BY1) / 2, ZU + BH + 0.2), (2 * BW + 1.0, BY1 - BY0 + 1.2, 0.4))
b.box("Merah", (0, (BY0 + BY1) / 2, ZU + BH - 0.1), (2 * BW + 1.05, BY1 - BY0 + 1.25, 0.18))
# sayap jembatan
for s in (-1, 1):
    b.box("Putih", (s * (BW + 1.7), (BY0 + BY1) / 2 + 0.6, ZU + 0.2), (3.4, 3.4, 0.4))
    b.box("Kaca", (s * (BW + 0.02), (BY0 + BY1) / 2 + 0.6, ZU + 1.0), (0.05, 0.8, 0.6))
    rail_path([(s * (BW + 3.3), BY0 + 1.8 + i, ZU + 0.4) for i in range(5)] , h=0.95, two=False)
    b.tube("Besi", (s * (BW + 3.3), BY0 + 1.8, ZU + 1.35), (s * (BW + 0.2), BY0 + 1.8, ZU + 1.35), 0.06, seg=6)
# tiang radar + antena + lampu
zm = ZU + BH + 0.4
b.cyl("Besi", (0, BY0 + 3.2, zm + 0.5), 0.35, 1.0, axis="Z", seg=10)
b.tube("Besi", (0, BY0 + 3.2, zm + 1.0), (0, BY0 + 3.2, zm + 5.2), 0.1, seg=8)
b.box("Putih", (0, BY0 + 3.2, zm + 2.0), (2.6, 0.25, 0.25))  # palang
b.box("Hitam", (0, BY0 + 3.2, zm + 1.25), (3.6, 0.5, 0.2))  # radar bar (menyala)
b.sphere("Putih", (0, BY0 + 3.2, zm + 5.4), 0.3, seg=8)
b.sphere("LampuMerah", (-1.25, BY0 + 3.2, zm + 2.0), 0.2, seg=8)
b.sphere("LampuHijau", (1.25, BY0 + 3.2, zm + 2.0), 0.2, seg=8)
for sx in (-1, 1):
    b.tube("Besi", (sx * 1.6, BY1 - 0.5, zm), (sx * 1.6, BY1 - 0.5, zm + 2.6), 0.04, seg=6)
b.tube("Besi", (-1.6, BY1 - 0.5, zm + 2.6), (0, BY0 + 3.2, zm + 3.0), 0.02, seg=4)
b.tube("Besi", (1.6, BY1 - 0.5, zm + 2.6), (0, BY0 + 3.2, zm + 3.0), 0.02, seg=4)

# ---------------------------------------------------------------- cerobong
FY = CY1 - 3.2
FH = 6.0
b.box("Putih", (0, FY, ZU + 0.6), (5.2, 4.4, 1.2))
b.cyl("Merah", (0, FY, ZU + 1.2 + FH / 2), 2.0, FH, axis="Z", seg=18)
b.cyl("Putih", (0, FY, ZU + 1.2 + FH * 0.55), 2.06, 1.3, axis="Z", seg=18)
b.cyl("Biru", (0, FY, ZU + 1.2 + FH * 0.55), 2.08, 0.5, axis="Z", seg=18)
b.cyl("Hitam", (0, FY, ZU + 1.2 + FH + 0.05), 2.04, 0.9, axis="Z", seg=18)
b.cyl("Hitam", (0, FY, ZU + 1.2 + FH + 0.55), 1.6, 0.15, axis="Z", seg=18)

# ---------------------------------------------------------------- geladak atas: pagar, bangku
uy = [BY1 + 0.2 + i * 2.2 for i in range(int((CY1 + 0.5 - BY1 - 0.2) / 2.2) + 1)]
for s in (-1, 1):
    rail_path([(s * (CW + 0.55), y, ZU) for y in [BY1 + 0.2 + i * 2.2 for i in range(int((CY1 + 0.4 - BY1) / 2.2) + 1)]], h=1.0)
rail_path([(x, CY1 + 0.55, ZU) for x in (-CW - 0.55, -CW * 0.5, 0, CW * 0.5, CW + 0.55)], h=1.0)
rail_path([(x, BY1 + 0.2, ZU) for x in (-CW - 0.55, -CW * 0.5, CW * 0.5, CW + 0.55)], h=1.0, two=False)


def bench(cx, cy, face, z, w=5.4):
    """bangku 2 tempat: face = -1 menghadap haluan (sandaran di +Y), 1 menghadap buritan."""
    b.box("Putih", (cx, cy, z + 0.3), (w, 1.3, 0.6))  # kotak dasar
    b.box("Jok", (cx, cy, z + 0.68), (w - 0.1, 1.2, 0.2))  # dudukan
    b.box("Jok", (cx, cy - face * 0.62, z + 1.3), (w - 0.1, 0.22, 1.05))  # sandaran
    b.box("Besi", (cx, cy - face * 0.62, z + 1.88), (w - 0.1, 0.26, 0.12))
    for sx in (-1, 1):  # sandaran tangan
        b.box("Putih", (cx + sx * (w / 2 - 0.1), cy, z + 0.95), (0.2, 1.3, 0.32))
    # dua tempat duduk
    for sx in (-1, 1):
        seats.append((cx + sx * w * 0.25, cy, z + 0.78, face))


# bangku geladak atas: 2 baris x 2 bangku
for yy in (BY1 + 1.6, BY1 + 4.4):
    for sx in (-1, 1):
        bench(sx * 3.3, yy, -1, ZU, w=5.4)
# sekoci (perahu penyelamat) di sisi geladak atas belakang jembatan
for s in (-1, 1):
    pass

# ---------------------------------------------------------------- geladak belakang terbuka: bangku + atap tenda
AY0 = CY1 + 2.0
for i, yy in enumerate((AY0 + 1.0, AY0 + 5.0, AY0 + 9.0, AY0 + 13.0)):
    wall = min(hw(yy) * 0.96 - 1.0, 9.0)
    for sx in (-1, 1):
        bench(sx * 3.6, yy, -1, Z0, w=5.6)
# tiang + atap tenda pada geladak belakang
TY0, TY1 = AY0 - 0.4, L / 2 - 1.6
TZ = Z0 + 3.5
for s in (-1, 1):
    for yy in (TY0 + 0.6, (TY0 + TY1) / 2, TY1):
        x = s * (hw(yy) * 0.9)
        b.tube("Besi", (x, yy, Z0), (x, yy, TZ), 0.11, seg=8)
tw = hw((TY0 + TY1) / 2) * 0.9
b.box("Putih", (0, (TY0 + TY1) / 2, TZ + 0.1), (2 * tw + 0.6, TY1 - TY0 + 0.6, 0.18))
for k in range(5):  # garis biru di atap tenda
    b.box("Biru", (-tw + 0.5 + k * (2 * tw - 1.0) / 4, (TY0 + TY1) / 2, TZ + 0.22), (0.45, TY1 - TY0 + 0.6, 0.06))
# lampu gantung di bawah tenda
for yy in (TY0 + 2.5, (TY0 + TY1) / 2 + 2, TY1 - 2):
    b.sphere("Kuning", (0, yy, TZ - 0.15), 0.22, seg=8)

# ---------------------------------------------------------------- sekoci + pelampung + tangga
for s in (-1, 1):
    # sekoci di davit sisi kabin
    yb = 1.5
    x = s * (CW + 1.6)
    b.box("Oranye", (x, yb, Z0 + 3.0), (1.7, 5.4, 0.9))
    b.box("Putih", (x, yb, Z0 + 3.5), (1.5, 5.0, 0.22))
    b.box("Oranye", (x, yb - 2.8, Z0 + 3.0), (1.2, 0.8, 0.8), rot=(math.radians(28), 0, 0))
    for dy in (-1.6, 1.6):
        b.tube("Besi", (s * (CW + 0.2), yb + dy, Z0 + 3.9), (x, yb + dy, Z0 + 3.6), 0.07, seg=6)
        b.tube("Besi", (s * (CW + 0.2), yb + dy, Z0 + 2.0), (s * (CW + 0.2), yb + dy, Z0 + 3.9), 0.07, seg=6)
    # pelampung penyelamat di dinding kabin
    b.torus("Merah", (s * (CW + 0.15), CY0 + 1.0, Z0 + 1.8), 0.5, 0.14, axis="X", seg=14, tube=6)
    b.torus("Putih", (s * (CW + 0.15), CY1 - 2.8, Z0 + 1.8), 0.5, 0.14, axis="X", seg=14, tube=6)
# tangga ke geladak atas (di buritan kabin, sisi kanan)
for i in range(8):
    b.box("Besi", (CW - 0.9, CY1 + 1.0 + (7 - i) * 0.0 + 0.0, Z0 + 0.2 + i * (CH + 0.36) / 8), (1.4, 0.5, 0.1)) if False else None
# tangga lurus naik di dinding belakang kabin
for i in range(9):
    z = Z0 + 0.25 + i * 0.5
    b.box("Besi", (CW - 1.0, CY1 + 0.45 + (i * 0.28), z), (1.6, 0.9, 0.12))
b.box("Besi", (CW - 1.9, CY1 + 1.5, Z0 + 2.2), (0.1, 2.9, 4.4), rot=(math.radians(0), 0, 0)) if False else None

# bollard + tali tambat di buritan dan sisi
for s in (-1, 1):
    for yy in (L / 2 - 2.0, -L / 2 + 14.0):
        z = b.deck_at(yy)[1] if yy < YB else Z0
        b.cyl("Hitam", (s * (hw(yy) * 0.9), yy, z + 0.28), 0.28, 0.5, axis="Z", seg=8)
        b.sphere("Hitam", (s * (hw(yy) * 0.9), yy, z + 0.6), 0.32, seg=8)
# lampu navigasi sisi (merah kiri, hijau kanan) di haluan dan di jembatan
b.sphere("LampuMerah", (-(BW + 3.3), BY0 + 1.9, ZU + 0.9), 0.22, seg=8)
b.sphere("LampuHijau", ((BW + 3.3), BY0 + 1.9, ZU + 0.9), 0.22, seg=8)

# ---------------------------------------------------------------- lambung: jendela bulat, bumper, gunwale, jangkar
for yy in [-22 + i * 4.4 for i in range(11)]:
    for s in (-1, 1):
        zt = 2.4
        x = side_x(yy, zt)
        # hanya yang cukup di tengah lambung dan sisi tidak terlalu runcing
        if x > 3.0:
            b.cyl("Kaca", (s * (x + 0.02), yy, zt), 0.38, 0.1, axis="X", seg=10)
            b.torus("Besi", (s * (x + 0.04), yy, zt), 0.38, 0.05, axis="X", seg=10, tube=4)
# bumper karet hitam di sisi lambung
for s in (-1, 1):
    zt = 1.25
    prev = None
    for yy in [-26 + i * 2.0 for i in range(25)]:
        x = side_x(yy, zt)
        if x < 1.2:
            prev = None
            continue
        p = (s * (x + 0.05), yy, zt)
        if prev is not None:
            b.tube("Hitam", prev, p, 0.17, seg=6)
        prev = p
# jangkar di sisi haluan
for s in (-1, 1):
    ya = -L / 2 + 9.0
    x = side_x(ya, 3.2)
    b.box("Hitam", (s * (x + 0.2), ya, 3.0), (0.35, 1.6, 1.2))

objs = b.build(hull_mats=("Bawah", "Garis", "Badan", "Geladak", "Besi", "LampuMerah", "LampuHijau", "Kuning", "Hitam"), bevel=0.05)

# ---------------------------------------------------------------- info + ekspor
from mathutils import Vector
info = {}
mn = Vector((1e9, 1e9, 1e9))
mx = Vector((-1e9, -1e9, -1e9))
tris = 0
for ob in objs:
    vs = [v.co for v in ob.data.vertices]
    omn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    omx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    info[ob.name] = {"min": [round(c, 3) for c in omn], "max": [round(c, 3) for c in omx],
                     "center": [round((a + b_) / 2, 3) for a, b_ in zip(omn, omx)],
                     "tris": sum(len(p.vertices) - 2 for p in ob.data.polygons)}
    tris += info[ob.name]["tris"]
    mn = Vector(map(min, mn, omn))
    mx = Vector(map(max, mx, omx))
print("TRIS", tris, "BBOX", tuple(mn), tuple(mx))

for o in bpy.context.scene.objects:
    o.select_set(False)
bpy.ops.export_scene.fbx(filepath=OUT_FBX, use_selection=False, object_types={"MESH"},
                         axis_forward="-Z", axis_up="Y", apply_scale_options="FBX_SCALE_ALL",
                         global_scale=1.0, bake_space_transform=False, add_leaf_bones=False)
try:
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
except Exception as e:
    print("blend", e)

lines = ["--!strict", "-- Dibuat oleh tools/blender/feri.py (jangan diubah tangan). Koordinat Blender: haluan -Y, atas +Z, garis air z=0.",
         "return {", "\tparts = {"]
for name, d in info.items():
    lines.append("\t\t%s = { center = Vector3.new(%s), size = Vector3.new(%s), tris = %d }," % (
        name, ", ".join(str(c) for c in d["center"]),
        ", ".join(str(round(a - b_, 3)) for a, b_ in zip(d["max"], d["min"])), d["tris"]))
lines.append("\t},")
lines.append("\t-- tempat duduk: x, y, z (Blender), hadap (-1 = ke haluan)")
lines.append("\tseats = {")
for (x, y, z, f) in seats:
    lines.append("\t\t{ %.2f, %.2f, %.2f, %d }," % (x, y, z, f))
lines.append("\t},")
lines.append("}")
open(OUT_DATA, "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("seats", len(seats))
