# Kanopi bengkel terbuka (halaman belakang Bengkel): atap pelana, tiang baja, lift dua tiang,
# rak oli, meja kerja, lemari alat, ban dan drum. Depan = +Y, atas = +Z, tengah di lantai.
# Dipakai: exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\bengkel_kanopi.py", encoding="utf8").read(), "k", "exec"))
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

new_scene("Kanopi")


def rbox(m, cx, cy, cz, sx, sy, sz, rx=0.0, ry=0.0, rz=0.0):
    """kotak miring; pusat di (cx, cy, cz), sudut dalam derajat."""
    b = bm(m)
    r = bmesh.ops.create_cube(b, size=1.0)
    bmesh.ops.scale(b, vec=(sx, sy, sz), verts=r["verts"])
    mat = Matrix.Rotation(math.radians(rz), 3, "Z") @ Matrix.Rotation(math.radians(ry), 3, "Y") @ Matrix.Rotation(math.radians(rx), 3, "X")
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=mat, verts=r["verts"])
    bmesh.ops.translate(b, vec=(cx, cy, cz), verts=r["verts"])


def cylx(m, cx, cy, cz, r, length, seg=16):
    """silinder dengan sumbu sepanjang X."""
    b = bm(m)
    res = bmesh.ops.create_cone(b, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r, depth=length)
    bmesh.ops.rotate(b, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"), verts=res["verts"])
    bmesh.ops.translate(b, vec=(cx, cy, cz), verts=res["verts"])


W, D = 44.0, 30.0           # bentang lantai
HW, HD = W / 2, D / 2
EAVE, RIDGE = 12.6, 15.4    # tinggi atap di tepi dan di bubungan
FL = 0.3                    # tebal lantai

# --- lantai + marka bay
box("KpFloor", 0, 0, 0, W, D, FL)
box("KpLine", 0, 0, FL, W - 2, 0.35, 0.04)
box("KpLine", 0, HD - 1.2, FL, W - 2, 0.35, 0.04)
box("KpLine", 0, -HD + 1.2, FL, W - 2, 0.35, 0.04)
for sx in (-1, 1):
    box("KpLine", sx * (HW - 1.0), 0, FL, 0.35, D - 2.4, 0.04)
# marka bay lift (kotak kuning di bawah mobil)
for sx in (-1, 1):
    box("KpLine", -6.0 + sx * 8.2, 0, FL, 0.3, 10.6, 0.04)
for sy in (-1, 1):
    box("KpLine", -6.0, sy * 5.3, FL, 16.7, 0.3, 0.04)

# --- tiang baja + kerah kuning
PX = (-18.0, 0.0, 18.0)
PY = (-12.0, 12.0)
for x in PX:
    for y in PY:
        box("KpPost", x, y, FL, 0.9, 0.9, EAVE - FL)
        box("KpYellow", x, y, FL, 1.4, 1.4, 1.4)
        box("KpDark", x, y, FL, 1.8, 1.8, 0.25)
# tiang bubungan di tengah (y = 0) tidak ada: ruang bebas untuk mobil

# --- rangka atap: balok melintang sepanjang X di tepi dan rafter pelana
for y in PY:
    box("KpDark", 0, y, EAVE - 1.0, W + 1.0, 0.7, 0.9)
ang = math.degrees(math.atan2(RIDGE - EAVE, HD + 0.6))
slope_len = math.hypot(HD + 0.6, RIDGE - EAVE)
for x in (-HW + 0.4, -18.0, -9.0, 0.0, 9.0, 18.0, HW - 0.4):
    for s in (-1, 1):
        cy = s * (HD + 0.6) / 2
        cz = EAVE + (RIDGE - EAVE) / 2 - 0.55
        rbox("KpDark", x, cy, cz, 0.55, slope_len, 0.55, rx=(-ang if s > 0 else ang))
# --- atap: dua sisi miring + rusuk bergelombang + bubungan + list pinggir kuning
for s in (-1, 1):
    cy = s * (HD + 0.6) / 2
    cz = EAVE + (RIDGE - EAVE) / 2
    a = (-ang if s > 0 else ang)
    rbox("KpRoof", 0, cy, cz, W + 1.6, slope_len + 0.4, 0.45, rx=a)
    n = 22
    for i in range(n):
        x = -W / 2 + 0.6 + i * (W - 1.2) / (n - 1)
        rbox("KpRib", x, cy, cz + 0.32, 0.45, slope_len + 0.3, 0.22, rx=a)
    # list kuning di tepi depan/belakang
    ey = s * (HD + 0.85)
    rbox("KpYellow", 0, ey, EAVE - 0.2, W + 1.8, 0.7, 1.3)
box("KpYellow", 0, 0, RIDGE - 0.2, W + 1.8, 1.4, 0.55)
# list samping (gable end)
for sx in (-1, 1):
    for s in (-1, 1):
        rbox("KpYellow", sx * (HW + 0.9), s * (HD + 0.6) / 2, EAVE + (RIDGE - EAVE) / 2, 0.5, slope_len + 0.4, 0.7, rx=(-ang if s > 0 else ang))

# --- lampu gantung (menyala malam)
for x in (-14.0, -4.0, 6.0, 16.0):
    for y in (-5.0, 5.0):
        zt = EAVE + (RIDGE - EAVE) * (1 - abs(y) / HD) - 1.0
        box("KpDark", x, y, zt - 0.15, 0.15, 0.15, 0.9)
        box("KpLamp", x, y, zt - 1.25, 3.0, 0.9, 0.3)

# --- dinding belakang bergelombang (y negatif) + rak
BY = -HD + 0.3
box("KpWall", 0, BY, FL, W - 1.0, 0.5, 9.0)
for i in range(30):
    x = -HW + 1.5 + i * (W - 3.0) / 29
    box("KpRib", x, BY + 0.3, FL, 0.45, 0.2, 9.0)
box("KpYellow", 0, BY + 0.28, 8.4, W - 1.0, 0.3, 0.6)
# rak tiga tingkat di dinding belakang (kiri)
SX0, SX1 = -19.0, -8.0
for lv in range(3):
    zs = 2.2 + lv * 2.6
    box("KpDark", (SX0 + SX1) / 2, BY + 1.6, zs, SX1 - SX0, 2.2, 0.25)
    # kaleng oli + kardus di tiap tingkat
    xx = SX0 + 0.9
    k = 0
    while xx < SX1 - 0.9:
        if (k + lv) % 3 == 0:
            box("KpBox", xx, BY + 1.6, zs + 0.25, 1.5, 1.4, 1.2)
        else:
            cyl("KpOilB" if (k + lv) % 3 == 1 else "KpOilY", xx, BY + 1.6, zs + 0.25, 0.5, 1.1, 12)
            cyl("KpOilB" if (k + lv) % 3 == 1 else "KpOilY", xx + 1.15, BY + 1.5, zs + 0.25, 0.5, 1.1, 12)
        xx += 2.4
        k += 1
for x in (SX0, SX1, (SX0 + SX1) / 2):
    box("KpDark", x, BY + 0.6, FL, 0.3, 0.3, 8.0)
# papan perkakas (pegboard) di dinding sisi kanan + perkakas gantung
box("KpPeg", 13.5, BY + 0.45, 3.0, 11.0, 0.2, 4.5)
for i in range(7):
    x = 9.0 + i * 1.5
    box("KpTool", x, BY + 0.7, 5.0, 0.18, 0.2, 1.9)
    box("KpRed", x, BY + 0.7, 4.7, 0.5, 0.25, 0.5)

# --- meja kerja di bawah pegboard
box("KpWood", 13.5, BY + 2.1, 2.6, 11.0, 3.2, 0.5)
for sx in (-1, 1):
    for sy in (-1, 1):
        box("KpDark", 13.5 + sx * 5.2, BY + 2.1 + sy * 1.3, FL, 0.45, 0.45, 2.3)
box("KpDark", 13.5, BY + 1.0, 0.9, 10.2, 0.3, 0.3)
# catok (ragum) + kaleng di meja
box("KpDark", 17.0, BY + 2.4, 3.1, 1.2, 1.4, 0.7)
box("KpRed", 17.0, BY + 2.4, 3.8, 0.8, 1.0, 0.5)
box("KpTool", 10.5, BY + 2.1, 3.1, 1.6, 0.35, 0.2)
box("KpRed", 12.5, BY + 2.0, 3.1, 1.3, 0.6, 0.5)

# --- lemari alat merah dengan laci
box("KpRed", 7.0, BY + 1.7, FL, 4.0, 2.6, 4.2)
box("KpDark", 7.0, BY + 1.7, 4.5, 4.2, 2.8, 0.3)
for i in range(4):
    box("KpTool", 7.0, BY + 3.02, 0.9 + i * 0.9, 3.2, 0.12, 0.12)
    box("KpDark", 7.0, BY + 3.0, 0.5 + i * 0.9, 3.6, 0.08, 0.05)

# --- lift dua tiang (kiri). Pusat bay x = -6
LX = -6.0
LIFT_Z = 4.4
for sy in (-1, 1):
    py = sy * 5.5
    box("KpDark", LX, py, FL, 3.2, 3.2, 0.3)
    box("KpLiftBlue", LX, py, FL + 0.3, 1.5, 1.5, 11.0)
    box("KpYellow", LX, py, 11.3, 1.7, 1.7, 0.5)
    # kereta lift (carriage) + dua lengan ayun ke tengah
    box("KpYellow", LX, py, LIFT_Z - 0.5, 8.4, 1.9, 1.0)
    for sx in (-1, 1):
        ax = LX + sx * 3.7
        l = 3.4
        box("KpDark", ax, py - sy * (l / 2 + 0.2), LIFT_Z - 0.35, 0.95, l, 0.7)
        cyl("KpRubber", ax, py - sy * (l + 0.1), LIFT_Z + 0.35, 0.8, 0.5, 14)
# --- ban & rak ban (kanan depan)
def tire(cx, cy, z0):
    cyl("KpTire", cx, cy, z0, 1.7, 1.0, 20)
    cyl("KpRim", cx, cy, z0, 0.95, 1.05, 14)
for i in range(5):
    tire(17.5, 8.0, FL + i * 1.0)
for i in range(3):
    tire(17.5, 4.2, FL + i * 1.0)
# --- drum oli
for i, (x, y) in enumerate(((19.2, -6.2), (19.2, -9.0), (16.4, -9.4))):
    cyl("KpOilB" if i != 1 else "KpRed", x, y, FL, 1.1, 3.2, 16)
    cyl("KpDark", x, y, FL + 1.1, 1.14, 0.18, 16)
    cyl("KpDark", x, y, FL + 2.2, 1.14, 0.18, 16)
# --- kompresor udara (tabung horizontal di roda kecil)
cylx("KpYellow", 1.0, BY + 1.6, 1.8, 0.95, 4.2, 16)
box("KpDark", 1.0, BY + 1.6, FL, 4.0, 1.4, 0.5)
cyl("KpDark", 2.4, BY + 1.6, 2.7, 0.2, 0.6, 8)
# --- dongkrak troli di dekat lift
box("KpRed", 4.6, 3.5, FL + 0.35, 3.4, 1.0, 0.7)
box("KpDark", 6.6, 3.5, FL + 0.5, 2.6, 0.3, 0.3)
cyl("KpDark", 4.0, 3.5, FL + 0.7, 0.45, 1.0, 10)
# --- rambu kecil "AWAS" di lantai sebelah lift
box("KpYellow", 3.4, -4.8, FL, 1.2, 1.2, 0.05)

print(export(r"D:\ROBLOX STUDIO\assets\blender\bengkel_kanopi.fbx", r"D:\ROBLOX STUDIO\assets\blender\roblock_bengkel_kanopi.blend"))
