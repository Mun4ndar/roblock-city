# Pesawat penumpang (asli, tanpa merek): hidung ke +Y Blender (= -Z Roblox). Panjang ~77, bentang sayap ~71.
import math
exec(open(r"D:\ROBLOX STUDIO\tools\blender_lib.py").read())

clear_scene()
M = Maker()
ZC = 7.6
ST = [  # y, jari-jari, tinggi pusat
    (38.5, 0.5, 6.7), (37.0, 2.0, 6.9), (34.0, 3.4, 7.2), (29.5, 4.0, 7.6), (22.0, 4.1, 7.6),
    (-18.0, 4.1, 7.6), (-26.0, 3.7, 8.1), (-32.0, 2.7, 9.2), (-37.0, 1.4, 10.4), (-38.5, 0.6, 10.9),
]
SEG = 20


def ring(y, r, zc, k0=0, k1=SEG, scale=1.0):
    return [(r * scale * math.cos(2 * math.pi * k / SEG), y, zc + r * scale * math.sin(2 * math.pi * k / SEG)) for k in range(k0, k1)]


M.rings("PlWhite", [ring(*s) for s in ST])

# pita warna di sisi badan (tebal tipis): busur dari a0 ke a1 derajat
def band(side, y0, y1, a0, a1):
    rings = []
    for (y, r, zc) in ST:
        if y0 <= y <= y1:
            outer, inner = [], []
            for k in range(5):
                a = math.radians(a0 + (a1 - a0) * k / 4)
                c, s = math.cos(a) * side, math.sin(a)
                outer.append((r * 1.012 * c, y, zc + r * 1.012 * s))
                inner.append((r * 0.96 * c, y, zc + r * 0.96 * s))
            rings.append(outer + inner[::-1])
    if side < 0:
        rings = [r[::-1] for r in rings]
    M.rings("PlLivery", rings)


for side in (1, -1):
    band(side, -30, 34, -38, -20)
    band(side, -30, 34, -14, -6)  # garis tipis kedua (aksen)

# jendela penumpang
y = 25.0
while y > -17:
    for side in (1, -1):
        M.box("PlDark", side * 4.02, y, ZC + 1.15, 0.3, 1.1, 1.2)
    y -= 2.5
# jendela kokpit
for side in (1, -1):
    M.box("PlDark", side * 1.6, 34.6, ZC + 1.35, 2.4, 1.6, 1.0)
M.box("PlDark", 0, 36.0, ZC + 1.1, 2.0, 1.2, 0.9)
# pintu penumpang depan (garis)
for side in (1, -1):
    M.box("PlGray", side * 4.0, 27.0, ZC - 0.2, 0.25, 3.2, 5.2)

# sirip tegak (warna maskapai) dan ujung
M.prism("PlLivery", [(-19, 11.5), (-31, 25.5), (-37.6, 25.5), (-38.4, 10.8)], "x", -0.45, 0.45)
M.prism("PlWhite", [(-31, 25.5), (-37.6, 25.5), (-37.6, 27.0), (-32.6, 27.0)], "x", -0.45, 0.45)
# sayap tegak ekor
for side in (1, -1):
    M.hexa("PlGray",
           [(side * 2.5, -29), (side * 14, -37), (side * 14, -40), (side * 2.5, -38.8)],
           [10.2, 11.6, 11.6, 10.2], [0.5, 0.35, 0.35, 0.5])
    # sayap utama (sapuan ke belakang, naik sedikit ke ujung)
    q = [(side * 3.0, 11), (side * 34.5, -9), (side * 34.5, -13.5), (side * 3.0, -15)]
    if side < 0:
        q = q[::-1]
    M.hexa("PlGray", q, [5.2, 7.3, 7.3, 5.2], [1.3, 0.5, 0.5, 1.2])
    # sayap kecil di ujung (warna maskapai)
    M.prism("PlLivery", [(-9.0, 7.2), (-13.5, 7.2), (-14.6, 11.8), (-11.2, 11.8)], "x", side * 34.4 - 0.25, side * 34.4 + 0.25)
    # mesin
    ex = side * 12.5
    M.cyl("PlGray", (ex, 6.0, 3.3), 2.5, 8.5, "y", 14)
    M.cyl("PlDark", (ex, 10.35, 3.3), 1.9, 0.5, "y", 14)
    M.cyl("PlLivery", (ex, 9.9, 3.3), 2.55, 1.2, "y", 14)
    M.box("PlGray", ex, 5.0, 5.0, 0.8, 6.0, 1.8)
    # roda utama
    gx = side * 5.0
    M.box("PlGray", gx, -2.0, 3.2, 0.7, 0.9, 3.8)
    for dx in (-0.55, 0.55):
        M.cyl("PlTire", (gx + dx, -2.0, 1.55), 1.55, 0.8, "x", 14)

# roda depan
M.box("PlGray", 0, 29.0, 3.8, 0.7, 0.8, 3.4)
for dx in (-0.55, 0.55):
    M.cyl("PlTire", (dx, 29.0, 1.1), 1.1, 0.7, "x", 12)

objs = M.build()
tris = export(objs, r"D:\ROBLOX STUDIO\assets\blender\pesawat_penumpang.fbx")
bpy.ops.wm.save_as_mainfile(filepath=r"D:\ROBLOX STUDIO\assets\blender\roblock_bandara.blend")
print(tris)
