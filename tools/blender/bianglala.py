# Bianglala dermaga pantai: tiga model terpisah.
#   bianglala_statik.fbx  rangka A-frame (asal = titik tanah di bawah poros, z=0 = lantai dermaga)
#   bianglala_putar.fbx   roda berputar (asal = pusat poros)
#   bianglala_kabin.fbx   satu gondola (asal = titik gantung di tengah atas)
# Sumbu roda = X; bidang roda = YZ; atas = +Z. Skala 1 unit = 1 stud.
# Dipakai: exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\bianglala.py", encoding="utf8").read(), "b", "exec"))
exec(compile(open(r"D:\ROBLOX STUDIO\tools\blender\helpers.py", encoding="utf8").read(), "helpers.py", "exec"))
import math

R = 36.0        # jari-jari titik gantung kabin
HUBZ = 43.0     # tinggi poros dari lantai dermaga
FRAME_X = 8.0   # rangka di x = +-8
OUT = r"D:\ROBLOX STUDIO\assets\blender"


def tube(m, p0, p1, r, seg=8):
    a, b_ = Vector(p0), Vector(p1)
    d = b_ - a
    L = d.length
    if L < 1e-4:
        return
    bb = bm(m)
    res = bmesh.ops.create_cone(bb, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r, depth=L)
    q = d.to_track_quat("Z", "Y")
    bmesh.ops.rotate(bb, cent=(0, 0, 0), matrix=q.to_matrix(), verts=res["verts"])
    bmesh.ops.translate(bb, vec=(a + b_) / 2, verts=res["verts"])


def cylx(m, cx, cy, cz, r, length, seg=20):
    tube(m, (cx - length / 2, cy, cz), (cx + length / 2, cy, cz), r, seg)


# ============================================================ statik
new_scene("BianglalaStatik")
for sx in (-1, 1):
    x = sx * FRAME_X
    for sy in (-1, 1):
        tube("WsWhite", (x, sy * 25.0, 0.5), (x, sy * 1.2, HUBZ - 1.0), 1.15, 12)
        box("WsDark", x, sy * 25.0, 0.0, 3.4, 3.4, 0.9)       # tapak kaki
        box("WsBlue", x, sy * 25.0, 0.9, 2.2, 2.2, 1.6)       # kerah kaki
    # palang silang A-frame
    for zz, yy in ((10.0, 17.5), (24.0, 10.0)):
        tube("WsBlue", (x, -yy, zz), (x, yy, zz), 0.55, 8)
    # blok bantalan poros
    box("WsDark", x, 0, HUBZ - 2.2, 3.6, 4.6, 4.4)
    cylx("WsBlue", x + sx * 1.6, 0, HUBZ, 2.1, 1.6, 20)
# balok pengikat antar sisi di dasar
for sy in (-1, 1):
    tube("WsBlue", (-FRAME_X, sy * 25.0, 1.3), (FRAME_X, sy * 25.0, 1.3), 0.8, 10)
# papan petunjuk kecil di kaki depan (teks dipasang di Studio)
print(export(OUT + r"\bianglala_statik.fbx", OUT + r"\roblock_bianglala_statik.blend"))

# ============================================================ putar
new_scene("BianglalaPutar")
cylx("WhHub", 0, 0, 0, 3.6, 9.0, 24)
cylx("WhHub", 0, 0, 0, 1.2, 2 * FRAME_X + 3.4, 16)            # poros menembus bantalan
NSEG = 48
for sx in (-1, 1):
    x = sx * 3.6
    # cincin luar
    for i in range(NSEG):
        a0, a1 = 2 * math.pi * i / NSEG, 2 * math.pi * (i + 1) / NSEG
        tube("WhRim", (x, R * math.sin(a0), R * math.cos(a0)), (x, R * math.sin(a1), R * math.cos(a1)), 0.95, 8)
    # cincin dalam
    for i in range(32):
        a0, a1 = 2 * math.pi * i / 32, 2 * math.pi * (i + 1) / 32
        tube("WhRimIn", (x, 22 * math.sin(a0), 22 * math.cos(a0)), (x, 22 * math.sin(a1), 22 * math.cos(a1)), 0.55, 6)
    # jari-jari
    for k in range(16):
        a = 2 * math.pi * k / 16
        tube("WhSpoke", (x, 3.4 * math.sin(a), 3.4 * math.cos(a)), (x, R * math.sin(a), R * math.cos(a)), 0.5, 6)
    # lampu neon di cincin luar
    for k in range(48):
        a = 2 * math.pi * (k + 0.5) / 48
        rr = R + 1.45
        box("WhLampA" if k % 2 == 0 else "WhLampB", x + 0.0, rr * math.sin(a), rr * math.cos(a), 0.7, 0.9, 0.9)
# pin gantungan kabin dan tiang silang pengikat
for k in range(16):
    a = 2 * math.pi * k / 16
    cylx("WhPin", 0, R * math.sin(a), R * math.cos(a), 0.7 if k % 2 == 0 else 0.45, 7.6, 12)
# bintang kecil/penutup di tengah tiap sisi
for sx in (-1, 1):
    cylx("WhCap", sx * 4.4, 0, 0, 2.6, 0.9, 20)
print(export(OUT + r"\bianglala_putar.fbx", OUT + r"\roblock_bianglala_putar.blend"))

# ============================================================ kabin
new_scene("BianglalaKabin")
FT = -5.8          # permukaan lantai di bawah titik gantung
CW, CD = 6.0, 7.0  # lebar (X) dan panjang (Y) kabin
box("KbFloor", 0, 0, FT - 0.4, CW, CD, 0.4)
box("KbBody", 0, 0, FT - 0.9, CW - 0.6, CD - 0.6, 0.5)             # perut bawah
# atap melengkung (tong) + tiang gantung
vault("KbRoof", 0, 0, -0.9, CW + 1.4, CD + 1.2, 1.1, 14)
box("KbBody", 0, 0, -1.0, CW + 1.2, CD + 1.0, 0.25)
cyl("KbHang", 0, 0, -1.0, 0.55, 1.0, 12)
ball("KbHang", 0, 0, 0.0, 0.8, 12)
# empat tiang sudut + balok atas
for sx in (-1, 1):
    for sy in (-1, 1):
        box("KbDark", sx * (CW / 2 - 0.2), sy * (CD / 2 - 0.2), FT, 0.4, 0.4, 4.9)
for sx in (-1, 1):
    box("KbDark", sx * (CW / 2 - 0.2), 0, FT + 4.5, 0.4, CD, 0.4)
for sy in (-1, 1):
    box("KbDark", 0, sy * (CD / 2 - 0.2), FT + 4.5, CW, 0.4, 0.4)
# dinding ujung (depan/belakang): bawah tertutup, atas kaca
for sy in (-1, 1):
    box("KbWall", 0, sy * (CD / 2 - 0.2), FT, CW - 0.6, 0.3, 1.9)
    box("KbGlass", 0, sy * (CD / 2 - 0.2), FT + 1.9, CW - 0.6, 0.15, 2.6)
    box("KbDark", 0, sy * (CD / 2 - 0.2), FT + 1.9, CW - 0.6, 0.35, 0.2)
# sisi samping: tembok rendah di dua ujung, pintu terbuka di tengah (lebar 3)
for sx in (-1, 1):
    for sy in (-1, 1):
        yc = sy * 2.55
        box("KbWall", sx * (CW / 2 - 0.2), yc, FT, 0.3, 1.9, 1.5)
        box("KbGlass", sx * (CW / 2 - 0.2), yc, FT + 1.5, 0.12, 1.9, 2.0)
    # palang pegangan di sisi pintu
    tube("KbDark", (sx * (CW / 2 - 0.2), -1.5, FT + 1.2), (sx * (CW / 2 - 0.2), 1.5, FT + 1.2), 0.12, 6)
# bangku berhadapan + sandaran
for sy in (-1, 1):
    box("KbSeat", 0, sy * 2.0, FT, CW - 1.4, 1.8, 1.0)
    box("KbSeatTop", 0, sy * 2.0, FT + 1.0, CW - 1.4, 1.8, 0.3)
    box("KbSeat", 0, sy * 2.95, FT + 1.3, CW - 1.4, 0.35, 1.8)
# lampu di bawah atap
box("KbLamp", 0, 0, -1.3, 1.2, 3.0, 0.15)
print(export(OUT + r"\bianglala_kabin.fbx", OUT + r"\roblock_bianglala_kabin.blend"))
